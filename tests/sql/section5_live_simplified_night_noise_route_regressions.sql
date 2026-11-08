-- Regression checks for the live Section 5 simplified-night/noise server gate.
-- All temporary changes are rolled back. This test never activates flights.
BEGIN;
DO $assert$
DECLARE
 g jsonb; w jsonb;
BEGIN
 g:=airlinerra_game.section5_simplified_airport_leg_screen_v1(
  1::smallint,'OURAIRPORTS:2685',57,'departure','2026-11-08 01:30+00');
 IF g->>'blockedBySimplifiedNighttimeBan'<>'true' OR
    g->>'gameHardBlocked'<>'true' THEN
  RAISE EXCEPTION 'Kiruna overnight AirlineSim game ban was not enforced: %',g;
 END IF;
 g:=airlinerra_game.section5_simplified_airport_leg_screen_v1(
  1::smallint,'OURAIRPORTS:2685',57,'departure','2026-11-08 12:00+00');
 IF g->>'blockedBySimplifiedNighttimeBan'<>'false' OR
    g->>'gameHardBlocked'<>'false' THEN
  RAISE EXCEPTION 'Kiruna daylight was incorrectly banned: %',g;
 END IF;
 g:=airlinerra_game.section5_simplified_airport_leg_screen_v1(
  1::smallint,'OURAIRPORTS:1990',57,'departure','2026-11-08 01:30+00');
 IF g->>'gameHardBlocked'<>'false' OR g->>'needsReview'<>'false' THEN
  RAISE EXCEPTION 'Unrestricted simple YYZ game flags imposed a restriction: %',g;
 END IF;
 g:=airlinerra_game.section5_simplified_airport_leg_screen_v1(
  1::smallint,'OURAIRPORTS:336537',57,'departure','2026-11-08 01:30+00');
 IF g->>'nighttimeWindowNeedsReview'<>'true' OR
    g->>'blockedBySimplifiedNighttimeBan'<>'false' THEN
  RAISE EXCEPTION 'Sunset-to-sunrise rule must be reviewed, not invented: %',g;
 END IF;
 g:=airlinerra_game.section5_universal_route_restriction_gate_v1(
  1::smallint,'OURAIRPORTS:2685','OURAIRPORTS:2701',57,
  '2026-11-08 01:30+00','2026-11-08 03:30+00',null,null);
 IF g->>'gameHardBlocked'<>'true' OR
    g->'origin'->>'blockedBySimplifiedNighttimeBan'<>'true' OR
    g->'origin'->>'blockedByAirportTimeRule'<>'true' OR
    g->>'canActivateNormalFlight'<>'false' THEN
  RAISE EXCEPTION 'Universal route failed to inherit simplified airport ban: %',g;
 END IF;
 w:=airlinerra_game.section5_weekly_route_restriction_gate_v1(
  1::smallint,'OURAIRPORTS:2685','OURAIRPORTS:2701',57,
  '2026-11-09 01:00+01','2026-11-09 03:00+01',
  '[{"day":0,"time":"02:30"}]'::jsonb);
 IF w->>'gameHardBlocked'<>'true' OR w->>'weeklyTimetableChecked'<>'true'
    OR w->>'occurrenceCount'<>'4'
    OR (SELECT count(*) FROM jsonb_array_elements(w->'occurrences') x
       WHERE x->'origin'->>'blockedBySimplifiedNighttimeBan'='true')<>4
 THEN RAISE EXCEPTION 'Weekly server draft preflight missed one or more banned nights: %',w;
 END IF;
 g:=airlinerra_game.section5_universal_route_restriction_gate_v1(
  1::smallint,'OURAIRPORTS:5564','OURAIRPORTS:2701',57,
  '2026-11-08 14:30+00','2026-11-08 16:30+00',null,null);
 IF g->'origin'->>'blockedByAirportTimeRule'<>'true' OR
    g->>'gameHardBlocked'<>'true' THEN
  RAISE EXCEPTION 'Existing FUK mandatory official rule was lost: %',g;
 END IF;
 IF has_function_privilege('anon',
  'airlinerra_game.section5_simplified_airport_leg_screen_v1(smallint,text,bigint,text,timestamptz)',
  'EXECUTE')
  OR has_function_privilege('authenticated',
  'airlinerra_game.section5_simplified_airport_leg_screen_v1(smallint,text,bigint,text,timestamptz)',
  'EXECUTE') THEN
  RAISE EXCEPTION 'New private helper executable by browser roles';
 END IF;
END;
$assert$;

-- Create a temporary difference between certificate-matched Chapters and the
-- simplified permitted-Chapter list. This must not change source research.
UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1
SET permitted_noise_chapters=ARRAY[3]::smallint[]
WHERE world_id=1 AND airport_key='OURAIRPORTS:2685';
DO $assert$
DECLARE g jsonb;
BEGIN
 g:=airlinerra_game.section5_simplified_airport_leg_screen_v1(
  1::smallint,'OURAIRPORTS:2685',57,'departure','2026-11-08 12:00+00');
 IF g->>'blockedBySimplifiedNoiseChapter'<>'true' THEN
  RAISE EXCEPTION 'Matched Chapter 4 must not pass a Chapter 3-only list: %',g;
 END IF;
 g:=airlinerra_game.section5_simplified_airport_leg_screen_v1(
  1::smallint,'OURAIRPORTS:2685',3,'departure','2026-11-08 12:00+00');
 IF g->>'blockedBySimplifiedNoiseChapter'<>'false'
    OR g->>'noiseCertificateNeedsReview'<>'true' THEN
  RAISE EXCEPTION 'Estimated/unknown aircraft certification must not hard block: %',g;
 END IF;
END;
$assert$;
-- Chapter 14 satisfies a Chapter 4 minimum in the simplified simulation.
UPDATE airlinerra_game.section5_airport_simplified_game_rules_v1
SET permitted_noise_chapters=ARRAY[3,4]::smallint[]
WHERE world_id=1 AND airport_key='OURAIRPORTS:2685';
DO $assert$
DECLARE g jsonb;
BEGIN
 g:=airlinerra_game.section5_simplified_airport_leg_screen_v1(
  1::smallint,'OURAIRPORTS:2685',24,'departure','2026-11-08 12:00+00');
 IF g->>'blockedBySimplifiedNoiseChapter'<>'false' THEN
  RAISE EXCEPTION 'Chapter 14 must satisfy a permitted Chapter 4 minimum: %',g;
 END IF;
END;
$assert$;
ROLLBACK;
