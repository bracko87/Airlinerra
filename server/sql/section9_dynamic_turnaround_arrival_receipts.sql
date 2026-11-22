-- Phase 14H: bounded deterministic game turnaround, one receipt per arrival.
CREATE TABLE airlinerra_game.section9_dynamic_turnaround_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),capture_enabled boolean NOT NULL DEFAULT false,dispatch_effects_enabled boolean NOT NULL DEFAULT false,CHECK(NOT dispatch_effects_enabled OR capture_enabled)
);
INSERT INTO airlinerra_game.section9_dynamic_turnaround_release_v1 VALUES(1,false,false);
CREATE TABLE airlinerra_game.section9_actual_turnaround_receipts_v1(
 physical_flight_id text PRIMARY KEY REFERENCES airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1(physical_flight_id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 arrival_event_id text NOT NULL UNIQUE REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 occurrence_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.section9_dated_flight_occurrences_v1(id),
 configuration_id bigint NOT NULL,installed_seats int NOT NULL CHECK(installed_seats>=0),
 assigned_cabin_crew int NOT NULL CHECK(assigned_cabin_crew BETWEEN 0 AND 40),
 scheduled_minutes int NOT NULL CHECK(scheduled_minutes BETWEEN 0 AND 1440),
 actual_minutes int NOT NULL CHECK(actual_minutes BETWEEN 0 AND 1440),
 arrival_utc timestamptz NOT NULL,available_utc timestamptz NOT NULL,
 model text NOT NULL DEFAULT 'GAME_DYNAMIC_TURNAROUND_V1',
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(available_utc=arrival_utc+make_interval(mins=>actual_minutes))
);
CREATE INDEX section9_turnaround_receipt_aircraft_idx ON airlinerra_game.section9_actual_turnaround_receipts_v1(aircraft_inventory_id,arrival_utc DESC);
ALTER TABLE airlinerra_game.section9_dynamic_turnaround_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_actual_turnaround_receipts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_dynamic_turnaround_release_v1,airlinerra_game.section9_actual_turnaround_receipts_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.section9_sample_turnaround_minutes_v1(p_configuration bigint,p_seats int,p_cabin int,p_scheduled int,p_roll numeric)
RETURNS integer LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE v jsonb;lo int;hi int;mn int;mx int;staffing numeric;shape numeric;
BEGIN
 IF p_roll IS NULL OR p_roll<0 OR p_roll>=1 THEN RAISE EXCEPTION 'INVALID_TURNAROUND_ROLL';END IF;
 v:=airlinerra_game.section9_dynamic_turnaround_preview_v1(p_configuration,p_seats,p_cabin,p_scheduled);
 IF v->>'status'<>'dynamic_turnaround_preview' THEN RETURN NULL;END IF;
 lo:=(v->>'minimumTurnaroundMinutes')::int;hi:=(v->>'maximumTurnaroundMinutes')::int;
 mn:=(v->>'minimumCabinCrew')::int;mx:=(v->>'maximumCabinCrew')::int;
 staffing:=CASE WHEN mx=mn THEN 0.5 ELSE (p_cabin-mn)::numeric/(mx-mn) END;
 shape:=power(4::numeric,1-2*staffing);
 RETURN greatest(lo,least(hi,round(lo+(hi-lo)*power(p_roll,1/shape))::int));
END $$;
CREATE FUNCTION airlinerra_game.section9_capture_actual_turnaround_v1(p_airline uuid,p_physical text,p_event text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE f record;old record;key text;digest bytea;roll numeric;minutes int;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO old FROM airlinerra_game.section9_actual_turnaround_receipts_v1 WHERE physical_flight_id=p_physical;
 IF FOUND THEN
 IF old.airline_id<>p_airline OR old.arrival_event_id<>p_event THEN RAISE EXCEPTION 'TURNAROUND_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status','turnaround_already_recorded','actualMinutes',old.actual_minutes,'availableUtc',old.available_utc);END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_dynamic_turnaround_release_v1 WHERE world_id=1 AND capture_enabled) THEN RETURN jsonb_build_object('status','dynamic_turnaround_disabled');END IF;
 SELECT a.actual_event_utc,a.aircraft_inventory_id,o.id occurrence_id,o.turnaround_minutes,o.verified_passenger_seats,d.configuration_id,cardinality(b.cabin_member_ids) cabin_count INTO f
 FROM airlinerra_game.section9_operated_crew_bindings_v1 b
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=b.occurrence_id AND o.airline_id=b.airline_id
 JOIN airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 d ON d.physical_flight_id=b.physical_flight_id AND d.airline_id=b.airline_id AND d.departure_engine_event_id=b.departure_event_id
 JOIN airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 r ON r.physical_flight_id=d.physical_flight_id AND r.airline_id=d.airline_id AND r.aircraft_inventory_id=d.aircraft_inventory_id
 JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.engine_event_id=r.arrival_engine_event_id AND a.flight_occurrence_id=r.physical_flight_id AND a.airline_id=r.airline_id AND a.aircraft_inventory_id=r.aircraft_inventory_id AND a.phase='arrived' AND a.schedule_id=o.schedule_id AND a.schedule_version=o.schedule_version
 WHERE b.airline_id=p_airline AND b.physical_flight_id=p_physical AND a.engine_event_id=p_event;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','turnaround_crew_or_arrival_evidence_missing');END IF;
 -- Mixed external rosters are not yet bound. Do not count unauthorized contracts.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_external_crew_contracts_v1 WHERE physical_flight_id=p_physical) THEN RETURN jsonb_build_object('status','mixed_crew_turnaround_pending');END IF;
 SELECT decrypted_secret INTO key FROM vault.decrypted_secrets WHERE name='airlinerra_operated_flight_auto_signing_v1';
 IF key IS NULL OR length(key)<64 THEN RETURN jsonb_build_object('status','turnaround_seed_unavailable');END IF;
 digest:=extensions.hmac(convert_to('airlinerra-turnaround-v1:'||p_physical,'UTF8'),convert_to(key,'UTF8'),'sha256');
 roll:=(get_byte(digest,0)*65536+get_byte(digest,1)*256+get_byte(digest,2))::numeric/16777216;
 minutes:=airlinerra_game.section9_sample_turnaround_minutes_v1(f.configuration_id,f.verified_passenger_seats,f.cabin_count,f.turnaround_minutes,roll);
 IF minutes IS NULL THEN RETURN jsonb_build_object('status','turnaround_staffing_unverified');END IF;
 INSERT INTO airlinerra_game.section9_actual_turnaround_receipts_v1(physical_flight_id,airline_id,aircraft_inventory_id,arrival_event_id,occurrence_id,configuration_id,installed_seats,assigned_cabin_crew,scheduled_minutes,actual_minutes,arrival_utc,available_utc)
 VALUES(p_physical,p_airline,f.aircraft_inventory_id,p_event,f.occurrence_id,f.configuration_id,f.verified_passenger_seats,f.cabin_count,f.turnaround_minutes,minutes,f.actual_event_utc,f.actual_event_utc+make_interval(mins=>minutes)) ON CONFLICT(physical_flight_id) DO NOTHING;
 SELECT * INTO STRICT old FROM airlinerra_game.section9_actual_turnaround_receipts_v1 WHERE physical_flight_id=p_physical;
 RETURN jsonb_build_object('status','turnaround_recorded','actualMinutes',old.actual_minutes,'scheduledMinutes',old.scheduled_minutes,'availableUtc',old.available_utc,'excessMinutes',greatest(0,old.actual_minutes-old.scheduled_minutes));
END $$;
-- Rolling actual game occupancy, including the scheduled ground time where
-- no dynamic receipt exists; no double counting overlapping intervals.
CREATE FUNCTION airlinerra_game.section9_actual_aircraft_occupancy_v2(p_airline uuid,p_aircraft uuid,p_now timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE blocks jsonb;u jsonb;c jsonb;
BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory WHERE airline_id=p_airline AND id=p_aircraft) THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_now IS NULL OR NOT isfinite(p_now) THEN RETURN jsonb_build_object('status','invalid_usage_window');END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('departureUtc',d.actual_event_utc,'arrivalUtc',coalesce(a.actual_event_utc,p_now),'availableUtc',CASE WHEN a.engine_event_id IS NULL THEN p_now ELSE coalesce(t.available_utc,a.actual_event_utc+make_interval(mins=>coalesce(o.turnaround_minutes,0))) END) ORDER BY d.actual_event_utc,d.engine_event_id),'[]') INTO blocks
 FROM airlinerra_game.section9_operated_flight_movements_v1 d
 LEFT JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.flight_occurrence_id=d.flight_occurrence_id AND a.airline_id=d.airline_id AND a.aircraft_inventory_id=d.aircraft_inventory_id AND a.phase='arrived' AND a.actual_event_utc<=p_now
 LEFT JOIN airlinerra_game.section9_actual_turnaround_receipts_v1 t ON t.physical_flight_id=d.flight_occurrence_id AND t.arrival_event_id=a.engine_event_id
 LEFT JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.schedule_id=d.schedule_id AND o.airline_id=d.airline_id AND o.aircraft_inventory_id=d.aircraft_inventory_id AND o.schedule_version=d.schedule_version AND o.flight_local_date=d.flight_local_date AND o.weekly_entry=d.weekly_entry
 WHERE d.airline_id=p_airline AND d.aircraft_inventory_id=p_aircraft AND d.world_id=1 AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1'
 AND d.actual_event_utc<p_now AND (a.engine_event_id IS NOT NULL OR EXISTS(SELECT 1 FROM airlinerra_game.section9_aircraft_current_position_v1 pos WHERE pos.aircraft_inventory_id=p_aircraft AND pos.airline_id=p_airline AND pos.location_status='in_flight' AND pos.current_flight_occurrence_id=d.flight_occurrence_id))
 AND coalesce(t.available_utc,a.actual_event_utc+make_interval(mins=>coalesce(o.turnaround_minutes,0)),p_now)>p_now-interval '24 hours';
 u:=airlinerra_game.section9_aircraft_usage_window_v2(p_now-interval '24 hours',blocks);
 c:=airlinerra_game.section9_game_airframe_condition_v1(p_airline,p_aircraft,p_now);
 IF u->>'status'<>'aircraft_usage_preview' OR c->>'conditionPct' IS NULL THEN RETURN jsonb_build_object('status','actual_reliability_unavailable');END IF;
 RETURN u||airlinerra_game.section9_utilization_reliability_v2((c->>'conditionPct')::numeric,(u->>'occupiedMinutes')::numeric)||jsonb_build_object('status','aircraft_reliability_preview','overloaded',((u->>'occupiedMinutes')::numeric>1080),'aircraftInventoryId',p_aircraft,'asOfUtc',p_now,'utilizationBasis','rolling_24h_flight_plus_game_turnaround','readOnly',true,'ledgerPosted',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_sample_turnaround_minutes_v1(bigint,int,int,int,numeric),airlinerra_game.section9_capture_actual_turnaround_v1(uuid,text,text),airlinerra_game.section9_actual_aircraft_occupancy_v2(uuid,uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
