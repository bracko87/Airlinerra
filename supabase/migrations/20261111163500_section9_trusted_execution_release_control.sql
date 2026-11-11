-- Independent World1 flight execution release, fail-closed.
-- Separates the engine's release from fuel/finance settlement release.
-- This migration does NOT authorize flights, create schedules or payments.

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_trusted_execution_release_policy_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 release_state text NOT NULL DEFAULT 'disabled'
   CHECK(release_state IN ('disabled','enabled')),
 release_reference text,
 approved_by text,
 reviewed_at timestamptz,
 enabled_at timestamptz,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CONSTRAINT section9_execution_requires_independent_admin_review CHECK (
   release_state='disabled' OR (
     release_state='enabled'
     AND char_length(coalesce(release_reference,''))>=16
     AND char_length(coalesce(approved_by,''))>=12
     AND reviewed_at IS NOT NULL AND enabled_at IS NOT NULL
     AND reviewed_at<=clock_timestamp() AND enabled_at<=clock_timestamp()
   )
 )
);
ALTER TABLE airlinerra_game.section9_trusted_execution_release_policy_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_trusted_execution_release_policy_v1
 FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO airlinerra_game.section9_trusted_execution_release_policy_v1
 (world_id,release_state)
 VALUES(1,'disabled') ON CONFLICT(world_id) DO NOTHING;

CREATE OR REPLACE VIEW airlinerra_game.section9_flight_engine_readiness_audit_v1
 AS SELECT 1::smallint AS world_id,
    w.state AS world_state,
    w.opens_at AS world_opens_at,
    c.confirmed_game_date,
    c.clock_source,
    c.clock_source = 'authoritative_game_engine'::text AND c.confirmed_game_date IS NOT NULL AS authoritative_clock_connected,
    producer.world_id IS NOT NULL AS clock_producer_configured,
    COALESCE(producer.producer_status = 'enabled'::text, false) AS clock_producer_enabled,
    ( SELECT count(*) AS count
           FROM airlinerra_game.airline_flight_schedule_drafts_v1) AS saved_flight_schedules,
    ( SELECT count(*) AS count
           FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
          WHERE s.status = 'active'::text) AS active_flight_schedules,
    ( SELECT count(*) AS count
           FROM airlinerra_game.section9_schedule_operational_certifications_v1) AS operational_certification_records,
    ( SELECT count(*) AS count
           FROM airlinerra_game.section9_aircraft_day_operations_jobs_v1) AS aircraft_operation_jobs,
    ( SELECT count(*) AS count
           FROM airlinerra_game.section9_operated_flight_movements_v1) AS verified_movement_records,
    ( SELECT count(*) AS count
           FROM airlinerra_game.section9_route_posted_flight_financials_v1) AS settled_flight_records,
    ( SELECT count(*) AS count
           FROM airlinerra_game.aircraft_fuel_planning_profiles_v1
          WHERE aircraft_fuel_planning_profiles_v1.full_kg_per_100km > 0::numeric) AS aircraft_fuel_planning_profiles,
    ( SELECT count(*) AS count
           FROM airlinerra_game.aircraft_game_fuel_family_v1
          WHERE aircraft_game_fuel_family_v1.fuel_family = 'TURBINE_KEROSENE_ASSUMED'::text) AS game_kerosene_aircraft_profiles,
    CASE WHEN EXISTS (
      SELECT 1 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 release
      WHERE release.world_id=1 AND release.release_state='enabled'
      AND release.enabled_at IS NOT NULL
      AND release.reviewed_at IS NOT NULL
      AND release.approved_by IS NOT NULL
      AND char_length(release.approved_by)>=12
      AND char_length(release.release_reference)>=16
    ) THEN 'RELEASED'::text
    ELSE 'NOT_ACTIVATED'::text END AS trusted_flight_execution_release,
    'NOT_ACTIVATED'::text AS fuel_transaction_release,
    false AS automatic_flight_and_fuel_settlement_enabled
   FROM airlinerra_game_worlds w
     LEFT JOIN airlinerra_game.holding_world_clock_v1 c ON c.world_id = w.id
     LEFT JOIN airlinerra_game.section9_clock_producer_schedule_v1 producer ON producer.world_id = w.id
  WHERE w.id = 1;
REVOKE ALL ON airlinerra_game.section9_flight_engine_readiness_audit_v1
 FROM PUBLIC,anon,authenticated;

COMMENT ON TABLE airlinerra_game.section9_trusted_execution_release_policy_v1
 IS 'Private administrative flight-execution release, disabled by default. Separate from financial settlement.';
