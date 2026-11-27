-- ROLLBACK-ONLY REVIEW. Reconstruct an exact employee's planned rotation
-- and verify the signed prefix before allowing a subsequent leg to be reviewed.
-- This is not a dispatch release or a replacement for commercial crew capture.
BEGIN;
CREATE FUNCTION airlinerra_game.storage_commercial_rotation_prefix_v1(p_airline uuid,p_plan uuid,p_duty uuid,p_employee uuid,p_occurrence uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE d record;f record;r record;leg record;rot jsonb;legs jsonb:='[]';assignment jsonb;role_key text;previous_arrival timestamptz;prior_count int:=0;current_count int:=0;total_count int:=0;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO STRICT d FROM airlinerra_game.section9_planned_crew_duties_v1 WHERE duty_id=p_duty AND plan_id=p_plan AND airline_id=p_airline AND employee_id=p_employee;
 SELECT * INTO STRICT f FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE plan_id=p_plan AND airline_id=p_airline AND occurrence_id=p_occurrence;
 SELECT * INTO STRICT r FROM airlinerra_game.storage_aware_crew_plan_reviews_v1 WHERE plan_id=p_plan AND airline_id=p_airline;
 FOR leg IN SELECT pf.*,s.seat_role,o.schedule_id,o.flight_local_date,o.weekly_entry
 FROM airlinerra_game.section9_planned_crew_seats_v1 s
 JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=s.plan_id AND pf.airline_id=s.airline_id AND pf.occurrence_id=s.occurrence_id
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=pf.occurrence_id AND o.airline_id=pf.airline_id AND o.world_id=1 AND o.booking_status<>'cancelled' AND o.schedule_version=pf.schedule_version AND o.aircraft_inventory_id=pf.aircraft_inventory_id AND o.departure_utc=pf.departure_utc AND o.arrival_utc=pf.arrival_utc AND o.origin_airport_key=pf.origin_airport_key AND o.destination_airport_key=pf.destination_airport_key
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 sd ON sd.id=o.schedule_id AND sd.airline_id=o.airline_id AND sd.aircraft_inventory_id=o.aircraft_inventory_id AND sd.version=o.schedule_version AND sd.status='active'
 JOIN airlinerra_game.section9_flight_crew_model_policy_v1 pol ON pol.configuration_id=sd.configuration_id AND pol.qualification_group=pf.qualification_group
 WHERE s.plan_id=p_plan AND s.airline_id=p_airline AND s.duty_id=p_duty AND s.employee_id=p_employee
 AND pf.physical_flight_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text
 ORDER BY pf.departure_utc,pf.occurrence_id LOOP
  total_count:=total_count+1;
  SELECT value INTO STRICT assignment FROM jsonb_array_elements(r.assignments) WHERE value->>'flightId'=leg.occurrence_id::text;
  role_key:=CASE leg.seat_role WHEN 'captain' THEN 'captains' WHEN 'first_officer' THEN 'firstOfficers' WHEN 'cabin' THEN 'cabinCrew' END;
  IF role_key IS NULL OR NOT coalesce((assignment->role_key)?p_employee::text,false) OR assignment->>'aircraftId' IS DISTINCT FROM leg.aircraft_inventory_id::text OR (assignment->>'departureUtc')::timestamptz IS DISTINCT FROM leg.departure_utc OR (assignment->>'arrivalUtc')::timestamptz IS DISTINCT FROM leg.arrival_utc
  OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(assignment->'duties') a(v) WHERE v->>'employeeId'=p_employee::text AND v->>'role'=CASE leg.seat_role WHEN 'first_officer' THEN 'firstOfficer' ELSE leg.seat_role END AND (v->>'dutyStartUtc')::timestamptz=d.duty_start_utc)
  THEN RETURN jsonb_build_object('passed',false,'status','commercial_rotation_assignment_changed');END IF;
  IF previous_arrival IS NOT NULL AND leg.departure_utc<previous_arrival+interval '30 minutes' THEN RETURN jsonb_build_object('passed',false,'status','commercial_rotation_turnaround_invalid');END IF;
  previous_arrival:=leg.arrival_utc;
  legs:=legs||jsonb_build_array(jsonb_build_object('originAirportKey',leg.origin_airport_key,'destinationAirportKey',leg.destination_airport_key,'departureUtc',to_char(leg.departure_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'arrivalUtc',to_char(leg.arrival_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'qualificationGroup',leg.qualification_group,'seatRole',leg.seat_role));
  IF leg.occurrence_id=p_occurrence THEN current_count:=current_count+1;
  ELSIF leg.departure_utc<f.departure_utc THEN
   -- Only an exact, on-time signed departure AND arrival bound to the same
   -- commercial plan and occurrence may continue this duty.
   IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_crew_bindings_v1 b
    JOIN airlinerra_game.section9_operated_flight_movements_v1 dep ON dep.engine_event_id=b.departure_event_id AND dep.airline_id=b.airline_id AND dep.flight_occurrence_id=b.physical_flight_id AND dep.phase='departed'
    JOIN airlinerra_game.section9_operated_flight_movements_v1 arr ON arr.airline_id=dep.airline_id AND arr.flight_occurrence_id=dep.flight_occurrence_id AND arr.aircraft_inventory_id=dep.aircraft_inventory_id AND arr.schedule_id=dep.schedule_id AND arr.schedule_version=dep.schedule_version AND arr.flight_local_date=dep.flight_local_date AND arr.weekly_entry=dep.weekly_entry AND arr.phase='arrived'
    WHERE b.airline_id=p_airline AND b.plan_id=p_plan AND b.occurrence_id=leg.occurrence_id AND b.physical_flight_id=leg.physical_flight_id
    AND dep.storage_request_id IS NULL AND arr.storage_request_id IS NULL
    AND dep.aircraft_inventory_id=leg.aircraft_inventory_id AND dep.schedule_id=leg.schedule_id AND dep.schedule_version=leg.schedule_version AND dep.flight_local_date=leg.flight_local_date AND dep.weekly_entry=leg.weekly_entry
    AND dep.origin_airport_key=leg.origin_airport_key AND dep.destination_airport_key=leg.destination_airport_key AND arr.origin_airport_key=leg.origin_airport_key AND arr.destination_airport_key=leg.destination_airport_key
    AND dep.actual_event_utc=leg.departure_utc AND arr.actual_event_utc=leg.arrival_utc AND arr.actual_event_utc+interval '30 minutes'<=f.departure_utc)
   THEN RETURN jsonb_build_object('passed',false,'status','commercial_rotation_prior_leg_unverified');END IF;
   prior_count:=prior_count+1;
  ELSE
   IF leg.departure_utc<=f.departure_utc OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.airline_id=p_airline AND m.flight_occurrence_id=leg.physical_flight_id) THEN RETURN jsonb_build_object('passed',false,'status','commercial_rotation_future_leg_invalid');END IF;
  END IF;
 END LOOP;
 IF current_count<>1 OR total_count<>(SELECT count(*) FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=p_plan AND airline_id=p_airline AND duty_id=p_duty AND employee_id=p_employee) THEN RETURN jsonb_build_object('passed',false,'status','commercial_rotation_coverage_incomplete');END IF;
 rot:=airlinerra_game.section9_crew_rotation_window_v2(legs);
 IF rot->>'status' IS DISTINCT FROM 'rotation_preview' OR (rot->>'dutyStartUtc')::timestamptz IS DISTINCT FROM d.duty_start_utc OR (rot->>'dutyEndUtc')::timestamptz IS DISTINCT FROM d.duty_end_utc OR rot->>'startingAirport' IS DISTINCT FROM d.starting_airport OR rot->>'endingAirport' IS DISTINCT FROM d.ending_airport
 OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(r.verified_duties) a(v) WHERE v->>'employeeId'=p_employee::text AND (v->>'dutyStartUtc')::timestamptz=d.duty_start_utc AND (v->>'dutyEndUtc')::timestamptz=d.duty_end_utc AND v->>'startingAirport'=d.starting_airport AND v->>'endingAirport'=d.ending_airport)
 THEN RETURN jsonb_build_object('passed',false,'status','commercial_rotation_review_changed');END IF;
 RETURN jsonb_build_object('passed',true,'status','commercial_rotation_prefix_verified','rotation',rot,'legs',legs,'priorLegCount',prior_count,'legCount',total_count,'dispatchAuthorized',false);
EXCEPTION WHEN no_data_found OR too_many_rows OR invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow OR invalid_parameter_value THEN RETURN jsonb_build_object('passed',false,'status','commercial_rotation_evidence_invalid');
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_commercial_rotation_prefix_v1(uuid,uuid,uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
