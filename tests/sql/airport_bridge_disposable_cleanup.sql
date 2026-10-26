-- Clean up exclusively the synthetic fixture inside disposable CI Postgres.
DO $guard$
BEGIN
  IF current_database() <> 'airlinerra_disposable' THEN
    RAISE EXCEPTION 'Refuse bridge cleanup outside disposable CI database';
  END IF;
  IF (SELECT count(*) FROM airlinerra_game.airlines) <> 0 THEN
    RAISE EXCEPTION 'Refuse cleanup when any airline exists';
  END IF;
END $guard$;

DELETE FROM airlinerra_game.approved_game_airports
WHERE approval_reference='SIMULATION_ONLY:FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26';
DROP SCHEMA airlinerra CASCADE;

DO $assertions$
BEGIN
  IF EXISTS (SELECT 1 FROM airlinerra_game.approved_game_airports)
    OR to_regnamespace('airlinerra') IS NOT NULL
    OR (SELECT count(*) FROM public.airlinerra_game_worlds WHERE state='planned') <> 3
    OR (SELECT count(*) FROM airlinerra_game.platform_release_gate WHERE enabled=false) <> 1 THEN
    RAISE EXCEPTION 'CI bridge cleanup did not restore prelaunch base state';
  END IF;
END $assertions$;
