-- A bounded residual rotation: one unchanged, on-time onward sector
-- with the identical original roster/duty lineage and no other commitments.
ALTER TABLE airlinerra_game.section9_delayed_crew_approval_release_v1 ADD COLUMN IF NOT EXISTS same_duty_replacement_enabled boolean NOT NULL DEFAULT false;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_residual_onward_scope_v1(p_airline uuid,p_plan uuid,p_occurrence uuid,p_arr timestamptz)
RETURNS uuid LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $b$
DECLARE t record;f record;pol record;next_id uuid;cnt int;original_count int;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approval_release_v1 WHERE world_id=1 AND same_duty_replacement_enabled) THEN RETURN NULL;END IF;
 SELECT * INTO t FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE plan_id=p_plan AND airline_id=p_airline AND occurrence_id=p_occurrence;
 IF NOT FOUND OR t.external_captain_count+t.external_first_officer_count+t.external_cabin_count<>0 THEN RETURN NULL;END IF;
 SELECT count(*) INTO original_count FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=p_plan AND occurrence_id=p_occurrence AND airline_id=p_airline;
 IF original_count=0 THEN RETURN NULL;END IF;
 SELECT count(DISTINCT pf.occurrence_id),(array_agg(DISTINCT pf.occurrence_id))[1] INTO cnt,next_id FROM airlinerra_game.section9_planned_crew_seats_v1 orig JOIN airlinerra_game.section9_planned_crew_seats_v1 s ON s.plan_id=orig.plan_id AND s.airline_id=orig.airline_id AND s.employee_id=orig.employee_id AND s.occurrence_id<>orig.occurrence_id JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=s.plan_id AND pf.occurrence_id=s.occurrence_id AND pf.airline_id=s.airline_id WHERE orig.plan_id=p_plan AND orig.airline_id=p_airline AND orig.occurrence_id=p_occurrence AND pf.departure_utc>=t.departure_utc;
 IF cnt<>1 THEN RETURN NULL;END IF;
 SELECT * INTO STRICT f FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE plan_id=p_plan AND occurrence_id=next_id;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 IF f.origin_airport_key<>t.destination_airport_key OR f.departure_utc<p_arr+make_interval(mins=>pol.postflight_minutes) OR f.qualification_group<>t.qualification_group OR f.external_captain_count+f.external_first_officer_count+f.external_cabin_count<>0 OR f.captain_count<>t.captain_count OR f.first_officer_count<>t.first_officer_count OR f.cabin_count<>t.cabin_count THEN RETURN NULL;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=p_plan AND occurrence_id=next_id)<>original_count OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=p_plan AND s.occurrence_id=next_id AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 o WHERE o.plan_id=p_plan AND o.occurrence_id=p_occurrence AND o.employee_id=s.employee_id AND o.seat_role=s.seat_role AND o.duty_id=s.duty_id)) THEN RETURN NULL;END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o JOIN airlinerra_game.airline_flight_schedule_drafts_v1 sc ON sc.id=o.schedule_id AND sc.airline_id=o.airline_id AND sc.version=o.schedule_version AND sc.status='active' AND sc.operationally_verified WHERE o.id=next_id AND o.airline_id=p_airline AND o.booking_status<>'cancelled' AND o.schedule_version=f.schedule_version AND o.aircraft_inventory_id=f.aircraft_inventory_id AND o.departure_utc=f.departure_utc AND o.arrival_utc=f.arrival_utc AND o.origin_airport_key=f.origin_airport_key AND o.destination_airport_key=f.destination_airport_key) OR EXISTS(SELECT 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1 WHERE occurrence_id=next_id) OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE airline_id=p_airline AND flight_occurrence_id=f.physical_flight_id) THEN RETURN NULL;END IF;
 RETURN next_id;
END $b$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_residual_onward_scope_v1(uuid,uuid,uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_residual_replacement_proof_v1(p_player uuid,p_airline uuid,p_plan uuid,p_occurrence uuid,p_dep timestamptz,p_arr timestamptz,p_cp uuid[],p_fo uuid[],p_ca uuid[],p_ec int,p_ef int,p_ea int)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $b$
DECLARE next_id uuid;f record;t record;pol record;snap jsonb;m jsonb;e record;report_at timestamptz;end_at timestamptz;orig record;quote jsonb;fee numeric:=0;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 next_id:=airlinerra_game.section9_residual_onward_scope_v1(p_airline,p_plan,p_occurrence,p_arr);
 IF next_id IS NULL THEN RETURN jsonb_build_object('status','residual_scope_unverified');END IF;
 SELECT * INTO STRICT f FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE plan_id=p_plan AND occurrence_id=next_id;
 SELECT * INTO STRICT t FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE plan_id=p_plan AND occurrence_id=p_occurrence;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 IF cardinality(p_cp)+p_ec<>f.captain_count OR cardinality(p_fo)+p_ef<>f.first_officer_count OR cardinality(p_ca)+p_ea<>f.cabin_count THEN RETURN jsonb_build_object('status','residual_staff_count_unverified');END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=p_plan AND occurrence_id=p_occurrence AND NOT employee_id=ANY(p_cp||p_fo||p_ca)) THEN RETURN jsonb_build_object('status','residual_no_replacement');END IF;
 snap:=airlinerra_game.section9_owned_weekly_crew_input_v1(p_player,p_airline,p_dep);
 IF snap->>'status' IS DISTINCT FROM 'weekly_crew_bootstrap_input_preview' OR snap->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','residual_input_unverified');END IF;
 end_at:=f.arrival_utc+make_interval(mins=>pol.postflight_minutes);
 FOR e IN SELECT x id,'captain' AS role FROM unnest(p_cp)x UNION ALL SELECT x,'first_officer' FROM unnest(p_fo)x UNION ALL SELECT x,'cabin' FROM unnest(p_ca)x LOOP
 SELECT s.seat_role,d.duty_start_utc,d.actual_release_game_utc INTO orig FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id WHERE s.plan_id=p_plan AND s.occurrence_id=p_occurrence AND s.employee_id=e.id;
 IF FOUND THEN
 IF orig.seat_role<>e.role OR orig.actual_release_game_utc IS NOT NULL THEN RETURN jsonb_build_object('status','residual_original_duty_unverified');END IF;
 report_at:=orig.duty_start_utc;
 ELSE report_at:=p_dep-make_interval(mins=>pol.preflight_minutes);END IF;
 IF end_at-report_at>make_interval(mins=>pol.maximum_duty_minutes) THEN RETURN jsonb_build_object('status','residual_duty_limit');END IF;
 SELECT value INTO m FROM jsonb_array_elements((snap->'pilots')||(snap->'cabinMembers')) WHERE value->>'id'=e.id::text;
 IF NOT FOUND OR (m->>'locationEffectiveUtc')::timestamptz>report_at THEN RETURN jsonb_build_object('status','residual_employment_unverified');END IF;
 IF e.role='cabin' THEN
 IF m?'permissions' OR m->>'role' NOT IN('flight_attendant','cabin_supervisor','purser') THEN RETURN jsonb_build_object('status','residual_cabin_role_unverified');END IF;
 ELSE
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(m->'permissions') q WHERE q->>'group'=f.qualification_group AND q->>'active'='true' AND q->>(CASE WHEN e.role='captain' THEN 'captain' ELSE 'firstOfficer' END)='true' AND (q->>'issued')::date<=(f.departure_utc AT TIME ZONE (m->>'baseTimezone'))::date AND (q->>'expires')::date>(f.arrival_utc AT TIME ZONE (m->>'baseTimezone'))::date) THEN RETURN jsonb_build_object('status','residual_qualification_unverified');END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_unavailability_v1 u WHERE u.airline_id=p_airline AND u.status='active' AND (u.pilot_id=e.id OR u.cabin_member_id=e.id) AND u.start_utc<end_at AND u.end_utc>report_at) THEN RETURN jsonb_build_object('status','residual_employee_unavailable');END IF;
 END LOOP;
 IF p_ec+p_ef+p_ea>0 THEN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=next_id AND booking_status='open' AND source_kind='game_verified_saleable_schedule_v1') THEN RETURN jsonb_build_object('status','residual_external_onward_not_saleable');END IF;
 quote:=airlinerra_game.section9_external_crew_quote_v1(p_airline,next_id,p_ec,p_ef,p_ea);
 IF quote->>'status' IS DISTINCT FROM 'external_crew_quote' THEN RETURN jsonb_build_object('status','residual_external_quote_unverified');END IF;
 fee:=(quote->>'estimatedCostUsd')::numeric;
 END IF;
 RETURN jsonb_build_object('status','residual_replacement_verified','onwardOccurrenceId',next_id,'onwardDepartureUtc',f.departure_utc,'onwardArrivalUtc',f.arrival_utc,'onwardCostUsd',fee,'onwardExternalCaptains',p_ec,'onwardExternalFirstOfficers',p_ef,'onwardExternalCabin',p_ea);
END $b$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_residual_replacement_proof_v1(uuid,uuid,uuid,uuid,timestamptz,timestamptz,uuid[],uuid[],uuid[],int,int,int) FROM PUBLIC,anon,authenticated,service_role;

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
 pid:=(m->>'id')::uuid;IF pid=ANY(orig_ids) THEN CONTINUE;END IF;
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
CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_approve_terminal_delayed_crew_v1(p_player uuid, p_airline uuid, p_occurrence uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE v jsonb;r jsonb;ap record;cp uuid[];fo uuid[];ca uuid[];
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approval_release_v1 WHERE world_id=1 AND approval_enabled AND binding_enabled AND automatic_recovery_enabled) OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_movement_capture_release_v1 WHERE world_id=1 AND capture_enabled) THEN RETURN jsonb_build_object('status','automatic_delayed_recovery_disabled','saved',false);END IF;
 SELECT * INTO ap FROM airlinerra_game.section9_delayed_crew_approvals_v1 WHERE airline_id=p_airline AND occurrence_id=p_occurrence;
 IF FOUND THEN RETURN jsonb_build_object('status','automatic_delayed_recovery_existing_approval','saved',false,'approvalId',ap.approval_id);END IF;
 v:=airlinerra_game.section9_plan_terminal_delayed_crew_v1(p_player,p_airline,p_occurrence);
 IF v->>'status' IS DISTINCT FROM 'automatic_terminal_recovery_validated' THEN RETURN jsonb_build_object('status',v->>'status','saved',false);END IF;
 SELECT coalesce(array_agg(x::uuid),'{}') INTO cp FROM jsonb_array_elements_text(v->'captains') x;
 SELECT coalesce(array_agg(x::uuid),'{}') INTO fo FROM jsonb_array_elements_text(v->'firstOfficers') x;
 SELECT coalesce(array_agg(x::uuid),'{}') INTO ca FROM jsonb_array_elements_text(v->'cabinCrew') x;
 r:=airlinerra_game.section9_stage_delayed_crew_approval_v1(p_player,p_airline,p_occurrence,gen_random_uuid(),(v->>'departureUtc')::timestamptz,(v->>'arrivalUtc')::timestamptz,(v->>'combinedQuoteUsd')::numeric,cp,fo,ca,(v->>'externalCaptains')::int,(v->>'externalFirstOfficers')::int,(v->>'externalCabin')::int);
 RETURN r||jsonb_build_object('internalReserveCount',v->'internalReserveCount','externalCaptains',v->'externalCaptains','externalFirstOfficers',v->'externalFirstOfficers','externalCabin',v->'externalCabin','internalPriorityVerified',true);
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
 IF residual->>'status' IS DISTINCT FROM 'residual_replacement_verified' OR (residual-'onwardCostUsd') IS DISTINCT FROM (ap.validation_receipt->'residualReplacement'-'onwardCostUsd') THEN RETURN jsonb_build_object('status','delayed_binding_residual_changed');END IF;
 onward_contract:=airlinerra_game.section9_verified_external_cabin_input_v1(p_airline,(residual->>'onwardOccurrenceId')::uuid);
 IF onward_contract->>'status' IS DISTINCT FROM 'external_cabin_input_verified' OR (onward_contract->>'captainCount')::int<>ap.external_captains OR (onward_contract->>'firstOfficerCount')::int<>ap.external_first_officers OR (onward_contract->>'cabinCount')::int<>ap.external_cabin OR (ap.external_captains+ap.external_first_officers+ap.external_cabin>0 AND onward_contract->>'contractReference' IS DISTINCT FROM 'residual-rotation-v1:'||ap.approval_id) THEN RETURN jsonb_build_object('status','delayed_binding_residual_contract_changed');END IF;
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
CREATE OR REPLACE FUNCTION airlinerra_game.section9_terminal_crew_release_proof_v1(p_airline uuid, p_plan uuid, p_occurrence uuid, p_employee uuid, p_release timestamp with time zone, p_revised_departure timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE duty record;target record;leg record;d record;a record;prev_arr timestamptz;airport text;count_legs integer:=0;pol record;h jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT pf.* INTO target FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.airline_id=pf.airline_id AND b.status='validated_preview' WHERE pf.plan_id=p_plan AND pf.occurrence_id=p_occurrence AND pf.airline_id=p_airline;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','release_source_plan_unverified');END IF;
 SELECT pd.* INTO duty FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 pd ON pd.duty_id=s.duty_id AND pd.plan_id=s.plan_id AND pd.employee_id=s.employee_id AND pd.airline_id=s.airline_id WHERE s.plan_id=p_plan AND s.airline_id=p_airline AND s.occurrence_id=p_occurrence AND s.employee_id=p_employee;
 IF NOT FOUND OR p_release IS NULL OR p_release<duty.duty_start_utc OR p_release>=p_revised_departure THEN RETURN jsonb_build_object('status','release_duty_unverified');END IF;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 IF p_release>p_revised_departure-make_interval(mins=>pol.preflight_minutes) THEN RETURN jsonb_build_object('status','release_replacement_reporting_time_passed');END IF;
 IF airlinerra_game.section9_delayed_downstream_scope_v1(p_airline,p_plan,p_occurrence,p_revised_departure+(target.arrival_utc-target.departure_utc))->>'status' IS DISTINCT FROM 'downstream_scope_verified' AND airlinerra_game.section9_residual_onward_scope_v1(p_airline,p_plan,p_occurrence,p_revised_departure+(target.arrival_utc-target.departure_utc)) IS NULL THEN RETURN jsonb_build_object('status','release_future_rotation_requires_replan');END IF;
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
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_bind_approved_delayed_crew_v1(p_airline uuid, p_occurrence uuid, p_event text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE ap record;pl record;existing record;proof jsonb;d jsonb;duty uuid;emp uuid;role_name text;basis timestamptz;ref text;next_leg record;onward_id uuid;onward_ref text;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO ap FROM airlinerra_game.section9_delayed_crew_approvals_v1 WHERE airline_id=p_airline AND occurrence_id=p_occurrence;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','delayed_binding_approval_missing');END IF;
 SELECT * INTO existing FROM airlinerra_game.section9_operated_crew_bindings_v1 WHERE physical_flight_id=ap.physical_flight_id;
 IF FOUND THEN
 IF existing.airline_id<>p_airline OR existing.plan_id<>ap.approval_id OR existing.departure_event_id<>p_event THEN RAISE EXCEPTION 'DELAYED_CREW_BINDING_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status','approved_delayed_crew_already_bound','replayed',true);
 END IF;
 proof:=airlinerra_game.section9_check_delayed_crew_binding_v1(p_airline,p_occurrence,ap.revised_departure_utc,p_event);
 IF proof->>'status'<>'delayed_crew_binding_ready' THEN RETURN proof;END IF;
 SELECT * INTO STRICT pl FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE plan_id=ap.source_plan_id AND occurrence_id=p_occurrence;
 basis:=date_trunc('day',ap.revised_departure_utc);
 ref:=proof->>'contractReference';
 onward_id:=(ap.validation_receipt->'residualReplacement'->>'onwardOccurrenceId')::uuid;
 IF onward_id IS NOT NULL THEN
 SELECT * INTO STRICT next_leg FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE plan_id=ap.source_plan_id AND occurrence_id=onward_id;
 onward_ref:=CASE WHEN ap.external_captains+ap.external_first_officers+ap.external_cabin>0 THEN 'residual-rotation-v1:'||ap.approval_id END;
 END IF;
 -- This non-current projection is linked exclusively through the actual
 -- signed departure binding. Current-plan uniqueness is preserved.
 INSERT INTO airlinerra_game.section9_crew_plan_batches_v1(plan_id,airline_id,window_start_utc,window_end_utc,source_snapshot,proposed_assignments,status) VALUES(ap.approval_id,p_airline,basis,basis+interval '168 hours',jsonb_build_object('status','delayed_approved_actual_projection','sourcePlanId',ap.source_plan_id),ap.request_payload,'superseded');
 INSERT INTO airlinerra_game.section9_planned_flight_crews_v1(plan_id,airline_id,occurrence_id,schedule_version,aircraft_inventory_id,physical_flight_id,qualification_group,departure_utc,arrival_utc,origin_airport_key,destination_airport_key,captain_count,first_officer_count,cabin_count,external_captain_count,external_first_officer_count,external_cabin_count,external_contract_reference)
 VALUES(ap.approval_id,p_airline,p_occurrence,pl.schedule_version,pl.aircraft_inventory_id,pl.physical_flight_id,pl.qualification_group,ap.revised_departure_utc,ap.revised_arrival_utc,pl.origin_airport_key,pl.destination_airport_key,cardinality(ap.internal_captains),cardinality(ap.internal_first_officers),cardinality(ap.internal_cabin),ap.external_captains,ap.external_first_officers,ap.external_cabin,ref);
 IF onward_id IS NOT NULL THEN
 INSERT INTO airlinerra_game.section9_planned_flight_crews_v1(plan_id,airline_id,occurrence_id,schedule_version,aircraft_inventory_id,physical_flight_id,qualification_group,departure_utc,arrival_utc,origin_airport_key,destination_airport_key,captain_count,first_officer_count,cabin_count,external_captain_count,external_first_officer_count,external_cabin_count,external_contract_reference)
 VALUES(ap.approval_id,p_airline,onward_id,next_leg.schedule_version,next_leg.aircraft_inventory_id,next_leg.physical_flight_id,next_leg.qualification_group,next_leg.departure_utc,next_leg.arrival_utc,next_leg.origin_airport_key,next_leg.destination_airport_key,cardinality(ap.internal_captains),cardinality(ap.internal_first_officers),cardinality(ap.internal_cabin),ap.external_captains,ap.external_first_officers,ap.external_cabin,onward_ref);
 END IF;
 FOR d IN SELECT value FROM jsonb_array_elements(proof->'duties') LOOP
 duty:=gen_random_uuid();emp:=(d->>'employeeId')::uuid;role_name:=d->>'role';
 INSERT INTO airlinerra_game.section9_planned_crew_duties_v1(duty_id,plan_id,airline_id,pilot_id,cabin_member_id,duty_start_utc,duty_end_utc,report_date,starting_airport,ending_airport)
 VALUES(duty,ap.approval_id,p_airline,CASE WHEN role_name<>'cabin' THEN emp END,CASE WHEN role_name='cabin' THEN emp END,(d->>'dutyStartUtc')::timestamptz,(d->>'dutyEndUtc')::timestamptz,(d->>'reportDate')::date,d->>'startingAirport',CASE WHEN onward_id IS NULL THEN pl.destination_airport_key ELSE next_leg.destination_airport_key END);
 INSERT INTO airlinerra_game.section9_planned_crew_seats_v1(plan_id,airline_id,occurrence_id,employee_id,duty_id,seat_role) VALUES(ap.approval_id,p_airline,p_occurrence,emp,duty,role_name);
 IF onward_id IS NOT NULL THEN INSERT INTO airlinerra_game.section9_planned_crew_seats_v1(plan_id,airline_id,occurrence_id,employee_id,duty_id,seat_role) VALUES(ap.approval_id,p_airline,onward_id,emp,duty,role_name);END IF;
 END LOOP;
 INSERT INTO airlinerra_game.section9_pilot_departure_manifests_v1(physical_flight_id,airline_id,departure_event_id,configuration_id,qualification_group,captain_ids,first_officer_ids,external_captain_count,external_first_officer_count,external_cabin_count,external_contract_reference)
 VALUES(ap.physical_flight_id,p_airline,p_event,(proof->>'configurationId')::bigint,pl.qualification_group,ap.internal_captains,ap.internal_first_officers,ap.external_captains,ap.external_first_officers,ap.external_cabin,ref);
 INSERT INTO airlinerra_game.section9_operated_crew_bindings_v1(physical_flight_id,airline_id,plan_id,occurrence_id,departure_event_id,cabin_member_ids,external_cabin_count,external_contract_reference,external_captain_count,external_first_officer_count)
 VALUES(ap.physical_flight_id,p_airline,ap.approval_id,p_occurrence,p_event,ap.internal_cabin,ap.external_cabin,ref,ap.external_captains,ap.external_first_officers);
 RETURN jsonb_build_object('status','approved_delayed_crew_bound','approvalId',ap.approval_id,'externalPilotCount',ap.external_captains+ap.external_first_officers,'externalCabinCount',ap.external_cabin,'replayed',false,'ledgerPosted',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_downstream_crew_reconciliation_v1(p_airline uuid, p_occurrence uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE ap record;cur record;n timestamptz;arrival_at timestamptz;count_ap int:=0;postflight int;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','downstream_airline_missing');END IF;
 n:=airlinerra_game.section9_verified_world_instant_v1();
 SELECT postflight_minutes INTO STRICT postflight FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 FOR ap IN SELECT x.* FROM airlinerra_game.section9_delayed_crew_approvals_v1 x WHERE x.airline_id=p_airline AND x.occurrence_id<>p_occurrence AND EXISTS(
 SELECT 1 FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_planned_crew_seats_v1 s ON s.plan_id=pf.plan_id AND s.occurrence_id=pf.occurrence_id AND s.airline_id=pf.airline_id
 JOIN airlinerra_game.section9_planned_crew_seats_v1 original ON original.plan_id=s.plan_id AND original.airline_id=s.airline_id AND original.employee_id=s.employee_id AND original.occurrence_id=x.occurrence_id
 WHERE pf.plan_id=x.source_plan_id AND pf.airline_id=x.airline_id AND pf.occurrence_id=p_occurrence AND pf.departure_utc>=x.original_departure_utc)
 ORDER BY x.authorized_game_utc,x.approval_id LOOP
 count_ap:=count_ap+1;
 SELECT a.actual_event_utc INTO arrival_at FROM airlinerra_game.section9_operated_crew_bindings_v1 b JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.engine_event_id=b.departure_event_id AND d.airline_id=b.airline_id AND d.flight_occurrence_id=b.physical_flight_id AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1'
 JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.airline_id=d.airline_id AND a.flight_occurrence_id=d.flight_occurrence_id AND a.phase='arrived' AND a.source_kind='signed_operated_game_flight_v1' AND a.aircraft_inventory_id=d.aircraft_inventory_id AND a.schedule_id=d.schedule_id AND a.schedule_version=d.schedule_version AND a.weekly_entry=d.weekly_entry AND a.flight_local_date=d.flight_local_date AND a.origin_airport_key=d.origin_airport_key AND a.destination_airport_key=d.destination_airport_key
 WHERE b.airline_id=p_airline AND b.plan_id=ap.approval_id AND b.occurrence_id=ap.occurrence_id AND b.physical_flight_id=ap.physical_flight_id AND d.actual_event_utc=ap.revised_departure_utc AND a.actual_event_utc>d.actual_event_utc;
 IF NOT FOUND OR n IS NULL OR n<arrival_at+make_interval(mins=>postflight) THEN RETURN jsonb_build_object('status','downstream_waiting_for_actual_arrival','affected',true);END IF;
 IF ap.validation_receipt->'residualReplacement'->>'onwardOccurrenceId'=p_occurrence::text THEN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.airline_id=pf.airline_id AND b.source_snapshot->>'status'='delayed_approved_actual_projection' WHERE pf.plan_id=ap.approval_id AND pf.airline_id=p_airline AND pf.occurrence_id=p_occurrence) OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=ap.approval_id AND s.occurrence_id=p_occurrence AND NOT airlinerra_game.section9_same_duty_prior_sector_v1(p_airline,ap.approval_id,ap.occurrence_id,s.employee_id,p_occurrence)) THEN RETURN jsonb_build_object('status','downstream_residual_continuity_unverified','affected',true);END IF;
 CONTINUE;
 END IF;
 -- Only the exact unchanged roster with a genuine same-duty arrival
 -- can continue without a fresh rolling plan.
 IF ap.validation_receipt->>'sameDutyContinuation'='true' AND EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_plan_batches_v1 b WHERE b.plan_id=ap.source_plan_id AND b.airline_id=p_airline AND b.status='validated_preview') THEN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id=p_occurrence AND s.airline_id=p_airline) OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id=p_occurrence AND s.airline_id=p_airline AND NOT coalesce((SELECT airlinerra_game.section9_same_duty_prior_sector_v1(p_airline,ap.source_plan_id,prev.occurrence_id,s.employee_id,p_occurrence) FROM airlinerra_game.section9_planned_crew_seats_v1 ps JOIN airlinerra_game.section9_planned_flight_crews_v1 prev ON prev.plan_id=ps.plan_id AND prev.occurrence_id=ps.occurrence_id AND prev.airline_id=ps.airline_id JOIN airlinerra_game.section9_planned_flight_crews_v1 cur_leg ON cur_leg.plan_id=s.plan_id AND cur_leg.occurrence_id=s.occurrence_id WHERE ps.plan_id=s.plan_id AND ps.airline_id=s.airline_id AND ps.employee_id=s.employee_id AND ps.duty_id=s.duty_id AND prev.departure_utc<cur_leg.departure_utc ORDER BY prev.departure_utc DESC,prev.occurrence_id LIMIT 1),false)) THEN RETURN jsonb_build_object('status','downstream_same_duty_continuity_unverified','affected',true);END IF;
 CONTINUE;
 END IF;
 SELECT b.plan_id,b.source_snapshot INTO cur FROM airlinerra_game.section9_crew_plan_batches_v1 b JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=b.plan_id AND pf.airline_id=b.airline_id AND pf.occurrence_id=p_occurrence WHERE b.airline_id=p_airline AND b.status='validated_preview';
 IF NOT FOUND OR cur.plan_id=ap.source_plan_id OR cur.source_snapshot->>'status' IS DISTINCT FROM 'rolling_crew_input_preview' OR (cur.source_snapshot->>'planningCutoffUtc')::timestamptz<arrival_at+make_interval(mins=>postflight) THEN RETURN jsonb_build_object('status','downstream_rolling_replan_required','affected',true);END IF;
 END LOOP;
 RETURN jsonb_build_object('status',CASE WHEN count_ap>0 THEN 'downstream_crew_reconciled' ELSE 'downstream_unaffected' END,'affected',count_ap>0,'dependencies',count_ap);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_capture_dispatched_crew_v1(p_airline uuid, p_physical text, p_event text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE m record;pl record;existing record;seat record;prior record;location record;cps uuid[];fos uuid[];cabin uuid[];outcome jsonb;issue text;external_cabin jsonb;actual_history jsonb;is_rolling boolean;residual_plan uuid;residual_occ uuid;residual_proof jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_movement_capture_release_v1 WHERE world_id=1 AND capture_enabled) THEN RETURN jsonb_build_object('status','crew_capture_disabled');END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT d.*,r.configuration_id INTO m FROM airlinerra_game.section9_operated_flight_movements_v1 d JOIN airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 r ON r.departure_engine_event_id=d.engine_event_id AND r.physical_flight_id=d.flight_occurrence_id AND r.airline_id=d.airline_id AND r.aircraft_inventory_id=d.aircraft_inventory_id
 WHERE d.engine_event_id=p_event AND d.flight_occurrence_id=p_physical AND d.airline_id=p_airline AND d.world_id=1 AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1' AND d.schedule_id IS NOT NULL;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','crew_departure_evidence_missing');END IF;
 SELECT * INTO existing FROM airlinerra_game.section9_operated_crew_bindings_v1 WHERE physical_flight_id=p_physical;
 IF FOUND THEN
 IF existing.airline_id<>p_airline OR existing.departure_event_id<>p_event THEN RAISE EXCEPTION 'CREW_BINDING_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status','crew_departure_already_bound','replayed',true);
 END IF;
 SELECT ap.approval_id,o.id INTO residual_plan,residual_occ FROM airlinerra_game.section9_delayed_crew_approvals_v1 ap JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=(ap.validation_receipt->'residualReplacement'->>'onwardOccurrenceId')::uuid AND o.airline_id=ap.airline_id WHERE ap.airline_id=p_airline AND o.schedule_id=m.schedule_id AND o.flight_local_date=m.flight_local_date AND o.weekly_entry=m.weekly_entry;
 IF FOUND THEN
 residual_proof:=airlinerra_game.section9_downstream_crew_reconciliation_v1(p_airline,residual_occ);
 IF residual_proof->>'status' IS DISTINCT FROM 'downstream_crew_reconciled' THEN RETURN jsonb_build_object('status','crew_residual_continuity_unverified');END IF;
 END IF;
 SELECT pf.* INTO pl FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.airline_id=pf.airline_id AND ((residual_plan IS NULL AND b.status='validated_preview') OR (b.plan_id=residual_plan AND b.status='superseded' AND b.source_snapshot->>'status'='delayed_approved_actual_projection'))
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=pf.occurrence_id AND o.airline_id=pf.airline_id AND o.schedule_id=m.schedule_id AND o.schedule_version=pf.schedule_version AND o.flight_local_date=m.flight_local_date AND o.weekly_entry=m.weekly_entry AND o.booking_status<>'cancelled' AND o.departure_utc=pf.departure_utc AND o.arrival_utc=pf.arrival_utc
 JOIN airlinerra_game.section9_flight_crew_model_policy_v1 pol ON pol.configuration_id=m.configuration_id AND pol.qualification_group=pf.qualification_group
 WHERE pf.airline_id=p_airline AND pf.physical_flight_id=p_physical AND pf.schedule_version=m.schedule_version AND pf.aircraft_inventory_id=m.aircraft_inventory_id AND pf.origin_airport_key=m.origin_airport_key AND pf.destination_airport_key=m.destination_airport_key AND pf.departure_utc=m.scheduled_departure_utc AND pf.arrival_utc=m.scheduled_arrival_utc;
 IF NOT FOUND THEN issue:='crew_current_plan_missing';
 ELSIF m.actual_event_utc<>pl.departure_utc THEN issue:='crew_delayed_rotation_requires_replan';
 END IF;
 IF issue IS NULL THEN
 SELECT coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='captain'),'{}'),coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='first_officer'),'{}'),coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='cabin'),'{}') INTO cps,fos,cabin FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=pl.plan_id AND occurrence_id=pl.occurrence_id;
 IF cardinality(cps)<>pl.captain_count OR cardinality(fos)<>pl.first_officer_count OR cardinality(cabin)<>pl.cabin_count THEN issue:='crew_seat_count_changed';END IF;
 END IF;
 IF issue IS NULL THEN
 external_cabin:=airlinerra_game.section9_verified_external_cabin_input_v1(p_airline,pl.occurrence_id);
 IF external_cabin->>'status'<>'external_cabin_input_verified' OR (external_cabin->>'cabinCount')::int IS DISTINCT FROM pl.external_cabin_count OR (external_cabin->>'captainCount')::int IS DISTINCT FROM pl.external_captain_count OR (external_cabin->>'firstOfficerCount')::int IS DISTINCT FROM pl.external_first_officer_count OR external_cabin->>'contractReference' IS DISTINCT FROM pl.external_contract_reference
 OR NOT airlinerra_game.section9_pilot_counts_valid_v1(CASE WHEN m.scheduled_arrival_utc-m.scheduled_departure_utc>interval '6 hours' THEN 2 ELSE 1 END,cardinality(cps),cardinality(fos),pl.external_captain_count,pl.external_first_officer_count)
 OR NOT airlinerra_game.section9_cabin_composition_valid_v1(m.configuration_id,(SELECT verified_passenger_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=pl.occurrence_id AND airline_id=p_airline),cardinality(cabin),pl.external_cabin_count) THEN issue:='crew_external_cabin_or_staffing_changed';END IF;
 END IF;
 IF issue IS NULL THEN
 SELECT source_snapshot->>'status'='rolling_crew_input_preview' INTO is_rolling FROM airlinerra_game.section9_crew_plan_batches_v1 WHERE plan_id=pl.plan_id AND airline_id=p_airline;
 FOR seat IN SELECT s.employee_id,s.seat_role,d.pilot_id,d.cabin_member_id,d.duty_id,d.duty_start_utc,d.duty_end_utc
 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id AND d.airline_id=s.airline_id AND d.employee_id=s.employee_id WHERE s.plan_id=pl.plan_id AND s.occurrence_id=pl.occurrence_id LOOP
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_unavailability_v1 a WHERE a.airline_id=p_airline AND a.status='active' AND (a.pilot_id=seat.pilot_id OR a.cabin_member_id=seat.cabin_member_id) AND a.start_utc<seat.duty_end_utc AND a.end_utc>seat.duty_start_utc) THEN issue:='crew_employee_unavailable';EXIT;END IF;
 IF seat.seat_role='cabin' THEN
 SELECT c.initial_airport_key,c.location_effective_utc,ap.timezone_iana INTO location FROM airlinerra_game.section9_cabin_crew_members_v1 c JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=c.world_id AND ap.airport_key=c.base_airport_key WHERE c.airline_id=p_airline AND c.member_id=seat.cabin_member_id AND c.employment_status='employed' AND c.role IN('flight_attendant','cabin_supervisor','purser') AND c.effective_game_date<=(seat.duty_start_utc AT TIME ZONE ap.timezone_iana)::date;
 ELSE
 SELECT b.initial_airport_key,b.location_effective_utc,ap.timezone_iana INTO location FROM airlinerra_game.section9_pilot_profiles_v1 pr JOIN airlinerra_game.section9_airline_crew_roster_v1 r ON r.airline_id=pr.airline_id AND r.crew_id=pr.crew_id
 JOIN airlinerra_game.section9_pilot_base_assignments_v1 b ON b.airline_id=pr.airline_id AND b.crew_id=pr.crew_id
 JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=b.world_id AND ap.airport_key=b.base_airport_key
 JOIN airlinerra_game.section9_pilot_family_permissions_v1 q ON q.airline_id=pr.airline_id AND q.crew_id=pr.crew_id AND q.qualification_group=pl.qualification_group
 WHERE pr.airline_id=p_airline AND pr.crew_id=seat.pilot_id AND r.employment_status='verified_employed' AND r.game_effective_date<=(seat.duty_start_utc AT TIME ZONE ap.timezone_iana)::date AND q.qualification_status='active'
 AND q.issued_game_date<=(pl.departure_utc AT TIME ZONE ap.timezone_iana)::date AND q.expires_game_date>(pl.arrival_utc AT TIME ZONE ap.timezone_iana)::date
 AND airlinerra_game.section9_pilot_can_fill_rank_v1(pr.career_rank,q.captain_permission,q.first_officer_permission,seat.seat_role);
 END IF;
 IF NOT FOUND OR location.location_effective_utc>seat.duty_start_utc THEN issue:='crew_employment_or_qualification_changed';EXIT;END IF;
 -- Every prior planned leg must have genuinely operated with this roster.
 -- Full actual duty history and disruption reallocation are phase 14G.
 SELECT pf.*,ps.duty_id AS prior_duty_id,pd.duty_end_utc AS prior_duty_end INTO prior FROM airlinerra_game.section9_planned_crew_seats_v1 ps JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=ps.plan_id AND pf.occurrence_id=ps.occurrence_id JOIN airlinerra_game.section9_planned_crew_duties_v1 pd ON pd.duty_id=ps.duty_id
 WHERE ps.plan_id=pl.plan_id AND ps.employee_id=seat.employee_id AND pf.departure_utc<pl.departure_utc ORDER BY pf.departure_utc DESC LIMIT 1;
 IF FOUND THEN
 IF NOT (CASE WHEN prior.prior_duty_id=seat.duty_id THEN airlinerra_game.section9_same_duty_prior_sector_v1(p_airline,pl.plan_id,prior.occurrence_id,seat.employee_id,pl.occurrence_id) ELSE EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_crew_bindings_v1 b JOIN airlinerra_game.section9_planned_crew_seats_v1 s ON s.plan_id=b.plan_id AND s.occurrence_id=b.occurrence_id AND s.airline_id=b.airline_id AND s.employee_id=seat.employee_id JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.flight_occurrence_id=b.physical_flight_id AND a.airline_id=b.airline_id AND a.phase='arrived' AND a.source_kind='signed_operated_game_flight_v1' AND a.destination_airport_key=pl.origin_airport_key WHERE b.plan_id=prior.plan_id AND b.occurrence_id=prior.occurrence_id AND a.actual_event_utc<=pl.departure_utc AND greatest(prior.prior_duty_end,a.actual_event_utc+interval '30 minutes')+interval '12 hours'<=seat.duty_start_utc) END)
 THEN issue:='crew_prior_arrival_or_rest_unverified';EXIT;END IF;
 ELSIF is_rolling THEN
 -- First leg of a replacement plan: previous operated duties may belong to
 -- superseded plans. Their actual arrival and rest are authoritative.
 actual_history:=airlinerra_game.section9_crew_actual_history_v1(p_airline,seat.employee_id,m.actual_event_utc);
 IF actual_history->>'availableForNewDuty' IS DISTINCT FROM 'true'
 OR coalesce(actual_history->>'lastAirport',location.initial_airport_key) IS DISTINCT FROM pl.origin_airport_key
 OR (actual_history->>'lastDutyEndUtc' IS NOT NULL AND (actual_history->>'lastDutyEndUtc')::timestamptz+interval '12 hours'>seat.duty_start_utc)
 THEN issue:='crew_actual_history_or_rest_unverified';EXIT;END IF;
 ELSIF location.initial_airport_key<>pl.origin_airport_key THEN issue:='crew_initial_airport_mismatch';EXIT;
 END IF;
 END LOOP;
 END IF;
 IF issue IS NULL THEN
 outcome:=airlinerra_game.section9_record_pilot_departure_manifest_v1(p_airline,p_physical,cps,fos);
 IF outcome->>'status' NOT IN('pilot_manifest_recorded','manifest_already_recorded') THEN issue:=coalesce(outcome->>'status','crew_manifest_unverified');
 ELSIF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_pilot_departure_manifests_v1 pm WHERE pm.physical_flight_id=p_physical AND pm.airline_id=p_airline AND pm.departure_event_id=p_event AND pm.external_captain_count=pl.external_captain_count AND pm.external_first_officer_count=pl.external_first_officer_count AND pm.external_cabin_count=pl.external_cabin_count AND pm.external_contract_reference IS NOT DISTINCT FROM pl.external_contract_reference) THEN issue:='crew_manifest_contract_mismatch';
 ELSE
 INSERT INTO airlinerra_game.section9_operated_crew_bindings_v1(physical_flight_id,airline_id,plan_id,occurrence_id,departure_event_id,cabin_member_ids,external_cabin_count,external_contract_reference,external_captain_count,external_first_officer_count) VALUES(p_physical,p_airline,pl.plan_id,pl.occurrence_id,p_event,cabin,pl.external_cabin_count,pl.external_contract_reference,pl.external_captain_count,pl.external_first_officer_count);
 RETURN jsonb_build_object('status','crew_departure_bound','pilotCount',cardinality(cps)+cardinality(fos)+pl.external_captain_count+pl.external_first_officer_count,'internalPilotCount',cardinality(cps)+cardinality(fos),'externalPilotCount',pl.external_captain_count+pl.external_first_officer_count,'cabinCount',cardinality(cabin)+pl.external_cabin_count,'internalCabinCount',cardinality(cabin),'externalCabinCount',pl.external_cabin_count,'replayed',false);
 END IF;
 END IF;
 INSERT INTO airlinerra_game.section9_operated_crew_capture_issues_v1(engine_event_id,airline_id,physical_flight_id,issue_code) VALUES(p_event,p_airline,p_physical,issue) ON CONFLICT(engine_event_id) DO NOTHING;
 RETURN jsonb_build_object('status',issue,'crewCancellationTriggered',false);
END $function$;