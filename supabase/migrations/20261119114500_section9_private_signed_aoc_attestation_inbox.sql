-- Private independently signed AOC evidence inbox, intentionally no producer and no release.
BEGIN;
CREATE TABLE airlinerra_game.section9_aoc_independent_correction_attestations_v1 (
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 producer_event_id text PRIMARY KEY CHECK(producer_event_id ~ '^[A-Za-z0-9._:-]{12,160}$'),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 task_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.section9_aoc_corrective_tasks_v1(task_id),
 event_id text NOT NULL REFERENCES airlinerra_game.section9_aoc_safety_incidents_v1(event_id),
 work_kind text NOT NULL CHECK(work_kind IN ('safety_inspection','compliance_audit')),
 receipt_reference text NOT NULL UNIQUE CHECK(receipt_reference ~ '^[A-Za-z0-9._:-]{12,160}$'),
 completed_game_day date NOT NULL,
 paid_ledger_entry_id bigint NOT NULL UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 paid_amount_usd_cents bigint NOT NULL CHECK(paid_amount_usd_cents>0),
 producer_reference text NOT NULL CHECK(producer_reference ~ '^[A-Za-z0-9._:-]{12,160}$'),
 evidence_source text NOT NULL CHECK(evidence_source='independent_trusted_game_safety_producer'),
 signature text NOT NULL CHECK(signature ~ '^[a-f0-9]{64}$'),
 signed_payload_sha256 text NOT NULL CHECK(signed_payload_sha256 ~ '^[a-f0-9]{64}$'),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE airlinerra_game.section9_aoc_independent_correction_attestations_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aoc_independent_correction_attestations_v1 FROM public,anon,authenticated,service_role;
CREATE TRIGGER section9_aoc_independent_attestation_append_only_v1
 BEFORE UPDATE OR DELETE ON airlinerra_game.section9_aoc_independent_correction_attestations_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_reject_certificate_audit_mutation_v1();
CREATE OR REPLACE FUNCTION airlinerra_game.section9_stage_independently_verified_aoc_correction_v1(p_airline uuid, p_task uuid, p_event text, p_work_kind text, p_receipt text, p_day date, p_paid_ledger bigint, p_amount numeric, p_producer_event text, p_payload_digest text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE task record; incident record; ledger record; v_day date; v_resolved boolean:=false;
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
 -- This must be the exact durable signed attestation that the separate
 -- private Node verifier authenticated. Merely passing a digest is insufficient.
 IF NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_aoc_independent_correction_attestations_v1 e
  WHERE e.world_id=1 AND e.airline_id=p_airline AND e.task_id=p_task
   AND e.event_id=p_event AND e.work_kind=p_work_kind
   AND e.receipt_reference=p_receipt AND e.completed_game_day=p_day
   AND e.paid_ledger_entry_id=p_paid_ledger
   AND e.paid_amount_usd_cents=p_amount*100
   AND e.producer_event_id=p_producer_event
   AND e.signed_payload_sha256=p_payload_digest
   AND e.evidence_source='independent_trusted_game_safety_producer'
  FOR SHARE
 ) THEN RETURN jsonb_build_object(
  'status','AOC_INDEPENDENT_SIGNED_EVIDENCE_NOT_FOUND',
  'staged',false,'incidentResolved',false,'charged',false,
  'certificateIssued',false,'flightActivated',false);END IF;
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
  v_resolved:=FOUND;
 END IF;
 RETURN jsonb_build_object('status','INDEPENDENT_AOC_CORRECTION_STAGED',
  'staged',true,'incidentResolved',v_resolved,'charged',false,
  'certificateIssued',false,'flightActivated',false);
END $function$
;
COMMIT;