-- Rollback-only World 1 game slot authority/source acceptance.
-- No slot approvals are issued to live schedules.
BEGIN;
DO $test$
DECLARE owner_id uuid;airline uuid;home text;code text;plane uuid;draft uuid;
 status jsonb;old_cert bigint;old_event bigint;old_ledger bigint;
 old_movements bigint;old_positions bigint;old_active bigint;
BEGIN
 IF has_function_privilege('anon',
 'airlinerra_game.section9_verify_slot_clearance_source_v1(uuid,uuid,integer,date)',
 'EXECUTE') OR has_function_privilege('authenticated',
 'airlinerra_game.section9_verify_slot_clearance_source_v1(uuid,uuid,integer,date)',
 'EXECUTE')
 THEN RAISE EXCEPTION 'Browser role accesses private slot authority';END IF;
 SELECT count(*) INTO old_cert FROM airlinerra_game.section9_schedule_operational_certifications_v1;
 SELECT count(*) INTO old_event FROM airlinerra_game.section9_operational_certification_events_v1;
 SELECT count(*) INTO old_ledger FROM airlinerra_game.airline_ledger;
 SELECT count(*) INTO old_movements FROM airlinerra_game.section9_operated_flight_movements_v1;
 SELECT count(*) INTO old_positions FROM airlinerra_game.section9_aircraft_current_position_v1;
 SELECT count(*) INTO old_active FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE status='active';
 SELECT id,owner_player_id,home_airport_key,iata_code INTO airline,owner_id,home,code
 FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 IF airline IS NULL THEN RAISE EXCEPTION 'World1 fixture airline not found';END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(airline,3,'S9-SLOTS-ROLLBACK','owned','in_service')
 RETURNING id INTO plane;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,reference_departure_utc,
  reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(airline,plane,3,code||'963',home,
  CASE WHEN home='OURAIRPORTS:2212' THEN 'OURAIRPORTS:4610'
   ELSE 'OURAIRPORTS:2212' END,
  '2000-01-03T09:00:00Z','2000-01-03T10:00:00Z',
  '[{"day":0,"time":"10:00"}]'::jsonb,'{}'::jsonb,owner_id)
 RETURNING id INTO draft;

 status:=airlinerra_game.section9_verify_slot_clearance_source_v1(
  airline,draft,1,DATE '2000-01-03');
 IF status->>'status'<>'blocked_unverified_world_or_game_day'
 OR status->>'verified'<>'false'
 OR status->>'flightActivated'<>'false'
 THEN RAISE EXCEPTION 'Unopened game returned a slot grant: %',status;END IF;
 status:=airlinerra_game.section9_verify_slot_clearance_source_v1(
  airline,draft,2,DATE '2000-01-03');
 IF status->>'status'<>'blocked_stale_or_non_draft_schedule'
 THEN RAISE EXCEPTION 'Stale schedule version returned slot clearance: %',status;END IF;

 -- Simulate signed game clock ONLY inside this rollback transaction.
 UPDATE public.airlinerra_game_worlds SET state='active',
  opens_at=clock_timestamp()-interval '7 days' WHERE id=1;
 UPDATE airlinerra_game.holding_world_clock_v1
 SET clock_source='authoritative_game_engine',
  confirmed_game_date=DATE '2000-01-03',
  engine_proof_ref='ROLLBACK_SIGNED_SLOT_AUTHORITY_20000103',
  last_verified_at=clock_timestamp() WHERE world_id=1;
 INSERT INTO airlinerra_game.section9_verified_game_tick_receipts_v1(
  world_id,game_date,engine_event_id,event_hmac_sha256,dispatch_kind)
 VALUES(1,DATE '2000-01-03','rollback-slot-authority-20000103',
  repeat('b',64),'no_verified_flights');
 status:=airlinerra_game.section9_verify_slot_clearance_source_v1(
  airline,draft,1,DATE '2000-01-03');
 IF status->>'status'<>'blocked_slot_clearance_evidence'
 OR status->>'verified'<>'false'
 OR status->>'flightActivated'<>'false'
 OR status->'blockers' IS NULL
 OR NOT status->'blockers' ? 'RECURRING_SLOT_RESERVATIONS_MISMATCH'
 THEN RAISE EXCEPTION 'Unreserved draft received verified slot proof: %',status;END IF;
 BEGIN
  PERFORM airlinerra_game.section9_record_verified_certification_event_v1(
   airline,draft,1,'airport_slot_capacity','certify',
   'synthetic-game-slot-clearance-without-reservations',
   'game-slot-capacity-v1-'||repeat('f',32),
   'independent-game-slot-authority-v1',
   DATE '2000-01-03',DATE '2000-01-31',repeat('a',64));
  RAISE EXCEPTION 'Certificate accepted without real airport reservation';
 EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 IF (SELECT count(*) FROM airlinerra_game.section9_schedule_operational_certifications_v1)
   <>old_cert OR
  (SELECT count(*) FROM airlinerra_game.section9_operational_certification_events_v1)
   <>old_event OR
  (SELECT count(*) FROM airlinerra_game.airline_ledger)<>old_ledger OR
  (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)
   <>old_movements OR
  (SELECT count(*) FROM airlinerra_game.section9_aircraft_current_position_v1)
   <>old_positions OR
  (SELECT count(*) FROM airlinerra_game.airline_flight_schedule_drafts_v1
    WHERE status='active')<>old_active
 THEN RAISE EXCEPTION 'Source verifier wrote approval, flight, position or money';END IF;
 RAISE NOTICE 'PASS: unopened world, stale draft, absent recurring reservations and fake signed clearance all fail closed';
END $test$;
ROLLBACK;