-- Safe World 1 regression tests for dynamic airport, runway and certificate restrictions.
-- BEGIN/ROLLBACK keeps all temporary runway test rules out of production.
-- Execute in privileged maintenance context; the functions are not public RPCs.
BEGIN;
DO $test$
DECLARE
 gate jsonb; leg jsonb;
BEGIN
 gate:=airlinerra_game.section5_universal_route_restriction_gate_v1(
  1::smallint,'OURAIRPORTS:5564','OURAIRPORTS:2218',3::bigint,
  '2026-11-05T14:30:00Z'::timestamptz,'2026-11-05T19:00:00Z'::timestamptz);
 IF gate->>'decision'<>'BLOCKED_BY_GAME_AIRPORT_RUNWAY_OR_NOISE_RESTRICTION'
    OR gate#>>'{origin,decision}'<>'BLOCKED_AIRPORT_TIME_CURFEW'
 THEN RAISE EXCEPTION 'Fukuoka nighttime curfew regression: %',gate; END IF;

 gate:=airlinerra_game.section5_universal_route_restriction_gate_v1(
  1::smallint,'OURAIRPORTS:19570','OURAIRPORTS:2218',3::bigint,
  '2026-11-05T11:00:00Z'::timestamptz,'2026-11-05T12:00:00Z'::timestamptz);
 IF gate#>>'{origin,decision}'<>'BLOCKED_GAME_RUNWAY_LENGTH'
 THEN RAISE EXCEPTION 'Full weight/short runway regression: %',gate; END IF;

 gate:=airlinerra_game.section5_universal_route_restriction_gate_v1(
  1::smallint,'OURAIRPORTS:4185','OURAIRPORTS:2218',3::bigint,
  '2026-11-05T11:00:00Z'::timestamptz,'2026-11-05T13:00:00Z'::timestamptz);
 IF gate->>'decision'<>'REVIEW_REQUIRED_GAME_RESTRICTION_SCREEN'
    OR (gate->>'gameHardBlocked')::boolean
    OR (gate->>'canActivateNormalFlight')::boolean
 THEN RAISE EXCEPTION 'Unverified source must not create false ban or activation: %',gate; END IF;

 gate:=airlinerra_game.section5_universal_route_restriction_gate_v1(
  1::smallint,'OURAIRPORTS:2218','OURAIRPORTS:4185',3::bigint,
  '2026-11-05T13:00:00Z'::timestamptz,'2026-11-05T15:00:00Z'::timestamptz,
  'NO_SUCH_RUNWAY',NULL);
 IF gate#>>'{origin,decision}'<>'BLOCKED_INVALID_RUNWAY_SELECTION'
 THEN RAISE EXCEPTION 'Invalid specific runway not rejected: %',gate; END IF;

 gate:=airlinerra_game.section5_universal_route_restriction_gate_v1(
  1::smallint,'OURAIRPORTS:2218','OURAIRPORTS:4185',999999::bigint,
  '2026-11-05T13:00:00Z'::timestamptz,'2026-11-05T15:00:00Z'::timestamptz);
 IF gate#>>'{origin,decision}'<>'BLOCKED_UNKNOWN_AIRPORT_OR_AIRCRAFT'
 THEN RAISE EXCEPTION 'Unknown aircraft reference must fail closed: %',gate; END IF;

 IF NOT airlinerra_game.section5_local_restriction_window_match_v1(
  '2026-11-09 00:30:00'::timestamp,'22:00'::time,'07:00'::time,
  ARRAY[7]::smallint[],'2026-11-08'::date,'2026-11-08'::date)
 OR airlinerra_game.section5_local_restriction_window_match_v1(
  '2026-11-09 08:00:00'::timestamp,'22:00'::time,'07:00'::time,ARRAY[7]::smallint[])
 THEN RAISE EXCEPTION 'Cross-midnight weekday/seasonal logic regression'; END IF;
END;
$test$;

-- Artificial temporary data proves per-runway enforcement without changing permanent rules.
INSERT INTO airlinerra_game.section5_runway_specific_restrictions_v1(
 world_id,airport_key,source_runway_id,rule_code,rule_kind,affected_operation,
 local_start,local_end,active_from,active_until,enforce_in_game,
 source_url,evidence_note,checked_on)
VALUES (
 1,'OURAIRPORTS:2218','236229','TEST_ONLY_08L_TEMP_CURFEW','RUNWAY_TIME_CLOSURE','departure',
 '12:00'::time,'14:00'::time,'2026-11-05','2026-11-05',true,
 'https://example.invalid/test-only-no-real-rule','ROLLBACK TEST FIXTURE','2026-11-06'
);

DO $test$
DECLARE fixed jsonb; alternative jsonb; automatic jsonb; uncertified jsonb; certified jsonb;
BEGIN
 fixed:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:2218',3::bigint,'departure','2026-11-05T11:30:00Z'::timestamptz,'236229');
 alternative:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:2218',3::bigint,'departure','2026-11-05T11:30:00Z'::timestamptz,'236228');
 automatic:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:2218',3::bigint,'departure','2026-11-05T11:30:00Z'::timestamptz);
 IF fixed->>'decision'<>'BLOCKED_SPECIFIC_RUNWAY_RULE'
    OR (alternative->>'gameHardBlocked')::boolean
    OR (automatic->>'gameHardBlocked')::boolean
    OR automatic->>'selectedRunwaySourceId'='236229'
 THEN RAISE EXCEPTION 'Named runway closure / alternative runway selection failure: %, %, %',
  fixed,alternative,automatic; END IF;

 INSERT INTO airlinerra_game.section5_runway_specific_restrictions_v1(
  world_id,airport_key,source_runway_id,rule_code,rule_kind,affected_operation,
  local_start,local_end,prohibited_icao_chapters,enforce_in_game,
  source_url,evidence_note,checked_on)
 VALUES (
  1,'OURAIRPORTS:2218','236228','TEST_ONLY_CERTIFIED_CH4','RUNWAY_NOISE_CHAPTER_BAN','departure',
  '00:00'::time,'00:00'::time,ARRAY[4]::smallint[],true,
  'https://example.invalid/test-only-no-real-rule','ROLLBACK TEST FIXTURE','2026-11-06');
 uncertified:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
  1::smallint,'OURAIRPORTS:2218',3::bigint,'departure',
  '2026-11-05T11:30:00Z'::timestamptz,'236228');
 certified:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
  1::smallint,'OURAIRPORTS:2218',57::bigint,'departure',
  '2026-11-05T11:30:00Z'::timestamptz,'236228');
 IF (uncertified->>'gameHardBlocked')::boolean
    OR certified->>'decision'<>'BLOCKED_SPECIFIC_RUNWAY_RULE'
 THEN RAISE EXCEPTION 'Noise Chapter bans require matched aircraft certificate: %, %',uncertified,certified;
 END IF;
 RAISE NOTICE 'PASS: night curfew, runway lengths, invalid runway, unknown references, DST calendar, named runway restrictions, alternative runway, matched noise cert, no accidental activation';
END;
$test$;

ROLLBACK;
