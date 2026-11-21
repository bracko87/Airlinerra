-- Install only after the verified private cost-approval SQL is present.
-- Keeps all release switches and current cron frequency unchanged.
DO $guard$
DECLARE j record;
BEGIN
 SELECT jobid,command INTO j FROM cron.job
 WHERE jobname='airlinerra-game-approved-final-flight-finance-v1';
 IF NOT FOUND OR NOT EXISTS(SELECT 1
 FROM airlinerra_game.section9_flight_finance_posting_release_v1
 WHERE world_id=1 AND release_state='paused')
 THEN RAISE EXCEPTION 'FINANCE_SCHEDULER_CHANGED_OR_NOT_PAUSED';END IF;
 IF j.command='SELECT airlinerra_game.section9_auto_approve_completed_game_flight_costs_v1(20); SELECT airlinerra_game.section9_auto_post_complete_game_flights_v1(20);'
 THEN RETURN;END IF;
 IF j.command IS DISTINCT FROM 'SELECT airlinerra_game.section9_auto_post_complete_game_flights_v1(20);'
 THEN RAISE EXCEPTION 'FINANCE_SCHEDULER_UNEXPECTED_COMMAND';END IF;
 PERFORM cron.alter_job(job_id:=j.jobid,command:='SELECT airlinerra_game.section9_auto_approve_completed_game_flight_costs_v1(20); SELECT airlinerra_game.section9_auto_post_complete_game_flights_v1(20);');
END $guard$;
