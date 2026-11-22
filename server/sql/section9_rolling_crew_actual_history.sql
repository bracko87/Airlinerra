-- Read actual completed legs from immutable signed movement evidence and the
-- departure-time crew binding. No mutation of employee starting locations.
CREATE FUNCTION airlinerra_game.section9_crew_actual_history_v1(p_airline uuid,p_employee uuid,p_start timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE legs jsonb;hist jsonb;last_airport text;last_end timestamptz;open_count int;invalid_count int;duty_count int;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_airline IS NULL OR p_employee IS NULL OR p_start IS NULL OR NOT isfinite(p_start) THEN RETURN jsonb_build_object('status','invalid_crew_history_request');END IF;
 WITH raw AS(
 SELECT ps.duty_id,pd.duty_start_utc,pd.starting_airport,pd.ending_airport,b.physical_flight_id,
 dep.actual_event_utc departed,dep.origin_airport_key,dep.destination_airport_key,arr.actual_event_utc arrived
 FROM airlinerra_game.section9_operated_crew_bindings_v1 b
 JOIN airlinerra_game.section9_planned_crew_seats_v1 ps ON ps.airline_id=b.airline_id AND ps.plan_id=b.plan_id AND ps.occurrence_id=b.occurrence_id AND ps.employee_id=p_employee
 JOIN airlinerra_game.section9_planned_crew_duties_v1 pd ON pd.duty_id=ps.duty_id AND pd.airline_id=ps.airline_id AND pd.employee_id=ps.employee_id
 JOIN airlinerra_game.section9_operated_flight_movements_v1 dep ON dep.engine_event_id=b.departure_event_id AND dep.airline_id=b.airline_id AND dep.phase='departed' AND dep.flight_occurrence_id=b.physical_flight_id
 LEFT JOIN airlinerra_game.section9_operated_flight_movements_v1 arr ON arr.flight_occurrence_id=b.physical_flight_id AND arr.airline_id=b.airline_id AND arr.phase='arrived' AND arr.aircraft_inventory_id=dep.aircraft_inventory_id AND arr.schedule_id=dep.schedule_id AND arr.schedule_version=dep.schedule_version AND arr.weekly_entry=dep.weekly_entry AND arr.flight_local_date=dep.flight_local_date AND arr.origin_airport_key=dep.origin_airport_key AND arr.destination_airport_key=dep.destination_airport_key
 WHERE b.airline_id=p_airline AND dep.actual_event_utc<p_start
 ), ordered AS(
 SELECT *,lag(destination_airport_key) OVER(PARTITION BY duty_id ORDER BY departed,physical_flight_id) prior_dest,lag(arrived) OVER(PARTITION BY duty_id ORDER BY departed,physical_flight_id) prior_arr FROM raw
 ), duties AS(
 SELECT duty_id,min(duty_start_utc) report_at,max(arrived)+interval '30 minutes' end_at,
 (array_agg(origin_airport_key ORDER BY departed,physical_flight_id))[1] origin,
 (array_agg(destination_airport_key ORDER BY departed DESC,physical_flight_id DESC))[1] destination,
 count(*) FILTER(WHERE arrived IS NULL OR arrived+interval '30 minutes'>p_start) open_legs,
 count(*) FILTER(WHERE departed<duty_start_utc OR arrived<=departed OR (prior_dest IS NOT NULL AND (prior_dest<>origin_airport_key OR prior_arr IS NULL OR prior_arr>departed))) invalid_legs
 FROM ordered GROUP BY duty_id
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('startUtc',report_at,'endUtc',end_at,'origin',origin,'destination',destination) ORDER BY report_at,duty_id) FILTER(WHERE open_legs=0 AND invalid_legs=0),'[]'),
 coalesce(sum(open_legs),0),coalesce(sum(invalid_legs),0),count(*) INTO hist,open_count,invalid_count,duty_count FROM duties;
 IF open_count>0 THEN RETURN jsonb_build_object('status','crew_in_flight_or_postflight','availableForNewDuty',false,'history',hist);END IF;
 IF invalid_count>0 OR duty_count>366 THEN RETURN jsonb_build_object('status','crew_history_requires_review','availableForNewDuty',false,'history',hist);END IF;
 -- The duty report time is the validated scheduled report, not a clock-in.
 -- Actual arrival (plus the agreed 30-minute postflight) determines rest.
 IF jsonb_array_length(hist)>0 THEN
 last_airport:=hist->-1->>'destination';last_end:=(hist->-1->>'endUtc')::timestamptz;
 END IF;
 RETURN jsonb_build_object('status','crew_completed_duty_history','availableForNewDuty',true,'history',hist,'lastAirport',last_airport,'lastDutyEndUtc',last_end,'reportTimeBasis','planned_report_actual_arrival','verifiedClockIn',false);
END $$;
-- Owner-scoped rolling planning input. Future schedules are still a preview:
-- unbound commercial movements and missing coverage prohibit live automation.
CREATE FUNCTION airlinerra_game.section9_owned_rolling_crew_input_v1(p_player uuid,p_airline uuid,p_start timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE base jsonb;member jsonb;h jsonb;pilots jsonb:='[]';cabin jsonb:='[]';excluded jsonb:='[]';issues int;unbound int;ongoing int;previous jsonb;now_utc timestamptz;
BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF p_start IS NULL OR NOT isfinite(p_start) OR p_start<now_utc OR p_start>now_utc+interval '7 days' THEN RETURN jsonb_build_object('status','rolling_crew_window_invalid');END IF;
 base:=airlinerra_game.section9_owned_weekly_crew_input_v1(p_player,p_airline,p_start);
 IF base->>'status'<>'weekly_crew_bootstrap_input_preview' THEN RETURN base;END IF;
 FOR member IN SELECT value FROM jsonb_array_elements((base->'pilots')||(base->'cabinMembers')) LOOP
 h:=airlinerra_game.section9_crew_actual_history_v1(p_airline,(member->>'id')::uuid,now_utc);
 IF h->>'availableForNewDuty' IS DISTINCT FROM 'true' THEN excluded:=excluded||jsonb_build_array(jsonb_build_object('employeeId',member->>'id','status',h->>'status'));CONTINUE;END IF;
 member:=jsonb_set(member,'{history}',h->'history');
 IF member?'permissions' THEN pilots:=pilots||jsonb_build_array(member);ELSE cabin:=cabin||jsonb_build_array(member);END IF;
 END LOOP;
 SELECT count(*) INTO issues FROM airlinerra_game.section9_operated_crew_capture_issues_v1 x JOIN airlinerra_game.section9_operated_flight_movements_v1 m ON m.engine_event_id=x.engine_event_id WHERE x.airline_id=p_airline AND m.actual_event_utc>=now_utc-interval '7 days' AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_crew_bindings_v1 b WHERE b.physical_flight_id=x.physical_flight_id AND b.airline_id=x.airline_id);
 SELECT count(*) INTO unbound FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.airline_id=p_airline AND m.phase='departed' AND m.actual_event_utc>=now_utc-interval '7 days' AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_crew_bindings_v1 b WHERE b.physical_flight_id=m.flight_occurrence_id AND b.airline_id=m.airline_id);
 -- Do not discard already-reported future legs; no safe continuation yet.
 SELECT count(DISTINCT pf.occurrence_id) INTO ongoing FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.status='validated_preview' JOIN airlinerra_game.section9_planned_crew_seats_v1 ps ON ps.plan_id=pf.plan_id AND ps.occurrence_id=pf.occurrence_id JOIN airlinerra_game.section9_planned_crew_duties_v1 pd ON pd.duty_id=ps.duty_id
 WHERE pf.airline_id=p_airline AND pf.departure_utc>=now_utc AND pd.duty_start_utc<=now_utc;
 SELECT coalesce(jsonb_agg(jsonb_build_object('flightId',pf.occurrence_id,'captains',(SELECT coalesce(jsonb_agg(s.employee_id ORDER BY s.employee_id),'[]') FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=pf.plan_id AND s.occurrence_id=pf.occurrence_id AND s.seat_role='captain'),'firstOfficers',(SELECT coalesce(jsonb_agg(s.employee_id ORDER BY s.employee_id),'[]') FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=pf.plan_id AND s.occurrence_id=pf.occurrence_id AND s.seat_role='first_officer'),'cabinCrew',(SELECT coalesce(jsonb_agg(s.employee_id ORDER BY s.employee_id),'[]') FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=pf.plan_id AND s.occurrence_id=pf.occurrence_id AND s.seat_role='cabin')) ORDER BY pf.departure_utc,pf.occurrence_id),'[]') INTO previous
 FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.status='validated_preview'
 WHERE pf.airline_id=p_airline AND EXISTS(SELECT 1 FROM jsonb_array_elements(base->'flights') f WHERE f->>'id'=pf.occurrence_id::text);
 RETURN base||jsonb_build_object('status','rolling_crew_input_preview','pilots',pilots,'cabinMembers',cabin,'excludedEmployees',excluded,'planningCutoffUtc',now_utc,'preferredAssignments',previous,'unboundDeparturesLast7Days',unbound,'unresolvedCaptureIssues',issues,'alreadyReportedFutureFlights',ongoing,'completedDutyHistoryIncluded',true,'dutyHistoryIntegrated',false,'scheduleCompletenessVerified',false,'dispatchEnforced',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_crew_actual_history_v1(uuid,uuid,timestamptz),airlinerra_game.section9_owned_rolling_crew_input_v1(uuid,uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
