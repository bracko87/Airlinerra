-- Controlled fuel-price/availability input; actual departure and arrival
-- receipt functions and fuel balance updates are installed from migrations.
INSERT INTO airlinerra_game.section9_aircraft_game_fuel_custody_v1
 (aircraft_inventory_id,airline_id,configuration_id,at_airport_key,fuel_game_family,onboard_kg,
 source_event_id,source_event_kind,evidence_reference,game_hour_utc)
 SELECT id,airline_id,configuration_id,'OURAIRPORTS:2212','GAME_KEROSENE',1000,
 'fixture-initial-fuel-receipt','approved_game_fuel_load','fixture-authorized-fuel-supply','2026-11-21 00:00+00'
 FROM airlinerra_game.airline_aircraft_inventory;
CREATE FUNCTION airlinerra_game.section9_auto_supply_game_only_fuel_v1(text) RETURNS jsonb LANGUAGE sql AS $$
 SELECT '{"status":"game_fuel_already_sufficient","ledgerPosted":false}'::jsonb
 $$;
CREATE FUNCTION airlinerra_game.section9_verify_game_fuel_before_departure_v1(p_id text) RETURNS jsonb LANGUAGE sql AS $$
 SELECT jsonb_build_object('status','verified_game_fuel_onboard_available_for_planned_trip',
 'fuelVerifiedForGame',true,'ledgerPosted',false,'airlineId',o.airline_id,'aircraftInventoryId',o.aircraft_inventory_id,
 'originAirport',o.origin_airport_key,'destinationAirport',o.destination_airport_key,'configurationId',c.configuration_id,
 'fuelCustodyRevision',c.revision,'fuelSourceEventId',c.source_event_id,'fuelOnBoardKg',c.onboard_kg,
 'plannedTripBurnKg',300,'plannedContingencyKg',20,'plannedHoldingReserveKg',150,
 'minimumPlannedFuelOnBoardKg',470,'fuelQuoteModelVersion','fixture-game-fuel-model')
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.section9_aircraft_game_fuel_custody_v1 c ON c.aircraft_inventory_id=o.aircraft_inventory_id
 WHERE p_id=o.schedule_id::text||':'||o.flight_local_date||':'||o.weekly_entry
 AND c.at_airport_key=o.origin_airport_key AND c.onboard_kg>=470
 $$;
DO $test$
DECLARE r jsonb; n int; stamp timestamptz;
BEGIN
 r:=airlinerra_game.section9_auto_dispatch_due_flight_events_v1(40);
 IF r->>'status'<>'trusted_game_dispatch_cycle_completed' OR (r->>'candidatesChecked')::int<>0 THEN
  RAISE EXCEPTION 'EARLY_FLIGHT: %',r;END IF;
 FOR n IN 1..4 LOOP
  stamp:='2026-11-21 00:00+00'::timestamptz+make_interval(hours=>n);
  UPDATE airlinerra_game.fixture_clock SET t=stamp;
  r:=airlinerra_game.section9_auto_dispatch_due_flight_events_v1(40);
  IF r->>'status'<>'trusted_game_dispatch_cycle_completed'
  OR (r->>'blocked')::int<>0
  OR (r->>'departuresRecorded')::int<>CASE WHEN n IN(1,3) THEN 1 ELSE 0 END
  OR (r->>'arrivalsRecorded')::int<>CASE WHEN n IN(2,4) THEN 1 ELSE 0 END
  THEN RAISE EXCEPTION 'CLOCK_STEP % FAILED: %',n,r;END IF;
  IF (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)<>n THEN
   RAISE EXCEPTION 'FLIGHT_EVENT_COUNT %',n;END IF;
  IF n IN(1,3) AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aircraft_current_position_v1 WHERE location_status='in_flight' AND airport_key IS NULL)
  THEN RAISE EXCEPTION 'AIRCRAFT_NOT_IN_FLIGHT';END IF;
  IF n IN(2,4) AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aircraft_current_position_v1
   WHERE location_status='grounded' AND airport_key=CASE WHEN n=2 THEN 'OURAIRPORTS:2218' ELSE 'OURAIRPORTS:2212' END)
  THEN RAISE EXCEPTION 'AIRCRAFT_WRONG_ARRIVAL';END IF;
  r:=airlinerra_game.section9_auto_dispatch_due_flight_events_v1(40);
  IF (r->>'candidatesChecked')::int<>0 THEN RAISE EXCEPTION 'REPLAY: %',r;END IF;
 END LOOP;
 IF (SELECT count(*) FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1)<>2
 OR (SELECT count(*) FROM airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1)<>2
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1 WHERE onboard_kg=400 AND at_airport_key='OURAIRPORTS:2212' AND revision=3)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_maintenance_state_v1 WHERE tracked_flight_hours=2 AND tracked_flight_cycles=2)
 OR (SELECT count(*) FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE booking_status='closed')<>2
 THEN RAISE EXCEPTION 'ROUNDTRIP_FINAL_STATE_MISMATCH';END IF;
 RAISE NOTICE 'PASS: actual dispatcher advanced through two departures and two arrivals, same aircraft at FRA, two flight hours/cycles, 600 kg consumed, no duplicate movement.';
END $test$;
