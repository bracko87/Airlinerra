-- Live gates remain disabled. Rollback-only negative acceptance tests.
DO $test$
DECLARE a record; snap jsonb; changed jsonb; start_at timestamptz; run_id uuid:=gen_random_uuid(); groups jsonb; r jsonb;
BEGIN
 BEGIN
 SELECT id,owner_player_id,home_airport_key INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 start_at:=airlinerra_game.section9_verified_world_instant_v1()+interval '1 day';
 groups:=jsonb_build_array(jsonb_build_object('baseAirportKey',a.home_airport_key,'qualificationGroup','family:12','captains',1,'firstOfficers',1,'cabinCrew',0));
 snap:=airlinerra_game.section9_owned_automatic_recruitment_snapshot_v1(a.owner_player_id,a.id,start_at);
 IF snap->>'automaticHiringEnabled'<>'false' THEN RAISE EXCEPTION 'gate snapshot';END IF;
 r:=airlinerra_game.section9_execute_automatic_crew_hire_v1(a.owner_player_id,a.id,run_id,start_at,snap,groups);
 IF r->>'status'<>'automatic_hiring_disabled' THEN RAISE EXCEPTION 'release %',r;END IF;
 UPDATE airlinerra_game.section9_shared_crew_employment_release_v1 SET manual_hiring_enabled=true,automatic_hiring_enabled=true WHERE world_id=1;
 snap:=airlinerra_game.section9_owned_automatic_recruitment_snapshot_v1(a.owner_player_id,a.id,start_at);
 r:=airlinerra_game.section9_execute_automatic_crew_hire_v1(a.owner_player_id,a.id,run_id,start_at,snap,groups);
 IF r->>'status'<>'manual_recruitment_selected' THEN RAISE EXCEPTION 'manual %',r;END IF;
 PERFORM airlinerra_game.section9_save_owned_crew_recruitment_settings_v1(a.owner_player_id,a.id,'automatic_minimum',0,100000,(snap->'settings'->>'version')::int);
 r:=airlinerra_game.section9_execute_automatic_crew_hire_v1(a.owner_player_id,a.id,run_id,start_at,snap,groups);
 IF r->>'status'<>'recruitment_snapshot_changed' THEN RAISE EXCEPTION 'stale %',r;END IF;
 changed:=airlinerra_game.section9_owned_automatic_recruitment_snapshot_v1(a.owner_player_id,a.id,start_at);
 r:=airlinerra_game.section9_execute_automatic_crew_hire_v1(a.owner_player_id,a.id,run_id,start_at,changed,groups);
 IF r->>'status'<>'authoritative_schedule_or_duty_history_required' THEN RAISE EXCEPTION 'incomplete %',r;END IF;
 BEGIN PERFORM airlinerra_game.section9_execute_automatic_crew_hire_v1(gen_random_uuid(),a.id,run_id,start_at,changed,groups);RAISE EXCEPTION 'owner bypass';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 RAISE SQLSTATE 'ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;END;
END $test$;
SELECT 'passed' test,(SELECT count(*) FROM airlinerra_game.section9_automatic_crew_hire_runs_v1) persisted_runs,(SELECT count(*) FROM airlinerra_game.section9_shared_crew_hire_batches_v1) persisted_batches,(SELECT to_jsonb(r) FROM airlinerra_game.section9_shared_crew_employment_release_v1 r) release,has_function_privilege('authenticated','airlinerra_game.section9_execute_automatic_crew_hire_v1(uuid,uuid,uuid,timestamptz,jsonb,jsonb)','execute') client_access;