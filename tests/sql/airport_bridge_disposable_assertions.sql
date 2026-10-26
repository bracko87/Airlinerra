-- Assertions after executing the ACTUAL (unmodified) prelaunch bridge SQL
-- against synthetic World 1 research tables in disposable PostgreSQL.
DO $assertions$
BEGIN
  IF current_database() <> 'airlinerra_disposable' THEN
    RAISE EXCEPTION 'Refuse bridge assertions outside disposable CI database';
  END IF;
  IF (SELECT count(*) FROM airlinerra_game.approved_game_airports) <> 3140 THEN
    RAISE EXCEPTION 'World 01 game approvals do not total 3140';
  END IF;
  IF EXISTS (SELECT 1 FROM airlinerra_game.approved_game_airports
             WHERE world_id <> 1
                OR approval_reference <> 'SIMULATION_ONLY:FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26') THEN
    RAISE EXCEPTION 'Unexpected World 01 approval scope';
  END IF;
  IF EXISTS (
    SELECT airport_key FROM airlinerra_game.approved_game_airports
    EXCEPT SELECT airport_key FROM airlinerra.airport_game_world1_registration_source
  ) OR EXISTS (
    SELECT airport_key FROM airlinerra.airport_game_world1_registration_source
    EXCEPT SELECT airport_key FROM airlinerra_game.approved_game_airports
  ) THEN
    RAISE EXCEPTION 'Authorized source keys and game-approved keys differ';
  END IF;
  IF EXISTS (SELECT 1 FROM public.airlinerra_game_worlds WHERE state <> 'planned')
     OR (SELECT count(*) FROM public.airlinerra_game_worlds) <> 3 THEN
    RAISE EXCEPTION 'Bridge changed a public game world state';
  END IF;
  IF (SELECT count(*) FROM airlinerra_game.platform_release_gate WHERE enabled = false) <> 1 THEN
    RAISE EXCEPTION 'Bridge incorrectly opened platform release gate';
  END IF;
  IF EXISTS (SELECT 1 FROM airlinerra_game.airlines)
     OR EXISTS (SELECT 1 FROM airlinerra_game.account_entitlements)
     OR EXISTS (SELECT 1 FROM airlinerra_game.account_consents)
     OR EXISTS (SELECT 1 FROM auth.users) THEN
    RAISE EXCEPTION 'Bridge unexpectedly created accounts or airlines';
  END IF;
  IF has_table_privilege('anon','airlinerra_game.approved_game_airports','SELECT')
     OR has_table_privilege('authenticated','airlinerra_game.approved_game_airports','SELECT') THEN
    RAISE EXCEPTION 'Bridge exposed private airport approvals';
  END IF;
END $assertions$;
