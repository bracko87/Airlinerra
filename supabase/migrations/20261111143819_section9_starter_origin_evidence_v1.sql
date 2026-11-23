-- Section 9: original starter aircraft have an explicitly assigned home
-- airport, distinct from purchased-aircraft delivery / inspection.
-- This read-only source must never manufacture a purchase or an inspection.
-- It does not grant certifications, activate flights, or move an aircraft.

CREATE OR REPLACE FUNCTION airlinerra_game.section9_starter_origin_evidence_v1(
 p_airline uuid,p_aircraft uuid,p_game_day date
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $source$
DECLARE
 proof record;
BEGIN
 IF p_airline IS NULL OR p_aircraft IS NULL OR p_game_day IS NULL
   OR p_game_day NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_STARTER_ORIGIN_REQUEST'; END IF;

 SELECT s.airline_id,s.aircraft_inventory_id,s.initial_home_airport_key,
        s.assigned_at,s.source_kind,s.source_fixture_id,
        s.registration,s.configuration_id
 INTO proof
 FROM airlinerra_game.initial_aircraft_allocations_v1 s
 JOIN airlinerra_game.airline_aircraft_inventory f
   ON f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id
 JOIN airlinerra_game.airlines a
   ON a.id=s.airline_id AND a.owner_player_id=s.owner_player_id
      AND a.world_id=1
 JOIN airlinerra_game.airport_reference_profiles airport
   ON airport.world_id=1 AND airport.airport_key=s.initial_home_airport_key
 JOIN pg_catalog.pg_timezone_names timezone_check
   ON timezone_check.name=airport.timezone_iana
 JOIN public.airlinerra_game_worlds world
   ON world.id=1 AND world.state='active'
   AND world.opens_at IS NOT NULL AND world.opens_at<=clock_timestamp()
 WHERE s.world_id=1 AND s.airline_id=p_airline
   AND s.aircraft_inventory_id=p_aircraft
   AND s.source_kind='original_airline_starter_allocation'
   AND s.source_fixture_id IS NOT NULL
   AND s.initial_home_airport_key=a.home_airport_key
   AND s.registration=f.registration
   AND s.configuration_id=f.configuration_id
   AND f.fleet_status='in_service' AND f.ownership_type='owned'
   AND s.assigned_at IS NOT NULL AND s.assigned_at<=clock_timestamp()
   AND (s.assigned_at AT TIME ZONE 'Europe/Berlin')::date<=p_game_day
 LIMIT 1;

 IF NOT FOUND THEN RETURN jsonb_build_object(
    'status','starter_origin_not_verified','verified',false,
    'initialPositionVerified',false,'readOnly',true,
    'inspectionApproved',false,'flightActivated',false,
    'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;

 RETURN jsonb_build_object(
    'status','verified_initial_starter_origin',
    'verified',true,'initialPositionVerified',true,
    'worldId',1,'airlineId',proof.airline_id,
    'aircraftInventoryId',proof.aircraft_inventory_id,
    'airportKey',proof.initial_home_airport_key,
    'sourceKind',proof.source_kind,
    'assignedGameDate',to_char(
       proof.assigned_at AT TIME ZONE 'Europe/Berlin','YYYY-MM-DD'),
    'readOnly',true,'inspectionApproved',false,
    'notAnAcquisitionInspection',true,
    'notCurrentFlightPosition',true,
    'flightActivated',false,'movementRecorded',false,
    'bookingsCreated',false,'ledgerPosted',false);
END $source$;

REVOKE ALL ON FUNCTION
 airlinerra_game.section9_starter_origin_evidence_v1(uuid,uuid,date)
 FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION
 airlinerra_game.section9_starter_origin_evidence_v1(uuid,uuid,date)
 IS 'Private, read-only original game starter-aircraft airport identity; never treats starter allocation as purchase, inspection or actual operated flight.';
