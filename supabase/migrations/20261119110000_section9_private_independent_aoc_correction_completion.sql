-- Private, gated correction evidence. Does not turn on the independent producer or AOC issuance.
BEGIN;
CREATE TABLE airlinerra_game.section9_aoc_verified_correction_proofs_v1 (
 producer_event_id text PRIMARY KEY CHECK(length(producer_event_id) BETWEEN 12 AND 160),
 task_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.section9_aoc_corrective_tasks_v1(task_id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 event_id text NOT NULL REFERENCES airlinerra_game.section9_aoc_safety_incidents_v1(event_id),
 work_kind text NOT NULL CHECK(work_kind IN ('safety_inspection','compliance_audit')),
 receipt_reference text NOT NULL UNIQUE CHECK(length(receipt_reference)>=12),
 completed_game_day date NOT NULL,
 paid_ledger_entry_id bigint NOT NULL UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 paid_amount_usd numeric NOT NULL CHECK(paid_amount_usd>0),
 signed_payload_sha256 text NOT NULL CHECK(signed_payload_sha256 ~ '^[a-f0-9]{64}$'),
 evidence_source text NOT NULL CHECK(evidence_source='independent_trusted_game_safety_producer'),
 staged_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE airlinerra_game.section9_aoc_verified_correction_proofs_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aoc_verified_correction_proofs_v1 FROM public,anon,authenticated,service_role;
CREATE TRIGGER section9_verified_aoc_proofs_append_only_v1
 BEFORE DELETE OR UPDATE ON airlinerra_game.section9_aoc_verified_correction_proofs_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_reject_certificate_audit_mutation_v1();
CREATE OR REPLACE FUNCTION airlinerra_game.section9_stage_independently_verified_aoc_correction_v1(p_airline uuid, p_task uuid, p_event text, p_work_kind text, p_receipt text, p_day date, p_paid_ledger bigint, p_amount numeric, p_producer_event text, p_payload_digest text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE task record; incident record; ledger record; v_day date;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501', MESSAGE='AOC_CORRECTION_PROOF_TRUSTED_ONLY';
 END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra_game.section9_aoc_independent_correction_release_v1
  WHERE world_id=1 AND verified_producer_enabled=true)
 THEN RETURN jsonb_build_object('status','INDEPENDENT_AOC_PRODUCER_NOT_RELEASED',
  'staged',false,'incidentResolved',false,'charged',false,'certificateIssued',false);
 END IF;
 IF p_airline IS NULL OR p_task IS NULL OR p_day IS NULL
  OR p_work_kind NOT IN ('safety_inspection','compliance_audit')
  OR p_event IS NULL OR length(p_event)<12
  OR p_receipt IS NULL OR length(p_receipt)<12
  OR p_producer_event IS NULL OR length(p_producer_event)<12
  OR p_payload_digest IS NULL OR p_payload_digest !~ '^[a-f0-9]{64}$'
  OR p_paid_ledger IS NULL OR p_paid_ledger<=0
  OR p_amount IS NULL OR p_amount<=0
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='AOC_CORRECTION_PROOF_INVALID';
 END IF;
 v_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF v_day IS NULL OR p_day>v_day
 THEN RETURN jsonb_build_object('status','AOC_CORRECTION_VERIFIED_GAME_DAY_MISSING',
  'staged',false,'incidentResolved',false,'charged',false);END IF;
 SELECT * INTO task FROM airlinerra_game.section9_aoc_corrective_tasks_v1
 WHERE task_id=p_task AND airline_id=p_airline FOR UPDATE;
 SELECT * INTO incident FROM airlinerra_game.section9_aoc_safety_incidents_v1
 WHERE event_id=p_event AND airline_id=p_airline FOR UPDATE;
 SELECT * INTO ledger FROM airlinerra_game.airline_ledger
 WHERE id=p_paid_ledger AND airline_id=p_airline;
 IF NOT FOUND OR task.task_id IS NULL OR incident.event_id IS NULL
 OR task.event_id IS DISTINCT FROM p_event
 OR task.work_kind IS DISTINCT FROM p_work_kind
 OR task.status IS DISTINCT FROM 'paid'
 OR task.paid_ledger_entry_id IS DISTINCT FROM p_paid_ledger
 OR task.quote_usd IS DISTINCT FROM p_amount
 OR ledger.entry_kind IS DISTINCT FROM 'EXPENSE'
 OR ledger.amount_usd IS DISTINCT FROM -p_amount
 OR incident.resolved_game_day IS NOT NULL
 OR incident.occurred_game_day>p_day
 THEN RETURN jsonb_build_object('status','AOC_CORRECTION_EVIDENCE_MISMATCH',
  'staged',false,'incidentResolved',false,'charged',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_verified_correction_proofs_v1
  WHERE producer_event_id=p_producer_event OR task_id=p_task
   OR receipt_reference=p_receipt OR paid_ledger_entry_id=p_paid_ledger)
 THEN RETURN jsonb_build_object('status','AOC_CORRECTION_PROOF_REPLAY',
  'staged',false,'incidentResolved',false,'charged',false);END IF;
 INSERT INTO airlinerra_game.section9_aoc_verified_correction_proofs_v1
 (producer_event_id,task_id,airline_id,event_id,work_kind,receipt_reference,
  completed_game_day,paid_ledger_entry_id,paid_amount_usd,signed_payload_sha256,evidence_source)
 VALUES(p_producer_event,p_task,p_airline,p_event,p_work_kind,p_receipt,
  p_day,p_paid_ledger,p_amount,p_payload_digest,'independent_trusted_game_safety_producer');
 INSERT INTO airlinerra_game.section9_aoc_compliance_receipts_v1
 (receipt_reference,task_id,airline_id,verified_game_day,evidence_source,signer_digest)
 VALUES(p_receipt,p_task,p_airline,p_day,
  'independent_trusted_game_safety_producer',p_payload_digest);
 UPDATE airlinerra_game.section9_aoc_corrective_tasks_v1
 SET status='completed',completed_game_day=p_day,
  completion_receipt_reference=p_receipt
 WHERE task_id=p_task AND airline_id=p_airline AND status='paid';
 IF NOT FOUND THEN RAISE EXCEPTION 'AOC_CORRECTION_COMPLETION_LOST_LOCK';END IF;
 -- Only resolve if this event has all required, now-completed actions.
 IF (SELECT count(*) FROM airlinerra_game.section9_aoc_corrective_tasks_v1
    WHERE event_id=p_event AND airline_id=p_airline)=incident.required_action_count
 AND (SELECT count(*) FROM airlinerra_game.section9_aoc_corrective_tasks_v1
    WHERE event_id=p_event AND airline_id=p_airline AND status='completed')=incident.required_action_count
 THEN
  UPDATE airlinerra_game.section9_aoc_safety_incidents_v1
  SET resolved_game_day=p_day,resolution_reference=p_receipt
  WHERE event_id=p_event AND airline_id=p_airline AND resolved_game_day IS NULL;
 END IF;
 RETURN jsonb_build_object('status','INDEPENDENT_AOC_CORRECTION_STAGED',
  'staged',true,'incidentResolved',false,'charged',false,
  'certificateIssued',false,'flightActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_stage_independently_verified_aoc_correction_v1(uuid,uuid,text,text,text,date,bigint,numeric,text,text)
 FROM public,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_safety_score_v1(p_airline uuid, p_game_day date)
 RETURNS jsonb
 LANGUAGE sql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
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
             SELECT 1 FROM airlinerra_game.section9_aoc_independent_correction_release_v1 rel
             WHERE rel.world_id=1 AND rel.verified_producer_enabled=true)
            AND EXISTS(
             SELECT 1 FROM airlinerra_game.section9_aoc_compliance_receipts_v1 r
             WHERE r.task_id=t.task_id AND r.airline_id=t.airline_id
              AND r.receipt_reference=t.completion_receipt_reference
              AND r.verified_game_day<=p_game_day
              AND EXISTS (
               SELECT 1 FROM airlinerra_game.section9_aoc_verified_correction_proofs_v1 v
               WHERE v.task_id=t.task_id AND v.airline_id=t.airline_id
                AND v.event_id=t.event_id AND v.work_kind=t.work_kind
                AND v.receipt_reference=r.receipt_reference
                AND v.completed_game_day=t.completed_game_day
                AND v.paid_ledger_entry_id=t.paid_ledger_entry_id
                AND v.paid_amount_usd=t.quote_usd
                AND v.completed_game_day<=p_game_day
              )))
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
$function$
;
COMMIT;