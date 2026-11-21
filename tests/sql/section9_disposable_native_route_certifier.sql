-- Real certification-sink and snapshot acceptance with real per-type HMAC.
\set ON_ERROR_STOP on
CREATE SCHEMA extensions;
CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
CREATE SCHEMA vault;
CREATE TABLE vault.decrypted_secrets(name text PRIMARY KEY,decrypted_secret text NOT NULL);
INSERT INTO vault.decrypted_secrets SELECT 'airlinerra_game_clearance_'||kind||'_v1',repeat(kind,8)
 FROM unnest(ARRAY['operator_licence','route_traffic_rights','airport_slot_capacity','trusted_flight_execution','commercial_finance']) AS kind;
DO $test$
DECLARE a uuid:='11111111-1111-4111-8111-111111111111';
 s uuid:='44444444-4444-4444-8444-444444444444';
 d date:='2026-11-20';kind text;r jsonb;e record;secret text;expected text;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres' THEN RAISE EXCEPTION 'DISPOSABLE_ONLY';END IF;
 UPDATE airlinerra_game.section9_activation_release_policy_v1 SET release_state='paused';
 r:=airlinerra_game.section9_auto_certify_queued_roundtrips_v1(10);
 IF r->>'status' IS DISTINCT FROM 'game_clearance_release_blocked' THEN RAISE EXCEPTION 'RELEASE_GUARD: %',r;END IF;
 UPDATE airlinerra_game.section9_activation_release_policy_v1 SET release_state='enabled';
 IF has_function_privilege('authenticated','airlinerra_game.section9_issue_queued_game_clearance_v1(uuid,uuid,integer,date,text)','EXECUTE')
 OR has_function_privilege('anon','airlinerra_game.section9_auto_certify_queued_roundtrips_v1(integer)','EXECUTE')
 THEN RAISE EXCEPTION 'PUBLIC_AUTHORITY_ACCESS';END IF;
 FOREACH kind IN ARRAY ARRAY['trusted_flight_execution','commercial_finance'] LOOP
  r:=airlinerra_game.section9_issue_queued_game_clearance_v1(a,s,1,d,kind);
  IF r->>'status' IS DISTINCT FROM 'certification_event_recorded' THEN RAISE EXCEPTION 'NATIVE_SIGNER_FAILED: %',r;END IF;
  SELECT * INTO e FROM airlinerra_game.section9_operational_certification_events_v1 WHERE event_id=r->>'eventId';
  SELECT decrypted_secret INTO secret FROM vault.decrypted_secrets WHERE name='airlinerra_game_clearance_'||kind||'_v1';
  expected:=encode(extensions.hmac(convert_to(concat_ws(E'\n','airlinerra-verified-operations-certification-v1','1','1',a::text,s::text,'1',kind,e.source_kind,'certify',e.event_id,e.source_reference,e.reviewer_reference,d::text,(d+28)::text),'UTF8'),convert_to(secret,'UTF8'),'sha256'),'hex');
  IF e.verified_hmac_sha256 IS DISTINCT FROM expected THEN RAISE EXCEPTION 'HMAC_MISMATCH';END IF;
  r:=airlinerra_game.section9_issue_queued_game_clearance_v1(a,s,1,d,kind);
  IF r->>'status' IS DISTINCT FROM 'certification_event_replayed' THEN RAISE EXCEPTION 'REPLAY_FAILED: %',r;END IF;
 END LOOP;
 UPDATE airlinerra_game.section9_schedule_operational_certifications_v1 SET review_status='revoked' WHERE clearance_type='route_traffic_rights';
 r:=airlinerra_game.section9_issue_queued_game_clearance_v1(a,s,1,d,'commercial_finance');
 IF r->>'status' IS DISTINCT FROM 'game_clearance_source_blocked' THEN RAISE EXCEPTION 'REVOKED_RIGHTS_ACCEPTED: %',r;END IF;
 RAISE NOTICE 'PASS: private native signer created real HMAC with distinct keys, atomic sink rechecked both source proofs, replay safe, revoked rights blocked, release and access protected.';
END $test$;
