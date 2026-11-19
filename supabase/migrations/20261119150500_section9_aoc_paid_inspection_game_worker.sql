-- Private game-day AOC inspection worker, not released until producer attestation and schedule tested.
BEGIN;
CREATE TABLE airlinerra_game.section9_aoc_inspection_game_jobs_v1 (
 task_id uuid PRIMARY KEY REFERENCES airlinerra_game.section9_aoc_corrective_tasks_v1(task_id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 event_id text NOT NULL REFERENCES airlinerra_game.section9_aoc_safety_incidents_v1(event_id),
 work_kind text NOT NULL CHECK(work_kind IN ('safety_inspection','compliance_audit')),
 paid_ledger_entry_id bigint NOT NULL UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 quote_usd numeric NOT NULL CHECK(quote_usd>0),
 booked_game_day date NOT NULL,
 due_game_day date NOT NULL,
 status text NOT NULL CHECK(status IN ('scheduled','completed')),
 completed_game_day date,
 completed_engine_tick_ref text,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(due_game_day>booked_game_day),
 CHECK((status='scheduled' AND completed_game_day IS NULL AND completed_engine_tick_ref IS NULL)
    OR (status='completed' AND completed_game_day IS NOT NULL AND
        completed_engine_tick_ref IS NOT NULL AND length(completed_engine_tick_ref)>=12))
);
ALTER TABLE airlinerra_game.section9_aoc_inspection_game_jobs_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aoc_inspection_game_jobs_v1 FROM public,anon,authenticated,service_role;
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
 -- No inspection/compliance charge before an independent receipt verifier exists.
 IF work.work_kind IN('safety_inspection','compliance_audit') AND NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_aoc_independent_correction_release_v1 rel
  WHERE rel.world_id=1 AND rel.verified_producer_enabled=true
 ) THEN RETURN jsonb_build_object(
  'status','aoc_independent_correction_producer_not_released',
  'charged',false,'completed',false,'flightActivated',false);END IF;
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
 -- Game work begins only after successful, reconciled and owned payment.
 -- The worker must observe the next independently verified game day.
 IF work.work_kind IN ('safety_inspection','compliance_audit') THEN
  INSERT INTO airlinerra_game.section9_aoc_inspection_game_jobs_v1(
   task_id,airline_id,event_id,work_kind,paid_ledger_entry_id,
   quote_usd,booked_game_day,due_game_day,status)
  VALUES(p_task,a.id,work.event_id,work.work_kind,entry_id,
   work.quote_usd,now_day,now_day+1,'scheduled');
 END IF;
 RETURN jsonb_build_object('status','aoc_corrective_payment_recorded',
  'charged',true,'chargedUsd',work.quote_usd,'completed',false,
  'ledgerEntryId',entry_id,'flightActivated',false);
END $function$
;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_complete_due_aoc_game_inspections_v1(p_limit integer DEFAULT 25)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE today date;row_job record; tick record; task record; led record;
 completed integer:=0; checked integer:=0; skipped integer:=0;
 ref text; engine_ref text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='AOC_INSPECTION_WORKER_POSTGRES_ONLY';
 END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='AOC_INSPECTION_WORKER_INVALID_LIMIT';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_independent_correction_release_v1
  WHERE world_id=1 AND verified_producer_enabled=true)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_release_policy_v1
  WHERE world_id=1 AND issuance_enabled=true AND safety_events_enabled=true)
 THEN RETURN jsonb_build_object('status','AOC_INSPECTION_WORKER_NOT_RELEASED',
  'processed',0,'completed',0,'charged',false,'certificatesIssued',0,'flightActivated',false);
 END IF;
 today:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF today IS NULL THEN RETURN jsonb_build_object('status','AOC_INSPECTION_WORKER_CLOCK_NOT_VERIFIED',
  'processed',0,'completed',0,'charged',false,'flightActivated',false);END IF;
 SELECT * INTO tick FROM airlinerra_game.section9_verified_game_tick_receipts_v1
 WHERE world_id=1 AND game_date=today;
 IF NOT FOUND OR length(coalesce(tick.engine_event_id,''))<12 THEN
  RETURN jsonb_build_object('status','AOC_INSPECTION_WORKER_TICK_NOT_VERIFIED',
   'processed',0,'completed',0,'charged',false,'flightActivated',false);
 END IF;
 FOR row_job IN
  SELECT j.* FROM airlinerra_game.section9_aoc_inspection_game_jobs_v1 j
  JOIN airlinerra_game.airlines a ON a.id=j.airline_id AND a.world_id=1
  WHERE j.status='scheduled' AND j.due_game_day<=today
  ORDER BY j.due_game_day,j.task_id
  LIMIT p_limit FOR UPDATE OF j SKIP LOCKED
 LOOP
  checked:=checked+1;
  SELECT * INTO task FROM airlinerra_game.section9_aoc_corrective_tasks_v1
   WHERE task_id=row_job.task_id AND airline_id=row_job.airline_id FOR UPDATE;
  SELECT * INTO led FROM airlinerra_game.airline_ledger
   WHERE id=row_job.paid_ledger_entry_id AND airline_id=row_job.airline_id;
  IF task.task_id IS NULL OR led.id IS NULL OR
   task.status IS DISTINCT FROM 'paid' OR task.event_id IS DISTINCT FROM row_job.event_id
   OR task.work_kind IS DISTINCT FROM row_job.work_kind
   OR task.paid_ledger_entry_id IS DISTINCT FROM row_job.paid_ledger_entry_id
   OR task.quote_usd IS DISTINCT FROM row_job.quote_usd
   OR led.entry_kind IS DISTINCT FROM 'EXPENSE' OR
   led.amount_usd IS DISTINCT FROM -row_job.quote_usd
   OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_safety_incidents_v1 i
    WHERE i.event_id=row_job.event_id AND i.airline_id=row_job.airline_id
     AND i.world_id=1 AND i.resolved_game_day IS NULL)
  THEN skipped:=skipped+1;CONTINUE;END IF;
  ref:='aoc-inspection-game-v1-'||row_job.task_id::text||'-'||today::text;
  engine_ref:='aoc-inspection-tick-v1-'||tick.engine_event_id||'-'||row_job.task_id::text;
  INSERT INTO airlinerra_game.section9_aoc_game_inspection_service_receipts_v1(
   service_event_id,world_id,airline_id,task_id,event_id,work_kind,
   completed_game_day,paid_ledger_entry_id,paid_amount_usd_cents,
   completed_by,engine_completion_reference)
  VALUES(ref,1,row_job.airline_id,row_job.task_id,row_job.event_id,row_job.work_kind,
   today,row_job.paid_ledger_entry_id,(row_job.quote_usd*100)::bigint,
   'trusted_aoc_game_inspection_worker_v1',engine_ref);
  UPDATE airlinerra_game.section9_aoc_inspection_game_jobs_v1
  SET status='completed',completed_game_day=today,completed_engine_tick_ref=tick.engine_event_id
  WHERE task_id=row_job.task_id AND status='scheduled';
  IF NOT FOUND THEN RAISE EXCEPTION 'AOC_INSPECTION_WORK_ORDER_RACE';END IF;
  completed:=completed+1;
 END LOOP;
 RETURN jsonb_build_object('status','AOC_INSPECTION_WORKER_PROCESSED',
  'gameDay',today,'processed',checked,'completed',completed,'skipped',skipped,
  'charged',false,'certificatesIssued',0,'flightActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_complete_due_aoc_game_inspections_v1(integer) FROM public,anon,authenticated,service_role;
COMMIT;