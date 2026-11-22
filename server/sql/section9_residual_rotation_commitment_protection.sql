-- A reserve remains committed through the actual final onward arrival
-- and postflight, even if the first sector has already settled financially.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_residual_crew_commitment_v1(p_airline uuid,p_employees uuid[],p_excluded_approval uuid,p_now timestamptz)
RETURNS boolean LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $b$
 SELECT EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approvals_v1 ap
 WHERE ap.airline_id=p_airline AND ap.approval_id IS DISTINCT FROM p_excluded_approval
 AND ap.validation_receipt->'residualReplacement'->>'onwardOccurrenceId' IS NOT NULL
 AND (p_employees IS NULL OR (ap.internal_captains||ap.internal_first_officers||ap.internal_cabin)&&p_employees)
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_crew_bindings_v1 b
 JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.engine_event_id=b.departure_event_id AND d.airline_id=b.airline_id AND d.flight_occurrence_id=b.physical_flight_id AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1'
 JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.airline_id=d.airline_id AND a.flight_occurrence_id=d.flight_occurrence_id AND a.phase='arrived' AND a.source_kind='signed_operated_game_flight_v1' AND a.aircraft_inventory_id=d.aircraft_inventory_id AND a.schedule_id=d.schedule_id AND a.schedule_version=d.schedule_version AND a.weekly_entry=d.weekly_entry AND a.flight_local_date=d.flight_local_date AND a.origin_airport_key=d.origin_airport_key AND a.destination_airport_key=d.destination_airport_key
 WHERE b.airline_id=ap.airline_id AND b.plan_id=ap.approval_id AND b.occurrence_id=(ap.validation_receipt->'residualReplacement'->>'onwardOccurrenceId')::uuid AND a.actual_event_utc>d.actual_event_utc AND a.actual_event_utc+interval '30 minutes'<=p_now))
$b$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_residual_crew_commitment_v1(uuid,uuid[],uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

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
  IF airlinerra_game.section9_residual_crew_commitment_v1(p_airline,ARRAY[emp.employee],NULL,now_utc) THEN RETURN jsonb_build_object('status','reserve_committed_residual_rotation');END IF;
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
 old_contract record;cr numeric;fr numeric;ar numeric;fee numeric;add_reserve numeric;pending numeric;baseline_commit numeric;release_item jsonb;updated_count int;residual jsonb;onward_fee numeric:=0;onward_contract jsonb;
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
 IF airlinerra_game.section9_delayed_downstream_scope_v1(p_airline,old_plan,p_occurrence,p_expected_arrival)->>'status' IS DISTINCT FROM 'downstream_scope_verified' THEN
 IF airlinerra_game.section9_same_duty_continuation_scope_v1(p_airline,old_plan,p_occurrence,p_expected_departure,p_expected_arrival,cp,fo,fa,p_external_captains+p_external_first_officers+p_external_cabin) THEN v:=v||jsonb_build_object('sameDutyContinuation',true);
 ELSE
 residual:=airlinerra_game.section9_residual_replacement_proof_v1(p_player,p_airline,old_plan,p_occurrence,p_expected_departure,p_expected_arrival,cp,fo,fa,p_external_captains,p_external_first_officers,p_external_cabin);
 IF residual->>'status' IS DISTINCT FROM 'residual_replacement_verified' OR EXISTS(SELECT 1 FROM airlinerra_game.section9_external_crew_contracts_v1 WHERE occurrence_id=(residual->>'onwardOccurrenceId')::uuid) THEN RETURN jsonb_build_object('status','replacement_rotation_release_required','saved',false);END IF;
 onward_fee:=(residual->>'onwardCostUsd')::numeric;
 IF fee+onward_fee>p_max_cost THEN RETURN jsonb_build_object('status','delayed_approval_budget_exceeded','quotedCostUsd',fee+onward_fee,'saved',false);END IF;
 v:=v||jsonb_build_object('residualReplacement',residual);
 END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approvals_v1 x WHERE x.airline_id=p_airline AND x.occurrence_id<>p_occurrence AND (x.internal_captains||x.internal_first_officers||x.internal_cabin||x.released_employee_ids)&&(ids||removed) AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 z JOIN airlinerra_game.section9_operated_flight_movements_v1 m ON m.engine_event_id=z.arrived_event_id AND m.phase='arrived' AND m.airline_id=x.airline_id AND m.flight_occurrence_id=x.physical_flight_id WHERE z.physical_flight_id=x.physical_flight_id AND m.actual_event_utc+interval '30 minutes'<=now_utc)) THEN RETURN jsonb_build_object('status','delayed_approval_employee_already_reserved','saved',false);END IF;
 IF airlinerra_game.section9_residual_crew_commitment_v1(p_airline,ids||removed,p_approval,now_utc) THEN RETURN jsonb_build_object('status','delayed_approval_residual_crew_reserved','saved',false);END IF;
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
 IF cash<baseline_commit+pending+add_reserve+onward_fee THEN RETURN jsonb_build_object('status','delayed_approval_combined_budget_exceeded','saved',false);END IF;
 INSERT INTO airlinerra_game.section9_delayed_crew_approvals_v1(approval_id,world_id,airline_id,occurrence_id,physical_flight_id,source_plan_id,original_departure_utc,revised_departure_utc,revised_arrival_utc,authorized_game_utc,internal_captains,internal_first_officers,internal_cabin,released_employee_ids,external_captains,external_first_officers,external_cabin,captain_rate,first_officer_rate,cabin_rate,quoted_cost_usd,additional_reserved_usd,original_contract_reference,request_payload,validation_receipt)
 VALUES(p_approval,1,p_airline,p_occurrence,q->>'physicalFlightId',old_plan,original_dep,p_expected_departure,p_expected_arrival,now_utc,cp,fo,fa,removed,p_external_captains,p_external_first_officers,p_external_cabin,cr,fr,ar,fee,add_reserve,old_contract.source_reference,req,v);
 IF residual IS NOT NULL AND onward_fee>0 THEN
 onward_contract:=airlinerra_game.section9_authorize_external_crew_v1(p_airline,(residual->>'onwardOccurrenceId')::uuid,p_external_captains,p_external_first_officers,p_external_cabin,'residual-rotation-v1:'||p_approval);
 IF onward_contract->>'status' IS DISTINCT FROM 'external_crew_contract_authorized' OR (onward_contract->>'quotedCostUsd')::numeric IS DISTINCT FROM onward_fee THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='RESIDUAL_CONTRACT_ATOMIC_ROLLBACK';END IF;
 END IF;
 -- Apply actual release only after all budget and roster guards passed;
 -- failure of any row update aborts the approval transaction.
 FOR release_item IN SELECT value FROM jsonb_array_elements(v->'activeReleaseProofs') LOOP
 UPDATE airlinerra_game.section9_planned_crew_duties_v1 SET actual_release_game_utc=(release_item->>'releaseUtc')::timestamptz,actual_release_airport_key=release_item->>'airportKey',actual_release_approval_id=p_approval WHERE plan_id=old_plan AND airline_id=p_airline AND duty_id=(release_item->>'dutyId')::uuid AND employee_id=(release_item->>'employeeId')::uuid AND actual_release_game_utc IS NULL;
 GET DIAGNOSTICS updated_count=ROW_COUNT;IF updated_count<>1 THEN RAISE EXCEPTION 'DELAYED_CREW_RELEASE_ATOMIC_CONFLICT';END IF;
 END LOOP;
 RETURN jsonb_build_object('status','delayed_crew_approval_staged','approvalId',p_approval,'occurrenceId',p_occurrence,'activeDutyReleaseCount',jsonb_array_length(v->'activeReleaseProofs'),'quotedCostUsd',fee,'additionalReservedUsd',add_reserve,'releasedAssignmentCount',cardinality(removed),'saved',true,'replayed',false,'dispatchAuthorizationIssued',false,'ledgerPosted',false,'activeRosterChanged',false,'requiresBindingAdapter',true,'onwardReservedUsd',onward_fee);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_check_delayed_crew_binding_v1(p_airline uuid, p_occurrence uuid, p_departure timestamp with time zone, p_event text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE ap record;f record;t record;pl record;pol record;employee record;old_duty record;m jsonb;hist jsonb;prior jsonb;rot jsonb;fit jsonb;report_at timestamptz;end_at timestamptz;ids uuid[];removed uuid[];duties jsonb:='[]';snap jsonb;owner_id uuid;n timestamptz;cash numeric;committed numeric;reference text; prior_sector record;prior_count integer;verified_count integer;previous_airport text;previous_arrival timestamptz;rotation_origin text;continued boolean;release_proof jsonb;release_item jsonb;residual jsonb;onward_contract jsonb;
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
 IF airlinerra_game.section9_residual_crew_commitment_v1(p_airline,ids,ap.approval_id,n) THEN RETURN jsonb_build_object('status','delayed_binding_residual_crew_reserved');END IF;
 SELECT coalesce(array_agg(s.employee_id ORDER BY s.employee_id),'{}') INTO removed FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id=p_occurrence AND NOT(s.employee_id=ANY(ids));
 IF removed IS DISTINCT FROM ap.released_employee_ids OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id=p_occurrence AND s.employee_id=ANY(removed) AND d.duty_start_utc<=ap.authorized_game_utc AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(ap.validation_receipt->'activeReleaseProofs','[]')) x WHERE x->>'employeeId'=s.employee_id::text AND x->>'dutyId'=d.duty_id::text AND d.actual_release_approval_id=ap.approval_id AND d.actual_release_game_utc=ap.authorized_game_utc AND d.actual_release_airport_key=f.origin_airport_key)) THEN RETURN jsonb_build_object('status','delayed_binding_release_conflict');END IF;
 FOR release_item IN SELECT value FROM jsonb_array_elements(coalesce(ap.validation_receipt->'activeReleaseProofs','[]')) LOOP
 release_proof:=airlinerra_game.section9_terminal_crew_release_proof_v1(p_airline,ap.source_plan_id,p_occurrence,(release_item->>'employeeId')::uuid,ap.authorized_game_utc,p_departure);
 IF release_proof IS DISTINCT FROM release_item THEN RETURN jsonb_build_object('status','delayed_binding_release_evidence_changed');END IF;
 END LOOP;
 -- Support a terminal sector after a signed earlier leg, but do not move
 -- future assigned employees or allow a changed rotation to strand anyone.
 IF airlinerra_game.section9_delayed_downstream_scope_v1(p_airline,ap.source_plan_id,p_occurrence,ap.revised_arrival_utc)->>'status' IS DISTINCT FROM 'downstream_scope_verified' AND NOT (coalesce(ap.validation_receipt->>'sameDutyContinuation','false')='true' AND airlinerra_game.section9_same_duty_continuation_scope_v1(p_airline,ap.source_plan_id,p_occurrence,ap.revised_departure_utc,ap.revised_arrival_utc,ap.internal_captains,ap.internal_first_officers,ap.internal_cabin,ap.external_captains+ap.external_first_officers+ap.external_cabin)) THEN
 IF ap.validation_receipt->'residualReplacement' IS NULL THEN RETURN jsonb_build_object('status','delayed_binding_multi_sector_replan_required');END IF;
 residual:=airlinerra_game.section9_residual_replacement_proof_v1(owner_id,p_airline,ap.source_plan_id,p_occurrence,ap.revised_departure_utc,ap.revised_arrival_utc,ap.internal_captains,ap.internal_first_officers,ap.internal_cabin,ap.external_captains,ap.external_first_officers,ap.external_cabin);
 IF residual->>'status' IS DISTINCT FROM 'residual_replacement_verified' OR (residual-'onwardCostUsd') IS DISTINCT FROM ((ap.validation_receipt->'residualReplacement')-'onwardCostUsd'::text) THEN RETURN jsonb_build_object('status','delayed_binding_residual_changed');END IF;
 onward_contract:=airlinerra_game.section9_verified_external_cabin_input_v1(p_airline,(residual->>'onwardOccurrenceId')::uuid);
 IF onward_contract->>'status' IS DISTINCT FROM 'external_cabin_input_verified' OR (onward_contract->>'captainCount')::int<>ap.external_captains OR (onward_contract->>'firstOfficerCount')::int<>ap.external_first_officers OR (onward_contract->>'cabinCount')::int<>ap.external_cabin OR (ap.external_captains+ap.external_first_officers+ap.external_cabin>0 AND onward_contract->>'contractReference' IS DISTINCT FROM 'residual-rotation-v1:'||ap.approval_id) THEN RETURN jsonb_build_object('status','delayed_binding_residual_contract_changed');END IF;
 IF ap.external_captains+ap.external_first_officers+ap.external_cabin>0 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_external_crew_contracts_v1 c WHERE c.airline_id=p_airline AND c.occurrence_id=(residual->>'onwardOccurrenceId')::uuid AND c.quoted_cost_usd=(ap.validation_receipt->'residualReplacement'->>'onwardCostUsd')::numeric) THEN RETURN jsonb_build_object('status','delayed_binding_residual_reserved_cost_changed');END IF;
 END IF;
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
 end_at:=coalesce((residual->>'onwardArrivalUtc')::timestamptz,ap.revised_arrival_utc)+make_interval(mins=>pol.postflight_minutes);
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
 rot:=jsonb_build_object('status','rotation_preview','dutyStartUtc',report_at,'dutyEndUtc',end_at,'startingAirport',rotation_origin,'endingAirport',coalesce((SELECT destination_airport_key FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE plan_id=ap.source_plan_id AND occurrence_id=(residual->>'onwardOccurrenceId')::uuid),f.destination_airport_key));
 fit:=airlinerra_game.section9_crew_duty_fit_v2(rot,prior,m->>'baseTimezone',m->>'initialAirport');
 IF fit->>'eligible' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','delayed_binding_'||coalesce(fit->>'status','rest_unverified'));END IF;
 duties:=duties||jsonb_build_array(jsonb_build_object('employeeId',employee.id,'role',employee.role,'dutyStartUtc',report_at,'dutyEndUtc',end_at,'reportDate',(report_at AT TIME ZONE (m->>'baseTimezone'))::date,'startingAirport',rotation_origin,'continuedDuty',continued));
 END LOOP;
 reference:=CASE WHEN ap.external_captains+ap.external_first_officers+ap.external_cabin>0 THEN 'delayed-approval-v1:'||ap.approval_id END;
 RETURN jsonb_build_object('status','delayed_crew_binding_ready','approvalId',ap.approval_id,'duties',duties,'configurationId',f.configuration_id,'contractReference',reference,'dispatchAuthorizationIssued',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_save_owned_rolling_crew_plan_v1(p_player uuid, p_airline uuid, p_plan uuid, p_start timestamp with time zone, p_snapshot jsonb, p_assignments jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE snap jsonb;old record;f record;item jsonb;member jsonb;emp jsonb;legs jsonb;rotation jsonb;prior_history jsonb;fit jsonb;d record;duty uuid;emp_id uuid;role_name text;required int;now_utc timestamptz;report_at timestamptz;count_f int:=0;failure text;ids jsonb;external_cabin jsonb;
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
 IF airlinerra_game.section9_residual_crew_commitment_v1(p_airline,NULL,NULL,now_utc) THEN RETURN jsonb_build_object('status','crew_pending_residual_rotation_protected','saved',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approvals_v1 x WHERE x.airline_id=p_airline AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_crew_bindings_v1 b JOIN airlinerra_game.section9_operated_flight_movements_v1 m ON m.airline_id=b.airline_id AND m.flight_occurrence_id=b.physical_flight_id AND m.phase='arrived' AND m.source_kind='signed_operated_game_flight_v1' WHERE b.airline_id=x.airline_id AND b.plan_id=x.approval_id AND b.occurrence_id=x.occurrence_id AND b.physical_flight_id=x.physical_flight_id AND m.actual_event_utc+interval '30 minutes'<=now_utc)) THEN RETURN jsonb_build_object('status','crew_pending_delayed_approval_protected','saved',false);END IF;
 IF p_start<now_utc OR p_start>now_utc+interval '7 days' THEN RETURN jsonb_build_object('status','crew_plan_window_invalid');END IF;
 snap:=airlinerra_game.section9_owned_rolling_crew_input_v1(p_player,p_airline,p_start);
 IF snap->>'status' IS DISTINCT FROM 'rolling_crew_input_preview' THEN RETURN jsonb_build_object('status','rolling_crew_input_unverified','saved',false);END IF;
 -- The clock alone changes between preview and validation. All other evidence
 -- (including exclusions, assignments, locations and history) must still match.
 IF (snap-'planningCutoffUtc') IS DISTINCT FROM (p_snapshot-'planningCutoffUtc') THEN RETURN jsonb_build_object('status','crew_plan_snapshot_changed');END IF;
 IF snap->>'invalidOccurrenceCount' IS DISTINCT FROM '0' OR snap->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','crew_plan_input_unreconciled');END IF;
 IF jsonb_array_length(p_assignments) NOT BETWEEN 1 AND 2000 OR jsonb_array_length(p_assignments)<>jsonb_array_length(snap->'flights') THEN RETURN jsonb_build_object('status','crew_plan_incomplete');END IF;
 -- No continuation or delayed-slot reassignment is implied by a completed-duty plan.
 IF snap->>'unboundDeparturesLast7Days' IS DISTINCT FROM '0' OR snap->>'unresolvedCaptureIssues' IS DISTINCT FROM '0' THEN RETURN jsonb_build_object('status','crew_history_incomplete','saved',false);END IF;
 IF snap->>'alreadyReportedFutureFlights' IS DISTINCT FROM '0' THEN RETURN jsonb_build_object('status','active_duty_continuation_required','saved',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.status='validated_preview'
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=pf.occurrence_id AND o.airline_id=pf.airline_id
 WHERE pf.airline_id=p_airline AND o.booking_status<>'cancelled'
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.airline_id=p_airline AND m.flight_occurrence_id=pf.physical_flight_id AND m.phase='departed')
 AND NOT EXISTS(SELECT 1 FROM jsonb_array_elements(snap->'flights') x WHERE x->>'id'=pf.occurrence_id::text))
 THEN RETURN jsonb_build_object('status','rolling_crew_previous_flight_not_covered','saved',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1 s JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=s.occurrence_id WHERE o.airline_id=p_airline AND EXISTS(SELECT 1 FROM jsonb_array_elements(snap->'flights') x WHERE x->>'id'=o.id::text) AND (s.revised_departure_utc<>o.departure_utc OR s.revised_arrival_utc<>o.arrival_utc)) THEN RETURN jsonb_build_object('status','crew_delayed_rotation_requires_replan','saved',false);END IF;
 BEGIN
 UPDATE airlinerra_game.section9_crew_plan_batches_v1 SET status='superseded' WHERE airline_id=p_airline AND status='validated_preview';
 INSERT INTO airlinerra_game.section9_crew_plan_batches_v1(plan_id,airline_id,window_start_utc,window_end_utc,source_snapshot,proposed_assignments,status)
 VALUES(p_plan,p_airline,p_start,p_start+interval '168 hours',p_snapshot,p_assignments,'validated_preview');
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
 external_cabin:=airlinerra_game.section9_verified_external_cabin_input_v1(p_airline,f.id);
 IF external_cabin->>'status'<>'external_cabin_input_verified' THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_external_contract_unverified';END IF;
 IF NOT airlinerra_game.section9_pilot_counts_valid_v1(required,jsonb_array_length(item->'captains'),jsonb_array_length(item->'firstOfficers'),(external_cabin->>'captainCount')::int,(external_cabin->>'firstOfficerCount')::int) OR NOT airlinerra_game.section9_cabin_composition_valid_v1(f.configuration_id,f.verified_passenger_seats,jsonb_array_length(item->'cabinCrew'),(external_cabin->>'cabinCount')::int) THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_wrong_staff_count';END IF;
 ids:=(item->'captains')||(item->'firstOfficers')||(item->'cabinCrew');
 IF jsonb_array_length(ids)<>(SELECT count(DISTINCT value) FROM jsonb_array_elements(ids)) OR jsonb_array_length(ids)<>jsonb_array_length(item->'duties') THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_duplicate_employee';END IF;
 INSERT INTO airlinerra_game.section9_planned_flight_crews_v1(plan_id,airline_id,occurrence_id,schedule_version,aircraft_inventory_id,physical_flight_id,qualification_group,departure_utc,arrival_utc,origin_airport_key,destination_airport_key,captain_count,first_officer_count,cabin_count,external_cabin_count,external_contract_reference,external_captain_count,external_first_officer_count)
 VALUES(p_plan,p_airline,f.id,f.schedule_version,f.aircraft_inventory_id,f.schedule_id||':'||f.flight_local_date||':'||f.weekly_entry,f.qualification_group,f.departure_utc,f.arrival_utc,f.origin_airport_key,f.destination_airport_key,jsonb_array_length(item->'captains'),jsonb_array_length(item->'firstOfficers'),jsonb_array_length(item->'cabinCrew'),(external_cabin->>'cabinCount')::int,external_cabin->>'contractReference',(external_cabin->>'captainCount')::int,(external_cabin->>'firstOfficerCount')::int);
 count_f:=count_f+1;
 END LOOP;
 -- Validate each distinct employee and reconstruct entire rotations from legs;
 -- the caller's proposed duty end is not trusted.
 FOR d IN SELECT DISTINCT (x->>'employeeId')::uuid employee FROM jsonb_array_elements(p_assignments) j CROSS JOIN LATERAL jsonb_array_elements(j->'duties') x LOOP
 emp_id:=d.employee;
 SELECT value INTO emp FROM jsonb_array_elements((snap->'pilots')||(snap->'cabinMembers')) WHERE value->>'id'=emp_id::text;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='crew_plan_employee_unavailable';END IF;
 -- Normalize verified actual history into the existing duty-fit contract.
 SELECT coalesce(jsonb_agg(jsonb_build_object('dutyStartUtc',h->'startUtc','dutyEndUtc',h->'endUtc','startingAirport',h->'origin','endingAirport',h->'destination') ORDER BY ord),'[]') INTO prior_history FROM jsonb_array_elements(emp->'history') WITH ORDINALITY x(h,ord);
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
 RETURN jsonb_build_object('status','validated_preview','planId',p_plan,'flightCount',count_f,'dutyCount',(SELECT count(*) FROM airlinerra_game.section9_planned_crew_duties_v1 WHERE plan_id=p_plan),'saved',true,'dispatchEnforced',false,'actualDutyHistoryIntegrated',true,'replayed',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_plan_terminal_delayed_crew_v1(p_player uuid, p_airline uuid, p_occurrence uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE n timestamptz;f record;pl record;pol record;a jsonb;snap jsonb;m jsonb;e record;h jsonb;prior jsonb;rot jsonb;fit jsonb;cp uuid[]:='{}';fo uuid[]:='{}';ca uuid[]:='{}';orig_ids uuid[];cap_only uuid[]:='{}';fo_only uuid[]:='{}';dual_ids uuid[]:='{}';cabin_ids uuid[]:='{}';pid uuid;cap_ok boolean;fo_ok boolean;cab_ok boolean;dep timestamptz;arr timestamptz;report_at timestamptz;end_at timestamptz;needed int;minimum int;ec int;ef int;ea int;v jsonb;residual jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 n:=airlinerra_game.section9_verified_world_instant_v1();
 IF n IS NULL THEN RETURN jsonb_build_object('status','automatic_recovery_clock_unverified');END IF;
 SELECT o.*,s.configuration_id,p.qualification_group,p.seat_basis,p.maximum_cabin_crew,t.effective_departure_utc,t.effective_arrival_utc INTO f FROM airlinerra_game.section9_dated_flight_occurrences_v1 o JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.version=o.schedule_version AND s.aircraft_inventory_id=o.aircraft_inventory_id AND s.status='active' AND s.operationally_verified JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=s.configuration_id CROSS JOIN LATERAL airlinerra_game.section9_effective_dispatch_window_v1(o.id) t WHERE o.id=p_occurrence AND o.airline_id=p_airline AND o.world_id=1 AND o.booking_status<>'cancelled' AND t.is_delayed AND t.dispatch_allowed FOR UPDATE OF o;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','automatic_recovery_slot_unverified');END IF;
 dep:=f.effective_departure_utc;arr:=f.effective_arrival_utc;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 report_at:=dep-make_interval(mins=>pol.preflight_minutes);end_at:=arr+make_interval(mins=>pol.postflight_minutes);
 IF n>report_at THEN RETURN jsonb_build_object('status','automatic_recovery_reporting_cutoff_passed');END IF;
 SELECT pf.* INTO pl FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.airline_id=pf.airline_id AND b.status='validated_preview' WHERE pf.airline_id=p_airline AND pf.occurrence_id=p_occurrence AND pf.schedule_version=f.schedule_version AND pf.aircraft_inventory_id=f.aircraft_inventory_id AND pf.departure_utc=f.departure_utc AND pf.arrival_utc=f.arrival_utc;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','automatic_recovery_source_plan_missing');END IF;
 SELECT coalesce(array_agg(employee_id ORDER BY employee_id),'{}') INTO orig_ids FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=pl.plan_id AND occurrence_id=p_occurrence;
 -- Scope checked after internal roster selection.
 a:=airlinerra_game.section9_assess_delayed_crew_rotation_v1(p_player,p_airline,p_occurrence);
 IF a->>'status' NOT IN('delayed_crew_duty_windows_fit','delayed_crew_replacement_required','delayed_external_contract_review_required') OR (a->>'employeesAssessed')::int IS DISTINCT FROM cardinality(orig_ids) THEN RETURN jsonb_build_object('status','automatic_recovery_assessment_unverified');END IF;
 FOR e IN SELECT employee_id,seat_role FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=pl.plan_id AND occurrence_id=p_occurrence ORDER BY employee_id LOOP
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(a->'employees') x WHERE x->>'employeeId'=e.employee_id::text AND x->>'role'=e.seat_role AND x->>'status'='duty_window_fits') THEN
 IF e.seat_role='captain' THEN cp:=array_append(cp,e.employee_id);ELSIF e.seat_role='first_officer' THEN fo:=array_append(fo,e.employee_id);ELSE ca:=array_append(ca,e.employee_id);END IF;
 END IF;
 END LOOP;
 needed:=CASE WHEN arr-dep>interval '6 hours' THEN 2 ELSE 1 END;
 minimum:=CASE WHEN f.seat_basis='cargo_zero' OR f.verified_passenger_seats<=19 THEN 0 ELSE (f.verified_passenger_seats+49)/50 END;
 IF f.verified_passenger_seats IS NULL OR needed<cardinality(cp) OR needed<cardinality(fo) OR minimum>f.maximum_cabin_crew OR arr-dep>interval '9 hours 30 minutes' THEN RETURN jsonb_build_object('status','automatic_recovery_staffing_policy_invalid');END IF;
 snap:=airlinerra_game.section9_owned_weekly_crew_input_v1(p_player,p_airline,n);
 IF snap->>'status'<>'weekly_crew_bootstrap_input_preview' OR snap->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' OR (snap->>'invalidOccurrenceCount')::int IS DISTINCT FROM 0 THEN RETURN jsonb_build_object('status','automatic_recovery_input_unverified');END IF;
 IF jsonb_array_length(snap->'pilots')+jsonb_array_length(snap->'cabinMembers')>2000 THEN RETURN jsonb_build_object('status','automatic_recovery_candidate_limit');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.airline_id=p_airline AND m.phase='departed' AND m.actual_event_utc>=n-interval '7 days' AND m.actual_event_utc<=n AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_crew_bindings_v1 b WHERE b.airline_id=p_airline AND b.physical_flight_id=m.flight_occurrence_id)) THEN RETURN jsonb_build_object('status','automatic_recovery_unbound_history');END IF;
 IF cardinality(cp)<needed OR cardinality(fo)<needed OR cardinality(ca)<minimum THEN
 FOR m IN SELECT value FROM jsonb_array_elements((snap->'pilots')||(snap->'cabinMembers')) ORDER BY value->>'id' LOOP
 pid:=(m->>'id')::uuid;IF pid=ANY(orig_ids) OR airlinerra_game.section9_residual_crew_commitment_v1(p_airline,ARRAY[pid],NULL,n) THEN CONTINUE;END IF;
 cap_ok:=false;fo_ok:=false;cab_ok:=false;
 IF m?'permissions' THEN
 SELECT coalesce(bool_or(x->>'captain'='true'),false),coalesce(bool_or(x->>'firstOfficer'='true'),false) INTO cap_ok,fo_ok FROM jsonb_array_elements(m->'permissions') x WHERE x->>'group'=f.qualification_group AND x->>'active'='true' AND (x->>'issued')::date<=(dep AT TIME ZONE (m->>'baseTimezone'))::date AND (x->>'expires')::date>(arr AT TIME ZONE (m->>'baseTimezone'))::date;
 ELSE cab_ok:=m->>'role' IN('flight_attendant','cabin_supervisor','purser');END IF;
 IF NOT(cap_ok OR fo_ok OR cab_ok) THEN CONTINUE;END IF;
 IF (m->>'locationEffectiveUtc')::timestamptz>report_at OR (m->>'employmentFrom')::date>(report_at AT TIME ZONE (m->>'baseTimezone'))::date THEN CONTINUE;END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=s.plan_id AND pf.occurrence_id=s.occurrence_id JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=s.plan_id AND b.status='validated_preview' WHERE s.airline_id=p_airline AND s.employee_id=pid AND pf.occurrence_id<>p_occurrence AND pf.departure_utc>=n) THEN CONTINUE;END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approvals_v1 x WHERE x.airline_id=p_airline AND x.occurrence_id<>p_occurrence AND pid=ANY(x.internal_captains||x.internal_first_officers||x.internal_cabin||x.released_employee_ids) AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 z JOIN airlinerra_game.section9_operated_flight_movements_v1 m ON m.engine_event_id=z.arrived_event_id AND m.airline_id=x.airline_id AND m.phase='arrived' WHERE z.physical_flight_id=x.physical_flight_id AND m.actual_event_utc+interval '30 minutes'<=n)) THEN CONTINUE;END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_unavailability_v1 x WHERE x.airline_id=p_airline AND x.status='active' AND (x.pilot_id=pid OR x.cabin_member_id=pid) AND x.start_utc<end_at AND x.end_utc>report_at) THEN CONTINUE;END IF;
 h:=airlinerra_game.section9_crew_actual_history_v1(p_airline,pid,n);
 IF h->>'availableForNewDuty' IS DISTINCT FROM 'true' THEN CONTINUE;END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('dutyStartUtc',j->'startUtc','dutyEndUtc',j->'endUtc','startingAirport',j->'origin','endingAirport',j->'destination') ORDER BY ord),'[]') INTO prior FROM jsonb_array_elements(h->'history') WITH ORDINALITY x(j,ord);
 rot:=jsonb_build_object('status','rotation_preview','dutyStartUtc',report_at,'dutyEndUtc',end_at,'startingAirport',f.origin_airport_key,'endingAirport',f.destination_airport_key);
 fit:=airlinerra_game.section9_crew_duty_fit_v2(rot,prior,m->>'baseTimezone',m->>'initialAirport');
 IF fit->>'eligible' IS DISTINCT FROM 'true' THEN CONTINUE;END IF;
 IF cab_ok THEN cabin_ids:=array_append(cabin_ids,pid);ELSIF cap_ok AND fo_ok THEN dual_ids:=array_append(dual_ids,pid);ELSIF cap_ok THEN cap_only:=array_append(cap_only,pid);ELSE fo_only:=array_append(fo_only,pid);END IF;
 END LOOP;
 FOREACH pid IN ARRAY cap_only LOOP EXIT WHEN cardinality(cp)>=needed;cp:=array_append(cp,pid);END LOOP;
 FOREACH pid IN ARRAY fo_only LOOP EXIT WHEN cardinality(fo)>=needed;fo:=array_append(fo,pid);END LOOP;
 FOREACH pid IN ARRAY dual_ids LOOP IF cardinality(cp)<needed THEN cp:=array_append(cp,pid);ELSIF cardinality(fo)<needed THEN fo:=array_append(fo,pid);ELSE EXIT;END IF;END LOOP;
 FOREACH pid IN ARRAY cabin_ids LOOP EXIT WHEN cardinality(ca)>=minimum;ca:=array_append(ca,pid);END LOOP;
 END IF;
 ec:=needed-cardinality(cp);ef:=needed-cardinality(fo);ea:=greatest(0,minimum-cardinality(ca));
 IF airlinerra_game.section9_delayed_downstream_scope_v1(p_airline,pl.plan_id,p_occurrence,arr)->>'status' IS DISTINCT FROM 'downstream_scope_verified' AND NOT airlinerra_game.section9_same_duty_continuation_scope_v1(p_airline,pl.plan_id,p_occurrence,dep,arr,cp,fo,ca,ec+ef+ea) THEN
 residual:=airlinerra_game.section9_residual_replacement_proof_v1(p_player,p_airline,pl.plan_id,p_occurrence,dep,arr,cp,fo,ca,ec,ef,ea);
 IF residual->>'status' IS DISTINCT FROM 'residual_replacement_verified' THEN RETURN jsonb_build_object('status','automatic_recovery_downstream_rotation_required','residualReason',residual->>'status');END IF;
 END IF;
 v:=airlinerra_game.section9_validate_delayed_crew_roster_v1(p_player,p_airline,p_occurrence,cp,fo,ca,ec,ef,ea);
 IF v->>'status' IS DISTINCT FROM 'delayed_roster_validation_passed' THEN RETURN jsonb_build_object('status',coalesce(v->>'status','automatic_recovery_validation_failed'),'rosterPersisted',false);END IF;
 RETURN jsonb_build_object('status','automatic_terminal_recovery_validated','occurrenceId',p_occurrence,'sourcePlanId',pl.plan_id,'departureUtc',dep,'arrivalUtc',arr,'captains',cp,'firstOfficers',fo,'cabinCrew',ca,'externalCaptains',ec,'externalFirstOfficers',ef,'externalCabin',ea,'quotedCostUsd',v->'quote'->'estimatedCostUsd','combinedQuoteUsd',(v->'quote'->>'estimatedCostUsd')::numeric+coalesce((residual->>'onwardCostUsd')::numeric,0),'internalReserveCount',v->'replacementInternalCrew','internalPriorityVerified',true,'rosterPersisted',false);
END $function$;