-- Berlin-local daily tick is signed at first cron opportunity after midnight.
-- The display clock is continuous; this job only records immutable day boundaries.
-- One-minute checks reduce the daily ledger lag to under a minute in normal operation.
-- No secrets, date or world activation are changed here.
DO $migration$
DECLARE id bigint;
BEGIN
 SELECT jobid INTO id FROM cron.job
 WHERE jobname='airlinerra-section9-world1-clock-v1' AND active=true;
 IF id IS NULL THEN
  RAISE EXCEPTION 'AIRLINERRA_WORLD1_CLOCK_JOB_NOT_FOUND';
 END IF;
 PERFORM cron.alter_job(job_id=>id,schedule=>'* * * * *');
END $migration$;
