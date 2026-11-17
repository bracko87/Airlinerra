-- AOC private, policy-gated GAME mechanics v1 (2026-11-17).
-- ALL RELEASE SWITCHES REMAIN FALSE. Functions not exposed to the player.
-- No automatic certificate, fee, reminder, clock job or flight change is
-- performed at installation. This is distinct from the paid route-permit issuer.

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_aoc_reminder_outbox_v1(
 reminder_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 airline_id uuid NOT NULL REFERENCES
   airlinerra_game.section9_aoc_operating_companies_v1(airline_id),
 expires_game_day date NOT NULL,
 due_game_day date NOT NULL,
 queued_game_day date NOT NULL,
 delivery_state text NOT NULL DEFAULT 'queued'
  CHECK(delivery_state IN('queued','delivered')),
 delivered_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(airline_id,expires_game_day),
 CHECK(due_game_day=expires_game_day-90),
 CHECK(queued_game_day>=due_game_day),
 CHECK((delivery_state='queued' AND delivered_at IS NULL) OR
       (delivery_state='delivered' AND delivered_at IS NOT NULL))
);
ALTER TABLE airlinerra_game.section9_aoc_reminder_outbox_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aoc_reminder_outbox_v1
 FROM PUBLIC,anon,authenticated,service_role;

-- Idempotent ORIGINAL certificate creation, executed only after an independent
-- operating-company registry has verified the original airline identity.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_issue_original_v1(
 p_airline uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE now_day date; a record;kind record;issued record;release record;
 audit_id text;proof text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='AOC_ORIGINAL_ISSUER_TRUSTED_ONLY';END IF;
 SELECT * INTO release FROM airlinerra_game.section9_aoc_release_policy_v1
 WHERE world_id=1;
 IF release.issuance_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','aoc_not_released',
  'issued',false,'charged',false);END IF;
 now_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF now_day IS NULL
 THEN RETURN jsonb_build_object('status','aoc_clock_not_verified',
  'issued',false,'charged',false);END IF;

 SELECT * INTO a FROM airlinerra_game.airlines
 WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','aoc_airline_unknown',
  'issued',false,'charged',false);END IF;
 SELECT * INTO kind FROM airlinerra_game.section9_aoc_operating_companies_v1
 WHERE airline_id=p_airline AND world_id=1 FOR SHARE;
 IF NOT FOUND OR kind.company_source IS DISTINCT FROM 'original' OR
  length(coalesce(kind.identity_evidence_reference,''))<12
 THEN RETURN jsonb_build_object('status','aoc_original_identity_not_verified',
  'issued',false,'charged',false);END IF;

 SELECT * INTO issued FROM airlinerra_game.section9_aoc_certificates_v1
 WHERE airline_id=p_airline FOR UPDATE;
 IF FOUND THEN RETURN jsonb_build_object('status','aoc_already_recorded',
  'issued',false,'charged',false,
  'certificateId',issued.certificate_id);END IF;

 proof:='aoc-original-registration-v1-'||p_airline::text||'-'||now_day::text;
 INSERT INTO airlinerra_game.section9_aoc_certificates_v1(
   airline_id,world_id,initial_issue_source,initial_issue_verified_reference,
   status,issued_game_day,expires_game_day,last_decision_game_day)
 VALUES(p_airline,1,'original_free_registration',proof,
   'active',now_day,now_day+365,now_day)
 RETURNING * INTO issued;

 audit_id:='aoc-original-v1-'||p_airline::text||'-'||now_day::text;
 INSERT INTO airlinerra_game.section9_aoc_review_audit_v1(
   event_id,airline_id,game_day,action,effective_safety_rating,
   expiry_game_day,verified_event_reference)
 VALUES(audit_id,p_airline,now_day,'original_issue',100,
   issued.expires_game_day,proof);

 RETURN jsonb_build_object('status','aoc_original_issued',
  'issued',true,'charged',false,'feeUsd',0,'airlineId',p_airline,
  'issuedGameDay',now_day,'expiresGameDay',issued.expires_game_day,
  'flightActivated',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_aoc_issue_original_v1(uuid)
 FROM PUBLIC,anon,authenticated,service_role;

-- Independently settles the AOC certificate ONLY after the existing
-- signed, owner-verified paid application has issued, and WITHOUT
-- charging the same $10,000 a second time.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_attach_paid_subsidiary_v1(
 p_airline uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE now_day date; a record;kind record;issued record;
 app record;proof text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='AOC_SUBSIDIARY_ISSUER_TRUSTED_ONLY';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_release_policy_v1
   WHERE world_id=1 AND issuance_enabled=true)
 THEN RETURN jsonb_build_object('status','aoc_not_released',
   'issued',false,'charged',false);END IF;
 now_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF now_day IS NULL THEN RETURN jsonb_build_object('status',
  'aoc_clock_not_verified','issued',false,'charged',false);END IF;
 SELECT * INTO a FROM airlinerra_game.airlines
 WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','aoc_airline_unknown',
  'issued',false,'charged',false);END IF;
 SELECT * INTO kind FROM airlinerra_game.section9_aoc_operating_companies_v1
 WHERE airline_id=p_airline AND world_id=1
  AND company_source='subsidiary' AND holding_id IS NOT NULL
  AND subsidiary_id IS NOT NULL FOR SHARE;
 IF NOT FOUND OR NOT EXISTS(
  SELECT 1 FROM airlinerra_game.holding_groups_v1 h
   JOIN airlinerra_game.holding_subsidiaries_v1 s ON s.holding_id=h.id
  WHERE h.id=kind.holding_id AND s.id=kind.subsidiary_id
   AND h.world_id=1 AND s.world_id=1
   AND h.owner_player_id=a.owner_player_id)
 THEN RETURN jsonb_build_object('status','aoc_subsidiary_identity_not_verified',
  'issued',false,'charged',false);END IF;
 SELECT * INTO issued FROM airlinerra_game.section9_aoc_certificates_v1
 WHERE airline_id=p_airline FOR UPDATE;
 IF FOUND THEN RETURN jsonb_build_object('status','aoc_already_recorded',
  'issued',false,'charged',false,
  'certificateId',issued.certificate_id);END IF;
 SELECT applicant.* INTO app
 FROM airlinerra_game.section9_game_permission_applications_v1 applicant
 JOIN airlinerra_game.airline_ledger ledger
   ON ledger.id=applicant.ledger_entry_id
   AND ledger.airline_id=p_airline AND ledger.entry_kind='EXPENSE'
   AND ledger.amount_usd=-10000
 JOIN airlinerra_game.section9_operator_licence_evidence_v1 evidence
   ON evidence.issued_application_id=applicant.id
   AND evidence.airline_id=p_airline AND evidence.evidence_status='verified'
 WHERE applicant.airline_id=p_airline AND applicant.world_id=1
  AND applicant.permission_code='AIR_OPERATOR_CERTIFICATE'
  AND applicant.status='issued' AND applicant.fee_usd=10000
  AND applicant.due_game_date=applicant.applied_game_date+3
  AND applicant.issued_game_date IS NOT NULL
  AND applicant.issued_game_date<=now_day
  AND applicant.valid_until_game_date>=applicant.issued_game_date+365
  AND EXISTS(SELECT 1 FROM
    airlinerra_game.section9_game_permission_review_events_v1 ev
   WHERE ev.application_id=applicant.id
    AND ev.decision='approve' AND ev.airline_id=p_airline)
 ORDER BY applicant.issued_game_date DESC,applicant.id
 LIMIT 1 FOR SHARE OF applicant;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','aoc_paid_application_not_verified',
  'issued',false,'charged',false);END IF;
 proof:='aoc-paid-subsidiary-v1-'||app.id::text||'-'||app.issued_game_date::text;
 INSERT INTO airlinerra_game.section9_aoc_certificates_v1(
  airline_id,world_id,initial_issue_source,initial_issue_application_id,
  initial_issue_ledger_id,initial_issue_verified_reference,status,
  issued_game_day,expires_game_day,last_decision_game_day)
 VALUES(p_airline,1,'subsidiary_paid_application',app.id,
  app.ledger_entry_id,proof,'active',app.issued_game_date,
  app.issued_game_date+365,app.issued_game_date)
 RETURNING * INTO issued;
 INSERT INTO airlinerra_game.section9_aoc_review_audit_v1(
  event_id,airline_id,game_day,action,effective_safety_rating,
  expiry_game_day,verified_event_reference)
 VALUES('aoc-subsidiary-v1-'||app.id::text,
  p_airline,app.issued_game_date,'subsidiary_issue',100,
  issued.expires_game_day,proof);
 RETURN jsonb_build_object('status','aoc_subsidiary_attached',
   'issued',true,'charged',false,'alreadyPaidUsd',10000,
   'airlineId',p_airline,'expiresGameDay',issued.expires_game_day,
   'flightActivated',false);
END $fn$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_aoc_attach_paid_subsidiary_v1(uuid)
 FROM PUBLIC,anon,authenticated,service_role;

-- Pay a trusted, already-priced corrective task from the correct operator,
-- with company ownership, company cash, and one-time ledger posting.
-- Completion REQUIRES a separate future independently verified receipt.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_pay_corrective_task_v1(
 p_player uuid,p_task uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE a record;work record;entry_id bigint;now_day date;
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
 -- Lock airline FIRST, then task, same as game licence fee settlement.
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
 IF work.status IN('paid','completed') AND work.paid_ledger_entry_id IS NOT NULL
 THEN RETURN jsonb_build_object('status','aoc_corrective_payment_already_recorded',
  'charged',false,'completed',work.status='completed',
  'ledgerEntryId',work.paid_ledger_entry_id);END IF;
 IF work.status NOT IN('quoted','booked') OR work.quote_usd<=0 OR
  length(coalesce(work.quote_source_reference,''))<12
 THEN RETURN jsonb_build_object('status','aoc_corrective_quote_invalid',
  'charged',false,'completed',false);END IF;
 IF a.cash_usd<work.quote_usd
 THEN RETURN jsonb_build_object('status','aoc_insufficient_company_cash',
  'charged',false,'completed',false,'requiredUsd',work.quote_usd);END IF;
 UPDATE airlinerra_game.airlines SET cash_usd=cash_usd-work.quote_usd
 WHERE id=a.id;
 INSERT INTO airlinerra_game.airline_ledger
  (airline_id,entry_kind,amount_usd)
 VALUES(a.id,'EXPENSE',-work.quote_usd)
 RETURNING id INTO entry_id;
 UPDATE airlinerra_game.section9_aoc_corrective_tasks_v1
 SET status='paid',paid_ledger_entry_id=entry_id WHERE task_id=p_task;
 RETURN jsonb_build_object('status','aoc_corrective_payment_recorded',
  'charged',true,'chargedUsd',work.quote_usd,'completed',false,
  'ledgerEntryId',entry_id,'flightActivated',false);
END $fn$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_aoc_pay_corrective_task_v1(uuid,uuid)
 FROM PUBLIC,anon,authenticated,service_role;

-- REVIEW / NOTIFICATION worker: never runs unless independent AOC
-- release switches and verified signed game clock are BOTH available.
-- It only updates this new AOC registry; the existing flight verifier is
-- deliberately unchanged until proof compatibility / refund testing.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_review_batch_v1(
 p_limit integer DEFAULT 50
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE day_now date;cert record;score jsonb;
 rating integer; processed integer:=0;reminders integer:=0;
 renewed integer:=0;expired integer:=0;reinstated integer:=0;
 change_day date;new_expiry date;ref text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='AOC_REVIEW_POSTGRES_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='AOC_REVIEW_INVALID_LIMIT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_release_policy_v1
  WHERE world_id=1 AND issuance_enabled=true AND
   safety_events_enabled=true AND renewal_enabled=true)
 THEN RETURN jsonb_build_object('status','aoc_review_not_released',
  'processed',0,'issued',0,'renewed',0,'expired',0,
  'reinstated',0,'remindersQueued',0,'charged',false);END IF;
 day_now:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF day_now IS NULL THEN RETURN jsonb_build_object('status',
  'aoc_review_unverified_game_clock','processed',0,'charged',false);END IF;

 FOR cert IN SELECT c.* FROM airlinerra_game.section9_aoc_certificates_v1 c
  JOIN airlinerra_game.section9_aoc_operating_companies_v1 company
   ON company.airline_id=c.airline_id AND company.world_id=1
  WHERE c.world_id=1 AND (c.status='expired'
   OR (c.status='active' AND c.expires_game_day-90<=day_now))
  ORDER BY c.expires_game_day,c.airline_id
  LIMIT p_limit FOR UPDATE OF c SKIP LOCKED
 LOOP
  processed:=processed+1;
  IF cert.status='active' AND day_now<cert.expires_game_day THEN
   IF cert.reminded_for_expiry_game_day IS DISTINCT FROM cert.expires_game_day THEN
    INSERT INTO airlinerra_game.section9_aoc_reminder_outbox_v1
    (airline_id,expires_game_day,due_game_day,queued_game_day)
    VALUES(cert.airline_id,cert.expires_game_day,
     cert.expires_game_day-90,day_now)
    ON CONFLICT(airline_id,expires_game_day) DO NOTHING;
    UPDATE airlinerra_game.section9_aoc_certificates_v1
    SET reminded_for_expiry_game_day=cert.expires_game_day,
     updated_at=clock_timestamp() WHERE airline_id=cert.airline_id;
    reminders:=reminders+1;
   END IF;
   CONTINUE;
  END IF;

  change_day:=CASE WHEN cert.status='active'
    THEN cert.expires_game_day ELSE day_now END;
  score:=airlinerra_game.section9_aoc_safety_score_v1(
    cert.airline_id,change_day);
  rating:=(score->>'rating')::integer;
  IF rating IS NULL OR rating<0 OR rating>100
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='AOC_REVIEW_SAFETY_SCORE_NOT_VERIFIED';END IF;

  IF cert.status='active' AND rating>=70 THEN
   new_expiry:=cert.expires_game_day+365;
   ref:='aoc-renew-'||cert.airline_id::text||'-'||
      cert.expires_game_day::text;
   UPDATE airlinerra_game.section9_aoc_certificates_v1
   SET issued_game_day=cert.expires_game_day,
     expires_game_day=new_expiry,
     reminded_for_expiry_game_day=NULL,
     last_decision_game_day=change_day,
     updated_at=clock_timestamp()
   WHERE airline_id=cert.airline_id;
   INSERT INTO airlinerra_game.section9_aoc_review_audit_v1(
    event_id,airline_id,game_day,action,effective_safety_rating,
    expiry_game_day,verified_event_reference)
   VALUES(ref,cert.airline_id,change_day,'renew',rating,new_expiry,
     'trusted-aoc-review-v1-'||change_day::text);
   renewed:=renewed+1;
  ELSIF cert.status='active' THEN
   ref:='aoc-expire-'||cert.airline_id::text||'-'||
      cert.expires_game_day::text;
   UPDATE airlinerra_game.section9_aoc_certificates_v1
   SET status='expired',last_decision_game_day=change_day,
     updated_at=clock_timestamp()
   WHERE airline_id=cert.airline_id;
   INSERT INTO airlinerra_game.section9_aoc_review_audit_v1(
    event_id,airline_id,game_day,action,effective_safety_rating,
    expiry_game_day,verified_event_reference)
   VALUES(ref,cert.airline_id,change_day,'expire',rating,
     cert.expires_game_day,'trusted-aoc-review-v1-'||change_day::text);
   expired:=expired+1;
  ELSIF cert.status='expired' AND rating>=70 THEN
   new_expiry:=day_now+365;
   ref:='aoc-reinstate-'||cert.airline_id::text||'-'||day_now::text;
   UPDATE airlinerra_game.section9_aoc_certificates_v1
   SET status='active',issued_game_day=day_now,
    expires_game_day=new_expiry,reminded_for_expiry_game_day=NULL,
    last_decision_game_day=day_now,updated_at=clock_timestamp()
   WHERE airline_id=cert.airline_id;
   INSERT INTO airlinerra_game.section9_aoc_review_audit_v1(
    event_id,airline_id,game_day,action,effective_safety_rating,
    expiry_game_day,verified_event_reference)
   VALUES(ref,cert.airline_id,day_now,'reinstate',rating,new_expiry,
    'trusted-aoc-recovery-v1-'||day_now::text);
   reinstated:=reinstated+1;
  END IF;
 END LOOP;
 RETURN jsonb_build_object('status','aoc_review_batch_completed',
  'gameDay',day_now,'processed',processed,'issued',0,
  'renewed',renewed,'expired',expired,'reinstated',reinstated,
  'remindersQueued',reminders,'charged',false,
  'flightActivated',false,'movementRecorded',false);
END $fn$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_aoc_review_batch_v1(integer)
 FROM PUBLIC,anon,authenticated,service_role;
