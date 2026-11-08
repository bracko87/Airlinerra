-- Airlinerra World 1, Section 5 + Section 6 server scheduling integration tests.
-- Executable against the connected PostgreSQL by a privileged maintenance role.
-- All aircraft, schedules, airport-capacity changes and reservations ROLLBACK.
BEGIN;
DO $test$
DECLARE
 airline uuid; player uuid; prefix text; plane_a uuid; plane_b uuid;
 first_draft uuid; second_draft uuid; outp jsonb; check_result jsonb;
 denied boolean;
BEGIN
 SELECT a.id,a.owner_player_id,a.iata_code INTO airline,player,prefix
 FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id
   AND w.player_id=a.owner_player_id
 WHERE a.world_id=1 AND w.state='active' AND a.iata_code IS NOT NULL
 LIMIT 1;
 IF airline IS NULL THEN RAISE EXCEPTION 'NO_TEST_AIRLINE_AVAILABLE'; END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(airline,3,'S6-ROLLBACK-A','owned','in_service') RETURNING id INTO plane_a;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(airline,3,'S6-ROLLBACK-B','leased','in_service') RETURNING id INTO plane_b;

 -- A single remote stand: only one movement of each direction per hour.
 UPDATE airlinerra_game.section6_airport_slot_capacity_v1
 SET remote_stands=1,remote_per_direction_10m=1
 WHERE world_id=1 AND airport_key IN ('OURAIRPORTS:2220','OURAIRPORTS:4001');
 outp:=airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
  player,airline,plane_a,prefix||'811','OURAIRPORTS:2220','OURAIRPORTS:4001',
  '2026-11-09 12:00+00','2026-11-09 14:00+00',
  '[{"day":0,"time":"13:00"}]'::jsonb,NULL,'remote','remote');
 first_draft:=(outp->>'scheduleId')::uuid;
 IF outp->>'slotsReserved'<>'true' OR outp->>'status'<>'draft' OR
    outp->>'canActivateNormalFlight'<>'false' THEN
  RAISE EXCEPTION 'VALID_SCHEDULE_DID_NOT_SAVE_AS_LOCKED_DRAFT: %',outp;
 END IF;
 IF (SELECT count(*) FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1
     WHERE schedule_id=first_draft)<>2 THEN
  RAISE EXCEPTION 'MISSING_ORIGIN_OR_DESTINATION_SLOT';
 END IF;

 -- Another flight at 13:20 is in a different 10-minute bucket,
 -- but it MUST still be blocked by the hourly stand capacity.
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
   player,airline,plane_b,prefix||'812','OURAIRPORTS:2220','OURAIRPORTS:4001',
   '2026-11-09 12:20+00','2026-11-09 14:20+00',
   '[{"day":0,"time":"13:20"}]'::jsonb,NULL,'remote','remote');
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
   denied:=SQLERRM='SECTION6_SLOT_UNAVAILABLE';
 END;
 IF NOT denied THEN RAISE EXCEPTION 'HOURLY_CAPACITY_OVERBOOKED'; END IF;

 -- Allow six moves per hour but one in the same 10-minute bucket.
 UPDATE airlinerra_game.section6_airport_slot_capacity_v1
 SET remote_stands=6,remote_per_direction_10m=1
 WHERE world_id=1 AND airport_key IN ('OURAIRPORTS:2220','OURAIRPORTS:4001');
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
   player,airline,plane_b,prefix||'812','OURAIRPORTS:2220','OURAIRPORTS:4001',
   '2026-11-09 12:05+00','2026-11-09 14:05+00',
   '[{"day":0,"time":"13:05"}]'::jsonb,NULL,'remote','remote');
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
   denied:=SQLERRM='SECTION6_SLOT_UNAVAILABLE';
 END;
 IF NOT denied THEN RAISE EXCEPTION 'TEN_MINUTE_CAPACITY_OVERBOOKED'; END IF;

 -- A conflicting edit must preserve the original draft and its reservations.
 UPDATE airlinerra_game.section6_airport_slot_capacity_v1
 SET remote_stands=1,remote_per_direction_10m=1
 WHERE world_id=1 AND airport_key IN ('OURAIRPORTS:2220','OURAIRPORTS:4001');
 outp:=airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
  player,airline,plane_b,prefix||'812','OURAIRPORTS:2220','OURAIRPORTS:4001',
  '2026-11-09 12:00+00','2026-11-09 14:00+00',
  '[{"day":0,"time":"14:00"}]'::jsonb,NULL,'remote','remote');
 second_draft:=(outp->>'scheduleId')::uuid;
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
   player,airline,plane_a,prefix||'811','OURAIRPORTS:2220','OURAIRPORTS:4001',
   '2026-11-09 12:00+00','2026-11-09 14:00+00',
   '[{"day":0,"time":"14:00"}]'::jsonb,first_draft,'remote','remote');
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
   denied:=SQLERRM='SECTION6_SLOT_UNAVAILABLE';
 END;
 IF NOT denied OR
   (SELECT weekly_schedule FROM airlinerra_game.airline_flight_schedule_drafts_v1
    WHERE id=first_draft)<>'[{"day":0,"time":"13:00"}]'::jsonb THEN
  RAISE EXCEPTION 'CONFLICTING_EDIT_MUTATED_ORIGINAL_DRAFT';
 END IF;
 IF (SELECT count(*) FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1
    WHERE schedule_id=first_draft)<>2 THEN
  RAISE EXCEPTION 'CONFLICTING_EDIT_RELEASED_OLD_RESERVATION';
 END IF;

 -- Edit to a free hour: the old hour is released and becomes bookable.
 outp:=airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
  player,airline,plane_a,prefix||'811','OURAIRPORTS:2220','OURAIRPORTS:4001',
  '2026-11-09 12:00+00','2026-11-09 14:00+00',
  '[{"day":0,"time":"15:00"}]'::jsonb,first_draft,'remote','remote');
 IF outp->>'slotsReserved'<>'true' OR (outp->>'version')::integer<>2 THEN
  RAISE EXCEPTION 'VALID_EDIT_FAILED: %',outp;
 END IF;
 check_result:=airlinerra_game.section6_weekly_slot_preflight_v1(
  1::smallint,'OURAIRPORTS:2220','OURAIRPORTS:4001',
  '2026-11-09 12:00+00','2026-11-09 14:00+00',
  '[{"day":0,"time":"13:00"}]'::jsonb,'remote','remote',NULL);
 IF check_result->>'available'<>'true' THEN
  RAISE EXCEPTION 'OLD_SLOT_NOT_RELEASED_AFTER_VALID_EDIT: %',check_result;
 END IF;

 -- Section 5 nighttime restriction: cannot persist slot or draft for a prohibited flight.
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
   player,airline,plane_a,prefix||'813','OURAIRPORTS:2685','OURAIRPORTS:2701',
   '2026-11-09 00:00+00','2026-11-09 02:00+00',
   '[{"day":0,"time":"02:30"}]'::jsonb,NULL,'remote','remote');
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
   denied:=SQLERRM='SCHEDULE_BLOCKED_BY_AIRPORT_OR_AIRCRAFT_RULE';
 END;
 IF NOT denied THEN RAISE EXCEPTION 'NIGHT_CURFEW_DID_NOT_BLOCK_ATOMIC_SCHEDULE'; END IF;

 -- Ownership, stand compatibility and cancellation also remain enforced.
 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
   player,airline,plane_a,prefix||'814','OURAIRPORTS:2220','OURAIRPORTS:4001',
   '2026-11-09 12:00+00','2026-11-09 14:00+00',
   '[{"day":0,"time":"17:00"}]'::jsonb,NULL,'cargo','remote');
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
   denied:=SQLERRM='SECTION6_INCOMPATIBLE_AIRCRAFT_STAND';
 END;
 IF NOT denied THEN RAISE EXCEPTION 'INCOMPATIBLE_STAND_WAS_ACCEPTED'; END IF;

 denied:=false;
 BEGIN
  PERFORM airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
   gen_random_uuid(),airline,plane_a,prefix||'815','OURAIRPORTS:2220','OURAIRPORTS:4001',
   '2026-11-09 12:00+00','2026-11-09 14:00+00',
   '[{"day":0,"time":"18:00"}]'::jsonb,NULL,'remote','remote');
 EXCEPTION WHEN SQLSTATE '42501' THEN denied:=true;
 END;
 IF NOT denied THEN RAISE EXCEPTION 'UNAUTHORIZED_DRAFT_WRITE_SUCCEEDED'; END IF;

 DELETE FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE id=first_draft;
 IF EXISTS (SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1
    WHERE schedule_id=first_draft) THEN
  RAISE EXCEPTION 'DRAFT_CANCELLATION_DID_NOT_RELEASE_SLOTS';
 END IF;
 IF (SELECT count(*) FROM airlinerra_game.airline_flight_schedule_drafts_v1
   WHERE airline_id=airline)<>1 THEN
  RAISE EXCEPTION 'UNEXPECTED_FIXTURE_DRAFT_COUNT';
 END IF;
 RAISE NOTICE 'PASS: atomic schedule/slot saving, hourly and 10-minute overbooking, edits, curfew, ownership, stand type, cancellation, no activation';
END $test$;
ROLLBACK;
