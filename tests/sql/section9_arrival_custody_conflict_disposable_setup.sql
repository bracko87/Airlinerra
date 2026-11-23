-- Set up a second synthetic flight after the first arrival is fully verified.
-- The aircraft/fuel reset is ONLY a disposable fixture operation.
UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET departure_utc='2026-11-23 18:00+00',
     arrival_utc='2026-11-23 19:00+00'
 WHERE weekly_entry=5;
UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1
 SET departure_utc='2026-11-23 18:00+00',
     arrival_utc='2026-11-23 19:00+00'
 WHERE physical_flight_id LIKE '%:5';
UPDATE airlinerra_game.section9_aircraft_current_position_v1
 SET location_status='grounded',airport_key='TEST-AAA',
 current_flight_occurrence_id=NULL,last_event_utc=NULL,
 last_departure_utc=NULL,last_arrival_utc=NULL;
UPDATE airlinerra_game.section9_aircraft_game_fuel_custody_v1
 SET onboard_kg=500,revision=3,at_airport_key='TEST-AAA',
 source_event_kind='approved_game_fuel_load',
 source_event_id='SYNTHETIC-FUEL-LOAD-EVENT-2',
 evidence_reference='SYNTHETIC-APPROVED-SUPPLIER-2',
 game_hour_utc='2026-11-23 18:00+00',recorded_at=now();
INSERT INTO airlinerra_game.section9_game_approved_fuel_load_receipts_v1
(source_event_id,source_status,airline_id,aircraft_inventory_id,
 at_airport_key,fuel_family,fuel_after_load_kg,game_hour_utc,game_supplier_reference)
SELECT source_event_id,'game_authority_approved',airline_id,
 aircraft_inventory_id,at_airport_key,fuel_game_family,onboard_kg,
 game_hour_utc,evidence_reference
FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_berlin_game_hour_v1()
 RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT jsonb_build_object('authoritativeGameHourAvailable',true,
 'gameHourUtc','2026-11-23 18:00:00+00') $$;
