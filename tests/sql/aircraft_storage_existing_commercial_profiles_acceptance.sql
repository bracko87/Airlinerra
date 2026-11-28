-- Isolated copy of the three existing game airport rows from read-only audit
-- 2026-11-27. No external runway certification implied.
CREATE TABLE airlinerra_game.airport_runway_inventory(world_id smallint,airport_key text,source_runway_id text,length_m numeric,width_m numeric,surface_reported text,verification text);
CREATE TABLE airlinerra_game.airport_facilities(world_id smallint,airport_key text,fuel_available boolean);
INSERT INTO airlinerra_game.airport_reference_profiles VALUES
(1,'OURAIRPORTS:26900',-23.806588,133.903427,'Australia/Darwin'),
(1,'OURAIRPORTS:3856',33.301601,-104.530998,'America/Denver'),
(1,'OURAIRPORTS:4073',43.178699,-0.006439,'Europe/Paris');
INSERT INTO airlinerra_game.airport_unified_operations_v1 VALUES
(1,'OURAIRPORTS:26900','Medium',true,true),(1,'OURAIRPORTS:3856','Large',true,true),(1,'OURAIRPORTS:4073','Medium',true,true);
INSERT INTO airlinerra_game.airport_runway_inventory VALUES
(1,'OURAIRPORTS:26900','233325',2438.1,45.1,'ASP','historical_unverified'),
(1,'OURAIRPORTS:3856','244235',3050.4,30.5,'ASP','historical_unverified'),
(1,'OURAIRPORTS:4073','235930',3000.1,45.1,'ASP','historical_unverified');
-- Non-landing tariff fields below are synthetic and not consumed by staging.
INSERT INTO airlinerra_game.section8_airport_operating_tariffs_v1 VALUES
(1,'OURAIRPORTS:26900',812,0.16,0.2,1,100,50,'background_adjusted_v3','GAME_ESTIMATE_NOT_REAL_AERONAUTICAL_TARIFF'),
(1,'OURAIRPORTS:3856',1875,0.18,0.2,1,100,50,'background_adjusted_v3','GAME_ESTIMATE_NOT_REAL_AERONAUTICAL_TARIFF'),
(1,'OURAIRPORTS:4073',1000,0.16,0.2,1,100,50,'background_adjusted_v3','GAME_ESTIMATE_NOT_REAL_AERONAUTICAL_TARIFF');
INSERT INTO airlinerra_game.section6_airport_slot_capacity_v1 VALUES(1,'OURAIRPORTS:26900',4,1),(1,'OURAIRPORTS:3856',5,1),(1,'OURAIRPORTS:4073',1,1);
INSERT INTO airlinerra_game.airport_facilities VALUES(1,'OURAIRPORTS:26900',true),(1,'OURAIRPORTS:3856',true),(1,'OURAIRPORTS:4073',true);
DO $test$
DECLARE j jsonb;
BEGIN
 UPDATE airlinerra_game.airport_facilities SET fuel_available=false WHERE airport_key='OURAIRPORTS:4073';
 j:=airlinerra_game.stage_existing_commercial_storage_profiles_v1();
 IF j->>'staged' IS DISTINCT FROM 'false' OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1) THEN RAISE EXCEPTION 'partial commercial profile staging: %',j;END IF;
 UPDATE airlinerra_game.airport_facilities SET fuel_available=true WHERE airport_key='OURAIRPORTS:4073';
 j:=airlinerra_game.stage_existing_commercial_storage_profiles_v1();
 IF j->>'staged' IS DISTINCT FROM 'true' OR j->>'profileCount' IS DISTINCT FROM '3' THEN RAISE EXCEPTION 'commercial profile staging failed: %',j;END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1 WHERE airport_key='OURAIRPORTS:26900' AND runway_length_m=2438.1 AND landing_fee_usd=812 AND departure_fee_usd=129.92)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1 WHERE airport_key='OURAIRPORTS:3856' AND runway_length_m=3050.4 AND landing_fee_usd=1875 AND departure_fee_usd=337.50)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1 WHERE airport_key='OURAIRPORTS:4073' AND runway_length_m=3000.1 AND landing_fee_usd=1000 AND departure_fee_usd=160)
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE review_state<>'candidate')
 OR airlinerra_game.aircraft_storage_airport_admission_v1('OURAIRPORTS:26900','storage_inbound')->>'eligible' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION 'staged profile data or admission mismatch';END IF;
 j:=airlinerra_game.stage_existing_commercial_storage_profiles_v1();
 IF j->>'staged' IS DISTINCT FROM 'true' OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1)<>3 THEN RAISE EXCEPTION 'profile staging replay failed';END IF;
 RAISE NOTICE 'Three dual-use storage operational profiles staged from audited game rows; failed staging rolls back; no admission changed';
END $test$;
