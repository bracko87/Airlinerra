-- Same-duty continuity is permitted only for an unchanged, all-internal
-- manifest. Changed crew still require an explicit residual rotation plan.
ALTER TABLE airlinerra_game.section9_delayed_crew_approval_release_v1 ADD COLUMN IF NOT EXISTS same_duty_continuation_enabled boolean NOT NULL DEFAULT false;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_same_duty_continuation_scope_v1(p_airline uuid,p_plan uuid,p_occurrence uuid,p_dep timestamptz,p_arr timestamptz,p_cp uuid[],p_fo uuid[],p_ca uuid[],p_external int)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $b$
DECLARE target record;leg record;pol record;prior_arr timestamptz;airport text;old_cp uuid[];old_fo uuid[];old_ca uuid[];ids uuid[];count_legs int:=0;end_at timestamptz;report_at timestamptz;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approval_release_v1 WHERE world_id=1 AND same_duty_continuation_enabled) OR p_external IS DISTINCT FROM 0 THEN RETURN false;END IF;
 SELECT * INTO target FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE airline_id=p_airline AND plan_id=p_plan AND occurrence_id=p_occurrence;
 IF NOT FOUND OR target.external_captain_count+target.external_first_officer_count+target.external_cabin_count<>0 THEN RETURN false;END IF;
 SELECT coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='captain'),'{}'),coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='first_officer'),'{}'),coalesce(array_agg(employee_id ORDER BY employee_id) FILTER(WHERE seat_role='cabin'),'{}') INTO old_cp,old_fo,old_ca FROM airlinerra_game.section9_planned_crew_seats_v1 WHERE plan_id=p_plan AND airline_id=p_airline AND occurrence_id=p_occurrence;
 IF old_cp IS DISTINCT FROM ARRAY(SELECT x FROM unnest(p_cp)x ORDER BY x) OR old_fo IS DISTINCT FROM ARRAY(SELECT x FROM unnest(p_fo)x ORDER BY x) OR old_ca IS DISTINCT FROM ARRAY(SELECT x FROM unnest(p_ca)x ORDER BY x) THEN RETURN false;END IF;
 ids:=old_cp||old_fo||old_ca;IF cardinality(ids)=0 THEN RETURN false;END IF;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 prior_arr:=p_arr;airport:=target.destination_airport_key;
 -- Every future same-duty leg must have the identical internal roster,
 -- same duty IDs, original timing and continuous airport chain. Reject mixed
 -- separate-duty dependencies here; the ordinary replan handles those.
 FOR leg IN SELECT DISTINCT pf.* FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=s.plan_id AND pf.occurrence_id=s.occurrence_id AND pf.airline_id=s.airline_id WHERE s.plan_id=p_plan AND s.airline_id=p_airline AND s.employee_id=ANY(ids) AND pf.occurrence_id<>p_occurrence AND pf.departure_utc>=target.departure_utc ORDER BY pf.departure_utc,pf.occurrence_id LOOP
 IF leg.origin_airport_key IS DISTINCT FROM airport OR leg.departure_utc<prior_arr+make_interval(mins=>pol.postflight_minutes) OR leg.external_captain_count+leg.external_first_officer_count+leg.external_cabin_count<>0 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o WHERE o.id=leg.occurrence_id AND o.airline_id=p_airline AND o.booking_status<>'cancelled' AND o.schedule_version=leg.schedule_version AND o.departure_utc=leg.departure_utc AND o.arrival_utc=leg.arrival_utc) OR EXISTS(SELECT 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1 x WHERE x.occurrence_id=leg.occurrence_id) THEN RETURN false;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=p_plan AND s.occurrence_id=leg.occurrence_id)<>cardinality(ids) OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=p_plan AND s.occurrence_id=leg.occurrence_id AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 x WHERE x.plan_id=p_plan AND x.occurrence_id=p_occurrence AND x.employee_id=s.employee_id AND x.seat_role=s.seat_role AND x.duty_id=s.duty_id)) THEN RETURN false;END IF;
 prior_arr:=leg.arrival_utc;airport:=leg.destination_airport_key;count_legs:=count_legs+1;
 END LOOP;
 IF count_legs=0 THEN RETURN false;END IF;
 end_at:=prior_arr+make_interval(mins=>pol.postflight_minutes);
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id WHERE s.plan_id=p_plan AND s.occurrence_id=p_occurrence AND (d.actual_release_game_utc IS NOT NULL OR end_at-d.duty_start_utc>make_interval(mins=>pol.maximum_duty_minutes) OR EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_unavailability_v1 u WHERE u.airline_id=p_airline AND u.status='active' AND (u.pilot_id=d.pilot_id OR u.cabin_member_id=d.cabin_member_id) AND u.start_utc<end_at AND u.end_utc>d.duty_start_utc))) THEN RETURN false;END IF;
 RETURN true;
END $b$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_same_duty_continuation_scope_v1(uuid,uuid,uuid,timestamptz,timestamptz,uuid[],uuid[],uuid[],integer) FROM PUBLIC,anon,authenticated,service_role;
-- Verify actual prior roster membership and actual arrival, not merely the
-- existence of a departure/arrival for the aircraft. Map an unchanged
-- delayed projection to its original source duty without resetting it.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_same_duty_prior_sector_v1(p_airline uuid,p_plan uuid,p_occurrence uuid,p_emp uuid,p_next uuid)
RETURNS boolean LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $b$
DECLARE old record;next_leg record;pol record;n timestamptz;actual_arr timestamptz;actual_dep timestamptz;bound_duty uuid;bound_plan uuid;report_at timestamptz;actual_report timestamptz;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT pf.*,s.duty_id,s.seat_role,d.duty_start_utc,d.actual_release_game_utc INTO old FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_planned_crew_seats_v1 s ON s.plan_id=pf.plan_id AND s.occurrence_id=pf.occurrence_id AND s.airline_id=pf.airline_id AND s.employee_id=p_emp JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id WHERE pf.plan_id=p_plan AND pf.airline_id=p_airline AND pf.occurrence_id=p_occurrence;
 IF NOT FOUND OR old.actual_release_game_utc IS NOT NULL THEN RETURN false;END IF;
 SELECT pf.*,s.duty_id,s.seat_role,d.duty_start_utc INTO next_leg FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_planned_crew_seats_v1 s ON s.plan_id=pf.plan_id AND s.occurrence_id=pf.occurrence_id AND s.airline_id=pf.airline_id AND s.employee_id=p_emp JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id WHERE pf.plan_id=p_plan AND pf.airline_id=p_airline AND pf.occurrence_id=p_next;
 IF NOT FOUND OR next_leg.duty_id<>old.duty_id OR next_leg.seat_role<>old.seat_role OR next_leg.origin_airport_key<>old.destination_airport_key THEN RETURN false;END IF;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 SELECT a.actual_event_utc,m.actual_event_utc,b.plan_id,sd.duty_start_utc INTO actual_arr,actual_dep,bound_plan,actual_report
 FROM airlinerra_game.section9_operated_crew_bindings_v1 b
 JOIN airlinerra_game.section9_planned_crew_seats_v1 s ON s.plan_id=b.plan_id AND s.airline_id=b.airline_id AND s.occurrence_id=b.occurrence_id AND s.employee_id=p_emp AND s.seat_role=old.seat_role
 JOIN airlinerra_game.section9_planned_crew_duties_v1 sd ON sd.duty_id=s.duty_id AND sd.plan_id=s.plan_id AND sd.actual_release_game_utc IS NULL
 JOIN airlinerra_game.section9_operated_flight_movements_v1 m ON m.engine_event_id=b.departure_event_id AND m.airline_id=b.airline_id AND m.flight_occurrence_id=b.physical_flight_id AND m.phase='departed' AND m.source_kind='signed_operated_game_flight_v1'
 JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.airline_id=m.airline_id AND a.flight_occurrence_id=m.flight_occurrence_id AND a.phase='arrived' AND a.source_kind='signed_operated_game_flight_v1' AND a.aircraft_inventory_id=m.aircraft_inventory_id AND a.schedule_id=m.schedule_id AND a.schedule_version=m.schedule_version AND a.weekly_entry=m.weekly_entry AND a.flight_local_date=m.flight_local_date AND a.origin_airport_key=m.origin_airport_key AND a.destination_airport_key=m.destination_airport_key
 WHERE b.airline_id=p_airline AND b.occurrence_id=p_occurrence AND b.physical_flight_id=old.physical_flight_id AND m.aircraft_inventory_id=old.aircraft_inventory_id AND m.schedule_version=old.schedule_version AND m.origin_airport_key=old.origin_airport_key AND m.destination_airport_key=old.destination_airport_key
 AND (b.plan_id=p_plan OR EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approvals_v1 ap WHERE ap.approval_id=b.plan_id AND ap.source_plan_id=p_plan AND ap.airline_id=p_airline AND ap.occurrence_id=p_occurrence AND ap.physical_flight_id=b.physical_flight_id AND ap.revised_departure_utc=m.actual_event_utc AND cardinality(ap.released_employee_ids)=0 AND ap.external_captains+ap.external_first_officers+ap.external_cabin=0 AND ap.validation_receipt->>'sameDutyContinuation'='true'));
 IF NOT FOUND OR actual_report IS DISTINCT FROM old.duty_start_utc OR actual_dep<actual_report OR actual_arr<=actual_dep OR actual_arr+make_interval(mins=>pol.postflight_minutes)>next_leg.departure_utc OR next_leg.arrival_utc+make_interval(mins=>pol.postflight_minutes)-actual_report>make_interval(mins=>pol.maximum_duty_minutes) THEN RETURN false;END IF;
 RETURN true;
END $b$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_same_duty_prior_sector_v1(uuid,uuid,uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_plan_terminal_delayed_crew_v1(p_player uuid, p_airline uuid, p_occurrence uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE n timestamptz;f record;pl record;pol record;a jsonb;snap jsonb;m jsonb;e record;h jsonb;prior jsonb;rot jsonb;fit jsonb;cp uuid[]:='{}';fo uuid[]:='{}';ca uuid[]:='{}';orig_ids uuid[];cap_only uuid[]:='{}';fo_only uuid[]:='{}';dual_ids uuid[]:='{}';cabin_ids uuid[]:='{}';pid uuid;cap_ok boolean;fo_ok boolean;cab_ok boolean;dep timestamptz;arr timestamptz;report_at timestamptz;end_at timestamptz;needed int;minimum int;ec int;ef int;ea int;v jsonb;
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
 IF airlinerra_game.section9_delayed_downstream_scope_v1(p_airline,pl.plan_id,p_occurrence,arr)->>'status' IS DISTINCT FROM 'downstream_scope_verified' AND NOT airlinerra_game.section9_same_duty_continuation_scope_v1(p_airline,pl.plan_id,p_occurrence,dep,arr,cp,fo,ca,ec+ef+ea) THEN RETURN jsonb_build_object('status','automatic_recovery_downstream_rotation_required');END IF;
 v:=airlinerra_game.section9_validate_delayed_crew_roster_v1(p_player,p_airline,p_occurrence,cp,fo,ca,ec,ef,ea);
 IF v->>'status' IS DISTINCT FROM 'delayed_roster_validation_passed' THEN RETURN jsonb_build_object('status',coalesce(v->>'status','automatic_recovery_validation_failed'),'rosterPersisted',false);END IF;
 RETURN jsonb_build_object('status','automatic_terminal_recovery_validated','occurrenceId',p_occurrence,'sourcePlanId',pl.plan_id,'departureUtc',dep,'arrivalUtc',arr,'captains',cp,'firstOfficers',fo,'cabinCrew',ca,'externalCaptains',ec,'externalFirstOfficers',ef,'externalCabin',ea,'quotedCostUsd',v->'quote'->'estimatedCostUsd','internalReserveCount',v->'replacementInternalCrew','internalPriorityVerified',true,'rosterPersisted',false);
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
 IF airlinerra_game.section9_delayed_downstream_scope_v1(p_airline,old_plan,p_occurrence,p_expected_arrival)->>'status' IS DISTINCT FROM 'downstream_scope_verified' THEN
 IF NOT airlinerra_game.section9_same_duty_continuation_scope_v1(p_airline,old_plan,p_occurrence,p_expected_departure,p_expected_arrival,cp,fo,fa,p_external_captains+p_external_first_officers+p_external_cabin) THEN RETURN jsonb_build_object('status','replacement_rotation_release_required','saved',false);END IF;
 v:=v||jsonb_build_object('sameDutyContinuation',true);
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
 IF airlinerra_game.section9_delayed_downstream_scope_v1(p_airline,ap.source_plan_id,p_occurrence,ap.revised_arrival_utc)->>'status' IS DISTINCT FROM 'downstream_scope_verified' AND NOT (coalesce(ap.validation_receipt->>'sameDutyContinuation','false')='true' AND airlinerra_game.section9_same_duty_continuation_scope_v1(p_airline,ap.source_plan_id,p_occurrence,ap.revised_departure_utc,ap.revised_arrival_utc,ap.internal_captains,ap.internal_first_officers,ap.internal_cabin,ap.external_captains+ap.external_first_officers+ap.external_cabin)) THEN RETURN jsonb_build_object('status','delayed_binding_multi_sector_replan_required');END IF;
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
 -- Only the exact unchanged roster with a genuine same-duty arrival
 -- can continue without a fresh rolling plan.
 IF ap.validation_receipt->>'sameDutyContinuation'='true' AND EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_plan_batches_v1 b WHERE b.plan_id=ap.source_plan_id AND b.airline_id=p_airline AND b.status='validated_preview') THEN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id=p_occurrence AND s.airline_id=p_airline) OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id=p_occurrence AND s.airline_id=p_airline AND NOT airlinerra_game.section9_same_duty_prior_sector_v1(p_airline,ap.source_plan_id,ap.occurrence_id,s.employee_id,p_occurrence)) THEN RETURN jsonb_build_object('status','downstream_same_duty_continuity_unverified','affected',true);END IF;
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
DECLARE m record;pl record;existing record;seat record;prior record;location record;cps uuid[];fos uuid[];cabin uuid[];outcome jsonb;issue text;external_cabin jsonb;actual_history jsonb;is_rolling boolean;
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
 SELECT pf.* INTO pl FROM airlinerra_game.section9_planned_flight_crews_v1 pf JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pf.plan_id AND b.airline_id=pf.airline_id AND b.status='validated_preview'
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