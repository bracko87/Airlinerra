-- AOC corrective evidence hardening. Install-only, gated; no game actions.
-- Do NOT charge twice for an aircraft repair: existing maintenance engine
-- already settles one maintenance ledger expense at service completion.

ALTER TABLE airlinerra_game.section9_aoc_corrective_tasks_v1
 ADD COLUMN maintenance_job_id uuid UNIQUE REFERENCES
 airlinerra_game.section9_game_maintenance_jobs_v1(job_id);
ALTER TABLE airlinerra_game.section9_aoc_corrective_tasks_v1
 ADD CONSTRAINT section9_aoc_repair_requires_existing_game_job_v1
 CHECK(work_kind<>'aircraft_repair' OR status<>'completed'
  OR maintenance_job_id IS NOT NULL);

-- Inspections/compliance reports will require an independent trusted
-- service producer. Merely typing a receipt string is NOT completion.
CREATE TABLE airlinerra_game.section9_aoc_compliance_receipts_v1 (
 receipt_reference text PRIMARY KEY CHECK(length(receipt_reference)>=12),
 task_id uuid NOT NULL UNIQUE REFERENCES
  airlinerra_game.section9_aoc_corrective_tasks_v1(task_id),
 airline_id uuid NOT NULL REFERENCES
  airlinerra_game.section9_aoc_operating_companies_v1(airline_id),
 verified_game_day date NOT NULL,
 evidence_source text NOT NULL CHECK(length(evidence_source)>=16),
 signer_digest text NOT NULL CHECK(signer_digest~'^[a-f0-9]{64}$'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE airlinerra_game.section9_aoc_compliance_receipts_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aoc_compliance_receipts_v1
 FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER section9_aoc_compliance_receipts_append_only_v1
 BEFORE UPDATE OR DELETE ON airlinerra_game.section9_aoc_compliance_receipts_v1
 FOR EACH ROW EXECUTE FUNCTION
 airlinerra_game.section9_reject_certificate_audit_mutation_v1();

-- Read-only score; only actually paid and independently witnessed
-- corrective work removes the associated incident's current penalty.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_safety_score_v1(
 p_airline uuid,p_game_day date
) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
 WITH incident_status AS (
  SELECT i.event_id,i.airline_id,i.penalty_points,i.occurred_game_day,
   (i.resolved_game_day IS NOT NULL AND i.resolved_game_day<=p_game_day
    AND (SELECT count(*) FROM airlinerra_game.section9_aoc_corrective_tasks_v1 t
         JOIN airlinerra_game.airline_ledger l ON l.id=t.paid_ledger_entry_id
           AND l.airline_id=i.airline_id
           AND l.entry_kind='EXPENSE'
           AND l.amount_usd=-t.quote_usd
         WHERE t.event_id=i.event_id AND t.airline_id=i.airline_id
          AND t.status='completed'
          AND t.completed_game_day<=p_game_day
          AND length(t.completion_receipt_reference)>=12
          AND (
           (t.work_kind='aircraft_repair' AND t.maintenance_job_id IS NOT NULL
             AND EXISTS(
              SELECT 1 FROM airlinerra_game.section9_game_maintenance_service_receipts_v1 m
              WHERE m.job_id=t.maintenance_job_id
                AND m.airline_id=t.airline_id
                AND m.paid_ledger_entry_id=t.paid_ledger_entry_id
                AND m.settled_cost_usd=t.quote_usd
                AND m.source_kind='verified_game_service_job_v1'
                AND m.game_completed_at_utc::date<=p_game_day
                AND t.completion_receipt_reference=
                 'aoc-game-maintenance-v1-'||m.job_id::text)
            )
           OR
           (t.work_kind IN('safety_inspection','compliance_audit')
            AND EXISTS(
             SELECT 1 FROM airlinerra_game.section9_aoc_compliance_receipts_v1 r
             WHERE r.task_id=t.task_id AND r.airline_id=t.airline_id
              AND r.receipt_reference=t.completion_receipt_reference
              AND r.verified_game_day<=p_game_day))
          )
        )=i.required_action_count
    AND (SELECT count(*) FROM airlinerra_game.section9_aoc_corrective_tasks_v1 t
         WHERE t.event_id=i.event_id AND t.airline_id=i.airline_id
        )=i.required_action_count
   ) AS fully_corrected
  FROM airlinerra_game.section9_aoc_safety_incidents_v1 i
  WHERE i.airline_id=p_airline AND i.occurred_game_day<=p_game_day
 ), tally AS (
  SELECT count(*)::integer AS lifetime,
   count(*) FILTER(WHERE occurred_game_day>p_game_day-365)::integer
     AS last365,
   count(*) FILTER(WHERE NOT fully_corrected)::integer AS open_count,
   coalesce(sum(penalty_points) FILTER(WHERE NOT fully_corrected),0)::integer
     AS penalty_total
  FROM incident_status
 )
 SELECT jsonb_build_object(
   'airlineId',p_airline,'gameDay',p_game_day,
   'rating',greatest(0,100-penalty_total),
   'unresolved',open_count,'last365GameDays',last365,'lifetime',lifetime,
   'initialBaseline',lifetime=0,'readOnly',true)
 FROM tally
$fn$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_aoc_safety_score_v1(uuid,date)
 FROM PUBLIC,anon,authenticated,service_role;

-- Aircraft repairs are paid via the EXISTING game maintenance engine.
-- Never charge separately for the same game repair.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_pay_corrective_task_v1(
 p_player uuid,p_task uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
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
END $fn$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_aoc_pay_corrective_task_v1(uuid,uuid)
 FROM PUBLIC,anon,authenticated,service_role;
