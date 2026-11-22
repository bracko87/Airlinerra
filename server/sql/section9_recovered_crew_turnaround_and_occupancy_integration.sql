CREATE OR REPLACE FUNCTION airlinerra_game.section9_capture_actual_turnaround_v1(p_airline uuid, p_physical text, p_event text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE f record;old record;key text;digest bytea;roll numeric;minutes int;delayed_cost numeric;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO old FROM airlinerra_game.section9_actual_turnaround_receipts_v1 WHERE physical_flight_id=p_physical;
 IF FOUND THEN
 IF old.airline_id<>p_airline OR old.arrival_event_id<>p_event THEN RAISE EXCEPTION 'TURNAROUND_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status','turnaround_already_recorded','actualMinutes',old.actual_minutes,'availableUtc',old.available_utc);END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_dynamic_turnaround_release_v1 WHERE world_id=1 AND capture_enabled) THEN RETURN jsonb_build_object('status','dynamic_turnaround_disabled');END IF;
 SELECT a.actual_event_utc,a.aircraft_inventory_id,o.id occurrence_id,o.turnaround_minutes,o.verified_passenger_seats,d.configuration_id,cardinality(b.cabin_member_ids)+b.external_cabin_count cabin_count,b.external_cabin_count,b.external_contract_reference,b.external_captain_count,b.external_first_officer_count INTO f
 FROM airlinerra_game.section9_operated_crew_bindings_v1 b
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=b.occurrence_id AND o.airline_id=b.airline_id
 JOIN airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 d ON d.physical_flight_id=b.physical_flight_id AND d.airline_id=b.airline_id AND d.departure_engine_event_id=b.departure_event_id
 JOIN airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 r ON r.physical_flight_id=d.physical_flight_id AND r.airline_id=d.airline_id AND r.aircraft_inventory_id=d.aircraft_inventory_id
 JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.engine_event_id=r.arrival_engine_event_id AND a.flight_occurrence_id=r.physical_flight_id AND a.airline_id=r.airline_id AND a.aircraft_inventory_id=r.aircraft_inventory_id AND a.phase='arrived' AND a.source_kind='signed_operated_game_flight_v1' AND a.schedule_id=o.schedule_id AND a.schedule_version=o.schedule_version AND a.weekly_entry=o.weekly_entry AND a.flight_local_date=o.flight_local_date AND a.origin_airport_key=o.origin_airport_key AND a.destination_airport_key=o.destination_airport_key
 WHERE b.airline_id=p_airline AND b.physical_flight_id=p_physical AND a.engine_event_id=p_event;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','turnaround_crew_or_arrival_evidence_missing');END IF;
 -- External cabin crew must have been bound at the verified departure; an offer or contract alone is insufficient.
 -- The immutable delayed approval is authoritative when the original
 -- contract has been replaced. Verify its actual bound manifest and signed
 -- movement pair using the same verifier as financial settlement.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approvals_v1 ap WHERE ap.physical_flight_id=p_physical) THEN
  BEGIN
   delayed_cost:=airlinerra_game.section9_bound_delayed_external_cost_v1(p_airline,p_physical,p_event);
   IF delayed_cost IS NULL THEN RETURN jsonb_build_object('status','delayed_turnaround_approval_unverified');END IF;
  EXCEPTION WHEN OTHERS THEN RETURN jsonb_build_object('status','delayed_turnaround_approval_unverified');END;
 ELSE
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_external_crew_contracts_v1 c WHERE c.physical_flight_id=p_physical)
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_external_crew_contracts_v1 c WHERE c.physical_flight_id=p_physical AND c.airline_id=p_airline AND c.occurrence_id=f.occurrence_id AND c.captains=f.external_captain_count AND c.first_officers=f.external_first_officer_count AND c.cabin_crew=f.external_cabin_count AND c.source_reference=f.external_contract_reference) THEN RETURN jsonb_build_object('status','mixed_crew_turnaround_pending');END IF;
 IF f.external_cabin_count+f.external_captain_count+f.external_first_officer_count>0 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_external_crew_contracts_v1 c WHERE c.physical_flight_id=p_physical AND c.airline_id=p_airline AND c.occurrence_id=f.occurrence_id AND c.captains=f.external_captain_count AND c.first_officers=f.external_first_officer_count AND c.cabin_crew=f.external_cabin_count AND c.source_reference=f.external_contract_reference) THEN RETURN jsonb_build_object('status','external_cabin_binding_missing');END IF;
 END IF;
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
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_actual_aircraft_occupancy_v2(p_airline uuid, p_aircraft uuid, p_now timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE blocks jsonb;u jsonb;c jsonb;
BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory WHERE airline_id=p_airline AND id=p_aircraft) THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_now IS NULL OR NOT isfinite(p_now) THEN RETURN jsonb_build_object('status','invalid_usage_window');END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('departureUtc',d.actual_event_utc,'arrivalUtc',coalesce(a.actual_event_utc,p_now),'availableUtc',CASE WHEN a.engine_event_id IS NULL THEN p_now ELSE coalesce(t.available_utc,a.actual_event_utc+make_interval(mins=>coalesce(o.turnaround_minutes,0))) END) ORDER BY d.actual_event_utc,d.engine_event_id),'[]') INTO blocks
 FROM airlinerra_game.section9_operated_flight_movements_v1 d
 LEFT JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.flight_occurrence_id=d.flight_occurrence_id AND a.airline_id=d.airline_id AND a.aircraft_inventory_id=d.aircraft_inventory_id AND a.phase='arrived' AND a.source_kind='signed_operated_game_flight_v1' AND a.schedule_id=d.schedule_id AND a.schedule_version=d.schedule_version AND a.weekly_entry=d.weekly_entry AND a.flight_local_date=d.flight_local_date AND a.origin_airport_key=d.origin_airport_key AND a.destination_airport_key=d.destination_airport_key AND a.actual_event_utc>d.actual_event_utc AND a.actual_event_utc<=p_now
 LEFT JOIN airlinerra_game.section9_actual_turnaround_receipts_v1 t ON t.physical_flight_id=d.flight_occurrence_id AND t.arrival_event_id=a.engine_event_id AND t.airline_id=d.airline_id AND t.aircraft_inventory_id=d.aircraft_inventory_id AND t.arrival_utc=a.actual_event_utc
 LEFT JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.schedule_id=d.schedule_id AND o.airline_id=d.airline_id AND o.aircraft_inventory_id=d.aircraft_inventory_id AND o.schedule_version=d.schedule_version AND o.flight_local_date=d.flight_local_date AND o.weekly_entry=d.weekly_entry
 WHERE d.airline_id=p_airline AND d.aircraft_inventory_id=p_aircraft AND d.world_id=1 AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1'
 AND d.actual_event_utc<p_now AND (a.engine_event_id IS NOT NULL OR EXISTS(SELECT 1 FROM airlinerra_game.section9_aircraft_current_position_v1 pos WHERE pos.aircraft_inventory_id=p_aircraft AND pos.airline_id=p_airline AND pos.location_status='in_flight' AND pos.current_flight_occurrence_id=d.flight_occurrence_id))
 AND coalesce(t.available_utc,a.actual_event_utc+make_interval(mins=>coalesce(o.turnaround_minutes,0)),p_now)>p_now-interval '24 hours';
 u:=airlinerra_game.section9_aircraft_usage_window_v2(p_now-interval '24 hours',blocks);
 c:=airlinerra_game.section9_game_airframe_condition_v1(p_airline,p_aircraft,p_now);
 IF u->>'status'<>'aircraft_usage_preview' OR c->>'conditionPct' IS NULL THEN RETURN jsonb_build_object('status','actual_reliability_unavailable');END IF;
 RETURN u||airlinerra_game.section9_utilization_reliability_v2((c->>'conditionPct')::numeric,(u->>'occupiedMinutes')::numeric)||jsonb_build_object('status','aircraft_reliability_preview','overloaded',((u->>'occupiedMinutes')::numeric>1080),'aircraftInventoryId',p_aircraft,'asOfUtc',p_now,'utilizationBasis','rolling_24h_flight_plus_game_turnaround','readOnly',true,'ledgerPosted',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_delayed_turnaround_clear_v1(p_aircraft uuid, p_occurrence uuid, p_departure timestamp with time zone)
 RETURNS boolean
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
 SELECT (NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_dynamic_turnaround_release_v1 WHERE world_id=1 AND dispatch_effects_enabled) OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_actual_turnaround_receipts_v1 t WHERE t.aircraft_inventory_id=p_aircraft AND t.occurrence_id<>p_occurrence AND t.arrival_utc<=p_departure AND t.available_utc>p_departure)) AND NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1 p
  JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=p.occurrence_id
  LEFT JOIN airlinerra_game.section9_operated_flight_movements_v1 arr ON arr.flight_occurrence_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text AND arr.phase='arrived' AND arr.source_kind='signed_operated_game_flight_v1' AND arr.airline_id=o.airline_id AND arr.aircraft_inventory_id=o.aircraft_inventory_id AND arr.schedule_id=o.schedule_id AND arr.schedule_version=o.schedule_version AND arr.flight_local_date=o.flight_local_date AND arr.weekly_entry=o.weekly_entry AND arr.origin_airport_key=o.origin_airport_key AND arr.destination_airport_key=o.destination_airport_key
  LEFT JOIN airlinerra_game.section9_actual_turnaround_receipts_v1 t ON t.physical_flight_id=arr.flight_occurrence_id AND t.arrival_event_id=arr.engine_event_id AND t.airline_id=o.airline_id AND t.aircraft_inventory_id=o.aircraft_inventory_id AND t.occurrence_id=o.id AND t.arrival_utc=arr.actual_event_utc AND EXISTS(SELECT 1 FROM airlinerra_game.section9_dynamic_turnaround_release_v1 WHERE world_id=1 AND dispatch_effects_enabled)
  WHERE p.aircraft_inventory_id=p_aircraft AND p.occurrence_id<>p_occurrence AND o.booking_status<>'cancelled'
   AND p_departure>=p.original_departure_utc
   AND (p_departure<coalesce(t.available_utc,arr.actual_event_utc+make_interval(mins=>o.turnaround_minutes),p.available_utc)
    OR arr.engine_event_id IS NULL)
 );
$function$;