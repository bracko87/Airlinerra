-- Bounded automatic rolling replan for affected, separate future duties.
-- An incomplete plan never supersedes the existing plan. No external purchases.
ALTER TABLE airlinerra_game.section9_delayed_crew_approval_release_v1 ADD COLUMN IF NOT EXISTS automatic_downstream_replan_enabled boolean NOT NULL DEFAULT false;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_replan_downstream_crew_v1(p_player uuid,p_airline uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog,airlinerra_game AS $b$
DECLARE n timestamptz;pol record;snap jsonb;f jsonb;m jsonb;pref jsonb;rot jsonb;prior jsonb;histories jsonb:='{}';assignments jsonb:='[]';duties jsonb;cp uuid[];fo uuid[];ca uuid[];eligible_cp uuid[];eligible_fo uuid[];dual_ids uuid[];eligible_ca uuid[];pid uuid;role_name text;cap_ok boolean;fo_ok boolean;cab_ok boolean;dep timestamptz;arr timestamptz;report_at timestamptz;end_at timestamptz;needed int;cabin_needed int;fit jsonb;receipt jsonb;affected boolean:=false;held record;proof jsonb;ext jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_delayed_crew_approval_release_v1 WHERE world_id=1 AND approval_enabled AND binding_enabled AND automatic_recovery_enabled AND automatic_downstream_replan_enabled) OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_movement_capture_release_v1 WHERE world_id=1 AND capture_enabled) THEN RETURN jsonb_build_object('status','automatic_downstream_replan_disabled','saved',false);END IF;
 n:=airlinerra_game.section9_verified_world_instant_v1();
 IF n IS NULL THEN RETURN jsonb_build_object('status','automatic_downstream_clock_unverified','saved',false);END IF;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 -- Derive affected flights from the immutable old roster, even if a new
 -- plan has already been created. Do not replan an unaffected airline.
 FOR held IN SELECT DISTINCT pf.occurrence_id FROM airlinerra_game.section9_delayed_crew_approvals_v1 x JOIN airlinerra_game.section9_planned_crew_seats_v1 original ON original.plan_id=x.source_plan_id AND original.airline_id=x.airline_id AND original.occurrence_id=x.occurrence_id JOIN airlinerra_game.section9_planned_crew_seats_v1 s ON s.plan_id=original.plan_id AND s.airline_id=original.airline_id AND s.employee_id=original.employee_id AND s.occurrence_id<>original.occurrence_id JOIN airlinerra_game.section9_planned_flight_crews_v1 pf ON pf.plan_id=s.plan_id AND pf.occurrence_id=s.occurrence_id AND pf.airline_id=s.airline_id JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=pf.occurrence_id AND o.airline_id=pf.airline_id WHERE x.airline_id=p_airline AND pf.departure_utc>=x.original_departure_utc AND o.booking_status<>'cancelled' AND pf.departure_utc>=n AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 d WHERE d.airline_id=p_airline AND d.flight_occurrence_id=pf.physical_flight_id AND d.phase='departed') LOOP
 proof:=airlinerra_game.section9_downstream_crew_reconciliation_v1(p_airline,held.occurrence_id);
 IF proof->>'status'='downstream_waiting_for_actual_arrival' THEN RETURN jsonb_build_object('status','automatic_downstream_waiting_for_arrival','saved',false);END IF;
 IF proof->>'status'='downstream_rolling_replan_required' THEN affected:=true;ELSIF proof->>'status'<>'downstream_crew_reconciled' THEN RETURN jsonb_build_object('status','automatic_downstream_dependency_unverified','saved',false);END IF;
 END LOOP;
 IF NOT affected THEN RETURN jsonb_build_object('status','automatic_downstream_no_replan_required','saved',false);END IF;
 snap:=airlinerra_game.section9_owned_rolling_crew_input_v1(p_player,p_airline,n);
 IF snap->>'status' IS DISTINCT FROM 'rolling_crew_input_preview' OR snap->>'invalidOccurrenceCount' IS DISTINCT FROM '0' OR snap->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' OR snap->>'unboundDeparturesLast7Days' IS DISTINCT FROM '0' OR snap->>'unresolvedCaptureIssues' IS DISTINCT FROM '0' OR snap->>'alreadyReportedFutureFlights' IS DISTINCT FROM '0' THEN RETURN jsonb_build_object('status','automatic_downstream_snapshot_protected','saved',false);END IF;
 IF jsonb_array_length(snap->'flights') NOT BETWEEN 1 AND 100 OR jsonb_array_length(snap->'pilots')+jsonb_array_length(snap->'cabinMembers')>500 THEN RETURN jsonb_build_object('status','automatic_downstream_workload_limit','saved',false);END IF;
 FOR m IN SELECT value FROM jsonb_array_elements((snap->'pilots')||(snap->'cabinMembers')) LOOP
 SELECT coalesce(jsonb_agg(jsonb_build_object('dutyStartUtc',h->'startUtc','dutyEndUtc',h->'endUtc','startingAirport',h->'origin','endingAirport',h->'destination') ORDER BY ord),'[]') INTO prior FROM jsonb_array_elements(m->'history') WITH ORDINALITY x(h,ord);
 histories:=jsonb_set(histories,ARRAY[m->>'id'],prior,true);
 END LOOP;
 FOR f IN SELECT value FROM jsonb_array_elements(snap->'flights') ORDER BY (value->>'departureUtc')::timestamptz,value->>'id' LOOP
 dep:=(f->>'departureUtc')::timestamptz;arr:=(f->>'arrivalUtc')::timestamptz;report_at:=dep-make_interval(mins=>pol.preflight_minutes);end_at:=arr+make_interval(mins=>pol.postflight_minutes);
 IF report_at<n OR end_at-report_at>make_interval(mins=>pol.maximum_duty_minutes) THEN RETURN jsonb_build_object('status','automatic_downstream_reporting_or_duty_limit','saved',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_replacement_slot_pairs_v1 x WHERE x.occurrence_id=(f->>'id')::uuid AND (x.revised_departure_utc<>dep OR x.revised_arrival_utc<>arr)) THEN RETURN jsonb_build_object('status','automatic_downstream_delayed_sector_requires_review','saved',false);END IF;
 ext:=airlinerra_game.section9_verified_external_cabin_input_v1(p_airline,(f->>'id')::uuid);
 IF ext->>'status' IS DISTINCT FROM 'external_cabin_input_verified' THEN RETURN jsonb_build_object('status','automatic_downstream_external_contract_unverified','saved',false);END IF;
 needed:=CASE WHEN arr-dep>interval '6 hours' THEN 2 ELSE 1 END;cabin_needed:=(f->>'cabinRequired')::int;
 -- Existing contracts are not changed by this restricted replan.
 IF (ext->>'captainCount')::int+(ext->>'firstOfficerCount')::int+(ext->>'cabinCount')::int<>0 THEN RETURN jsonb_build_object('status','automatic_downstream_existing_contract_review','saved',false);END IF;
 SELECT value INTO pref FROM jsonb_array_elements(snap->'preferredAssignments') WHERE value->>'flightId'=f->>'id';
 cp:='{}';fo:='{}';ca:='{}';eligible_cp:='{}';eligible_fo:='{}';dual_ids:='{}';eligible_ca:='{}';duties:='[]';
 rot:=jsonb_build_object('status','rotation_preview','dutyStartUtc',report_at,'dutyEndUtc',end_at,'startingAirport',f->>'origin','endingAirport',f->>'destination');
 FOR m IN SELECT value FROM jsonb_array_elements((snap->'pilots')||(snap->'cabinMembers')) ORDER BY CASE WHEN coalesce(pref->'captains','[]')? (value->>'id') OR coalesce(pref->'firstOfficers','[]')?(value->>'id') OR coalesce(pref->'cabinCrew','[]')?(value->>'id') THEN 0 ELSE 1 END,value->>'id' LOOP
 pid:=(m->>'id')::uuid;cap_ok:=false;fo_ok:=false;cab_ok:=false;
 IF m?'permissions' THEN SELECT coalesce(bool_or(x->>'captain'='true'),false),coalesce(bool_or(x->>'firstOfficer'='true'),false) INTO cap_ok,fo_ok FROM jsonb_array_elements(m->'permissions') x WHERE x->>'group'=f->>'group' AND x->>'active'='true' AND (x->>'issued')::date<=(dep AT TIME ZONE (m->>'baseTimezone'))::date AND (x->>'expires')::date>(arr AT TIME ZONE (m->>'baseTimezone'))::date;
 ELSE cab_ok:=m->>'role' IN('flight_attendant','cabin_supervisor','purser');END IF;
 IF NOT(cap_ok OR fo_ok OR cab_ok) OR (m->>'locationEffectiveUtc')::timestamptz>report_at OR (m->>'employmentFrom')::date>(report_at AT TIME ZONE (m->>'baseTimezone'))::date THEN CONTINUE;END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(coalesce(m->'absences','[]')) x WHERE (x->>'startUtc')::timestamptz<end_at AND (x->>'endUtc')::timestamptz>report_at) THEN CONTINUE;END IF;
 fit:=airlinerra_game.section9_crew_duty_fit_v2(rot,histories->(pid::text),m->>'baseTimezone',m->>'initialAirport');
 IF fit->>'eligible' IS DISTINCT FROM 'true' THEN CONTINUE;END IF;
 IF cab_ok THEN eligible_ca:=array_append(eligible_ca,pid);ELSIF cap_ok AND fo_ok THEN dual_ids:=array_append(dual_ids,pid);ELSIF cap_ok THEN eligible_cp:=array_append(eligible_cp,pid);ELSE eligible_fo:=array_append(eligible_fo,pid);END IF;
 END LOOP;
 FOREACH pid IN ARRAY eligible_cp LOOP EXIT WHEN cardinality(cp)>=needed;cp:=array_append(cp,pid);END LOOP;
 FOREACH pid IN ARRAY eligible_fo LOOP EXIT WHEN cardinality(fo)>=needed;fo:=array_append(fo,pid);END LOOP;
 FOREACH pid IN ARRAY dual_ids LOOP IF cardinality(cp)<needed THEN cp:=array_append(cp,pid);ELSIF cardinality(fo)<needed THEN fo:=array_append(fo,pid);ELSE EXIT;END IF;END LOOP;
 FOREACH pid IN ARRAY eligible_ca LOOP EXIT WHEN cardinality(ca)>=cabin_needed;ca:=array_append(ca,pid);END LOOP;
 IF cardinality(cp)<>needed OR cardinality(fo)<>needed OR cardinality(ca)<>cabin_needed THEN RETURN jsonb_build_object('status','automatic_downstream_internal_shortage','saved',false,'occurrenceId',f->>'id');END IF;
 FOREACH pid IN ARRAY cp||fo||ca LOOP
 role_name:=CASE WHEN pid=ANY(cp) THEN 'captain' WHEN pid=ANY(fo) THEN 'firstOfficer' ELSE 'cabin' END;
 duties:=duties||jsonb_build_array(jsonb_build_object('employeeId',pid,'role',role_name,'dutyStartUtc',report_at,'dutyEndUtc',end_at));
 histories:=jsonb_set(histories,ARRAY[pid::text],(histories->(pid::text))||jsonb_build_array(rot));
 END LOOP;
 assignments:=assignments||jsonb_build_array(jsonb_build_object('flightId',f->>'id','aircraftId',f->>'aircraftId','departureUtc',dep,'arrivalUtc',arr,'captains',cp,'firstOfficers',fo,'cabinCrew',ca,'duties',duties));
 END LOOP;
 receipt:=airlinerra_game.section9_save_owned_rolling_crew_plan_v1(p_player,p_airline,gen_random_uuid(),n,snap,assignments);
 RETURN receipt||jsonb_build_object('automaticDownstreamReplan',true,'externalContractsCreated',false,'ledgerPosted',false,'dispatchAuthorizationIssued',false);
END $b$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_auto_replan_downstream_crew_v1(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
