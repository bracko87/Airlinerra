-- ROLLBACK-ONLY Section 9 unified activation readiness acceptance.
-- Must leave the production schedule, movement, position and ledger unchanged.
BEGIN;
DO $test$
DECLARE
 airline uuid;player uuid;prefix text;home text;
 aircraft uuid;schedule uuid;result jsonb;
 before_schedule bigint;before_movement bigint;before_position bigint;before_money bigint;
BEGIN
 SELECT count(*) INTO before_schedule FROM airlinerra_game.airline_flight_schedule_drafts_v1;
 SELECT count(*) INTO before_movement FROM airlinerra_game.section9_operated_flight_movements_v1;
 SELECT count(*) INTO before_position FROM airlinerra_game.section9_aircraft_current_position_v1;
 SELECT count(*) INTO before_money FROM airlinerra_game.airline_ledger;
 IF has_function_privilege('anon',
  'airlinerra_game.section9_owned_commercial_activation_preflight_v1(uuid,uuid,uuid,date,integer)',
  'EXECUTE')
  OR has_function_privilege('authenticated',
  'airlinerra_game.section9_owned_commercial_activation_preflight_v1(uuid,uuid,uuid,date,integer)',
  'EXECUTE')
 THEN RAISE EXCEPTION 'Player roles could directly execute private preflight';END IF;

 BEGIN
  PERFORM airlinerra_game.section9_owned_commercial_activation_preflight_v1(
   '11111111-1111-4111-8111-111111111111'::uuid,
   '22222222-2222-4222-8222-222222222222'::uuid,
   '44444444-4444-4444-8444-444444444444'::uuid,
   DATE '2000-11-09',28);
  RAISE EXCEPTION 'Unowned schedule was accepted';
 EXCEPTION WHEN insufficient_privilege THEN NULL;
 END;

 SELECT id,owner_player_id,iata_code,home_airport_key
 INTO airline,player,prefix,home FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 IF airline IS NULL THEN RAISE EXCEPTION 'Test requires one existing World 1 airline';END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(airline,3,'S9-PREFLIGHT-ROLLBACK','owned','in_service')
 RETURNING id INTO aircraft;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,reference_departure_utc,
  reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(airline,aircraft,3,prefix||'987',home,
  CASE WHEN home='OURAIRPORTS:2212'
       THEN 'OURAIRPORTS:4610' ELSE 'OURAIRPORTS:2212' END,
  '2000-01-03T09:00:00Z','2000-01-03T10:00:00Z',
  '[{"day":0,"time":"10:00"}]'::jsonb,'{}'::jsonb,player)
 RETURNING id INTO schedule;
 result:=airlinerra_game.section9_owned_commercial_activation_preflight_v1(
  player,airline,schedule,DATE '2000-01-03',28);
 IF result->>'status'<>'BLOCKED_COMMERCIAL_ACTIVATION_NOT_RELEASED'
 OR result->>'readOnly'<>'true'
 OR result->>'canActivateNormalFlight'<>'false'
 OR result->>'flightActivated'<>'false'
 OR result->>'movementRecorded'<>'false'
 OR result->>'bookingsCreated'<>'false'
 OR result->>'ledgerPosted'<>'false'
 OR result->'activationChecklist'->>'draftOnly'<>'true'
 OR jsonb_array_length(result->'activationBlockers')<5
 THEN RAISE EXCEPTION 'Draft preflight unsafe: %',result;END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)
   <>before_movement OR
  (SELECT count(*) FROM airlinerra_game.section9_aircraft_current_position_v1)
   <>before_position OR
  (SELECT count(*) FROM airlinerra_game.airline_ledger)<>before_money
 THEN RAISE EXCEPTION 'Preview created movement or finance records';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airline_flight_schedule_drafts_v1)
   <>before_schedule+1
 THEN RAISE EXCEPTION 'Preview changed another schedule';END IF;
 RAISE NOTICE 'PASS: unified activation blocked, private, owner-scoped, side-effect-free';
END $test$;
ROLLBACK;
