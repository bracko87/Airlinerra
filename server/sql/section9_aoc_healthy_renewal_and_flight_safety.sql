BEGIN;
-- Routine AOC renewal uses the canonical safety score, which continues to require all genuine paid correction proof. An unreleased inspection producer must not prevent healthy airlines from renewing.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_flight_release_readiness_v1(p_airline uuid, p_game_day date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
declare a record; registry record; cert record; issues text[]:=ARRAY[]::text[]; live_day date;
begin
 if p_airline is null or p_game_day is null
 then return jsonb_build_object('status','AOC_INVALID_FLIGHT_SCOPE','authorized',false,
   'issues',jsonb_build_array('AOC_INVALID_FLIGHT_SCOPE'));end if;
 select * into a from airlinerra_game.airlines
 where id=p_airline and world_id=1;
 if not found then return jsonb_build_object('status','AOC_AIRLINE_NOT_FOUND','authorized',false,
   'issues',jsonb_build_array('AOC_AIRLINE_NOT_FOUND'));end if;
 if not exists(select 1 from airlinerra_game.section9_aoc_release_policy_v1 rp
 where rp.world_id=1 and rp.issuance_enabled and rp.safety_events_enabled
 and rp.renewal_enabled and rp.flight_enforcement_enabled)
 then issues:=array_append(issues,'AOC_FLIGHT_ENFORCEMENT_NOT_RELEASED');end if;
 live_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 if live_day is null or live_day is distinct from p_game_day
 then issues:=array_append(issues,'AOC_VERIFIED_GAME_DAY_MISMATCH');end if;
 select * into registry from airlinerra_game.section9_aoc_operating_companies_v1
 where airline_id=p_airline and world_id=1;
 if not found or registry.business_kind not in('passenger','regional','low_cost','cargo','charter','vip')
 then issues:=array_append(issues,'AOC_OPERATING_COMPANY_NOT_VERIFIED');end if;
 select * into cert from airlinerra_game.section9_aoc_certificates_v1
 where airline_id=p_airline and world_id=1;
 if not found or cert.status<>'active' or cert.issued_game_day>p_game_day
 or cert.expires_game_day<=p_game_day
 or cert.expires_game_day is distinct from cert.issued_game_day+365
 then issues:=array_append(issues,'AOC_ACTIVE_CERTIFICATE_NOT_VERIFIED');
 else
  if registry.company_source='original' then
   if cert.initial_issue_source is distinct from 'original_free_registration'
    or cert.initial_issue_application_id is not null
    or cert.initial_issue_ledger_id is not null
    or registry.identity_evidence_reference is distinct from
     'verified-original-airline-registration-v1-'||p_airline::text
   then issues:=array_append(issues,'AOC_ORIGINAL_ISSUE_PROVENANCE_INVALID');end if;
  elsif registry.company_source='subsidiary' then
   if cert.initial_issue_source is distinct from 'subsidiary_paid_application'
    or not exists(
     select 1 from airlinerra_game.section9_game_permission_applications_v1 app
     join airlinerra_game.airline_ledger ledger on ledger.id=app.ledger_entry_id
      and ledger.airline_id=p_airline and ledger.entry_kind='EXPENSE'
      and ledger.amount_usd=-10000
     join airlinerra_game.section9_operator_licence_evidence_v1 ev
      on ev.issued_application_id=app.id and ev.airline_id=p_airline
      and ev.evidence_status='verified'
     where app.id=cert.initial_issue_application_id
      and app.airline_id=p_airline and app.world_id=1
      and app.permission_code='AIR_OPERATOR_CERTIFICATE'
      and app.status='issued' and app.fee_usd=10000
      and app.ledger_entry_id=cert.initial_issue_ledger_id)
   then issues:=array_append(issues,'AOC_SUBSIDIARY_PAID_PROVENANCE_INVALID');end if;
  else issues:=array_append(issues,'AOC_COMPANY_ORIGIN_NOT_VERIFIED');end if;
 end if;
 if coalesce((airlinerra_game.section9_aoc_safety_score_v1(p_airline,p_game_day)->>'rating')::int,-1)<70 then issues:=array_append(issues,'AOC_SAFETY_RATING_BELOW_70');end if;
 return jsonb_build_object(
  'status',case when cardinality(issues)=0 then 'AOC_FLIGHT_READY' else 'AOC_FLIGHT_BLOCKED' end,
  'authorized',cardinality(issues)=0,'issues',to_jsonb(issues),
  'airlineId',p_airline,'gameDay',p_game_day,
  'flightActivated',false,'ledgerPosted',false);
end $function$;
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
END $function$;
COMMIT;
