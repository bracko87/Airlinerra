-- Require exact company cash/ledger reconciliation before paid AOC corrective work.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_pay_corrective_task_v1(p_player uuid, p_task uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE a record;work record;entry_id bigint;now_day date;
 ledger_balance numeric;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='AOC_CORRECTIVE_PAYMENT_TRUSTED_ONLY';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_release_policy_v1
  WHERE world_id=1 AND issuance_enabled=true AND safety_events_enabled=true)
 THEN RETURN jsonb_build_object('status','aoc_corrections_not_released',
  'charged',false,'completed',false);END IF;
 now_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF now_day IS NULL THEN RETURN jsonb_build_object('status','aoc_clock_not_verified',
  'charged',false,'completed',false);END IF;
 SELECT airline.* INTO a FROM airlinerra_game.airlines airline
 WHERE airline.id=(SELECT t.airline_id FROM
   airlinerra_game.section9_aoc_corrective_tasks_v1 t WHERE t.task_id=p_task)
  AND airline.owner_player_id=p_player AND airline.world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='AOC_CORRECTIVE_AIRLINE_NOT_OWNED';END IF;
 SELECT t.* INTO work FROM airlinerra_game.section9_aoc_corrective_tasks_v1 t
 JOIN airlinerra_game.section9_aoc_safety_incidents_v1 incident
  ON incident.event_id=t.event_id AND incident.airline_id=t.airline_id
 WHERE t.task_id=p_task AND t.airline_id=a.id
  AND incident.resolved_game_day IS NULL FOR UPDATE OF t;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','aoc_corrective_task_unavailable',
  'charged',false,'completed',false);END IF;
 IF work.work_kind='aircraft_repair' THEN
  RETURN jsonb_build_object('status','aoc_use_existing_paid_maintenance_job',
   'charged',false,'completed',false,'doubleChargePrevented',true);
 END IF;
 IF work.status IN('paid','completed') AND work.paid_ledger_entry_id IS NOT NULL
 THEN RETURN jsonb_build_object('status','aoc_corrective_payment_already_recorded',
  'charged',false,'completed',work.status='completed',
  'ledgerEntryId',work.paid_ledger_entry_id);END IF;
 IF work.status NOT IN('quoted','booked') OR work.quote_usd<=0 OR
  length(coalesce(work.quote_source_reference,''))<12
 THEN RETURN jsonb_build_object('status','aoc_corrective_quote_invalid',
  'charged',false,'completed',false);END IF;
 SELECT coalesce(sum(amount_usd),0) INTO ledger_balance
 FROM airlinerra_game.airline_ledger WHERE airline_id=a.id;
 IF a.cash_usd IS NULL OR ledger_balance IS DISTINCT FROM a.cash_usd
 THEN RETURN jsonb_build_object('status','aoc_company_cash_ledger_not_reconciled',
  'charged',false,'completed',false);END IF;
 IF a.cash_usd<work.quote_usd OR ledger_balance<work.quote_usd
 THEN RETURN jsonb_build_object('status','aoc_insufficient_company_cash',
  'charged',false,'completed',false,'requiredUsd',work.quote_usd);END IF;
 UPDATE airlinerra_game.airlines SET cash_usd=cash_usd-work.quote_usd
 WHERE id=a.id AND cash_usd>=work.quote_usd;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='40001',
  MESSAGE='AOC_CORRECTIVE_CASH_CHANGED_CONCURRENTLY';END IF;
 INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
 VALUES(a.id,'EXPENSE',-work.quote_usd) RETURNING id INTO entry_id;
 UPDATE airlinerra_game.section9_aoc_corrective_tasks_v1
 SET status='paid',paid_ledger_entry_id=entry_id WHERE task_id=p_task;
 RETURN jsonb_build_object('status','aoc_corrective_payment_recorded',
  'charged',true,'chargedUsd',work.quote_usd,'completed',false,
  'ledgerEntryId',entry_id,'flightActivated',false);
END $function$
;
