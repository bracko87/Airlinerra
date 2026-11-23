-- Correct the Charter/VIP worker identity; no changes to licence release.
DO $cron$
BEGIN
 IF EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-charter-licence3-review-v1')
 THEN PERFORM cron.unschedule('airlinerra-charter-licence3-review-v1');END IF;
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-charter-licence4-review-v1')
 THEN PERFORM cron.schedule('airlinerra-charter-licence4-review-v1',
 '*/5 * * * *','SELECT airlinerra_game.licence4_review_due_charter_game_applications_v1(25)');END IF;
END $cron$;