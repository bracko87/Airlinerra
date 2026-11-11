-- World 1 clock mode: 1 real second = 1 game second, Europe/Berlin.
-- Day changes follow *calendar midnight* in Berlin, including CET/CEST DST.
-- Preserve existing signed tick history and the original world opening approval.
-- This only changes scheduling/read-only clock information; NO flight, payment or salary writes.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_clock_producer_due_v1(
 p_world smallint DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $function$
DECLARE
 w record;s record;c record;
 elapsed int;next_index int;due_at timestamptz;next_day date;berlin_today date;
BEGIN
 IF p_world IS DISTINCT FROM 1 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_CLOCK_PRODUCER_WORLD1_ONLY';END IF;
 SELECT state,opens_at INTO w
 FROM public.airlinerra_game_worlds WHERE id=p_world;
 IF w.state IS DISTINCT FROM 'active' OR w.opens_at IS NULL OR
   w.opens_at>clock_timestamp() THEN
  RETURN jsonb_build_object('status','blocked_world_not_open',
   'worldId',p_world,'readOnly',true,'clockAdvanced',false);END IF;
 SELECT * INTO s FROM airlinerra_game.section9_clock_producer_schedule_v1
 WHERE world_id=p_world;
 IF NOT FOUND THEN
  RETURN jsonb_build_object('status','not_configured',
   'worldId',p_world,'readOnly',true,'clockAdvanced',false);END IF;
 IF s.producer_status<>'enabled' THEN
  RETURN jsonb_build_object('status','paused','worldId',p_world,
   'readOnly',true,'clockAdvanced',false);END IF;
 IF s.official_world_opens_at IS DISTINCT FROM w.opens_at THEN
  RETURN jsonb_build_object('status','opening_anchor_changed',
   'worldId',p_world,'readOnly',true,'clockAdvanced',false);END IF;
 SELECT * INTO c FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=p_world;
 IF NOT FOUND OR c.clock_source NOT IN ('not_connected','authoritative_game_engine') OR
  (c.clock_source='not_connected' AND c.confirmed_game_date IS NOT NULL) OR
  (c.clock_source='authoritative_game_engine' AND c.confirmed_game_date IS NULL)
 THEN RETURN jsonb_build_object('status','clock_state_invalid',
  'worldId',p_world,'readOnly',true,'clockAdvanced',false);END IF;
 next_index:=CASE WHEN c.confirmed_game_date IS NULL THEN 0
   ELSE (c.confirmed_game_date-s.start_game_date)+1 END;
 IF next_index<0 OR next_index>73000 THEN
  RETURN jsonb_build_object('status','clock_outside_release',
   'worldId',p_world,'readOnly',true,'clockAdvanced',false);END IF;
 -- The server's real UTC instant becomes local Berlin time using PostgreSQL
 -- IANA timezone rules. No JS clock, user input or artificial 86400-second days.
 berlin_today:=(clock_timestamp() AT TIME ZONE 'Europe/Berlin')::date;
 elapsed:=berlin_today-s.start_game_date;
 IF elapsed<next_index THEN
  RETURN jsonb_build_object('status','caught_up','worldId',p_world,
   'currentGameDate',c.confirmed_game_date,
   'readOnly',true,'clockAdvanced',false,'daysBehind',0);END IF;
 next_day:=s.start_game_date+next_index;
 IF next_day>DATE '2199-12-31' THEN
  RETURN jsonb_build_object('status','clock_date_limit',
   'worldId',p_world,'readOnly',true,'clockAdvanced',false);END IF;
 -- Berlin midnight: 23/25-hour days are handled automatically around DST.
 -- On launch day, never process a tick before the approved opening instant.
 due_at:=greatest(w.opens_at,(next_day::timestamp AT TIME ZONE 'Europe/Berlin'));
 IF due_at>clock_timestamp() THEN
  RETURN jsonb_build_object('status','caught_up','worldId',p_world,
   'currentGameDate',c.confirmed_game_date,
   'readOnly',true,'clockAdvanced',false,'daysBehind',0);END IF;
 RETURN jsonb_build_object('status','due','worldId',p_world,
  'gameDate',next_day,
  'eventId','horizon-world1-day-'||to_char(next_day,'YYYY-MM-DD'),
  'dueAtUtc',due_at,
  'daysBehind',elapsed-next_index,
  'timeZone','Europe/Berlin',
  'readOnly',true,'clockAdvanced',false,
  'payrollPosted',false,'bookingsCreated',false);
END $function$;

-- One immutable timestamp per read; provides exact real time for the UI.
-- It must NOT advance the daily receipt ledger or operate any game economy.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_live_berlin_clock_v1(
 p_world smallint DEFAULT 1)
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $function$
DECLARE sample_at timestamptz;
BEGIN
 IF p_world IS DISTINCT FROM 1 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_WORLD1_ONLY';END IF;
 sample_at:=clock_timestamp();
 RETURN jsonb_build_object(
  'worldId',1,
  'utcNow',to_char(sample_at AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'berlinDate',to_char(sample_at AT TIME ZONE 'Europe/Berlin','YYYY-MM-DD'),
  'berlinTime',to_char(sample_at AT TIME ZONE 'Europe/Berlin','HH24:MI:SS'),
  'timeZone','Europe/Berlin',
  'speed','1:1',
  'readOnly',true);
END $function$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_live_berlin_clock_v1(smallint)
 FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section9_live_berlin_clock_v1(smallint) IS
 'Server-verified current World1 time, fixed Europe/Berlin, 1:1 with real world; no writes.';
COMMENT ON FUNCTION airlinerra_game.section9_clock_producer_due_v1(smallint) IS
 'Due only on real Europe/Berlin local calendar days, midnight DST aware; one signed event per date.';
