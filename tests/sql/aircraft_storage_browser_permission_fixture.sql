-- Synthetic permission calendar for disposable browser CI only.
BEGIN;
DO $test$
DECLARE t timestamptz; d date;
BEGIN
 IF current_database()<>'review' THEN RAISE EXCEPTION 'disposable review database required';END IF;
 SELECT storage_started_utc INTO STRICT t FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE aircraft_inventory_id='00000000-0000-4000-8000-000000000003' AND storage_ended_utc IS NULL;
 d:=(t AT TIME ZONE 'UTC')::date;
 INSERT INTO airlinerra_game.storage_service_policy_v1 VALUES(1,'OURAIRPORTS:316427','UTC',d-1,d+10,'prior_permission_required','synthetic CI service calendar',t);
 INSERT INTO airlinerra_game.storage_service_windows_v1
 SELECT 1,'OURAIRPORTS:316427',op,day,d-1,d+10,0,1440 FROM (VALUES ('arrival'),('departure')) AS ops(op) CROSS JOIN generate_series(1,7) AS days(day);
 INSERT INTO airlinerra_game.storage_game_permission_policy_v1 VALUES(1,'OURAIRPORTS:316427',true,120,'synthetic CI access review','synthetic CI sponsor review',t);
 UPDATE airlinerra_game.storage_game_permission_release_v1 SET enabled=true WHERE world_id=1;
END $test$;
COMMIT;
