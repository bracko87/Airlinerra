-- Executed AFTER six independent pg17 connections race the SAME
-- genuine signed operator-licence event for the same synthetic BEG->ZAG
-- schedule and source evidence. Intentional local persistence is disposed
-- with the whole GitHub Actions database service after CI.
\set ON_ERROR_STOP on
DO $race$
DECLARE
 sid uuid:='44444444-4444-4444-8444-444444444444';
 airline uuid:='11111111-1111-4111-8111-111111111111';
 ev record;
 receipt jsonb;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'SIGNATURE_CONCURRENCY_REQUIRES_DISPOSABLE_DATABASE';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_operational_certification_events_v1)<>1
 OR (SELECT count(*) FROM airlinerra_game.section9_operational_certification_events_v1
   WHERE schedule_id=sid AND schedule_version=1
   AND clearance_type='operator_licence' AND action='certify')<>1
 OR (SELECT count(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1
   WHERE schedule_id=sid AND schedule_version=1 AND clearance_type='operator_licence'
   AND review_status='certified')<>1
 THEN RAISE EXCEPTION 'Six concurrent issuer calls duplicated or dropped signed event';END IF;
 SELECT * INTO ev FROM airlinerra_game.section9_operational_certification_events_v1;
 IF NOT FOUND
 OR ev.valid_from_game_date<>'2026-11-24'
 OR ev.valid_to_game_date<>'2026-12-22'
 OR ev.verified_hmac_sha256 IS DISTINCT FROM
  encode(extensions.hmac(
  convert_to(concat_ws(E'\n','airlinerra-verified-operations-certification-v1','1','1',
  airline::text,sid::text,'1','operator_licence',ev.source_kind,'certify',ev.event_id,
  ev.source_reference,ev.reviewer_reference,'2026-11-24','2026-12-22'),'UTF8'),
  convert_to((SELECT decrypted_secret FROM vault.decrypted_secrets
     WHERE name='airlinerra_game_clearance_operator_licence_v1'),'UTF8'),'sha256'),'hex')
 THEN RAISE EXCEPTION 'Concurrent signed event invalid identity/version/HMAC';END IF;
 receipt:=airlinerra_game.section9_issue_queued_game_clearance_v1(
  airline,sid,1,'2026-11-24','operator_licence');
 IF receipt->>'status'<>'certification_event_replayed'
 OR receipt->>'certificateChanged'<>'false'
 OR receipt->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'Sequential postrace repeat incorrectly inserted another certificate: %',receipt;END IF;
 RAISE NOTICE 'PASS: SIX concurrent real issuer/sink calls serialized into ONE signed operator event and ONE version-bound certificate; one recorded, five replay, independent HMAC valid.';
END $race$;
