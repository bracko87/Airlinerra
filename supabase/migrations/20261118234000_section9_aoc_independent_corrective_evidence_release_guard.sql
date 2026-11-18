-- Independent AOC correction evidence and payment must remain disabled until trusted producer validation.
BEGIN;
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_aoc_independent_correction_release_v1(
 world_id smallint primary key check(world_id=1),
 verified_producer_enabled boolean not null default false,
 reviewer_reference text,
 constraint section9_aoc_independent_producer_must_remain_off_v1 check(verified_producer_enabled=false));
ALTER TABLE airlinerra_game.section9_aoc_independent_correction_release_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aoc_independent_correction_release_v1 FROM public,anon,authenticated,service_role;
INSERT INTO airlinerra_game.section9_aoc_independent_correction_release_v1(world_id) VALUES(1) ON CONFLICT DO NOTHING;
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
$function$
;
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
 RETURN jsonb_build_object('status','aoc_corrective_payment_recorded',
  'charged',true,'chargedUsd',work.quote_usd,'completed',false,
  'ledgerEntryId',entry_id,'flightActivated',false);
END $function$
;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_review_batch_v1(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
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
 -- Do not enforce an expiry that could strand airlines behind unavailable
 -- inspection/compliance completion. This is a separate reviewed release gate.
 IF NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_aoc_independent_correction_release_v1 rel
  WHERE rel.world_id=1 AND rel.verified_producer_enabled=true
 ) THEN RETURN jsonb_build_object(
  'status','aoc_independent_correction_producer_not_released',
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
END $function$
;
COMMIT;