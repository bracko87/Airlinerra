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
CREATE FUNCTION airlinerra_game.section9_crew_duty_fit_v2(p_rotation jsonb,p_existing jsonb,p_home_timezone text,p_initial_airport text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE pol record; s timestamptz;e timestamptz; d record; prev_end timestamptz; prev_dest text;
 report_date date;work_dates date[]:='{}'; day_start date; working_count integer; peak int:=0;
BEGIN
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 IF p_rotation->>'status' IS DISTINCT FROM 'rotation_preview' THEN RETURN jsonb_build_object('status','invalid_rotation','eligible',false);END IF;
 IF p_existing IS NULL OR jsonb_typeof(p_existing)<>'array' OR p_initial_airport IS NULL OR btrim(p_initial_airport)='' OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p_home_timezone) THEN RETURN jsonb_build_object('status','invalid_duty_history','eligible',false);END IF;
 IF jsonb_array_length(p_existing)>366 THEN RETURN jsonb_build_object('status','history_requires_sharding','eligible',false);END IF;
 s:=(p_rotation->>'dutyStartUtc')::timestamptz;e:=(p_rotation->>'dutyEndUtc')::timestamptz;
 IF s IS NULL OR e IS NULL OR NOT isfinite(s) OR NOT isfinite(e) OR e<=s OR e-s>make_interval(mins=>pol.maximum_duty_minutes) THEN RETURN jsonb_build_object('status','invalid_rotation','eligible',false);END IF;
 report_date:=(s AT TIME ZONE p_home_timezone)::date;
 prev_dest:=p_initial_airport;
 FOR d IN SELECT (v->>'dutyStartUtc')::timestamptz ds,(v->>'dutyEndUtc')::timestamptz de,
 v->>'startingAirport' AS origin,v->>'endingAirport' AS destination
 FROM jsonb_array_elements(p_existing||jsonb_build_array(p_rotation)) x(v)
 ORDER BY ds,de LOOP
  IF d.ds IS NULL OR d.de IS NULL OR NOT isfinite(d.ds) OR NOT isfinite(d.de) OR d.de<=d.ds OR d.de-d.ds>make_interval(mins=>pol.maximum_duty_minutes) OR nullif(btrim(d.origin),'') IS NULL OR nullif(btrim(d.destination),'') IS NULL THEN RETURN jsonb_build_object('status','invalid_duty_history','eligible',false);END IF;
  IF prev_end IS NOT NULL AND d.ds<prev_end THEN RETURN jsonb_build_object('status','duty_overlap','eligible',false);END IF;
  IF prev_end IS NOT NULL AND d.ds<prev_end+make_interval(mins=>pol.minimum_rest_minutes) THEN RETURN jsonb_build_object('status','insufficient_rest','eligible',false);END IF;
  IF prev_dest IS DISTINCT FROM d.origin THEN RETURN jsonb_build_object('status','crew_wrong_airport','eligible',false);END IF;
  work_dates:=array_append(work_dates,(d.ds AT TIME ZONE p_home_timezone)::date);
  prev_end:=d.de;prev_dest:=d.destination;
 END LOOP;
 FOR day_start IN SELECT report_date-i FROM generate_series(0,pol.working_day_window-1) i LOOP
  SELECT count(DISTINCT dt) INTO working_count FROM unnest(work_dates) dt WHERE dt BETWEEN day_start AND day_start+pol.working_day_window-1;
  peak:=greatest(peak,working_count);
 END LOOP;
 RETURN jsonb_build_object('status',CASE WHEN peak>pol.maximum_working_days THEN 'working_days_exceeded' ELSE 'duty_fit_preview' END,
 'eligible',peak<=pol.maximum_working_days,'maxWorkingDaysInWindow',peak,'workingDayBasis','home_base_reporting_date','reportDate',report_date,'dispatchEnforced',false);
EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR invalid_text_representation THEN RETURN jsonb_build_object('status','invalid_duty_history','eligible',false);
END $$;

-- Synthetic member inputs; actual duty-fit function is used.
CREATE TABLE airlinerra_game.section9_crew_plan_batches_v1(plan_id uuid PRIMARY KEY,airline_id uuid,status text);
CREATE TABLE airlinerra_game.section9_planned_crew_duties_v1(plan_id uuid,airline_id uuid,employee_id uuid,duty_end_utc timestamptz);
CREATE FUNCTION airlinerra_game.section9_owned_rolling_crew_input_v1(uuid,uuid,timestamptz)
RETURNS jsonb LANGUAGE sql STABLE AS $$SELECT current_setting('test.storage_crew_input')::jsonb$$;
DO $candidates$
DECLARE s record;owner_id uuid;dep timestamptz;rot jsonb;pilot jsonb;member jsonb;inp jsonb;outcome jsonb;hist jsonb;ds timestamptz;plan uuid:=gen_random_uuid();
 cap uuid:='11111111-1111-4111-8111-111111111111';fo uuid:='22222222-2222-4222-8222-222222222222';c1 uuid:='33333333-3333-4333-8333-333333333333';c2 uuid:='44444444-4444-4444-8444-444444444444';
BEGIN
 SELECT * INTO STRICT s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
 SELECT owner_player_id INTO STRICT owner_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=s.request_id;
 PERFORM set_config('test.storage_hour',s.storage_started_utc::text,true);
 dep:=date_trunc('second',s.storage_started_utc+interval '3 hours');
 outcome:=airlinerra_game.owned_aircraft_storage_cost_preview_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep);
 rot:=airlinerra_game.aircraft_storage_crew_requirements_v1(1,s.airport_key,'OURAIRPORTS:999',dep,(outcome->>'arrivalUtc')::timestamptz)->'rotation';
 ds:=(rot->>'dutyStartUtc')::timestamptz;
 pilot:=jsonb_build_object('id',cap,'initialAirport',s.airport_key,'baseTimezone','Europe/Berlin','locationEffectiveUtc',ds-interval '30 days','employmentFrom',(ds-interval '30 days')::date,'history','[]'::jsonb,'absences','[]'::jsonb,
 'permissions',jsonb_build_array(jsonb_build_object('group','family:1','issued',(ds-interval '30 days')::date,'expires',(ds+interval '30 days')::date,'active',true,'captain',true,'firstOfficer',true)));
 IF NOT airlinerra_game.aircraft_storage_crew_candidate_fit_v1(pilot,rot,'family:1','captain') THEN RAISE EXCEPTION 'qualified captain rejected';END IF;
 IF airlinerra_game.aircraft_storage_crew_candidate_fit_v1(pilot||jsonb_build_object('initialAirport','OTHER'),rot,'family:1','captain') THEN RAISE EXCEPTION 'wrong airport accepted';END IF;
 IF airlinerra_game.aircraft_storage_crew_candidate_fit_v1(pilot,rot,'family:2','captain') THEN RAISE EXCEPTION 'wrong family accepted';END IF;
 IF airlinerra_game.aircraft_storage_crew_candidate_fit_v1(pilot||jsonb_build_object('absences',jsonb_build_array(jsonb_build_object('startUtc',ds,'endUtc',ds+interval '1 hour'))),rot,'family:1','captain') THEN RAISE EXCEPTION 'absent employee accepted';END IF;
 hist:=jsonb_build_array(jsonb_build_object('startUtc',ds-interval '10 hours','endUtc',ds-interval '5 hours','origin',s.airport_key,'destination',s.airport_key));
 IF airlinerra_game.aircraft_storage_crew_candidate_fit_v1(pilot||jsonb_build_object('history',hist),rot,'family:1','captain') THEN RAISE EXCEPTION 'insufficient rest accepted';END IF;
 -- Isolate the weekly hours gate from the five-working-day gate.
 UPDATE airlinerra_game.section9_crew_scheduler_policy_v2 SET maximum_working_days=7;
 SELECT jsonb_agg(jsonb_build_object('startUtc',ds-i*interval '24 hours','endUtc',ds-i*interval '24 hours'+interval '12 hours','origin',s.airport_key,'destination',s.airport_key) ORDER BY i DESC) INTO hist FROM generate_series(1,5) i;
 IF airlinerra_game.aircraft_storage_crew_candidate_fit_v1(pilot||jsonb_build_object('history',hist),rot,'family:1','captain') THEN RAISE EXCEPTION 'weekly duty cap bypassed';END IF;
 UPDATE airlinerra_game.section9_crew_scheduler_policy_v2 SET maximum_working_days=5;
 member:=(pilot-'permissions')||jsonb_build_object('role','flight_attendant');
 inp:=jsonb_build_object('status','rolling_crew_input_preview','unboundDeparturesLast7Days',0,'unresolvedCaptureIssues',0,'invalidOccurrenceCount',0,'alreadyReportedFutureFlights',0,
 'pilots',jsonb_build_array(pilot,jsonb_set(jsonb_set(pilot,'{id}',to_jsonb(fo)),'{permissions,0,captain}','false'::jsonb)),
 'cabinMembers',jsonb_build_array(member||jsonb_build_object('id',c1),member||jsonb_build_object('id',c2)));
 PERFORM set_config('test.storage_crew_input',inp::text,true);
 outcome:=airlinerra_game.owned_aircraft_storage_crew_candidates_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep);
 IF outcome->>'status' IS DISTINCT FROM 'storage_crew_candidates_found' OR outcome#>>'{candidateCaptains,0}' IS DISTINCT FROM cap::text OR outcome#>>'{candidateFirstOfficers,0}' IS DISTINCT FROM fo::text OR outcome->>'crewReserved' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'crew selection incorrect: %',outcome;END IF;
 INSERT INTO airlinerra_game.section9_crew_plan_batches_v1 VALUES(plan,s.airline_id,'validated_preview');
 INSERT INTO airlinerra_game.section9_planned_crew_duties_v1 VALUES(plan,s.airline_id,cap,ds+interval '1 day');
 outcome:=airlinerra_game.owned_aircraft_storage_crew_candidates_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep);
 IF outcome->>'status' IS DISTINCT FROM 'storage_crew_candidates_insufficient' THEN RAISE EXCEPTION 'commercial duty conflict not rejected: %',outcome;END IF;
 PERFORM set_config('test.storage_crew_input',(inp||jsonb_build_object('unboundDeparturesLast7Days',1))::text,true);
 outcome:=airlinerra_game.owned_aircraft_storage_crew_candidates_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep);
 IF outcome->>'status' IS DISTINCT FROM 'storage_crew_history_unverified' THEN RAISE EXCEPTION 'incomplete history accepted: %',outcome;END IF;
 RAISE NOTICE 'Storage crew candidate selection acceptance passed (synthetic rolling input, actual duty fit)';
END $candidates$;

ROLLBACK TO SAVEPOINT storage_operational_screen;
