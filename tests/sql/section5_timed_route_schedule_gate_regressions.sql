-- Section 5 non-mutating SQL regression suite: run against World 1 after a gate change.
DO $tests$
DECLARE verdict text;
BEGIN
 SELECT airlinerra_game.section5_timed_route_schedule_gate_v1(
 1::smallint,'OURAIRPORTS:2513','OURAIRPORTS:2218',30::bigint,
 '2026-11-05T12:00:00Z'::timestamptz,'2026-11-05T14:00:00Z'::timestamptz)->>'decision'
 INTO verdict;
 IF verdict<>'BLOCKED_NOISE_CHAPTER_OR_DOCUMENTED_CURFEW' THEN
  RAISE EXCEPTION 'AMS Chapter2 gate failed: %',verdict;
 END IF;

 SELECT airlinerra_game.section5_timed_route_schedule_gate_v1(
 1::smallint,'OURAIRPORTS:5564','OURAIRPORTS:2218',3::bigint,
 '2026-11-05T14:30:00Z'::timestamptz,'2026-11-05T19:00:00Z'::timestamptz)->>'decision'
 INTO verdict;
 IF verdict<>'BLOCKED_NOISE_CHAPTER_OR_DOCUMENTED_CURFEW' THEN
  RAISE EXCEPTION 'FUK night gate failed: %',verdict;
 END IF;

 SELECT airlinerra_game.section5_timed_route_schedule_gate_v1(
 1::smallint,'OURAIRPORTS:2218','OURAIRPORTS:4185',3::bigint,
 '2026-11-05T21:30:00Z'::timestamptz,'2026-11-05T23:40:00Z'::timestamptz)->>'decision'
 INTO verdict;
 IF verdict<>'SPECIAL_PERMISSION_OR_SLOT_REVIEW_REQUIRED' THEN
  RAISE EXCEPTION 'MUC shoulder review failed: %',verdict;
 END IF;

 SELECT airlinerra_game.section5_timed_route_schedule_gate_v1(
 1::smallint,'OURAIRPORTS:19570','OURAIRPORTS:2218',3::bigint,
 '2026-11-05T11:00:00Z'::timestamptz,'2026-11-05T12:00:00Z'::timestamptz)->>'decision'
 INTO verdict;
 IF verdict<>'BLOCKED_FULL_WEIGHT_RUNWAY_SCREEN' THEN
  RAISE EXCEPTION 'Short runway not blocked: %',verdict;
 END IF;

 SELECT airlinerra_game.section5_timed_route_schedule_gate_v1(
 1::smallint,'OURAIRPORTS:4185','OURAIRPORTS:2218',3::bigint,
 '2026-11-05T11:00:00Z'::timestamptz,'2026-11-05T13:00:00Z'::timestamptz)->>'decision'
 INTO verdict;
 IF verdict<>'PRELIMINARY_ALLOW_WITH_UNVERIFIED_NOISE_OR_AIRPORT_RULES' THEN
  RAISE EXCEPTION 'Unverified airport falsely approved: %',verdict;
 END IF;

 SELECT airlinerra_game.section5_timed_route_schedule_gate_v1(
 1::smallint,'OURAIRPORTS:999999999','OURAIRPORTS:2218',3::bigint,
 '2026-11-05T11:00:00Z'::timestamptz,'2026-11-05T13:00:00Z'::timestamptz)->>'decision'
 INTO verdict;
 IF verdict<>'BLOCKED_UNRESOLVED_AIRPORT_AIRCRAFT_OR_RUNWAY' THEN
  RAISE EXCEPTION 'Missing reference fail-closed check failed: %',verdict;
 END IF;

 SELECT airlinerra_game.section5_timed_route_schedule_gate_v1(
 1::smallint,'OURAIRPORTS:4185','OURAIRPORTS:2218',3::bigint,
 '2026-11-05T14:00:00Z'::timestamptz,'2026-11-05T13:00:00Z'::timestamptz)->>'decision'
 INTO verdict;
 IF verdict<>'BLOCKED_INVALID_ROUTE_OR_TIME' THEN
  RAISE EXCEPTION 'Invalid times fail-closed check failed: %',verdict;
 END IF;

 SELECT game_schedule_outcome FROM airlinerra_game.section5_game_airport_noise_curfew_check_v3(
 1::smallint,'OURAIRPORTS:3894',3::bigint,'departure',
 '2026-11-09T14:30:00Z'::timestamptz) INTO verdict;
 IF verdict<>'BLOCKED_DOCUMENTED_NORMAL_FLIGHT_CURFEW' THEN
  RAISE EXCEPTION 'SNA Sunday/Monday crossover failed: %',verdict;
 END IF;

 RAISE NOTICE 'SECTION5: eight flight schedule regression tests passed.';
END;
$tests$;