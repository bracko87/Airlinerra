-- ROLLBACK-ONLY REVIEW: prospective pg_cron registration.
-- Run only in an isolated database with pg_cron and the complete reviewed
-- storage schema installed. This script never persists a scheduled job.
BEGIN;
DO $schedule$
DECLARE jid bigint;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_extension WHERE extname='pg_cron') THEN RAISE EXCEPTION 'STORAGE_CRON_EXTENSION_REQUIRED';END IF;
 IF to_regprocedure('airlinerra_game.run_storage_background_tick_v1(integer)') IS NULL THEN RAISE EXCEPTION 'STORAGE_BACKGROUND_TICK_MISSING';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_background_worker_release_v1 WHERE world_id=1 AND NOT movement_enabled AND NOT billing_enabled AND NOT expiry_enabled AND NOT custody_enabled) THEN RAISE EXCEPTION 'STORAGE_BACKGROUND_GATES_MUST_BE_DISABLED';END IF;
 IF EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-world1-storage-background-v1') THEN RAISE EXCEPTION 'STORAGE_BACKGROUND_CRON_ALREADY_EXISTS';END IF;
 SELECT cron.schedule('airlinerra-world1-storage-background-v1','* * * * *','SELECT airlinerra_game.run_storage_background_tick_v1(25)') INTO jid;
 IF jid IS NULL OR NOT EXISTS(SELECT 1 FROM cron.job WHERE jobid=jid AND jobname='airlinerra-world1-storage-background-v1' AND schedule='* * * * *' AND command='SELECT airlinerra_game.run_storage_background_tick_v1(25)' AND username=current_user) THEN RAISE EXCEPTION 'STORAGE_BACKGROUND_CRON_REGISTRATION_MISMATCH';END IF;
 RAISE NOTICE 'Storage minute cron registration reviewed; rollback follows; all worker gates disabled';
END $schedule$;
ROLLBACK;
