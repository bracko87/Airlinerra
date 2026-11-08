-- Read-only rotation preview tested with temporary owned flight schedules.
BEGIN;
DO $test$
DECLARE a uuid;u uuid;code text;plane uuid;s1 uuid;s2 uuid;v jsonb;denied bool:=false;
BEGIN
 SELECT id,owner_player_id,iata_code INTO a,u,code
 FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 IF a IS NULL THEN RAISE EXCEPTION 'Missing regression airline';END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(a,3,'SECTION9-ROTATION-ROLLBACK','owned','in_service')
 RETURNING id INTO plane;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,reference_departure_utc,
  reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(a,plane,3,code||'961','OURAIRPORTS:2214','OURAIRPORTS:2212',
  '2026-11-09T09:00:00Z','2026-11-09T10:00:00Z',
  '[{"day":0,"time":"10:00"}]'::jsonb,'{}'::jsonb,u) RETURNING id INTO s1;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,reference_departure_utc,
  reference_arrival_utc,weekly_schedule,restriction_snapshot,created_by_player_id)
 VALUES(a,plane,3,code||'962','OURAIRPORTS:2212','OURAIRPORTS:2214',
  '2026-11-09T09:30:00Z','2026-11-09T10:30:00Z',
  '[{"day":0,"time":"10:30"}]'::jsonb,'{}'::jsonb,u) RETURNING id INTO s2;
 v:=airlinerra_game.section9_owned_aircraft_rotation_preview_v1(
  u,a,s1,'2026-11-09'::date,14);
 IF (v->>'overlappingFlights')::int<1 OR v->>'canActivateNormalFlight'<>'false'
 THEN RAISE EXCEPTION 'Overlapping aircraft flights not caught: %',v;END IF;
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1 SET
  weekly_schedule='[{"day":0,"time":"12:30"}]'::jsonb WHERE id=s2;
 v:=airlinerra_game.section9_owned_aircraft_rotation_preview_v1(
  u,a,s1,'2026-11-09'::date,14);
 IF (v->>'overlappingFlights')::int<>0 OR
   (v->>'wrongAirportDepartures')::int<>0 OR
    v->>'status'<>'ROTATION_PREVIEW_NO_CONFLICTS' OR
    v->>'initialAircraftPositionVerified'<>'false'
 THEN RAISE EXCEPTION 'Valid two-leg weekly rotation rejected: %',v;END IF;
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1 SET
  origin_airport_key='OURAIRPORTS:2210' WHERE id=s2;
 v:=airlinerra_game.section9_owned_aircraft_rotation_preview_v1(
  u,a,s1,'2026-11-09'::date,14);
 IF (v->>'wrongAirportDepartures')::int<1
 THEN RAISE EXCEPTION 'Aircraft teleportation not caught: %',v;END IF;
 BEGIN
  PERFORM airlinerra_game.section9_owned_aircraft_rotation_preview_v1(
   gen_random_uuid(),a,s1,'2026-11-09'::date,14);
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true; END;
 IF NOT denied THEN RAISE EXCEPTION 'Nonowner preview allowed';END IF;
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
  SET origin_airport_key='OURAIRPORTS:2212' WHERE id=s2;
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
  SET weekly_schedule='[{"day":6,"time":"02:30"}]'::jsonb WHERE id=s1;
 v:=airlinerra_game.section9_owned_aircraft_rotation_preview_v1(
  u,a,s1,'2026-03-29'::date,14);
 IF (v->>'daylightSavingTimeIssues')::int<1
 THEN RAISE EXCEPTION 'DST nonexistent 02:30 flight not caught: %',v;END IF;
 IF has_function_privilege('anon',
  'airlinerra_game.section9_owned_aircraft_rotation_preview_v1(uuid,uuid,uuid,date,integer)',
  'EXECUTE') OR has_function_privilege('authenticated',
  'airlinerra_game.section9_owned_aircraft_rotation_preview_v1(uuid,uuid,uuid,date,integer)',
  'EXECUTE')
 THEN RAISE EXCEPTION 'Public rotation DB access leaked';END IF;
 RAISE NOTICE 'PASS overlap, feasible rotation, wrong airport, owner isolation, DST, private API';
END $test$;
ROLLBACK;