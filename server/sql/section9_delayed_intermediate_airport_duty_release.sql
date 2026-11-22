-- Explicit duty release is an actual-game-time event, not a rewrite of planned duty.
ALTER TABLE airlinerra_game.section9_planned_crew_duties_v1
 ADD COLUMN IF NOT EXISTS actual_release_game_utc timestamptz,
 ADD COLUMN IF NOT EXISTS actual_release_airport_key text,
 ADD COLUMN IF NOT EXISTS actual_release_approval_id uuid;
ALTER TABLE airlinerra_game.section9_planned_crew_duties_v1 ADD CONSTRAINT section9_actual_duty_release_complete_ck CHECK
 ((num_nonnulls(actual_release_game_utc,actual_release_airport_key,actual_release_approval_id)=0)
 OR (num_nonnulls(actual_release_game_utc,actual_release_airport_key,actual_release_approval_id)=3 AND actual_release_game_utc>=duty_start_utc));

CREATE OR REPLACE FUNCTION airlinerra_game.section9_terminal_crew_release_proof_v1(p_airline uuid,p_plan uuid,p_occurrence uuid,p_employee uuid,p_release timestamptz,p_revised_departure timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $body$
DECLARE duty record;target record;leg record;d record;a record;prev_arr timestamptz;airport text;count_legs integer:=0;pol record;h jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT pf.* INTO target FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.airline_id=pf.airline_id AND b.status='validated_preview' WHERE pf.plan_id=p_plan AND pf.occurrence_id=p_occurrence AND pf.airline_id=p_airline;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','release_source_plan_unverified');END IF;
 SELECT pd.* INTO duty FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 pd ON pd.duty_id=s.duty_id AND pd.plan_id=s.plan_id AND pd.employee_id=s.employee_id AND pd.airline_id=s.airline_id WHERE s.plan_id=p_plan AND s.airline_id=p_airline AND s.occurrence_id=p_occurrence AND s.employee_id=p_employee;
 IF NOT FOUND OR p_release IS NULL OR p_release<duty.duty_start_utc OR p_release>=p_revised_departure THEN RETURN jsonb_build_object('status','release_duty_unverified');END IF;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 IF p_release>p_revised_departure-make_interval(mins=>pol.preflight_minutes) THEN RETURN jsonb_build_object('status','release_replacement_reporting_time_passed');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=s.plan_id AND pf.occurrence_id=s.occurrence_id WHERE s.plan_id=p_plan AND s.employee_id=p_employee AND s.occurrence_id<>p_occurrence AND pf.departure_utc>=target.departure_utc) THEN RETURN jsonb_build_object('status','release_future_rotation_requires_replan');END IF;
 airport:=duty.starting_airport;
 FOR leg IN SELECT pf.* FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=s.plan_id AND pf.occurrence_id=s.occurrence_id WHERE s.plan_id=p_plan AND s.duty_id=duty.duty_id AND pf.departure_utc<target.departure_utc ORDER BY pf.departure_utc,pf.occurrence_id LOOP
  IF airport IS DISTINCT FROM leg.origin_airport_key THEN RETURN jsonb_build_object('status','release_rotation_discontinuous');END IF;
  SELECT m.* INTO d FROM airlinerra_game.section9_operated_crew_bindings_v1 b JOIN airlinerra_game.section9_planned_crew_seats_v1 s ON s.plan_id=b.plan_id AND s.occurrence_id=b.occurrence_id AND s.airline_id=b.airline_id AND s.employee_id=p_employee JOIN airlinerra_game.section9_operated_flight_movements_v1 m ON m.engine_event_id=b.departure_event_id AND m.flight_occurrence_id=b.physical_flight_id AND m.airline_id=b.airline_id AND m.phase='departed' AND m.source_kind='signed_operated_game_flight_v1'
  WHERE b.plan_id=p_plan AND b.airline_id=p_airline AND b.occurrence_id=leg.occurrence_id AND b.physical_flight_id=leg.physical_flight_id AND m.schedule_version=leg.schedule_version AND m.aircraft_inventory_id=leg.aircraft_inventory_id AND m.origin_airport_key=leg.origin_airport_key AND m.destination_airport_key=leg.destination_airport_key;
  IF NOT FOUND OR d.actual_event_utc<duty.duty_start_utc OR (prev_arr IS NOT NULL AND d.actual_event_utc<prev_arr) THEN RETURN jsonb_build_object('status','release_prior_departure_unverified');END IF;
  SELECT m.* INTO a FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.airline_id=p_airline AND m.flight_occurrence_id=d.flight_occurrence_id AND m.phase='arrived' AND m.source_kind='signed_operated_game_flight_v1' AND m.schedule_id=d.schedule_id AND m.schedule_version=d.schedule_version AND m.aircraft_inventory_id=d.aircraft_inventory_id AND m.weekly_entry=d.weekly_entry AND m.flight_local_date=d.flight_local_date AND m.origin_airport_key=d.origin_airport_key AND m.destination_airport_key=d.destination_airport_key;
  IF NOT FOUND OR a.actual_event_utc<=d.actual_event_utc OR a.actual_event_utc+make_interval(mins=>pol.postflight_minutes)>p_release THEN RETURN jsonb_build_object('status','release_prior_arrival_unverified');END IF;
  prev_arr:=a.actual_event_utc;airport:=leg.destination_airport_key;count_legs:=count_legs+1;
 END LOOP;
 IF count_legs=0 OR airport IS DISTINCT FROM target.origin_airport_key THEN RETURN jsonb_build_object('status','release_intermediate_airport_unverified');END IF;
 h:=airlinerra_game.section9_crew_actual_history_v1(p_airline,p_employee,p_release+interval '1 second');
 IF h->>'availableForNewDuty' IS DISTINCT FROM 'true' OR h->>'lastAirport' IS DISTINCT FROM airport OR (h->'history'->-1->>'startUtc')::timestamptz IS DISTINCT FROM duty.duty_start_utc OR (h->>'lastDutyEndUtc')::timestamptz IS DISTINCT FROM greatest(prev_arr+make_interval(mins=>pol.postflight_minutes),coalesce(duty.actual_release_game_utc,prev_arr)) THEN RETURN jsonb_build_object('status','release_actual_history_unverified');END IF;
 RETURN jsonb_build_object('status','terminal_crew_release_verified','employeeId',p_employee,'dutyId',duty.duty_id,'airportKey',airport,'releaseUtc',p_release,'priorArrivalUtc',prev_arr,'restUntilUtc',p_release+make_interval(mins=>pol.minimum_rest_minutes));
END $body$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_terminal_crew_release_proof_v1(uuid,uuid,uuid,uuid,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_validate_delayed_crew_roster_v1(p_player uuid, p_airline uuid, p_occurrence uuid, p_captains uuid[], p_first_officers uuid[], p_cabin uuid[], p_external_captains integer, p_external_first_officers integer, p_external_cabin integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE q jsonb;f record;old record;a jsonb;emp record;m jsonb;hist jsonb;rot jsonb;prior jsonb;fit jsonb;now_utc timestamptz;dep timestamptz;arr timestamptz;report_at timestamptz;end_at timestamptz;pol record;snap jsonb;original_seat record;total int;retained int:=0;replacements int:=0;release_proofs jsonb:='[]';release_proof jsonb;removed_staff record;
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
 -- Active staff can be released only after their own signed prior arrival
 -- on the terminal sector, and only for a verified failure of continuation.
 FOR removed_staff IN SELECT s.employee_id FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id WHERE s.plan_id=old.plan_id AND s.occurrence_id=p_occurrence AND NOT(s.employee_id=ANY(p_captains||p_first_officers||p_cabin)) AND d.duty_start_utc<=now_utc LOOP
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(a->'employees') x WHERE x->>'employeeId'=removed_staff.employee_id::text AND x->>'status' IN('crew_employee_unavailable','duty_limit_exceeded','insufficient_rest','crew_employment_or_qualification_changed')) THEN RETURN jsonb_build_object('status','active_duty_release_required');END IF;
 release_proof:=airlinerra_game.section9_terminal_crew_release_proof_v1(p_airline,old.plan_id,p_occurrence,removed_staff.employee_id,now_utc,dep);
 IF release_proof->>'status'<>'terminal_crew_release_verified' THEN RETURN jsonb_build_object('status','active_duty_release_required','releaseReason',release_proof->>'status');END IF;
 release_proofs:=release_proofs||jsonb_build_array(release_proof);
 END LOOP;
 IF q->>'affordable' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','delayed_external_crew_insufficient_funds','quote',q);END IF;
 RETURN jsonb_build_object('status','delayed_roster_validation_passed','occurrenceId',p_occurrence,'sourcePlanId',old.plan_id,'retainedInternalCrew',retained,'replacementInternalCrew',replacements,'activeReleaseProofs',release_proofs,'quote',q,'rosterPersisted',false,'contractChanged',false,'ledgerPosted',false,'dispatchEnforced',false,'dispatchAuthorizationIssued',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_stage_delayed_crew_approval_v1(p_player uuid, p_airline uuid, p_occurrence uuid, p_approval uuid, p_expected_departure timestamp with time zone, p_expected_arrival timestamp with time zone, p_max_cost numeric, p_captains uuid[], p_first_officers uuid[], p_cabin uuid[], p_external_captains integer, p_external_first_officers integer, p_external_cabin integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE existing record;co record;v jsonb;q jsonb;req jsonb;cash numeric;now_utc timestamptz;
 cp uuid[];fo uuid[];fa uuid[];removed uuid[];ids uuid[];old_plan uuid;original_dep timestamptz;
 old_contract record;cr numeric;fr numeric;ar numeric;fee numeric;add_reserve numeric;pending numeric;baseline_commit numeric;release_item jsonb;updated_count int;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT cash_usd INTO cash FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_approval IS NULL OR p_occurrence IS NULL OR p_expected_departure IS NULL OR p_expected_arrival IS NULL OR NOT isfinite(p_expected_departure) OR NOT isfinite(p_expected_arrival) OR p_expected_arrival<=p_expected_departure
 OR p_max_cost IS NULL OR p_max_cost<0 OR p_max_cost>1000000000 OR p_max_cost<>round(p_max_cost,2)
 OR p_captains IS NULL OR p_first_officers IS NULL OR p_cabin IS NULL OR cardinality(p_captains)>2 OR cardinality(p_first_officers)>2 OR cardinality(p_cabin)>40
 OR p_external_captains IS NULL OR p_external_first_officers IS NULL OR p_external_cabin IS NULL THEN RETURN jsonb_build_object('status','delayed_approval_invalid_request');END IF;
 SELECT coalesce(array_agg(x ORDER BY x),'{}') INTO cp FROM unnest(p_captains)x;
 SELECT coalesce(array_agg(x ORDER BY x),'{}') INTO fo FROM unnest(p_first_officers)x;
 SELECT coalesce(array_agg(x ORDER BY x),'{}') INTO fa FROM unnest(p_cabin)x;
 ids:=cp||fo||fa;
 req:=jsonb_build_object('occurrenceId',p_occurrence,'departureUtc',p_expected_departure,'arrivalUtc',p_expected_arrival,'maxCostUsd',p_max_cost,
 'captains',cp,'firstOfficers',fo,'cabinCrew',fa,'externalCaptains',p_external_captains,'externalFirstOfficers',p_external_first_officers,'externalCabin',p_external_cabin);
 SELECT * INTO existing FROM airlinerra_game.section9_delayed_crew_approvals_v1 WHERE approval_id=p_approval OR occurrence_id=p_occurrence;
 IF FOUND THEN
  IF existing.airline_id<>p_airline OR existing.approval_id<>p_approval OR existing.request_payload IS DISTINCT FROM req THEN RETURN jsonb_build_object('status','delayed_approval_replay_conflict','saved',false);END IF;
  -- Replays report the historical receipt, never a new dispatch permission.
  RETURN jsonb_build_object('status','delayed_crew_approval_staged','approvalId',p_approval,'occurrenceId',p_occurrence,'quotedCostUsd',existing.quoted_cost_usd,'saved',true,'replayed',true,'dispatchAuthorizationIssued',false,'ledgerPosted',false,'activeRosterChanged',false);
 END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approval_release_v1 WHERE world_id=1 AND approval_enabled) THEN RETURN jsonb_build_object('status','delayed_crew_approval_disabled','saved',false);END IF;
 -- Protect canonical occurrence and revised slot rows for the entire receipt.
 PERFORM 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=p_occurrence AND airline_id=p_airline AND world_id=1 AND booking_status<>'cancelled' FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','delayed_approval_occurrence_unavailable','saved',false);END IF;
 PERFORM 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1 WHERE occurrence_id=p_occurrence AND revised_departure_utc=p_expected_departure AND revised_arrival_utc=p_expected_arrival FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','delayed_approval_slot_changed','saved',false);END IF;
 PERFORM 1 FROM airlinerra_game.section9_dated_replacement_slots_v1 WHERE occurrence_id=p_occurrence FOR SHARE;
 v:=airlinerra_game.section9_validate_delayed_crew_roster_v1(p_player,p_airline,p_occurrence,cp,fo,fa,p_external_captains,p_external_first_officers,p_external_cabin);
 IF v->>'status' IS DISTINCT FROM 'delayed_roster_validation_passed' THEN RETURN jsonb_build_object('status',coalesce(v->>'status','delayed_approval_validation_failed'),'saved',false);END IF;
 q:=v->'quote';old_plan:=(v->>'sourcePlanId')::uuid;original_dep:=(q->>'originalDepartureUtc')::timestamptz;now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 fee:=(q->>'estimatedCostUsd')::numeric;
 IF (q->>'revisedDepartureUtc')::timestamptz IS DISTINCT FROM p_expected_departure OR (q->>'revisedArrivalUtc')::timestamptz IS DISTINCT FROM p_expected_arrival OR now_utc>=p_expected_departure THEN RETURN jsonb_build_object('status','delayed_approval_slot_changed','saved',false);END IF;
 IF fee>p_max_cost THEN RETURN jsonb_build_object('status','delayed_approval_budget_exceeded','quotedCostUsd',fee,'saved',false);END IF;
 IF (p_external_captains+p_external_first_officers+p_external_cabin>0 OR q->>'existingContract'='true') AND q->>'contractingEnabled' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','external_crew_contracting_disabled','saved',false);END IF;
 PERFORM 1 FROM airlinerra_game.section9_crew_plan_batches_v1 WHERE plan_id=old_plan AND airline_id=p_airline AND status='validated_preview' FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','delayed_approval_source_plan_changed','saved',false);END IF;
 SELECT coalesce(array_agg(s.employee_id ORDER BY s.employee_id),'{}') INTO removed FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=old_plan AND s.occurrence_id=p_occurrence AND NOT(s.employee_id=ANY(ids));
 -- The receipt can release only an unstarted isolated assignment. Later legs
 -- cannot inherit a false airport or reset rest. Other scenarios remain held.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id WHERE s.plan_id=old_plan AND s.occurrence_id=p_occurrence AND s.employee_id=ANY(removed) AND d.duty_start_utc<=now_utc AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v->'activeReleaseProofs') x WHERE x->>'employeeId'=s.employee_id::text AND x->>'dutyId'=d.duty_id::text AND (x->>'releaseUtc')::timestamptz=now_utc)) THEN RETURN jsonb_build_object('status','active_duty_release_required','saved',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_flight_crews_v1 f ON f.plan_id=s.plan_id AND f.occurrence_id=s.occurrence_id WHERE s.plan_id=old_plan AND s.employee_id=ANY(removed) AND s.occurrence_id<>p_occurrence AND f.departure_utc>=now_utc) THEN RETURN jsonb_build_object('status','replacement_rotation_release_required','saved',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approvals_v1 x WHERE x.airline_id=p_airline AND x.occurrence_id<>p_occurrence AND (x.internal_captains||x.internal_first_officers||x.internal_cabin||x.released_employee_ids)&&(ids||removed) AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 z JOIN airlinerra_game.section9_operated_flight_movements_v1 m ON m.engine_event_id=z.arrived_event_id AND m.phase='arrived' AND m.airline_id=x.airline_id AND m.flight_occurrence_id=x.physical_flight_id WHERE z.physical_flight_id=x.physical_flight_id AND m.actual_event_utc+interval '30 minutes'<=now_utc)) THEN RETURN jsonb_build_object('status','delayed_approval_employee_already_reserved','saved',false);END IF;
 SELECT * INTO old_contract FROM airlinerra_game.section9_external_crew_contracts_v1 WHERE occurrence_id=p_occurrence FOR UPDATE;
 IF FOUND THEN cr:=old_contract.captain_rate;fr:=old_contract.first_officer_rate;ar:=old_contract.cabin_rate;
 ELSE
 SELECT hourly_usd INTO STRICT cr FROM airlinerra_game.section9_external_crew_rate_v1 WHERE role='captain' FOR SHARE;
 SELECT hourly_usd INTO STRICT fr FROM airlinerra_game.section9_external_crew_rate_v1 WHERE role='first_officer' FOR SHARE;
 SELECT hourly_usd INTO STRICT ar FROM airlinerra_game.section9_external_crew_rate_v1 WHERE role='cabin' FOR SHARE;
 END IF;
 IF airlinerra_game.section9_external_crew_cost_v1(p_external_captains,p_external_first_officers,p_external_cabin,cr,fr,ar,extract(epoch FROM p_expected_arrival-p_expected_departure)/60) IS DISTINCT FROM fee THEN RETURN jsonb_build_object('status','delayed_approval_quote_changed','saved',false);END IF;
 -- Count all ordinary outstanding commitments, plus only positive incremental
 -- reservations for staged amendments. Do not release an old contract's funds.
 SELECT coalesce(sum(x.quoted_cost_usd),0) INTO baseline_commit FROM airlinerra_game.section9_external_crew_contracts_v1 x WHERE x.airline_id=p_airline AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 z WHERE z.physical_flight_id=x.physical_flight_id) AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.id=x.occurrence_id AND o.booking_status='cancelled');
 SELECT coalesce(sum(x.additional_reserved_usd),0) INTO pending FROM airlinerra_game.section9_delayed_crew_approvals_v1 x WHERE x.airline_id=p_airline AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 z WHERE z.physical_flight_id=x.physical_flight_id);
 add_reserve:=greatest(0,fee-coalesce(old_contract.quoted_cost_usd,0));
 IF cash<baseline_commit+pending+add_reserve THEN RETURN jsonb_build_object('status','delayed_approval_combined_budget_exceeded','saved',false);END IF;
 INSERT INTO airlinerra_game.section9_delayed_crew_approvals_v1(approval_id,world_id,airline_id,occurrence_id,physical_flight_id,source_plan_id,original_departure_utc,revised_departure_utc,revised_arrival_utc,authorized_game_utc,internal_captains,internal_first_officers,internal_cabin,released_employee_ids,external_captains,external_first_officers,external_cabin,captain_rate,first_officer_rate,cabin_rate,quoted_cost_usd,additional_reserved_usd,original_contract_reference,request_payload,validation_receipt)
 VALUES(p_approval,1,p_airline,p_occurrence,q->>'physicalFlightId',old_plan,original_dep,p_expected_departure,p_expected_arrival,now_utc,cp,fo,fa,removed,p_external_captains,p_external_first_officers,p_external_cabin,cr,fr,ar,fee,add_reserve,old_contract.source_reference,req,v);
 -- Apply actual release only after all budget and roster guards passed;
 -- failure of any row update aborts the approval transaction.
 FOR release_item IN SELECT value FROM jsonb_array_elements(v->'activeReleaseProofs') LOOP
 UPDATE airlinerra_game.section9_planned_crew_duties_v1 SET actual_release_game_utc=(release_item->>'releaseUtc')::timestamptz,actual_release_airport_key=release_item->>'airportKey',actual_release_approval_id=p_approval WHERE plan_id=old_plan AND airline_id=p_airline AND duty_id=(release_item->>'dutyId')::uuid AND employee_id=(release_item->>'employeeId')::uuid AND actual_release_game_utc IS NULL;
 GET DIAGNOSTICS updated_count=ROW_COUNT;IF updated_count<>1 THEN RAISE EXCEPTION 'DELAYED_CREW_RELEASE_ATOMIC_CONFLICT';END IF;
 END LOOP;
 RETURN jsonb_build_object('status','delayed_crew_approval_staged','approvalId',p_approval,'occurrenceId',p_occurrence,'activeDutyReleaseCount',jsonb_array_length(v->'activeReleaseProofs'),'quotedCostUsd',fee,'additionalReservedUsd',add_reserve,'releasedAssignmentCount',cardinality(removed),'saved',true,'replayed',false,'dispatchAuthorizationIssued',false,'ledgerPosted',false,'activeRosterChanged',false,'requiresBindingAdapter',true);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_check_delayed_crew_binding_v1(p_airline uuid, p_occurrence uuid, p_departure timestamp with time zone, p_event text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE ap record;f record;t record;pl record;pol record;employee record;old_duty record;m jsonb;hist jsonb;prior jsonb;rot jsonb;fit jsonb;report_at timestamptz;end_at timestamptz;ids uuid[];removed uuid[];duties jsonb:='[]';snap jsonb;owner_id uuid;n timestamptz;cash numeric;committed numeric;reference text; prior_sector record;prior_count integer;verified_count integer;previous_airport text;previous_arrival timestamptz;rotation_origin text;continued boolean;release_proof jsonb;release_item jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT owner_player_id,cash_usd INTO owner_id,cash FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','delayed_binding_airline_unavailable');END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approval_release_v1 WHERE world_id=1 AND approval_enabled AND binding_enabled) OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_movement_capture_release_v1 WHERE world_id=1 AND capture_enabled) THEN RETURN jsonb_build_object('status','delayed_binding_disabled');END IF;
 SELECT * INTO ap FROM airlinerra_game.section9_delayed_crew_approvals_v1 WHERE airline_id=p_airline AND occurrence_id=p_occurrence FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','delayed_binding_approval_missing');END IF;
 SELECT o.*,s.configuration_id,p.qualification_group INTO f FROM airlinerra_game.section9_dated_flight_occurrences_v1 o JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.version=o.schedule_version AND s.airline_id=o.airline_id AND s.aircraft_inventory_id=o.aircraft_inventory_id AND s.status='active' AND s.operationally_verified JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=s.configuration_id WHERE o.id=p_occurrence AND o.airline_id=p_airline AND o.world_id=1 AND o.booking_status<>'cancelled' FOR UPDATE OF o;
 IF NOT FOUND OR f.schedule_id||':'||f.flight_local_date||':'||f.weekly_entry IS DISTINCT FROM ap.physical_flight_id OR f.departure_utc IS DISTINCT FROM ap.original_departure_utc THEN RETURN jsonb_build_object('status','delayed_binding_occurrence_changed');END IF;
 PERFORM 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1 WHERE occurrence_id=p_occurrence FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','delayed_binding_slot_missing');END IF;
 PERFORM 1 FROM airlinerra_game.section9_dated_replacement_slots_v1 WHERE occurrence_id=p_occurrence FOR SHARE;
 SELECT * INTO t FROM airlinerra_game.section9_effective_dispatch_window_v1(p_occurrence);
 IF NOT FOUND OR t.is_delayed IS DISTINCT FROM true OR t.dispatch_allowed IS DISTINCT FROM true OR t.effective_departure_utc IS DISTINCT FROM ap.revised_departure_utc OR t.effective_arrival_utc IS DISTINCT FROM ap.revised_arrival_utc OR p_departure IS DISTINCT FROM ap.revised_departure_utc THEN RETURN jsonb_build_object('status','delayed_binding_slot_changed');END IF;
 n:=airlinerra_game.section9_verified_world_instant_v1();
 IF n IS NULL OR n<p_departure OR n>p_departure+interval '24 hours' THEN RETURN jsonb_build_object('status','delayed_binding_not_due');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id=ap.physical_flight_id AND (p_event IS NULL OR engine_event_id<>p_event OR phase<>'departed')) THEN RETURN jsonb_build_object('status','delayed_binding_movement_conflict');END IF;
 IF p_event IS NOT NULL AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 d JOIN airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 r ON r.departure_engine_event_id=d.engine_event_id AND r.physical_flight_id=d.flight_occurrence_id AND r.airline_id=d.airline_id AND r.aircraft_inventory_id=d.aircraft_inventory_id AND r.configuration_id=f.configuration_id WHERE d.engine_event_id=p_event AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1' AND d.flight_occurrence_id=ap.physical_flight_id AND d.airline_id=p_airline AND d.schedule_id=f.schedule_id AND d.schedule_version=f.schedule_version AND d.aircraft_inventory_id=f.aircraft_inventory_id AND d.flight_local_date=f.flight_local_date AND d.weekly_entry=f.weekly_entry AND d.origin_airport_key=f.origin_airport_key AND d.destination_airport_key=f.destination_airport_key AND d.actual_event_utc=p_departure AND d.scheduled_departure_utc=f.departure_utc AND d.scheduled_arrival_utc=f.arrival_utc) THEN RETURN jsonb_build_object('status','delayed_binding_signed_departure_missing');END IF;
 SELECT pf.* INTO pl FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.airline_id=pf.airline_id AND b.status='validated_preview' WHERE pf.plan_id=ap.source_plan_id AND pf.occurrence_id=p_occurrence AND pf.airline_id=p_airline AND pf.schedule_version=f.schedule_version AND pf.departure_utc=f.departure_utc AND pf.arrival_utc=f.arrival_utc AND pf.aircraft_inventory_id=f.aircraft_inventory_id AND pf.qualification_group=f.qualification_group;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','delayed_binding_source_plan_changed');END IF;
 ids:=ap.internal_captains||ap.internal_first_officers||ap.internal_cabin;
 SELECT coalesce(array_agg(s.employee_id ORDER BY s.employee_id),'{}') INTO removed FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id=p_occurrence AND NOT(s.employee_id=ANY(ids));
 IF removed IS DISTINCT FROM ap.released_employee_ids OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id=p_occurrence AND s.employee_id=ANY(removed) AND d.duty_start_utc<=ap.authorized_game_utc AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(ap.validation_receipt->'activeReleaseProofs','[]')) x WHERE x->>'employeeId'=s.employee_id::text AND x->>'dutyId'=d.duty_id::text AND d.actual_release_approval_id=ap.approval_id AND d.actual_release_game_utc=ap.authorized_game_utc AND d.actual_release_airport_key=f.origin_airport_key)) THEN RETURN jsonb_build_object('status','delayed_binding_release_conflict');END IF;
 FOR release_item IN SELECT value FROM jsonb_array_elements(coalesce(ap.validation_receipt->'activeReleaseProofs','[]')) LOOP
 release_proof:=airlinerra_game.section9_terminal_crew_release_proof_v1(p_airline,ap.source_plan_id,p_occurrence,(release_item->>'employeeId')::uuid,ap.authorized_game_utc,p_departure);
 IF release_proof IS DISTINCT FROM release_item THEN RETURN jsonb_build_object('status','delayed_binding_release_evidence_changed');END IF;
 END LOOP;
 -- Support a terminal sector after a signed earlier leg, but do not move
 -- future assigned employees or allow a changed rotation to strand anyone.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=s.plan_id AND pf.occurrence_id=s.occurrence_id WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id<>p_occurrence AND s.employee_id=ANY(ids||removed) AND pf.departure_utc>=pl.departure_utc)
 THEN RETURN jsonb_build_object('status','delayed_binding_multi_sector_replan_required');END IF;
 IF NOT airlinerra_game.section9_pilot_counts_valid_v1(CASE WHEN t.effective_arrival_utc-t.effective_departure_utc>interval '6 hours' THEN 2 ELSE 1 END,cardinality(ap.internal_captains),cardinality(ap.internal_first_officers),ap.external_captains,ap.external_first_officers)
 OR NOT airlinerra_game.section9_cabin_composition_valid_v1(f.configuration_id,f.verified_passenger_seats,cardinality(ap.internal_cabin),ap.external_cabin)
 OR cardinality(ids)<>(SELECT count(DISTINCT x) FROM unnest(ids)x) THEN RETURN jsonb_build_object('status','delayed_binding_staffing_changed');END IF;
 IF ap.external_captains+ap.external_first_officers+ap.external_cabin>0 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_external_crew_release_v1 WHERE world_id=1 AND contracting_enabled) THEN RETURN jsonb_build_object('status','external_crew_contracting_disabled');END IF;
 IF (SELECT source_reference FROM airlinerra_game.section9_external_crew_contracts_v1 WHERE occurrence_id=p_occurrence) IS DISTINCT FROM ap.original_contract_reference THEN RETURN jsonb_build_object('status','delayed_binding_original_contract_changed');END IF;
 SELECT coalesce(sum(ec.quoted_cost_usd),0) INTO committed FROM airlinerra_game.section9_external_crew_contracts_v1 ec WHERE ec.airline_id=p_airline AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 z WHERE z.physical_flight_id=ec.physical_flight_id) AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.id=ec.occurrence_id AND o.booking_status='cancelled');
 committed:=committed+(SELECT coalesce(sum(x.additional_reserved_usd),0) FROM airlinerra_game.section9_delayed_crew_approvals_v1 x WHERE x.airline_id=p_airline AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 z WHERE z.physical_flight_id=x.physical_flight_id));
 IF cash<committed THEN RETURN jsonb_build_object('status','delayed_binding_funds_changed');END IF;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 snap:=airlinerra_game.section9_owned_weekly_crew_input_v1(owner_id,p_airline,p_departure);
 IF snap->>'status'<>'weekly_crew_bootstrap_input_preview' OR snap->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','delayed_binding_roster_unverified');END IF;
 end_at:=ap.revised_arrival_utc+make_interval(mins=>pol.postflight_minutes);
 FOR employee IN SELECT x id,'captain' role FROM unnest(ap.internal_captains)x UNION ALL SELECT x,'first_officer' FROM unnest(ap.internal_first_officers)x UNION ALL SELECT x,'cabin' FROM unnest(ap.internal_cabin)x LOOP
 continued:=false;rotation_origin:=f.origin_airport_key;prior_count:=0;verified_count:=0;previous_airport:=NULL;previous_arrival:=NULL;
 SELECT s.seat_role,d.duty_start_utc,d.duty_id,d.starting_airport INTO old_duty FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id=p_occurrence AND s.employee_id=employee.id;
 IF FOUND THEN
 IF old_duty.seat_role<>employee.role THEN RETURN jsonb_build_object('status','delayed_binding_role_changed');END IF;
 report_at:=old_duty.duty_start_utc;
 -- Every earlier planned sector of the same duty must have a matching
 -- signed departure, signed arrival and actual employee seat binding.
 FOR prior_sector IN SELECT pf.*,s.employee_id AS assigned_employee
 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=s.plan_id AND pf.occurrence_id=s.occurrence_id
 WHERE s.plan_id=ap.source_plan_id AND s.duty_id=old_duty.duty_id AND pf.departure_utc<pl.departure_utc ORDER BY pf.departure_utc,pf.occurrence_id LOOP
 prior_count:=prior_count+1;
 IF prior_count=1 THEN previous_airport:=old_duty.starting_airport; END IF;
 IF previous_airport IS DISTINCT FROM prior_sector.origin_airport_key THEN RETURN jsonb_build_object('status','delayed_binding_prior_route_discontinuous');END IF;
 SELECT a.actual_event_utc INTO previous_arrival FROM airlinerra_game.section9_operated_crew_bindings_v1 b
 JOIN airlinerra_game.section9_planned_crew_seats_v1 bs ON bs.plan_id=b.plan_id AND bs.occurrence_id=b.occurrence_id AND bs.airline_id=b.airline_id AND bs.employee_id=employee.id
 JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.engine_event_id=b.departure_event_id AND d.airline_id=b.airline_id AND d.flight_occurrence_id=b.physical_flight_id AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1'
 JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.flight_occurrence_id=d.flight_occurrence_id AND a.airline_id=d.airline_id AND a.phase='arrived' AND a.source_kind='signed_operated_game_flight_v1' AND a.aircraft_inventory_id=d.aircraft_inventory_id AND a.schedule_id=d.schedule_id AND a.schedule_version=d.schedule_version AND a.weekly_entry=d.weekly_entry AND a.flight_local_date=d.flight_local_date AND a.origin_airport_key=d.origin_airport_key AND a.destination_airport_key=d.destination_airport_key
 WHERE b.airline_id=p_airline AND b.plan_id=ap.source_plan_id AND b.occurrence_id=prior_sector.occurrence_id AND b.physical_flight_id=prior_sector.physical_flight_id
 AND d.aircraft_inventory_id=prior_sector.aircraft_inventory_id AND d.schedule_version=prior_sector.schedule_version AND d.origin_airport_key=prior_sector.origin_airport_key AND d.destination_airport_key=prior_sector.destination_airport_key AND a.actual_event_utc>d.actual_event_utc AND a.actual_event_utc+make_interval(mins=>pol.postflight_minutes)<=p_departure;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','delayed_binding_prior_sector_unverified');END IF;
 verified_count:=verified_count+1;previous_airport:=prior_sector.destination_airport_key;
 END LOOP;
 IF prior_count>0 THEN
 IF verified_count<>prior_count OR previous_airport IS DISTINCT FROM f.origin_airport_key THEN RETURN jsonb_build_object('status','delayed_binding_prior_airport_mismatch');END IF;
 continued:=true;rotation_origin:=old_duty.starting_airport;
 END IF;
 ELSE
 report_at:=p_departure-make_interval(mins=>pol.preflight_minutes);
 IF report_at<ap.authorized_game_utc THEN RETURN jsonb_build_object('status','delayed_binding_report_unverified');END IF;
 END IF;
 IF report_at>p_departure OR end_at-report_at>make_interval(mins=>pol.maximum_duty_minutes) THEN RETURN jsonb_build_object('status','delayed_binding_duty_limit');END IF;
 SELECT value INTO m FROM jsonb_array_elements((snap->'pilots')||(snap->'cabinMembers')) WHERE value->>'id'=employee.id::text;
 IF NOT FOUND OR (m->>'locationEffectiveUtc')::timestamptz>report_at OR (m->>'employmentFrom')::date>(report_at AT TIME ZONE (m->>'baseTimezone'))::date THEN RETURN jsonb_build_object('status','delayed_binding_employment_changed');END IF;
 IF employee.role='cabin' THEN
 IF m?'permissions' OR m->>'role' NOT IN('flight_attendant','cabin_supervisor','purser') THEN RETURN jsonb_build_object('status','delayed_binding_cabin_role_changed');END IF;
 ELSE
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(m->'permissions','[]')) x WHERE x->>'group'=f.qualification_group AND x->>'active'='true' AND x->>(CASE employee.role WHEN 'captain' THEN 'captain' ELSE 'firstOfficer' END)='true' AND (x->>'issued')::date<=(p_departure AT TIME ZONE (m->>'baseTimezone'))::date AND (x->>'expires')::date>(ap.revised_arrival_utc AT TIME ZONE (m->>'baseTimezone'))::date) THEN RETURN jsonb_build_object('status','delayed_binding_qualification_changed');END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_unavailability_v1 x WHERE x.airline_id=p_airline AND x.status='active' AND (x.pilot_id=employee.id OR x.cabin_member_id=employee.id) AND x.start_utc<end_at AND x.end_utc>report_at) THEN RETURN jsonb_build_object('status','delayed_binding_employee_unavailable');END IF;
 hist:=airlinerra_game.section9_crew_actual_history_v1(p_airline,employee.id,p_departure);
 IF hist->>'availableForNewDuty' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','delayed_binding_actual_history_unverified');END IF;
 IF continued THEN
 -- Merge, rather than start another duty at the intermediate airport.
 -- The last actual history entry must be exactly this same earlier duty.
 IF hist->'history'->-1->>'origin' IS DISTINCT FROM rotation_origin OR hist->'history'->-1->>'destination' IS DISTINCT FROM f.origin_airport_key
 OR (hist->'history'->-1->>'startUtc')::timestamptz IS DISTINCT FROM report_at
 OR (hist->'history'->-1->>'endUtc')::timestamptz IS DISTINCT FROM previous_arrival+make_interval(mins=>pol.postflight_minutes)
 THEN RETURN jsonb_build_object('status','delayed_binding_active_history_mismatch');END IF;
 hist:=jsonb_set(hist,'{history}',(hist->'history')-(-1));
 END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('dutyStartUtc',h->'startUtc','dutyEndUtc',h->'endUtc','startingAirport',h->'origin','endingAirport',h->'destination') ORDER BY ord),'[]') INTO prior FROM jsonb_array_elements(hist->'history') WITH ORDINALITY x(h,ord);
 rot:=jsonb_build_object('status','rotation_preview','dutyStartUtc',report_at,'dutyEndUtc',end_at,'startingAirport',rotation_origin,'endingAirport',f.destination_airport_key);
 fit:=airlinerra_game.section9_crew_duty_fit_v2(rot,prior,m->>'baseTimezone',m->>'initialAirport');
 IF fit->>'eligible' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','delayed_binding_'||coalesce(fit->>'status','rest_unverified'));END IF;
 duties:=duties||jsonb_build_array(jsonb_build_object('employeeId',employee.id,'role',employee.role,'dutyStartUtc',report_at,'dutyEndUtc',end_at,'reportDate',(report_at AT TIME ZONE (m->>'baseTimezone'))::date,'startingAirport',rotation_origin,'continuedDuty',continued));
 END LOOP;
 reference:=CASE WHEN ap.external_captains+ap.external_first_officers+ap.external_cabin>0 THEN 'delayed-approval-v1:'||ap.approval_id END;
 RETURN jsonb_build_object('status','delayed_crew_binding_ready','approvalId',ap.approval_id,'duties',duties,'configurationId',f.configuration_id,'contractReference',reference,'dispatchAuthorizationIssued',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_crew_actual_history_v1(p_airline uuid, p_employee uuid, p_start timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE legs jsonb;hist jsonb;last_airport text;last_end timestamptz;open_count int;invalid_count int;duty_count int;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_airline IS NULL OR p_employee IS NULL OR p_start IS NULL OR NOT isfinite(p_start) THEN RETURN jsonb_build_object('status','invalid_crew_history_request');END IF;
 WITH raw AS(
 SELECT coalesce(source_duty.duty_id,ps.duty_id) AS duty_id,pd.duty_start_utc,pd.starting_airport,pd.ending_airport,b.physical_flight_id,
 dep.actual_event_utc departed,dep.origin_airport_key,dep.destination_airport_key,arr.actual_event_utc arrived,CASE WHEN pd.actual_release_game_utc<=p_start AND pd.actual_release_airport_key=dep.destination_airport_key THEN pd.actual_release_game_utc END AS actual_release
 FROM airlinerra_game.section9_operated_crew_bindings_v1 b
 JOIN airlinerra_game.section9_planned_crew_seats_v1 ps ON ps.airline_id=b.airline_id AND ps.plan_id=b.plan_id AND ps.occurrence_id=b.occurrence_id AND ps.employee_id=p_employee
 JOIN airlinerra_game.section9_planned_crew_duties_v1 pd ON pd.duty_id=ps.duty_id AND pd.airline_id=ps.airline_id AND pd.employee_id=ps.employee_id
 LEFT JOIN airlinerra_game.section9_crew_plan_batches_v1 projection ON projection.plan_id=b.plan_id AND projection.airline_id=b.airline_id AND projection.source_snapshot->>'status'='delayed_approved_actual_projection'
 LEFT JOIN airlinerra_game.section9_planned_crew_seats_v1 source_seat ON source_seat.plan_id=(projection.source_snapshot->>'sourcePlanId')::uuid AND source_seat.airline_id=b.airline_id AND source_seat.occurrence_id=b.occurrence_id AND source_seat.employee_id=ps.employee_id AND source_seat.seat_role=ps.seat_role
 LEFT JOIN airlinerra_game.section9_planned_crew_duties_v1 source_duty ON source_duty.duty_id=source_seat.duty_id AND source_duty.airline_id=b.airline_id AND source_duty.employee_id=ps.employee_id AND source_duty.duty_start_utc=pd.duty_start_utc
 JOIN airlinerra_game.section9_operated_flight_movements_v1 dep ON dep.engine_event_id=b.departure_event_id AND dep.airline_id=b.airline_id AND dep.phase='departed' AND dep.flight_occurrence_id=b.physical_flight_id
 LEFT JOIN airlinerra_game.section9_operated_flight_movements_v1 arr ON arr.flight_occurrence_id=b.physical_flight_id AND arr.airline_id=b.airline_id AND arr.phase='arrived' AND arr.aircraft_inventory_id=dep.aircraft_inventory_id AND arr.schedule_id=dep.schedule_id AND arr.schedule_version=dep.schedule_version AND arr.weekly_entry=dep.weekly_entry AND arr.flight_local_date=dep.flight_local_date AND arr.origin_airport_key=dep.origin_airport_key AND arr.destination_airport_key=dep.destination_airport_key
 WHERE b.airline_id=p_airline AND dep.actual_event_utc<p_start
 ), ordered AS(
 SELECT *,lag(destination_airport_key) OVER(PARTITION BY duty_id ORDER BY departed,physical_flight_id) prior_dest,lag(arrived) OVER(PARTITION BY duty_id ORDER BY departed,physical_flight_id) prior_arr FROM raw
 ), duties AS(
 SELECT duty_id,min(duty_start_utc) report_at,greatest(max(arrived)+interval '30 minutes',max(actual_release)) end_at,
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
END $function$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_terminal_crew_release_proof_v1(uuid,uuid,uuid,uuid,timestamptz,timestamptz),airlinerra_game.section9_validate_delayed_crew_roster_v1(uuid,uuid,uuid,uuid[],uuid[],uuid[],integer,integer,integer),airlinerra_game.section9_stage_delayed_crew_approval_v1(uuid,uuid,uuid,uuid,timestamptz,timestamptz,numeric,uuid[],uuid[],uuid[],integer,integer,integer),airlinerra_game.section9_check_delayed_crew_binding_v1(uuid,uuid,timestamptz,text),airlinerra_game.section9_crew_actual_history_v1(uuid,uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;