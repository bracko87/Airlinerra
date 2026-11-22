-- Isolated schema acceptance, rolled back in full. Production tables/triggers are
-- never modified. Copies of production functions execute against fixture relations.
DO $test$
DECLARE tbl text; fn record; a record; ac uuid; conf bigint; grp text; hire jsonb; sc uuid; oid uuid; snap jsonb; assignments jsonb:='[]'; duties jsonb; start_at timestamptz:='2026-11-24T00:00:00Z'; dep timestamptz; arr timestamptz; orig text; dest text; plan uuid:=gen_random_uuid(); other_plan uuid:=gen_random_uuid(); r jsonb; i int; bad jsonb; result jsonb; ph text; de text; ae text; pf record; cp uuid; second_pf record; contract jsonb; paid numeric;
BEGIN
 BEGIN
 CREATE SCHEMA crew_turn_fixture_14h;
 FOREACH tbl IN ARRAY ARRAY['airlines','airline_aircraft_inventory','airport_reference_profiles','section9_crew_bases_v1','section9_flight_crew_model_policy_v1','section9_pilot_qualification_groups_v1','section9_airline_crew_roster_v1','section9_pilot_profiles_v1','section9_pilot_family_permissions_v1','section9_pilot_base_assignments_v1','section9_cabin_crew_pools_v1','section9_cabin_crew_members_v1','section9_crew_unavailability_v1','section9_shared_crew_employment_release_v1','section9_shared_crew_salary_policy_v1','section9_shared_crew_hire_batches_v1','section9_crew_scheduler_policy_v2','airline_flight_schedule_drafts_v1','section9_dated_flight_occurrences_v1','section9_pilot_departure_manifests_v1','section9_crew_plan_batches_v1','section9_planned_flight_crews_v1','section9_planned_crew_duties_v1','section9_planned_crew_seats_v1','section9_operated_flight_movements_v1','section9_game_flight_fuel_departure_receipts_v1','section9_pilot_flight_experience_v1','section9_crew_movement_capture_release_v1','section9_operated_crew_bindings_v1','section9_operated_crew_capture_issues_v1','section9_game_flight_fuel_arrival_receipts_v1','section9_external_crew_contracts_v1','section9_external_crew_release_v1','section9_external_crew_rate_v1','section9_route_posted_flight_financials_v1','section9_delayed_crew_approvals_v1','section9_replacement_slot_pairs_v1','section9_dynamic_turnaround_release_v1','section9_actual_turnaround_receipts_v1'] LOOP
 EXECUTE format('CREATE TABLE crew_turn_fixture_14h.%I (LIKE airlinerra_game.%I INCLUDING ALL)',tbl,tbl);
 END LOOP;
 FOR fn IN SELECT c.conrelid::regclass::text rel,c.conname,pg_get_constraintdef(c.oid) def FROM pg_constraint c WHERE c.contype='f' AND c.conrelid IN('airlinerra_game.section9_crew_plan_batches_v1'::regclass,'airlinerra_game.section9_planned_flight_crews_v1'::regclass,'airlinerra_game.section9_planned_crew_duties_v1'::regclass,'airlinerra_game.section9_planned_crew_seats_v1'::regclass,'airlinerra_game.section9_operated_crew_bindings_v1'::regclass,'airlinerra_game.section9_operated_crew_capture_issues_v1'::regclass) LOOP
 EXECUTE 'ALTER TABLE '||replace(fn.rel,'airlinerra_game','crew_turn_fixture_14h')||' ADD CONSTRAINT '||quote_ident(fn.conname)||' '||replace(fn.def,'airlinerra_game','crew_turn_fixture_14h');
 END LOOP;
 FOR fn IN SELECT pg_get_functiondef(p.oid) def FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='airlinerra_game' AND p.proname IN('section9_owned_shared_crew_payroll_forecast_v1','section9_owned_shared_crew_hire_quote_v1','section9_confirm_owned_shared_crew_hire_v1','section9_pilot_can_fill_rank_v1','section9_crew_unavailability_windows_v1','section9_owned_weekly_crew_input_v1','section9_crew_rotation_window_v2','section9_crew_duty_fit_v2','section9_save_owned_crew_plan_preview_v1','section9_record_pilot_departure_manifest_v1','section9_credit_completed_pilot_flight_v1','section9_capture_dispatched_crew_v1','section9_complete_bound_crew_arrival_v1','section9_flight_crew_requirements_v1','section9_cabin_composition_valid_v1','section9_verified_external_cabin_input_v1','section9_pilot_counts_valid_v1','section9_external_crew_cost_v1','section9_external_crew_quote_v1','section9_authorize_external_crew_v1','section9_completed_external_crew_cost_v1','section9_bound_delayed_external_cost_v1','section9_delayed_turnaround_clear_v1','section9_dynamic_turnaround_preview_v1','section9_sample_turnaround_minutes_v1','section9_capture_actual_turnaround_v1') ORDER BY CASE p.proname WHEN 'section9_owned_shared_crew_payroll_forecast_v1' THEN 0 WHEN 'section9_owned_shared_crew_hire_quote_v1' THEN 1 ELSE 2 END LOOP
 EXECUTE replace(replace(fn.def,'airlinerra_game','crew_turn_fixture_14h'), E'SELECT decrypted_secret INTO key FROM vault.decrypted_secrets WHERE name=\'airlinerra_operated_flight_auto_signing_v1\';', 'key:=repeat(''fixture-key'',8);');
 END LOOP;
 CREATE FUNCTION crew_turn_fixture_14h.section9_verified_world_instant_v1() RETURNS timestamptz LANGUAGE sql STABLE AS 'SELECT ''2026-11-22T11:24:00Z''::timestamptz';
 SELECT id,owner_player_id,home_airport_key,iata_code INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 SELECT f.id,f.configuration_id,p.qualification_group INTO STRICT ac,conf,grp FROM airlinerra_game.airline_aircraft_inventory f JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=f.configuration_id WHERE f.airline_id=a.id AND p.seat_basis<>'cargo_zero' LIMIT 1;
 INSERT INTO crew_turn_fixture_14h.airlines SELECT * FROM airlinerra_game.airlines WHERE id=a.id;
 INSERT INTO crew_turn_fixture_14h.airline_aircraft_inventory SELECT * FROM airlinerra_game.airline_aircraft_inventory WHERE id=ac;
 SELECT string_agg(quote_ident(column_name),',' ORDER BY ordinal_position) INTO tbl FROM information_schema.columns WHERE table_schema='airlinerra_game' AND table_name='airport_reference_profiles' AND is_generated='NEVER';
 EXECUTE format('INSERT INTO crew_turn_fixture_14h.airport_reference_profiles(%s) SELECT %s FROM airlinerra_game.airport_reference_profiles WHERE world_id=1 AND airport_key=ANY($1)',tbl,tbl) USING ARRAY[a.home_airport_key,'OURAIRPORTS:2212'];
 INSERT INTO crew_turn_fixture_14h.section9_crew_bases_v1 SELECT * FROM airlinerra_game.section9_crew_bases_v1 WHERE airline_id=a.id AND airport_key=a.home_airport_key;
 INSERT INTO crew_turn_fixture_14h.section9_flight_crew_model_policy_v1 SELECT * FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=conf;
 INSERT INTO crew_turn_fixture_14h.section9_pilot_qualification_groups_v1 SELECT * FROM airlinerra_game.section9_pilot_qualification_groups_v1 WHERE qualification_group=grp;
 INSERT INTO crew_turn_fixture_14h.section9_shared_crew_employment_release_v1(world_id,manual_hiring_enabled,automatic_hiring_enabled,payroll_enabled) VALUES(1,true,false,false);
 INSERT INTO crew_turn_fixture_14h.section9_shared_crew_salary_policy_v1 SELECT * FROM airlinerra_game.section9_shared_crew_salary_policy_v1;
 INSERT INTO crew_turn_fixture_14h.section9_crew_scheduler_policy_v2 SELECT * FROM airlinerra_game.section9_crew_scheduler_policy_v2;
 INSERT INTO crew_turn_fixture_14h.section9_external_crew_release_v1 VALUES(1,true);
 INSERT INTO crew_turn_fixture_14h.section9_external_crew_rate_v1 SELECT * FROM airlinerra_game.section9_external_crew_rate_v1;
 hire:=crew_turn_fixture_14h.section9_confirm_owned_shared_crew_hire_v1(a.owner_player_id,a.id,gen_random_uuid(),a.home_airport_key,grp,1,1,4,22800);
 IF hire->>'status'<>'shared_crew_hired' THEN RAISE EXCEPTION 'hire %',hire;END IF;
 FOR i IN 1..2 LOOP
 dep:=start_at+make_interval(hours=>CASE WHEN i=1 THEN 6 ELSE 12 END);arr:=dep+interval '3 hours';
 orig:=CASE WHEN i=1 THEN a.home_airport_key ELSE 'OURAIRPORTS:2212' END;dest:=CASE WHEN i=1 THEN 'OURAIRPORTS:2212' ELSE a.home_airport_key END;
 INSERT INTO crew_turn_fixture_14h.airline_flight_schedule_drafts_v1(airline_id,aircraft_inventory_id,configuration_id,flight_number,origin_airport_key,destination_airport_key,reference_departure_utc,reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id,status,operationally_verified)
 VALUES(a.id,ac,conf,a.iata_code|| (980+i),orig,dest,dep,arr,jsonb_build_array(jsonb_build_object('day',extract(isodow FROM dep)::int-1,'time',to_char(dep,'HH24:MI'))),'{}',a.owner_player_id,'active',true) RETURNING id INTO sc;
 INSERT INTO crew_turn_fixture_14h.section9_dated_flight_occurrences_v1(world_id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,weekly_entry,flight_local_date,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,turnaround_minutes,verified_passenger_seats,booking_status,booked_seats,recognized_revenue_usd,source_kind)
 VALUES(1,a.id,sc,ac,1,1,dep::date,orig,dest,dep,arr,60,156,'not_open',0,0,'verified_schedule_preview_not_saleable') RETURNING id INTO oid;
 contract:=crew_turn_fixture_14h.section9_authorize_external_crew_v1(a.id,oid,1,0,1,'isolated-test-contract-'||oid);
 IF contract->>'status'<>'external_crew_contract_authorized' THEN RAISE EXCEPTION 'contract %',contract;END IF;
 SELECT jsonb_agg(jsonb_build_object('employeeId',x.emp,'role',x.role,'dutyStartUtc',start_at+interval '4 hours','dutyEndUtc',arr+interval '30 minutes')) INTO duties FROM(
 SELECT hire->'pilotIds'->>1 emp,'firstOfficer' role UNION ALL SELECT value,'cabin' FROM jsonb_array_elements_text(hire->'cabinIds') WITH ORDINALITY as c(value,ord) WHERE ord<=3)x;
 assignments:=assignments||jsonb_build_array(jsonb_build_object('flightId',oid,'aircraftId',ac,'departureUtc',dep,'arrivalUtc',arr,'captains','[]'::jsonb,'firstOfficers',jsonb_build_array(hire->'pilotIds'->1),'cabinCrew',jsonb_build_array(hire->'cabinIds'->0,hire->'cabinIds'->1,hire->'cabinIds'->2),'duties',duties));
 END LOOP;
 snap:=crew_turn_fixture_14h.section9_owned_weekly_crew_input_v1(a.owner_player_id,a.id,start_at);
 r:=crew_turn_fixture_14h.section9_save_owned_crew_plan_preview_v1(a.owner_player_id,a.id,plan,start_at,snap,assignments);
 IF r->>'status'<>'validated_preview' OR r->>'dutyCount'<>'4' OR r->>'flightCount'<>'2' THEN RAISE EXCEPTION 'plan %',r;END IF;
 IF (SELECT count(*) FROM crew_turn_fixture_14h.section9_planned_crew_seats_v1 WHERE plan_id=plan)<>8 OR EXISTS(SELECT 1 FROM crew_turn_fixture_14h.section9_planned_crew_duties_v1 WHERE plan_id=plan AND duty_end_utc-duty_start_utc<>interval '11 hours 30 minutes') THEN RAISE EXCEPTION 'duty manifest';END IF;

 SELECT * INTO STRICT pf FROM crew_turn_fixture_14h.section9_planned_flight_crews_v1 WHERE plan_id=plan AND departure_utc=start_at+interval '6 hours';
 SELECT * INTO STRICT second_pf FROM crew_turn_fixture_14h.section9_planned_flight_crews_v1 WHERE plan_id=plan AND departure_utc=start_at+interval '12 hours';
 SELECT schedule_id INTO sc FROM crew_turn_fixture_14h.section9_dated_flight_occurrences_v1 WHERE id=pf.occurrence_id;
 ph:=pf.physical_flight_id;de:='test-crew-bound-depart-'||sc;ae:='test-crew-bound-arrive-'||sc;cp:=(hire->'pilotIds'->>1)::uuid;
 INSERT INTO crew_turn_fixture_14h.section9_crew_movement_capture_release_v1 VALUES(1,false);
 IF crew_turn_fixture_14h.section9_capture_dispatched_crew_v1(a.id,ph,de)->>'status'<>'crew_capture_disabled' THEN RAISE EXCEPTION 'gate';END IF;
 UPDATE crew_turn_fixture_14h.section9_crew_movement_capture_release_v1 SET capture_enabled=true;
 IF crew_turn_fixture_14h.section9_capture_dispatched_crew_v1(a.id,ph,de)->>'status'<>'crew_departure_evidence_missing' THEN RAISE EXCEPTION 'missing signed evidence';END IF;
 INSERT INTO crew_turn_fixture_14h.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc,source_kind)
 VALUES(1,de,repeat('a',64),a.id,ac,sc,1,1,pf.departure_utc::date,ph,'departed',pf.origin_airport_key,pf.destination_airport_key,pf.departure_utc,pf.arrival_utc,pf.departure_utc,'signed_operated_game_flight_v1');
 INSERT INTO crew_turn_fixture_14h.section9_game_flight_fuel_departure_receipts_v1(physical_flight_id,airline_id,aircraft_inventory_id,departure_engine_event_id,departure_airport_key,destination_airport_key,configuration_id,fuel_custody_source_event_id,fuel_custody_revision,onboard_at_departure_kg,planned_trip_burn_kg,planned_contingency_kg,planned_holding_reserve_kg,minimum_planned_onboard_kg,model_version,verified_game_hour_utc)
 VALUES(ph,a.id,ac,de,pf.origin_airport_key,pf.destination_airport_key,conf,'test-fuel-custody',1,6000,4000,400,600,5000,'rollback-fixture',pf.departure_utc);
 INSERT INTO crew_turn_fixture_14h.section9_crew_unavailability_v1(airline_id,pilot_id,reason,start_utc,end_utc) VALUES(a.id,cp,'sickness',start_at+interval '5 hours',start_at+interval '7 hours');
 r:=crew_turn_fixture_14h.section9_capture_dispatched_crew_v1(a.id,ph,de);
 IF r->>'status'<>'crew_employee_unavailable' OR r->>'crewCancellationTriggered'<>'false' THEN RAISE EXCEPTION 'absence %',r;END IF;
 DELETE FROM crew_turn_fixture_14h.section9_crew_unavailability_v1 WHERE pilot_id=cp;
 r:=crew_turn_fixture_14h.section9_capture_dispatched_crew_v1(a.id,ph,de);
 IF r->>'status'<>'crew_departure_bound' OR r->>'pilotCount'<>'2' OR r->>'cabinCount'<>'4' OR r->>'externalPilotCount'<>'1' OR r->>'externalCabinCount'<>'1' THEN RAISE EXCEPTION 'binding %',r;END IF;
 IF crew_turn_fixture_14h.section9_capture_dispatched_crew_v1(a.id,ph,de)->>'status'<>'crew_departure_already_bound' THEN RAISE EXCEPTION 'replay';END IF;
 IF crew_turn_fixture_14h.section9_complete_bound_crew_arrival_v1(a.id,ph,ae)->>'status'<>'crew_arrival_evidence_missing' THEN RAISE EXCEPTION 'premature arrival';END IF;
 INSERT INTO crew_turn_fixture_14h.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc,source_kind)
 VALUES(1,ae,repeat('b',64),a.id,ac,sc,1,1,pf.departure_utc::date,ph,'arrived',pf.origin_airport_key,pf.destination_airport_key,pf.departure_utc,pf.arrival_utc,pf.arrival_utc+interval '15 minutes','signed_operated_game_flight_v1');
 r:=crew_turn_fixture_14h.section9_complete_bound_crew_arrival_v1(a.id,ph,ae);
 IF r->>'status'<>'pilot_experience_credited' OR r->>'pilotsCredited'<>'1' OR r->>'flightMinutes'<>'195' THEN RAISE EXCEPTION 'credit %',r;END IF;
 IF crew_turn_fixture_14h.section9_complete_bound_crew_arrival_v1(a.id,ph,ae)->>'pilotsCredited'<>'0' THEN RAISE EXCEPTION 'duplicate hours';END IF;
 IF (SELECT total_flight_minutes FROM crew_turn_fixture_14h.section9_pilot_profiles_v1 WHERE crew_id=cp)<>195 THEN RAISE EXCEPTION 'total minutes';END IF;
 INSERT INTO crew_turn_fixture_14h.section9_dynamic_turnaround_release_v1 VALUES(1,false,false);
 IF crew_turn_fixture_14h.section9_capture_actual_turnaround_v1(a.id,ph,ae)->>'status'<>'dynamic_turnaround_disabled' THEN RAISE EXCEPTION 'gate';END IF;
 UPDATE crew_turn_fixture_14h.section9_dynamic_turnaround_release_v1 SET capture_enabled=true;
 IF crew_turn_fixture_14h.section9_capture_actual_turnaround_v1(a.id,ph,ae)->>'status'<>'turnaround_crew_or_arrival_evidence_missing' THEN RAISE EXCEPTION 'missing fuel evidence';END IF;
 INSERT INTO crew_turn_fixture_14h.section9_game_flight_fuel_arrival_receipts_v1(physical_flight_id,airline_id,aircraft_inventory_id,arrival_engine_event_id,trip_burn_kg,onboard_after_arrival_kg,location_airport_key,receipt_source)
 VALUES(ph,a.id,ac,ae,4000,2000,pf.destination_airport_key,'signed_game_arrival_estimated_burn_v1');
 r:=crew_turn_fixture_14h.section9_capture_actual_turnaround_v1(a.id,ph,ae);
 IF r->>'status'<>'turnaround_recorded' OR (r->>'availableUtc')::timestamptz<>pf.arrival_utc+interval '15 minutes'+make_interval(mins=>(r->>'actualMinutes')::int) THEN RAISE EXCEPTION 'turnaround %',r;END IF;
 paid:=crew_turn_fixture_14h.section9_completed_external_crew_cost_v1(a.id,ph,ae);
 IF paid<>1462.50 OR (SELECT count(*) FROM crew_turn_fixture_14h.section9_pilot_flight_experience_v1 WHERE physical_flight_id=ph)<>1 THEN RAISE EXCEPTION 'external cost or career count %',paid;END IF;
 UPDATE crew_turn_fixture_14h.section9_dynamic_turnaround_release_v1 SET dispatch_effects_enabled=true;
 IF crew_turn_fixture_14h.section9_delayed_turnaround_clear_v1(ac,second_pf.occurrence_id,pf.arrival_utc+interval '16 minutes') OR NOT crew_turn_fixture_14h.section9_delayed_turnaround_clear_v1(ac,second_pf.occurrence_id,second_pf.departure_utc) THEN RAISE EXCEPTION 'turnaround dispatch timing';END IF;
 result:=r||jsonb_build_object('externalCrewCostUsd',paid,'internalPilotsCredited',1,'externalPilots',1,'externalCabinCrew',1,'turnaroundDispatchGuardPassed',true);
 r:=crew_turn_fixture_14h.section9_capture_actual_turnaround_v1(a.id,ph,ae);
 IF r->>'status'<>'turnaround_already_recorded' OR r->>'actualMinutes'<>result->>'actualMinutes' OR (SELECT count(*) FROM crew_turn_fixture_14h.section9_actual_turnaround_receipts_v1)<>1 THEN RAISE EXCEPTION 'turnaround replay';END IF;
 RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE=result::text;
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN PERFORM set_config('airlinerra.crew_turn_fixture_result',SQLERRM,true);END;
END $test$;
SELECT current_setting('airlinerra.crew_turn_fixture_result',true)::jsonb AS movement_test, to_regnamespace('crew_turn_fixture_14h') IS NULL AS isolated_schema_removed,(SELECT count(*) FROM airlinerra_game.section9_crew_plan_batches_v1) AS live_plans;