DO $test$
DECLARE a record; snap jsonb; start_at timestamptz; r jsonb; plan uuid:=gen_random_uuid();
BEGIN
 SELECT id,owner_player_id INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 start_at:=airlinerra_game.section9_verified_world_instant_v1()+interval '1 day';
 snap:=airlinerra_game.section9_owned_weekly_crew_input_v1(a.owner_player_id,a.id,start_at);
 r:=airlinerra_game.section9_save_owned_crew_plan_preview_v1(a.owner_player_id,a.id,plan,start_at,snap||'{"extra":true}'::jsonb,'[]');
 IF r->>'status'<>'crew_plan_snapshot_changed' THEN RAISE EXCEPTION 'stale %',r;END IF;
 r:=airlinerra_game.section9_save_owned_crew_plan_preview_v1(a.owner_player_id,a.id,plan,start_at,snap,'[]');
 IF r->>'status'<>'crew_plan_incomplete' THEN RAISE EXCEPTION 'empty %',r;END IF;
 BEGIN PERFORM airlinerra_game.section9_save_owned_crew_plan_preview_v1(gen_random_uuid(),a.id,plan,start_at,snap,'[]');RAISE EXCEPTION 'ownership bypass';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_plan_batches_v1 WHERE plan_id=plan) THEN RAISE EXCEPTION 'invalid plan saved';END IF;
END $test$;
SELECT 'passed' test,(SELECT count(*) FROM airlinerra_game.section9_crew_plan_batches_v1) persisted_plans,(SELECT count(*) FROM airlinerra_game.section9_planned_crew_seats_v1) persisted_seats,has_function_privilege('authenticated','airlinerra_game.section9_save_owned_crew_plan_preview_v1(uuid,uuid,uuid,timestamptz,jsonb,jsonb)','execute') client_access;