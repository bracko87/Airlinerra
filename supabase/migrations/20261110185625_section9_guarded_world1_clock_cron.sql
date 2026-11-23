-- World 1 authoritative clock transport, fail-closed until private
-- Edge Function runtime variables and the matching Vault HTTP job token
-- have been configured by the operator. No signing keys in the repo/DB.
-- Scheduling this transport alone does NOT advance the game clock,
-- authorize a flight, post payroll, or settle fuel/finances.
--
-- Preflight: an enabled, owner-approved World 1 clock schedule exists.
-- Request emission requires a nonempty private Vault token and a due date.
-- The trusted Edge job must independently verify token + HMAC, then
-- atomically re-check time and accept the due tick in Postgres.
--
-- Private environment setup:
--   AIRLINERRA_CLOCK_JOB_TOKEN (Edge only)
--   AIRLINERRA_GAME_ENGINE_HMAC_SECRET (Edge only)
--   SUPABASE_DB_URL (Edge only)
--   airlinerra_clock_job_token_v1 (Vault, same value as Edge token)
-- Never expose these in GitHub, SQL migrations, or website JavaScript.

DO $bootstrap$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname='pg_cron')
    OR NOT EXISTS (SELECT 1 FROM pg_extension WHERE extname='pg_net') THEN
   RAISE NOTICE 'World 1 clock transport not scheduled: pg_cron/pg_net missing';
   RETURN;
 END IF;

 PERFORM cron.schedule(
  'airlinerra-section9-world1-clock-v1',
  '*/5 * * * *',
  $clock$
    SELECT net.http_post(
      url:='https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-game-clock-job',
      headers:=jsonb_build_object(
        'Content-Type','application/json',
        'x-airlinerra-clock-job-token',s.decrypted_secret
      ),
      body:='{}'::jsonb,
      timeout_milliseconds:=20000
    )
    FROM vault.decrypted_secrets AS s
    WHERE s.name='airlinerra_clock_job_token_v1'
      AND length(s.decrypted_secret)>=32
      AND (
        SELECT due->>'status'
        FROM (SELECT airlinerra_game.section9_clock_producer_due_v1(
          1::smallint) AS due) AS check_due
      )='due';
  $clock$
 );
END;
$bootstrap$;
