-- World 1 weekly-schedule restriction regression; no persistent test records.
DO $checks$
DECLARE v jsonb;
BEGIN
 v:=airlinerra_game.section5_weekly_route_restriction_gate_v1(
  1::smallint,'OURAIRPORTS:5564','OURAIRPORTS:2218',3::bigint,
  '2026-11-06T09:00:00Z'::timestamptz,
  '2026-11-06T11:00:00Z'::timestamptz,
  '[{"day":0,"time":"09:00"},{"day":4,"time":"23:30"}]'::jsonb);
 IF v->>'decision'<>'BLOCKED_RECURRING_ROUTE_OCCURRENCE'
 OR (v->>'gameHardBlocked')::boolean IS DISTINCT FROM true
 OR (v->>'occurrenceCount')::int<>8
 OR (v->>'canActivateNormalFlight')::boolean IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'Weekly curfew gate did not block correct date: %',v; END IF;
 v:=airlinerra_game.section5_weekly_route_restriction_gate_v1(
  1::smallint,'OURAIRPORTS:2218','OURAIRPORTS:4001',3::bigint,
  '2026-11-06T10:00:00Z'::timestamptz,
  '2026-11-06T11:00:00Z'::timestamptz,
  '[{"day":0,"time":"13:00"},{"day":2,"time":"13:00"},{"day":5,"time":"13:00"}]'::jsonb);
 IF (v->>'occurrenceCount')::int<>12
 OR (v->>'gameHardBlocked')::boolean IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'Review-only 12-week-occurrence case wrongly rejected: %',v; END IF;
 v:=airlinerra_game.section5_weekly_route_restriction_gate_v1(
  1::smallint,'OURAIRPORTS:2220','OURAIRPORTS:4001',3::bigint,
  '2026-03-29T10:00:00Z'::timestamptz,
  '2026-03-29T12:00:00Z'::timestamptz,
  '[{"day":6,"time":"02:30"}]'::jsonb);
 IF v->>'decision'<>'BLOCKED_NONEXISTENT_LOCAL_TIME_DST_TRANSITION'
 THEN RAISE EXCEPTION 'DST gap not rejected: %',v; END IF;
 v:=airlinerra_game.section5_weekly_route_restriction_gate_v1(
  1::smallint,'OURAIRPORTS:2220','OURAIRPORTS:4001',3::bigint,
  '2026-11-06T10:00:00Z'::timestamptz,
  '2026-11-06T11:00:00Z'::timestamptz,
  '[{"day":1,"time":"09:00"},{"day":1,"time":"10:00"}]'::jsonb);
 IF v->>'decision'<>'BLOCKED_DUPLICATE_WEEKDAY' THEN
  RAISE EXCEPTION 'Duplicate weekday not rejected: %',v; END IF;
END $checks$;