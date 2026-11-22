-- Parenthesize JSON extraction before concatenation to preserve employee arrays.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_save_owned_crew_plan_preview_v1(p_player uuid, p_airline uuid, p_plan uuid, p_start timestamp with time zone, p_snapshot jsonb, p_assignments jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE snap jsonb;old record;f record;item jsonb;member jsonb;emp jsonb;legs jsonb;rotation jsonb;prior_history jsonb;fit jsonb;d record;duty uuid;emp_id uuid;role_name text;required int;now_utc timestamptz;report_at timestamptz;count_f int:=0;failure text;ids jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_plan IS NULL OR p_start IS NULL OR p_snapshot IS NULL OR jsonb_typeof(p_assignments) IS DISTINCT FROM 'array' THEN RAISE EXCEPTION USING ERRCODE='22023';END IF;
 SELECT * INTO old FROM airlinerra_game.section9_crew_plan_batches_v1 WHERE plan_id=p_plan AND airline_id=p_airline;
 IF FOUND THEN
 IF old.source_snapshot<>p_snapshot OR old.proposed_assignments<>p_assignments OR old.window_start_utc<>p_start THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='CREW_PLAN_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status',old.status,'planId',p_plan,'replayed',true,'dispatchEnforced',false);
 END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF p_start<now_utc OR p_start>now_utc+interval '7 days' THEN RETURN jsonb_build_object('status','crew_plan_window_invalid');END IF;
 snap:=airlinerra_game.section9_owned_weekly_crew_input_v1(p_player,p_airline,p_start);
 IF snap IS DISTINCT FROM p_snapshot THEN RETURN jsonb_build_object('status','crew_plan_snapshot_changed');END IF;
 IF snap->>'invalidOccurrenceCount' IS DISTINCT FROM '0' OR snap->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','crew_plan_input_unreconciled');END IF;
 IF jsonb_array_length(p_assignments) NOT BETWEEN 1 AND 2000 OR jsonb_array_length(p_assignments)<>jsonb_array_length(snap->'flights') THEN RETURN jsonb_build_object('status','crew_plan_incomplete');END IF;
 -- Live history is not yet integrated. Never replace a duty that has begun.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_duties_v1 pd JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pd.plan_id WHERE b.airline_id=p_airline AND b.status='validated_preview' AND pd.duty_start_utc<=now_utc)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_pilot_departure_manifests_v1 WHERE airline_id=p_airline)
 THEN RETURN jsonb_build_object('status','live_duty_history_required');END IF;
 BEGIN
 UPDATE airlinerra_game.section9_crew_plan_batches_v1 SET status='superseded' WHERE airline_id=p_airline AND status='validated_preview';
 INSERT INTO airlinerra_game.section9_crew_plan_batches_v1(plan_id,airline_id,window_start_utc,window_end_utc,source_snapshot,proposed_assignments,status)
 VALUES(p_plan,p_airline,p_start,p_start+interval '168 hours',snap,p_assignments,'validated_preview');
 -- Store each flight using only current trusted occurrence data.
 FOR item IN SELECT value FROM jsonb_array_elements(p_assignments) LOOP
 SELECT o.*,s.configuration_id,pol.qualification_group,pol.maximum_cabin_crew,pol.seat_basis INTO f
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.aircraft_inventory_id=o.aircraft_inventory_id AND s.version=o.schedule_version AND s.status='active'
 JOIN airlinerra_game.section9_flight_crew_model_policy_v1 pol ON pol.configuration_id=s.configuration_id
 WHERE o.id=(item->>'flightId')::uuid AND o.airline_id=p_airline AND o.world_id=1 AND o.departure_utc>=p_start AND o.departure_utc<p_start+interval '168 hours' AND o.booking_status<>'cancelled';
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_occurrence_invalid';END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(snap->'flights') x WHERE x->>'id'=f.id::text) OR item->>'aircraftId' IS DISTINCT FROM f.aircraft_inventory_id::text OR (item->>'departureUtc')::timestamptz IS DISTINCT FROM f.departure_utc OR (item->>'arrivalUtc')::timestamptz IS DISTINCT FROM f.arrival_utc THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_occurrence_mismatch';END IF;
 required:=CASE WHEN f.arrival_utc-f.departure_utc>interval '6 hours' THEN 2 ELSE 1 END;
 IF jsonb_typeof(item->'captains') IS DISTINCT FROM 'array' OR jsonb_typeof(item->'firstOfficers') IS DISTINCT FROM 'array' OR jsonb_typeof(item->'cabinCrew') IS DISTINCT FROM 'array' OR jsonb_typeof(item->'duties') IS DISTINCT FROM 'array' THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_invalid_manifest';END IF;
 IF jsonb_array_length(item->'captains')<>required OR jsonb_array_length(item->'firstOfficers')<>required OR jsonb_array_length(item->'cabinCrew')<>(CASE WHEN f.seat_basis='cargo_zero' OR f.verified_passenger_seats<=19 THEN 0 ELSE (f.verified_passenger_seats+49)/50 END) THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_wrong_staff_count';END IF;
 ids:=(item->'captains')||(item->'firstOfficers')||(item->'cabinCrew');
 IF jsonb_array_length(ids)<>(SELECT count(DISTINCT value) FROM jsonb_array_elements(ids)) OR jsonb_array_length(ids)<>jsonb_array_length(item->'duties') THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_duplicate_employee';END IF;
 INSERT INTO airlinerra_game.section9_planned_flight_crews_v1(plan_id,airline_id,occurrence_id,schedule_version,aircraft_inventory_id,physical_flight_id,qualification_group,departure_utc,arrival_utc,origin_airport_key,destination_airport_key,captain_count,first_officer_count,cabin_count)
 VALUES(p_plan,p_airline,f.id,f.schedule_version,f.aircraft_inventory_id,f.schedule_id||':'||f.flight_local_date||':'||f.weekly_entry,f.qualification_group,f.departure_utc,f.arrival_utc,f.origin_airport_key,f.destination_airport_key,required,required,jsonb_array_length(item->'cabinCrew'));
 count_f:=count_f+1;
 END LOOP;
 -- Validate each distinct employee and reconstruct entire rotations from legs;
 -- the caller's proposed duty end is not trusted.
 FOR d IN SELECT DISTINCT (x->>'employeeId')::uuid employee FROM jsonb_array_elements(p_assignments) j CROSS JOIN LATERAL jsonb_array_elements(j->'duties') x LOOP
 emp_id:=d.employee;
 SELECT value INTO emp FROM jsonb_array_elements((snap->'pilots')||(snap->'cabinMembers')) WHERE value->>'id'=emp_id::text;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_employee_unavailable';END IF;
 prior_history:='[]';
 FOR report_at IN SELECT DISTINCT (x->>'dutyStartUtc')::timestamptz FROM jsonb_array_elements(p_assignments) j CROSS JOIN LATERAL jsonb_array_elements(j->'duties') x WHERE x->>'employeeId'=emp_id::text ORDER BY 1 LOOP
 SELECT jsonb_agg(jsonb_build_object('departureUtc',to_char(flight.departure_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'arrivalUtc',to_char(flight.arrival_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'originAirportKey',flight.origin_airport_key,'destinationAirportKey',flight.destination_airport_key) ORDER BY flight.departure_utc,flight.occurrence_id) INTO legs
 FROM jsonb_array_elements(p_assignments) j CROSS JOIN LATERAL jsonb_array_elements(j->'duties') x JOIN airlinerra_game.section9_planned_flight_crews_v1 flight ON flight.plan_id=p_plan AND flight.occurrence_id=(j->>'flightId')::uuid
 WHERE x->>'employeeId'=emp_id::text AND (x->>'dutyStartUtc')::timestamptz=report_at;
 rotation:=airlinerra_game.section9_crew_rotation_window_v2(legs);
 IF rotation->>'status'<>'rotation_preview' OR (rotation->>'dutyStartUtc')::timestamptz<>report_at OR report_at<now_utc OR report_at<(emp->>'locationEffectiveUtc')::timestamptz OR (report_at AT TIME ZONE (emp->>'baseTimezone'))::date<(emp->>'employmentFrom')::date THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_invalid_duty';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(emp->'absences','[]')) a WHERE (a->>'startUtc')::timestamptz<(rotation->>'dutyEndUtc')::timestamptz AND (a->>'endUtc')::timestamptz>report_at) THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_employee_absent';END IF;
 fit:=airlinerra_game.section9_crew_duty_fit_v2(rotation,prior_history,emp->>'baseTimezone',emp->>'initialAirport');
 IF fit->>'eligible'<>'true' THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_'||(fit->>'status');END IF;
 prior_history:=prior_history||jsonb_build_array(rotation);
 INSERT INTO airlinerra_game.section9_planned_crew_duties_v1(plan_id,airline_id,pilot_id,cabin_member_id,duty_start_utc,duty_end_utc,report_date,starting_airport,ending_airport)
 VALUES(p_plan,p_airline,CASE WHEN emp?'permissions' THEN emp_id END,CASE WHEN NOT emp?'permissions' THEN emp_id END,report_at,(rotation->>'dutyEndUtc')::timestamptz,(report_at AT TIME ZONE (emp->>'baseTimezone'))::date,rotation->>'startingAirport',rotation->>'endingAirport') RETURNING duty_id INTO duty;
 FOR member IN SELECT jsonb_build_object('flight',j,'assignment',x) FROM jsonb_array_elements(p_assignments) j CROSS JOIN LATERAL jsonb_array_elements(j->'duties') x WHERE x->>'employeeId'=emp_id::text AND (x->>'dutyStartUtc')::timestamptz=report_at LOOP
 item:=member->'flight'; role_name:=member->'assignment'->>'role';
 SELECT * INTO STRICT f FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE plan_id=p_plan AND occurrence_id=(item->>'flightId')::uuid;
 IF role_name NOT IN('captain','firstOfficer','cabin') OR role_name IS NULL THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_invalid_role';END IF;
 ids:=CASE role_name WHEN 'captain' THEN item->'captains' WHEN 'firstOfficer' THEN item->'firstOfficers' ELSE item->'cabinCrew' END;
 IF NOT ids?emp_id::text THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_manifest_mismatch';END IF;
 IF role_name='cabin' THEN
 IF emp?'permissions' OR emp->>'role' NOT IN('flight_attendant','cabin_supervisor','purser') THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_wrong_cabin_role';END IF;
 ELSE
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(emp->'permissions','[]')) q WHERE q->>'group'=f.qualification_group AND q->>'active'='true' AND q->>role_name='true' AND (q->>'issued')::date<=(f.departure_utc AT TIME ZONE (emp->>'baseTimezone'))::date AND (q->>'expires')::date>(f.arrival_utc AT TIME ZONE (emp->>'baseTimezone'))::date) THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_qualification_failed';END IF;
 END IF;
 INSERT INTO airlinerra_game.section9_planned_crew_seats_v1(plan_id,airline_id,occurrence_id,duty_id,employee_id,seat_role) VALUES(p_plan,p_airline,f.occurrence_id,duty,emp_id,CASE WHEN role_name='firstOfficer' THEN 'first_officer' ELSE role_name END);
 END LOOP;
 END LOOP;
 END LOOP;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_flight_crews_v1 pf WHERE pf.plan_id=p_plan AND (pf.captain_count<>(SELECT count(*) FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=pf.plan_id AND s.occurrence_id=pf.occurrence_id AND s.seat_role='captain') OR pf.first_officer_count<>(SELECT count(*) FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=pf.plan_id AND s.occurrence_id=pf.occurrence_id AND s.seat_role='first_officer') OR pf.cabin_count<>(SELECT count(*) FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=pf.plan_id AND s.occurrence_id=pf.occurrence_id AND s.seat_role='cabin'))) THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_incomplete_seats';END IF;
 EXCEPTION WHEN SQLSTATE 'ZX002' THEN GET STACKED DIAGNOSTICS failure=MESSAGE_TEXT;RETURN jsonb_build_object('status',failure,'saved',false);
 WHEN unique_violation OR invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow THEN RETURN jsonb_build_object('status','crew_plan_invalid_or_duplicate_data','saved',false);
 END;
 RETURN jsonb_build_object('status','validated_preview','planId',p_plan,'flightCount',count_f,'dutyCount',(SELECT count(*) FROM airlinerra_game.section9_planned_crew_duties_v1 WHERE plan_id=p_plan),'saved',true,'dispatchEnforced',false,'actualDutyHistoryIntegrated',false,'replayed',false);
END $function$
;
