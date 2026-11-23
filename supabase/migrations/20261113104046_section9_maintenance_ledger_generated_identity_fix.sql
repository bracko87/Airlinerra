-- Correct identity GENERATED ALWAYS ledger ID: let Postgres allocate it.
BEGIN;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_advance_game_maintenance_jobs_v1()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO airlinerra_game,pg_catalog AS $fn$
DECLARE v_now timestamptz; j record; begun integer:=0; finished integer:=0;
 posted integer:=0; total_usd numeric:=0;
 ledger_id bigint; airline_row uuid; balance_usd numeric;
BEGIN
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 FOR j IN
 SELECT * FROM airlinerra_game.section9_game_maintenance_jobs_v1
 WHERE status IN ('scheduled','in_progress','payment_required') AND game_start_utc<=v_now
 ORDER BY game_start_utc,job_id FOR UPDATE SKIP LOCKED
 LOOP
   IF j.status='scheduled' THEN
      UPDATE airlinerra_game.section9_game_maintenance_jobs_v1
       SET status='in_progress',engine_start_observed_at=v_now
       WHERE job_id=j.job_id AND status='scheduled';
      begun:=begun+1;
   END IF;
   IF j.game_end_utc<=v_now THEN
     -- Charge once, atomically with the GAME-only service receipt.
     -- No funds? Keep grounded in payment_required; do not forge free release.
     SELECT id INTO airline_row FROM airlinerra_game.airlines
     WHERE id=j.airline_id AND world_id=1 FOR UPDATE;
     IF NOT FOUND OR j.quoted_cost_usd IS NULL OR j.quoted_cost_usd<=0 THEN
      UPDATE airlinerra_game.section9_game_maintenance_jobs_v1
      SET status='payment_required'
      WHERE job_id=j.job_id AND status IN ('in_progress','payment_required');
      CONTINUE;
     END IF;
     SELECT coalesce(sum(amount_usd),0) INTO balance_usd
     FROM airlinerra_game.airline_ledger WHERE airline_id=j.airline_id;
     IF balance_usd<j.quoted_cost_usd THEN
      UPDATE airlinerra_game.section9_game_maintenance_jobs_v1
      SET status='payment_required'
      WHERE job_id=j.job_id AND status IN ('in_progress','payment_required');
      CONTINUE;
     END IF;
     INSERT INTO airlinerra_game.airline_ledger
      (airline_id,entry_kind,amount_usd,recorded_at)
     VALUES(j.airline_id,'EXPENSE',-j.quoted_cost_usd,v_now)
     RETURNING id INTO ledger_id;
     UPDATE airlinerra_game.section9_game_maintenance_jobs_v1
      SET status='completed',engine_completion_observed_at=v_now,
          paid_ledger_entry_id=ledger_id
     WHERE job_id=j.job_id AND status IN ('in_progress','payment_required');
     INSERT INTO airlinerra_game.section9_game_maintenance_service_receipts_v1
      (job_id,airline_id,aircraft_inventory_id,check_code,
       game_completed_at_utc,flight_hours_at_game_completion,
       paid_ledger_entry_id,settled_cost_usd)
     VALUES(j.job_id,j.airline_id,j.aircraft_inventory_id,j.check_code,
       j.game_end_utc,j.flight_hours_at_book,ledger_id,j.quoted_cost_usd)
     ON CONFLICT(job_id) DO NOTHING;
     finished:=finished+1;posted:=posted+1;total_usd:=total_usd+j.quoted_cost_usd;
   END IF;
 END LOOP;
 RETURN jsonb_build_object('status','processed','gameNowUtc',v_now,
  'started',begun,'completed',finished,
  'physicalInspectionsRecorded',0,'financialPostings',posted,
  'gameMaintenanceExpenseUsd',total_usd,'flightsActivated',0);
END $fn$;
COMMIT;