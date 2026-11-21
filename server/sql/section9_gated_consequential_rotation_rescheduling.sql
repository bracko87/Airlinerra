-- Atomic consequential rotation rescheduling, separately gated from dispatch.
ALTER TABLE airlinerra_game.section9_disruption_release_v1
 ADD COLUMN IF NOT EXISTS rotation_rescheduling_enabled boolean NOT NULL DEFAULT false;

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_rotation_reschedule_receipts_v1(
 root_occurrence_id uuid PRIMARY KEY REFERENCES airlinerra_game.section9_dated_flight_occurrences_v1(id) ON DELETE CASCADE,
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 result jsonb NOT NULL CHECK(jsonb_typeof(result)='object')
);
ALTER TABLE airlinerra_game.section9_rotation_reschedule_receipts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_rotation_reschedule_receipts_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_reschedule_disrupted_rotation_v1(
 p_root uuid,p_max_delay_minutes integer DEFAULT 240
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE root record; leg record; pos jsonb; prior jsonb; now_utc timestamptz; ready timestamptz; airport text;
 planned jsonb; cancelled jsonb; cancellation_reason text; technical integer; d timestamptz; a timestamptz;
 earliest timestamptz; n integer; delayed_count integer:=0; cancelled_count integer:=0; examined integer:=0;
 result jsonb; items jsonb:='[]'::jsonb; blocker jsonb; ids uuid[]; recovery_boundary boolean:=false;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_ROTATION_RESCHEDULER';END IF;
 IF p_root IS NULL OR p_max_delay_minutes IS NULL OR p_max_delay_minutes NOT BETWEEN 30 AND 720 THEN RAISE EXCEPTION 'INVALID_ROTATION_RESCHEDULING_INPUT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_disruption_release_v1 WHERE world_id=1
 AND rotation_rescheduling_enabled AND replacement_reservation_enabled AND cancellation_enabled) THEN
 RETURN jsonb_build_object('status','rotation_rescheduling_not_released','committed',false);END IF;
 IF NOT pg_try_advisory_xact_lock(583729,10041) THEN RETURN jsonb_build_object('status','rotation_dispatch_busy','committed',false);END IF;
 SELECT r.result INTO prior FROM airlinerra_game.section9_rotation_reschedule_receipts_v1 r WHERE root_occurrence_id=p_root;
 IF FOUND THEN RETURN prior||jsonb_build_object('replayed',true);END IF;
 SELECT o.*,al.owner_player_id INTO root FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airlines al ON al.id=o.airline_id
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.aircraft_inventory_id=o.aircraft_inventory_id AND s.version=o.schedule_version AND s.status='active' AND s.operationally_verified
 WHERE o.id=p_root AND o.world_id=1 AND o.booking_status='open' AND o.source_kind='game_verified_saleable_schedule_v1';
 IF NOT FOUND THEN RETURN jsonb_build_object('status','rotation_root_unavailable','committed',false);END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=root.aircraft_inventory_id AND fleet_status='in_service' FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','rotation_aircraft_unavailable','committed',false);END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL OR now_utc<root.departure_utc-interval '10 minutes' THEN
 RETURN jsonb_build_object('status','rotation_outside_assessment_window','committed',false);END IF;
 SELECT technical_delay_minutes INTO technical FROM airlinerra_game.section9_flight_disruption_decisions_v1 WHERE occurrence_id=p_root;
 IF coalesce(technical,0)<=0 THEN RETURN jsonb_build_object('status','positive_root_technical_delay_required','committed',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 WHERE o.aircraft_inventory_id=root.aircraft_inventory_id AND o.id<>p_root AND o.departure_utc<=root.departure_utc AND o.booking_status IN('open','closed')
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.flight_occurrence_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text AND m.phase='arrived'))
 THEN RETURN jsonb_build_object('status','earlier_aircraft_rotation_unresolved','committed',false);END IF;
 pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(root.owner_player_id,root.airline_id,root.aircraft_inventory_id,(now_utc AT TIME ZONE 'Europe/Berlin')::date);
 IF pos->>'verified' IS DISTINCT FROM 'true' OR pos->>'atGroundAirport' IS DISTINCT FROM 'true' OR pos->>'airportKey' IS NULL THEN
 RETURN jsonb_build_object('status','rotation_ground_position_unverified','committed',false);END IF;
 airport:=pos->>'airportKey';
 SELECT greatest(date_trunc('second',now_utc)+interval '1 second',coalesce(max(m.actual_event_utc+make_interval(mins=>o.turnaround_minutes)),'-infinity'::timestamptz)) INTO ready
 FROM airlinerra_game.section9_operated_flight_movements_v1 m JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON m.flight_occurrence_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text
 WHERE m.aircraft_inventory_id=root.aircraft_inventory_id AND m.phase='arrived';
 SELECT array_agg(id ORDER BY departure_utc,id) INTO ids FROM (
 SELECT o.id,o.departure_utc FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 WHERE o.aircraft_inventory_id=root.aircraft_inventory_id AND o.departure_utc>=root.departure_utc AND o.booking_status IN('open','closed')
 ORDER BY o.departure_utc,o.id LIMIT 101) q;
 IF cardinality(ids)>100 THEN RETURN jsonb_build_object('status','rotation_horizon_requires_sharding','committed',false);END IF;
 -- Lock capacity in deterministic order before examining any candidate pair.
 PERFORM 1 FROM airlinerra_game.section6_airport_slot_capacity_v1 c WHERE c.world_id=1 AND c.airport_key IN(
 SELECT origin_airport_key FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=ANY(ids)
 UNION SELECT destination_airport_key FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=ANY(ids))
 ORDER BY c.airport_key FOR UPDATE;
 BEGIN
 FOR leg IN SELECT o.*,s.configuration_id,s.departure_stand_type,s.arrival_stand_type,s.status AS schedule_status,s.operationally_verified,
 coalesce(td.technical_delay_minutes,0) AS technical_minutes
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.aircraft_inventory_id=o.aircraft_inventory_id AND s.version=o.schedule_version
 LEFT JOIN airlinerra_game.section9_flight_disruption_decisions_v1 td ON td.occurrence_id=o.id
 WHERE o.id=ANY(ids) ORDER BY o.departure_utc,o.id
 LOOP
 examined:=examined+1; cancellation_reason:=NULL;
 IF leg.booking_status<>'open' OR leg.source_kind<>'game_verified_saleable_schedule_v1' OR leg.schedule_status<>'active' OR NOT leg.operationally_verified OR EXISTS(
 SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.flight_occurrence_id=leg.schedule_id::text||':'||leg.flight_local_date::text||':'||leg.weekly_entry::text)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1 WHERE occurrence_id=leg.id)
 THEN blocker:=jsonb_build_object('status','rotation_leg_already_operated_or_reserved','occurrenceId',leg.id);RAISE SQLSTATE 'ZX002';END IF;
 earliest:=greatest(leg.departure_utc,ready)+make_interval(mins=>leg.technical_minutes);
 IF airport IS DISTINCT FROM leg.origin_airport_key THEN cancellation_reason:='aircraft_at_wrong_airport';
 ELSIF earliest>leg.departure_utc+make_interval(mins=>p_max_delay_minutes) THEN cancellation_reason:='maximum_delay_exceeded';
 ELSIF earliest=leg.departure_utc THEN
  -- Delay absorbed by original schedule slack; remaining rotation is untouched.
  items:=items||jsonb_build_array(jsonb_build_object('occurrenceId',leg.id,'status','on_time_recovery_boundary','departureUtc',leg.departure_utc,'arrivalUtc',leg.arrival_utc,'delayMinutes',0));
  recovery_boundary:=true;EXIT;
 ELSE
  planned:=airlinerra_game.section9_preview_replacement_slot_pair_v1(leg.world_id,leg.origin_airport_key,leg.destination_airport_key,leg.configuration_id,leg.departure_stand_type,leg.arrival_stand_type,leg.departure_utc,leg.arrival_utc,earliest,leg.turnaround_minutes,p_max_delay_minutes);
  IF planned->>'status'='replacement_slot_pair_preview' THEN
   d:=(planned->>'departureUtc')::timestamptz;a:=(planned->>'arrivalUtc')::timestamptz;
   ready:=(planned->>'availableUtc')::timestamptz;
   INSERT INTO airlinerra_game.section9_replacement_slot_pairs_v1(occurrence_id,world_id,aircraft_inventory_id,original_departure_utc,original_arrival_utc,revised_departure_utc,revised_arrival_utc,available_utc)
   VALUES(leg.id,leg.world_id,leg.aircraft_inventory_id,leg.departure_utc,leg.arrival_utc,d,a,ready);
   INSERT INTO airlinerra_game.section9_dated_replacement_slots_v1(occurrence_id,world_id,airport_key,stand_type,direction,movement_utc,local_date,weekday,minute_of_day)
   SELECT leg.id,leg.world_id,m.airport_key,m.stand_type,m.direction,m.movement_utc,z.local_dt::date,(extract(isodow FROM z.local_dt)::int-1)::smallint,(extract(hour FROM z.local_dt)::int*60+(extract(minute FROM z.local_dt)::int/10)*10)::smallint
   FROM (VALUES(leg.origin_airport_key,leg.departure_stand_type,'departure',d),(leg.destination_airport_key,leg.arrival_stand_type,'arrival',a)) m(airport_key,stand_type,direction,movement_utc)
   JOIN airlinerra_game.section5_airport_operating_policy_v1 pol ON pol.world_id=leg.world_id AND pol.airport_key=m.airport_key
   CROSS JOIN LATERAL(SELECT m.movement_utc AT TIME ZONE pol.timezone_iana AS local_dt) z;
   GET DIAGNOSTICS n=ROW_COUNT;
   IF n<>2 THEN RAISE EXCEPTION 'ROTATION_PAIR_NOT_ATOMIC';END IF;
   delayed_count:=delayed_count+1;airport:=leg.destination_airport_key;
   items:=items||jsonb_build_array(jsonb_build_object('occurrenceId',leg.id,'status','delayed','departureUtc',d,'arrivalUtc',a,'availableUtc',ready,'delayMinutes',planned->'delayMinutes','technicalDelayMinutes',leg.technical_minutes));
  ELSE cancellation_reason:='maximum_delay_exceeded';
  END IF;
 END IF;
 IF cancellation_reason IS NOT NULL THEN
  cancelled:=airlinerra_game.section9_cancel_unflown_occurrence_v1(leg.id,cancellation_reason);
  IF cancelled->>'cancelled' IS DISTINCT FROM 'true' THEN
   blocker:=jsonb_build_object('status','rotation_cancellation_recovery_required','occurrenceId',leg.id,'reason',cancellation_reason,'cancellationResult',cancelled);
   RAISE SQLSTATE 'ZX002';
  END IF;
  cancelled_count:=cancelled_count+1;
  items:=items||jsonb_build_array(jsonb_build_object('occurrenceId',leg.id,'status','cancelled','reason',cancellation_reason,'aircraftAirportAfter',airport,'cancellation',cancelled));
 END IF;
 END LOOP;
 IF examined=0 OR (delayed_count=0 AND cancelled_count=0) THEN RAISE EXCEPTION 'ROTATION_NO_DISRUPTION_APPLIED';END IF;
 result:=jsonb_build_object('status','rotation_rescheduled','committed',true,'replayed',false,'delayedFlights',delayed_count,'cancelledFlights',cancelled_count,'examinedFlights',examined,'recoveredBeforeNextFlight',recovery_boundary,'flights',items,'weeklySchedulesRetained',true);
 INSERT INTO airlinerra_game.section9_rotation_reschedule_receipts_v1(root_occurrence_id,aircraft_inventory_id,result) VALUES(p_root,root.aircraft_inventory_id,result);
 EXCEPTION WHEN SQLSTATE 'ZX002' THEN
 RETURN blocker||jsonb_build_object('committed',false,'rotationRolledBack',true);
 END;
 RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_reschedule_disrupted_rotation_v1(uuid,integer) FROM PUBLIC,anon,authenticated,service_role;
