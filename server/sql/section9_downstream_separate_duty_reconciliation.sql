-- Later, separate duties may be replanned after the delayed sector actually
-- completes. Never silently detach an onward sector in the same duty.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_delayed_downstream_scope_v1(p_airline uuid,p_plan uuid,p_occurrence uuid,p_revised_arrival timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $b$
DECLARE target record;later record;ids uuid[]:='{}';postflight int;n timestamptz;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO target FROM airlinerra_game.section9_planned_flight_crews_v1 WHERE airline_id=p_airline AND plan_id=p_plan AND occurrence_id=p_occurrence;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','downstream_source_missing');END IF;
 SELECT postflight_minutes INTO STRICT postflight FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 n:=airlinerra_game.section9_verified_world_instant_v1();
 FOR later IN SELECT DISTINCT pf.occurrence_id,pf.departure_utc,d.duty_start_utc,(s.duty_id=original.duty_id) same_duty
 FROM airlinerra_game.section9_planned_crew_seats_v1 original JOIN airlinerra_game.section9_planned_crew_seats_v1 s ON s.plan_id=original.plan_id AND s.airline_id=original.airline_id AND s.employee_id=original.employee_id AND s.occurrence_id<>original.occurrence_id
 JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=s.plan_id AND pf.occurrence_id=s.occurrence_id AND pf.airline_id=s.airline_id
 JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id AND d.airline_id=s.airline_id
 WHERE original.airline_id=p_airline AND original.plan_id=p_plan AND original.occurrence_id=p_occurrence AND pf.departure_utc>=target.departure_utc
 ORDER BY pf.departure_utc,pf.occurrence_id LOOP
 IF later.same_duty OR later.duty_start_utc<=greatest(n,p_revised_arrival+make_interval(mins=>postflight)) THEN RETURN jsonb_build_object('status','downstream_active_rotation_requires_replan');END IF;
 IF NOT later.occurrence_id=ANY(ids) THEN ids:=array_append(ids,later.occurrence_id);END IF;
 END LOOP;
 RETURN jsonb_build_object('status','downstream_scope_verified','affectedOccurrences',ids,'affectedCount',cardinality(ids));
END $b$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_delayed_downstream_scope_v1(uuid,uuid,uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
-- Holds are derived from the immutable approval and old plan, never from
-- mutable client state; even a bootstrap preview cannot clear them.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_downstream_crew_reconciliation_v1(p_airline uuid,p_occurrence uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $b$
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
 SELECT b.plan_id,b.source_snapshot INTO cur FROM airlinerra_game.section9_crew_plan_batches_v1 b JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=b.plan_id AND pf.airline_id=b.airline_id AND pf.occurrence_id=p_occurrence WHERE b.airline_id=p_airline AND b.status='validated_preview';
 IF NOT FOUND OR cur.plan_id=ap.source_plan_id OR cur.source_snapshot->>'status' IS DISTINCT FROM 'rolling_crew_input_preview' OR (cur.source_snapshot->>'planningCutoffUtc')::timestamptz<arrival_at+make_interval(mins=>postflight) THEN RETURN jsonb_build_object('status','downstream_rolling_replan_required','affected',true);END IF;
 END LOOP;
 RETURN jsonb_build_object('status',CASE WHEN count_ap>0 THEN 'downstream_crew_reconciled' ELSE 'downstream_unaffected' END,'affected',count_ap>0,'dependencies',count_ap);
END $b$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_downstream_crew_reconciliation_v1(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

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
 IF airlinerra_game.section9_delayed_downstream_scope_v1(p_airline,pl.plan_id,p_occurrence,arr)->>'status' IS DISTINCT FROM 'downstream_scope_verified' THEN RETURN jsonb_build_object('status','automatic_recovery_downstream_rotation_required');END IF;
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
 v:=airlinerra_game.section9_validate_delayed_crew_roster_v1(p_player,p_airline,p_occurrence,cp,fo,ca,ec,ef,ea);
 IF v->>'status' IS DISTINCT FROM 'delayed_roster_validation_passed' THEN RETURN jsonb_build_object('status',coalesce(v->>'status','automatic_recovery_validation_failed'),'rosterPersisted',false);END IF;
 RETURN jsonb_build_object('status','automatic_terminal_recovery_validated','occurrenceId',p_occurrence,'sourcePlanId',pl.plan_id,'departureUtc',dep,'arrivalUtc',arr,'captains',cp,'firstOfficers',fo,'cabinCrew',ca,'externalCaptains',ec,'externalFirstOfficers',ef,'externalCabin',ea,'quotedCostUsd',v->'quote'->'estimatedCostUsd','internalReserveCount',v->'replacementInternalCrew','internalPriorityVerified',true,'rosterPersisted',false);
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
 IF airlinerra_game.section9_delayed_downstream_scope_v1(p_airline,ap.source_plan_id,p_occurrence,ap.revised_arrival_utc)->>'status' IS DISTINCT FROM 'downstream_scope_verified' THEN RETURN jsonb_build_object('status','delayed_binding_multi_sector_replan_required');END IF;
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
 IF airlinerra_game.section9_delayed_downstream_scope_v1(p_airline,old_plan,p_occurrence,p_expected_arrival)->>'status' IS DISTINCT FROM 'downstream_scope_verified' THEN RETURN jsonb_build_object('status','replacement_rotation_release_required','saved',false);END IF;
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
 IF airlinerra_game.section9_delayed_downstream_scope_v1(p_airline,p_plan,p_occurrence,p_revised_departure+(target.arrival_utc-target.departure_utc))->>'status' IS DISTINCT FROM 'downstream_scope_verified' THEN RETURN jsonb_build_object('status','release_future_rotation_requires_replan');END IF;
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
CREATE OR REPLACE FUNCTION airlinerra_game.section9_save_owned_crew_plan_preview_v1(p_player uuid, p_airline uuid, p_plan uuid, p_start timestamp with time zone, p_snapshot jsonb, p_assignments jsonb)
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
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approvals_v1 WHERE airline_id=p_airline) THEN RETURN jsonb_build_object('status','crew_rolling_replan_required_after_delayed_approval','saved',false);END IF;
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
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_dispatch_due_flight_events_v1(p_limit integer DEFAULT 40)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 clock_proof jsonb;now_utc timestamptz;
 activation record;execution record;engine record;
 evt record;matches jsonb;candidate jsonb;
 maintenance jsonb;movement jsonb;airframe_usage jsonb;fuel_check jsonb;fuel_receipt jsonb;fuel_supply jsonb;
 required_permission_code text;movement_event_id text;
 signer_key text;payload text;event_signature text;
 used integer:=0;departures integer:=0;arrivals integer:=0;
 blocked integer:=0;reason text;warnings jsonb:='{}'::jsonb;
 changed integer:=0;disruption_result jsonb;crew_capture jsonb;crew_capture_counts jsonb:='{}'::jsonb;crew_code text;turnaround_result jsonb;turnaround_counts jsonb:='{}'::jsonb;turnaround_code text;
 delayed_binding_required boolean;delayed_crew_check jsonb;automatic_crew_recovery jsonb;downstream_proof jsonb;downstream_required boolean;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_TRUSTED_DISPATCH_POSTGRES_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_DISPATCH_LIMIT_INVALID';END IF;
 clock_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true' THEN
  RETURN jsonb_build_object('status','blocked_game_hour_not_verified',
   'eventsDispatched',0,'ledgerPosted',false,'movementRecorded',false);END IF;
 now_utc:=(clock_proof->>'gameHourUtc')::timestamptz;
 SELECT * INTO activation
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT * INTO execution
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO engine
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF activation.release_state IS DISTINCT FROM 'enabled'
 OR activation.crew_mode IS DISTINCT FROM 'deferred_phase1'
 OR activation.enabled_at IS NULL
 OR execution.release_state IS DISTINCT FROM 'enabled'
 OR execution.enabled_at IS NULL
 OR engine.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_flight_engine_release',
   'eventsDispatched',0,'ledgerPosted',false,'movementRecorded',false);END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583729,10041) THEN
  RETURN jsonb_build_object('status','flight_dispatch_already_running',
   'eventsDispatched',0,'ledgerPosted',false,'movementRecorded',false);END IF;
 SELECT decrypted_secret INTO signer_key FROM vault.decrypted_secrets
 WHERE name='airlinerra_operated_flight_auto_signing_v1';
 IF signer_key IS NULL OR length(signer_key)<64 THEN
  RETURN jsonb_build_object('status','blocked_missing_private_event_signer',
   'eventsDispatched',0,'ledgerPosted',false,'movementRecorded',false);END IF;

 disruption_result:=airlinerra_game.section9_auto_disruption_cycle_v1(p_limit);
 automatic_crew_recovery:=airlinerra_game.section9_auto_recover_delayed_crew_cycle_v1(least(p_limit,20));
 FOR evt IN
  SELECT o.id AS occurrence_id,o.schedule_id,o.airline_id,
   o.aircraft_inventory_id,o.schedule_version,o.flight_local_date,
   o.weekly_entry,o.departure_utc,o.arrival_utc,o.booking_status,
   o.booked_seats,o.verified_passenger_seats,
   o.origin_airport_key,o.destination_airport_key,
   o.schedule_id::text||':'||o.flight_local_date::text||':'||
     o.weekly_entry::text physical_id,
   s.reference_departure_utc,s.reference_arrival_utc,
   s.version as schedule_version_current,s.configuration_id,
   fleet.fleet_status,fleet.ownership_type,fleet.configuration_id AS fleet_configuration,
   conf.use_type,
   airline.owner_player_id,
   a_home.country_iso as home_country,
   a_origin.country_iso as origin_country,
   a_dest.country_iso as destination_country,
   cap.passenger_capacity,cap.passengers_held,
   cap.schedule_version AS capacity_version,
   cap.commercial_version AS capacity_commercial_version,
   cap.departure_utc AS capacity_departure_utc,
   cap.arrival_utc AS capacity_arrival_utc,
   plan.version AS plan_version,
   phase.phase,phase.event_time,phase.original_event_time,
   timing.effective_departure_utc,timing.effective_arrival_utc,timing.is_delayed,
   (
    SELECT count(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1 c
    WHERE c.schedule_id=o.schedule_id
    AND c.airline_id=o.airline_id
    AND c.schedule_version=o.schedule_version
    AND c.review_status='certified'
    AND c.valid_from_game_date<=o.flight_local_date
    AND c.valid_to_game_date>=o.flight_local_date
   ) as certification_count
  FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
  JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
   ON s.id=o.schedule_id AND s.airline_id=o.airline_id
    AND s.version=o.schedule_version AND s.status='active'
    AND s.operationally_verified=true
  JOIN airlinerra_game.airline_aircraft_inventory fleet
   ON fleet.id=o.aircraft_inventory_id
    AND fleet.airline_id=o.airline_id
  JOIN airlinerra.aircraft_catalog_configuration_inventory conf
   ON conf.configuration_id=s.configuration_id
  JOIN airlinerra_game.airlines airline ON airline.id=o.airline_id
  LEFT JOIN airlinerra_game.airport_reference_profiles a_home
   ON a_home.world_id=1 AND a_home.airport_key=airline.home_airport_key
  LEFT JOIN airlinerra_game.airport_reference_profiles a_origin
   ON a_origin.world_id=1 AND a_origin.airport_key=o.origin_airport_key
  LEFT JOIN airlinerra_game.airport_reference_profiles a_dest
   ON a_dest.world_id=1 AND a_dest.airport_key=o.destination_airport_key
  LEFT JOIN airlinerra_game.section9_occurrence_capacity_inventory_v1 cap
   ON cap.physical_flight_id=o.schedule_id::text||':'||
      o.flight_local_date::text||':'||o.weekly_entry::text
  LEFT JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
   ON plan.schedule_id=o.schedule_id AND plan.airline_id=o.airline_id
  CROSS JOIN LATERAL airlinerra_game.section9_effective_dispatch_window_v1(o.id) timing
  CROSS JOIN LATERAL(VALUES('departed'::text,timing.effective_departure_utc,o.departure_utc),
                            ('arrived'::text,timing.effective_arrival_utc,o.arrival_utc)) phase(phase,event_time,original_event_time)
  WHERE o.world_id=1
   AND o.source_kind='game_verified_saleable_schedule_v1'
   AND o.booking_status IN('open','closed')
   AND timing.dispatch_allowed
   AND (phase.phase='arrived' OR airlinerra_game.section9_disruption_departure_clear_v1(o.id))
   AND (phase.event_time>now_utc-interval '10 minutes'
        OR (airlinerra_game.section9_automatic_disruption_ready_v1()
            AND phase.phase='arrived'
            AND phase.event_time>now_utc-interval '24 hours'
            AND EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 departed
              WHERE departed.flight_occurrence_id=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text
              AND departed.phase='departed')))
   AND phase.event_time<=now_utc
   AND NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
    WHERE m.flight_occurrence_id=o.schedule_id::text||':'||
      o.flight_local_date::text||':'||o.weekly_entry::text
      AND m.phase=phase.phase)
  ORDER BY phase.event_time,o.schedule_id,o.flight_local_date,o.weekly_entry,phase.phase
  LIMIT p_limit
 LOOP
  used:=used+1;reason:=NULL;
  IF evt.owner_player_id IS NULL
   OR evt.fleet_status<>'in_service'
   OR evt.ownership_type NOT IN ('owned','leased')
   OR evt.fleet_configuration IS DISTINCT FROM evt.configuration_id
   OR evt.use_type<>'passenger'
   OR evt.reference_arrival_utc<=evt.reference_departure_utc
   OR evt.verified_passenger_seats IS NULL
   OR evt.verified_passenger_seats<1
   OR evt.booked_seats>evt.verified_passenger_seats
   OR evt.passenger_capacity IS DISTINCT FROM evt.verified_passenger_seats
   OR evt.passengers_held<evt.booked_seats
   OR evt.passengers_held>evt.passenger_capacity
   OR evt.capacity_version IS DISTINCT FROM evt.schedule_version
   OR evt.capacity_commercial_version IS DISTINCT FROM evt.plan_version
   OR evt.capacity_departure_utc IS DISTINCT FROM evt.departure_utc
   OR evt.capacity_arrival_utc IS DISTINCT FROM evt.arrival_utc
   OR evt.certification_count<5
   OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_schedule_activation_preparations_v1 prep
    WHERE prep.schedule_id=evt.schedule_id
    AND prep.schedule_version=evt.schedule_version
    AND prep.airline_id=evt.airline_id
    AND prep.aircraft_inventory_id=evt.aircraft_inventory_id
    AND prep.verified_game_date<=evt.flight_local_date
    AND prep.verified_game_date+prep.certified_horizon_days>=evt.flight_local_date
    AND prep.fingerprint_md5~'^[a-f0-9]{32}$'
    AND length(prep.release_reference)>=12)
  THEN reason:='INCOMPLETE_CERTIFIED_OPERATING_SCHEDULE';END IF;
  IF reason IS NULL AND (
     NOT EXISTS(
       SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slots
       WHERE slots.schedule_id=evt.schedule_id
        AND slots.airport_key=evt.origin_airport_key AND slots.direction='departure')
     OR NOT EXISTS(
       SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slots
       WHERE slots.schedule_id=evt.schedule_id
        AND slots.airport_key=evt.destination_airport_key AND slots.direction='arrival')
  ) THEN reason:='AIRPORT_SLOTS_NOT_RESERVED';END IF;
  IF reason IS NULL AND NOT airlinerra_game.section9_canonical_aoc_covers_v1(evt.airline_id,airlinerra_game.section9_verified_permission_game_day_v1(),0) THEN reason:='ISSUED_OPERATOR_GAME_LICENCE_MISSING';END IF;
  IF reason IS NULL AND airlinerra_game.section9_game_route_licence_scope_v1(evt.airline_id,evt.origin_airport_key,evt.destination_airport_key,evt.flight_local_date,0)->>'allowed' IS DISTINCT FROM 'true' THEN reason:='GAME_ROUTE_LICENCE_SCOPE_NOT_AUTHORIZED';END IF;
  IF reason IS NULL AND evt.phase='departed' AND NOT airlinerra_game.section9_delayed_turnaround_clear_v1(evt.aircraft_inventory_id,evt.occurrence_id,evt.event_time) THEN
   reason:='DELAYED_AIRCRAFT_TURNAROUND_NOT_COMPLETE';END IF;
  IF reason IS NULL AND evt.phase='departed' THEN
   maintenance:=airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(
      evt.owner_player_id,evt.airline_id,evt.aircraft_inventory_id,
      evt.effective_departure_utc,evt.effective_arrival_utc);
   IF maintenance->>'gameMaintenanceClear' IS DISTINCT FROM 'true'
   THEN reason:='GAME_MAINTENANCE_DISPATCH_BLOCKED';END IF;
  END IF;
  -- Fuel must already exist on this exact game aircraft, at this
  -- exact departure airport, backed by an approved game-source receipt
  -- or signed prior arrival. Generic airport fuel_available is insufficient.
  IF reason IS NULL AND evt.phase='departed' THEN
    -- A trusted GAME-ONLY airport supply fills a verified fuel gap when
    -- the airplane is on the authoritative game ground airport. No
    -- client payment, no real-world fuel certification, no ledger charge.
    fuel_supply:=airlinerra_game.section9_auto_supply_game_only_fuel_v1(
       evt.physical_id);
    IF fuel_supply->>'status' NOT IN
      ('game_only_auto_fuel_supply_recorded','game_fuel_already_sufficient')
      OR fuel_supply->>'ledgerPosted' IS DISTINCT FROM 'false'
    THEN
      reason:='GAME_AIRPORT_FUEL_TOPUP_NOT_AVAILABLE';
    ELSE
      fuel_check:=airlinerra_game.section9_verify_game_fuel_before_departure_v1(
        evt.physical_id);
      IF fuel_check->>'status' IS DISTINCT FROM
          'verified_game_fuel_onboard_available_for_planned_trip'
        OR fuel_check->>'fuelVerifiedForGame' IS DISTINCT FROM 'true'
        OR fuel_check->>'ledgerPosted' IS DISTINCT FROM 'false'
      THEN reason:='AIRCRAFT_FUEL_NOT_PROVEN_AT_ORIGIN';END IF;
    END IF;

  END IF;
  IF reason IS NULL AND evt.phase='arrived' AND
     NOT EXISTS(
      SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
      WHERE m.flight_occurrence_id=evt.physical_id AND m.phase='departed')
  THEN reason:='ARRIVAL_WITHOUT_VERIFIED_DEPARTURE';END IF;
  IF reason IS NULL THEN
   matches:=airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(
     evt.airline_id,evt.aircraft_inventory_id,
     (evt.original_event_time AT TIME ZONE 'UTC')::date);
   IF matches->>'status' IS DISTINCT FROM 'verified_operational_candidates_only'
    OR jsonb_typeof(matches->'candidates')<>'array'
   THEN reason:='VERIFIED_AIRCRAFT_DAY_EVENTS_MISSING';
   ELSE
    candidate:=NULL;
    SELECT value INTO candidate
    FROM jsonb_array_elements(matches->'candidates') c(value)
    WHERE c.value->>'scheduleId'=evt.schedule_id::text
     AND c.value->>'scheduleVersion'=evt.schedule_version::text
     AND c.value->>'flightLocalDate'=evt.flight_local_date::text
     AND c.value->>'weeklyEntry'=evt.weekly_entry::text
     AND c.value->>'phase'=evt.phase
     AND (c.value->>'scheduledEventUtc')::timestamptz=evt.original_event_time
    LIMIT 1;
    IF candidate IS NULL THEN
     reason:='SIGNED_AIRCRAFT_TIMETABLE_MISMATCH';END IF;
   END IF;
  END IF;
  -- Delayed approvals must be consumed atomically, not by the advisory tracker.
  delayed_binding_required:=evt.phase='departed' AND
   (EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approvals_v1 a WHERE a.occurrence_id=evt.occurrence_id AND a.airline_id=evt.airline_id)
    OR (evt.is_delayed AND EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approval_release_v1 WHERE world_id=1 AND binding_enabled)));
  downstream_required:=false;
  IF reason IS NULL AND evt.phase='departed' THEN
   downstream_proof:=airlinerra_game.section9_downstream_crew_reconciliation_v1(evt.airline_id,evt.occurrence_id);
   IF downstream_proof->>'status' NOT IN('downstream_unaffected','downstream_crew_reconciled') THEN reason:='DOWNSTREAM_CREW_REPLAN_REQUIRED';
   ELSE downstream_required:=downstream_proof->>'status'='downstream_crew_reconciled';END IF;
  END IF;
  IF reason IS NULL AND delayed_binding_required THEN
   delayed_crew_check:=airlinerra_game.section9_check_delayed_crew_binding_v1(evt.airline_id,evt.occurrence_id,evt.event_time);
   IF delayed_crew_check->>'status' IS DISTINCT FROM 'delayed_crew_binding_ready' THEN
    reason:='DELAYED_CREW_BINDING_NOT_READY';
   END IF;
  END IF;
  IF reason IS NOT NULL THEN
    blocked:=blocked+1;
    warnings:=jsonb_set(warnings,ARRAY[reason],
      to_jsonb(coalesce((warnings->>reason)::integer,0)+1),true);
    CONTINUE;
  END IF;
  movement_event_id:=candidate->>'eventId';
  IF movement_event_id IS NULL OR length(movement_event_id) NOT BETWEEN 12 AND 128
  THEN RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_INVALID_VERIFIED_DISPATCH_EVENT_ID';END IF;
  payload:=concat_ws(E'\n',
   'airlinerra-operated-game-event-v1','1',evt.airline_id::text,
   evt.schedule_id::text,evt.schedule_version::text,
   evt.flight_local_date::text,evt.weekly_entry::text,evt.phase,
   to_char(evt.event_time AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
   movement_event_id);
  event_signature:=encode(extensions.hmac(
   pg_catalog.convert_to(payload,'UTF8'),
   pg_catalog.convert_to(signer_key,'UTF8'),'sha256'),'hex');
  movement:=airlinerra_game.section9_record_signed_operated_flight_movement_v1(
   evt.airline_id,evt.schedule_id,evt.schedule_version,
   evt.flight_local_date,evt.weekly_entry,evt.phase,
   evt.event_time,movement_event_id,event_signature);
  IF movement->>'movementRecorded' IS DISTINCT FROM 'true'
   OR movement->>'replayed' IS DISTINCT FROM 'false'
   OR movement->>'ledgerPosted' IS DISTINCT FROM 'false'
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_AUTOMATIC_DISPATCH_MOVEMENT_NOT_CONFIRMED_ROLLBACK';END IF;
  IF evt.phase='departed' THEN
    fuel_receipt:=airlinerra_game.section9_capture_verified_departure_fuel_v1(
      evt.physical_id,movement_event_id);
    IF fuel_receipt->>'status' IS DISTINCT FROM
       'signed_game_fuel_departure_receipt_created'
      OR fuel_receipt->>'fuelReceiptCreated' IS DISTINCT FROM 'true'
      OR fuel_receipt->>'ledgerPosted' IS DISTINCT FROM 'false'
    THEN RAISE EXCEPTION USING ERRCODE='42501',
      MESSAGE='SECTION9_UNVERIFIED_DEPARTURE_FUEL_ROLLS_BACK_MOVEMENT';END IF;
    UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
    SET booking_status='closed' WHERE id=evt.occurrence_id
      AND booking_status='open';
    GET DIAGNOSTICS changed=ROW_COUNT;
    IF changed<>1 THEN RAISE EXCEPTION USING ERRCODE='42501',
       MESSAGE='SECTION9_DEPARTURE_BOOKING_CLOSE_UNCONFIRMED_ROLLBACK';END IF;
    -- Tracking is advisory until live duty history and standby coverage are released.
    -- A tracking failure must not cancel an otherwise valid flight.
    IF delayed_binding_required THEN
     crew_capture:=airlinerra_game.section9_bind_approved_delayed_crew_v1(evt.airline_id,evt.occurrence_id,movement_event_id);
     IF crew_capture->>'status' IS DISTINCT FROM 'approved_delayed_crew_bound' THEN
      RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_DELAYED_CREW_BINDING_ATOMIC_ROLLBACK';
     END IF;
    ELSIF downstream_required THEN
     crew_capture:=airlinerra_game.section9_capture_dispatched_crew_v1(evt.airline_id,evt.physical_id,movement_event_id);
     IF crew_capture->>'status' IS DISTINCT FROM 'crew_departure_bound' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_DOWNSTREAM_CREW_BINDING_ATOMIC_ROLLBACK';END IF;
    ELSE
     BEGIN
      crew_capture:=airlinerra_game.section9_capture_dispatched_crew_v1(evt.airline_id,evt.physical_id,movement_event_id);
     EXCEPTION WHEN OTHERS THEN
      crew_capture:=jsonb_build_object('status','crew_departure_tracking_error');
      INSERT INTO airlinerra_game.section9_operated_crew_capture_issues_v1(engine_event_id,airline_id,physical_flight_id,issue_code) VALUES(movement_event_id,evt.airline_id,evt.physical_id,'crew_departure_tracking_error') ON CONFLICT(engine_event_id) DO NOTHING;
     END;
    END IF;
    departures:=departures+1;
  ELSE
    airframe_usage:=airlinerra_game.section9_apply_arrival_airframe_usage_once_v1(
      evt.physical_id);
    IF airframe_usage->>'status' IS DISTINCT FROM 'arrived_airframe_usage_recorded_once'
    OR airframe_usage->>'usageApplied' IS DISTINCT FROM 'true'
    OR airframe_usage->>'ledgerPosted' IS DISTINCT FROM 'false'
    THEN RAISE EXCEPTION USING ERRCODE='42501',
       MESSAGE='SECTION9_ARRIVAL_AIRFRAME_USAGE_NOT_ATOMIC_ROLLBACK';END IF;
    fuel_receipt:=airlinerra_game.section9_apply_verified_arrival_fuel_burn_once_v1(
      evt.physical_id,movement_event_id);
    IF fuel_receipt->>'status' IS DISTINCT FROM
        'signed_game_arrival_fuel_burn_recorded_once'
      OR fuel_receipt->>'fuelBurnRecorded' IS DISTINCT FROM 'true'
      OR fuel_receipt->>'ledgerPosted' IS DISTINCT FROM 'false'
    THEN RAISE EXCEPTION USING ERRCODE='42501',
      MESSAGE='SECTION9_UNVERIFIED_ARRIVAL_FUEL_ROLLS_BACK_MOVEMENT';END IF;
    BEGIN
     crew_capture:=airlinerra_game.section9_complete_bound_crew_arrival_v1(evt.airline_id,evt.physical_id,movement_event_id);
    EXCEPTION WHEN OTHERS THEN
     crew_capture:=jsonb_build_object('status','crew_arrival_tracking_error');
     INSERT INTO airlinerra_game.section9_operated_crew_capture_issues_v1(engine_event_id,airline_id,physical_flight_id,issue_code) VALUES(movement_event_id,evt.airline_id,evt.physical_id,'crew_arrival_tracking_error') ON CONFLICT(engine_event_id) DO NOTHING;
    END;
    BEGIN
     turnaround_result:=airlinerra_game.section9_capture_actual_turnaround_v1(evt.airline_id,evt.physical_id,movement_event_id);
    EXCEPTION WHEN OTHERS THEN turnaround_result:=jsonb_build_object('status','turnaround_capture_'||SQLSTATE);END;
    turnaround_code:=coalesce(turnaround_result->>'status','turnaround_unverified');
    turnaround_counts:=jsonb_set(turnaround_counts,ARRAY[turnaround_code],to_jsonb(coalesce((turnaround_counts->>turnaround_code)::int,0)+1),true);
    arrivals:=arrivals+1;
  END IF;
  crew_code:=coalesce(crew_capture->>'status','crew_tracking_unverified');
  crew_capture_counts:=jsonb_set(crew_capture_counts,ARRAY[crew_code],to_jsonb(coalesce((crew_capture_counts->>crew_code)::int,0)+1),true);
 END LOOP;
 RETURN jsonb_build_object(
   'status','trusted_game_dispatch_cycle_completed',
   'crewTrackingCounts',crew_capture_counts,'turnaroundTrackingCounts',turnaround_counts,
   'crewShortageCancellationEnforced',false,
   'verifiedGameHourUtc',now_utc,
   'candidatesChecked',used,
   'departuresRecorded',departures,'arrivalsRecorded',arrivals,
   'blocked',blocked,'blockerCounts',warnings,
   'disruptionCycle',disruption_result,'automaticCrewRecovery',automatic_crew_recovery,'signingSecretExposed',false,
   'ticketRevenueRecognized',false,'ledgerPosted',false,
   'actualFuelSettlementConnected',false,'gameFuelCustodyTrackingConnected',true);
END $function$;