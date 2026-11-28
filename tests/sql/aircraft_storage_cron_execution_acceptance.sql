-- Called after two successful real minute executions by pg_cron.
BEGIN;
DO $test$
DECLARE b record; jid bigint;
BEGIN
 IF current_database()<>'review' OR current_user<>'postgres' THEN RAISE EXCEPTION 'disposable review required';END IF;
 SELECT * INTO STRICT b FROM airlinerra_game.test_storage_cron_baseline;
 SELECT jobid INTO STRICT jid FROM cron.job WHERE jobname='airlinerra-world1-storage-background-v1' AND database=current_database();
 IF (SELECT count(*) FROM cron.job_run_details WHERE jobid=jid AND status='succeeded')<2 THEN RAISE EXCEPTION 'two successful minute jobs required';END IF;
 IF EXISTS(SELECT 1 FROM cron.job_run_details WHERE jobid=jid AND status='failed') THEN RAISE EXCEPTION 'minute job failed';END IF;
 IF (SELECT count(*) FROM airlinerra_game.aircraft_storage_monthly_receipts_v1 WHERE request_id=b.request_id)<>2
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_monthly_receipts_v1 r JOIN airlinerra_game.airline_ledger l ON l.id=r.ledger_id WHERE r.request_id=b.request_id AND r.month_number=2 AND r.amount_usd=b.amount AND r.due_game_date=b.due_date AND l.airline_id=b.airline_id AND l.amount_usd=-b.amount AND l.entry_kind='EXPENSE')
 OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=b.airline_id) IS DISTINCT FROM b.cash_before-b.amount
 THEN RAISE EXCEPTION 'scheduler billing not exactly once';END IF;
 IF NOT cron.unschedule(jid) THEN RAISE EXCEPTION 'scheduler cleanup failed';END IF;
 UPDATE airlinerra_game.storage_background_worker_release_v1 SET billing_enabled=false,movement_enabled=false,expiry_enabled=false WHERE world_id=1;
 RAISE NOTICE 'PASS real pg_cron minute execution: two successful runs, one new monthly storage charge, matching cash and ledger, job removed';
END $test$;
COMMIT;
