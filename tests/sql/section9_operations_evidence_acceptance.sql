-- Rollback-only validation of owner-scoped aircraft turnaround and evidence preflight.
BEGIN;
DO $checks$
DECLARE a uuid;u uuid;code text;plane uuid;first_id uuid;second_id uuid;
 result jsonb;is_denied bool:=false;
BEGIN
 SELECT id,owner_player_id,iata_code INTO a,u,code
 FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 IF a IS NULL THEN RAISE EXCEPTION 'Missing known airline test fixture';END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
   airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(a,3,'SECTION9-TURNAROUND-ROLLBACK','owned','in_service')
 RETURNING id INTO plane;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,reference_departure_utc,
  reference_arrival_utc,weekly_schedule,restriction_snapshot,
  created_by_player_id)
 VALUES(a,plane,3,code||'971','OURAIRPORTS:2214','OURAIRPORTS:2212',
  '2026-11-09T09:00:00Z','2026-11-09T10:00:00Z',
  '[{"day":0,"time":"10:00"}]'::jsonb,'{}'::jsonb,u)
 RETURNING id INTO first_id;
 INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1(
  airline_id,aircraft_inventory_id,configuration_id,flight_number,
  origin_airport_key,destination_airport_key,reference_departure_utc,
  reference_arrival_utc,weekly_schedule,restriction_snapshot,
  created_by_player_id)
 VALUES(a,plane,3,code||'972','OURAIRPORTS:2212','OURAIRPORTS:2214',
  '2026-11-09T10:10:00Z','2026-11-09T11:10:00Z',
  '[{"day":0,"time":"11:10"}]'::jsonb,'{}'::jsonb,u)
 RETURNING id INTO second_id;
 result:=airlinerra_game.section9_owned_operational_preflight_v1(
  u,a,first_id,'2026-11-09'::date,14);
 IF (result->'turnaround'->>'shortTurnaroundOccurrences')::integer<1 OR
    (result->'turnaround'->>'minimumMinutes')::integer<=10 OR
    result->>'canActivateNormalFlight'<>'false' OR
    result->'routeRights'->>'operationallyAuthorized'<>'false'
 THEN RAISE EXCEPTION 'Too-short ground time or legal gate not detected: %',result;END IF;
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET weekly_schedule='[{"day":0,"time":"13:30"}]'::jsonb
 WHERE id=second_id;
 result:=airlinerra_game.section9_owned_operational_preflight_v1(
  u,a,first_id,'2026-11-09'::date,14);
 IF (result->'turnaround'->>'shortTurnaroundOccurrences')::integer<>0 OR
    result->>'canActivateNormalFlight'<>'false' OR
    result->'deliveryEvidence'->>'inspectionApproved'<>'false' OR
    result->'crew'->>'assignmentsVerified'<>'false' OR
    result->>'initialPositionVerified'<>'false'
 THEN RAISE EXCEPTION 'Valid provisional ground time must not bypass other gates: %',result;END IF;
 BEGIN
  PERFORM airlinerra_game.section9_owned_operational_preflight_v1(
   gen_random_uuid(),a,first_id,'2026-11-09'::date,14);
 EXCEPTION WHEN SQLSTATE '42501' THEN is_denied:=true;END;
 IF NOT is_denied THEN RAISE EXCEPTION 'Nonowner granted operational preview';END IF;
 IF has_function_privilege('anon',
 'airlinerra_game.section9_owned_operational_preflight_v1(uuid,uuid,uuid,date,integer)',
 'EXECUTE') OR has_table_privilege('authenticated',
 'airlinerra_game.section9_game_turnaround_policy_v1','UPDATE')
 THEN RAISE EXCEPTION 'Public operational policy authority leaked';END IF;
 RAISE NOTICE 'PASS: short turnaround, valid gap, source-evidence gaps, legal advisory, nonowner denial';
END $checks$;
ROLLBACK;