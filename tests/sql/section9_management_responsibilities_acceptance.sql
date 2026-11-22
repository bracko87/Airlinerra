DO $test$
DECLARE a record;v jsonb;pol jsonb;oldversion int;
BEGIN
 BEGIN
 SELECT id,owner_player_id INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 v:=airlinerra_game.section9_owned_management_responsibilities_v1(a.owner_player_id,a.id);
 oldversion:=(v->>'version')::int;
 pol:='{"pilots":"auto","cabin":"auto","station":"approval","ground":"approval","maintenance":"approval","customer":"approval","administrative":"approval"}';
 v:=airlinerra_game.section9_save_owned_management_responsibilities_v1(a.owner_player_id,a.id,oldversion,pol);
 IF v->>'status'<>'management_responsibilities' OR (v->>'version')::int<>oldversion+1 OR v->>'delegatedHiringEnabled'<>'false' THEN RAISE EXCEPTION 'save %',v;END IF;
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(v->'roles') r WHERE r->>'key'='pilots' AND r->>'mode'='auto') THEN RAISE EXCEPTION 'policy missing';END IF;
 IF airlinerra_game.section9_save_owned_management_responsibilities_v1(a.owner_player_id,a.id,oldversion,pol)->>'status'<>'management_version_conflict' THEN RAISE EXCEPTION 'stale write';END IF;
 IF airlinerra_game.section9_save_owned_management_responsibilities_v1(a.owner_player_id,a.id,oldversion+1,(pol-'pilots')||'{"ceo":"auto"}')->>'status'<>'invalid_management_policies' THEN RAISE EXCEPTION 'executive delegation';END IF;
 BEGIN PERFORM airlinerra_game.section9_owned_management_responsibilities_v1(gen_random_uuid(),a.id);RAISE EXCEPTION 'owner bypass';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 IF airlinerra_game.section9_crew_capacity_status_v1(79.99)->>'crewShortageCancellationEligible'<>'true' OR airlinerra_game.section9_crew_capacity_status_v1(80)->>'crewShortageCancellationEligible'<>'false' OR airlinerra_game.section9_crew_capacity_status_v1(90)->>'status'<>'sufficient' OR airlinerra_game.section9_crew_capacity_status_v1(100)->>'status'<>'fully_staffed' OR airlinerra_game.section9_crew_capacity_status_v1(111)->>'status'<>'strong_reserves' THEN RAISE EXCEPTION 'threshold';END IF;
 v:=airlinerra_game.section9_owned_fleet_crew_capacity_input_v1(a.owner_player_id,a.id);
 IF v->>'status'<>'fleet_crew_capacity_input' OR v->>'airlineId'<>a.id::text OR v->'policy'->>'capacity_dispatch_enabled'<>'false' THEN RAISE EXCEPTION 'capacity input';END IF;
 RAISE SQLSTATE 'ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;END;
END $test$;
SELECT 'passed' test,has_function_privilege('authenticated','airlinerra_game.section9_save_owned_management_responsibilities_v1(uuid,uuid,int,jsonb)','execute') client_access,(SELECT count(*) FROM airlinerra_game.section9_management_responsibilities_v1) saved_policies;