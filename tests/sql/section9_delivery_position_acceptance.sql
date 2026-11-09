-- Rollback-only production acceptance of authoritative delivery location.
-- Fictional delivery, owner, approved inspection and game clock fixtures
-- NEVER survive this transaction.
BEGIN;
DO $tests$
DECLARE company uuid;owner_id uuid;code text;home text;
 aircraft uuid; offer uuid; ord uuid; inspect uuid;
 route1 uuid;route2 uuid;result jsonb;preview jsonb;
 first_money numeric;paid_price numeric;before_ledger bigint;before_positions bigint;
 denied boolean;
BEGIN
 SELECT id,owner_player_id,iata_code,home_airport_key,cash_usd
 INTO company,owner_id,code,home,first_money
 FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 IF company IS NULL THEN RAISE EXCEPTION 'No existing test airline';END IF;
 SELECT count(*) INTO before_ledger FROM airlinerra_game.airline_ledger;
 SELECT count(*) INTO before_positions FROM
  airlinerra_game.section9_aircraft_delivery_position_v1;
 IF (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 OR (SELECT clock_source FROM airlinerra_game.holding_world_clock_v1
      WHERE world_id=1)<>'not_connected'
 THEN RAISE EXCEPTION 'Production state changed: abort delivery fixture';END IF;

 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(company,3,'S9-LOCATION-ROLLBACK','owned','in_service')
 RETURNING id INTO aircraft;
 -- Reuse an ACTUALLY published market offer: never invent a
 -- pricing approval or bypass aircraft-market release guards.
 SELECT offer_id,upfront_price_usd INTO offer,paid_price
 FROM airlinerra_game.aircraft_acquisition_offers_v1
 WHERE world_id=1 AND configuration_id=3
  AND transaction_type='purchase' AND offer_status='published'
  AND pricing_basis LIKE 'AIRLINERRA_GAME_BALANCE_V1:%'
 ORDER BY offer_id LIMIT 1;
 IF offer IS NULL THEN RAISE EXCEPTION 'Released configuration 3 offer absent';END IF;
 INSERT INTO airlinerra_game.aircraft_acquisition_orders_v1(
  airline_id,player_id,request_id,offer_id,
  aircraft_inventory_id,registration,configuration_id,
  transaction_type,paid_upfront_usd,delivery_home_airport_key,
  delivery_due_at,order_status)
 VALUES(company,owner_id,gen_random_uuid(),offer,
  aircraft,'S9-LOCATION-ROLLBACK',3,'purchase',paid_price,home,
  clock_timestamp()-interval '2 days','delivered_pending_inspection')
 RETURNING order_id INTO ord;
 INSERT INTO airlinerra_game.aircraft_delivery_inspections_v1(
  order_id,aircraft_inventory_id,inspection_status,requested_at,
  reviewed_at,reviewer_reference)
 VALUES(ord,aircraft,'approved',clock_timestamp()-interval '2 days',
  clock_timestamp()-interval '1 day',
  'ROLLBACK-REVIEWER-APPROVAL-001')
 RETURNING inspection_id INTO inspect;

 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,
  reference_departure_utc,reference_arrival_utc,
  weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(company,aircraft,3,code||'971',home,'OURAIRPORTS:2212',
  '2026-11-09T09:00:00Z','2026-11-09T10:00:00Z',
  '[{"day":0,"time":"11:00"}]'::jsonb,'{}'::jsonb,owner_id)
 RETURNING id INTO route1;

 -- The delivery evidence is not usable while the world clock is offline.
 result:=airlinerra_game.section9_capture_approved_delivery_position_v1(
  company,aircraft);
 IF result->>'status'<>'blocked_unverified_world_clock' OR
  (SELECT count(*) FROM airlinerra_game.section9_aircraft_delivery_position_v1)
    <>before_positions
 THEN RAISE EXCEPTION 'Delivery was anchored to disconnected clock';END IF;
 preview:=airlinerra_game.section9_owned_aircraft_delivery_position_preview_v1(
  owner_id,company,route1,DATE '2000-01-03',14);
 IF preview->>'status'<>'delivery_anchor_missing' OR
  preview->>'canActivateNormalFlight'<>'false'
 THEN RAISE EXCEPTION 'Unapproved delivery was falsely cleared: %',preview;END IF;

 -- Only inside this transaction, simulate a formally opened game world.
 UPDATE public.airlinerra_game_worlds
 SET state='active',opens_at=clock_timestamp()-interval '5 days' WHERE id=1;
 UPDATE airlinerra_game.holding_world_clock_v1
 SET confirmed_game_date=DATE '2000-01-03',
  clock_source='authoritative_game_engine',
  engine_proof_ref='ROLLBACK_TEST_AUTHENTICATED_ENGINE_DAY_20000103',
  last_verified_at=clock_timestamp() WHERE world_id=1;

 result:=airlinerra_game.section9_capture_approved_delivery_position_v1(
  company,aircraft);
 IF result->>'status'<>'approved_delivery_position_recorded' OR
  result->>'airportKey'<>home OR
  result->>'anchoredGameDate'<>'2000-01-03' OR
  result->>'currentLocationVerified'<>'false'
 THEN RAISE EXCEPTION 'Verified delivery did not anchor at real source: %',result;END IF;
 result:=airlinerra_game.section9_capture_approved_delivery_position_v1(
  company,aircraft);
 IF result->>'status'<>'approved_delivery_position_replayed' THEN
  RAISE EXCEPTION 'Second delivery created duplicate location';END IF;
 result:=airlinerra_game.section9_sync_approved_delivery_positions_v1(20);
 IF result->>'recorded'<>'0' THEN RAISE EXCEPTION 'Sync repeated event';END IF;
 preview:=airlinerra_game.section9_owned_aircraft_delivery_position_preview_v1(
  owner_id,company,route1,DATE '2000-01-03',14);
 IF preview->>'status'<>'delivery_matches_first_planned_departure'
  OR preview->>'initialDepartureMatchesDelivery'<>'true'
  OR preview->>'movementHistoryVerified'<>'false'
  OR preview->>'canActivateNormalFlight'<>'false'
 THEN RAISE EXCEPTION 'First departure/certification preview wrong: %',preview;END IF;

 -- Same aircraft, earlier flight starting at another airport:
 -- compare earliest actual timetable across ALL aircraft routes.
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,
  reference_departure_utc,reference_arrival_utc,
  weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(company,aircraft,3,code||'972','OURAIRPORTS:2212',home,
  '2026-11-09T09:00:00Z','2026-11-09T10:00:00Z',
  '[{"day":0,"time":"09:00"}]'::jsonb,'{}'::jsonb,owner_id)
 RETURNING id INTO route2;
 preview:=airlinerra_game.section9_owned_aircraft_delivery_position_preview_v1(
  owner_id,company,route1,DATE '2000-01-03',14);
 IF preview->>'status'<>'first_departure_airport_mismatch' OR
  preview->>'initialDepartureMatchesDelivery'<>'false'
  OR preview->>'firstPlannedDepartureAirport'<>'OURAIRPORTS:2212'
 THEN RAISE EXCEPTION 'Wrong first airport not detected: %',preview;END IF;
 result:=airlinerra_game.section9_owned_operations_with_crew_rights_v1(
  owner_id,company,route1,DATE '2000-01-03',14);
 IF result->>'canActivateNormalFlight'<>'false' OR
  result->'aircraftPosition'->>'status'<>'first_departure_airport_mismatch'
  OR NOT result->'blockers' ? 'FIRST_PLANNED_DEPARTURE_AT_WRONG_AIRPORT'
 THEN RAISE EXCEPTION 'Operating preflight lost position block';END IF;

 denied:=false;
 BEGIN
  UPDATE airlinerra_game.section9_aircraft_delivery_position_v1
  SET airport_key='OURAIRPORTS:2212'
  WHERE aircraft_inventory_id=aircraft;
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Immutable anchor was rewritten';END IF;

 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_owned_aircraft_delivery_position_preview_v1(
   gen_random_uuid(),company,route1,DATE '2000-01-03',14);
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Nonowner accessed aircraft location';END IF;

 -- Rejection/revocation of original approval invalidates source validation.
 UPDATE airlinerra_game.aircraft_delivery_inspections_v1
 SET inspection_status='rejected' WHERE inspection_id=inspect;
 preview:=airlinerra_game.section9_owned_aircraft_delivery_position_preview_v1(
  owner_id,company,route1,DATE '2000-01-03',14);
 IF preview->>'deliveryAnchorRecorded'<>'false'
 THEN RAISE EXCEPTION 'Revoked inspection still counted as approved';END IF;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section9_capture_approved_delivery_position_v1(
   company,aircraft);
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;END;
 IF NOT denied THEN RAISE EXCEPTION 'Revoked inspection allowed recording';END IF;

 IF (SELECT count(*) FROM airlinerra_game.airline_ledger)<>before_ledger OR
  (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=company)<>first_money
 THEN RAISE EXCEPTION 'Delivery position changed finances';END IF;
 IF has_table_privilege('authenticated',
  'airlinerra_game.section9_aircraft_delivery_position_v1','INSERT') OR
  has_function_privilege('authenticated',
   'airlinerra_game.section9_capture_approved_delivery_position_v1(uuid,uuid)',
   'EXECUTE') OR
  has_function_privilege('anon',
   'airlinerra_game.section9_sync_approved_delivery_positions_v1(integer)',
   'EXECUTE')
 THEN RAISE EXCEPTION 'Browser role granted aircraft position authority';END IF;
 RAISE NOTICE 'PASS clock gate, approved delivery proof, replay, immutable airport, first-flight mismatch, revoked inspection, owner privacy, no money';
END $tests$;
ROLLBACK;