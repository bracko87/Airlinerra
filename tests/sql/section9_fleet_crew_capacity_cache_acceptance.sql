DO $test$
DECLARE a record; r jsonb; rev bigint; data jsonb;ac uuid;cfg bigint;
BEGIN
 BEGIN
 SELECT id,owner_player_id INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 SELECT configuration_id INTO STRICT cfg FROM airlinerra_game.airline_aircraft_inventory WHERE airline_id=a.id LIMIT 1;
 DELETE FROM airlinerra_game.section9_fleet_crew_capacity_cache_v1 WHERE airline_id=a.id;
 r:=airlinerra_game.section9_read_fleet_crew_capacity_cache_v1(a.owner_player_id,a.id);
 IF r->>'status'<>'capacity_cache_miss' THEN RAISE EXCEPTION 'miss';END IF;
 rev:=(r->>'revision')::bigint;
 data:=jsonb_build_object('status','fleet_crew_capacity','airlineId',a.id,'dispatchEnforced',false,'families','[]'::jsonb);
 IF airlinerra_game.section9_store_fleet_crew_capacity_cache_v1(a.owner_player_id,a.id,rev,data)->>'status'<>'capacity_cache_stored' THEN RAISE EXCEPTION 'store';END IF;
 r:=airlinerra_game.section9_read_fleet_crew_capacity_cache_v1(a.owner_player_id,a.id);
 IF r->>'status'<>'capacity_cache_hit' OR r->'payload'<>data THEN RAISE EXCEPTION 'hit';END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(airline_id,configuration_id,registration,ownership_type,fleet_status) VALUES(a.id,cfg,'TEST-CAPACITY-CACHE','owned','in_service') RETURNING id INTO ac;
 r:=airlinerra_game.section9_read_fleet_crew_capacity_cache_v1(a.owner_player_id,a.id);
 IF r->>'status'<>'capacity_cache_miss' OR (r->>'revision')::bigint<=rev THEN RAISE EXCEPTION 'invalidation %',r;END IF;
 IF airlinerra_game.section9_store_fleet_crew_capacity_cache_v1(a.owner_player_id,a.id,rev,data)->>'status'<>'capacity_cache_revision_changed' THEN RAISE EXCEPTION 'stale write';END IF;
 IF airlinerra_game.section9_store_fleet_crew_capacity_cache_v1(a.owner_player_id,a.id,(r->>'revision')::bigint,data)->>'status'<>'capacity_cache_stored' THEN RAISE EXCEPTION 'new revision';END IF;
 UPDATE airlinerra_game.section9_fleet_crew_capacity_cache_v1 SET computed_at=now()-interval '2 hours' WHERE airline_id=a.id;
 IF airlinerra_game.section9_read_fleet_crew_capacity_cache_v1(a.owner_player_id,a.id)->>'status'<>'capacity_cache_miss' THEN RAISE EXCEPTION 'expiry';END IF;
 BEGIN PERFORM airlinerra_game.section9_read_fleet_crew_capacity_cache_v1(gen_random_uuid(),a.id);RAISE EXCEPTION 'owner bypass';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 RAISE SQLSTATE 'ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;END;
END $test$;
SELECT 'passed' test,has_function_privilege('authenticated','airlinerra_game.section9_read_fleet_crew_capacity_cache_v1(uuid,uuid)','execute') cache_client_access,(SELECT contracting_enabled FROM airlinerra_game.section9_external_crew_release_v1 WHERE world_id=1) contractor_gate,(SELECT count(*) FROM airlinerra_game.section9_external_crew_contracts_v1) live_contracts;