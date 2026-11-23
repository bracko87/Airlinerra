-- Real automatic fuel supply additional dependencies for disposable PostgreSQL.
-- The preceding fixture has a pre-authorized 500 kg source; tests change it
-- to 100 kg to force a genuine 80 kg top-up. The actual auto-supply function,
-- preflight and dispatcher are installed unchanged from production migration.
ALTER TABLE airlinerra_game.section9_aircraft_game_fuel_custody_v1
 ADD COLUMN recorded_at timestamptz NOT NULL DEFAULT now();
ALTER TABLE airlinerra_game.airlines
 ADD COLUMN world_id smallint NOT NULL DEFAULT 1;
ALTER TABLE airlinerra_game.section9_game_approved_fuel_load_receipts_v1
 ADD COLUMN load_added_kg numeric(14,3);
CREATE FUNCTION airlinerra_game.section9_owned_aircraft_operational_position_v1(
 uuid,uuid,uuid,date)
 RETURNS jsonb LANGUAGE sql STABLE AS $$
 SELECT '{"verified":true,"atGroundAirport":true,"airportKey":"TEST-AAA","status":"verified_original_game_starter_position"}'::jsonb $$;
