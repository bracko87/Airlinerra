-- Airlinerra World 1 foundation 3140 -> account game-roster migration dry run.
-- Executed PASS on 26 October 2026 using *temporary* SQL state.
-- Does not create the airlinerra_game schema, deploy auth, create a player,
-- activate world access, or write to persistent approved_game_airports.
-- This test intentionally requires the real account roster to be absent.
DO $dry$
DECLARE n integer; n2 integer; unauthorized integer;
BEGIN
 IF to_regclass('airlinerra_game.approved_game_airports') IS NOT NULL THEN
 RAISE EXCEPTION 'Account roster now exists: use the post-auth sync migration, not the preinstall dryrun';
 END IF;
 CREATE TEMP TABLE airlinerra_world1_roster_dryrun_20261026 (
 world_id smallint NOT NULL CHECK(world_id=1),
 source_airport_id bigint NOT NULL,
 approval_reference text NOT NULL CHECK(
  approval_reference='SIMULATION_ONLY:FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26'),
 PRIMARY KEY(world_id,source_airport_id)
 ) ON COMMIT DROP;
 INSERT INTO airlinerra_world1_roster_dryrun_20261026
 (world_id,source_airport_id,approval_reference)
 SELECT c.world_id,c.home_airport_source_id,
 'SIMULATION_ONLY:FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26'
 FROM airlinerra.airport_game_world1_registration_source c
 ON CONFLICT (world_id,source_airport_id) DO NOTHING;
 SELECT count(*) INTO n FROM airlinerra_world1_roster_dryrun_20261026;
 IF n<>3140 THEN RAISE EXCEPTION 'Initial sync count incorrect: %',n; END IF;
 INSERT INTO airlinerra_world1_roster_dryrun_20261026
 (world_id,source_airport_id,approval_reference)
 SELECT c.world_id,c.home_airport_source_id,
 'SIMULATION_ONLY:FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26'
 FROM airlinerra.airport_game_world1_registration_source c
 ON CONFLICT (world_id,source_airport_id) DO NOTHING;
 SELECT count(*) INTO n2 FROM airlinerra_world1_roster_dryrun_20261026;
 IF n2<>n THEN RAISE EXCEPTION 'Sync import is not idempotent'; END IF;
 SELECT count(*) INTO unauthorized
 FROM airlinerra_world1_roster_dryrun_20261026 a
 LEFT JOIN airlinerra.airport_game_world1_registration_source c
 ON c.world_id=a.world_id AND c.home_airport_source_id=a.source_airport_id
 WHERE c.home_airport_source_id IS NULL;
 IF unauthorized>0 THEN RAISE EXCEPTION 'Unauthorized airport in copied game roster'; END IF;
 DROP TABLE airlinerra_world1_roster_dryrun_20261026;
END $dry$;
SELECT 'PASS' AS isolated_game_roster_sync_dryrun,
 3140::integer AS eligible_simulated_airports,
 false AS game_account_schema_installed;
