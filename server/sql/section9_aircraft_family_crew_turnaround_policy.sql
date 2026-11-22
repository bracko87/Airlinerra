-- Game-design estimates, not certified type ratings, aircraft limits or regulations.
-- Configurations remain linked to the existing aircraft catalogue.
CREATE TABLE airlinerra_game.section9_flight_crew_model_policy_v1(
 configuration_id bigint PRIMARY KEY REFERENCES airlinerra.aircraft_configurations(id),
 qualification_group text NOT NULL,
 family_id bigint NOT NULL REFERENCES airlinerra.aircraft_families(id),
 reference_seats integer NOT NULL CHECK(reference_seats BETWEEN 0 AND 1000),
 seat_basis text NOT NULL CHECK(seat_basis IN('catalogue_maximum','catalogue_typical','cargo_zero')),
 minimum_cabin_crew integer NOT NULL CHECK(minimum_cabin_crew BETWEEN 0 AND 20),
 maximum_cabin_crew integer NOT NULL CHECK(maximum_cabin_crew BETWEEN minimum_cabin_crew AND 40),
 minimum_turnaround_minutes integer NOT NULL CHECK(minimum_turnaround_minutes BETWEEN 15 AND 360),
 maximum_turnaround_minutes integer NOT NULL CHECK(maximum_turnaround_minutes BETWEEN minimum_turnaround_minutes AND 360),
 model_version text NOT NULL DEFAULT 'GAME_FLIGHT_CREW_V1' CHECK(model_version='GAME_FLIGHT_CREW_V1'),
 CHECK(qualification_group ~ '^(family:[0-9]+|atr:42-72)$')
);
ALTER TABLE airlinerra_game.section9_flight_crew_model_policy_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_flight_crew_model_policy_v1 FROM PUBLIC,anon,authenticated,service_role;
WITH source AS (
 SELECT c.id,c.use_type,v.model_name,f.id family_id,f.family_name,f.aircraft_class,f.propulsion_class,
 CASE WHEN c.use_type='cargo' THEN 0 ELSE coalesce(c.maximum_passenger_seats,c.typical_passenger_seats) END seats,
 CASE WHEN c.use_type='cargo' THEN 'cargo_zero' WHEN c.maximum_passenger_seats IS NOT NULL THEN 'catalogue_maximum' ELSE 'catalogue_typical' END seat_basis
 FROM airlinerra.aircraft_configurations c JOIN airlinerra.aircraft_variants v ON v.id=c.variant_id JOIN airlinerra.aircraft_families f ON f.id=v.family_id
), base AS (
 SELECT *,CASE WHEN seats<=19 THEN 0 ELSE (seats+49)/50 END min_crew,
 CASE WHEN use_type='cargo' THEN CASE WHEN aircraft_class='widebody' THEN 75 WHEN aircraft_class='narrowbody' THEN 50 ELSE 35 END
 WHEN family_name='A380' THEN 90
 WHEN family_name='787' THEN 65
 WHEN family_name='A320' AND model_name ILIKE '%A319%' THEN 35
 WHEN family_name='A320' AND model_name ILIKE '%A321%' THEN 45
 WHEN family_name='A320' THEN 40
 WHEN family_name='ATR 72' THEN 25
 WHEN seats<=19 THEN 20 WHEN seats<=50 THEN 25 WHEN seats<=100 THEN 30 WHEN seats<=150 THEN 35
 WHEN seats<=200 THEN 40 WHEN seats<=250 THEN 45 WHEN seats<=350 THEN 60 WHEN seats<=450 THEN 70 ELSE 85 END min_turn
 FROM source WHERE seats BETWEEN 0 AND 1000
), limits AS (
 SELECT *,CASE WHEN seats=0 THEN 0 WHEN seats<=19 THEN 1
 WHEN family_name='A380' THEN greatest(min_crew,25)
 WHEN family_name='787' THEN greatest(min_crew,12)
 WHEN family_name='A320' AND model_name ILIKE '%A319%' THEN greatest(min_crew,5)
 WHEN family_name='A320' AND model_name ILIKE '%A321%' THEN greatest(min_crew,7)
 WHEN family_name='A320' THEN greatest(min_crew,6)
 WHEN family_name='ATR 72' THEN greatest(min_crew,3)
 ELSE greatest(min_crew+1,ceil(min_crew*1.5)::integer) END max_crew,
 CASE WHEN use_type='cargo' THEN min_turn+30
 WHEN family_name='A380' THEN 140 WHEN family_name='787' THEN 100
 WHEN family_name='A320' AND model_name ILIKE '%A319%' THEN 55
 WHEN family_name='A320' AND model_name ILIKE '%A321%' THEN 70
 WHEN family_name='A320' THEN 60 WHEN family_name='ATR 72' THEN 40
 ELSE ceil(min_turn*1.5/5)::integer*5 END max_turn
 FROM base
)
INSERT INTO airlinerra_game.section9_flight_crew_model_policy_v1(configuration_id,qualification_group,family_id,reference_seats,seat_basis,minimum_cabin_crew,maximum_cabin_crew,minimum_turnaround_minutes,maximum_turnaround_minutes)
SELECT id,CASE WHEN family_id IN(15,16) THEN 'atr:42-72' ELSE 'family:'||family_id::text END,family_id,seats,seat_basis,min_crew,max_crew,min_turn,max_turn FROM limits;
CREATE FUNCTION airlinerra_game.section9_flight_crew_requirements_v1(p_configuration bigint,p_installed_seats integer,p_flight_minutes integer)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE p record; min_cabin integer; captains integer;
BEGIN
 SELECT * INTO p FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=p_configuration;
 IF NOT FOUND OR p_installed_seats IS NULL OR p_installed_seats NOT BETWEEN 0 AND 1000 OR p_flight_minutes IS NULL OR p_flight_minutes NOT BETWEEN 1 AND 1440 THEN
  RETURN jsonb_build_object('status','crew_requirements_unverified');END IF;
 IF (p.seat_basis='cargo_zero' AND p_installed_seats<>0) OR (p.seat_basis<>'cargo_zero' AND p_installed_seats=0) THEN
  RETURN jsonb_build_object('status','crew_configuration_seat_mismatch');END IF;
 min_cabin:=CASE WHEN p_installed_seats<=19 THEN 0 ELSE (p_installed_seats+49)/50 END;
 IF min_cabin>p.maximum_cabin_crew THEN RETURN jsonb_build_object('status','crew_configuration_requires_review');END IF;
 captains:=CASE WHEN p_flight_minutes>360 THEN 2 ELSE 1 END;
 RETURN jsonb_build_object('status','game_flight_crew_requirements','configurationId',p_configuration,'qualificationGroup',p.qualification_group,'installedSeats',p_installed_seats,
 'captains',captains,'firstOfficers',captains,'totalPilots',captains*2,'replacementPilots',CASE WHEN captains=2 THEN 2 ELSE 0 END,'minimumCabinCrew',min_cabin,'maximumCabinCrew',p.maximum_cabin_crew,'minimumTurnaroundMinutes',p.minimum_turnaround_minutes,'maximumTurnaroundMinutes',p.maximum_turnaround_minutes,'modelVersion',p.model_version,'regulatoryRequirement',false,'dispatchEnforced',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_flight_crew_requirements_v1(bigint,integer,integer) FROM PUBLIC,anon,authenticated,service_role;
