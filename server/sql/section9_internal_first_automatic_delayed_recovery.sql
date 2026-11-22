-- Internal-first automatic recovery for a terminal delayed sector.
ALTER TABLE airlinerra_game.section9_delayed_crew_approval_release_v1 ADD COLUMN IF NOT EXISTS automatic_recovery_enabled boolean NOT NULL DEFAULT false;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_plan_terminal_delayed_crew_v1(p_player uuid,p_airline uuid,p_occurrence uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $b$
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
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=s.plan_id AND pf.occurrence_id=s.occurrence_id WHERE s.plan_id=pl.plan_id AND s.employee_id=ANY(orig_ids) AND s.occurrence_id<>p_occurrence AND pf.departure_utc>=pl.departure_utc) THEN RETURN jsonb_build_object('status','automatic_recovery_downstream_rotation_required');END IF;
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
END $b$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_plan_terminal_delayed_crew_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_approve_terminal_delayed_crew_v1(p_player uuid,p_airline uuid,p_occurrence uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $b$
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
 r:=airlinerra_game.section9_stage_delayed_crew_approval_v1(p_player,p_airline,p_occurrence,gen_random_uuid(),(v->>'departureUtc')::timestamptz,(v->>'arrivalUtc')::timestamptz,(v->>'quotedCostUsd')::numeric,cp,fo,ca,(v->>'externalCaptains')::int,(v->>'externalFirstOfficers')::int,(v->>'externalCabin')::int);
 RETURN r||jsonb_build_object('internalReserveCount',v->'internalReserveCount','externalCaptains',v->'externalCaptains','externalFirstOfficers',v->'externalFirstOfficers','externalCabin',v->'externalCabin','internalPriorityVerified',true);
END $b$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_auto_approve_terminal_delayed_crew_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;