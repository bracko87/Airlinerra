-- Rollback-only World 1 permission application/settlement acceptance.
-- All test application records and clock edits disappear on ROLLBACK.
BEGIN;
DO $test$
DECLARE
 airline_id uuid;player_id uuid;fee_before numeric;
 ledger_before bigint;apps_before bigint;reviews_before bigint;
 licences_before bigint;routes_before bigint;movement_before bigint;
 cash_after numeric;application_id uuid;request_id uuid:=gen_random_uuid();
 verdict jsonb;event_id text:='rollback-signed-game-permission-review-001';
BEGIN
 SELECT a.id,a.owner_player_id,a.cash_usd INTO airline_id,player_id,fee_before
 FROM airlinerra_game.airlines a WHERE a.world_id=1 LIMIT 1;
 IF airline_id IS NULL THEN RAISE EXCEPTION 'No airline fixture';END IF;
 SELECT count(*) INTO ledger_before FROM airlinerra_game.airline_ledger;
 SELECT count(*) INTO apps_before
 FROM airlinerra_game.section9_game_permission_applications_v1;
 SELECT count(*) INTO reviews_before
 FROM airlinerra_game.section9_game_permission_review_events_v1;
 SELECT count(*) INTO licences_before
 FROM airlinerra_game.section9_operator_licence_evidence_v1;
 SELECT count(*) INTO routes_before
 FROM airlinerra_game.section9_route_operating_permission_evidence_v1;
 SELECT count(*) INTO movement_before
 FROM airlinerra_game.section9_operated_flight_movements_v1;
 IF has_table_privilege('anon',
  'airlinerra_game.section9_game_permission_applications_v1','SELECT')
  OR has_table_privilege('authenticated',
  'airlinerra_game.section9_game_permission_review_events_v1','INSERT')
  OR has_function_privilege('authenticated',
  'airlinerra_game.section9_decide_game_permission_application_v1(uuid,text,text,text,text,date)','EXECUTE')
  OR has_function_privilege('anon',
  'airlinerra_game.section9_submit_game_permission_application_v1(uuid,uuid,uuid,text,text,text,text)','EXECUTE')
 THEN RAISE EXCEPTION 'Application system exposed to browser';END IF;

 verdict:=airlinerra_game.section9_submit_game_permission_application_v1(
  player_id,airline_id,request_id,'AIR_OPERATOR_CERTIFICATE',NULL,NULL,NULL);
 IF verdict->>'status'<>'blocked_unverified_world_or_game_day'
 OR verdict->>'charged'<>'false'
 THEN RAISE EXCEPTION 'Closed game unexpectedly accepted permission application: %',verdict;END IF;
 BEGIN
  PERFORM airlinerra_game.section9_submit_game_permission_application_v1(
   '11111111-1111-4111-8111-111111111111',airline_id,
   gen_random_uuid(),'AIR_OPERATOR_CERTIFICATE',NULL,NULL,NULL);
  RAISE EXCEPTION 'Unowned airline accepted a licence request';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;

 -- A fully signed game day inside the transaction is STILL not a
 -- business policy release: disabled catalogue must block charging.
 UPDATE public.airlinerra_game_worlds SET state='active',
  opens_at=clock_timestamp()-interval '1 day' WHERE id=1;
 UPDATE airlinerra_game.holding_world_clock_v1
 SET confirmed_game_date=DATE '2000-01-08',
  clock_source='authoritative_game_engine',
  engine_proof_ref='ROLLBACK_GAME_PERMISSIONS_TEST_20000108',
  last_verified_at=clock_timestamp() WHERE world_id=1;
 INSERT INTO airlinerra_game.section9_verified_game_tick_receipts_v1(
  world_id,game_date,engine_event_id,event_hmac_sha256,dispatch_kind)
 VALUES(1,DATE '2000-01-08','rollback-game-permission-20000108',
 repeat('f',64),'no_verified_flights');
 verdict:=airlinerra_game.section9_submit_game_permission_application_v1(
  player_id,airline_id,request_id,'AIR_OPERATOR_CERTIFICATE',NULL,NULL,NULL);
 IF verdict->>'status'<>'blocked_game_permission_issuance_disabled' OR
  verdict->>'charged'<>'false'
 THEN RAISE EXCEPTION 'Disabled permission catalogue bypassed: %',verdict;END IF;

 -- Review tests use a private synthetic "submitted" row rather than
 -- falsely enabling a real user permission in production.
 INSERT INTO airlinerra_game.section9_game_permission_applications_v1(
  airline_id,applicant_player_id,request_key,permission_code,scope_key,
  jurisdiction_iso2,applied_game_date,due_game_date,
  policy_revision,fee_usd,validity_game_days)
 VALUES(airline_id,player_id,request_id,'AIR_OPERATOR_CERTIFICATE',
  'operator:RS','RS',DATE '2000-01-01',DATE '2000-01-05',
  1,250.00,365) RETURNING id INTO application_id;
 verdict:=airlinerra_game.section9_submit_game_permission_application_v1(
  player_id,airline_id,request_id,'AIR_OPERATOR_CERTIFICATE',NULL,NULL,NULL);
 IF verdict->>'status'<>'permission_application_replayed'
 OR verdict->>'applicationId'<>application_id::text
 THEN RAISE EXCEPTION 'Request idempotency failed: %',verdict;END IF;

 verdict:=airlinerra_game.section9_decide_game_permission_application_v1(
  application_id,'rollback-fake-approval-with-disabled-policy-0001',
  'approve','independent-review-synthetic-001',
  repeat('a',64),DATE '2000-01-08');
 IF verdict->>'status'<>'blocked_permission_policy_changed_or_disabled'
 OR verdict->>'chargedNow'<>'false'
 THEN RAISE EXCEPTION 'Disabled policy approval charged airline: %',verdict;END IF;
 verdict:=airlinerra_game.section9_decide_game_permission_application_v1(
  application_id,event_id,'reject',
  'independent-review-synthetic-001',
  repeat('b',64),DATE '2000-01-08');
 IF verdict->>'status'<>'game_permission_rejected'
 OR verdict->>'chargedNow'<>'false'
 OR verdict->>'ledgerPostedNow'<>'false'
 THEN RAISE EXCEPTION 'Signed rejection did not record no-charge state: %',verdict;END IF;
 verdict:=airlinerra_game.section9_decide_game_permission_application_v1(
  application_id,event_id,'reject',
  'independent-review-synthetic-001',
  repeat('b',64),DATE '2000-01-08');
 IF verdict->>'status'<>'game_permission_decision_replayed'
 OR verdict->>'chargedNow'<>'false'
 THEN RAISE EXCEPTION 'Replay charged airline or failed idempotence: %',verdict;END IF;
 BEGIN
  PERFORM airlinerra_game.section9_decide_game_permission_application_v1(
   application_id,event_id,'reject',
   'independent-review-synthetic-001',
   repeat('c',64),DATE '2000-01-08');
  RAISE EXCEPTION 'Conflicting review event signature accepted';
 EXCEPTION WHEN unique_violation THEN NULL;END;
 verdict:=airlinerra_game.section9_decide_game_permission_application_v1(
  application_id,'rollback-new-approval-after-rejection-0001',
  'approve','independent-review-synthetic-001',
  repeat('c',64),DATE '2000-01-08');
 IF verdict->>'status'<>'blocked_application_not_due_or_processed'
 THEN RAISE EXCEPTION 'Rejected application reapproved: %',verdict;END IF;

 verdict:=airlinerra_game.section9_expire_game_permissions_batch_v1(100);
 IF verdict->>'status'<>'game_permission_expiry_batch_completed'
 OR verdict->>'expired'<>'0'
 THEN RAISE EXCEPTION 'Unissued game permission expired incorrectly: %',verdict;END IF;
 SELECT cash_usd INTO cash_after FROM airlinerra_game.airlines WHERE id=airline_id;
 IF cash_after IS DISTINCT FROM fee_before OR
  (SELECT count(*) FROM airlinerra_game.airline_ledger)<>ledger_before OR
  (SELECT count(*) FROM airlinerra_game.section9_operator_licence_evidence_v1)<>licences_before OR
  (SELECT count(*) FROM airlinerra_game.section9_route_operating_permission_evidence_v1)<>routes_before OR
  (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)<>movement_before OR
  (SELECT count(*) FROM airlinerra_game.section9_game_permission_review_events_v1)<>reviews_before+1 OR
  (SELECT count(*) FROM airlinerra_game.section9_game_permission_applications_v1)<>apps_before+1
 THEN RAISE EXCEPTION 'Permission workflow wrote unexpected money, licences or flight';END IF;
 RAISE NOTICE 'PASS: closed world, ownership, disabled catalog, no-charge rejection, replay, review conflict, no flights';
END $test$;
ROLLBACK;