-- Synthetic screening inputs. Existing commercial screen functions are
-- represented by explicit doubles; storage-only calculations run for real.
SAVEPOINT storage_operational_screen;
CREATE TABLE airlinerra_game.section5_full_weight_aircraft_reference_v2(configuration_id bigint PRIMARY KEY,game_full_weight_takeoff_reference_m numeric,game_full_weight_landing_reference_m numeric,game_formula_version text);
CREATE TABLE airlinerra_game.section5_full_weight_airport_aircraft_screen_v2(world_id smallint,airport_key text,configuration_id bigint,high_elevation_needs_site_specific_review boolean,full_weight_takeoff_length_pass boolean,full_weight_landing_length_pass boolean,runway_reference_source_id text,formula_version text);
CREATE TABLE airlinerra_game.section5_icao_aircraft_certification_v2(configuration_id bigint PRIMARY KEY,official_icao_chapter smallint,noise_certificate_status text);
INSERT INTO airlinerra_game.section5_full_weight_aircraft_reference_v2 VALUES(1,2000,1800,'fixture');
INSERT INTO airlinerra_game.section5_full_weight_airport_aircraft_screen_v2 VALUES(1,'OURAIRPORTS:999',1,false,true,true,'fixture','fixture');
INSERT INTO airlinerra_game.section5_icao_aircraft_certification_v2 VALUES(1,14,'CERTIFICATE_CONFIGURATION_MATCHED');
CREATE FUNCTION airlinerra_game.section5_simplified_airport_leg_screen_v1(smallint,text,bigint,text,timestamptz) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('gameHardBlocked',false,'needsReview',false)$$;
CREATE FUNCTION airlinerra_game.section5_universal_airport_leg_restriction_v1(smallint,text,bigint,text,timestamptz,text) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('gameHardBlocked',false,'needsReview',false)$$;
CREATE FUNCTION airlinerra_game.section9_canonical_aoc_covers_v1(uuid,date,integer) RETURNS boolean LANGUAGE sql AS $$SELECT true$$;
CREATE FUNCTION airlinerra_game.section9_game_route_licence_scope_v1(uuid,text,text,date,integer) RETURNS jsonb LANGUAGE sql AS $$SELECT jsonb_build_object('allowed',true)$$;
DO $test$
DECLARE s record; owner_id uuid; j jsonb; v_now timestamptz; airport text:='OURAIRPORTS:316427';
BEGIN
 SELECT * INTO STRICT s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
 SELECT owner_player_id INTO STRICT owner_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=s.request_id;
 v_now:=s.storage_started_utc;
 PERFORM set_config('test.storage_hour',v_now::text,true);
 UPDATE airlinerra_game.aircraft_storage_airport_operational_profiles_v1 SET reviewed_at=v_now-interval '1 hour' WHERE airport_key=airport;
 j:=airlinerra_game.aircraft_storage_leg_airport_screen_v1(airport,1,'departure',v_now,true);
 IF j->>'status' IS DISTINCT FROM 'storage_operational_rules_missing' THEN RAISE EXCEPTION 'missing storage rules accepted: %',j;END IF;
 INSERT INTO airlinerra_game.aircraft_storage_only_airport_rules_v1 VALUES(1,airport,1.1,40,false,NULL,NULL,false,NULL,'fixture',v_now);
 j:=airlinerra_game.aircraft_storage_leg_airport_screen_v1(airport,1,'departure',v_now,true);
 IF j->>'passed' IS DISTINCT FROM 'true' OR (j->>'requiredRunwayM')::numeric IS DISTINCT FROM 2200::numeric OR j->>'dispatchAuthorized' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'storage runway screen incorrect: %',j;END IF;
 UPDATE airlinerra_game.aircraft_storage_only_airport_rules_v1 SET runway_elevation_factor=1.5 WHERE airport_key=airport;
 j:=airlinerra_game.aircraft_storage_leg_airport_screen_v1(airport,1,'departure',v_now,true);
 IF j->>'status' IS DISTINCT FROM 'storage_runway_screen_blocked' THEN RAISE EXCEPTION 'short runway accepted: %',j;END IF;
 UPDATE airlinerra_game.aircraft_storage_only_airport_rules_v1 SET runway_elevation_factor=1.1,nighttime_ban=true,curfew_start_local='23:00',curfew_end_local='06:00' WHERE airport_key=airport;
 j:=airlinerra_game.aircraft_storage_leg_airport_screen_v1(airport,1,'departure',timestamp '2026-11-27 01:00' AT TIME ZONE 'Europe/Madrid',true);
 IF j->>'status' IS DISTINCT FROM 'storage_curfew_blocked' THEN RAISE EXCEPTION 'overnight curfew bypass: %',j;END IF;
 UPDATE airlinerra_game.aircraft_storage_only_airport_rules_v1 SET nighttime_ban=false,curfew_start_local=NULL,curfew_end_local=NULL,noise_restrictions=true,permitted_noise_chapters=ARRAY[4]::smallint[] WHERE airport_key=airport;
 j:=airlinerra_game.aircraft_storage_leg_airport_screen_v1(airport,1,'departure',v_now,true);
 IF j->>'passed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'chapter 14 rejected by chapter 4 rule: %',j;END IF;
 UPDATE airlinerra_game.section5_icao_aircraft_certification_v2 SET official_icao_chapter=3 WHERE configuration_id=1;
 j:=airlinerra_game.aircraft_storage_leg_airport_screen_v1(airport,1,'departure',v_now,true);
 IF j->>'status' IS DISTINCT FROM 'storage_noise_chapter_blocked' THEN RAISE EXCEPTION 'noise restriction bypass: %',j;END IF;
 UPDATE airlinerra_game.section5_icao_aircraft_certification_v2 SET noise_certificate_status='UNKNOWN' WHERE configuration_id=1;
 j:=airlinerra_game.aircraft_storage_leg_airport_screen_v1(airport,1,'departure',v_now,true);
 IF j->>'status' IS DISTINCT FROM 'storage_noise_certificate_unverified' THEN RAISE EXCEPTION 'unverified certificate accepted: %',j;END IF;
 UPDATE airlinerra_game.section5_icao_aircraft_certification_v2 SET noise_certificate_status='CERTIFICATE_CONFIGURATION_MATCHED',official_icao_chapter=14 WHERE configuration_id=1;
 j:=airlinerra_game.owned_aircraft_storage_operational_screen_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',date_trunc('second',v_now+interval '1 hour'));
 IF j->>'airportScreenPassed' IS DISTINCT FROM 'true' OR j#>>'{licenceScreen,decision}' IS DISTINCT FROM 'STORAGE_FERRY_LICENCE_REVIEW_REQUIRED' OR j->>'clearanceGenerated' IS DISTINCT FROM 'false' OR j->>'bookingEligible' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'incomplete clearance incorrectly released: %',j;END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_booking_approvals_v1) THEN RAISE EXCEPTION 'read-only preflight generated approval';END IF;
 RAISE NOTICE 'Storage operational screen acceptance passed (synthetic commercial-screen inputs)';
END $test$;
ROLLBACK TO SAVEPOINT storage_operational_screen;
