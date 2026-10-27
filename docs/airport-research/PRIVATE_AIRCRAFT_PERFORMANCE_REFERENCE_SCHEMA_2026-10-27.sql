-- ARCHIVE ONLY: installed already in private Supabase on 2026-10-27.
-- Applied migration: airlinerra_private_aircraft_performance_reference_grid_20261027
-- Do NOT blindly run again. No sample/manufacturer distances are seeded.
CREATE TABLE airlinerra.aircraft_performance_reference_sets (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 aircraft_variant_key text NOT NULL CHECK (aircraft_variant_key ~ '^[A-Z0-9][A-Z0-9_-]{2,63}$'),
 manufacturer text NOT NULL CHECK (length(trim(manufacturer))>=2),
 aircraft_model text NOT NULL CHECK (length(trim(aircraft_model))>=2),
 aircraft_variant text NOT NULL CHECK (length(trim(aircraft_variant))>=1),
 engine_configuration text NOT NULL CHECK (length(trim(engine_configuration))>=2),
 max_takeoff_mass_kg numeric(9,1) NOT NULL CHECK(max_takeoff_mass_kg>0),
 max_landing_mass_kg numeric(9,1) NOT NULL CHECK(max_landing_mass_kg>0),
 min_reference_mass_kg numeric(9,1) NOT NULL CHECK(min_reference_mass_kg>0),
 wingspan_m numeric(6,2) NOT NULL CHECK(wingspan_m>0),
 source_authority text NOT NULL,source_document_ref text NOT NULL,
 source_revision text NOT NULL,source_effective_date date NOT NULL,
 review_status text NOT NULL DEFAULT 'UNVERIFIED'
   CHECK(review_status IN('UNVERIFIED','PRIMARY_SOURCE_REVIEWED')),
 reviewed_by text,reviewed_on date,
 allow_conservative_mass_upper_envelope boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT aircraft_performance_reference_mass_bounds
   CHECK(min_reference_mass_kg<=max_landing_mass_kg
     AND max_landing_mass_kg<=max_takeoff_mass_kg),
 CONSTRAINT aircraft_performance_review_requires_reviewer
   CHECK(review_status='UNVERIFIED'
     OR (length(trim(reviewed_by))>=2 AND reviewed_on IS NOT NULL)),
 UNIQUE(aircraft_variant_key,source_document_ref,source_revision)
);
CREATE INDEX aircraft_performance_reference_variant
 ON airlinerra.aircraft_performance_reference_sets(
 aircraft_variant_key,source_effective_date DESC);

CREATE TABLE airlinerra.aircraft_performance_reference_points (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 reference_set_id bigint NOT NULL
   REFERENCES airlinerra.aircraft_performance_reference_sets(id),
 phase text NOT NULL CHECK(phase IN('TAKEOFF','LANDING')),
 aircraft_configuration_code text NOT NULL
   CHECK(length(trim(aircraft_configuration_code))>=2),
 operating_mass_kg numeric(9,1) NOT NULL CHECK(operating_mass_kg>0),
 pressure_altitude_ft integer NOT NULL
   CHECK(pressure_altitude_ft BETWEEN -2000 AND 20000),
 outside_air_temperature_c numeric(5,1) NOT NULL
   CHECK(outside_air_temperature_c BETWEEN -60 AND 65),
 headwind_component_kt numeric(5,1) NOT NULL
   CHECK(headwind_component_kt BETWEEN -60 AND 100),
 runway_slope_pct numeric(5,2) NOT NULL
   CHECK(runway_slope_pct BETWEEN -5 AND 5),
 runway_condition text NOT NULL CHECK(runway_condition IN('DRY','WET')),
 required_tora_m numeric(8,1),required_toda_m numeric(8,1),
 required_asda_m numeric(8,1),required_lda_m numeric(8,1),
 source_table_reference text NOT NULL
   CHECK(length(trim(source_table_reference))>=3),
 review_status text NOT NULL DEFAULT 'UNVERIFIED'
   CHECK(review_status IN('UNVERIFIED','PRIMARY_SOURCE_REVIEWED')),
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT aircraft_performance_phase_distances CHECK(
  (phase='TAKEOFF' AND required_tora_m>0
   AND required_toda_m>0 AND required_asda_m>0 AND required_lda_m IS NULL)
  OR
  (phase='LANDING' AND required_lda_m>0 AND required_tora_m IS NULL
   AND required_toda_m IS NULL AND required_asda_m IS NULL)
 ),
 UNIQUE(reference_set_id,phase,aircraft_configuration_code,operating_mass_kg,
  pressure_altitude_ft,outside_air_temperature_c,headwind_component_kt,
  runway_slope_pct,runway_condition)
);
CREATE INDEX aircraft_performance_points_by_condition
 ON airlinerra.aircraft_performance_reference_points(
  reference_set_id,phase,aircraft_configuration_code,
  runway_condition,operating_mass_kg);
ALTER TABLE airlinerra.aircraft_performance_reference_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra.aircraft_performance_reference_points ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.aircraft_performance_reference_sets,
 airlinerra.aircraft_performance_reference_points FROM PUBLIC,anon,authenticated;
REVOKE ALL ON SEQUENCE airlinerra.aircraft_performance_reference_sets_id_seq,
 airlinerra.aircraft_performance_reference_points_id_seq FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra.aircraft_performance_reference_sets IS
 'Private primary-source aircraft performance references; no aircraft model catalog, no automatic game admission, empty until independently reviewed.';
COMMENT ON TABLE airlinerra.aircraft_performance_reference_points IS
 'Private phase/configuration/conditions exact-grid performance entries; NO derived or fabricated AFM distances; never exposed to game clients.';

-- SECOND INSTALLED MIGRATION (already applied, do not rerun):
-- airlinerra_private_aircraft_performance_review_source_constraints_20261027
ALTER TABLE airlinerra.aircraft_performance_reference_sets
 DROP CONSTRAINT aircraft_performance_review_requires_reviewer;
ALTER TABLE airlinerra.aircraft_performance_reference_sets
 ADD CONSTRAINT aircraft_performance_review_requires_reviewer CHECK(
   review_status='UNVERIFIED'
   OR (reviewed_by IS NOT NULL AND length(trim(reviewed_by))>=2
       AND reviewed_on IS NOT NULL)
 );
ALTER TABLE airlinerra.aircraft_performance_reference_sets
 ADD CONSTRAINT aircraft_performance_reference_source_identity CHECK(
   length(trim(source_authority))>=3
   AND length(trim(source_document_ref))>=3
   AND length(trim(source_revision))>=1
 );
