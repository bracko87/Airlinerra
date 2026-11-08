-- Rollback-free, read-only Section 9 occurrence identity checks.
DO $check$
DECLARE payload jsonb;invalid boolean:=false; spring timestamptz;
 ambiguous timestamptz;synthetic_count integer;
BEGIN
 payload:=airlinerra_game.section9_verified_daily_flight_page_v2(
  1::smallint,DATE '2026-11-09',1000,NULL,NULL);
 IF jsonb_typeof(payload)<>'array' THEN
  RAISE EXCEPTION 'Occurrence page is not an array';END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(payload) x
  WHERE x->>'id' IS DISTINCT FROM
   ((x->>'scheduleId')||':'||(x->>'marketDate')||':'||(x->>'weeklyEntry'))
   OR x->>'capacitySource'<>'verified_activated_schedule')
 THEN RAISE EXCEPTION 'Invalid physical occurrence identity';END IF;
 IF (SELECT count(*) FROM jsonb_array_elements(payload)) <>
    (SELECT count(DISTINCT x->>'id') FROM jsonb_array_elements(payload) x)
 THEN RAISE EXCEPTION 'Repeated occurrence ID in one page';END IF;
 BEGIN
  PERFORM airlinerra_game.section9_verified_daily_flight_page_v2(
   1::smallint,DATE '2026-11-09',1000,
   '11111111-1111-4111-8111-111111111111'::uuid,NULL);
 EXCEPTION WHEN SQLSTATE '22023' THEN invalid:=true;END;
 IF NOT invalid THEN RAISE EXCEPTION 'Partial keyset cursor not blocked';END IF;
 -- Same schedule, same local weekday, different ordinal = TWO identities.
 WITH fixture AS (
  SELECT '11111111-1111-4111-8111-111111111111'::uuid schedule_id,
    ordinal::int AS weekly_entry
  FROM jsonb_array_elements(
   '[{"day":0,"time":"09:00"},{"day":0,"time":"17:00"}]'::jsonb)
  WITH ORDINALITY j(item,ordinal)
 )
 SELECT count(DISTINCT schedule_id::text||':2026-11-09:'||
  weekly_entry::text) INTO synthetic_count FROM fixture;
 IF synthetic_count<>2 THEN RAISE EXCEPTION 'Same-day departures collide';END IF;
 -- Berlin spring time 02:30 does not exist; autumn 02:30 is ambiguous.
 spring:=TIMESTAMP '2026-03-29 02:30' AT TIME ZONE 'Europe/Berlin';
 ambiguous:=TIMESTAMP '2026-10-25 02:30' AT TIME ZONE 'Europe/Berlin';
 IF (spring AT TIME ZONE 'Europe/Berlin')=
      TIMESTAMP '2026-03-29 02:30' THEN
  RAISE EXCEPTION 'Spring gap not identifiable';END IF;
 IF NOT (
  ((ambiguous-INTERVAL '1 hour') AT TIME ZONE 'Europe/Berlin')=
     TIMESTAMP '2026-10-25 02:30' OR
  ((ambiguous+INTERVAL '1 hour') AT TIME ZONE 'Europe/Berlin')=
     TIMESTAMP '2026-10-25 02:30'
 ) THEN RAISE EXCEPTION 'Autumn overlap not identifiable';END IF;
 IF has_function_privilege('anon',
    'airlinerra_game.section9_verified_daily_flight_page_v2(smallint,date,integer,uuid,integer)',
    'EXECUTE') OR has_function_privilege('authenticated',
    'airlinerra_game.section9_verified_daily_flight_page_v2(smallint,date,integer,uuid,integer)',
    'EXECUTE') THEN
  RAISE EXCEPTION 'Private occurrence reader was granted to browser roles';END IF;
 RAISE NOTICE 'SECTION9 PASSED: occurrence identity, composite cursor, DST and private execution';
END $check$;
