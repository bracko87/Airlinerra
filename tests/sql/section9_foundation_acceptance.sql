-- Section 9 acceptance. Run against the development/staging database.
-- All schedule fixtures are transaction-local and rolled back.
BEGIN;
DO $checks$
DECLARE a uuid; u uuid; prefix text; airplane uuid; target_id uuid;
 v jsonb; con jsonb; denied boolean:=false; total_airports integer;
BEGIN
 SELECT count(*) INTO total_airports
 FROM airlinerra_game.section9_airport_transfer_policy_v1 WHERE world_id=1;
 IF total_airports<>3141 THEN RAISE EXCEPTION 'Expected 3141 airport transfer rules, got %',total_airports; END IF;
 IF EXISTS (
  SELECT 1 FROM airlinerra_game.section9_airport_transfer_policy_v1
  WHERE minimum_transfer_minutes NOT IN (25,30,40,45,55,65)
   OR maximum_transfer_minutes<>720
 ) THEN RAISE EXCEPTION 'Invalid minimum or maximum transfer time';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_seasonal_demand_profiles WHERE world_id=1)<>3141
 THEN RAISE EXCEPTION 'Seasonal coverage missing';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_seasonal_demand_profiles
  WHERE profile='neutral_unverified_game_default_v1' AND verified=true)>0
 THEN RAISE EXCEPTION 'Unverified defaults incorrectly marked verified';END IF;

 v:=airlinerra_game.section9_route_market_preview_v1(
  1::smallint,'OURAIRPORTS:26519','OURAIRPORTS:26555',7::smallint);
 IF (v->>'directPassengersPerDay')::numeric<=0 OR
  (v->>'cargoTonnesPerDay')::numeric<0 OR
  v->>'flightActivationAllowed'<>'false' THEN
  RAISE EXCEPTION 'Invalid preview: %',v;END IF;

 SELECT id,owner_player_id,iata_code INTO a,u,prefix
 FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 IF a IS NULL OR prefix IS NULL THEN RAISE EXCEPTION 'Missing test airline';END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(a,3,'TEST-SECTION9-ROLLBACK','owned','in_service')
 RETURNING id INTO airplane;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,reference_departure_utc,
  reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(a,airplane,3,prefix||'871',
  'OURAIRPORTS:2214','OURAIRPORTS:2212',
  '2026-11-09T11:00:00Z','2026-11-09T12:00:00Z',
  '[{"day":0,"time":"12:00"}]'::jsonb,'{}'::jsonb,u)
 RETURNING id INTO target_id;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,reference_departure_utc,
  reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(a,airplane,3,prefix||'872',
  'OURAIRPORTS:2210','OURAIRPORTS:2214',
  '2026-11-09T08:00:00Z','2026-11-09T09:30:00Z',
  '[{"day":0,"time":"09:00"}]'::jsonb,'{}'::jsonb,u);
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,reference_departure_utc,
  reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(a,airplane,3,prefix||'873',
  'OURAIRPORTS:2212','OURAIRPORTS:2218',
  '2026-11-09T13:20:00Z','2026-11-09T14:30:00Z',
  '[{"day":0,"time":"14:20"}]'::jsonb,'{}'::jsonb,u);
 -- Arrives only 35 minutes ahead of HAM departure; HAM requires 55.
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,reference_departure_utc,
  reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(a,airplane,3,prefix||'874',
  'OURAIRPORTS:2213','OURAIRPORTS:2214',
  '2026-11-09T09:25:00Z','2026-11-09T10:25:00Z',
  '[{"day":0,"time":"10:25"}]'::jsonb,'{}'::jsonb,u);

 v:=airlinerra_game.section9_owned_route_preview_v1(u,a,target_id,7::smallint);
 con:=v->'connections';
 IF (con->>'inboundCount')::int<>1 OR (con->>'outboundCount')::int<>1 OR
  (con->>'inboundMinimumMinutes')::int<>55 OR
  (con->>'outboundMinimumMinutes')::int<>65 OR
  (con->'inbound'->0->>'shortestTransferMinutes')::int<55 OR
  (con->'outbound'->0->>'shortestTransferMinutes')::int<65 OR
  v->>'status'<>'draft_market_estimate'
 THEN RAISE EXCEPTION 'Invalid connection preview: %',v;END IF;

 BEGIN
  PERFORM airlinerra_game.section9_owned_route_preview_v1(
   gen_random_uuid(),a,target_id,7::smallint);
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'Non-owner could preview route';END IF;
 RAISE NOTICE 'PASS Section9 airport policy, neutral seasonality, market preview, transfer rules and ownership';
END $checks$;
ROLLBACK;
