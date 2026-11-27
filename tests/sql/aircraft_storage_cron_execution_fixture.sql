-- Only after the disposable connected browser test. No hosted connection.
-- Use the real storage background tick and real monthly billing function,
-- with a synthetic game clock fixed exactly at the next storage anniversary.
BEGIN;
DO $test$
DECLARE s record; due date; clock_value timestamptz;
BEGIN
 IF current_database()<>'review' OR current_user<>'postgres' THEN RAISE EXCEPTION 'disposable review required';END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_extension WHERE extname='pg_cron') THEN RAISE EXCEPTION 'pg_cron missing';END IF;
 IF EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-world1-storage-background-v1') THEN RAISE EXCEPTION 'unexpected existing job';END IF;
 SELECT ss.request_id,ss.airline_id,t.anchor_game_date,t.monthly_usd,a.cash_usd INTO STRICT s
 FROM airlinerra_game.aircraft_storage_sessions_v1 ss
 JOIN airlinerra_game.aircraft_storage_billing_terms_v1 t USING(request_id)
 JOIN airlinerra_game.airlines a ON a.id=ss.airline_id
 WHERE ss.storage_ended_utc IS NULL;
 IF s.monthly_usd<>8000 OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_monthly_receipts_v1 WHERE request_id=s.request_id)<>1 THEN RAISE EXCEPTION 'unexpected active storage billing fixture';END IF;
 due:=airlinerra_game.storage_month_anniversary_v1(s.anchor_game_date,1);
 clock_value:=due::timestamp AT TIME ZONE 'Europe/Berlin';
 EXECUTE format('CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_world_instant_v1() RETURNS timestamptz LANGUAGE sql STABLE AS %L','SELECT '||quote_literal(clock_value)||'::timestamptz');
 CREATE TABLE airlinerra_game.test_storage_cron_baseline(request_id uuid,airline_id uuid,cash_before numeric,amount numeric,due_date date);
 INSERT INTO airlinerra_game.test_storage_cron_baseline VALUES(s.request_id,s.airline_id,s.cash_usd,s.monthly_usd,due);
 UPDATE airlinerra_game.storage_background_worker_release_v1 SET billing_enabled=true,movement_enabled=false,expiry_enabled=false WHERE world_id=1;
END $test$;
SELECT cron.schedule('airlinerra-world1-storage-background-v1','* * * * *','SELECT airlinerra_game.run_storage_background_tick_v1(25)');
COMMIT;
