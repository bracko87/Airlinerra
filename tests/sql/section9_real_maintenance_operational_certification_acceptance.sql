-- Phase 14Z maintenance source model. Transaction-only fixture schema, no live modifications.
DO $maintenance$
DECLARE t text; fn record; a record; aircraft uuid; game_day date; dep timestamptz; arr timestamptz; proof jsonb; verdict jsonb; result jsonb; overlap_job uuid;
BEGIN
 BEGIN
 CREATE SCHEMA cert_maintenance_fixture_14z;
 CREATE TABLE cert_maintenance_fixture_14z.fixture_worlds(id smallint primary key,state text,opens_at timestamptz);
 INSERT INTO cert_maintenance_fixture_14z.fixture_worlds VALUES(1,'active',now()-interval '30 days');
 FOREACH t IN ARRAY ARRAY[
 'airlines','airline_aircraft_inventory','world_memberships','holding_world_clock_v1',
 'section9_clock_producer_schedule_v1','section9_verified_game_tick_receipts_v1',
 'aircraft_maintenance_state_v1','section9_starter_game_airframe_baselines_v1','maintenance_check_policy_v1',
 'section9_game_maintenance_service_receipts_v1','section9_game_maintenance_jobs_v1',
 'airline_ledger','section9_arrived_aircraft_usage_receipts_v1','section9_operated_flight_movements_v1'
 ] LOOP EXECUTE format('CREATE TABLE cert_maintenance_fixture_14z.%I(LIKE airlinerra_game.%I INCLUDING ALL)',t,t);END LOOP;
 FOR fn IN SELECT pg_get_functiondef(oid) def FROM pg_proc WHERE pronamespace='airlinerra_game'::regnamespace AND proname IN(
 'section9_verified_world_instant_v1','section9_verified_berlin_game_hour_v1',
 'section9_game_airframe_condition_v1','section9_game_utilization_wear_multiplier_v1',
 'section9_owned_game_maintenance_due_v1','section9_verified_game_maintenance_dispatch_window_v1'
 ) LOOP
 EXECUTE replace(replace(replace(fn.def,'airlinerra_game','cert_maintenance_fixture_14z'),'public.cert_maintenance_fixture_14z_worlds','cert_maintenance_fixture_14z.fixture_worlds'),
 'time_now timestamptz:=clock_timestamp()','time_now timestamptz:=current_setting(''airlinerra.fixture_maintenance_now'',true)::timestamptz');
 END LOOP;
 SELECT * INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 SELECT id INTO STRICT aircraft FROM airlinerra_game.airline_aircraft_inventory WHERE airline_id=a.id LIMIT 1;
 game_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF game_day IS NULL THEN RAISE EXCEPTION 'verified maintenance game day unavailable';END IF;
 PERFORM set_config('airlinerra.fixture_maintenance_now',((game_day::timestamp+interval '8 hours') AT TIME ZONE 'Europe/Berlin')::text,true);
 dep:=(game_day::timestamp+interval '9 hours') AT TIME ZONE 'Europe/Berlin';
 arr:=dep+interval '3 hours';
 INSERT INTO cert_maintenance_fixture_14z.airlines SELECT * FROM airlinerra_game.airlines WHERE id=a.id;
 INSERT INTO cert_maintenance_fixture_14z.airline_aircraft_inventory SELECT * FROM airlinerra_game.airline_aircraft_inventory WHERE id=aircraft;
 INSERT INTO cert_maintenance_fixture_14z.world_memberships SELECT * FROM airlinerra_game.world_memberships WHERE world_id=1 AND player_id=a.owner_player_id;
 INSERT INTO cert_maintenance_fixture_14z.holding_world_clock_v1 SELECT * FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=1;
 INSERT INTO cert_maintenance_fixture_14z.section9_clock_producer_schedule_v1 SELECT * FROM airlinerra_game.section9_clock_producer_schedule_v1 WHERE world_id=1;
 INSERT INTO cert_maintenance_fixture_14z.section9_verified_game_tick_receipts_v1 SELECT * FROM airlinerra_game.section9_verified_game_tick_receipts_v1 WHERE world_id=1 AND game_date=game_day;
 INSERT INTO cert_maintenance_fixture_14z.aircraft_maintenance_state_v1 SELECT * FROM airlinerra_game.aircraft_maintenance_state_v1 WHERE aircraft_inventory_id=aircraft;
 INSERT INTO cert_maintenance_fixture_14z.section9_starter_game_airframe_baselines_v1 SELECT * FROM airlinerra_game.section9_starter_game_airframe_baselines_v1 WHERE aircraft_inventory_id=aircraft;
 INSERT INTO cert_maintenance_fixture_14z.maintenance_check_policy_v1 SELECT * FROM airlinerra_game.maintenance_check_policy_v1;
 proof:=cert_maintenance_fixture_14z.section9_verified_berlin_game_hour_v1();
 IF proof->>'authoritativeGameHourAvailable'<>'true' THEN RAISE EXCEPTION 'fixture time unverified %',proof;END IF;
 verdict:=cert_maintenance_fixture_14z.section9_verified_game_maintenance_dispatch_window_v1(a.owner_player_id,a.id,aircraft,dep,arr);
 IF verdict->>'gameMaintenanceClear'<>'false'
 OR NOT verdict->'blockers' ? 'MAINTENANCE_CHECK_DUE_DAILY'
 OR NOT verdict->'blockers' ? 'MAINTENANCE_CHECK_DUE_WEEKLY'
 THEN RAISE EXCEPTION 'overdue maintenance not grounded %',verdict;END IF;
 UPDATE cert_maintenance_fixture_14z.section9_starter_game_airframe_baselines_v1 SET game_baseline_date=game_day WHERE aircraft_inventory_id=aircraft;
 verdict:=cert_maintenance_fixture_14z.section9_verified_game_maintenance_dispatch_window_v1(a.owner_player_id,a.id,aircraft,dep,arr);
 IF verdict->>'gameMaintenanceClear'<>'true' THEN RAISE EXCEPTION 'fresh baseline rejected %',verdict;END IF;
 INSERT INTO cert_maintenance_fixture_14z.section9_game_maintenance_jobs_v1(world_id,owner_player_id,airline_id,aircraft_inventory_id,check_code,airport_key,game_start_utc,game_end_utc,duration_hours,flight_hours_at_book,status,source_kind,quoted_cost_usd)
 VALUES(1,a.owner_player_id,a.id,aircraft,'weekly',a.home_airport_key,dep+interval '30 minutes',dep+interval '3 hours 30 minutes',3,0,'scheduled','owner_booked_game_service_v1',500) RETURNING job_id INTO overlap_job;
 verdict:=cert_maintenance_fixture_14z.section9_verified_game_maintenance_dispatch_window_v1(a.owner_player_id,a.id,aircraft,dep,arr);
 IF verdict->>'gameMaintenanceClear'<>'false' OR NOT verdict->'blockers' ? 'MAINTENANCE_JOB_OVERLAP_OR_UNPAID'
 THEN RAISE EXCEPTION 'scheduled maintenance not grounding flight %',verdict;END IF;
 DELETE FROM cert_maintenance_fixture_14z.section9_game_maintenance_jobs_v1 WHERE job_id=overlap_job;
 UPDATE cert_maintenance_fixture_14z.aircraft_maintenance_state_v1 SET tracked_flight_hours=499 WHERE aircraft_inventory_id=aircraft;
 verdict:=cert_maintenance_fixture_14z.section9_verified_game_maintenance_dispatch_window_v1(a.owner_player_id,a.id,aircraft,dep,arr);
 IF verdict->>'gameMaintenanceClear'<>'false' OR NOT verdict->'blockers' ? 'MAINTENANCE_HOUR_LIMIT_BEFORE_ARRIVAL_A'
 THEN RAISE EXCEPTION 'A check threshold not enforced %',verdict;END IF;
 IF NOT EXISTS(SELECT 1 FROM cert_maintenance_fixture_14z.section9_starter_game_airframe_baselines_v1 WHERE aircraft_inventory_id=aircraft) THEN RAISE EXCEPTION 'baseline lost';END IF;
 result:=jsonb_build_object('status','passed','realHourlyMaintenanceVerification',true,'dailyWeeklyOverdueBlocks',true,'freshMaintenanceBaselineClears',true,'scheduledJobOverlapBlocks',true,'hourLimitBlocks',true,'noLiveDataChanges',true);
 RAISE EXCEPTION USING ERRCODE='ZX001',MESSAGE=result::text;
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN PERFORM set_config('airlinerra.cert_maintenance_fixture_14z',SQLERRM,true);END;
END $maintenance$;
SELECT current_setting('airlinerra.cert_maintenance_fixture_14z',true)::jsonb result,to_regnamespace('cert_maintenance_fixture_14z') IS NULL fixture_removed,
(SELECT count(*) FROM airlinerra_game.section9_game_maintenance_jobs_v1) live_maintenance_jobs;