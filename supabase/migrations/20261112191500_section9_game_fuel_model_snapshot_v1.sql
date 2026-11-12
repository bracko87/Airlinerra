-- Versioned GAME calculation inputs for server-owned Airlinerra fuel
-- integration. Values are existing provisional gameplay estimates, NOT OEM
-- fuel certification, real engine fitment or airport fuel contracts.
-- Import all catalog models and preserve missing tank values as NULL.
-- Nothing here enables fuel dispatch, refuelling or cash settlement.
BEGIN;
CREATE TABLE airlinerra_game.section9_game_fuel_model_snapshot_v1 (
 configuration_id bigint PRIMARY KEY
  REFERENCES airlinerra.aircraft_configurations(id),
 model_version text NOT NULL DEFAULT 'AIRLINERRA_FIVE_PHASE_FUEL_GAME_V1_2026_11_12'
  CHECK(model_version='AIRLINERRA_FIVE_PHASE_FUEL_GAME_V1_2026_11_12'),
 manufacturer_name text NOT NULL,
 model_name text NOT NULL,
 cruise_speed_kmh numeric(11,2) NOT NULL CHECK(cruise_speed_kmh>0),
 empty_kg_per_100km numeric(11,2) NOT NULL CHECK(empty_kg_per_100km>0),
 half_kg_per_100km numeric(11,2) NOT NULL
  CHECK(half_kg_per_100km>=empty_kg_per_100km),
 full_kg_per_100km numeric(11,2) NOT NULL
  CHECK(full_kg_per_100km>=half_kg_per_100km),
 tank_capacity_kg numeric(13,2) CHECK(tank_capacity_kg>0),
 fuel_game_family text NOT NULL DEFAULT 'TURBINE_KEROSENE_ASSUMED'
  CHECK(fuel_game_family='TURBINE_KEROSENE_ASSUMED'),
 model_source_kind text NOT NULL CHECK(model_source_kind IN
  ('EXISTING_PROVISIONAL_DISTANCE_RATE','DERIVED_PEER_AIRCRAFT_GAME_ESTIMATE')),
 model_confidence_class text NOT NULL,
 reference_peer_configuration_id bigint,
 game_calculation_ready boolean GENERATED ALWAYS AS (
  tank_capacity_kg IS NOT NULL AND tank_capacity_kg>0
 ) STORED,
 operational_dispatch_release text NOT NULL DEFAULT 'NOT_RELEASED'
  CHECK(operational_dispatch_release='NOT_RELEASED'),
 financial_settlement_release text NOT NULL DEFAULT 'NOT_RELEASED'
  CHECK(financial_settlement_release='NOT_RELEASED'),
 snapshot_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(reference_peer_configuration_id IS NULL OR
       reference_peer_configuration_id<>configuration_id)
);
INSERT INTO airlinerra_game.section9_game_fuel_model_snapshot_v1(
 configuration_id,manufacturer_name,model_name,cruise_speed_kmh,
 empty_kg_per_100km,half_kg_per_100km,full_kg_per_100km,
 tank_capacity_kg,fuel_game_family,model_source_kind,
 model_confidence_class,reference_peer_configuration_id)
SELECT p.configuration_id,p.manufacturer_name,p.model_name,
 p.cruise_speed_kmh,p.empty_kg_per_100km,p.half_kg_per_100km,
 p.full_kg_per_100km,p.fuel_tank_capacity_kg,
 g.fuel_family,p.rate_evidence,p.confidence_class,
 p.reference_peer_configuration_id
FROM airlinerra_game.aircraft_fuel_planning_profiles_v1 p
JOIN airlinerra_game.aircraft_game_fuel_family_v1 g
 ON g.configuration_id=p.configuration_id
WHERE p.cruise_speed_kmh>0 AND
 p.empty_kg_per_100km>0 AND
 p.half_kg_per_100km>=p.empty_kg_per_100km AND
 p.full_kg_per_100km>=p.half_kg_per_100km AND
 g.fuel_family='TURBINE_KEROSENE_ASSUMED';
-- No silent model omissions except missing positive source model values.
DO $check$
DECLARE catalog_count integer; snapshot_count integer;
BEGIN
 SELECT count(*) INTO catalog_count
 FROM airlinerra_game.aircraft_fuel_planning_profiles_v1;
 SELECT count(*) INTO snapshot_count
 FROM airlinerra_game.section9_game_fuel_model_snapshot_v1;
 IF snapshot_count<>catalog_count THEN
  RAISE EXCEPTION 'GAME_FUEL_MODEL_SNAPSHOT_INCOMPLETE: %/%',
   snapshot_count,catalog_count;
 END IF;
END $check$;
ALTER TABLE airlinerra_game.section9_game_fuel_model_snapshot_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_game_fuel_model_snapshot_v1
 FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON TABLE airlinerra_game.section9_game_fuel_model_snapshot_v1 IS
 'Immutable-on-release source-tagged fuel GAME simulation baseline, not manufacturer certification. NULL tank intentionally blocks one incomplete model. Zero operational or financial release.';
COMMIT;
