-- Read-only live acceptance of the official Europe/Berlin World 1 clock.
-- No changes to any clock row, game world, signed tick, finances or flight.
DO $proof$
DECLARE
 actual jsonb; current_day date;
 sample_at timestamptz;
 spring_seconds bigint; autumn_seconds bigint; state jsonb;
BEGIN
 actual:=airlinerra_game.section9_live_berlin_clock_v1(1::smallint);
 IF actual->>'timeZone'<>'Europe/Berlin' OR
  actual->>'speed'<>'1:1' OR
  actual->>'readOnly'<>'true' OR actual->>'worldId'<>'1'
 THEN RAISE EXCEPTION 'World 1 is not a read-only 1:1 Berlin clock: %',actual;END IF;
 sample_at:=(actual->>'utcNow')::timestamptz;
 current_day:=(sample_at AT TIME ZONE 'Europe/Berlin')::date;
 IF (actual->>'berlinDate')::date IS DISTINCT FROM current_day OR
  (actual->>'berlinTime') IS DISTINCT FROM
    to_char(sample_at AT TIME ZONE 'Europe/Berlin','HH24:MI:SS') OR
  abs(EXTRACT(epoch FROM (clock_timestamp()-sample_at)))>10
 THEN RAISE EXCEPTION 'Berlin game clock is out of sync with server: %',actual;END IF;
 SELECT EXTRACT(epoch FROM (
  (DATE '2026-03-30'::timestamp AT TIME ZONE 'Europe/Berlin')-
  (DATE '2026-03-29'::timestamp AT TIME ZONE 'Europe/Berlin')))
 INTO spring_seconds;
 SELECT EXTRACT(epoch FROM (
  (DATE '2026-10-26'::timestamp AT TIME ZONE 'Europe/Berlin')-
  (DATE '2026-10-25'::timestamp AT TIME ZONE 'Europe/Berlin')))
 INTO autumn_seconds;
 IF spring_seconds<>82800 OR autumn_seconds<>90000
 THEN RAISE EXCEPTION 'Berlin DST day durations incorrect'; END IF;
 state:=airlinerra_game.section9_clock_producer_due_v1(1::smallint);
 IF state->>'status' NOT IN ('caught_up','due') THEN
  RAISE EXCEPTION 'World clock due status invalid: %',state; END IF;
 IF state->>'status'='due' AND (state->>'gameDate')::date>current_day
 THEN RAISE EXCEPTION 'A future Berlin day was marked due: %',state;END IF;
 IF has_function_privilege('anon',
  'airlinerra_game.section9_live_berlin_clock_v1(smallint)','EXECUTE')
  OR has_function_privilege('authenticated',
  'airlinerra_game.section9_live_berlin_clock_v1(smallint)','EXECUTE')
 THEN RAISE EXCEPTION 'Live internal time SQL function exposed to browser';END IF;
 RAISE NOTICE 'PASS Berlin 1:1 server time, midnight due, DST 23h/25h and private SQL ACL';
END $proof$;
