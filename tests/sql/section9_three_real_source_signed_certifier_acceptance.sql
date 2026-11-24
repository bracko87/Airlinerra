-- Three independent real source verifiers -> deployed issuer with
-- per-authority synthetic Vault HMAC -> actual schedule-locked sink.
-- Both SQL functions are the EXACT live 2026-11-24 source snapshot.
-- The snapshot never contains actual user/airline identities or secrets.
\set ON_ERROR_STOP on
BEGIN;
DO $accept$
DECLARE
 a uuid:='11111111-1111-4111-8111-111111111111';
 sid uuid:='44444444-4444-4444-8444-444444444444';
 game_day date:='2026-11-24';
 kind text;
 res jsonb; old jsonb; ev record;
 key_string text;payload text;calc text;
 prefix text; expected_kind text; src text;
 raw_count integer; cert_count integer;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'ACTUAL_SIGNER_SINK_TEST_DISPOSABLE_ONLY';END IF;
 SELECT pg_get_functiondef(
 'airlinerra_game.section9_issue_queued_game_clearance_v1(uuid,uuid,integer,date,text)'::regprocedure) INTO src;
 IF position('vault.decrypted_secrets' IN src)=0
 OR position('extensions.hmac' IN src)=0
 OR position('section9_record_verified_certification_event_v1' IN src)=0
 OR position('current_user IS DISTINCT FROM ''postgres''' IN src)=0
 THEN RAISE EXCEPTION 'Not the actual Vault-backed signed certificate issuer';END IF;
 SELECT pg_get_functiondef(
 'airlinerra_game.section9_record_verified_certification_event_v1(uuid,uuid,integer,text,text,text,text,text,date,date,text)'::regprocedure) INTO src;
 IF position('FOR UPDATE OF sch' IN src)=0
 OR position('section9_verify_game_operator_licence_v1' IN src)=0
 OR position('section9_verify_game_route_traffic_rights_v1' IN src)=0
 OR position('section9_verify_slot_clearance_source_v1' IN src)=0
 OR position('SECTION9_CERTIFICATION_EVENT_REPLAY_CONFLICT' IN src)=0
 THEN RAISE EXCEPTION 'Atomic schedule-locked current sink was not installed';END IF;
 IF has_function_privilege('authenticated',
   'airlinerra_game.section9_issue_queued_game_clearance_v1(uuid,uuid,integer,date,text)','EXECUTE')
 OR has_function_privilege('service_role',
   'airlinerra_game.section9_issue_queued_game_clearance_v1(uuid,uuid,integer,date,text)','EXECUTE')
 OR has_function_privilege('anon',
   'airlinerra_game.section9_record_verified_certification_event_v1(uuid,uuid,integer,text,text,text,text,text,date,date,text)','EXECUTE')
 OR has_function_privilege('authenticated',
   'airlinerra_game.section9_record_verified_certification_event_v1(uuid,uuid,integer,text,text,text,text,text,date,date,text)','EXECUTE')
 THEN RAISE EXCEPTION 'Public/API role can bypass independent private certification';END IF;
 IF (SELECT COUNT(*) FROM airlinerra_game.section9_operational_certification_events_v1)<>0
 OR (SELECT COUNT(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1)<>0
 THEN RAISE EXCEPTION 'Synthetic pre-seeded certificates polluted the real-signed test';END IF;
 INSERT INTO airlinerra_game.section9_schedule_activation_preparations_v1
 VALUES(sid,1,'{"notApproved":true}'::jsonb);

 FOREACH kind IN ARRAY ARRAY['operator_licence','route_traffic_rights','airport_slot_capacity']
 LOOP
  res:=airlinerra_game.section9_issue_queued_game_clearance_v1(a,sid,1,game_day,kind);
  IF res->>'status'<>'certification_event_recorded'
   OR res->>'clearanceType' IS DISTINCT FROM kind
   OR res->>'replayed'<>'false' OR res->>'certificateChanged'<>'true'
   OR res->>'flightActivated'<>'false'
   OR res->>'bookingsCreated'<>'false' OR res->>'ledgerPosted'<>'false'
  THEN RAISE EXCEPTION 'Real signed issuance failed kind %: %',kind,res; END IF;
  SELECT * INTO ev FROM airlinerra_game.section9_operational_certification_events_v1
  WHERE event_id=res->>'eventId';
  IF NOT FOUND OR ev.schedule_id<>sid OR ev.airline_id<>a
   OR ev.schedule_version<>1 OR ev.clearance_type<>kind
   OR ev.valid_from_game_date<>game_day OR ev.valid_to_game_date<>game_day+28
   OR ev.action<>'certify' OR ev.verified_hmac_sha256 !~ '^[a-f0-9]{64}$'
  THEN RAISE EXCEPTION 'Signed certification audit row wrong for %',kind;END IF;
  key_string:=(SELECT decrypted_secret FROM vault.decrypted_secrets
     WHERE name='airlinerra_game_clearance_'||kind||'_v1');
  IF key_string IS NULL THEN RAISE EXCEPTION 'Synthetic test signing key not found';END IF;
  payload:=concat_ws(E'\n','airlinerra-verified-operations-certification-v1','1','1',
   a::text,sid::text,'1',kind,ev.source_kind,'certify',ev.event_id,
   ev.source_reference,ev.reviewer_reference,game_day::text,(game_day+28)::text);
  calc:=encode(extensions.hmac(convert_to(payload,'UTF8'),
    convert_to(key_string,'UTF8'),'sha256'),'hex');
  IF ev.verified_hmac_sha256 IS DISTINCT FROM calc
  THEN RAISE EXCEPTION 'Real per-type signing HMAC did not verify for %',kind;END IF;
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_schedule_operational_certifications_v1 c
     WHERE c.schedule_id=sid AND c.schedule_version=1 AND c.clearance_type=kind
       AND c.review_status='certified' AND c.source_reference=ev.source_reference
       AND c.last_verified_event_id=ev.event_id)
  THEN RAISE EXCEPTION 'Exact source fingerprint not version-bound to current certified row for %',kind;END IF;
  res:=airlinerra_game.section9_issue_queued_game_clearance_v1(a,sid,1,game_day,kind);
  IF res->>'status'<>'certification_event_replayed'
   OR res->>'replayed'<>'true'
   OR res->>'certificateChanged'<>'false'
   OR res->>'ledgerPosted'<>'false'
  THEN RAISE EXCEPTION 'Issuing same certification twice not idempotent for %: %',kind,res;END IF;
 END LOOP;
 IF (SELECT COUNT(*) FROM airlinerra_game.section9_operational_certification_events_v1)<>3
 OR (SELECT COUNT(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1)<>3
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_schedule_activation_preparations_v1 WHERE schedule_id=sid)
 THEN RAISE EXCEPTION 'Expected 3 independent approvals and invalidated activation preparation';END IF;

 -- Invalid replay with same event ID but different source fingerprint or
 -- HMAC must throw the actual sink's unique replay-conflict error.
 SELECT * INTO ev FROM airlinerra_game.section9_operational_certification_events_v1
 WHERE schedule_id=sid AND clearance_type='operator_licence';
 BEGIN
  PERFORM airlinerra_game.section9_record_verified_certification_event_v1(
    a,sid,1,'operator_licence','certify',ev.event_id,
    'game-operator-licence-v1-'||repeat('f',32),
    ev.reviewer_reference,game_day,game_day+28,repeat('f',64));
  RAISE EXCEPTION 'Conflicting certification replay wrongly accepted';
 EXCEPTION WHEN unique_violation THEN
  IF SQLERRM NOT LIKE '%SECTION9_CERTIFICATION_EVENT_REPLAY_CONFLICT%'
  THEN RAISE;END IF;
 END;

 -- Event ledger must remain immutable after issuing signed proof.
 BEGIN
  UPDATE airlinerra_game.section9_operational_certification_events_v1
  SET verified_hmac_sha256=repeat('f',64) WHERE event_id=ev.event_id;
  RAISE EXCEPTION 'Previously signed immutable event was overwritten';
 EXCEPTION WHEN insufficient_privilege THEN
  IF SQLERRM NOT LIKE '%SECTION9_CERTIFICATION_EVENT_LOG_IS_APPEND_ONLY%'
  THEN RAISE;END IF;
 END;

 -- Real issuer reads actual canonical AOC again. Changing the synthetic
 -- safety evidence after signing cannot issue a new operator certificate.
 UPDATE airlinerra_game.fixture_safety_rating SET game_rating=69 WHERE airline_id=a;
 res:=airlinerra_game.section9_issue_queued_game_clearance_v1(a,sid,1,game_day,'operator_licence');
 IF res->>'status'<>'game_clearance_source_blocked'
 THEN RAISE EXCEPTION 'After safety drop, old signed licence bypassed source issuer: %',res;END IF;
 UPDATE airlinerra_game.fixture_safety_rating SET game_rating=90 WHERE airline_id=a;

 -- Real slot verifier must reject deleted arrival slot. Sink must independently
 -- re-read and reject the PREVIOUS verified source fingerprint as stale.
 DELETE FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1
 WHERE schedule_id=sid AND direction='arrival';
 res:=airlinerra_game.section9_issue_queued_game_clearance_v1(a,sid,1,game_day,'airport_slot_capacity');
 IF res->>'status'<>'game_clearance_source_blocked'
 THEN RAISE EXCEPTION 'Missing airport arrival slot still signed: %',res;END IF;
 SELECT * INTO ev FROM airlinerra_game.section9_operational_certification_events_v1
 WHERE schedule_id=sid AND clearance_type='airport_slot_capacity';
 BEGIN
  PERFORM airlinerra_game.section9_record_verified_certification_event_v1(
    a,sid,1,'airport_slot_capacity','certify',
    'synthetic-new-slot-signature-after-change-v1',
    ev.source_reference,ev.reviewer_reference,game_day,game_day+28,
    repeat('f',64));
  RAISE EXCEPTION 'Existing source hash passed atomic slot recheck after reservation deletion';
 EXCEPTION WHEN insufficient_privilege THEN
  IF SQLERRM NOT LIKE '%SECTION9_CERTIFICATION_SOURCE_FACTS_NOT_VERIFIED%'
  THEN RAISE;END IF;
 END;
 INSERT INTO airlinerra_game.section6_weekly_airport_slot_reservations_v1
 VALUES(sid,'OURAIRPORTS:3993','terminal','arrival',5,714);

 -- Never grant a flight/finance clearance just because a signing key exists.
 FOREACH kind IN ARRAY ARRAY['trusted_flight_execution','commercial_finance']
 LOOP
  res:=airlinerra_game.section9_issue_queued_game_clearance_v1(a,sid,1,game_day,kind);
  IF res->>'status'<>'game_clearance_source_blocked'
  THEN RAISE EXCEPTION 'Unreleased % certificate was issued: %',kind,res;END IF;
 END LOOP;

 -- Changing schedule version invalidates current authority. An old
 -- idempotent replay remains harmless, but new v1 issuance must be denied.
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1 SET version=2 WHERE id=sid;
 res:=airlinerra_game.section9_issue_queued_game_clearance_v1(a,sid,1,game_day,'operator_licence');
 IF res->>'status'<>'game_clearance_source_blocked'
 THEN RAISE EXCEPTION 'Old schedule version reauthorized: %',res;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_operational_certification_events_v1)<>3
 OR (SELECT count(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1)<>3
 OR EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1
    WHERE status='active' OR operationally_verified)
 THEN RAISE EXCEPTION 'Negative cases added certificates or activated flight';END IF;

 RAISE NOTICE 'PASS REAL issuer+sink: 3 unique live-source BEG-ZAG certificates with independent synthetic-key HMACs, exact schedule/version/source binding, replay no-op/conflict denial, audit immutability, atomic source drift failure, safety and missing-slot fail-closed, no execution/finance grant.';
END $accept$;
ROLLBACK;

DO $clean$ BEGIN
 IF (SELECT count(*) FROM airlinerra_game.section9_operational_certification_events_v1)<>0
 OR (SELECT count(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1)<>0
 THEN RAISE EXCEPTION 'Disposable signed-certification transaction did not roll back';END IF;
END $clean$;
