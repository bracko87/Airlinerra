-- Run game-only maintenance service starts/completions once per minute.
-- This does not execute any flight, physical inspection, booking or financial posting.
BEGIN;
DO $$
BEGIN
 IF EXISTS (
  SELECT 1 FROM cron.job WHERE jobname='airlinerra-section9-game-maintenance-v1'
 ) THEN RAISE EXCEPTION USING ERRCODE='23505',
 MESSAGE='SECTION9_GAME_MAINTENANCE_CRON_ALREADY_EXISTS'; END IF;
END $$;
SELECT cron.schedule('airlinerra-section9-game-maintenance-v1','* * * * *',
 'SELECT airlinerra_game.section9_advance_game_maintenance_jobs_v1()');
COMMIT;