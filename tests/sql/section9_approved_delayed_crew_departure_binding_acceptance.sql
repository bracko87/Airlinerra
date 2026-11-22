-- Isolated schema acceptance, rolled back in full. Production tables/triggers are
-- never modified. Copies of production functions execute against fixture relations.
DO $test$
DECLARE tbl text; fn record; a record; ac uuid; conf bigint; grp text; hire jsonb; sc uuid; oid uuid; snap jsonb; assignments jsonb:='[]'; duties jsonb; start_at timestamptz:='2026-11-24T00:00:00Z'; dep timestamptz; arr timestamptz; orig text; dest text; plan uuid:=gen_random_uuid(); other_plan uuid:=gen_random_uuid(); r jsonb; i int; bad jsonb; result jsonb; ph text; de text; ae text; pf record; cp uuid; second_pf record; assessed jsonb; delay_mins int; revised_dep timestamptz; revised_arr timestamptz; v jsonb; q jsonb; ca uuid[]; fo uuid[]; fa uuid[]; baseline_cash numeric; approval uuid:=gen_random_uuid(); req2 uuid:=gen_random_uuid(); receipt jsonb; receipt2 jsonb;
BEGIN
 BEGIN
 CREATE SCHEMA crew_binding_fixture_14l;
 FOREACH tbl IN ARRAY ARRAY['airlines','airline_aircraft_inventory','airport_reference_profiles','section9_crew_bases_v1','section9_flight_crew_model_policy_v1','section9_pilot_qualification_groups_v1','section9_airline_crew_roster_v1','section9_pilot_profiles_v1','section9_pilot_family_permissions_v1','section9_pilot_base_assignments_v1','section9_cabin_crew_pools_v1','section9_cabin_crew_members_v1','section9_crew_unavailability_v1','section9_shared_crew_employment_release_v1','section9_shared_crew_salary_policy_v1','section9_shared_crew_hire_batches_v1','section9_crew_scheduler_policy_v2','airline_flight_schedule_drafts_v1','section9_dated_flight_occurrences_v1','section9_pilot_departure_manifests_v1','section9_crew_plan_batches_v1','section9_planned_flight_crews_v1','section9_planned_crew_duties_v1','section9_planned_crew_seats_v1','section9_operated_flight_movements_v1','section9_game_flight_fuel_departure_receipts_v1','section9_pilot_flight_experience_v1','section9_crew_movement_capture_release_v1','section9_operated_crew_bindings_v1','section9_operated_crew_capture_issues_v1','section9_external_crew_contracts_v1','section9_external_crew_release_v1','section9_disruption_release_v1','section9_replacement_slot_pairs_v1','section9_dated_replacement_slots_v1','section9_external_crew_rate_v1','section9_route_posted_flight_financials_v1','section9_delayed_crew_approvals_v1','section9_delayed_crew_approval_release_v1'] LOOP
 EXECUTE format('CREATE TABLE crew_binding_fixture_14l.%I (LIKE airlinerra_game.%I INCLUDING ALL)',tbl,tbl);
 END LOOP;
 FOR fn IN SELECT c.conrelid::regclass::text rel,c.conname,pg_get_constraintdef(c.oid) def FROM pg_constraint c WHERE c.contype='f' AND c.conrelid IN('airlinerra_game.section9_crew_plan_batches_v1'::regclass,'airlinerra_game.section9_planned_flight_crews_v1'::regclass,'airlinerra_game.section9_planned_crew_duties_v1'::regclass,'airlinerra_game.section9_planned_crew_seats_v1'::regclass,'airlinerra_game.section9_operated_crew_bindings_v1'::regclass,'airlinerra_game.section9_operated_crew_capture_issues_v1'::regclass) LOOP
 EXECUTE 'ALTER TABLE '||replace(fn.rel,'airlinerra_game','crew_binding_fixture_14l')||' ADD CONSTRAINT '||quote_ident(fn.conname)||' '||replace(fn.def,'airlinerra_game','crew_binding_fixture_14l');
 END LOOP;
 FOR fn IN SELECT pg_get_functiondef(p.oid) def FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='airlinerra_game' AND p.proname IN('section9_owned_shared_crew_payroll_forecast_v1','section9_owned_shared_crew_hire_quote_v1','section9_confirm_owned_shared_crew_hire_v1','section9_pilot_can_fill_rank_v1','section9_crew_unavailability_windows_v1','section9_owned_weekly_crew_input_v1','section9_crew_rotation_window_v2','section9_crew_duty_fit_v2','section9_save_owned_crew_plan_preview_v1','section9_record_pilot_departure_manifest_v1','section9_credit_completed_pilot_flight_v1','section9_capture_dispatched_crew_v1','section9_complete_bound_crew_arrival_v1','section9_crew_actual_history_v1','section9_flight_crew_requirements_v1','section9_cabin_composition_valid_v1','section9_verified_external_cabin_input_v1','section9_pilot_counts_valid_v1','section9_effective_dispatch_window_v1','section9_delayed_crew_duty_window_v1','section9_assess_delayed_crew_rotation_v1','section9_external_crew_cost_v1','section9_delayed_external_crew_quote_v1','section9_validate_delayed_crew_roster_v1','section9_stage_delayed_crew_approval_v1','section9_check_delayed_crew_binding_v1','section9_bind_approved_delayed_crew_v1','section9_bound_delayed_external_cost_v1','section9_completed_external_crew_cost_v1') ORDER BY CASE p.proname WHEN 'section9_owned_shared_crew_payroll_forecast_v1' THEN 0 WHEN 'section9_owned_shared_crew_hire_quote_v1' THEN 1 ELSE 2 END LOOP
 EXECUTE replace(fn.def,'airlinerra_game','crew_binding_fixture_14l');
 END LOOP;
 CREATE FUNCTION crew_binding_fixture_14l.section9_verified_world_instant_v1() RETURNS timestamptz LANGUAGE sql STABLE AS 'SELECT coalesce(nullif(current_setting(''airlinerra.requote_fixture_clock'',true),'''')::timestamptz,''2026-11-22T11:24:00Z''::timestamptz)';
 SELECT id,owner_player_id,home_airport_key,iata_code INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 SELECT f.id,f.configuration_id,p.qualification_group INTO STRICT ac,conf,grp FROM airlinerra_game.airline_aircraft_inventory f JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=f.configuration_id WHERE f.airline_id=a.id AND p.seat_basis<>'cargo_zero' LIMIT 1;
 INSERT INTO crew_binding_fixture_14l.airlines SELECT * FROM airlinerra_game.airlines WHERE id=a.id;
 INSERT INTO crew_binding_fixture_14l.airline_aircraft_inventory SELECT * FROM airlinerra_game.airline_aircraft_inventory WHERE id=ac;
 SELECT string_agg(quote_ident(column_name),',' ORDER BY ordinal_position) INTO tbl FROM information_schema.columns WHERE table_schema='airlinerra_game' AND table_name='airport_reference_profiles' AND is_generated='NEVER';
 EXECUTE format('INSERT INTO crew_binding_fixture_14l.airport_reference_profiles(%s) SELECT %s FROM airlinerra_game.airport_reference_profiles WHERE world_id=1 AND airport_key=ANY($1)',tbl,tbl) USING ARRAY[a.home_airport_key,'OURAIRPORTS:2212'];
 INSERT INTO crew_binding_fixture_14l.section9_crew_bases_v1 SELECT * FROM airlinerra_game.section9_crew_bases_v1 WHERE airline_id=a.id AND airport_key=a.home_airport_key;
 INSERT INTO crew_binding_fixture_14l.section9_flight_crew_model_policy_v1 SELECT * FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=conf;
 INSERT INTO crew_binding_fixture_14l.section9_pilot_qualification_groups_v1 SELECT * FROM airlinerra_game.section9_pilot_qualification_groups_v1 WHERE qualification_group=grp;
 INSERT INTO crew_binding_fixture_14l.section9_shared_crew_employment_release_v1(world_id,manual_hiring_enabled,automatic_hiring_enabled,payroll_enabled) VALUES(1,true,false,false);
 INSERT INTO crew_binding_fixture_14l.section9_shared_crew_salary_policy_v1 SELECT * FROM airlinerra_game.section9_shared_crew_salary_policy_v1;
 INSERT INTO crew_binding_fixture_14l.section9_crew_scheduler_policy_v2 SELECT * FROM airlinerra_game.section9_crew_scheduler_policy_v2;
 INSERT INTO crew_binding_fixture_14l.section9_external_crew_rate_v1 SELECT * FROM airlinerra_game.section9_external_crew_rate_v1;
 INSERT INTO crew_binding_fixture_14l.section9_external_crew_release_v1 VALUES(1,false);
 hire:=crew_binding_fixture_14l.section9_confirm_owned_shared_crew_hire_v1(a.owner_player_id,a.id,gen_random_uuid(),a.home_airport_key,grp,1,1,4,22800);
 IF hire->>'status'<>'shared_crew_hired' THEN RAISE EXCEPTION 'hire %',hire;END IF;
 FOR i IN 1..1 LOOP
 dep:=start_at+make_interval(hours=>CASE WHEN i=1 THEN 6 ELSE 12 END);arr:=dep+interval '3 hours';
 orig:=CASE WHEN i=1 THEN a.home_airport_key ELSE 'OURAIRPORTS:2212' END;dest:=CASE WHEN i=1 THEN 'OURAIRPORTS:2212' ELSE a.home_airport_key END;
 INSERT INTO crew_binding_fixture_14l.airline_flight_schedule_drafts_v1(airline_id,aircraft_inventory_id,configuration_id,flight_number,origin_airport_key,destination_airport_key,reference_departure_utc,reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id,status,operationally_verified)
 VALUES(a.id,ac,conf,a.iata_code|| (980+i),orig,dest,dep,arr,jsonb_build_array(jsonb_build_object('day',extract(isodow FROM dep)::int-1,'time',to_char(dep,'HH24:MI'))),'{}',a.owner_player_id,'active',true) RETURNING id INTO sc;
 INSERT INTO crew_binding_fixture_14l.section9_dated_flight_occurrences_v1(world_id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,weekly_entry,flight_local_date,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,turnaround_minutes,verified_passenger_seats,booking_status,booked_seats,recognized_revenue_usd,source_kind)
 VALUES(1,a.id,sc,ac,1,1,dep::date,orig,dest,dep,arr,60,156,'not_open',0,0,'verified_schedule_preview_not_saleable') RETURNING id INTO oid;
 SELECT jsonb_agg(jsonb_build_object('employeeId',x.emp,'role',x.role,'dutyStartUtc',start_at+interval '4 hours','dutyEndUtc',arr+interval '30 minutes')) INTO duties FROM(
 SELECT hire->'pilotIds'->>0 emp,'captain' role UNION ALL SELECT hire->'pilotIds'->>1,'firstOfficer' UNION ALL SELECT value,'cabin' FROM jsonb_array_elements_text(hire->'cabinIds'))x;
 assignments:=assignments||jsonb_build_array(jsonb_build_object('flightId',oid,'aircraftId',ac,'departureUtc',dep,'arrivalUtc',arr,'captains',jsonb_build_array(hire->'pilotIds'->0),'firstOfficers',jsonb_build_array(hire->'pilotIds'->1),'cabinCrew',hire->'cabinIds','duties',duties));
 END LOOP;
 snap:=crew_binding_fixture_14l.section9_owned_weekly_crew_input_v1(a.owner_player_id,a.id,start_at);
 r:=crew_binding_fixture_14l.section9_save_owned_crew_plan_preview_v1(a.owner_player_id,a.id,plan,start_at,snap,assignments);
 IF r->>'status'<>'validated_preview' OR r->>'dutyCount'<>'6' OR r->>'flightCount'<>'1' THEN RAISE EXCEPTION 'plan %',r;END IF;
 IF (SELECT count(*) FROM crew_binding_fixture_14l.section9_planned_crew_seats_v1 WHERE plan_id=plan)<>6 OR EXISTS(SELECT 1 FROM crew_binding_fixture_14l.section9_planned_crew_duties_v1 WHERE plan_id=plan AND duty_end_utc-duty_start_utc<>interval '5 hours 30 minutes') THEN RAISE EXCEPTION 'duty manifest';END IF;

 SELECT * INTO STRICT pf FROM crew_binding_fixture_14l.section9_planned_flight_crews_v1 WHERE plan_id=plan AND departure_utc=start_at+interval '6 hours';

 -- One isolated unstarted leg. The original roster remains unchanged even
 -- after staging a replacement approval containing one external captain.
 INSERT INTO crew_binding_fixture_14l.section9_disruption_release_v1(world_id,delayed_execution_enabled) VALUES(1,true);
 INSERT INTO crew_binding_fixture_14l.section9_delayed_crew_approval_release_v1(world_id,approval_enabled) VALUES(1,false);
 cp:=(hire->'pilotIds'->>0)::uuid;
 ca:=ARRAY[cp];fo:=ARRAY[(hire->'pilotIds'->>1)::uuid];SELECT array_agg(value::uuid) INTO fa FROM jsonb_array_elements_text(hire->'cabinIds');
 revised_dep:=pf.departure_utc+interval '40 minutes';revised_arr:=pf.arrival_utc+interval '40 minutes';
 INSERT INTO crew_binding_fixture_14l.section9_replacement_slot_pairs_v1(occurrence_id,world_id,aircraft_inventory_id,original_departure_utc,original_arrival_utc,revised_departure_utc,revised_arrival_utc,available_utc)
 VALUES(pf.occurrence_id,1,ac,pf.departure_utc,pf.arrival_utc,revised_dep,revised_arr,revised_arr+interval '60 minutes');
 INSERT INTO crew_binding_fixture_14l.section9_dated_replacement_slots_v1(occurrence_id,world_id,airport_key,stand_type,direction,movement_utc,local_date,weekday,minute_of_day)
 SELECT pf.occurrence_id,1,z.airport,'terminal',z.direction,z.movement,(z.movement AT TIME ZONE ap.timezone_iana)::date,extract(isodow FROM z.movement AT TIME ZONE ap.timezone_iana)::int-1,extract(hour FROM z.movement AT TIME ZONE ap.timezone_iana)::int*60+extract(minute FROM z.movement AT TIME ZONE ap.timezone_iana)::int
 FROM (VALUES(pf.origin_airport_key,'departure',revised_dep),(pf.destination_airport_key,'arrival',revised_arr)) z(airport,direction,movement) JOIN crew_binding_fixture_14l.airport_reference_profiles ap ON ap.world_id=1 AND ap.airport_key=z.airport;
 SELECT cash_usd INTO baseline_cash FROM crew_binding_fixture_14l.airlines WHERE id=a.id;
 receipt:=crew_binding_fixture_14l.section9_stage_delayed_crew_approval_v1(a.owner_player_id,a.id,pf.occurrence_id,approval,revised_dep,revised_arr,1050,'{}',fo,fa,1,0,0);
 IF receipt->>'status'<>'delayed_crew_approval_disabled' THEN RAISE EXCEPTION 'release gate %',receipt;END IF;
 UPDATE crew_binding_fixture_14l.section9_delayed_crew_approval_release_v1 SET approval_enabled=true;
 receipt:=crew_binding_fixture_14l.section9_stage_delayed_crew_approval_v1(a.owner_player_id,a.id,pf.occurrence_id,approval,revised_dep,revised_arr,1050,'{}',fo,fa,1,0,0);
 IF receipt->>'status'<>'external_crew_contracting_disabled' THEN RAISE EXCEPTION 'external gate %',receipt;END IF;
 UPDATE crew_binding_fixture_14l.section9_external_crew_release_v1 SET contracting_enabled=true;
 receipt:=crew_binding_fixture_14l.section9_stage_delayed_crew_approval_v1(a.owner_player_id,a.id,pf.occurrence_id,approval,revised_dep+interval '1 minute',revised_arr,1050,'{}',fo,fa,1,0,0);
 IF receipt->>'status'<>'delayed_approval_slot_changed' THEN RAISE EXCEPTION 'stale slot %',receipt;END IF;
 receipt:=crew_binding_fixture_14l.section9_stage_delayed_crew_approval_v1(a.owner_player_id,a.id,pf.occurrence_id,approval,revised_dep,revised_arr,1000,'{}',fo,fa,1,0,0);
 IF receipt->>'status'<>'delayed_approval_budget_exceeded' THEN RAISE EXCEPTION 'budget %',receipt;END IF;
 IF EXISTS(SELECT 1 FROM crew_binding_fixture_14l.section9_delayed_crew_approvals_v1) THEN RAISE EXCEPTION 'blocked approval persisted';END IF;
 -- Advancing game time beyond report protects the original employee.
 PERFORM set_config('airlinerra.requote_fixture_clock',(pf.departure_utc-interval '1 hour')::text,true);
 receipt:=crew_binding_fixture_14l.section9_stage_delayed_crew_approval_v1(a.owner_player_id,a.id,pf.occurrence_id,approval,revised_dep,revised_arr,1050,'{}',fo,fa,1,0,0);
 IF receipt->>'status'<>'active_duty_release_required' THEN RAISE EXCEPTION 'active duty guard %',receipt;END IF;
 -- Isolated clock reset for independent before-report scenario.
 PERFORM set_config('airlinerra.requote_fixture_clock','2026-11-22T11:24:00Z',true);
 receipt:=crew_binding_fixture_14l.section9_stage_delayed_crew_approval_v1(a.owner_player_id,a.id,pf.occurrence_id,approval,revised_dep,revised_arr,1050,'{}',fo,fa,1,0,0);
 IF receipt->>'status'<>'delayed_crew_approval_staged' OR receipt->>'releasedAssignmentCount'<>'1' OR receipt->>'dispatchAuthorizationIssued'<>'false' OR (receipt->>'quotedCostUsd')::numeric<>1050 THEN RAISE EXCEPTION 'approval %',receipt;END IF;
 receipt2:=crew_binding_fixture_14l.section9_stage_delayed_crew_approval_v1(a.owner_player_id,a.id,pf.occurrence_id,approval,revised_dep,revised_arr,1050,'{}',fo,fa,1,0,0);
 IF receipt2->>'replayed'<>'true' THEN RAISE EXCEPTION 'idempotency %',receipt2;END IF;
 receipt2:=crew_binding_fixture_14l.section9_stage_delayed_crew_approval_v1(a.owner_player_id,a.id,pf.occurrence_id,req2,revised_dep,revised_arr,1050,'{}',fo,fa,1,0,0);
 IF receipt2->>'status'<>'delayed_approval_replay_conflict' THEN RAISE EXCEPTION 'duplicate approval %',receipt2;END IF;
 receipt2:=crew_binding_fixture_14l.section9_stage_delayed_crew_approval_v1(a.owner_player_id,a.id,pf.occurrence_id,approval,revised_dep,revised_arr,1500,'{}',fo,fa,1,0,0);
 IF receipt2->>'status'<>'delayed_approval_replay_conflict' THEN RAISE EXCEPTION 'changed replay %',receipt2;END IF;
 IF (SELECT count(*) FROM crew_binding_fixture_14l.section9_delayed_crew_approvals_v1)<>1 OR NOT EXISTS(SELECT 1 FROM crew_binding_fixture_14l.section9_delayed_crew_approvals_v1 WHERE approval_id=approval AND released_employee_ids=ca AND external_captains=1 AND quoted_cost_usd=1050 AND additional_reserved_usd=1050 AND captain_rate=350) THEN RAISE EXCEPTION 'receipt mismatch';END IF;
 IF (SELECT cash_usd FROM crew_binding_fixture_14l.airlines WHERE id=a.id)<>baseline_cash OR EXISTS(SELECT 1 FROM crew_binding_fixture_14l.section9_external_crew_contracts_v1) OR EXISTS(SELECT 1 FROM crew_binding_fixture_14l.section9_route_posted_flight_financials_v1) OR NOT EXISTS(SELECT 1 FROM crew_binding_fixture_14l.section9_planned_crew_seats_v1 WHERE plan_id=plan AND employee_id=cp) THEN RAISE EXCEPTION 'live roster or money mutated';END IF;
 -- Binding must not create a manifest until signed departure and fuel evidence.
 PERFORM set_config('airlinerra.requote_fixture_clock',revised_dep::text,true);
 receipt:=crew_binding_fixture_14l.section9_check_delayed_crew_binding_v1(a.id,pf.occurrence_id,revised_dep);
 IF receipt->>'status'<>'delayed_binding_disabled' THEN RAISE EXCEPTION 'binding disabled gate %',receipt;END IF;
 UPDATE crew_binding_fixture_14l.section9_delayed_crew_approval_release_v1 SET binding_enabled=true;
 INSERT INTO crew_binding_fixture_14l.section9_crew_movement_capture_release_v1 VALUES(1,true);
 receipt:=crew_binding_fixture_14l.section9_check_delayed_crew_binding_v1(a.id,pf.occurrence_id,revised_dep);
 IF receipt->>'status'<>'delayed_crew_binding_ready' OR jsonb_array_length(receipt->'duties')<>5 THEN RAISE EXCEPTION 'binding preflight %',receipt;END IF;
 receipt:=crew_binding_fixture_14l.section9_bind_approved_delayed_crew_v1(a.id,pf.occurrence_id,'fixture-missing-event');
 IF receipt->>'status'<>'delayed_binding_signed_departure_missing' THEN RAISE EXCEPTION 'missing evidence %',receipt;END IF;
 INSERT INTO crew_binding_fixture_14l.section9_crew_unavailability_v1(airline_id,pilot_id,reason,start_utc,end_utc) VALUES(a.id,fo[1],'sickness',pf.departure_utc,pf.arrival_utc+interval '1 day');
 receipt:=crew_binding_fixture_14l.section9_check_delayed_crew_binding_v1(a.id,pf.occurrence_id,revised_dep);
 IF receipt->>'status'<>'delayed_binding_employee_unavailable' THEN RAISE EXCEPTION 'changed illness %',receipt;END IF;
 DELETE FROM crew_binding_fixture_14l.section9_crew_unavailability_v1 WHERE pilot_id=fo[1];
 SELECT schedule_id INTO sc FROM crew_binding_fixture_14l.section9_dated_flight_occurrences_v1 WHERE id=pf.occurrence_id;
 ph:=pf.physical_flight_id;de:='test-delayed-depart-'||sc;ae:='test-delayed-arrive-'||sc;
 INSERT INTO crew_binding_fixture_14l.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc,source_kind)
 VALUES(1,de,repeat('a',64),a.id,ac,sc,1,1,pf.departure_utc::date,ph,'departed',pf.origin_airport_key,pf.destination_airport_key,pf.departure_utc,pf.arrival_utc,revised_dep,'signed_operated_game_flight_v1');
 INSERT INTO crew_binding_fixture_14l.section9_game_flight_fuel_departure_receipts_v1(physical_flight_id,airline_id,aircraft_inventory_id,departure_engine_event_id,departure_airport_key,destination_airport_key,configuration_id,fuel_custody_source_event_id,fuel_custody_revision,onboard_at_departure_kg,planned_trip_burn_kg,planned_contingency_kg,planned_holding_reserve_kg,minimum_planned_onboard_kg,model_version,verified_game_hour_utc)
 VALUES(ph,a.id,ac,de,pf.origin_airport_key,pf.destination_airport_key,conf,'test-fuel-custody',1,6000,4000,400,600,5000,'rollback-fixture',revised_dep);
 receipt:=crew_binding_fixture_14l.section9_bind_approved_delayed_crew_v1(a.id,pf.occurrence_id,de);
 IF receipt->>'status'<>'approved_delayed_crew_bound' OR receipt->>'externalPilotCount'<>'1' THEN RAISE EXCEPTION 'binding %',receipt;END IF;
 receipt:=crew_binding_fixture_14l.section9_bind_approved_delayed_crew_v1(a.id,pf.occurrence_id,de);
 IF receipt->>'status'<>'approved_delayed_crew_already_bound' THEN RAISE EXCEPTION 'binding replay %',receipt;END IF;
 IF NOT EXISTS(SELECT 1 FROM crew_binding_fixture_14l.section9_pilot_departure_manifests_v1 WHERE physical_flight_id=ph AND cardinality(captain_ids)=0 AND first_officer_ids=fo AND external_captain_count=1) THEN RAISE EXCEPTION 'manifest roster';END IF;
 IF NOT EXISTS(SELECT 1 FROM crew_binding_fixture_14l.section9_planned_crew_seats_v1 WHERE plan_id=plan AND employee_id=cp) OR EXISTS(SELECT 1 FROM crew_binding_fixture_14l.section9_planned_crew_seats_v1 WHERE plan_id=approval AND employee_id=cp) THEN RAISE EXCEPTION 'history projection';END IF;
 INSERT INTO crew_binding_fixture_14l.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc,source_kind)
 VALUES(1,ae,repeat('b',64),a.id,ac,sc,1,1,pf.departure_utc::date,ph,'arrived',pf.origin_airport_key,pf.destination_airport_key,pf.departure_utc,pf.arrival_utc,revised_arr+interval '15 minutes','signed_operated_game_flight_v1');
 receipt:=crew_binding_fixture_14l.section9_complete_bound_crew_arrival_v1(a.id,ph,ae);
 IF receipt->>'pilotsCredited'<>'1' OR receipt->>'flightMinutes'<>'195' THEN RAISE EXCEPTION 'pilot credit %',receipt;END IF;
 IF crew_binding_fixture_14l.section9_complete_bound_crew_arrival_v1(a.id,ph,ae)->>'pilotsCredited'<>'0' THEN RAISE EXCEPTION 'duplicate pilot credit';END IF;
 IF (SELECT total_flight_minutes FROM crew_binding_fixture_14l.section9_pilot_profiles_v1 WHERE crew_id=cp)<>0 THEN RAISE EXCEPTION 'released pilot credited';END IF;
 IF crew_binding_fixture_14l.section9_completed_external_crew_cost_v1(a.id,ph,ae)<>1137.50 THEN RAISE EXCEPTION 'actual contractor cost';END IF;
 receipt:=crew_binding_fixture_14l.section9_crew_actual_history_v1(a.id,fo[1],revised_arr+interval '1 hour');
 IF receipt->>'lastAirport'<>pf.destination_airport_key OR (receipt->>'lastDutyEndUtc')::timestamptz<>revised_arr+interval '45 minutes' THEN RAISE EXCEPTION 'crew actual history %',receipt;END IF;
 IF EXISTS(SELECT 1 FROM crew_binding_fixture_14l.section9_route_posted_flight_financials_v1) OR (SELECT cash_usd FROM crew_binding_fixture_14l.airlines WHERE id=a.id)<>baseline_cash THEN RAISE EXCEPTION 'unexpected finance mutation';END IF;
 result:=jsonb_build_object('status','passed','signedReplacementBound',true,'releasedCaptainNotCredited',true,'remainingPilotCreditedMinutes',195,'crewHistoryUsesNewBinding',true,'bindingReplaySafe',true,'changedIllnessRejected',true,'missingEvidenceRejected',true,'actualContractCostUsd',1137.50,'atomicStagedApproval',true,'releaseGatesProtected',true,'staleSlotRejected',true,'budgetExceededRejected',true,'activeDutyProtected',true,'releasedAssignmentRecorded',true,'exactReplaySafe',true,'changedReplayRejected',true,'contractReservationUsd',1050,'originalRosterPreserved',true,'financialWrites',false,'dispatchAuthorized',false);
 RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE=result::text;
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN PERFORM set_config('airlinerra.crew_approval_fixture_result',SQLERRM,true);END;
END $test$;
SELECT current_setting('airlinerra.crew_approval_fixture_result',true)::jsonb AS approval_test,to_regnamespace('crew_binding_fixture_14l') IS NULL AS isolated_schema_removed,(SELECT count(*) FROM airlinerra_game.section9_delayed_crew_approvals_v1) AS live_approvals;