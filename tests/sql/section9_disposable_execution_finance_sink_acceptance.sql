-- The ACTUAL original signed-certification function, amended only by
-- the exact production migrations, runs against a disposable PG17 DB.
\set ON_ERROR_STOP on
DO $accept$
DECLARE
 a uuid:='11111111-1111-4111-8111-111111111111';
 s uuid:='44444444-4444-4444-8444-444444444444';
 day date:=DATE '2026-11-20';until_day date:=DATE '2026-12-18';
 kind text;ref text;reviewer text;event_name text;
 snapshot jsonb;receipt jsonb;replayed jsonb;was_blocked boolean;
 initial_ref text;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'NOT_ISOLATED_CERTIFICATION_TEST';END IF;
 FOREACH kind IN ARRAY ARRAY['trusted_flight_execution','commercial_finance'] LOOP
  snapshot:=airlinerra_game.section9_execution_finance_source_snapshot_v1(
   a,s,1,day,kind);
  IF snapshot->>'candidateReady'<>'true'
  THEN RAISE EXCEPTION 'Missing candidate source: %',snapshot;END IF;
  ref:=snapshot->>'sourceReference';
  initial_ref:=ref;
  reviewer:=CASE kind WHEN 'trusted_flight_execution'
    THEN 'independent-trusted-flight-execution-authority-v1'
    ELSE 'independent-commercial-finance-authority-v1' END;
  event_name:='real-disposable-'||kind||'-signed-20261120';
  -- A valid HMAC hex has already been validated by private Node ingress.
  -- This SQL test explicitly exercises the DB source recheck and audit,
  -- not HMAC verification (covered by the isolated Node tests).
  receipt:=airlinerra_game.section9_record_verified_certification_event_v1(
   a,s,1,kind,'certify',event_name,ref,reviewer,day,until_day,
   repeat(CASE kind WHEN 'trusted_flight_execution' THEN 'a' ELSE 'b' END,64));
  IF receipt->>'status'<>'certification_event_recorded'
   OR receipt->>'certificateChanged'<>'true'
   OR receipt->>'ledgerPosted'<>'false'
  THEN RAISE EXCEPTION 'Actual signed sink did not commit %: %',kind,receipt;END IF;
  replayed:=airlinerra_game.section9_record_verified_certification_event_v1(
   a,s,1,kind,'certify',event_name,ref,reviewer,day,until_day,
   repeat(CASE kind WHEN 'trusted_flight_execution' THEN 'a' ELSE 'b' END,64));
  IF replayed->>'status'<>'certification_event_replayed'
   OR replayed->>'certificateChanged'<>'false'
  THEN RAISE EXCEPTION 'Exact replay not idempotent %: %',kind,replayed;END IF;
  IF (SELECT count(*) FROM
    airlinerra_game.section9_operational_certification_events_v1
    WHERE clearance_type=kind)<>1
  THEN RAISE EXCEPTION 'Duplicate immutable audit event %',kind;END IF;
  IF (SELECT count(*) FROM
    airlinerra_game.section9_schedule_operational_certifications_v1
    WHERE clearance_type=kind AND review_status='certified')<>1
  THEN RAISE EXCEPTION 'Missing saved certificate for %',kind;END IF;
  -- An otherwise valid old fingerprint is invalidated by new route facts.
  UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
   SET destination_airport_key='OURAIRPORTS:9999' WHERE id=s;
  was_blocked:=false;
  BEGIN
   PERFORM airlinerra_game.section9_record_verified_certification_event_v1(
    a,s,1,kind,'certify',event_name||'-tamper-route',initial_ref,
    reviewer,day,until_day,repeat('c',64));
  EXCEPTION WHEN SQLSTATE '42501' THEN was_blocked:=true;END;
  IF NOT was_blocked THEN RAISE EXCEPTION 'Changed route allowed original fingerprint %',kind;END IF;
  UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
   SET destination_airport_key='OURAIRPORTS:2218' WHERE id=s;
  -- A revoked prior independent route approval must block a NEW cert.
  UPDATE airlinerra_game.section9_schedule_operational_certifications_v1
   SET review_status='revoked'
   WHERE schedule_id=s AND clearance_type='route_traffic_rights';
  was_blocked:=false;
  BEGIN
   PERFORM airlinerra_game.section9_record_verified_certification_event_v1(
    a,s,1,kind,'certify',event_name||'-revoked-rights',initial_ref,
    reviewer,day,until_day,repeat('c',64));
  EXCEPTION WHEN SQLSTATE '42501' THEN was_blocked:=true;END;
  IF NOT was_blocked THEN RAISE EXCEPTION 'Revoked traffic rights accepted %',kind;END IF;
  UPDATE airlinerra_game.section9_schedule_operational_certifications_v1
   SET review_status='certified'
   WHERE schedule_id=s AND clearance_type='route_traffic_rights';
  -- Changing release-source proof must prevent old evidence replay
  -- through a DIFFERENT event ID even with correctly shaped HMAC hex.
  UPDATE airlinerra_game.section9_fuel_and_settlement_release_policy_v1
   SET settlement_writer_evidence='changed-disposable-settlement-proof-20261120'
   WHERE world_id=1;
  was_blocked:=false;
  BEGIN
   PERFORM airlinerra_game.section9_record_verified_certification_event_v1(
    a,s,1,kind,'certify',event_name||'-changed-evidence',initial_ref,
    reviewer,day,until_day,repeat('d',64));
  EXCEPTION WHEN SQLSTATE '42501' THEN was_blocked:=true;END;
  IF NOT was_blocked THEN RAISE EXCEPTION 'Changed settlement proof accepted %',kind;END IF;
  UPDATE airlinerra_game.section9_fuel_and_settlement_release_policy_v1
   SET settlement_writer_evidence='disposable-settlement-writer-evidence-2026'
   WHERE world_id=1;
 END LOOP;
 -- No invalid certification attempt should persist an append-only event.
 IF (SELECT count(*) FROM airlinerra_game.section9_operational_certification_events_v1
     WHERE clearance_type IN ('trusted_flight_execution','commercial_finance'))<>2
 OR (SELECT count(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1
     WHERE clearance_type IN ('trusted_flight_execution','commercial_finance'))<>2
 THEN RAISE EXCEPTION 'Mutation leaked after denied certification';END IF;
 IF EXISTS (SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1
  WHERE status<>'draft' OR operationally_verified)
 THEN RAISE EXCEPTION 'Certification activated a flight';END IF;
 RAISE NOTICE 'PASS: actual signed sink wrote two certs with matching live-source references; replay idempotent; tamper/revocation/release mutations denied before insert; no flight activation';
END $accept$;
