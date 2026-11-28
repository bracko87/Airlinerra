-- ROLLBACK-ONLY REVIEW. Revalidate a promoted commercial duty at departure
-- using current roster and combined signed history. Multi-leg rotations require
-- an exact signed prefix and an independently reconstructed full duty. Existing commercial departure guard remains unconditional.
BEGIN;
CREATE FUNCTION airlinerra_game.storage_commercial_crew_departure_readiness_v1(p_airline uuid,p_physical text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE f record;r record;seat record;model record;owner_id uuid;now_utc timestamptz;roster jsonb;member jsonb;h jsonb;rot jsonb;assignment jsonb;coverage jsonb;n int;nc int;nf int;na int;expected int;review_seats jsonb;actual_seats jsonb;prefix jsonb;duty_leg jsonb;history_at timestamptz;multileg boolean:=false;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT a.owner_player_id INTO owner_id FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active' WHERE a.id=p_airline AND a.world_id=1;
 IF NOT FOUND THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_owner_invalid');END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 SELECT pf.* INTO STRICT f FROM airlinerra_game.section9_planned_flight_crews_v1 pf
 JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.airline_id=pf.airline_id AND b.status='validated_preview'
 JOIN airlinerra_game.storage_crew_plan_handoffs_v1 h ON h.plan_id=pf.plan_id AND h.airline_id=pf.airline_id
 WHERE pf.airline_id=p_airline AND pf.physical_flight_id=p_physical;
 IF now_utc IS NULL OR NOT isfinite(now_utc) OR now_utc<f.departure_utc OR now_utc>=f.departure_utc+interval '10 minutes' THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_departure_window_invalid');END IF;
 SELECT * INTO STRICT r FROM airlinerra_game.storage_aware_crew_plan_reviews_v1 WHERE plan_id=f.plan_id AND airline_id=p_airline;
 SELECT pol.* INTO STRICT model FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.aircraft_inventory_id=o.aircraft_inventory_id AND s.version=o.schedule_version AND s.status='active'
 JOIN airlinerra_game.section9_flight_crew_model_policy_v1 pol ON pol.configuration_id=s.configuration_id AND pol.qualification_group=f.qualification_group
 JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=o.aircraft_inventory_id AND i.airline_id=o.airline_id AND i.configuration_id=s.configuration_id AND i.fleet_status='in_service'
 WHERE o.id=f.occurrence_id AND o.airline_id=p_airline AND o.world_id=1 AND o.booking_status<>'cancelled'
 AND o.schedule_version=f.schedule_version AND o.aircraft_inventory_id=f.aircraft_inventory_id AND o.departure_utc=f.departure_utc AND o.arrival_utc=f.arrival_utc
 AND o.origin_airport_key=f.origin_airport_key AND o.destination_airport_key=f.destination_airport_key
 AND o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text=p_physical
 AND f.cabin_count=CASE WHEN pol.seat_basis='cargo_zero' OR o.verified_passenger_seats<=19 THEN 0 ELSE (o.verified_passenger_seats+49)/50 END;
 SELECT value INTO STRICT assignment FROM jsonb_array_elements(r.assignments) WHERE value->>'flightId'=f.occurrence_id::text;
 IF assignment->>'aircraftId' IS DISTINCT FROM f.aircraft_inventory_id::text OR (assignment->>'departureUtc')::timestamptz IS DISTINCT FROM f.departure_utc OR (assignment->>'arrivalUtc')::timestamptz IS DISTINCT FROM f.arrival_utc THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_assignment_changed');END IF;
 rot:=airlinerra_game.section9_crew_rotation_window_v2(jsonb_build_array(jsonb_build_object('originAirportKey',f.origin_airport_key,'destinationAirportKey',f.destination_airport_key,'departureUtc',to_char(f.departure_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'arrivalUtc',to_char(f.arrival_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'))));
 IF rot->>'status' IS DISTINCT FROM 'rotation_preview' THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_rotation_invalid');END IF;
 expected:=CASE WHEN f.arrival_utc-f.departure_utc>interval '6 hours' THEN 2 ELSE 1 END;
 SELECT count(*),count(*) FILTER(WHERE seat_role='captain'),count(*) FILTER(WHERE seat_role='first_officer'),count(*) FILTER(WHERE seat_role='cabin'),
 coalesce(jsonb_agg(jsonb_build_object('employeeId',employee_id::text,'role',seat_role) ORDER BY employee_id::text),'[]'::jsonb)
 INTO n,nc,nf,na,actual_seats FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=f.plan_id AND airline_id=p_airline AND occurrence_id=f.occurrence_id;
 SELECT coalesce(jsonb_agg(jsonb_build_object('employeeId',id,'role',role) ORDER BY id),'[]'::jsonb) INTO review_seats FROM
 (SELECT jsonb_array_elements_text(assignment->'captains') id,'captain' role UNION ALL SELECT jsonb_array_elements_text(assignment->'firstOfficers'),'first_officer' UNION ALL SELECT jsonb_array_elements_text(assignment->'cabinCrew'),'cabin') seats;
 IF nc<>expected OR nf<>expected OR nc<>f.captain_count OR nf<>f.first_officer_count OR na<>f.cabin_count OR n<>nc+nf+na OR actual_seats IS DISTINCT FROM review_seats
 OR n<>(SELECT count(DISTINCT v->>'employeeId') FROM jsonb_array_elements(actual_seats) a(v))
 THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_manifest_changed');END IF;
 coverage:=airlinerra_game.storage_rolling_crew_coverage_v1(p_airline,now_utc);
 IF coverage->>'coverageVerified' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_history_coverage_blocked');END IF;
 roster:=airlinerra_game.section9_owned_weekly_crew_input_v1(owner_id,p_airline,now_utc);
 IF roster->>'status' IS DISTINCT FROM 'weekly_crew_bootstrap_input_preview' OR roster->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' OR roster->>'invalidOccurrenceCount' IS DISTINCT FROM '0' OR jsonb_typeof(roster->'pilots') IS DISTINCT FROM 'array' OR jsonb_typeof(roster->'cabinMembers') IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_roster_unverified');END IF;
 FOR seat IN SELECT s.employee_id,s.seat_role,s.duty_id,d.duty_start_utc,d.duty_end_utc,d.starting_airport,d.ending_airport FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id AND d.airline_id=s.airline_id AND d.employee_id=s.employee_id WHERE s.plan_id=f.plan_id AND s.occurrence_id=f.occurrence_id AND s.airline_id=p_airline LOOP
  prefix:=airlinerra_game.storage_commercial_rotation_prefix_v1(p_airline,f.plan_id,seat.duty_id,seat.employee_id,f.occurrence_id);
  IF prefix->>'passed' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('passed',false,'status',prefix->>'status');END IF;
  rot:=prefix->'rotation';
  multileg:=multileg OR (prefix->>'legCount')::int>1;
  history_at:=CASE WHEN (prefix->>'priorLegCount')::int>0 THEN seat.duty_start_utc ELSE now_utc END;
  IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_duties_v1 pd JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pd.plan_id AND b.airline_id=pd.airline_id AND b.status='validated_preview' WHERE pd.airline_id=p_airline AND pd.employee_id=seat.employee_id AND pd.duty_id<>seat.duty_id AND pd.duty_start_utc<seat.duty_end_utc+interval '12 hours' AND pd.duty_end_utc>seat.duty_start_utc-interval '12 hours') THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_conflicting_duty');END IF;
  SELECT count(*) INTO n FROM jsonb_array_elements((roster->'pilots')||(roster->'cabinMembers')) a(v) WHERE v->>'id'=seat.employee_id::text;
  IF n<>1 THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_employee_changed');END IF;
  SELECT value INTO STRICT member FROM jsonb_array_elements(CASE WHEN seat.seat_role='cabin' THEN roster->'cabinMembers' ELSE roster->'pilots' END) WHERE value->>'id'=seat.employee_id::text;
  IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 c LEFT JOIN airlinerra_game.aircraft_storage_crew_duty_receipts_v1 d ON d.request_id=c.request_id AND d.employee_id=c.employee_id AND d.airline_id=c.airline_id WHERE c.airline_id=p_airline AND c.employee_id=seat.employee_id AND c.status<>'cancelled' AND (c.status<>'awaiting_history_handoff' OR d.rest_complete_utc IS NULL OR d.rest_complete_utc>seat.duty_start_utc OR airlinerra_game.storage_signed_crew_departure_covered_v1(p_airline,d.departure_engine_event_id) IS DISTINCT FROM true)) THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_storage_custody_unverified');END IF;
  h:=airlinerra_game.storage_crew_combined_history_preview_v1(p_airline,seat.employee_id,history_at,member->>'initialAirport',(member->>'locationEffectiveUtc')::timestamptz);
  IF h->>'status' IS DISTINCT FROM 'combined_crew_history_preview' OR h->>'eligibleByHistory' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_current_duty_fit_failed');END IF;
  -- The signed prefix is part of this rotation, not a second completed duty.
  -- Recheck the full duty against history at original report for continuation.
  FOR duty_leg IN SELECT value FROM jsonb_array_elements(prefix->'legs') LOOP
   IF airlinerra_game.aircraft_storage_crew_candidate_fit_v1(jsonb_set(member,'{history}',h->'history'),rot,duty_leg->>'qualificationGroup',duty_leg->>'seatRole') IS DISTINCT FROM true THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_current_duty_fit_failed');END IF;
  END LOOP;
 END LOOP;
 IF (SELECT count(*) FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id AND d.airline_id=s.airline_id AND d.employee_id=s.employee_id WHERE s.plan_id=f.plan_id AND s.occurrence_id=f.occurrence_id AND s.airline_id=p_airline)<>nc+nf+na THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_duty_missing');END IF;
 RETURN jsonb_build_object('passed',true,'status',CASE WHEN multileg THEN 'commercial_handoff_multileg_revalidated' ELSE 'commercial_handoff_single_leg_revalidated' END,'crewCount',nc+nf+na,'dispatchAuthorized',false,'crewReleased',false);
EXCEPTION WHEN no_data_found OR too_many_rows OR invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow OR invalid_parameter_value THEN RETURN jsonb_build_object('passed',false,'status','commercial_handoff_evidence_invalid');
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_commercial_crew_departure_readiness_v1(uuid,text) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
