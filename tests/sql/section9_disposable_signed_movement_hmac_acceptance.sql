-- Disposable-only verified HMAC tests against the ACTUAL reviewed movement
-- procedure, not an imitation. The same CI suite already installed the
-- original function and its exact-source FOR SHARE occurrence patch.
-- No movement is authorized or inserted in this test.
\set ON_ERROR_STOP on
DO $guard$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regnamespace('vault') IS NOT NULL
 OR to_regnamespace('extensions') IS NOT NULL
 THEN RAISE EXCEPTION 'SIGNED_HMAC_TEST_REQUIRES_ISOLATED_DISPOSABLE_DB';END IF;
END $guard$;
CREATE SCHEMA vault;
CREATE SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA extensions;
CREATE VIEW vault.decrypted_secrets AS
 SELECT 'airlinerra_operated_flight_auto_signing_v1'::text AS name,
 repeat('t',80)::text AS decrypted_secret;

-- Ensure the test is fail-closed prior to flight-event release, so
-- valid signatures reach only the release check, not any real movement.
UPDATE airlinerra_game.section9_activation_release_policy_v1
 SET release_state='disabled',enabled_at=NULL WHERE world_id=1;

DO $signature_tests$
DECLARE
 v_airline uuid:='11111111-1111-4111-8111-111111111111';
 v_schedule uuid:='eeeeeeee-1111-4111-8111-eeeeeeeeeeee';
 v_event timestamptz:='2026-11-21T16:00:00Z';
 v_event_id text:='isolated-signed-event-20261123';
 v_payload text;
 v_signature text;
 v_result jsonb;
 invalid_rejected boolean:=false;
 bad_event_id text:='isolated-bad-event-20261123';
BEGIN
 v_payload:=concat_ws(E'\n',
  'airlinerra-operated-game-event-v1','1',v_airline::text,
  v_schedule::text,'1','2026-11-21','1','departed',
  to_char(v_event AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS"Z"'),
  v_event_id);
 v_signature:=encode(extensions.hmac(
  convert_to(v_payload,'UTF8'),
  convert_to(repeat('t',80),'UTF8'),'sha256'),'hex');

 BEGIN
  PERFORM airlinerra_game.section9_record_signed_operated_flight_movement_v1(
   v_airline,v_schedule,1,'2026-11-21',1,'departed',v_event,
   bad_event_id,v_signature);
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM='SECTION9_MOVEMENT_EVENT_SIGNATURE_INVALID'
  THEN invalid_rejected:=true; ELSE RAISE; END IF;
 END;
 IF NOT invalid_rejected THEN
  RAISE EXCEPTION 'Original signed movement accepted a mismatched HMAC';
 END IF;

 v_result:=airlinerra_game.section9_record_signed_operated_flight_movement_v1(
   v_airline,v_schedule,1,'2026-11-21',1,'departed',
   v_event,v_event_id,v_signature);
 IF v_result->>'status'<>'blocked_unreleased_movement_engine'
 OR v_result->>'movementRecorded'<>'false'
 THEN RAISE EXCEPTION 'Signed valid HMAC did not reach safe release gate: %',v_result;END IF;

 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1
  WHERE flight_occurrence_id=v_schedule::text||':2026-11-21:1')
 THEN RAISE EXCEPTION 'HMAC validation wrote unapproved flight movement';END IF;

 RAISE NOTICE 'PASS real signed movement rejects wrong HMAC; accepts correct HMAC only up to disabled release gate';
END $signature_tests$;
