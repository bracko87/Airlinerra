-- ROLLBACK-ONLY REVIEW. Merge signed ferry duties with actual commercial duty history.
-- This is a read-only adapter. It does not change employee base checkpoints,
-- release reservations, replace a live function, or authorize dispatch.
BEGIN;
CREATE FUNCTION airlinerra_game.storage_crew_combined_history_preview_v1(p_airline uuid,p_employee uuid,p_at timestamptz,p_initial_airport text,p_location_effective timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE commercial jsonb; ferry jsonb; merged jsonb; leg jsonb; ds timestamptz; de timestamptz; prior_end timestamptz; prior_airport text; ready_at timestamptz; pending boolean; unready boolean;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_airline IS NULL OR p_employee IS NULL OR p_at IS NULL OR NOT isfinite(p_at) OR p_initial_airport IS NULL OR btrim(p_initial_airport)='' OR p_location_effective IS NULL OR NOT isfinite(p_location_effective) OR p_location_effective>p_at THEN
  RETURN jsonb_build_object('status','combined_crew_checkpoint_invalid','availableForNewDuty',false,'historyIntegrated',false);
 END IF;
 commercial:=airlinerra_game.section9_crew_actual_history_v1(p_airline,p_employee,p_at);
 IF commercial->>'availableForNewDuty' IS DISTINCT FROM 'true' OR jsonb_typeof(commercial->'history') IS DISTINCT FROM 'array' THEN
  RETURN jsonb_build_object('status','combined_commercial_history_unverified','availableForNewDuty',false,'historyIntegrated',false);
 END IF;
 -- Pending flights and cancellations after reporting cannot be treated as
 -- completed duty. Keep those employees unavailable.
 SELECT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 c
 LEFT JOIN airlinerra_game.aircraft_storage_crew_duty_receipts_v1 d ON d.request_id=c.request_id AND d.employee_id=c.employee_id AND d.airline_id=c.airline_id
 JOIN airlinerra_game.aircraft_storage_relocation_requests_v1 r ON r.id=c.request_id AND r.airline_id=c.airline_id
 WHERE c.airline_id=p_airline AND c.employee_id=p_employee AND c.status<>'cancelled'
 AND (r.status<>'completed' OR d.arrival_engine_event_id IS NULL OR d.completed_duty_end_utc IS NULL OR d.completed_duty_end_utc>p_at)) INTO pending;
 IF pending THEN RETURN jsonb_build_object('status','combined_storage_duty_pending','availableForNewDuty',false,'historyIntegrated',false);END IF;
 -- Match the receipts against immutable signed movement identity and the
 -- original crew reservation, not just a supplied airport or end timestamp.
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 d
 JOIN airlinerra_game.aircraft_storage_crew_reservations_v1 c ON c.request_id=d.request_id AND c.employee_id=d.employee_id
 LEFT JOIN airlinerra_game.section9_operated_flight_movements_v1 dep ON dep.engine_event_id=d.departure_engine_event_id
 LEFT JOIN airlinerra_game.section9_operated_flight_movements_v1 arr ON arr.engine_event_id=d.arrival_engine_event_id
 WHERE d.airline_id=p_airline AND d.employee_id=p_employee AND
 (c.airline_id IS DISTINCT FROM d.airline_id OR c.status='cancelled' OR dep.phase IS DISTINCT FROM 'departed' OR arr.phase IS DISTINCT FROM 'arrived'
 OR dep.storage_request_id IS DISTINCT FROM d.request_id OR arr.storage_request_id IS DISTINCT FROM d.request_id
 OR dep.airline_id IS DISTINCT FROM d.airline_id OR arr.airline_id IS DISTINCT FROM d.airline_id
 OR dep.flight_occurrence_id IS DISTINCT FROM arr.flight_occurrence_id OR dep.aircraft_inventory_id IS DISTINCT FROM arr.aircraft_inventory_id
 OR dep.origin_airport_key IS DISTINCT FROM d.origin_airport_key OR arr.destination_airport_key IS DISTINCT FROM d.destination_airport_key
 OR dep.destination_airport_key IS DISTINCT FROM d.destination_airport_key OR arr.origin_airport_key IS DISTINCT FROM d.origin_airport_key
 OR dep.actual_event_utc IS DISTINCT FROM d.actual_departure_utc OR arr.actual_event_utc IS DISTINCT FROM d.actual_arrival_utc
 OR c.duty_start_utc IS DISTINCT FROM d.reported_duty_start_utc OR c.origin_airport_key IS DISTINCT FROM d.origin_airport_key OR c.destination_airport_key IS DISTINCT FROM d.destination_airport_key
 OR d.completed_duty_end_utc IS NULL OR d.rest_complete_utc IS NULL OR d.completed_duty_end_utc<d.actual_arrival_utc OR d.rest_complete_utc<d.completed_duty_end_utc+interval '12 hours'))
 THEN RETURN jsonb_build_object('status','combined_storage_receipt_mismatch','availableForNewDuty',false,'historyIntegrated',false);END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('startUtc',d.reported_duty_start_utc,'endUtc',d.completed_duty_end_utc,'origin',d.origin_airport_key,'destination',d.destination_airport_key) ORDER BY d.reported_duty_start_utc,d.request_id),'[]'::jsonb)
 INTO ferry FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 d WHERE d.airline_id=p_airline AND d.employee_id=p_employee AND d.completed_duty_end_utc<=p_at;
 SELECT coalesce(jsonb_agg(v ORDER BY (v->>'startUtc')::timestamptz,(v->>'endUtc')::timestamptz),'[]'::jsonb) INTO merged
 FROM jsonb_array_elements((commercial->'history')||ferry) a(v);
 IF jsonb_array_length(merged)>366 THEN RETURN jsonb_build_object('status','combined_crew_history_requires_sharding','availableForNewDuty',false,'historyIntegrated',false);END IF;
 prior_airport:=p_initial_airport;
 FOR leg IN SELECT value FROM jsonb_array_elements(merged) LOOP
  ds:=(leg->>'startUtc')::timestamptz;de:=(leg->>'endUtc')::timestamptz;
  IF ds IS NULL OR de IS NULL OR NOT isfinite(ds) OR NOT isfinite(de) OR ds<p_location_effective OR de>p_at OR de<=ds OR de-ds>interval '12 hours'
   OR leg->>'origin' IS DISTINCT FROM prior_airport OR nullif(btrim(leg->>'destination'),'') IS NULL
   OR (prior_end IS NOT NULL AND ds<prior_end+interval '12 hours') THEN
   RETURN jsonb_build_object('status','combined_crew_history_conflict','availableForNewDuty',false,'historyIntegrated',false);
  END IF;
  prior_end:=de;prior_airport:=leg->>'destination';
 END LOOP;
 SELECT greatest(prior_end+interval '12 hours',max(rest_complete_utc)) INTO ready_at
 FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE airline_id=p_airline AND employee_id=p_employee;
 unready:=coalesce(ready_at>p_at,false);
 RETURN jsonb_build_object('status','combined_crew_history_preview','history',merged,'lastAirport',prior_airport,'lastDutyEndUtc',prior_end,'nextReadyUtc',ready_at,
 'restComplete',NOT unready,'eligibleByHistory',NOT unready,'availableForNewDuty',false,'historyIntegrated',false,'dispatchAuthorized',false,'storageDutyCount',jsonb_array_length(ferry),'commercialDutyCount',jsonb_array_length(commercial->'history'));
EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR invalid_text_representation OR invalid_parameter_value THEN
 RETURN jsonb_build_object('status','combined_crew_history_invalid','availableForNewDuty',false,'historyIntegrated',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_crew_combined_history_preview_v1(uuid,uuid,timestamptz,text,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
