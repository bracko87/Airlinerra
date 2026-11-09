-- Rollback-only Section 9 signed certification event state machine acceptance.
-- Synthetic HMAC strings below are NOT real verifier evidence; this test
-- exercises private SQL state and audit semantics, never production approval.
BEGIN;
DO $test$
DECLARE a uuid;owner_id uuid;code text;home text;plane uuid;draft uuid;
 event1 text:='synthetic-operation-certification-event-0001';
 event2 text:='synthetic-operation-certification-event-0002';
 response jsonb;old_ledger bigint;old_movements bigint;old_positions bigint;
 old_drafts bigint;old_certs bigint;old_events bigint;old_preps bigint;
BEGIN
 IF has_function_privilege('anon',
 'airlinerra_game.section9_record_verified_certification_event_v1(uuid,uuid,integer,text,text,text,text,text,date,date,text)',
 'EXECUTE') OR has_function_privilege('authenticated',
 'airlinerra_game.section9_record_verified_certification_event_v1(uuid,uuid,integer,text,text,text,text,text,date,date,text)',
 'EXECUTE') OR has_table_privilege('authenticated',
 'airlinerra_game.section9_operational_certification_events_v1','INSERT')
 THEN RAISE EXCEPTION 'Untrusted browser can issue certificates';END IF;
 SELECT count(*) INTO old_ledger FROM airlinerra_game.airline_ledger;
 SELECT count(*) INTO old_movements FROM airlinerra_game.section9_operated_flight_movements_v1;
 SELECT count(*) INTO old_positions FROM airlinerra_game.section9_aircraft_current_position_v1;
 SELECT count(*) INTO old_drafts FROM airlinerra_game.airline_flight_schedule_drafts_v1;
 SELECT count(*) INTO old_certs FROM airlinerra_game.section9_schedule_operational_certifications_v1;
 SELECT count(*) INTO old_events FROM airlinerra_game.section9_operational_certification_events_v1;
 SELECT count(*) INTO old_preps FROM airlinerra_game.section9_schedule_activation_preparations_v1;
 SELECT id,owner_player_id,iata_code,home_airport_key INTO a,owner_id,code,home
 FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 IF NOT FOUND THEN RAISE EXCEPTION 'No World 1 test airline';END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(a,3,'S9-CERT-ROLLBACK','owned','in_service')
 RETURNING id INTO plane;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,reference_departure_utc,
  reference_arrival_utc,weekly_schedule,restriction_snapshot,
  created_by_player_id)
 VALUES(a,plane,3,code||'961',home,
  CASE WHEN home='OURAIRPORTS:2212' THEN 'OURAIRPORTS:4610'
  ELSE 'OURAIRPORTS:2212' END,
  '2000-01-03T09:00:00Z','2000-01-03T10:00:00Z',
  '[{"day":0,"time":"10:00"}]'::jsonb,'{}'::jsonb,owner_id)
 RETURNING id INTO draft;

 BEGIN
  PERFORM airlinerra_game.section9_record_verified_certification_event_v1(
   a,draft,3,'trusted_flight_execution','certify',event1,
   'source-test-operation-001','source-test-reviewer-001',
   DATE '2000-01-03',DATE '2000-02-05',repeat('a',64));
  RAISE EXCEPTION 'Stale schedule version accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN
  PERFORM airlinerra_game.section9_record_verified_certification_event_v1(
   a,draft,1,'operator_licence','certify',
   'synthetic-missing-operator-licence-001',
   'source-test-licence-001','source-test-reviewer-001',
   DATE '2000-01-03',DATE '2000-02-05',repeat('b',64));
  RAISE EXCEPTION 'Missing game operator evidence accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN
  PERFORM airlinerra_game.section9_record_verified_certification_event_v1(
   a,draft,1,'trusted_flight_execution','revoke',event2,
   'source-test-operation-002','source-test-reviewer-002',
   DATE '2000-01-03',DATE '2000-02-05',repeat('b',64));
  RAISE EXCEPTION 'Revocation without a certificate accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;

 -- Simulates a trusted source passing server-side HMAC verification.
 -- The private SQL function itself cannot validate the secret.
 response:=airlinerra_game.section9_record_verified_certification_event_v1(
  a,draft,1,'trusted_flight_execution','certify',event1,
  'source-test-operation-001','source-test-reviewer-001',
  DATE '2000-01-03',DATE '2000-02-05',repeat('a',64));
 IF response->>'status'<>'certification_event_recorded'
  OR response->>'flightActivated'<>'false'
  OR response->>'activationPreparationInvalidated'<>'true'
 THEN RAISE EXCEPTION 'Synthetic certification write failed: %',response;END IF;
 IF NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_schedule_operational_certifications_v1 c
  JOIN airlinerra_game.section9_operational_certification_events_v1 e
   ON e.event_id=c.last_verified_event_id AND e.action='certify'
  WHERE c.schedule_id=draft AND c.review_status='certified'
   AND c.last_verified_event_id=event1
 ) THEN RAISE EXCEPTION 'Latest signed event not linked to active certification';END IF;
 response:=airlinerra_game.section9_record_verified_certification_event_v1(
  a,draft,1,'trusted_flight_execution','certify',event1,
  'source-test-operation-001','source-test-reviewer-001',
  DATE '2000-01-03',DATE '2000-02-05',repeat('a',64));
 IF response->>'status'<>'certification_event_replayed'
  OR response->>'certificateChanged'<>'false'
 THEN RAISE EXCEPTION 'Duplicate event mutated certificate';END IF;
 BEGIN
  PERFORM airlinerra_game.section9_record_verified_certification_event_v1(
   a,draft,1,'trusted_flight_execution','certify',event1,
   'source-test-operation-001','source-test-reviewer-001',
   DATE '2000-01-03',DATE '2000-02-05',repeat('c',64));
  RAISE EXCEPTION 'Conflicting event ID accepted';
 EXCEPTION WHEN unique_violation THEN NULL;END;

 INSERT INTO airlinerra_game.section9_schedule_activation_preparations_v1(
  schedule_id,schedule_version,airline_id,aircraft_inventory_id,
  verified_game_date,certified_horizon_days,fingerprint_md5,release_reference)
 VALUES(draft,1,a,plane,DATE '2000-01-03',28,repeat('f',32),
 'synthetic-review-approval-001');
 response:=airlinerra_game.section9_record_verified_certification_event_v1(
  a,draft,1,'trusted_flight_execution','revoke',event2,
  'source-test-operation-002','source-test-reviewer-002',
  DATE '2000-01-03',DATE '2000-02-05',repeat('b',64));
 IF response->>'status'<>'certification_revoked'
  OR response->>'reviewStatus'<>'revoked'
  OR EXISTS(SELECT 1 FROM airlinerra_game.section9_schedule_activation_preparations_v1
     WHERE schedule_id=draft)
 THEN RAISE EXCEPTION 'Revocation did not invalidate preparation: %',response;END IF;
 response:=airlinerra_game.section9_record_verified_certification_event_v1(
  a,draft,1,'trusted_flight_execution','certify',event1,
  'source-test-operation-001','source-test-reviewer-001',
  DATE '2000-01-03',DATE '2000-02-05',repeat('a',64));
 IF response->>'status'<>'certification_event_replayed' OR
  (SELECT review_status FROM airlinerra_game.section9_schedule_operational_certifications_v1
   WHERE schedule_id=draft AND clearance_type='trusted_flight_execution')<>'revoked'
 THEN RAISE EXCEPTION 'Replay resurrected revoked approval';END IF;
 BEGIN
  UPDATE airlinerra_game.section9_operational_certification_events_v1
  SET source_reference='forbidden-audit-change'
  WHERE event_id=event1;
  RAISE EXCEPTION 'Audit event mutation succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 BEGIN
  DELETE FROM airlinerra_game.section9_operational_certification_events_v1
  WHERE event_id=event1;
  RAISE EXCEPTION 'Audit event deletion succeeded';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;

 IF (SELECT count(*) FROM airlinerra_game.airline_ledger)<>old_ledger
 OR (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)<>old_movements
 OR (SELECT count(*) FROM airlinerra_game.section9_aircraft_current_position_v1)<>old_positions
 OR (SELECT status FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE id=draft)<>'draft'
 OR (SELECT operationally_verified FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE id=draft)
 THEN RAISE EXCEPTION 'Certification audit accidentally operated a flight';END IF;
 RAISE NOTICE 'PASS: source guards, one-use event, immutable audit, revocation, no flights';
END $test$;
ROLLBACK;