-- Isolated schema acceptance, rolled back in full. Production tables/triggers are
-- never modified. Copies of production functions execute against fixture relations.
DO $test$
DECLARE tbl text; fn record; a record; ac uuid; conf bigint; grp text; hire jsonb; sc uuid; oid uuid; snap jsonb; assignments jsonb:='[]'; duties jsonb; start_at timestamptz:='2026-11-24T00:00:00Z'; dep timestamptz; arr timestamptz; orig text; dest text; plan uuid:=gen_random_uuid(); other_plan uuid:=gen_random_uuid(); r jsonb; i int; bad jsonb; result jsonb; ph text; de text; ae text; pf record; cp uuid; second_pf record; assessed jsonb; delay_mins int; revised_dep timestamptz; revised_arr timestamptz; v jsonb; q jsonb; ca uuid[]; fo uuid[]; fa uuid[]; baseline_cash numeric; approval uuid:=gen_random_uuid(); receipt jsonb; de2 text; ae2 text; ph2 text; history jsonb; reserve_hire jsonb; reserve_id uuid; release_at timestamptz; third_pf record; roll_start timestamptz; roll_snap jsonb; roll_assign jsonb; wrong_assign jsonb; item jsonb; third_de text; third_ae text;
BEGIN
 BEGIN
 CREATE SCHEMA crew_external_downstream_fixture_14r;
 FOREACH tbl IN ARRAY ARRAY['airlines','airline_aircraft_inventory','airport_reference_profiles','section9_crew_bases_v1','section9_flight_crew_model_policy_v1','section9_pilot_qualification_groups_v1','section9_airline_crew_roster_v1','section9_pilot_profiles_v1','section9_pilot_family_permissions_v1','section9_pilot_base_assignments_v1','section9_cabin_crew_pools_v1','section9_cabin_crew_members_v1','section9_crew_unavailability_v1','section9_shared_crew_employment_release_v1','section9_shared_crew_salary_policy_v1','section9_shared_crew_hire_batches_v1','section9_crew_scheduler_policy_v2','airline_flight_schedule_drafts_v1','section9_dated_flight_occurrences_v1','section9_pilot_departure_manifests_v1','section9_crew_plan_batches_v1','section9_planned_flight_crews_v1','section9_planned_crew_duties_v1','section9_planned_crew_seats_v1','section9_operated_flight_movements_v1','section9_game_flight_fuel_departure_receipts_v1','section9_pilot_flight_experience_v1','section9_crew_movement_capture_release_v1','section9_operated_crew_bindings_v1','section9_operated_crew_capture_issues_v1','section9_external_crew_contracts_v1','section9_external_crew_release_v1','section9_disruption_release_v1','section9_replacement_slot_pairs_v1','section9_dated_replacement_slots_v1','section9_external_crew_rate_v1','section9_route_posted_flight_financials_v1','section9_delayed_crew_approvals_v1','section9_delayed_crew_approval_release_v1'] LOOP
 EXECUTE format('CREATE TABLE crew_external_downstream_fixture_14r.%I (LIKE airlinerra_game.%I INCLUDING ALL)',tbl,tbl);
 END LOOP;
 FOR fn IN SELECT c.conrelid::regclass::text rel,c.conname,pg_get_constraintdef(c.oid) def FROM pg_constraint c WHERE c.contype='f' AND c.conrelid IN('airlinerra_game.section9_crew_plan_batches_v1'::regclass,'airlinerra_game.section9_planned_flight_crews_v1'::regclass,'airlinerra_game.section9_planned_crew_duties_v1'::regclass,'airlinerra_game.section9_planned_crew_seats_v1'::regclass,'airlinerra_game.section9_operated_crew_bindings_v1'::regclass,'airlinerra_game.section9_operated_crew_capture_issues_v1'::regclass) LOOP
 EXECUTE 'ALTER TABLE '||replace(fn.rel,'airlinerra_game','crew_external_downstream_fixture_14r')||' ADD CONSTRAINT '||quote_ident(fn.conname)||' '||replace(fn.def,'airlinerra_game','crew_external_downstream_fixture_14r');
 END LOOP;
 FOR fn IN SELECT pg_get_functiondef(p.oid) def FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='airlinerra_game' AND p.proname IN('section9_owned_shared_crew_payroll_forecast_v1','section9_owned_shared_crew_hire_quote_v1','section9_confirm_owned_shared_crew_hire_v1','section9_pilot_can_fill_rank_v1','section9_crew_unavailability_windows_v1','section9_owned_weekly_crew_input_v1','section9_crew_rotation_window_v2','section9_crew_duty_fit_v2','section9_save_owned_crew_plan_preview_v1','section9_record_pilot_departure_manifest_v1','section9_credit_completed_pilot_flight_v1','section9_capture_dispatched_crew_v1','section9_complete_bound_crew_arrival_v1','section9_crew_actual_history_v1','section9_flight_crew_requirements_v1','section9_cabin_composition_valid_v1','section9_verified_external_cabin_input_v1','section9_pilot_counts_valid_v1','section9_effective_dispatch_window_v1','section9_delayed_crew_duty_window_v1','section9_assess_delayed_crew_rotation_v1','section9_external_crew_cost_v1','section9_delayed_external_crew_quote_v1','section9_validate_delayed_crew_roster_v1','section9_stage_delayed_crew_approval_v1','section9_check_delayed_crew_binding_v1','section9_bind_approved_delayed_crew_v1','section9_bound_delayed_external_cost_v1','section9_completed_external_crew_cost_v1','section9_terminal_crew_release_proof_v1','section9_plan_terminal_delayed_crew_v1','section9_auto_approve_terminal_delayed_crew_v1','section9_auto_recover_delayed_crew_cycle_v1','section9_delayed_downstream_scope_v1','section9_same_duty_continuation_scope_v1','section9_same_duty_prior_sector_v1','section9_residual_onward_scope_v1','section9_residual_crew_commitment_v1','section9_residual_replacement_proof_v1','section9_downstream_crew_reconciliation_v1','section9_owned_rolling_crew_input_v1','section9_save_owned_rolling_crew_plan_v1','section9_auto_replan_downstream_crew_v1','section9_auto_replan_downstream_cycle_v1','section9_external_crew_quote_v1','section9_authorize_external_crew_v1') ORDER BY CASE p.proname WHEN 'section9_owned_shared_crew_payroll_forecast_v1' THEN 0 WHEN 'section9_owned_shared_crew_hire_quote_v1' THEN 1 ELSE 2 END LOOP
 EXECUTE replace(fn.def,'airlinerra_game','crew_external_downstream_fixture_14r');
 END LOOP;
 CREATE FUNCTION crew_external_downstream_fixture_14r.section9_verified_world_instant_v1() RETURNS timestamptz LANGUAGE sql STABLE AS 'SELECT coalesce(nullif(current_setting(''airlinerra.requote_fixture_clock'',true),'''')::timestamptz,''2026-11-22T11:24:00Z''::timestamptz)';
 SELECT id,owner_player_id,home_airport_key,iata_code INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 SELECT f.id,f.configuration_id,p.qualification_group INTO STRICT ac,conf,grp FROM airlinerra_game.airline_aircraft_inventory f JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=f.configuration_id WHERE f.airline_id=a.id AND p.seat_basis<>'cargo_zero' LIMIT 1;
 INSERT INTO crew_external_downstream_fixture_14r.airlines SELECT * FROM airlinerra_game.airlines WHERE id=a.id;
 INSERT INTO crew_external_downstream_fixture_14r.airline_aircraft_inventory SELECT * FROM airlinerra_game.airline_aircraft_inventory WHERE id=ac;
 SELECT string_agg(quote_ident(column_name),',' ORDER BY ordinal_position) INTO tbl FROM information_schema.columns WHERE table_schema='airlinerra_game' AND table_name='airport_reference_profiles' AND is_generated='NEVER';
 EXECUTE format('INSERT INTO crew_external_downstream_fixture_14r.airport_reference_profiles(%s) SELECT %s FROM airlinerra_game.airport_reference_profiles WHERE world_id=1 AND airport_key=ANY($1)',tbl,tbl) USING ARRAY[a.home_airport_key,'OURAIRPORTS:2212'];
 INSERT INTO crew_external_downstream_fixture_14r.section9_crew_bases_v1 SELECT * FROM airlinerra_game.section9_crew_bases_v1 WHERE airline_id=a.id AND airport_key=a.home_airport_key;
 INSERT INTO crew_external_downstream_fixture_14r.section9_flight_crew_model_policy_v1 SELECT * FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=conf;
 INSERT INTO crew_external_downstream_fixture_14r.section9_pilot_qualification_groups_v1 SELECT * FROM airlinerra_game.section9_pilot_qualification_groups_v1 WHERE qualification_group=grp;
 INSERT INTO crew_external_downstream_fixture_14r.section9_shared_crew_employment_release_v1(world_id,manual_hiring_enabled,automatic_hiring_enabled,payroll_enabled) VALUES(1,true,false,false);
 INSERT INTO crew_external_downstream_fixture_14r.section9_shared_crew_salary_policy_v1 SELECT * FROM airlinerra_game.section9_shared_crew_salary_policy_v1;
 INSERT INTO crew_external_downstream_fixture_14r.section9_crew_scheduler_policy_v2 SELECT * FROM airlinerra_game.section9_crew_scheduler_policy_v2;
 INSERT INTO crew_external_downstream_fixture_14r.section9_external_crew_rate_v1 SELECT * FROM airlinerra_game.section9_external_crew_rate_v1;
 INSERT INTO crew_external_downstream_fixture_14r.section9_external_crew_release_v1 VALUES(1,false);
 hire:=crew_external_downstream_fixture_14r.section9_confirm_owned_shared_crew_hire_v1(a.owner_player_id,a.id,gen_random_uuid(),a.home_airport_key,grp,1,1,4,22800);
 IF hire->>'status'<>'shared_crew_hired' THEN RAISE EXCEPTION 'hire %',hire;END IF;

 reserve_hire:=crew_external_downstream_fixture_14r.section9_confirm_owned_shared_crew_hire_v1(a.owner_player_id,a.id,gen_random_uuid(),a.home_airport_key,grp,1,0,0,1000000);
 IF reserve_hire->>'status'<>'shared_crew_hired' THEN RAISE EXCEPTION 'reserve hire %',reserve_hire;END IF;
 reserve_id:=(reserve_hire->'pilotIds'->>0)::uuid;
 FOR i IN 1..3 LOOP
 dep:=start_at+make_interval(hours=>CASE WHEN i=1 THEN 6 WHEN i=2 THEN 12 ELSE 54 END);arr:=dep+interval '3 hours';
 orig:=CASE WHEN i=2 THEN 'OURAIRPORTS:2212' ELSE a.home_airport_key END;dest:=CASE WHEN i=2 THEN a.home_airport_key ELSE 'OURAIRPORTS:2212' END;
 INSERT INTO crew_external_downstream_fixture_14r.airline_flight_schedule_drafts_v1(airline_id,aircraft_inventory_id,configuration_id,flight_number,origin_airport_key,destination_airport_key,reference_departure_utc,reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id,status,operationally_verified)
 VALUES(a.id,ac,conf,a.iata_code|| (980+i),orig,dest,dep,arr,jsonb_build_array(jsonb_build_object('day',extract(isodow FROM dep)::int-1,'time',to_char(dep,'HH24:MI'))),'{}',a.owner_player_id,'active',true) RETURNING id INTO sc;
 INSERT INTO crew_external_downstream_fixture_14r.section9_dated_flight_occurrences_v1(world_id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,weekly_entry,flight_local_date,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,turnaround_minutes,verified_passenger_seats,booking_status,booked_seats,recognized_revenue_usd,source_kind)
 VALUES(1,a.id,sc,ac,1,1,dep::date,orig,dest,dep,arr,60,156,'not_open',0,0,'verified_schedule_preview_not_saleable') RETURNING id INTO oid;
 SELECT jsonb_agg(jsonb_build_object('employeeId',x.emp,'role',x.role,'dutyStartUtc',CASE WHEN i=3 THEN dep-interval '2 hours' ELSE start_at+interval '4 hours' END,'dutyEndUtc',arr+interval '30 minutes')) INTO duties FROM(
 SELECT hire->'pilotIds'->>0 emp,'captain' role UNION ALL SELECT hire->'pilotIds'->>1,'firstOfficer' UNION ALL SELECT value,'cabin' FROM jsonb_array_elements_text(hire->'cabinIds'))x;
 assignments:=assignments||jsonb_build_array(jsonb_build_object('flightId',oid,'aircraftId',ac,'departureUtc',dep,'arrivalUtc',arr,'captains',jsonb_build_array(hire->'pilotIds'->0),'firstOfficers',jsonb_build_array(hire->'pilotIds'->1),'cabinCrew',hire->'cabinIds','duties',duties));
 END LOOP;
 snap:=crew_external_downstream_fixture_14r.section9_owned_weekly_crew_input_v1(a.owner_player_id,a.id,start_at);
 r:=crew_external_downstream_fixture_14r.section9_save_owned_crew_plan_preview_v1(a.owner_player_id,a.id,plan,start_at,snap,assignments);
 IF r->>'status'<>'validated_preview' OR r->>'dutyCount'<>'12' OR r->>'flightCount'<>'3' THEN RAISE EXCEPTION 'plan %',r;END IF;
 IF (SELECT count(*) FROM crew_external_downstream_fixture_14r.section9_planned_crew_seats_v1 WHERE plan_id=plan)<>18 OR EXISTS(SELECT 1 FROM crew_external_downstream_fixture_14r.section9_planned_crew_duties_v1 WHERE plan_id=plan AND duty_end_utc-duty_start_utc NOT IN(interval '11 hours 30 minutes',interval '5 hours 30 minutes')) THEN RAISE EXCEPTION 'duty manifest';END IF;

 SELECT * INTO STRICT pf FROM crew_external_downstream_fixture_14r.section9_planned_flight_crews_v1 WHERE plan_id=plan AND departure_utc=start_at+interval '6 hours';
 SELECT * INTO STRICT second_pf FROM crew_external_downstream_fixture_14r.section9_planned_flight_crews_v1 WHERE plan_id=plan AND departure_utc=start_at+interval '12 hours';
 SELECT * INTO STRICT third_pf FROM crew_external_downstream_fixture_14r.section9_planned_flight_crews_v1 WHERE plan_id=plan AND departure_utc=start_at+interval '54 hours';
 SELECT schedule_id INTO sc FROM crew_external_downstream_fixture_14r.section9_dated_flight_occurrences_v1 WHERE id=pf.occurrence_id;
 ph:=pf.physical_flight_id;de:='test-crew-bound-depart-'||sc;ae:='test-crew-bound-arrive-'||sc;cp:=(hire->'pilotIds'->>0)::uuid;
 INSERT INTO crew_external_downstream_fixture_14r.section9_crew_movement_capture_release_v1 VALUES(1,false);
 IF crew_external_downstream_fixture_14r.section9_capture_dispatched_crew_v1(a.id,ph,de)->>'status'<>'crew_capture_disabled' THEN RAISE EXCEPTION 'gate';END IF;
 UPDATE crew_external_downstream_fixture_14r.section9_crew_movement_capture_release_v1 SET capture_enabled=true;
 IF crew_external_downstream_fixture_14r.section9_capture_dispatched_crew_v1(a.id,ph,de)->>'status'<>'crew_departure_evidence_missing' THEN RAISE EXCEPTION 'missing signed evidence';END IF;
 INSERT INTO crew_external_downstream_fixture_14r.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc,source_kind)
 VALUES(1,de,repeat('a',64),a.id,ac,sc,1,1,pf.departure_utc::date,ph,'departed',pf.origin_airport_key,pf.destination_airport_key,pf.departure_utc,pf.arrival_utc,pf.departure_utc,'signed_operated_game_flight_v1');
 INSERT INTO crew_external_downstream_fixture_14r.section9_game_flight_fuel_departure_receipts_v1(physical_flight_id,airline_id,aircraft_inventory_id,departure_engine_event_id,departure_airport_key,destination_airport_key,configuration_id,fuel_custody_source_event_id,fuel_custody_revision,onboard_at_departure_kg,planned_trip_burn_kg,planned_contingency_kg,planned_holding_reserve_kg,minimum_planned_onboard_kg,model_version,verified_game_hour_utc)
 VALUES(ph,a.id,ac,de,pf.origin_airport_key,pf.destination_airport_key,conf,'test-fuel-custody',1,6000,4000,400,600,5000,'rollback-fixture',pf.departure_utc);
 INSERT INTO crew_external_downstream_fixture_14r.section9_crew_unavailability_v1(airline_id,pilot_id,reason,start_utc,end_utc) VALUES(a.id,cp,'sickness',start_at+interval '5 hours',start_at+interval '7 hours');
 r:=crew_external_downstream_fixture_14r.section9_capture_dispatched_crew_v1(a.id,ph,de);
 IF r->>'status'<>'crew_employee_unavailable' OR r->>'crewCancellationTriggered'<>'false' THEN RAISE EXCEPTION 'absence %',r;END IF;
 DELETE FROM crew_external_downstream_fixture_14r.section9_crew_unavailability_v1 WHERE pilot_id=cp;
 r:=crew_external_downstream_fixture_14r.section9_capture_dispatched_crew_v1(a.id,ph,de);
 IF r->>'status'<>'crew_departure_bound' OR r->>'pilotCount'<>'2' OR r->>'cabinCount'<>'4' THEN RAISE EXCEPTION 'binding %',r;END IF;
 IF crew_external_downstream_fixture_14r.section9_capture_dispatched_crew_v1(a.id,ph,de)->>'status'<>'crew_departure_already_bound' THEN RAISE EXCEPTION 'replay';END IF;
 IF crew_external_downstream_fixture_14r.section9_complete_bound_crew_arrival_v1(a.id,ph,ae)->>'status'<>'crew_arrival_evidence_missing' THEN RAISE EXCEPTION 'premature arrival';END IF;
 r:=crew_external_downstream_fixture_14r.section9_crew_actual_history_v1(a.id,cp,pf.departure_utc+interval '1 hour');
 IF r->>'availableForNewDuty'<>'false' OR r->>'status'<>'crew_in_flight_or_postflight' THEN RAISE EXCEPTION 'in flight %',r;END IF;
 INSERT INTO crew_external_downstream_fixture_14r.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc,source_kind)
 VALUES(1,ae,repeat('b',64),a.id,ac,sc,1,1,pf.departure_utc::date,ph,'arrived',pf.origin_airport_key,pf.destination_airport_key,pf.departure_utc,pf.arrival_utc,pf.arrival_utc+interval '15 minutes','signed_operated_game_flight_v1');
 r:=crew_external_downstream_fixture_14r.section9_complete_bound_crew_arrival_v1(a.id,ph,ae);
 IF r->>'status'<>'pilot_experience_credited' OR r->>'pilotsCredited'<>'2' OR r->>'flightMinutes'<>'195' THEN RAISE EXCEPTION 'credit %',r;END IF;
 IF crew_external_downstream_fixture_14r.section9_complete_bound_crew_arrival_v1(a.id,ph,ae)->>'pilotsCredited'<>'0' THEN RAISE EXCEPTION 'duplicate hours';END IF;
 IF (SELECT total_flight_minutes FROM crew_external_downstream_fixture_14r.section9_pilot_profiles_v1 WHERE crew_id=cp)<>195 THEN RAISE EXCEPTION 'total minutes';END IF;
 r:=crew_external_downstream_fixture_14r.section9_crew_actual_history_v1(a.id,cp,pf.arrival_utc+interval '20 minutes');
 IF r->>'availableForNewDuty'<>'false' THEN RAISE EXCEPTION 'postflight %',r;END IF;
 r:=crew_external_downstream_fixture_14r.section9_crew_actual_history_v1(a.id,cp,pf.arrival_utc+interval '1 hour');
 IF r->>'status'<>'crew_completed_duty_history' OR r->>'lastAirport'<>pf.destination_airport_key OR (r->>'lastDutyEndUtc')::timestamptz<>pf.arrival_utc+interval '45 minutes' OR jsonb_array_length(r->'history')<>1 THEN RAISE EXCEPTION 'actual history %',r;END IF;
 IF crew_external_downstream_fixture_14r.section9_crew_actual_history_v1(a.id,(hire->'cabinIds'->>0)::uuid,pf.arrival_utc+interval '1 hour')->>'lastAirport'<>pf.destination_airport_key THEN RAISE EXCEPTION 'cabin airport';END IF;
 -- The return leg has not departed. Test actual prior arrival + verified revised slots.
 PERFORM set_config('airlinerra.requote_fixture_clock',(pf.arrival_utc+interval '1 hour')::text,true);
 ca:=ARRAY[cp];fo:=ARRAY[(hire->'pilotIds'->>1)::uuid];SELECT array_agg(value::uuid) INTO fa FROM jsonb_array_elements_text(hire->'cabinIds');
 SELECT cash_usd INTO baseline_cash FROM crew_external_downstream_fixture_14r.airlines WHERE id=a.id;
 INSERT INTO crew_external_downstream_fixture_14r.section9_disruption_release_v1(world_id,delayed_execution_enabled) VALUES(1,true);
 assessed:=crew_external_downstream_fixture_14r.section9_assess_delayed_crew_rotation_v1(a.owner_player_id,a.id,second_pf.occurrence_id);
 IF assessed->>'status'<>'verified_delay_window_required' THEN RAISE EXCEPTION 'no delay guard %',assessed;END IF;
 delay_mins:=20;
 revised_dep:=second_pf.departure_utc+make_interval(mins=>delay_mins);
 revised_arr:=second_pf.arrival_utc+make_interval(mins=>delay_mins);
 INSERT INTO crew_external_downstream_fixture_14r.section9_replacement_slot_pairs_v1(occurrence_id,world_id,aircraft_inventory_id,original_departure_utc,original_arrival_utc,revised_departure_utc,revised_arrival_utc,available_utc)
 VALUES(second_pf.occurrence_id,1,ac,second_pf.departure_utc,second_pf.arrival_utc,revised_dep,revised_arr,revised_arr+interval '60 minutes')
 ON CONFLICT(occurrence_id) DO UPDATE SET revised_departure_utc=excluded.revised_departure_utc,revised_arrival_utc=excluded.revised_arrival_utc,available_utc=excluded.available_utc;
 DELETE FROM crew_external_downstream_fixture_14r.section9_dated_replacement_slots_v1 WHERE occurrence_id=second_pf.occurrence_id;
 INSERT INTO crew_external_downstream_fixture_14r.section9_dated_replacement_slots_v1(occurrence_id,world_id,airport_key,stand_type,direction,movement_utc,local_date,weekday,minute_of_day)
 SELECT second_pf.occurrence_id,1,z.airport,'terminal',z.direction,z.movement,(z.movement AT TIME ZONE ap.timezone_iana)::date,extract(isodow FROM z.movement AT TIME ZONE ap.timezone_iana)::int-1,extract(hour FROM z.movement AT TIME ZONE ap.timezone_iana)::int*60+extract(minute FROM z.movement AT TIME ZONE ap.timezone_iana)::int
 FROM (VALUES(second_pf.origin_airport_key,'departure',revised_dep),(second_pf.destination_airport_key,'arrival',revised_arr)) z(airport,direction,movement) JOIN crew_external_downstream_fixture_14r.airport_reference_profiles ap ON ap.world_id=1 AND ap.airport_key=z.airport;


 INSERT INTO crew_external_downstream_fixture_14r.section9_delayed_crew_approval_release_v1(world_id,approval_enabled,binding_enabled) VALUES(1,true,true);
 UPDATE crew_external_downstream_fixture_14r.section9_external_crew_release_v1 SET contracting_enabled=true;
 receipt:=crew_external_downstream_fixture_14r.section9_auto_approve_terminal_delayed_crew_v1(a.owner_player_id,a.id,second_pf.occurrence_id);
 IF receipt->>'status'<>'automatic_delayed_recovery_disabled' THEN RAISE EXCEPTION 'automatic gate %',receipt;END IF;
 receipt:=crew_external_downstream_fixture_14r.section9_auto_recover_delayed_crew_cycle_v1(20);
 IF receipt->>'status'<>'automatic_delayed_recovery_disabled' OR receipt->>'approvalsSaved'<>'0' THEN RAISE EXCEPTION 'cycle gate %',receipt;END IF;
 receipt:=crew_external_downstream_fixture_14r.section9_auto_replan_downstream_cycle_v1(5);
 IF receipt->>'status'<>'automatic_downstream_replan_disabled' THEN RAISE EXCEPTION 'downstream gate %',receipt;END IF;
 UPDATE crew_external_downstream_fixture_14r.section9_delayed_crew_approval_release_v1 SET automatic_recovery_enabled=true,automatic_downstream_replan_enabled=true;
 release_at:=crew_external_downstream_fixture_14r.section9_verified_world_instant_v1();
 IF release_at<>pf.arrival_utc+interval '1 hour' THEN RAISE EXCEPTION 'release clock %',release_at;END IF;
 receipt:=crew_external_downstream_fixture_14r.section9_plan_terminal_delayed_crew_v1(a.owner_player_id,a.id,second_pf.occurrence_id);
 IF receipt->>'status'<>'automatic_terminal_recovery_validated' OR receipt->>'externalCaptains'<>'0' OR receipt->'captains'<>to_jsonb(ca) THEN RAISE EXCEPTION 'retain original captain %',receipt;END IF;
 receipt:=crew_external_downstream_fixture_14r.section9_delayed_downstream_scope_v1(a.id,plan,second_pf.occurrence_id,revised_arr);
 IF receipt->>'status'<>'downstream_scope_verified' OR receipt->>'affectedCount'<>'1' OR NOT receipt->'affectedOccurrences'?third_pf.occurrence_id::text THEN RAISE EXCEPTION 'downstream scope %',receipt;END IF;
 IF crew_external_downstream_fixture_14r.section9_delayed_downstream_scope_v1(a.id,plan,pf.occurrence_id,pf.arrival_utc)->>'status'<>'downstream_active_rotation_requires_replan' THEN RAISE EXCEPTION 'same-duty onward leg guard';END IF;
 -- No needless release of an eligible actively reporting captain.
 receipt:=crew_external_downstream_fixture_14r.section9_stage_delayed_crew_approval_v1(a.owner_player_id,a.id,second_pf.occurrence_id,approval,revised_dep,revised_arr,1050,'{}',fo,fa,1,0,0);
 IF receipt->>'status'<>'active_duty_release_required' THEN RAISE EXCEPTION 'eligible captain release guard %',receipt;END IF;
 INSERT INTO crew_external_downstream_fixture_14r.section9_crew_unavailability_v1(airline_id,pilot_id,reason,start_utc,end_utc) VALUES(a.id,cp,'sickness',release_at,second_pf.arrival_utc+interval '1 day');
 receipt:=crew_external_downstream_fixture_14r.section9_plan_terminal_delayed_crew_v1(a.owner_player_id,a.id,second_pf.occurrence_id);
 IF receipt->>'status'<>'automatic_terminal_recovery_validated' OR receipt->>'externalCaptains'<>'1' OR receipt->>'internalReserveCount'<>'0' THEN RAISE EXCEPTION 'external fallback %',receipt;END IF;
 receipt:=crew_external_downstream_fixture_14r.section9_validate_delayed_crew_roster_v1(a.owner_player_id,a.id,second_pf.occurrence_id,ARRAY[reserve_id],fo,fa,0,0,0);
 IF receipt->>'status'<>'reserve_crew_wrong_airport' THEN RAISE EXCEPTION 'wrong airport reserve %',receipt;END IF;
 BEGIN
  -- A separate fixture scenario: this reserve was already stationed at
  -- the intermediate airport. Do not move any employee in real gameplay.
  INSERT INTO crew_external_downstream_fixture_14r.section9_crew_bases_v1(airline_id,world_id,airport_key) VALUES(a.id,1,second_pf.origin_airport_key) ON CONFLICT DO NOTHING;
  UPDATE crew_external_downstream_fixture_14r.section9_pilot_base_assignments_v1 SET base_airport_key=second_pf.origin_airport_key,initial_airport_key=second_pf.origin_airport_key WHERE airline_id=a.id AND crew_id=reserve_id;
  receipt:=crew_external_downstream_fixture_14r.section9_plan_terminal_delayed_crew_v1(a.owner_player_id,a.id,second_pf.occurrence_id);
  IF receipt->>'status'<>'automatic_terminal_recovery_validated' OR receipt->>'externalCaptains'<>'0' OR receipt->>'internalReserveCount'<>'1' OR receipt->'captains'<>to_jsonb(ARRAY[reserve_id]) THEN RAISE EXCEPTION 'automatic internal priority %',receipt;END IF;
  BEGIN
   receipt:=crew_external_downstream_fixture_14r.section9_auto_recover_delayed_crew_cycle_v1(20);
   IF receipt->>'checked'<>'0' THEN RAISE EXCEPTION 'non-saleable cycle candidate %',receipt;END IF;
   UPDATE crew_external_downstream_fixture_14r.section9_dated_flight_occurrences_v1 SET booking_status='open',source_kind='game_verified_saleable_schedule_v1' WHERE id=second_pf.occurrence_id;
   receipt:=crew_external_downstream_fixture_14r.section9_auto_recover_delayed_crew_cycle_v1(20);
   IF receipt->>'checked'<>'1' OR receipt->>'approvalsSaved'<>'1' OR NOT EXISTS(SELECT 1 FROM crew_external_downstream_fixture_14r.section9_delayed_crew_approvals_v1 WHERE occurrence_id=second_pf.occurrence_id AND internal_captains=ARRAY[reserve_id] AND quoted_cost_usd=0) THEN RAISE EXCEPTION 'cycle internal reserve %',receipt;END IF;
   receipt:=crew_external_downstream_fixture_14r.section9_auto_recover_delayed_crew_cycle_v1(20);
   IF receipt->>'checked'<>'0' OR receipt->>'approvalsSaved'<>'0' THEN RAISE EXCEPTION 'cycle duplicate %',receipt;END IF;
   RAISE EXCEPTION USING ERRCODE='ZX003',MESSAGE='rollback automatic cycle case';
  EXCEPTION WHEN SQLSTATE 'ZX003' THEN NULL;END;
  receipt:=crew_external_downstream_fixture_14r.section9_auto_approve_terminal_delayed_crew_v1(a.owner_player_id,a.id,second_pf.occurrence_id);
  IF receipt->>'status'<>'delayed_crew_approval_staged' OR receipt->>'activeDutyReleaseCount'<>'1' OR (receipt->>'quotedCostUsd')::numeric<>0 THEN RAISE EXCEPTION 'stationed reserve %',receipt;END IF;
  PERFORM set_config('airlinerra.requote_fixture_clock',revised_dep::text,true);
  receipt:=crew_external_downstream_fixture_14r.section9_check_delayed_crew_binding_v1(a.id,second_pf.occurrence_id,revised_dep);
  IF receipt->>'status'<>'delayed_crew_binding_ready' OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(receipt->'duties') x WHERE x->>'employeeId'=reserve_id::text AND x->>'continuedDuty'='false' AND x->>'startingAirport'=second_pf.origin_airport_key) THEN RAISE EXCEPTION 'reserve preflight %',receipt;END IF;
  RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='restore reserve scenario';
 EXCEPTION WHEN SQLSTATE 'ZX002' THEN NULL;END;
 -- Prove missing signed arrival blocks release, independently of illness.
 BEGIN
  DELETE FROM crew_external_downstream_fixture_14r.section9_operated_flight_movements_v1 WHERE engine_event_id=ae;
  receipt:=crew_external_downstream_fixture_14r.section9_terminal_crew_release_proof_v1(a.id,plan,second_pf.occurrence_id,cp,release_at,revised_dep);
  IF receipt->>'status'<>'release_prior_arrival_unverified' THEN RAISE EXCEPTION 'unverified release %',receipt;END IF;
  RAISE EXCEPTION USING ERRCODE='ZX002',MESSAGE='restore arrival';
 EXCEPTION WHEN SQLSTATE 'ZX002' THEN NULL;END;
 receipt:=crew_external_downstream_fixture_14r.section9_stage_delayed_crew_approval_v1(a.owner_player_id,a.id,second_pf.occurrence_id,approval,revised_dep,revised_arr,1000,'{}',fo,fa,1,0,0);
 IF receipt->>'status'<>'delayed_approval_budget_exceeded' OR EXISTS(SELECT 1 FROM crew_external_downstream_fixture_14r.section9_planned_crew_duties_v1 WHERE actual_release_game_utc IS NOT NULL) THEN RAISE EXCEPTION 'budget rollback %',receipt;END IF;
 receipt:=crew_external_downstream_fixture_14r.section9_auto_approve_terminal_delayed_crew_v1(a.owner_player_id,a.id,second_pf.occurrence_id);
 approval:=(receipt->>'approvalId')::uuid;
 IF receipt->>'status'<>'delayed_crew_approval_staged' OR receipt->>'activeDutyReleaseCount'<>'1' OR receipt->>'releasedAssignmentCount'<>'1' THEN RAISE EXCEPTION 'handover approval %',receipt;END IF;
 receipt:=crew_external_downstream_fixture_14r.section9_auto_approve_terminal_delayed_crew_v1(a.owner_player_id,a.id,second_pf.occurrence_id);
 IF receipt->>'status'<>'automatic_delayed_recovery_existing_approval' OR receipt->>'approvalId'<>approval::text THEN RAISE EXCEPTION 'automatic duplicate %',receipt;END IF;
 IF NOT EXISTS(SELECT 1 FROM crew_external_downstream_fixture_14r.section9_planned_crew_duties_v1 WHERE plan_id=plan AND employee_id=cp AND actual_release_game_utc=release_at AND actual_release_approval_id=approval AND actual_release_airport_key=second_pf.origin_airport_key AND duty_start_utc=start_at+interval '4 hours') THEN RAISE EXCEPTION 'release duty evidence';END IF;
 receipt:=crew_external_downstream_fixture_14r.section9_downstream_crew_reconciliation_v1(a.id,third_pf.occurrence_id);
 IF receipt->>'status'<>'downstream_waiting_for_actual_arrival' THEN RAISE EXCEPTION 'downstream before arrival %',receipt;END IF;
 receipt:=crew_external_downstream_fixture_14r.section9_auto_replan_downstream_crew_v1(a.owner_player_id,a.id);
 IF receipt->>'status'<>'automatic_downstream_waiting_for_arrival' THEN RAISE EXCEPTION 'auto before arrival %',receipt;END IF;
 receipt:=crew_external_downstream_fixture_14r.section9_auto_replan_downstream_cycle_v1(5);
 IF receipt->>'checked'<>'0' OR receipt->>'plansSaved'<>'0' THEN RAISE EXCEPTION 'cycle before arrival %',receipt;END IF;
 roll_start:=release_at+interval '1 minute';
 receipt:=crew_external_downstream_fixture_14r.section9_save_owned_rolling_crew_plan_v1(a.owner_player_id,a.id,other_plan,roll_start,'{}','[]');
 IF receipt->>'status'<>'crew_pending_delayed_approval_protected' THEN RAISE EXCEPTION 'pending plan guard %',receipt;END IF;
 history:=crew_external_downstream_fixture_14r.section9_crew_actual_history_v1(a.id,cp,release_at+interval '1 minute');
 IF history->>'lastAirport'<>second_pf.origin_airport_key OR (history->>'lastDutyEndUtc')::timestamptz<>release_at THEN RAISE EXCEPTION 'released history %',history;END IF;
 PERFORM set_config('airlinerra.requote_fixture_clock',revised_dep::text,true);
 receipt:=crew_external_downstream_fixture_14r.section9_check_delayed_crew_binding_v1(a.id,second_pf.occurrence_id,revised_dep);
 IF receipt->>'status'<>'delayed_crew_binding_ready' OR jsonb_array_length(receipt->'duties')<>5 OR EXISTS(SELECT 1 FROM jsonb_array_elements(receipt->'duties') x WHERE x->>'continuedDuty'<>'true' OR x->>'employeeId'=cp::text) THEN RAISE EXCEPTION 'handover preflight %',receipt;END IF;
 SELECT schedule_id INTO sc FROM crew_external_downstream_fixture_14r.section9_dated_flight_occurrences_v1 WHERE id=second_pf.occurrence_id;
 ph2:=second_pf.physical_flight_id;de2:='test-handover-depart-'||sc;ae2:='test-handover-arrive-'||sc;
 INSERT INTO crew_external_downstream_fixture_14r.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc,source_kind)
 VALUES(1,de2,repeat('a',64),a.id,ac,sc,1,1,second_pf.departure_utc::date,ph2,'departed',second_pf.origin_airport_key,second_pf.destination_airport_key,second_pf.departure_utc,second_pf.arrival_utc,revised_dep,'signed_operated_game_flight_v1');
 INSERT INTO crew_external_downstream_fixture_14r.section9_game_flight_fuel_departure_receipts_v1(physical_flight_id,airline_id,aircraft_inventory_id,departure_engine_event_id,departure_airport_key,destination_airport_key,configuration_id,fuel_custody_source_event_id,fuel_custody_revision,onboard_at_departure_kg,planned_trip_burn_kg,planned_contingency_kg,planned_holding_reserve_kg,minimum_planned_onboard_kg,model_version,verified_game_hour_utc)
 VALUES(ph2,a.id,ac,de2,second_pf.origin_airport_key,second_pf.destination_airport_key,conf,'test-fuel-custody',1,6000,4000,400,600,5000,'rollback-fixture',revised_dep);
 receipt:=crew_external_downstream_fixture_14r.section9_bind_approved_delayed_crew_v1(a.id,second_pf.occurrence_id,de2);
 IF receipt->>'status'<>'approved_delayed_crew_bound' OR receipt->>'externalPilotCount'<>'1' THEN RAISE EXCEPTION 'handover binding %',receipt;END IF;
 INSERT INTO crew_external_downstream_fixture_14r.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc,source_kind)
 VALUES(1,ae2,repeat('b',64),a.id,ac,sc,1,1,second_pf.departure_utc::date,ph2,'arrived',second_pf.origin_airport_key,second_pf.destination_airport_key,second_pf.departure_utc,second_pf.arrival_utc,revised_arr,'signed_operated_game_flight_v1');
 receipt:=crew_external_downstream_fixture_14r.section9_complete_bound_crew_arrival_v1(a.id,ph2,ae2);
 IF receipt->>'pilotsCredited'<>'1' OR receipt->>'flightMinutes'<>'180' THEN RAISE EXCEPTION 'second sector credit %',receipt;END IF;
 IF (SELECT total_flight_minutes FROM crew_external_downstream_fixture_14r.section9_pilot_profiles_v1 WHERE crew_id=cp)<>195 OR (SELECT total_flight_minutes FROM crew_external_downstream_fixture_14r.section9_pilot_profiles_v1 WHERE crew_id=fo[1])<>375 THEN RAISE EXCEPTION 'pilot credits';END IF;
 history:=crew_external_downstream_fixture_14r.section9_crew_actual_history_v1(a.id,cp,revised_arr+interval '1 hour');
 IF history->>'lastAirport'<>second_pf.origin_airport_key OR (history->>'lastDutyEndUtc')::timestamptz<>release_at THEN RAISE EXCEPTION 'released crew teleported %',history;END IF;
 IF crew_external_downstream_fixture_14r.section9_completed_external_crew_cost_v1(a.id,ph2,ae2)<>1050 THEN RAISE EXCEPTION 'external cost';END IF;
 -- The later duty cannot depart while the old roster is still current.
 PERFORM set_config('airlinerra.requote_fixture_clock',(revised_arr+interval '1 hour')::text,true);
 receipt:=crew_external_downstream_fixture_14r.section9_downstream_crew_reconciliation_v1(a.id,third_pf.occurrence_id);
 IF receipt->>'status'<>'downstream_rolling_replan_required' THEN RAISE EXCEPTION 'hold after arrival %',receipt;END IF;
 roll_start:=revised_arr+interval '1 hour 1 minute';
 roll_snap:=crew_external_downstream_fixture_14r.section9_owned_rolling_crew_input_v1(a.owner_player_id,a.id,roll_start);
 SELECT value INTO item FROM jsonb_array_elements(assignments) WHERE value->>'flightId'=third_pf.occurrence_id::text;
 wrong_assign:=jsonb_build_array(item);
 receipt:=crew_external_downstream_fixture_14r.section9_save_owned_rolling_crew_plan_v1(a.owner_player_id,a.id,other_plan,roll_start,roll_snap,wrong_assign);
 IF receipt->>'status'<>'crew_plan_crew_wrong_airport' THEN RAISE EXCEPTION 'wrong airport replan %',receipt;END IF;
 -- Eligible internal reserve wins even when external fallback is enabled.
 UPDATE crew_external_downstream_fixture_14r.section9_delayed_crew_approval_release_v1 SET automatic_downstream_external_enabled=true;
 UPDATE crew_external_downstream_fixture_14r.section9_dated_flight_occurrences_v1 SET booking_status='open',source_kind='game_verified_saleable_schedule_v1' WHERE id=third_pf.occurrence_id;
 BEGIN
  receipt:=crew_external_downstream_fixture_14r.section9_auto_replan_downstream_crew_v1(a.owner_player_id,a.id);
  IF receipt->>'saved'<>'true' OR receipt->>'externalContractCount'<>'0' OR NOT EXISTS(SELECT 1 FROM crew_external_downstream_fixture_14r.section9_planned_crew_seats_v1 WHERE plan_id=(receipt->>'planId')::uuid AND occurrence_id=third_pf.occurrence_id AND employee_id=reserve_id AND seat_role='captain') THEN RAISE EXCEPTION 'internal preference %',receipt;END IF;
  RAISE EXCEPTION USING ERRCODE='ZX004',MESSAGE='restore original plan';
 EXCEPTION WHEN SQLSTATE 'ZX004' THEN NULL;END;
 INSERT INTO crew_external_downstream_fixture_14r.section9_crew_unavailability_v1(airline_id,pilot_id,reason,start_utc,end_utc) VALUES(a.id,reserve_id,'sickness',third_pf.departure_utc-interval '3 hours',third_pf.arrival_utc+interval '1 hour');
 BEGIN
  UPDATE crew_external_downstream_fixture_14r.section9_delayed_crew_approval_release_v1 SET automatic_downstream_external_enabled=false;
  receipt:=crew_external_downstream_fixture_14r.section9_auto_replan_downstream_crew_v1(a.owner_player_id,a.id);
  IF receipt->>'status'<>'automatic_downstream_internal_shortage' THEN RAISE EXCEPTION 'external gate %',receipt;END IF;
  RAISE EXCEPTION USING ERRCODE='ZX004',MESSAGE='restore gate';
 EXCEPTION WHEN SQLSTATE 'ZX004' THEN NULL;END;
 BEGIN
  UPDATE crew_external_downstream_fixture_14r.airlines SET cash_usd=1050 WHERE id=a.id;
  receipt:=crew_external_downstream_fixture_14r.section9_auto_replan_downstream_crew_v1(a.owner_player_id,a.id);
  IF receipt->>'status'<>'automatic_downstream_combined_budget_exceeded' OR EXISTS(SELECT 1 FROM crew_external_downstream_fixture_14r.section9_external_crew_contracts_v1 WHERE occurrence_id=third_pf.occurrence_id) THEN RAISE EXCEPTION 'combined budget %',receipt;END IF;
  RAISE EXCEPTION USING ERRCODE='ZX004',MESSAGE='restore cash';
 EXCEPTION WHEN SQLSTATE 'ZX004' THEN NULL;END;
 -- Force the independently validated saver to reject after reservation;
 -- both new contract and plan must disappear in its subtransaction.
 BEGIN
  EXECUTE 'CREATE OR REPLACE FUNCTION crew_external_downstream_fixture_14r.section9_save_owned_rolling_crew_plan_v1(p_player uuid,p_airline uuid,p_plan uuid,p_start timestamptz,p_snapshot jsonb,p_assignments jsonb) RETURNS jsonb LANGUAGE sql AS $stub$SELECT jsonb_build_object(''status'',''forced_validation_rejection'',''saved'',false)$stub$';
  receipt:=crew_external_downstream_fixture_14r.section9_auto_replan_downstream_crew_v1(a.owner_player_id,a.id);
  IF receipt->>'status'<>'forced_validation_rejection' OR receipt->>'atomicRollback'<>'true' OR EXISTS(SELECT 1 FROM crew_external_downstream_fixture_14r.section9_external_crew_contracts_v1 WHERE occurrence_id=third_pf.occurrence_id) OR NOT EXISTS(SELECT 1 FROM crew_external_downstream_fixture_14r.section9_crew_plan_batches_v1 WHERE plan_id=plan AND status='validated_preview') THEN RAISE EXCEPTION 'atomic rollback %',receipt;END IF;
  RAISE EXCEPTION USING ERRCODE='ZX004',MESSAGE='restore original saver';
 EXCEPTION WHEN SQLSTATE 'ZX004' THEN NULL;END;
 receipt:=crew_external_downstream_fixture_14r.section9_auto_replan_downstream_cycle_v1(5);
 IF receipt->>'status'<>'automatic_downstream_replan_cycle_completed' OR receipt->>'checked'<>'1' OR receipt->>'plansSaved'<>'1' THEN RAISE EXCEPTION 'automatic fallback %',receipt;END IF;
 SELECT plan_id INTO STRICT other_plan FROM crew_external_downstream_fixture_14r.section9_crew_plan_batches_v1 WHERE airline_id=a.id AND status='validated_preview';
 IF other_plan=plan OR NOT EXISTS(SELECT 1 FROM crew_external_downstream_fixture_14r.section9_external_crew_contracts_v1 WHERE occurrence_id=third_pf.occurrence_id AND captains=1 AND first_officers=0 AND cabin_crew=0 AND quoted_cost_usd=1050) OR NOT EXISTS(SELECT 1 FROM crew_external_downstream_fixture_14r.section9_planned_flight_crews_v1 WHERE plan_id=other_plan AND occurrence_id=third_pf.occurrence_id AND external_captain_count=1 AND captain_count=0) THEN RAISE EXCEPTION 'fallback composition';END IF;
 receipt:=crew_external_downstream_fixture_14r.section9_auto_replan_downstream_cycle_v1(5);
 IF receipt->>'checked'<>'0' OR receipt->>'plansSaved'<>'0' OR (SELECT count(*) FROM crew_external_downstream_fixture_14r.section9_external_crew_contracts_v1 WHERE occurrence_id=third_pf.occurrence_id)<>1 THEN RAISE EXCEPTION 'duplicate fallback %',receipt;END IF;
 receipt:=crew_external_downstream_fixture_14r.section9_downstream_crew_reconciliation_v1(a.id,third_pf.occurrence_id);
 IF receipt->>'status'<>'downstream_crew_reconciled' THEN RAISE EXCEPTION 'hold not cleared %',receipt;END IF;
 SELECT schedule_id INTO sc FROM crew_external_downstream_fixture_14r.section9_dated_flight_occurrences_v1 WHERE id=third_pf.occurrence_id;
 third_de:='test-downstream-depart-'||sc;
 INSERT INTO crew_external_downstream_fixture_14r.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc,source_kind)
 VALUES(1,third_de,repeat('c',64),a.id,ac,sc,1,1,third_pf.departure_utc::date,third_pf.physical_flight_id,'departed',third_pf.origin_airport_key,third_pf.destination_airport_key,third_pf.departure_utc,third_pf.arrival_utc,third_pf.departure_utc,'signed_operated_game_flight_v1');
 INSERT INTO crew_external_downstream_fixture_14r.section9_game_flight_fuel_departure_receipts_v1(physical_flight_id,airline_id,aircraft_inventory_id,departure_engine_event_id,departure_airport_key,destination_airport_key,configuration_id,fuel_custody_source_event_id,fuel_custody_revision,onboard_at_departure_kg,planned_trip_burn_kg,planned_contingency_kg,planned_holding_reserve_kg,minimum_planned_onboard_kg,model_version,verified_game_hour_utc)
 VALUES(third_pf.physical_flight_id,a.id,ac,third_de,third_pf.origin_airport_key,third_pf.destination_airport_key,conf,'test-fuel-custody',1,6000,4000,400,600,5000,'rollback-fixture',third_pf.departure_utc);
 receipt:=crew_external_downstream_fixture_14r.section9_capture_dispatched_crew_v1(a.id,third_pf.physical_flight_id,third_de);
 IF receipt->>'status'<>'crew_departure_bound' OR NOT EXISTS(SELECT 1 FROM crew_external_downstream_fixture_14r.section9_pilot_departure_manifests_v1 WHERE physical_flight_id=third_pf.physical_flight_id AND cardinality(captain_ids)=0) THEN RAISE EXCEPTION 'downstream capture %',receipt;END IF;
 third_ae:='test-downstream-arrive-'||sc;
 INSERT INTO crew_external_downstream_fixture_14r.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc,source_kind)
 VALUES(1,third_ae,repeat('d',64),a.id,ac,sc,1,1,third_pf.departure_utc::date,third_pf.physical_flight_id,'arrived',third_pf.origin_airport_key,third_pf.destination_airport_key,third_pf.departure_utc,third_pf.arrival_utc,third_pf.arrival_utc+interval '15 minutes','signed_operated_game_flight_v1');
 receipt:=crew_external_downstream_fixture_14r.section9_complete_bound_crew_arrival_v1(a.id,third_pf.physical_flight_id,third_ae);
 IF receipt->>'pilotsCredited'<>'1' OR crew_external_downstream_fixture_14r.section9_completed_external_crew_cost_v1(a.id,third_pf.physical_flight_id,third_ae)<>1137.50 THEN RAISE EXCEPTION 'fallback arrival cost %',receipt;END IF;
 result:=jsonb_build_object('status','passed','externalDownstreamFallback',true,'internalPriorityWithFallbackEnabled',true,'combinedCommitmentsProtected',true,'contractRollbackOnRosterFailure',true,'externalFallbackGate',true,'exactlyOneContract',true,'downstreamActualCostUsd',1137.50,'downstreamHoldBeforeArrival',true,'automaticDownstreamCycleExecuted',true,'automaticDownstreamGate',true,'automaticDuplicateReplanPrevented',true,'internalShortagePreservesOldPlan',true,'downstreamHoldUntilValidatedRollingPlan',true,'wrongAirportReplanRejected',true,'pendingApprovalProtected',true,'sameDutyOnwardGuard',true,'newCrewBoundOnLaterFlight',true,'changedCaptainNotTeleported',true,'activeHandoverBound',true,'automaticApprovalGate',true,'automaticCycleGate',true,'automaticCycleInternalPriority',true,'automaticCycleDuplicateProtected',true,'nonSaleablePreviewExcluded',true,'internalPriority',true,'externalFallback',true,'automaticDuplicateProtected',true,'wrongAirportReserveRejected',true,'stationedInternalReserveValidated',true,'eligibleCrewNotUnnecessarilyReleased',true,'unverifiedArrivalRejected',true,'budgetFailureRolledBack',true,'releasedCaptainFlightMinutes',195,'retainedFirstOfficerFlightMinutes',375,'releasedAirport',history->>'lastAirport','releasedAtUtc',release_at,'nextRestEndsUtc',release_at+interval '12 hours','externalCrewCostUsd',1050,'originalPlanPreserved',true,'ledgerPosted',false);
 RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE=result::text;
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN PERFORM set_config('airlinerra.crew_handover_fixture_result',SQLERRM,true);END;
END $test$;
SELECT current_setting('airlinerra.crew_handover_fixture_result',true)::jsonb AS handover_test,to_regnamespace('crew_external_downstream_fixture_14r') IS NULL AS isolated_schema_removed,(SELECT count(*) FROM airlinerra_game.section9_delayed_crew_approvals_v1) AS live_approvals;
