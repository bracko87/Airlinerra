-- Cabin attendants are pooled by airline and base; pilots retain their separate roster.
-- Provisional game requirements based on installed seats, not ticket load.
CREATE TABLE airlinerra_game.section9_cabin_crew_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 employment_enabled boolean NOT NULL DEFAULT false,
 payroll_enabled boolean NOT NULL DEFAULT false,
 dispatch_checks_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.section9_cabin_crew_release_v1 VALUES(1,false,false,false);
CREATE TABLE airlinerra_game.section9_cabin_crew_pools_v1(
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 base_airport_key text NOT NULL CHECK(length(base_airport_key) BETWEEN 1 AND 100),
 role text NOT NULL CHECK(role IN('flight_attendant','cabin_supervisor','purser','cabin_crew_instructor')),
 employed_count integer NOT NULL CHECK(employed_count BETWEEN 0 AND 100000),
 monthly_salary_usd numeric(12,2) NOT NULL CHECK(monthly_salary_usd BETWEEN 0 AND 100000),
 version integer NOT NULL DEFAULT 1 CHECK(version>0),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(airline_id,base_airport_key,role)
);
ALTER TABLE airlinerra_game.section9_cabin_crew_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_cabin_crew_pools_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_cabin_crew_release_v1,airlinerra_game.section9_cabin_crew_pools_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.section9_cabin_crew_requirement_v1(p_seats integer)
RETURNS jsonb LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path TO pg_catalog AS $$
 SELECT CASE WHEN p_seats IS NULL OR p_seats NOT BETWEEN 0 AND 1000 THEN
  jsonb_build_object('status','cabin_seats_unverified')
 ELSE jsonb_build_object('status','game_cabin_crew_requirement','installedSeats',p_seats,
  'minimum',CASE WHEN p_seats<=19 THEN 0 ELSE (p_seats+49)/50 END,
  'recommended',CASE WHEN p_seats=0 THEN 0 WHEN p_seats<=19 THEN 1 WHEN p_seats<=250 THEN (p_seats+49)/50+1 WHEN p_seats<=500 THEN (p_seats+49)/50+2 ELSE (p_seats+49)/50+3 END,
  'modelVersion','GAME_CABIN_CREW_V1','regulatoryRequirement',false) END
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_cabin_crew_requirement_v1(integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.section9_owned_cabin_crew_overview_v1(p_player uuid,p_airline uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE fleet jsonb;pools jsonb;req record;flags record;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_CABIN_CREW_WORKER_ONLY';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RETURN jsonb_build_object('status','blocked_airline_not_owned');END IF;
 SELECT * INTO flags FROM airlinerra_game.section9_cabin_crew_release_v1 WHERE world_id=1;
 SELECT coalesce(jsonb_agg(jsonb_build_object('aircraftId',f.id,'registration',f.registration,'requirement',airlinerra_game.section9_cabin_crew_requirement_v1(c.installed_seats)) ORDER BY f.registration),'[]') INTO fleet
 FROM airlinerra_game.airline_aircraft_inventory f LEFT JOIN airlinerra_game.section9_installed_cabin_comfort_v1 c
 ON c.aircraft_inventory_id=f.id AND c.airline_id=f.airline_id AND c.configuration_id=f.configuration_id
 WHERE f.airline_id=p_airline AND f.fleet_status='in_service';
 SELECT coalesce(jsonb_agg(jsonb_build_object('baseAirportKey',p.base_airport_key,'role',p.role,'employedCount',p.employed_count,'monthlySalaryUsd',p.monthly_salary_usd,'version',p.version) ORDER BY p.base_airport_key,p.role),'[]') INTO pools
 FROM airlinerra_game.section9_cabin_crew_pools_v1 p WHERE p.airline_id=p_airline;
 RETURN jsonb_build_object('status','cabin_crew_overview','aircraft',fleet,'pools',pools,'employmentEnabled',flags.employment_enabled,'payrollEnabled',flags.payroll_enabled,'dispatchChecksEnabled',flags.dispatch_checks_enabled,'requirementsPerFlight',true,'availabilityCalculated',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_cabin_crew_overview_v1(uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
