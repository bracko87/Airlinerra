-- Rollback-only acceptance for private World 1 operated-flight candidates.
-- No production activation, money, location, or event changes.
BEGIN;
DO $test$
DECLARE
 a uuid;owner_id uuid;code text;home text;
 plane uuid;draft uuid;res jsonb;
 before_events bigint;before_pos bigint;before_money bigint;
BEGIN
 IF has_function_privilege('anon',
  'airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(uuid,uuid,date)',
  'EXECUTE')
 OR has_function_privilege('authenticated',
  'airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(uuid,uuid,date)',
  'EXECUTE') THEN RAISE EXCEPTION 'Browser roles may read private operations candidates';END IF;
 SELECT count(*) INTO before_events
  FROM airlinerra_game.section9_operated_flight_movements_v1;
 SELECT count(*) INTO before_pos
  FROM airlinerra_game.section9_aircraft_current_position_v1;
 SELECT count(*) INTO before_money FROM airlinerra_game.airline_ledger;
 SELECT id,owner_player_id,iata_code,home_airport_key INTO a,owner_id,code,home
 FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 IF a IS NULL THEN RAISE EXCEPTION 'Rollback test requires World 1 airline';END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(a,3,'S9-CANDIDATE-ROLLBACK','owned','in_service') RETURNING id INTO plane;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,
  reference_departure_utc,reference_arrival_utc,
  weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(a,plane,3,code||'985',home,
   CASE WHEN home='OURAIRPORTS:2212'
    THEN 'OURAIRPORTS:4610' ELSE 'OURAIRPORTS:2212' END,
   '2000-01-03T09:00:00Z','2000-01-03T10:00:00Z',
   '[{"day":0,"time":"10:00"}]'::jsonb,'{}'::jsonb,owner_id)
 RETURNING id INTO draft;
 res:=airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(
  a,plane,DATE '2000-01-03');
 IF res->>'status'<>'blocked_world_not_open'
    OR res->>'movementRecorded'<>'false'
    OR jsonb_array_length(res->'candidates')<>0
 THEN RAISE EXCEPTION 'World not open still emitted flight candidates: %',res;END IF;
 -- Synthetic clock and opening are rolled back with the draft.
 UPDATE public.airlinerra_game_worlds SET state='active',
  opens_at=clock_timestamp()-interval '7 days' WHERE id=1;
 UPDATE airlinerra_game.holding_world_clock_v1
 SET clock_source='authoritative_game_engine',
  confirmed_game_date=DATE '2000-01-03',
  engine_proof_ref='ROLLBACK_OPERATIONS_CANDIDATE_20000103',
  last_verified_at=clock_timestamp() WHERE world_id=1;
 INSERT INTO airlinerra_game.section9_verified_game_tick_receipts_v1(
  world_id,game_date,engine_event_id,event_hmac_sha256,dispatch_kind)
 VALUES(1,DATE '2000-01-03',
 'rollback-operation-candidate-day-20000103',repeat('e',64),'no_verified_flights');
 res:=airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(
  a,plane,DATE '2000-01-03');
 IF res->>'status'<>'no_verified_activated_schedules'
    OR res->>'readOnly'<>'true'
    OR res->>'requiresTrustedOperationDecision'<>'true'
    OR res->>'flightActivated'<>'false'
    OR res->>'movementRecorded'<>'false'
    OR jsonb_array_length(res->'candidates')<>0
 THEN RAISE EXCEPTION 'Draft emitted operated candidates: %',res;END IF;
 res:=airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(
  a,plane,DATE '2000-01-04');
 IF res->>'status'<>'blocked_unverified_game_day'
 THEN RAISE EXCEPTION 'Unverified tomorrow became dispatchable: %',res;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)
  <>before_events OR
  (SELECT count(*) FROM airlinerra_game.section9_aircraft_current_position_v1)
  <>before_pos OR
  (SELECT count(*) FROM airlinerra_game.airline_ledger)<>before_money OR
  (SELECT status FROM airlinerra_game.airline_flight_schedule_drafts_v1
   WHERE id=draft)<>'draft'
 THEN RAISE EXCEPTION 'Read-only operations candidates mutated flight, money or position';END IF;
 RAISE NOTICE 'PASS: unopened world, draft, future game day blocked; no mutations';
END $test$;
ROLLBACK;