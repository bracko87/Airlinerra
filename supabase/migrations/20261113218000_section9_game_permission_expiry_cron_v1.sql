-- Complete automatic game licence lifecycle. Expire previously issued
-- game permissions after their verified game end date; invalidate stale
-- certification preparations through the existing reviewed expiry writer.
-- No new approval, route creation, booking or financial charge.
-- Retains authority's own verified clock and batched SQL locks.
DO $scheduler_setup$
BEGIN
 IF NOT EXISTS(
  SELECT 1 FROM cron.job
  WHERE jobname='airlinerra-game-permission-expiry-v1'
 ) THEN
  PERFORM cron.schedule(
   'airlinerra-game-permission-expiry-v1',
   '*/5 * * * *',
   'SELECT airlinerra_game.section9_expire_game_permissions_batch_v1(100);'
  );
 END IF;
END $scheduler_setup$;
