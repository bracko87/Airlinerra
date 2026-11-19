-- Private game-engine EU Licence 2 automatic review. Release flags remain OFF.
-- Random HMAC key generated inside Vault and never stored in source control.
BEGIN;
DO $vault$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM vault.secrets
  WHERE name='airlinerra_licence2_auto_review_signing_v1')
 THEN PERFORM vault.create_secret(encode(extensions.gen_random_bytes(48),'hex'),
  'airlinerra_licence2_auto_review_signing_v1','Private game-only EU Licence 2 reviewer');
 END IF;
END $vault$;
CREATE TABLE airlinerra_game.licence2_private_auto_review_audit_v1 (
 review_event_id text PRIMARY KEY CHECK(review_event_id ~ '^[A-Za-z0-9._:-]{16,128}$'),
 application_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.licence2_market_applications_v1(application_id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 market_code text NOT NULL CHECK(market_code='L2-EU'),
 requested_level smallint NOT NULL CHECK(requested_level BETWEEN 1 AND 4),
 game_day date NOT NULL,
 verified_engine_tick_event_id text NOT NULL CHECK(length(verified_engine_tick_event_id)>=12),
 review_reference text NOT NULL CHECK(length(review_reference)>=20),
 charged_fee_usd numeric NOT NULL CHECK(charged_fee_usd>0),
 signature_hmac_sha256 text NOT NULL CHECK(signature_hmac_sha256 ~ '^[a-f0-9]{64}$'),
 signed_payload_sha256 text NOT NULL CHECK(signed_payload_sha256 ~ '^[a-f0-9]{64}$'),
 verified_authority_kind text NOT NULL CHECK(verified_authority_kind='AIRLINERRA_GAME_L2_AUTO_REVIEW_V1'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE airlinerra_game.licence2_private_auto_review_audit_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.licence2_private_auto_review_audit_v1 FROM public,anon,authenticated,service_role;
CREATE TRIGGER licence2_private_auto_review_audit_append_only_v1
 BEFORE UPDATE OR DELETE ON airlinerra_game.licence2_private_auto_review_audit_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_reject_certificate_audit_mutation_v1();
CREATE OR REPLACE FUNCTION airlinerra_game.licence2_review_due_eu_game_applications_auto_v1(p_limit integer DEFAULT 25)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE now_day date;signing_key text;clock_event text;
 item record;pre jsonb;decision jsonb;payload text;event_key text;
 review_reference text;signature text; fee numeric;
 reviewed integer:=0;issued integer:=0;blocked integer:=0;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='LICENCE2_GAME_AUTO_REVIEW_TRUSTED_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='LICENCE2_GAME_AUTO_REVIEW_INVALID_LIMIT';END IF;
 -- Do not even read the signing key while any owner-reviewed release is off.
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.licence2_approval_release_v1
  WHERE world_id=1 AND approval_enabled=true AND
  reviewer_integration_verified=true AND fee_ledger_integration_verified=true)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.licence2_market_policy_v1
  WHERE market_code='L2-EU' AND issuance_enabled=true)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_release_policy_v1
  WHERE world_id=1 AND issuance_enabled=true AND flight_enforcement_enabled=true)
 THEN RETURN jsonb_build_object('status','LICENCE2_GAME_AUTO_REVIEW_NOT_RELEASED',
  'reviewed',0,'issued',0,'charged',false,'flightActivated',false);END IF;
 now_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF now_day IS NULL THEN RETURN jsonb_build_object(
  'status','LICENCE2_GAME_AUTO_REVIEW_CLOCK_NOT_VERIFIED',
  'reviewed',0,'issued',0,'charged',false,'flightActivated',false);END IF;
 SELECT engine_event_id INTO clock_event
 FROM airlinerra_game.section9_verified_game_tick_receipts_v1
 WHERE world_id=1 AND game_date=now_day;
 IF length(coalesce(clock_event,''))<12 THEN
  RETURN jsonb_build_object('status','LICENCE2_GAME_AUTO_REVIEW_TICK_MISSING',
   'reviewed',0,'issued',0,'charged',false,'flightActivated',false);END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583729,10022) THEN
  RETURN jsonb_build_object('status','LICENCE2_GAME_AUTO_REVIEW_IN_PROGRESS',
   'reviewed',0,'issued',0,'charged',false,'flightActivated',false);END IF;
 SELECT decrypted_secret INTO signing_key
 FROM vault.decrypted_secrets
 WHERE name='airlinerra_licence2_auto_review_signing_v1';
 IF signing_key IS NULL OR length(signing_key)<64 THEN
  RETURN jsonb_build_object('status','LICENCE2_GAME_REVIEW_SIGNING_KEY_UNAVAILABLE',
   'reviewed',0,'issued',0,'charged',false,'flightActivated',false);END IF;
 FOR item IN
  SELECT a.application_id,a.airline_id,a.market_code,a.requested_level
  FROM airlinerra_game.licence2_market_applications_v1 a
  WHERE a.world_id=1 AND a.market_code='L2-EU' AND
   a.status='submitted' AND a.submitted_game_date IS NOT NULL AND
   a.submitted_game_date<=now_day-3
  ORDER BY a.submitted_game_date,a.application_id LIMIT p_limit
 LOOP
  pre:=airlinerra_game.licence2_approval_preflight_v1(item.application_id);
  IF pre->>'approvalReady' IS DISTINCT FROM 'true' OR
   pre->>'market' IS DISTINCT FROM 'L2-EU' OR
   (pre->>'level')::integer IS DISTINCT FROM item.requested_level OR
   (pre->>'processingGameDays')::integer IS DISTINCT FROM 3
  THEN blocked:=blocked+1;CONTINUE;END IF;
  fee:=(pre->>'quotedFeeUsd')::numeric;
  IF (item.requested_level=1 AND fee<>25000) OR
     (item.requested_level=2 AND fee<>75000) OR
     (item.requested_level=3 AND fee<>200000) OR
     (item.requested_level=4 AND fee<>500000) OR
     fee IS NULL THEN
   RAISE EXCEPTION 'LICENCE2_OWNER_APPROVED_FEE_MISMATCH';END IF;
  event_key:='l2-auto-game-v1-'||item.application_id::text||'-'||now_day::text;
  review_reference:='l2-auto-verified-review-v1-'||item.application_id::text||'-'||now_day::text;
  payload:='airlinerra-eu-licence2-auto-game-review-v1'||E'\n'||
   '1'||E'\n'||item.application_id::text||E'\n'||
   item.airline_id::text||E'\n'||item.market_code||E'\n'||
   item.requested_level::text||E'\n'||'approve'||E'\n'||
   event_key||E'\n'||review_reference||E'\n'||
   now_day::text||E'\n'||clock_event||E'\n'||fee::text;
  signature:=encode(extensions.hmac(
   pg_catalog.convert_to(payload,'UTF8'),
   pg_catalog.convert_to(signing_key,'UTF8'),'sha256'),'hex');
  -- Locked atomic writer verifies owned submission, original AOC, age,
  -- reserve, route evidence, day, fee, airline cash and ledger one more time.
  decision:=airlinerra_game.licence2_approve_application_atomic_v1(
   item.application_id,event_key,review_reference);
  reviewed:=reviewed+1;
  IF decision->>'status'='APPROVED_AND_CHARGED_ONCE'
   AND decision->>'chargedNow'='true' AND
   decision->>'permitIssuedNow'='true' AND
   decision->>'flightActivated'='false' AND
   (decision->>'chargedUsd')::numeric=fee AND
   decision->>'applicationId'=item.application_id::text AND
   decision->>'reviewEventId'=event_key
  THEN
   INSERT INTO airlinerra_game.licence2_private_auto_review_audit_v1(
    review_event_id,application_id,airline_id,market_code,requested_level,
    game_day,verified_engine_tick_event_id,review_reference,charged_fee_usd,
    signature_hmac_sha256,signed_payload_sha256,verified_authority_kind)
   VALUES(event_key,item.application_id,item.airline_id,item.market_code,
    item.requested_level,now_day,clock_event,review_reference,fee,signature,
    encode(extensions.digest(pg_catalog.convert_to(payload,'UTF8'),'sha256'),'hex'),
    'AIRLINERRA_GAME_L2_AUTO_REVIEW_V1');
   issued:=issued+1;
  ELSIF decision->>'chargedNow'='false' AND
        decision->>'permitIssuedNow'='false' AND
        decision->>'status' IN (
         'APPROVAL_PREFLIGHT_BLOCKED','ALREADY_APPROVED',
         'SUBMITTED_OWNED_APPLICATION_REQUIRED','APPROVAL_GAME_DAY_UNVERIFIED',
         'ALREADY_HOLDS_LEVEL','APPROVAL_CASH_LEDGER_BLOCKED',
         'LICENCE2_APPROVAL_NOT_RELEASED')
  THEN blocked:=blocked+1;
  ELSE
   RAISE EXCEPTION 'LICENCE2_AUTO_REVIEW_UNSAFE_WRITER_RESPONSE: %',
    decision->>'status';
  END IF;
 END LOOP;
 RETURN jsonb_build_object('status','LICENCE2_GAME_AUTO_REVIEW_PROCESSED',
  'reviewed',reviewed,'issued',issued,'blocked',blocked,
  'chargedOnlyOnAtomicPermitIssuance',true,'flightActivated',false,
  'signingKeyExposed',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.licence2_review_due_eu_game_applications_auto_v1(integer)
 FROM public,anon,authenticated,service_role;
DO $cron$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-licence2-eu-auto-review-v1')
 THEN PERFORM cron.schedule('airlinerra-licence2-eu-auto-review-v1',
  '*/5 * * * *',
  'SELECT airlinerra_game.licence2_review_due_eu_game_applications_auto_v1(25)');
 END IF;
END $cron$;
COMMIT;