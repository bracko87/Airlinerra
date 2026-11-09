-- ROLLBACK-ONLY aircraft movement acceptance. Tests the pure transaction
-- reducer on synthetic states WITHOUT bypassing the production draft-only
-- flight activation check. A fake clock is inserted only inside ROLLBACK.
BEGIN;
DO $test$
DECLARE departure jsonb;arrival jsonb;blocked jsonb;
 a uuid;owner_id uuid;code text;home text;
 aircraft uuid;schedule uuid;
 before_ledger bigint;before_events bigint;before_current bigint;
 t1 timestamptz:='2000-01-03T10:00:00Z';
 t2 timestamptz:='2000-01-03T11:00:00Z';
 flight text:='example-schedule:2000-01-03:1';
BEGIN
 departure:=airlinerra_game.section9_aircraft_movement_decision_v1(
 'departed','grounded','OURAIRPORTS:4610',NULL,NULL,NULL,
 'OURAIRPORTS:4610','OURAIRPORTS:2212',flight,t1);
 IF departure->>'allowed'<>'true' OR
   departure->>'newState'<>'in_flight' OR
   departure->>'newAirport' IS NOT NULL
 THEN RAISE EXCEPTION 'Valid grounded departure rejected: %',departure;END IF;
 blocked:=airlinerra_game.section9_aircraft_movement_decision_v1(
 'departed','in_flight',NULL,flight,t1,t1,
 'OURAIRPORTS:4610','OURAIRPORTS:2212','other-flight',t2);
 IF blocked->>'reason'<>'AIRCRAFT_ALREADY_IN_FLIGHT'
 THEN RAISE EXCEPTION 'Second concurrent departure accepted: %',blocked;END IF;
 blocked:=airlinerra_game.section9_aircraft_movement_decision_v1(
 'arrived','in_flight',NULL,flight,t1,t1,
 'OURAIRPORTS:4610','OURAIRPORTS:2212','wrong-occurrence',t2);
 IF blocked->>'reason'<>'ARRIVAL_NOT_FOR_CURRENT_FLIGHT'
 THEN RAISE EXCEPTION 'Arrival with wrong flight accepted: %',blocked;END IF;
 blocked:=airlinerra_game.section9_aircraft_movement_decision_v1(
 'arrived','in_flight',NULL,flight,t1,t1,
 'OURAIRPORTS:4610','OURAIRPORTS:2212',flight,t1);
 IF blocked->>'allowed'<>'false'
 THEN RAISE EXCEPTION 'Arrival not after departure accepted';END IF;
 arrival:=airlinerra_game.section9_aircraft_movement_decision_v1(
 'arrived','in_flight',NULL,flight,t1,t1,
 'OURAIRPORTS:4610','OURAIRPORTS:2212',flight,t2);
 IF arrival->>'allowed'<>'true' OR
   arrival->>'newState'<>'grounded' OR
   arrival->>'newAirport'<>'OURAIRPORTS:2212'
 THEN RAISE EXCEPTION 'Valid arrival did not move aircraft: %',arrival;END IF;
 blocked:=airlinerra_game.section9_aircraft_movement_decision_v1(
 'departed','grounded','OURAIRPORTS:2212',NULL,t2,t1,
 'OURAIRPORTS:4610','OURAIRPORTS:2212','third-flight',
 t2+interval '1 hour');
 IF blocked->>'reason'<>'AIRCRAFT_AT_WRONG_AIRPORT'
 THEN RAISE EXCEPTION 'Aircraft teleported to old origin: %',blocked;END IF;
 departure:=airlinerra_game.section9_aircraft_movement_decision_v1(
 'departed','grounded','OURAIRPORTS:2212',NULL,t2,t1,
 'OURAIRPORTS:2212','OURAIRPORTS:4610','return-flight',
 t2+interval '1 hour');
 IF departure->>'allowed'<>'true'
 THEN RAISE EXCEPTION 'Correct next airport departed was rejected';END IF;
 blocked:=airlinerra_game.section9_aircraft_movement_decision_v1(
 'arrived','grounded','OURAIRPORTS:2212',NULL,t2,t1,
 'OURAIRPORTS:4610','OURAIRPORTS:2212',flight,
 t2+interval '1 hour');
 IF blocked->>'reason'<>'AIRCRAFT_HAS_NO_DEPARTURE'
 THEN RAISE EXCEPTION 'Arrival without departure allowed';END IF;

 SELECT count(*) INTO before_ledger FROM airlinerra_game.airline_ledger;
 SELECT count(*) INTO before_events FROM
 airlinerra_game.section9_operated_flight_movements_v1;
 SELECT count(*) INTO before_current FROM
 airlinerra_game.section9_aircraft_current_position_v1;
 SELECT id,owner_player_id,iata_code,home_airport_key
 INTO a,owner_id,code,home
 FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 IF a IS NULL THEN RAISE EXCEPTION 'No available test airline';END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(a,3,'S9-OPERATED-ROLLBACK','owned','in_service')
 RETURNING id INTO aircraft;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,
  reference_departure_utc,reference_arrival_utc,
  weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(a,aircraft,3,code||'986',home,'OURAIRPORTS:2212',
  '2000-01-03T09:00:00Z','2000-01-03T10:00:00Z',
  '[{"day":0,"time":"10:00"}]'::jsonb,'{}'::jsonb,owner_id)
 RETURNING id INTO schedule;
 blocked:=airlinerra_game.section9_record_signed_operated_flight_movement_v1(
 a,schedule,1,DATE '2000-01-03',1,'departed',
 t1,'test-operated-event-missing-world',repeat('a',64));
 IF blocked->>'status'<>'blocked_world_not_open' THEN
  RAISE EXCEPTION 'Planned world allowed movement: %',blocked;END IF;

 UPDATE public.airlinerra_game_worlds SET state='active',
  opens_at=clock_timestamp()-interval '7 days' WHERE id=1;
 UPDATE airlinerra_game.holding_world_clock_v1
 SET clock_source='authoritative_game_engine',
  confirmed_game_date=DATE '2000-01-03',
  engine_proof_ref='ROLLBACK_ONLY_ENGINE_EVENT_20000103',
  last_verified_at=clock_timestamp() WHERE world_id=1;
 INSERT INTO airlinerra_game.section9_verified_game_tick_receipts_v1(
  world_id,game_date,engine_event_id,event_hmac_sha256,dispatch_kind)
 VALUES(1,DATE '2000-01-03',
 'rollback-world-one-20000103',repeat('b',64),'no_verified_flights');
 blocked:=airlinerra_game.section9_record_signed_operated_flight_movement_v1(
 a,schedule,1,DATE '2000-01-03',1,'departed',
 t1,'test-operated-event-still-draft',repeat('c',64));
 IF blocked->>'status'<>'blocked_schedule_not_operational' OR
   blocked->>'movementRecorded'<>'false' OR
   blocked->>'bookingsCreated'<>'false' OR
   blocked->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'Draft schedule forged movement: %',blocked;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)
   <>before_events OR
  (SELECT count(*) FROM airlinerra_game.section9_aircraft_current_position_v1)
   <>before_current OR
  (SELECT count(*) FROM airlinerra_game.airline_ledger)<>before_ledger
 THEN RAISE EXCEPTION 'Engine movement attempt wrote draft position/money';END IF;
 IF has_function_privilege('authenticated',
  'airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)',
  'EXECUTE') OR
  has_table_privilege('anon',
  'airlinerra_game.section9_operated_flight_movements_v1','SELECT') OR
  has_table_privilege('authenticated',
  'airlinerra_game.section9_aircraft_current_position_v1','INSERT')
 THEN RAISE EXCEPTION 'Public browser movement permissions granted';END IF;
 IF NOT EXISTS(SELECT 1 FROM pg_trigger t WHERE t.tgrelid=
  'airlinerra_game.section9_operated_flight_movements_v1'::regclass
  AND t.tgname='section9_operated_movement_immutable'
  AND t.tgenabled='O')
 THEN RAISE EXCEPTION 'Immutable movement trigger missing';END IF;
 RAISE NOTICE 'PASS pure movement chronology; wrong airport and duplicate departure blocked; draft schedule cannot create movement; no money, private roles';
END $test$;
ROLLBACK;