-- Private one-minute game-flight execution transport.
-- FAIL CLOSED: no HTTP request without a Vault token AND reviewed release.
-- The deployable Edge worker additionally validates its private job token,
-- independent/departure keys, UTC game clock, six certificates, and physical
-- aircraft state. No finance or fuel settlements are invoked here.
--
-- Admin separately provisions a >=32-char random job token in BOTH:
-- 1. Edge secret AIRLINERRA_FLIGHT_EXECUTION_JOB_TOKEN
-- 2. Supabase Vault name airlinerra_flight_execution_job_token_v1
-- Never put values into repository migrations or chat.

DO $bootstrap$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM pg_extension WHERE extname='pg_cron')
 OR NOT EXISTS(SELECT 1 FROM pg_extension WHERE extname='pg_net')
 THEN RAISE NOTICE 'Private flight scheduler skipped: cron/net unavailable';
 RETURN;END IF;

 PERFORM cron.schedule(
  'airlinerra-section9-world1-execution-v1',
  '* * * * *',
  $job$
    SELECT net.http_post(
      url:='https://hwllkabgzaynalahvkpz.supabase.co/functions/v1/airlinerra-game-flight-execution-job',
      headers:=jsonb_build_object(
        'Content-Type','application/json',
        'x-airlinerra-flight-execution-token',secret.decrypted_secret
      ),
      body:='{}'::jsonb,
      timeout_milliseconds:=60000
    )
    FROM vault.decrypted_secrets secret
    WHERE secret.name='airlinerra_flight_execution_job_token_v1'
      AND length(secret.decrypted_secret)>=32
      AND EXISTS (
        SELECT 1
        FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 r
        WHERE r.world_id=1
        AND r.world_state='active'
        AND r.authoritative_clock_connected=true
        AND r.active_flight_schedules>0
        AND r.trusted_flight_execution_release='RELEASED'
        AND r.automatic_flight_and_fuel_settlement_enabled=false
        AND r.fuel_transaction_release='NOT_ACTIVATED'
      );
  $job$
 );
END $bootstrap$;
