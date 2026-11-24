-- Exact currently deployed GAME slot authority proof, with source-snapshotted
-- BEG-ZAG (pass) and BEG-MUC (unverified noise; deny) weekly Section5 evidence.
-- Fake reservation writers are *only inputs* to unmodified real authority.
-- All test changes rolled back; no certificates/HMAC/player money produced.
\set ON_ERROR_STOP on
BEGIN;
DO $test$
DECLARE
 a uuid:='11111111-1111-4111-8111-111111111111';
 zag uuid:='44444444-4444-4444-8444-444444444444';
 muc uuid:='55555555-5555-4555-8555-555555555555';
 d date:='2026-11-24';
 res jsonb; previous jsonb; src text;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'REAL_SLOT_SOURCE_TEST_DISPOSABLE_ONLY';END IF;
 SELECT pg_get_functiondef('airlinerra_game.section9_verify_slot_clearance_source_v1(uuid,uuid,integer,date)'::regprocedure) INTO src;
 IF position('section9_game_route_restrictions_valid_v1' IN src)=0
 OR position('OR (restriction_check->>''needsReview'') IS DISTINCT FROM ''false''' IN src)>0
 OR position('section6_weekly_airport_slot_reservations_v1' IN src)=0
 OR position('section6_weekly_slot_preflight_v1' IN src)=0
 THEN RAISE EXCEPTION 'Wrong or historical slot verifier version installed';END IF;

 res:=airlinerra_game.section9_verify_slot_clearance_source_v1(a,zag,1,d);
 IF res->>'status'<>'verified_game_airport_slots'
 OR res->>'verified'<>'true' OR res->>'readOnly'<>'true'
 OR res->>'sourceKind'<>'verified_airport_slot_engine'
 OR res->>'validThroughGameDate'<>'2026-12-22'
 OR res->>'proposedSlots'<>'2' OR res->>'reservedSlots'<>'2'
 OR res->>'ledgerPosted'<>'false' OR res->>'flightActivated'<>'false'
 OR coalesce(res->>'proofFingerprint','') !~ '^[a-f0-9]{32}$'
 THEN RAISE EXCEPTION 'Actual slot verifier failed source-backed GAME BEG-ZAG: %',res;END IF;

 res:=airlinerra_game.section9_verify_slot_clearance_source_v1(a,muc,1,d);
 IF res->>'status'<>'blocked_slot_clearance_evidence'
 OR res->>'verified'<>'false'
 OR NOT(res->'blockers' ? 'UNRESOLVED_AIRPORT_RESTRICTION')
 OR res->>'reservedSlots'<>'2'
 THEN RAISE EXCEPTION 'Actual slot verifier allowed unverified MUC noise Chapter: %',res;END IF;

 -- Authorized airport slots demand exact reference-time/weekday/stand rows.
 DELETE FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1
 WHERE schedule_id=zag AND direction='arrival';
 res:=airlinerra_game.section9_verify_slot_clearance_source_v1(a,zag,1,d);
 IF res->>'status'<>'blocked_slot_clearance_evidence'
 OR NOT(res->'blockers' ? 'RECURRING_SLOT_RESERVATIONS_MISMATCH')
 THEN RAISE EXCEPTION 'Missing arrival slot was accepted: %',res;END IF;
 INSERT INTO airlinerra_game.section6_weekly_airport_slot_reservations_v1
 VALUES(zag,'OURAIRPORTS:3993','terminal','arrival',5,714);

 UPDATE airlinerra_game.fixture_slot_availability SET available=false WHERE singleton;
 res:=airlinerra_game.section9_verify_slot_clearance_source_v1(a,zag,1,d);
 IF res->>'status'<>'blocked_slot_clearance_evidence'
 OR NOT(res->'blockers' ? 'AIRPORT_CAPACITY_RECHECK_FAILED')
 THEN RAISE EXCEPTION 'Full/overbooked stand capacity was approved: %',res;END IF;
 UPDATE airlinerra_game.fixture_slot_availability SET available=true WHERE singleton;

 UPDATE airlinerra_game.airport_unified_operations_v1
 SET game_runway_length_m=500 WHERE airport_key='OURAIRPORTS:3993';
 res:=airlinerra_game.section9_verify_slot_clearance_source_v1(a,zag,1,d);
 IF res->>'status'<>'blocked_slot_clearance_evidence'
 OR NOT(res->'blockers' ? 'UNRESOLVED_AIRPORT_RESTRICTION')
 THEN RAISE EXCEPTION 'Too short game runway got GAME clearance: %',res;END IF;
 UPDATE airlinerra_game.airport_unified_operations_v1
 SET game_runway_length_m=3251.9 WHERE airport_key='OURAIRPORTS:3993';

 SELECT weekly_screen INTO previous FROM airlinerra_game.fixture_source_route_game_evidence
 WHERE destination_code='ZAG';
 UPDATE airlinerra_game.fixture_source_route_game_evidence
 SET weekly_screen=jsonb_set(weekly_screen,
 '{occurrences,0,destination,simpleNightNoise,needsReview}','true'::jsonb)
 WHERE destination_code='ZAG';
 res:=airlinerra_game.section9_verify_slot_clearance_source_v1(a,zag,1,d);
 IF res->>'status'<>'blocked_slot_clearance_evidence'
 OR NOT(res->'blockers' ? 'UNRESOLVED_AIRPORT_RESTRICTION')
 THEN RAISE EXCEPTION 'Unverified Section5 game noise chapter passed: %',res;END IF;
 UPDATE airlinerra_game.fixture_source_route_game_evidence
 SET weekly_screen=previous WHERE destination_code='ZAG';

 UPDATE airlinerra_game.fixture_source_route_game_evidence
 SET weekly_screen=jsonb_set(weekly_screen,'{gameHardBlocked}','true'::jsonb)
 WHERE destination_code='ZAG';
 res:=airlinerra_game.section9_verify_slot_clearance_source_v1(a,zag,1,d);
 IF res->>'status'<>'blocked_slot_clearance_evidence'
 OR NOT(res->'blockers' ? 'UNRESOLVED_AIRPORT_RESTRICTION')
 THEN RAISE EXCEPTION 'Hard night/airport-game restriction bypassed: %',res;END IF;
 UPDATE airlinerra_game.fixture_source_route_game_evidence
 SET weekly_screen=previous WHERE destination_code='ZAG';

 UPDATE airlinerra_game.holding_world_clock_v1 SET confirmed_game_date='2026-11-23';
 res:=airlinerra_game.section9_verify_slot_clearance_source_v1(a,zag,1,d);
 IF res->>'status'<>'blocked_unverified_world_or_game_day'
 THEN RAISE EXCEPTION 'Stale game-day receipt used for source clearance: %',res;END IF;
 UPDATE airlinerra_game.holding_world_clock_v1 SET confirmed_game_date=d;

 res:=airlinerra_game.section9_verify_slot_clearance_source_v1(a,zag,2,d);
 IF res->>'status'<>'blocked_stale_or_non_draft_schedule'
 THEN RAISE EXCEPTION 'Wrong schedule-version slot authority approved: %',res;END IF;

 res:=airlinerra_game.section9_verify_slot_clearance_source_v1(a,zag,1,d);
 IF res->>'status'<>'verified_game_airport_slots'
 OR res->>'reservedSlots'<>'2'
 THEN RAISE EXCEPTION 'Restored positive BEG-ZAG no longer passes real GAME slot authority: %',res;END IF;

 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1
 WHERE status='active' OR operationally_verified)
 THEN RAISE EXCEPTION 'Read-only slot verifier activated a game flight';END IF;
 RAISE NOTICE 'PASS: LIVE unmodified slot verifier BEG-ZAG 2 correct stand slots + actual Section5 GAME evidence; MUC unknown Chapter, missing slot, unavailable capacity, short runway, unverified Chapter, hard curfew, stale tick, wrong version all fail closed; zero HMAC certificates issued.';
END $test$;
ROLLBACK;
