-- Private delayed-crew approval validation. No contract, plan or ledger writes.
-- The canonical occurrence identity remains immutable; verified replacement
-- slots supply the effective timestamps. An affirmative result is NOT dispatch authorization.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_delayed_external_crew_quote_v1(
 p_player uuid,p_airline uuid,p_occurrence uuid,p_captains integer,p_first_officers integer,p_cabin integer
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $body$
DECLARE f record;t record;c record;cr numeric;fr numeric;ar numeric;required int;minimum int;fee numeric;committed numeric;cash numeric;physical text;old_fee numeric:=0;existing boolean:=false;now_utc timestamptz;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT cash_usd INTO cash FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT o.*,s.configuration_id,p.qualification_group,p.seat_basis,p.maximum_cabin_crew INTO f
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.version=o.schedule_version AND s.airline_id=o.airline_id AND s.aircraft_inventory_id=o.aircraft_inventory_id AND s.status='active' AND s.operationally_verified
 JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=s.configuration_id
 WHERE o.id=p_occurrence AND o.airline_id=p_airline AND o.world_id=1 AND o.booking_status<>'cancelled';
 IF NOT FOUND THEN RETURN jsonb_build_object('status','external_crew_occurrence_unverified');END IF;
 SELECT * INTO t FROM airlinerra_game.section9_effective_dispatch_window_v1(p_occurrence);
 IF NOT FOUND OR t.is_delayed IS DISTINCT FROM true OR t.dispatch_allowed IS DISTINCT FROM true THEN RETURN jsonb_build_object('status','verified_delay_window_required');END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 physical:=f.schedule_id||':'||f.flight_local_date||':'||f.weekly_entry;
 IF now_utc IS NULL OR now_utc>=t.effective_departure_utc OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id=physical)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 WHERE physical_flight_id=physical)
 THEN RETURN jsonb_build_object('status','delayed_contract_requote_too_late');END IF;
 required:=CASE WHEN t.effective_arrival_utc-t.effective_departure_utc>interval '6 hours' THEN 2 ELSE 1 END;
 minimum:=CASE WHEN f.seat_basis='cargo_zero' OR f.verified_passenger_seats<=19 THEN 0 ELSE (f.verified_passenger_seats+49)/50 END;
 IF f.verified_passenger_seats IS NULL OR t.effective_arrival_utc<=t.effective_departure_utc OR t.effective_arrival_utc-t.effective_departure_utc>interval '9 hours 30 minutes'
 OR minimum>f.maximum_cabin_crew OR p_captains IS NULL OR p_first_officers IS NULL OR p_cabin IS NULL
 OR p_captains NOT BETWEEN 0 AND required OR p_first_officers NOT BETWEEN 0 AND required OR p_cabin NOT BETWEEN 0 AND minimum
 THEN RETURN jsonb_build_object('status','delayed_external_crew_counts_invalid');END IF;
 SELECT * INTO c FROM airlinerra_game.section9_external_crew_contracts_v1 WHERE occurrence_id=p_occurrence OR physical_flight_id=physical;
 IF FOUND THEN
 IF c.airline_id<>p_airline OR c.occurrence_id<>p_occurrence OR c.physical_flight_id<>physical OR c.schedule_version<>f.schedule_version OR c.qualification_group<>f.qualification_group OR c.planned_departure_utc<>f.departure_utc OR c.planned_arrival_utc<>f.arrival_utc THEN RETURN jsonb_build_object('status','existing_delayed_contract_identity_unverified');END IF;
 existing:=true;old_fee:=c.quoted_cost_usd;cr:=c.captain_rate;fr:=c.first_officer_rate;ar:=c.cabin_rate;
 ELSE
 SELECT hourly_usd INTO STRICT cr FROM airlinerra_game.section9_external_crew_rate_v1 WHERE role='captain';
 SELECT hourly_usd INTO STRICT fr FROM airlinerra_game.section9_external_crew_rate_v1 WHERE role='first_officer';
 SELECT hourly_usd INTO STRICT ar FROM airlinerra_game.section9_external_crew_rate_v1 WHERE role='cabin';
 END IF;
 fee:=airlinerra_game.section9_external_crew_cost_v1(p_captains,p_first_officers,p_cabin,cr,fr,ar,extract(epoch FROM t.effective_arrival_utc-t.effective_departure_utc)/60);
 SELECT coalesce(sum(ec.quoted_cost_usd),0) INTO committed FROM airlinerra_game.section9_external_crew_contracts_v1 ec
 WHERE ec.airline_id=p_airline AND ec.physical_flight_id<>physical
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 x WHERE x.physical_flight_id=ec.physical_flight_id)
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.id=ec.occurrence_id AND o.booking_status='cancelled');
 RETURN jsonb_build_object('status','delayed_external_crew_quote','occurrenceId',p_occurrence,'physicalFlightId',physical,
 'originalDepartureUtc',f.departure_utc,'originalArrivalUtc',f.arrival_utc,'revisedDepartureUtc',t.effective_departure_utc,'revisedArrivalUtc',t.effective_arrival_utc,'requiredCaptains',required,'requiredFirstOfficers',required,'minimumCabinCrew',minimum,'qualificationGroup',f.qualification_group,
 'captains',p_captains,'firstOfficers',p_first_officers,'cabinCrew',p_cabin,'estimatedCostUsd',fee,'previousQuoteUsd',old_fee,'quoteDifferenceUsd',fee-old_fee,
 'existingContract',existing,'existingContractReference',CASE WHEN existing THEN c.source_reference END,'frozenRatesUsed',existing,
 'otherCommittedUsd',committed,'affordable',cash>=committed+fee,'contractRevisionRequired',existing OR p_captains+p_first_officers+p_cabin>0,
 'contractingEnabled',coalesce((SELECT contracting_enabled FROM airlinerra_game.section9_external_crew_release_v1 WHERE world_id=1),false),
 'contractChanged',false,'ledgerPosted',false,'dispatchEnforced',false);
END $body$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_delayed_external_crew_quote_v1(uuid,uuid,uuid,integer,integer,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_validate_delayed_crew_roster_v1(
 p_player uuid,p_airline uuid,p_occurrence uuid,p_captains uuid[],p_first_officers uuid[],p_cabin uuid[],p_external_captains integer,p_external_first_officers integer,p_external_cabin integer
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $body$
DECLARE q jsonb;f record;old record;a jsonb;emp record;m jsonb;hist jsonb;rot jsonb;prior jsonb;fit jsonb;now_utc timestamptz;dep timestamptz;arr timestamptz;report_at timestamptz;end_at timestamptz;pol record;snap jsonb;original_seat record;total int;retained int:=0;replacements int:=0;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 q:=airlinerra_game.section9_delayed_external_crew_quote_v1(p_player,p_airline,p_occurrence,p_external_captains,p_external_first_officers,p_external_cabin);
 IF q->>'status'<>'delayed_external_crew_quote' THEN RETURN q;END IF;
 IF p_captains IS NULL OR p_first_officers IS NULL OR p_cabin IS NULL OR array_position(p_captains,NULL) IS NOT NULL OR array_position(p_first_officers,NULL) IS NOT NULL OR array_position(p_cabin,NULL) IS NOT NULL
 THEN RETURN jsonb_build_object('status','delayed_roster_invalid');END IF;
 SELECT o.*,s.configuration_id INTO STRICT f FROM airlinerra_game.section9_dated_flight_occurrences_v1 o JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id WHERE o.id=p_occurrence AND o.airline_id=p_airline;
 IF NOT airlinerra_game.section9_pilot_counts_valid_v1((q->>'requiredCaptains')::int,cardinality(p_captains),cardinality(p_first_officers),p_external_captains,p_external_first_officers)
 OR NOT airlinerra_game.section9_cabin_composition_valid_v1(f.configuration_id,f.verified_passenger_seats,cardinality(p_cabin),p_external_cabin)
 THEN RETURN jsonb_build_object('status','delayed_roster_wrong_staff_count');END IF;
 total:=cardinality(p_captains)+cardinality(p_first_officers)+cardinality(p_cabin);
 IF total<>(SELECT count(DISTINCT x) FROM unnest(p_captains||p_first_officers||p_cabin) x) THEN RETURN jsonb_build_object('status','delayed_roster_duplicate_employee');END IF;
 a:=airlinerra_game.section9_assess_delayed_crew_rotation_v1(p_player,p_airline,p_occurrence);
 IF a->>'status' NOT IN('delayed_crew_duty_windows_fit','delayed_crew_replacement_required','delayed_external_contract_review_required') THEN RETURN jsonb_build_object('status','original_delayed_roster_unverified');END IF;
 SELECT pf.* INTO STRICT old FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.airline_id=pf.airline_id AND b.status='validated_preview' WHERE pf.occurrence_id=p_occurrence AND pf.airline_id=p_airline;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 dep:=(q->>'revisedDepartureUtc')::timestamptz;arr:=(q->>'revisedArrivalUtc')::timestamptz;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 report_at:=dep-make_interval(mins=>pol.preflight_minutes);end_at:=arr+make_interval(mins=>pol.postflight_minutes);
 snap:=airlinerra_game.section9_owned_weekly_crew_input_v1(p_player,p_airline,now_utc);
 IF snap->>'status'<>'weekly_crew_bootstrap_input_preview' OR snap->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','delayed_roster_input_unreconciled');END IF;
 -- Never replace an active reporting/continuation duty silently. An explicit
 -- release of the original employee is required in a later atomic workflow.
 FOR emp IN SELECT x employee,'captain' role FROM unnest(p_captains)x UNION ALL SELECT x,'first_officer' FROM unnest(p_first_officers)x UNION ALL SELECT x,'cabin' FROM unnest(p_cabin)x LOOP
  SELECT s.seat_role,d.duty_start_utc INTO original_seat FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id WHERE s.plan_id=old.plan_id AND s.occurrence_id=p_occurrence AND s.employee_id=emp.employee;
  IF FOUND AND original_seat.seat_role=emp.role THEN
   IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(a->'employees') x WHERE x->>'employeeId'=emp.employee::text AND x->>'role'=emp.role AND x->>'status'='duty_window_fits') THEN RETURN jsonb_build_object('status','retained_crew_duty_unverified');END IF;
   retained:=retained+1;CONTINUE;
  END IF;
  IF report_at<now_utc THEN RETURN jsonb_build_object('status','reserve_reporting_time_passed');END IF;
  SELECT value INTO m FROM jsonb_array_elements((snap->'pilots')||(snap->'cabinMembers')) WHERE value->>'id'=emp.employee::text;
  IF NOT FOUND OR (m->>'locationEffectiveUtc')::timestamptz>report_at OR (m->>'employmentFrom')::date>(report_at AT TIME ZONE (m->>'baseTimezone'))::date THEN RETURN jsonb_build_object('status','reserve_employment_or_location_unverified');END IF;
  IF emp.role='cabin' THEN
   IF m?'permissions' OR m->>'role' NOT IN('flight_attendant','cabin_supervisor','purser') THEN RETURN jsonb_build_object('status','reserve_wrong_cabin_role');END IF;
  ELSE
   IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(m->'permissions','[]')) x WHERE x->>'group'=q->>'qualificationGroup' AND x->>'active'='true' AND x->>(CASE emp.role WHEN 'captain' THEN 'captain' ELSE 'firstOfficer' END)='true'
    AND (x->>'issued')::date<=(dep AT TIME ZONE (m->>'baseTimezone'))::date AND (x->>'expires')::date>(arr AT TIME ZONE (m->>'baseTimezone'))::date) THEN RETURN jsonb_build_object('status','reserve_qualification_unverified');END IF;
  END IF;
  -- Conservative: a reserve already committed to a future leg is not free.
  IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=s.plan_id AND pf.occurrence_id=s.occurrence_id JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=s.plan_id AND b.status='validated_preview'
   WHERE s.airline_id=p_airline AND s.employee_id=emp.employee AND pf.occurrence_id<>p_occurrence AND pf.departure_utc>=now_utc)
  THEN RETURN jsonb_build_object('status','reserve_has_other_future_assignment');END IF;
  IF EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_unavailability_v1 x WHERE x.airline_id=p_airline AND x.status='active' AND (x.pilot_id=emp.employee OR x.cabin_member_id=emp.employee) AND x.start_utc<end_at AND x.end_utc>report_at) THEN RETURN jsonb_build_object('status','reserve_unavailable');END IF;
  hist:=airlinerra_game.section9_crew_actual_history_v1(p_airline,emp.employee,now_utc);
  IF hist->>'availableForNewDuty' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','reserve_actual_history_unverified');END IF;
  SELECT coalesce(jsonb_agg(jsonb_build_object('dutyStartUtc',h->'startUtc','dutyEndUtc',h->'endUtc','startingAirport',h->'origin','endingAirport',h->'destination') ORDER BY ord),'[]') INTO prior FROM jsonb_array_elements(hist->'history') WITH ORDINALITY x(h,ord);
  rot:=airlinerra_game.section9_crew_rotation_window_v2(jsonb_build_array(jsonb_build_object('departureUtc',to_char(dep AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),'arrivalUtc',to_char(arr AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),'originAirportKey',f.origin_airport_key,'destinationAirportKey',f.destination_airport_key)));
  fit:=airlinerra_game.section9_crew_duty_fit_v2(rot,prior,m->>'baseTimezone',m->>'initialAirport');
  IF fit->>'eligible' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','reserve_'||coalesce(fit->>'status','duty_not_verified'));END IF;
  replacements:=replacements+1;
 END LOOP;
 -- This validator cannot drop an already-reported employee or unwind their
 -- other planned legs. No displacing live duty, even when a contractor fits.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id WHERE s.plan_id=old.plan_id AND s.occurrence_id=p_occurrence AND NOT(s.employee_id=ANY(p_captains||p_first_officers||p_cabin)) AND d.duty_start_utc<=now_utc)
 THEN RETURN jsonb_build_object('status','active_duty_release_required');END IF;
 IF q->>'affordable' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','delayed_external_crew_insufficient_funds','quote',q);END IF;
 RETURN jsonb_build_object('status','delayed_roster_validation_passed','occurrenceId',p_occurrence,'sourcePlanId',old.plan_id,'retainedInternalCrew',retained,'replacementInternalCrew',replacements,'quote',q,'rosterPersisted',false,'contractChanged',false,'ledgerPosted',false,'dispatchEnforced',false,'dispatchAuthorizationIssued',false);
END $body$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_validate_delayed_crew_roster_v1(uuid,uuid,uuid,uuid[],uuid[],uuid[],integer,integer,integer) FROM PUBLIC,anon,authenticated,service_role;
