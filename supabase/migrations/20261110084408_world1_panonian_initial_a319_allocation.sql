-- Panonian World 1: one-time non-financial allocation of the existing
-- Airbus A319-100 fixture as a REAL, owner-scoped game fleet airframe.
-- This is not a purchased/leased aircraft, not a forged order or inspection,
-- and does not issue an airline licence or activate flights.
-- No real money or game USD is debited. No unrelated airline is touched.
BEGIN;

CREATE TABLE IF NOT EXISTS airlinerra_game.initial_aircraft_allocations_v1 (
 airline_id uuid PRIMARY KEY REFERENCES airlinerra_game.airlines(id) ON DELETE RESTRICT,
 aircraft_inventory_id uuid NOT NULL UNIQUE
  REFERENCES airlinerra_game.airline_aircraft_inventory(id) ON DELETE RESTRICT,
 source_fixture_id uuid NOT NULL UNIQUE,
 owner_player_id uuid NOT NULL,
 configuration_id bigint NOT NULL REFERENCES airlinerra.aircraft_configurations(id),
 registration text NOT NULL UNIQUE,
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 initial_home_airport_key text NOT NULL,
 source_kind text NOT NULL DEFAULT 'original_airline_starter_allocation'
  CHECK (source_kind='original_airline_starter_allocation'),
 assigned_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 allocation_note text NOT NULL,
 CONSTRAINT starter_home_fk FOREIGN KEY (world_id, initial_home_airport_key)
  REFERENCES airlinerra_game.approved_game_airports(world_id, airport_key)
  DEFERRABLE INITIALLY DEFERRED
);
ALTER TABLE airlinerra_game.initial_aircraft_allocations_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.initial_aircraft_allocations_v1 FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE airlinerra_game.initial_aircraft_allocations_v1 IS
 'Private audit for an explicitly operator-authorized one-time starter fleet asset. It is not evidence of a player purchase, an airworthiness inspection, a delivered-aircraft position or flight activation.';

DO $grant$
DECLARE
 company record;
 fixture record;
 airframe uuid;
 previous record;
 model_ok boolean;
BEGIN
 SELECT a.id,a.owner_player_id,a.home_airport_key,a.world_id,w.state,a.name
 INTO STRICT company
 FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships w
  ON w.world_id=a.world_id AND w.player_id=a.owner_player_id
 WHERE a.world_id=1 AND a.name='Panonian' AND w.state='active'
 FOR UPDATE OF a;

 SELECT * INTO previous FROM airlinerra_game.initial_aircraft_allocations_v1
 WHERE airline_id=company.id;
 IF FOUND THEN
  IF previous.configuration_id<>16 OR previous.registration<>'YU-PAN01' OR
     NOT EXISTS (
      SELECT 1 FROM airlinerra_game.airline_aircraft_inventory i
      WHERE i.id=previous.aircraft_inventory_id AND i.airline_id=company.id
       AND i.configuration_id=16 AND i.registration='YU-PAN01'
       AND i.ownership_type='owned' AND i.fleet_status='in_service'
     ) THEN
   RAISE EXCEPTION 'STARTER_A319_ALLOCATION_IDEMPOTENCY_MISMATCH';
  END IF;
 ELSE
  SELECT f.* INTO STRICT fixture
  FROM airlinerra_game.airline_aircraft_test_fixtures f
  WHERE f.airline_id=company.id AND f.display_registration='TEST-PA-A319-01'
    AND f.configuration_id=16 AND f.test_only=true AND f.operationally_allowed=false
  FOR UPDATE;

  IF EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory i
      WHERE i.airline_id=company.id)
   OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_acquisition_orders_v1 o
      WHERE o.airline_id=company.id) THEN
   RAISE EXCEPTION 'STARTER_ALLOCATION_REQUIRES_EMPTY_REAL_FLEET';
  END IF;
  SELECT EXISTS(
   SELECT 1 FROM airlinerra.aircraft_catalog_configuration_inventory c
   WHERE c.configuration_id=fixture.configuration_id
     AND c.manufacturer_name='Airbus' AND c.model_name='A319-100'
     AND c.model_catalog_status='service_verified'
     AND c.civilian_service_status='active'
     AND NOT EXISTS(SELECT 1 FROM airlinerra.aircraft_expansion_group3 g
                    WHERE g.configuration_id=c.configuration_id)
  ) INTO model_ok;
  IF NOT model_ok THEN
   RAISE EXCEPTION 'AIRBUS_A319_CONFIGURATION_NOT_GAME_RELEASED';
  END IF;
  IF EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory i
      WHERE upper(i.registration)='YU-PAN01') THEN
   RAISE EXCEPTION 'STARTER_AIRCRAFT_REGISTRATION_ALREADY_USED';
  END IF;

  -- This is an explicit original-airline starter allocation, separate from
  -- the paid market acquisition and delivery inspection lifecycle. It is
  -- in_service for owner-scoped schedule-DRAFT compatibility only.
  -- Later Section 9 certification and initial-position gates still apply.
  INSERT INTO airlinerra_game.airline_aircraft_inventory (
   airline_id,configuration_id,registration,ownership_type,fleet_status
  ) VALUES (
   company.id,fixture.configuration_id,'YU-PAN01','owned','in_service'
  ) RETURNING id INTO airframe;

  INSERT INTO airlinerra_game.initial_aircraft_allocations_v1 (
   airline_id,aircraft_inventory_id,source_fixture_id,owner_player_id,
   configuration_id,registration,initial_home_airport_key,allocation_note
  ) VALUES (
   company.id,airframe,fixture.id,company.owner_player_id,fixture.configuration_id,
   'YU-PAN01',company.home_airport_key,
   'One-time player-requested starter aircraft. No purchase, lease, debit, inspection approval or commercial flight.'
  );

  DELETE FROM airlinerra_game.airline_aircraft_test_fixtures
  WHERE id=fixture.id AND airline_id=company.id;
  IF NOT FOUND THEN RAISE EXCEPTION 'OLD_SIMULATION_AIRCRAFT_NOT_REMOVED'; END IF;
 END IF;
END
$grant$;

COMMIT;
