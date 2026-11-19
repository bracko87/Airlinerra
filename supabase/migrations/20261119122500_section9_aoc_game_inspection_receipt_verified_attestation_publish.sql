-- Unreleased independent game inspection completion evidence and protected attestation publisher.
BEGIN;
CREATE TABLE airlinerra_game.section9_aoc_game_inspection_service_receipts_v1 (
 service_event_id text PRIMARY KEY CHECK(service_event_id ~ '^[A-Za-z0-9._:-]{12,160}$'),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 task_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.section9_aoc_corrective_tasks_v1(task_id),
 event_id text NOT NULL REFERENCES airlinerra_game.section9_aoc_safety_incidents_v1(event_id),
 work_kind text NOT NULL CHECK(work_kind IN('safety_inspection','compliance_audit')),
 completed_game_day date NOT NULL,
 paid_ledger_entry_id bigint NOT NULL UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 paid_amount_usd_cents bigint NOT NULL CHECK(paid_amount_usd_cents>0),
 completed_by text NOT NULL CHECK(completed_by='trusted_aoc_game_inspection_worker_v1'),
 engine_completion_reference text NOT NULL UNIQUE CHECK(length(engine_completion_reference)>=16),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE airlinerra_game.section9_aoc_game_inspection_service_receipts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aoc_game_inspection_service_receipts_v1 FROM public,anon,authenticated,service_role;
CREATE TRIGGER section9_aoc_game_inspection_receipts_append_only_v1
 BEFORE UPDATE OR DELETE ON airlinerra_game.section9_aoc_game_inspection_service_receipts_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_reject_certificate_audit_mutation_v1();
CREATE OR REPLACE FUNCTION airlinerra_game.section9_publish_verified_aoc_signed_attestation_v1(p_airline uuid, p_task uuid, p_event text, p_work_kind text, p_receipt text, p_day date, p_paid_ledger bigint, p_amount_cents bigint, p_producer_event text, p_producer_reference text, p_signature text, p_payload_digest text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 v_task record; v_incident record; v_ledger record; v_service record;
 v_day date;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='AOC_SIGNED_ATTESTATION_PRIVATE_VERIFIED_PRODUCER_ONLY';
 END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_independent_correction_release_v1
   WHERE world_id=1 AND verified_producer_enabled=true)
 THEN RETURN jsonb_build_object('status','AOC_INDEPENDENT_PRODUCER_NOT_RELEASED',
   'published',false,'charged',false,'incidentResolved',false);END IF;
 IF p_airline IS NULL OR p_task IS NULL OR p_event IS NULL OR
 p_work_kind NOT IN('safety_inspection','compliance_audit') OR
 p_receipt !~ '^[A-Za-z0-9._:-]{12,160}$' OR
 p_producer_event !~ '^[A-Za-z0-9._:-]{12,160}$' OR
 p_producer_reference !~ '^[A-Za-z0-9._:-]{12,160}$' OR
 p_signature !~ '^[a-f0-9]{64}$' OR
 p_payload_digest !~ '^[a-f0-9]{64}$' OR
 p_day IS NULL OR p_paid_ledger IS NULL OR
 p_amount_cents IS NULL OR p_amount_cents<=0
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='AOC_SIGNED_ATTESTATION_INVALID';
 END IF;
 v_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF v_day IS NULL OR p_day>v_day
 THEN RETURN jsonb_build_object('status','AOC_VERIFIED_GAME_DAY_NOT_READY',
   'published',false,'charged',false,'incidentResolved',false);END IF;
 SELECT * INTO v_task FROM airlinerra_game.section9_aoc_corrective_tasks_v1
 WHERE task_id=p_task AND airline_id=p_airline FOR UPDATE;
 SELECT * INTO v_incident FROM airlinerra_game.section9_aoc_safety_incidents_v1
 WHERE event_id=p_event AND airline_id=p_airline FOR SHARE;
 SELECT * INTO v_ledger FROM airlinerra_game.airline_ledger
 WHERE id=p_paid_ledger AND airline_id=p_airline;
 SELECT * INTO v_service FROM airlinerra_game.section9_aoc_game_inspection_service_receipts_v1
 WHERE service_event_id=p_producer_event AND airline_id=p_airline
 AND task_id=p_task AND event_id=p_event AND work_kind=p_work_kind
 AND completed_game_day=p_day AND paid_ledger_entry_id=p_paid_ledger
 AND paid_amount_usd_cents=p_amount_cents
 AND completed_by='trusted_aoc_game_inspection_worker_v1';
 IF v_task.task_id IS NULL OR v_incident.event_id IS NULL OR
 v_ledger.id IS NULL OR v_service.service_event_id IS NULL OR
 v_task.event_id IS DISTINCT FROM p_event OR
 v_task.work_kind IS DISTINCT FROM p_work_kind OR
 v_task.status IS DISTINCT FROM 'paid' OR
 v_task.paid_ledger_entry_id IS DISTINCT FROM p_paid_ledger OR
 v_task.quote_usd*100 IS DISTINCT FROM p_amount_cents OR
 v_ledger.entry_kind IS DISTINCT FROM 'EXPENSE' OR
 v_ledger.amount_usd*100 IS DISTINCT FROM -p_amount_cents OR
 v_incident.resolved_game_day IS NOT NULL OR
 v_incident.occurred_game_day>p_day
 THEN RETURN jsonb_build_object('status','AOC_COMPLETED_GAME_INSPECTION_NOT_VERIFIED',
   'published',false,'charged',false,'incidentResolved',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_independent_correction_attestations_v1
  WHERE producer_event_id=p_producer_event OR task_id=p_task
   OR receipt_reference=p_receipt OR paid_ledger_entry_id=p_paid_ledger)
 THEN RETURN jsonb_build_object('status','AOC_ATTESTATION_REPLAY',
   'published',false,'charged',false,'incidentResolved',false);END IF;
 INSERT INTO airlinerra_game.section9_aoc_independent_correction_attestations_v1
 (world_id,producer_event_id,airline_id,task_id,event_id,work_kind,
 receipt_reference,completed_game_day,paid_ledger_entry_id,
 paid_amount_usd_cents,producer_reference,evidence_source,
 signature,signed_payload_sha256)
 VALUES(1,p_producer_event,p_airline,p_task,p_event,p_work_kind,
 p_receipt,p_day,p_paid_ledger,p_amount_cents,p_producer_reference,
 'independent_trusted_game_safety_producer',p_signature,p_payload_digest);
 RETURN jsonb_build_object('status','AOC_SIGNED_ATTESTATION_PUBLISHED',
  'published',true,'charged',false,'incidentResolved',false,
  'certificateIssued',false,'flightActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_publish_verified_aoc_signed_attestation_v1(uuid,uuid,text,text,text,date,bigint,bigint,text,text,text,text)
 FROM public,anon,authenticated,service_role;
COMMIT;