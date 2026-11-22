-- Isolated schema acceptance, rolled back in full. Production tables/triggers are
-- never modified. Copies of production functions execute against fixture relations.
DO $test$
DECLARE tbl text; fn record; a record; ac uuid; conf bigint; grp text; hire jsonb; sc uuid; oid uuid; snap jsonb; assignments jsonb:='[]'; duties jsonb; start_at timestamptz:='2026-11-24T00:00:00Z'; dep timestamptz; arr timestamptz; orig text; dest text; plan uuid:=gen_random_uuid(); other_plan uuid:=gen_random_uuid(); r jsonb; i int; bad jsonb; result jsonb;
BEGIN
 BEGIN
 CREATE SCHEMA crew_plan_fixture_14e;
 FOREACH tbl IN ARRAY ARRAY['airlines','airline_aircraft_inventory','airport_reference_profiles','section9_crew_bases_v1','section9_flight_crew_model_policy_v1','section9_pilot_qualification_groups_v1','section9_airline_crew_roster_v1','section9_pilot_profiles_v1','section9_pilot_family_permissions_v1','section9_pilot_base_assignments_v1','section9_cabin_crew_pools_v1','section9_cabin_crew_members_v1','section9_crew_unavailability_v1','section9_shared_crew_employment_release_v1','section9_shared_crew_salary_policy_v1','section9_shared_crew_hire_batches_v1','section9_crew_scheduler_policy_v2','airline_flight_schedule_drafts_v1','section9_dated_flight_occurrences_v1','section9_pilot_departure_manifests_v1','section9_crew_plan_batches_v1','section9_planned_flight_crews_v1','section9_planned_crew_duties_v1','section9_planned_crew_seats_v1','section9_external_crew_contracts_v1','section9_external_crew_release_v1','section9_delayed_crew_approvals_v1'] LOOP
 EXECUTE format('CREATE TABLE crew_plan_fixture_14e.%I (LIKE airlinerra_game.%I INCLUDING ALL)',tbl,tbl);
 END LOOP;
 FOR fn IN SELECT c.conrelid::regclass::text rel,c.conname,pg_get_constraintdef(c.oid) def FROM pg_constraint c WHERE c.contype='f' AND c.conrelid IN('airlinerra_game.section9_crew_plan_batches_v1'::regclass,'airlinerra_game.section9_planned_flight_crews_v1'::regclass,'airlinerra_game.section9_planned_crew_duties_v1'::regclass,'airlinerra_game.section9_planned_crew_seats_v1'::regclass) LOOP
 EXECUTE 'ALTER TABLE '||replace(fn.rel,'airlinerra_game','crew_plan_fixture_14e')||' ADD CONSTRAINT '||quote_ident(fn.conname)||' '||replace(fn.def,'airlinerra_game','crew_plan_fixture_14e');
 END LOOP;
 FOR fn IN SELECT pg_get_functiondef(p.oid) def FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace WHERE n.nspname='airlinerra_game' AND p.proname IN('section9_owned_shared_crew_payroll_forecast_v1','section9_owned_shared_crew_hire_quote_v1','section9_confirm_owned_shared_crew_hire_v1','section9_pilot_can_fill_rank_v1','section9_crew_unavailability_windows_v1','section9_owned_weekly_crew_input_v1','section9_crew_rotation_window_v2','section9_crew_duty_fit_v2','section9_save_owned_crew_plan_preview_v1','section9_flight_crew_requirements_v1','section9_cabin_composition_valid_v1','section9_verified_external_cabin_input_v1','section9_pilot_counts_valid_v1') ORDER BY CASE p.proname WHEN 'section9_owned_shared_crew_payroll_forecast_v1' THEN 0 WHEN 'section9_owned_shared_crew_hire_quote_v1' THEN 1 ELSE 2 END LOOP
 EXECUTE replace(fn.def,'airlinerra_game','crew_plan_fixture_14e');
 END LOOP;
 CREATE FUNCTION crew_plan_fixture_14e.section9_verified_world_instant_v1() RETURNS timestamptz LANGUAGE sql STABLE AS 'SELECT ''2026-11-22T11:24:00Z''::timestamptz';
 SELECT id,owner_player_id,home_airport_key,iata_code INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 SELECT f.id,f.configuration_id,p.qualification_group INTO STRICT ac,conf,grp FROM airlinerra_game.airline_aircraft_inventory f JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=f.configuration_id WHERE f.airline_id=a.id AND p.seat_basis<>'cargo_zero' LIMIT 1;
 INSERT INTO crew_plan_fixture_14e.airlines SELECT * FROM airlinerra_game.airlines WHERE id=a.id;
 INSERT INTO crew_plan_fixture_14e.airline_aircraft_inventory SELECT * FROM airlinerra_game.airline_aircraft_inventory WHERE id=ac;
 SELECT string_agg(quote_ident(column_name),',' ORDER BY ordinal_position) INTO tbl FROM information_schema.columns WHERE table_schema='airlinerra_game' AND table_name='airport_reference_profiles' AND is_generated='NEVER';
 EXECUTE format('INSERT INTO crew_plan_fixture_14e.airport_reference_profiles(%s) SELECT %s FROM airlinerra_game.airport_reference_profiles WHERE world_id=1 AND airport_key=ANY($1)',tbl,tbl) USING ARRAY[a.home_airport_key,'OURAIRPORTS:2212'];
 INSERT INTO crew_plan_fixture_14e.section9_crew_bases_v1 SELECT * FROM airlinerra_game.section9_crew_bases_v1 WHERE airline_id=a.id AND airport_key=a.home_airport_key;
 INSERT INTO crew_plan_fixture_14e.section9_flight_crew_model_policy_v1 SELECT * FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=conf;
 INSERT INTO crew_plan_fixture_14e.section9_pilot_qualification_groups_v1 SELECT * FROM airlinerra_game.section9_pilot_qualification_groups_v1 WHERE qualification_group=grp;
 INSERT INTO crew_plan_fixture_14e.section9_shared_crew_employment_release_v1(world_id,manual_hiring_enabled,automatic_hiring_enabled,payroll_enabled) VALUES(1,true,false,false);
 INSERT INTO crew_plan_fixture_14e.section9_shared_crew_salary_policy_v1 SELECT * FROM airlinerra_game.section9_shared_crew_salary_policy_v1;
 INSERT INTO crew_plan_fixture_14e.section9_crew_scheduler_policy_v2 SELECT * FROM airlinerra_game.section9_crew_scheduler_policy_v2;
 hire:=crew_plan_fixture_14e.section9_confirm_owned_shared_crew_hire_v1(a.owner_player_id,a.id,gen_random_uuid(),a.home_airport_key,grp,1,1,4,22800);
 IF hire->>'status'<>'shared_crew_hired' THEN RAISE EXCEPTION 'hire %',hire;END IF;
 FOR i IN 1..2 LOOP
 dep:=start_at+make_interval(hours=>CASE WHEN i=1 THEN 6 ELSE 12 END);arr:=dep+interval '3 hours';
 orig:=CASE WHEN i=1 THEN a.home_airport_key ELSE 'OURAIRPORTS:2212' END;dest:=CASE WHEN i=1 THEN 'OURAIRPORTS:2212' ELSE a.home_airport_key END;
 INSERT INTO crew_plan_fixture_14e.airline_flight_schedule_drafts_v1(airline_id,aircraft_inventory_id,configuration_id,flight_number,origin_airport_key,destination_airport_key,reference_departure_utc,reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id,status,operationally_verified)
 VALUES(a.id,ac,conf,a.iata_code|| (980+i),orig,dest,dep,arr,jsonb_build_array(jsonb_build_object('day',extract(isodow FROM dep)::int-1,'time',to_char(dep,'HH24:MI'))),'{}',a.owner_player_id,'active',true) RETURNING id INTO sc;
 INSERT INTO crew_plan_fixture_14e.section9_dated_flight_occurrences_v1(world_id,airline_id,schedule_id,aircraft_inventory_id,schedule_version,weekly_entry,flight_local_date,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,turnaround_minutes,verified_passenger_seats,booking_status,booked_seats,recognized_revenue_usd,source_kind)
 VALUES(1,a.id,sc,ac,1,1,dep::date,orig,dest,dep,arr,60,156,'not_open',0,0,'verified_schedule_preview_not_saleable') RETURNING id INTO oid;
 SELECT jsonb_agg(jsonb_build_object('employeeId',x.emp,'role',x.role,'dutyStartUtc',start_at+interval '4 hours','dutyEndUtc',arr+interval '30 minutes')) INTO duties FROM(
 SELECT hire->'pilotIds'->>0 emp,'captain' role UNION ALL SELECT hire->'pilotIds'->>1,'firstOfficer' UNION ALL SELECT value,'cabin' FROM jsonb_array_elements_text(hire->'cabinIds'))x;
 assignments:=assignments||jsonb_build_array(jsonb_build_object('flightId',oid,'aircraftId',ac,'departureUtc',dep,'arrivalUtc',arr,'captains',jsonb_build_array(hire->'pilotIds'->0),'firstOfficers',jsonb_build_array(hire->'pilotIds'->1),'cabinCrew',hire->'cabinIds','duties',duties));
 END LOOP;
 snap:=crew_plan_fixture_14e.section9_owned_weekly_crew_input_v1(a.owner_player_id,a.id,start_at);
 r:=crew_plan_fixture_14e.section9_save_owned_crew_plan_preview_v1(a.owner_player_id,a.id,plan,start_at,snap,assignments);
 IF r->>'status'<>'validated_preview' OR r->>'dutyCount'<>'6' OR r->>'flightCount'<>'2' THEN RAISE EXCEPTION 'plan %',r;END IF;
 IF (SELECT count(*) FROM crew_plan_fixture_14e.section9_planned_crew_seats_v1 WHERE plan_id=plan)<>12 OR EXISTS(SELECT 1 FROM crew_plan_fixture_14e.section9_planned_crew_duties_v1 WHERE plan_id=plan AND duty_end_utc-duty_start_utc<>interval '11 hours 30 minutes') THEN RAISE EXCEPTION 'duty manifest';END IF;
 result:=r;
 r:=crew_plan_fixture_14e.section9_save_owned_crew_plan_preview_v1(a.owner_player_id,a.id,plan,start_at,snap,assignments);
 IF r->>'replayed'<>'true' THEN RAISE EXCEPTION 'replay';END IF;
 bad:=jsonb_set(assignments,'{0,captains}',jsonb_build_array(hire->'pilotIds'->1));
 r:=crew_plan_fixture_14e.section9_save_owned_crew_plan_preview_v1(a.owner_player_id,a.id,other_plan,start_at,snap,bad);
 IF r->>'status'<>'crew_plan_duplicate_employee' THEN RAISE EXCEPTION 'duplicate seat %',r;END IF;
 SELECT jsonb_agg(jsonb_set(value,'{dutyStartUtc}',to_jsonb(start_at+interval '10 hours'))) INTO duties FROM jsonb_array_elements(assignments->1->'duties');
 bad:=jsonb_set(assignments,'{1,duties}',duties);
 r:=crew_plan_fixture_14e.section9_save_owned_crew_plan_preview_v1(a.owner_player_id,a.id,other_plan,start_at,snap,bad);
 IF r->>'status'<>'crew_plan_insufficient_rest' THEN RAISE EXCEPTION 'rest %',r;END IF;
 IF (SELECT status FROM crew_plan_fixture_14e.section9_crew_plan_batches_v1 WHERE plan_id=plan)<>'validated_preview' THEN RAISE EXCEPTION 'invalid plan replaced valid one';END IF;
 UPDATE crew_plan_fixture_14e.section9_pilot_family_permissions_v1 SET qualification_status='expired' WHERE crew_id=(hire->'pilotIds'->>0)::uuid;
 snap:=crew_plan_fixture_14e.section9_owned_weekly_crew_input_v1(a.owner_player_id,a.id,start_at);
 r:=crew_plan_fixture_14e.section9_save_owned_crew_plan_preview_v1(a.owner_player_id,a.id,other_plan,start_at,snap,assignments);
 IF r->>'status'<>'crew_plan_qualification_failed' THEN RAISE EXCEPTION 'qualification %',r;END IF;
 UPDATE crew_plan_fixture_14e.section9_pilot_family_permissions_v1 SET qualification_status='active' WHERE crew_id=(hire->'pilotIds'->>0)::uuid;
 INSERT INTO crew_plan_fixture_14e.section9_crew_unavailability_v1(airline_id,pilot_id,reason,start_utc,end_utc) VALUES(a.id,(hire->'pilotIds'->>0)::uuid,'sickness',start_at+interval '5 hours',start_at+interval '7 hours');
 snap:=crew_plan_fixture_14e.section9_owned_weekly_crew_input_v1(a.owner_player_id,a.id,start_at);
 r:=crew_plan_fixture_14e.section9_save_owned_crew_plan_preview_v1(a.owner_player_id,a.id,other_plan,start_at,snap,assignments);
 IF r->>'status'<>'crew_plan_employee_absent' THEN RAISE EXCEPTION 'absence %',r;END IF;
 RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE=result::text;
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN PERFORM set_config('airlinerra.crew_plan_fixture_result',SQLERRM,true);END;
END $test$;
SELECT current_setting('airlinerra.crew_plan_fixture_result',true)::jsonb AS accepted_plan, to_regnamespace('crew_plan_fixture_14e') IS NULL AS isolated_schema_removed,(SELECT count(*) FROM airlinerra_game.section9_crew_plan_batches_v1) AS live_plans;