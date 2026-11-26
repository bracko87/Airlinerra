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
-- Production rotation function body; policy/model rows are isolated fixtures.
CREATE TABLE airlinerra_game.section9_crew_scheduler_policy_v2(world_id smallint PRIMARY KEY,preflight_minutes int,postflight_minutes int,maximum_duty_minutes int,minimum_rest_minutes int,maximum_working_days int,working_day_window int);
INSERT INTO airlinerra_game.section9_crew_scheduler_policy_v2 VALUES(1,120,30,720,720,5,7);
CREATE TABLE airlinerra_game.section9_flight_crew_model_policy_v1(configuration_id bigint PRIMARY KEY,qualification_group text,minimum_cabin_crew int,maximum_cabin_crew int);
INSERT INTO airlinerra_game.section9_flight_crew_model_policy_v1 VALUES(1,'family:1',2,5);
CREATE OR REPLACE FUNCTION airlinerra_game.section9_crew_rotation_window_v2(p_legs jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE pol record; leg jsonb; dep timestamptz; arr timestamptz; first_dep timestamptz;
 last_arr timestamptz; first_origin text; last_destination text; orig text; dest text;
 duty_start timestamptz; duty_end timestamptz; flight_minutes numeric:=0;
BEGIN
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 IF p_legs IS NULL OR jsonb_typeof(p_legs)<>'array' THEN RETURN jsonb_build_object('status','invalid_legs');END IF;
 IF jsonb_array_length(p_legs) NOT BETWEEN 1 AND 32 THEN RETURN jsonb_build_object('status','invalid_legs');END IF;
 FOR leg IN SELECT value FROM jsonb_array_elements(p_legs) LOOP
  IF NOT coalesce(leg->>'departureUtc','') ~ '(Z|[+-][0-9]{2}:[0-9]{2})$' OR NOT coalesce(leg->>'arrivalUtc','') ~ '(Z|[+-][0-9]{2}:[0-9]{2})$' THEN
   RETURN jsonb_build_object('status','invalid_leg_time');END IF;
  dep:=(leg->>'departureUtc')::timestamptz;arr:=(leg->>'arrivalUtc')::timestamptz;
  orig:=nullif(btrim(leg->>'originAirportKey'),'');dest:=nullif(btrim(leg->>'destinationAirportKey'),'');
  IF dep IS NULL OR arr IS NULL OR NOT isfinite(dep) OR NOT isfinite(arr) OR arr<=dep OR orig IS NULL OR dest IS NULL OR orig=dest THEN RETURN jsonb_build_object('status','invalid_leg');END IF;
  IF last_arr IS NOT NULL AND dep<last_arr THEN RETURN jsonb_build_object('status','overlapping_flights');END IF;
  IF last_destination IS NOT NULL AND last_destination<>orig THEN RETURN jsonb_build_object('status','crew_wrong_airport');END IF;
  IF first_dep IS NULL THEN first_dep:=dep;first_origin:=orig;END IF;
  last_arr:=arr;last_destination:=dest;flight_minutes:=flight_minutes+extract(epoch FROM arr-dep)/60;
 END LOOP;
 duty_start:=first_dep-make_interval(mins=>pol.preflight_minutes);
 duty_end:=last_arr+make_interval(mins=>pol.postflight_minutes);
 RETURN jsonb_build_object('status',CASE WHEN duty_end-duty_start>make_interval(mins=>pol.maximum_duty_minutes) THEN 'duty_too_long' ELSE 'rotation_preview' END,
 'dutyStartUtc',duty_start,'dutyEndUtc',duty_end,'startingAirport',first_origin,'endingAirport',last_destination,
 'dutyMinutes',extract(epoch FROM duty_end-duty_start)/60,'flightMinutes',flight_minutes,
 'legCount',jsonb_array_length(p_legs),'nextReadyUtc',duty_end+make_interval(mins=>pol.minimum_rest_minutes),
 'dispatchEnforced',false);
EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR invalid_text_representation THEN RETURN jsonb_build_object('status','invalid_leg_time');
END $function$;
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
DO $ferry$
DECLARE s record; owner_id uuid; j jsonb; dep timestamptz; arr timestamptz; first_day date; last_day date;
BEGIN
 SELECT * INTO STRICT s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
 SELECT owner_player_id INTO STRICT owner_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=s.request_id;
 PERFORM set_config('test.storage_hour',s.storage_started_utc::text,true);
 dep:=s.storage_started_utc+interval '3 hours';arr:=dep+interval '7 hours';
 first_day:=(dep AT TIME ZONE 'Europe/Berlin')::date;last_day:=(arr AT TIME ZONE 'Europe/Berlin')::date;
 j:=airlinerra_game.aircraft_storage_ferry_licence_screen_v1(s.airline_id,'storage_reactivation',s.airport_key,'OURAIRPORTS:999',dep,arr);
 IF j->>'allowed' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'missing ferry permission accepted';END IF;
 INSERT INTO airlinerra_game.aircraft_storage_ferry_permissions_v1(world_id,airline_id,purpose,origin_airport_key,destination_airport_key,valid_from_game_date,valid_through_game_date,approval_reference,approved_at)
 VALUES(1,s.airline_id,'storage_reactivation',s.airport_key,'OURAIRPORTS:999',first_day,last_day,'synthetic ferry permission',s.storage_started_utc);
 j:=airlinerra_game.aircraft_storage_ferry_licence_screen_v1(s.airline_id,'storage_reactivation',s.airport_key,'OURAIRPORTS:999',dep,arr);
 IF j->>'allowed' IS DISTINCT FROM 'true' OR j->>'commercialAuthorityGranted' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'ferry permission verification failed: %',j;END IF;
 j:=airlinerra_game.aircraft_storage_ferry_licence_screen_v1(s.airline_id,'storage_inbound','OURAIRPORTS:999',s.airport_key,dep,arr);
 IF j->>'allowed' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'reverse ferry direction accepted';END IF;
 j:=airlinerra_game.aircraft_storage_ferry_licence_screen_v1(s.airline_id,'storage_reactivation',s.airport_key,'OURAIRPORTS:999',dep+interval '2 days',arr+interval '2 days');
 IF j->>'allowed' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'expired ferry permission accepted';END IF;
 UPDATE airlinerra_game.aircraft_storage_ferry_permissions_v1 SET revoked_at=s.storage_started_utc WHERE airline_id=s.airline_id;
 j:=airlinerra_game.aircraft_storage_ferry_licence_screen_v1(s.airline_id,'storage_reactivation',s.airport_key,'OURAIRPORTS:999',dep,arr);
 IF j->>'allowed' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'revoked ferry permission accepted';END IF;
 j:=airlinerra_game.aircraft_storage_crew_requirements_v1(1,s.airport_key,'OURAIRPORTS:999',dep,dep+interval '6 hours');
 IF j->>'requirementsVerified' IS DISTINCT FROM 'true' OR j->>'pilotsRequired' IS DISTINCT FROM '2' OR j->>'crewReserved' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'six-hour crew boundary failed: %',j;END IF;
 j:=airlinerra_game.aircraft_storage_crew_requirements_v1(1,s.airport_key,'OURAIRPORTS:999',dep,arr);
 IF j->>'pilotsRequired' IS DISTINCT FROM '4' OR j->>'minimumCabinCrew' IS DISTINCT FROM '2' OR j->>'allowed' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'replacement crew requirement failed: %',j;END IF;
 j:=airlinerra_game.aircraft_storage_crew_requirements_v1(1,s.airport_key,'OURAIRPORTS:999',dep,dep+interval '10 hours');
 IF j->>'decision' IS DISTINCT FROM 'STORAGE_CREW_DUTY_WINDOW_BLOCKED' THEN RAISE EXCEPTION '12-hour duty limit bypass: %',j;END IF;
 j:=airlinerra_game.aircraft_storage_crew_requirements_v1(1,s.airport_key,'OURAIRPORTS:999',s.storage_started_utc+interval '1 hour',s.storage_started_utc+interval '2 hours');
 IF j->>'decision' IS DISTINCT FROM 'STORAGE_CREW_REPORTING_WINDOW_PASSED' THEN RAISE EXCEPTION 'missed report time accepted: %',j;END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_booking_approvals_v1) THEN RAISE EXCEPTION 'licence/duty preflight generated booking clearance';END IF;
 RAISE NOTICE 'Storage ferry permission and actual rotation duty-window acceptance passed';
END $ferry$;
ROLLBACK TO SAVEPOINT storage_operational_screen;
