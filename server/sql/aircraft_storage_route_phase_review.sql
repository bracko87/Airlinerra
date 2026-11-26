-- REVIEW ONLY. Derived from live section9_game_route_phase_profile_v1
-- 2026-11-26. Original commercial function unchanged. Estimate only.
BEGIN;
CREATE FUNCTION airlinerra_game.aircraft_storage_timing_endpoint_v1(p_key text,p_storage boolean)
RETURNS TABLE(airport_key text,latitude_deg numeric,longitude_deg numeric,game_category text)
LANGUAGE sql STABLE SET search_path=pg_catalog AS $fn$
 SELECT f.airport_key,p.latitude_deg,p.longitude_deg,
 -- Local taxi timing is a game assumption for dedicated storage airports.
 CASE WHEN f.admission_scope='existing_commercial' THEN coalesce(u.game_category,'Local') ELSE 'Local' END::text
 FROM airlinerra_game.aircraft_storage_facilities_v1 f
 JOIN airlinerra_game.aircraft_storage_airport_operational_profiles_v1 p USING(world_id,airport_key)
 LEFT JOIN airlinerra_game.airport_unified_operations_v1 u USING(world_id,airport_key)
 WHERE current_user='postgres' AND p_storage IS TRUE AND f.world_id=1 AND f.airport_key=p_key AND f.review_state='approved'
 UNION ALL
 SELECT a.airport_key,a.latitude_deg::numeric,a.longitude_deg::numeric,u.game_category::text
 FROM airlinerra_game.airport_reference_profiles a
 JOIN airlinerra_game.airport_unified_operations_v1 u USING(world_id,airport_key)
 JOIN pg_timezone_names z ON z.name=a.timezone_iana
 WHERE current_user='postgres' AND p_storage IS FALSE AND a.world_id=1 AND a.airport_key=p_key
 AND u.operationally_authorized AND u.dispatch_eligible_by_airport_admission;
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_timing_endpoint_v1(text,boolean) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.aircraft_storage_route_phase_profile_v1(p_configuration bigint, p_origin text, p_destination text, p_purpose text, p_scheduled_minutes integer DEFAULT NULL::integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE origin record;destination record;aircraft record;seed text;km numeric;speed numeric;
 taxi_factor numeric;climb_factor numeric;climb_base numeric;descent_base numeric;
 taxi_out numeric;taxi_in numeric;climb numeric;descent numeric;cruise numeric;scale numeric;minutes int;
 out_low int;out_high int;in_low int;in_high int;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_origin IS NULL OR p_destination IS NULL OR p_origin=p_destination
 OR p_purpose IS NULL OR p_purpose NOT IN ('storage_inbound','storage_reactivation') THEN RETURN NULL;END IF;
 IF airlinerra_game.aircraft_storage_airport_admission_v1(CASE WHEN p_purpose='storage_inbound' THEN p_destination ELSE p_origin END,p_purpose)->>'eligible' IS DISTINCT FROM 'true' THEN RETURN NULL;END IF;
 SELECT * INTO origin FROM airlinerra_game.aircraft_storage_timing_endpoint_v1(p_origin,p_purpose='storage_reactivation');
 SELECT * INTO destination FROM airlinerra_game.aircraft_storage_timing_endpoint_v1(p_destination,p_purpose='storage_inbound');
 IF origin.airport_key IS NULL OR destination.airport_key IS NULL OR origin.latitude_deg IS NULL OR origin.longitude_deg IS NULL OR destination.latitude_deg IS NULL OR destination.longitude_deg IS NULL
 THEN RETURN NULL;END IF;
 SELECT m.configuration_id,m.cruise_speed_kmh,c.mtow_kg INTO aircraft
 FROM airlinerra_game.section9_game_fuel_model_snapshot_v1 m
 LEFT JOIN airlinerra.aircraft_catalog_configuration_inventory c ON c.configuration_id=m.configuration_id
 WHERE m.configuration_id=p_configuration AND m.game_calculation_ready;
 IF NOT FOUND OR coalesce(aircraft.cruise_speed_kmh,0)<=0 THEN RETURN NULL;END IF;
 speed:=aircraft.cruise_speed_kmh;
 km:=round((6371.0088*acos(least(1.0,greatest(-1.0,sin(radians(origin.latitude_deg::float8))*sin(radians(destination.latitude_deg::float8))+cos(radians(origin.latitude_deg::float8))*cos(radians(destination.latitude_deg::float8))*cos(radians((destination.longitude_deg-origin.longitude_deg)::float8))))))::numeric);
 IF km<=0 THEN RETURN NULL;END IF;
 seed:=p_origin||'|'||p_destination;
 SELECT lo,hi INTO out_low,out_high FROM (VALUES ('Local',3,9),('Regional',5,11),('Medium',7,14),('Large',9,17),('Major Hub',12,21),('Mega Hub',15,28)) t(category,lo,hi) WHERE category=origin.game_category;
 SELECT lo,hi INTO in_low,in_high FROM (VALUES ('Local',3,6),('Regional',4,8),('Medium',5,10),('Large',7,12),('Major Hub',9,15),('Mega Hub',11,19)) t(category,lo,hi) WHERE category=destination.game_category;
 taxi_factor:=CASE WHEN aircraft.mtow_kg IS NULL OR aircraft.mtow_kg<=0 THEN 1 WHEN aircraft.mtow_kg<20000 THEN .8 WHEN aircraft.mtow_kg<50000 THEN .9 WHEN aircraft.mtow_kg<100000 THEN 1 WHEN aircraft.mtow_kg<200000 THEN 1.15 ELSE 1.3 END;
 taxi_out:=greatest(1,round(airlinerra_game.section9_route_timing_pick_v1(seed||'|taxi-out',coalesce(out_low,7),coalesce(out_high,14))*taxi_factor));
 taxi_in:=greatest(1,round(airlinerra_game.section9_route_timing_pick_v1(seed||'|taxi-in',coalesce(in_low,5),coalesce(in_high,10))*taxi_factor));
 climb_factor:=least(1,greatest(.35,(km/speed*60+10)/45));
 climb_base:=airlinerra_game.section9_route_timing_pick_v1(seed||'|climb',CASE WHEN km<300 THEN 10 ELSE 12 END,CASE WHEN km<300 THEN 14 ELSE 20 END);
 descent_base:=airlinerra_game.section9_route_timing_pick_v1(seed||'|descent',CASE WHEN km<300 THEN 10 ELSE 12 END,CASE WHEN km<300 THEN 14 ELSE 20 END);
 climb:=greatest(3,round(climb_base*climb_factor));descent:=greatest(3,round(descent_base*climb_factor));
 scale:=least(1,km/((climb+descent)*speed*.65/60));
 cruise:=greatest(0,km-(climb+descent)*speed*.65/60*scale)/speed*60;
 climb:=greatest(1,round(climb*scale));descent:=greatest(1,round(descent*scale));cruise:=greatest(1,round(cruise));
 minutes:=(taxi_out+taxi_in+climb+descent+cruise)::int;
 -- Legacy exact-duration schedules retain their timetable. New schedules
 -- always use the unscaled game profile. Preserve at least one minute/phase.
 IF p_scheduled_minutes IS NOT NULL AND p_scheduled_minutes<>minutes THEN
  IF p_scheduled_minutes NOT BETWEEN 5 AND 1800 THEN RETURN NULL;END IF;
  scale:=p_scheduled_minutes::numeric/minutes;
  taxi_out:=greatest(1,least(p_scheduled_minutes-4,round(taxi_out*scale)));
  climb:=greatest(1,least(p_scheduled_minutes-taxi_out-3,round(climb*scale)));
  descent:=greatest(1,least(p_scheduled_minutes-taxi_out-climb-2,round(descent*scale)));
  taxi_in:=greatest(1,least(p_scheduled_minutes-taxi_out-climb-descent-1,round(taxi_in*scale)));
  cruise:=p_scheduled_minutes-taxi_out-climb-descent-taxi_in;
  minutes:=p_scheduled_minutes;
 END IF;
 RETURN jsonb_build_object('model','AIRLINERRA_STORAGE_GAME_PHASES_V1','distanceKm',km,'totalMinutes',minutes,
 'taxiOutMinutes',taxi_out,'climbMinutes',climb,'cruiseMinutes',cruise,'descentMinutes',descent,'taxiInMinutes',taxi_in);

END $function$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_route_phase_profile_v1(bigint,text,text,text,integer) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
