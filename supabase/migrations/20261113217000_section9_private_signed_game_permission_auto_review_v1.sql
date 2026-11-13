-- Trusted automatic GAME-only reviewer. NOT official aviation approval.
-- Secret is generated securely inside the database; its plaintext is
-- never embedded in this migration, code, a GitHub commit or tool output.
DO $vault_setup$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM vault.secrets
    WHERE name='airlinerra_game_permission_auto_signing_v1')
 THEN
  PERFORM vault.create_secret(
   encode(extensions.gen_random_bytes(48),'hex'),
   'airlinerra_game_permission_auto_signing_v1',
   'Game-only automatic licence review. Restricted to trusted database worker.');
 END IF;
END $vault_setup$;

-- Signed, owner-proof, idempotent issuance/replay checking delegated to
-- the existing section9_decide_game_permission_application_v1 function.
-- Automatic reviewer only runs on an independently enabled game policy.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_review_due_game_permissions_auto_v1(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 game_day date;
 secret_value text;
 application_row record;
 event_id text;
 payload text;
 signature text;
 decision_result jsonb;
 reviewed integer:=0;
 issued integer:=0;
 blocked integer:=0;
 ignored integer:=0;
 blocked_reasons jsonb:='{}'::jsonb;
 reason text;
 auto_release_count integer;
BEGIN
 -- This guard runs BEFORE reading private Vault data or applications.
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='GAME_PERMISSION_AUTO_AUTHORITY_POSTGRES_ONLY';
 END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='GAME_PERMISSION_AUTO_REVIEW_LIMIT_INVALID';
 END IF;
 game_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF game_day IS NULL THEN
  RETURN jsonb_build_object('status','blocked_unverified_game_clock',
   'reviewed',0,'issued',0,'charged',false,'flightActivated',false);
 END IF;

 SELECT count(*) INTO auto_release_count
 FROM airlinerra_game.section9_game_permission_issuance_policy_v1 r
 JOIN airlinerra_game.business_permission_catalog_v1 c USING(permission_code)
 WHERE r.release_enabled=true AND r.released_at IS NOT NULL
  AND c.enabled_in_game=true
  AND r.reviewed_by='AIRLINERRA_GAME_AUTHORITY_AUTO_V1'
  AND r.release_reference LIKE 'AUTO_GAME_AUTHORITY_PHASE1_%'
  AND r.validity_game_days BETWEEN 35 AND 1095
  AND c.game_fee_usd>0 AND c.processing_game_days BETWEEN 1 AND 90
  AND c.permission_code IN (
   'AIR_OPERATOR_CERTIFICATE','DOMESTIC_TRAFFIC','THIRD_FOURTH_FREEDOM');
 IF auto_release_count=0 THEN
  RETURN jsonb_build_object('status','game_permission_issuance_not_released',
   'reviewed',0,'issued',0,'charged',false,'flightActivated',false);
 END IF;

 IF NOT pg_catalog.pg_try_advisory_xact_lock(583729,10019) THEN
  RETURN jsonb_build_object('status','game_permission_review_in_progress',
   'reviewed',0,'issued',0,'charged',false,'flightActivated',false);
 END IF;

 SELECT decrypted_secret INTO secret_value
 FROM vault.decrypted_secrets
 WHERE name='airlinerra_game_permission_auto_signing_v1';
 IF secret_value IS NULL OR length(secret_value)<64 THEN
  RETURN jsonb_build_object('status','game_permission_signing_key_unavailable',
   'reviewed',0,'issued',0,'charged',false,'flightActivated',false);
 END IF;
 -- App locks are taken *inside* the existing issuer, in airline-first
 -- order. Do not FOR UPDATE this list to avoid deadlocks.
 FOR application_row IN
  SELECT a.id,a.permission_code,a.due_game_date
  FROM airlinerra_game.section9_game_permission_applications_v1 a
  JOIN airlinerra_game.section9_game_permission_issuance_policy_v1 r
   ON r.permission_code=a.permission_code
  JOIN airlinerra_game.business_permission_catalog_v1 c
   ON c.permission_code=a.permission_code
  WHERE a.world_id=1 AND a.status='submitted'
   AND a.due_game_date<=game_day
   AND r.release_enabled=true AND r.released_at IS NOT NULL
   AND c.enabled_in_game=true
   AND r.reviewed_by='AIRLINERRA_GAME_AUTHORITY_AUTO_V1'
   AND r.release_reference LIKE 'AUTO_GAME_AUTHORITY_PHASE1_%'
   AND r.policy_revision=a.policy_revision
   AND r.validity_game_days=a.validity_game_days
   AND a.fee_usd=c.game_fee_usd
   AND c.permission_code IN (
    'AIR_OPERATOR_CERTIFICATE','DOMESTIC_TRAFFIC','THIRD_FOURTH_FREEDOM')
  ORDER BY a.due_game_date,a.id LIMIT p_limit
 LOOP
  event_id:='auto-game-permission-v1-'||
   application_row.id::text||'-'||to_char(game_day,'YYYYMMDD');
  payload:='airlinerra-game-permission-review-v1'||E'\n'||
   '1'||E'\n'||'1'||E'\n'||
   application_row.id::text||E'\n'||event_id||E'\n'||
   'approve'||E'\n'||game_day::text||E'\n'||
   'airlinerra-game-automatic-authority-v1';
  signature:=encode(extensions.hmac(
   pg_catalog.convert_to(payload,'UTF8'),
   pg_catalog.convert_to(secret_value,'UTF8'),
   'sha256'),'hex');

  decision_result:=airlinerra_game.section9_decide_game_permission_application_v1(
   application_row.id,event_id,'approve',
   'airlinerra-game-automatic-authority-v1',
   signature,game_day);
  reviewed:=reviewed+1;
  reason:=decision_result->>'status';
  IF reason='game_permission_issued' AND
     decision_result->>'chargedNow'='true' AND
     decision_result->>'licenceIssuedNow'='true' AND
     decision_result->>'ledgerPostedNow'='true' AND
     decision_result->>'flightActivated'='false'
  THEN issued:=issued+1;
  ELSIF reason='game_permission_decision_replayed' AND
    decision_result->>'chargedNow'='false' AND
    decision_result->>'ledgerPostedNow'='false'
  THEN ignored:=ignored+1;
  ELSIF reason IN (
   'blocked_unverified_world_or_game_day',
   'blocked_application_not_due_or_processed',
   'blocked_permission_policy_changed_or_disabled',
   'blocked_game_traffic_rights_policy_changed',
   'blocked_operator_licence_expired_or_revoked',
   'blocked_permission_already_valid',
   'blocked_insufficient_airline_cash'
  ) AND decision_result->>'chargedNow'='false'
   AND decision_result->>'ledgerPostedNow'='false'
  THEN
   blocked:=blocked+1;
   blocked_reasons:=jsonb_set(blocked_reasons,
    ARRAY[reason],
    to_jsonb(coalesce((blocked_reasons->>reason)::integer,0)+1),true);
  ELSE
   RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='GAME_PERMISSION_AUTO_REVIEW_UNSAFE_ISSUER_RESPONSE';
  END IF;
 END LOOP;
 RETURN jsonb_build_object(
  'status','game_permission_automatic_review_batch_completed',
  'gameDate',game_day,'reviewed',reviewed,'issued',issued,
  'alreadyReviewed',ignored,'blocked',blocked,
  'blockedReasons',blocked_reasons,
  'chargesAppliedOnlyAtIssuance',true,
  'flightActivated',false,'bookingsCreated',false,
  'movementRecorded',false,
  'signingSecretExposed',false);
END $function$
;

REVOKE ALL ON FUNCTION airlinerra_game.section9_review_due_game_permissions_auto_v1(integer)
 FROM PUBLIC,anon,authenticated,service_role;

-- Start the private scheduler. With release_enabled=false (default) this
-- produces zero decisions and zero charges; never flips release switches.
DO $scheduler_setup$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job
   WHERE jobname='airlinerra-game-permission-auto-review-v1')
 THEN
  PERFORM cron.schedule(
   'airlinerra-game-permission-auto-review-v1',
   '*/5 * * * *',
   'SELECT airlinerra_game.section9_review_due_game_permissions_auto_v1(50);');
 END IF;
END $scheduler_setup$;
