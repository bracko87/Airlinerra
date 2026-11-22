-- Phase 14L. Delayed single-sector binding; default off. A separate historical
-- projection represents the crew that actually flew. Never overwrite the
-- original weekly plan or its previous signed movement bindings.
ALTER TABLE airlinerra_game.section9_delayed_crew_approval_release_v1 ADD COLUMN IF NOT EXISTS binding_enabled boolean NOT NULL DEFAULT false;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_check_delayed_crew_binding_v1(p_airline uuid,p_occurrence uuid,p_departure timestamptz,p_event text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $body$
DECLARE ap record;f record;t record;pl record;pol record;employee record;old_duty record;m jsonb;hist jsonb;prior jsonb;rot jsonb;fit jsonb;report_at timestamptz;end_at timestamptz;ids uuid[];removed uuid[];duties jsonb:='[]';snap jsonb;owner_id uuid;n timestamptz;cash numeric;committed numeric;reference text;
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
 IF removed IS DISTINCT FROM ap.released_employee_ids OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id=p_occurrence AND s.employee_id=ANY(removed) AND d.duty_start_utc<=ap.authorized_game_utc) THEN RETURN jsonb_build_object('status','delayed_binding_release_conflict');END IF;
 -- Scope: isolated single sector only. Neither released nor retained staff
 -- may be in a multi-sector duty or another future assignment.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_seats_v1 other ON other.plan_id=s.plan_id AND other.duty_id=s.duty_id AND other.occurrence_id<>s.occurrence_id WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id=p_occurrence)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=s.plan_id AND pf.occurrence_id=s.occurrence_id WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id<>p_occurrence AND s.employee_id=ANY(ids||removed) AND pf.departure_utc>=ap.authorized_game_utc)
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
 SELECT s.seat_role,d.duty_start_utc INTO old_duty FROM airlinerra_game.section9_planned_crew_seats_v1 s JOIN airlinerra_game.section9_planned_crew_duties_v1 d ON d.duty_id=s.duty_id AND d.plan_id=s.plan_id WHERE s.plan_id=ap.source_plan_id AND s.occurrence_id=p_occurrence AND s.employee_id=employee.id;
 IF FOUND THEN
 IF old_duty.seat_role<>employee.role THEN RETURN jsonb_build_object('status','delayed_binding_role_changed');END IF;
 report_at:=old_duty.duty_start_utc;
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
 SELECT coalesce(jsonb_agg(jsonb_build_object('dutyStartUtc',h->'startUtc','dutyEndUtc',h->'endUtc','startingAirport',h->'origin','endingAirport',h->'destination') ORDER BY ord),'[]') INTO prior FROM jsonb_array_elements(hist->'history') WITH ORDINALITY x(h,ord);
 rot:=jsonb_build_object('status','rotation_preview','dutyStartUtc',report_at,'dutyEndUtc',end_at,'startingAirport',f.origin_airport_key,'endingAirport',f.destination_airport_key);
 fit:=airlinerra_game.section9_crew_duty_fit_v2(rot,prior,m->>'baseTimezone',m->>'initialAirport');
 IF fit->>'eligible' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','delayed_binding_'||coalesce(fit->>'status','rest_unverified'));END IF;
 duties:=duties||jsonb_build_array(jsonb_build_object('employeeId',employee.id,'role',employee.role,'dutyStartUtc',report_at,'dutyEndUtc',end_at,'reportDate',(report_at AT TIME ZONE (m->>'baseTimezone'))::date));
 END LOOP;
 reference:=CASE WHEN ap.external_captains+ap.external_first_officers+ap.external_cabin>0 THEN 'delayed-approval-v1:'||ap.approval_id END;
 RETURN jsonb_build_object('status','delayed_crew_binding_ready','approvalId',ap.approval_id,'duties',duties,'configurationId',f.configuration_id,'contractReference',reference,'dispatchAuthorizationIssued',false);
END $body$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_check_delayed_crew_binding_v1(uuid,uuid,timestamptz,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_bind_approved_delayed_crew_v1(p_airline uuid,p_occurrence uuid,p_event text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $body$
DECLARE ap record;pl record;existing record;proof jsonb;d jsonb;duty uuid;emp uuid;role_name text;basis timestamptz;ref text;
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
 -- This non-current projection is linked exclusively through the actual
 -- signed departure binding. Current-plan uniqueness is preserved.
 INSERT INTO airlinerra_game.section9_crew_plan_batches_v1(plan_id,airline_id,window_start_utc,window_end_utc,source_snapshot,proposed_assignments,status) VALUES(ap.approval_id,p_airline,basis,basis+interval '168 hours',jsonb_build_object('status','delayed_approved_actual_projection','sourcePlanId',ap.source_plan_id),ap.request_payload,'superseded');
 INSERT INTO airlinerra_game.section9_planned_flight_crews_v1(plan_id,airline_id,occurrence_id,schedule_version,aircraft_inventory_id,physical_flight_id,qualification_group,departure_utc,arrival_utc,origin_airport_key,destination_airport_key,captain_count,first_officer_count,cabin_count,external_captain_count,external_first_officer_count,external_cabin_count,external_contract_reference)
 VALUES(ap.approval_id,p_airline,p_occurrence,pl.schedule_version,pl.aircraft_inventory_id,pl.physical_flight_id,pl.qualification_group,ap.revised_departure_utc,ap.revised_arrival_utc,pl.origin_airport_key,pl.destination_airport_key,cardinality(ap.internal_captains),cardinality(ap.internal_first_officers),cardinality(ap.internal_cabin),ap.external_captains,ap.external_first_officers,ap.external_cabin,ref);
 FOR d IN SELECT value FROM jsonb_array_elements(proof->'duties') LOOP
 duty:=gen_random_uuid();emp:=(d->>'employeeId')::uuid;role_name:=d->>'role';
 INSERT INTO airlinerra_game.section9_planned_crew_duties_v1(duty_id,plan_id,airline_id,pilot_id,cabin_member_id,duty_start_utc,duty_end_utc,report_date,starting_airport,ending_airport)
 VALUES(duty,ap.approval_id,p_airline,CASE WHEN role_name<>'cabin' THEN emp END,CASE WHEN role_name='cabin' THEN emp END,(d->>'dutyStartUtc')::timestamptz,(d->>'dutyEndUtc')::timestamptz,(d->>'reportDate')::date,pl.origin_airport_key,pl.destination_airport_key);
 INSERT INTO airlinerra_game.section9_planned_crew_seats_v1(plan_id,airline_id,occurrence_id,employee_id,duty_id,seat_role) VALUES(ap.approval_id,p_airline,p_occurrence,emp,duty,role_name);
 END LOOP;
 INSERT INTO airlinerra_game.section9_pilot_departure_manifests_v1(physical_flight_id,airline_id,departure_event_id,configuration_id,qualification_group,captain_ids,first_officer_ids,external_captain_count,external_first_officer_count,external_cabin_count,external_contract_reference)
 VALUES(ap.physical_flight_id,p_airline,p_event,(proof->>'configurationId')::bigint,pl.qualification_group,ap.internal_captains,ap.internal_first_officers,ap.external_captains,ap.external_first_officers,ap.external_cabin,ref);
 INSERT INTO airlinerra_game.section9_operated_crew_bindings_v1(physical_flight_id,airline_id,plan_id,occurrence_id,departure_event_id,cabin_member_ids,external_cabin_count,external_contract_reference,external_captain_count,external_first_officer_count)
 VALUES(ap.physical_flight_id,p_airline,ap.approval_id,p_occurrence,p_event,ap.internal_cabin,ap.external_cabin,ref,ap.external_captains,ap.external_first_officers);
 RETURN jsonb_build_object('status','approved_delayed_crew_bound','approvalId',ap.approval_id,'externalPilotCount',ap.external_captains+ap.external_first_officers,'externalCabinCount',ap.external_cabin,'replayed',false,'ledgerPosted',false);
END $body$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_bind_approved_delayed_crew_v1(uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;

-- Use the existing final-cost approval and exactly-once financial posting
-- transaction. Never create a second expense path for delayed approvals.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_bound_delayed_external_cost_v1(p_airline uuid,p_physical text,p_arrival_event text)
RETURNS numeric LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $body$
DECLARE ap record;b record;m record;d record;a record;reference text;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO ap FROM airlinerra_game.section9_delayed_crew_approvals_v1 WHERE physical_flight_id=p_physical;
 IF NOT FOUND THEN RETURN NULL;END IF;
 IF ap.airline_id<>p_airline THEN RAISE EXCEPTION 'DELAYED_CREW_COST_AIRLINE_MISMATCH';END IF;
 SELECT * INTO b FROM airlinerra_game.section9_operated_crew_bindings_v1 WHERE physical_flight_id=p_physical AND airline_id=p_airline AND plan_id=ap.approval_id AND occurrence_id=ap.occurrence_id;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='DELAYED_APPROVAL_NOT_BOUND';END IF;
 reference:=CASE WHEN ap.external_captains+ap.external_first_officers+ap.external_cabin>0 THEN 'delayed-approval-v1:'||ap.approval_id END;
 SELECT * INTO STRICT m FROM airlinerra_game.section9_pilot_departure_manifests_v1 WHERE physical_flight_id=p_physical AND airline_id=p_airline AND departure_event_id=b.departure_event_id;
 IF m.captain_ids IS DISTINCT FROM ap.internal_captains OR m.first_officer_ids IS DISTINCT FROM ap.internal_first_officers OR b.cabin_member_ids IS DISTINCT FROM ap.internal_cabin OR m.external_contract_reference IS DISTINCT FROM reference OR b.external_contract_reference IS DISTINCT FROM reference OR m.external_captain_count<>ap.external_captains OR b.external_captain_count<>ap.external_captains OR m.external_first_officer_count<>ap.external_first_officers OR b.external_first_officer_count<>ap.external_first_officers OR m.external_cabin_count<>ap.external_cabin OR b.external_cabin_count<>ap.external_cabin THEN RAISE EXCEPTION 'DELAYED_APPROVAL_BINDING_MISMATCH';END IF;
 SELECT * INTO STRICT d FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=b.departure_event_id AND airline_id=p_airline AND flight_occurrence_id=p_physical AND phase='departed' AND actual_event_utc=ap.revised_departure_utc AND source_kind='signed_operated_game_flight_v1';
 SELECT * INTO STRICT a FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=p_arrival_event AND flight_occurrence_id=p_physical AND airline_id=p_airline AND phase='arrived' AND aircraft_inventory_id=d.aircraft_inventory_id AND schedule_id=d.schedule_id AND schedule_version=d.schedule_version AND weekly_entry=d.weekly_entry AND flight_local_date=d.flight_local_date AND origin_airport_key=d.origin_airport_key AND destination_airport_key=d.destination_airport_key AND source_kind='signed_operated_game_flight_v1';
 RETURN airlinerra_game.section9_external_crew_cost_v1(ap.external_captains,ap.external_first_officers,ap.external_cabin,ap.captain_rate,ap.first_officer_rate,ap.cabin_rate,extract(epoch FROM a.actual_event_utc-d.actual_event_utc)/60);
END $body$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_bound_delayed_external_cost_v1(uuid,text,text) FROM PUBLIC,anon,authenticated,service_role;
