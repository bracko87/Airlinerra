-- Section 9: trusted scheduled game-day producer bound to an administrator-
-- released opening anchor and the existing signed tick ingress.
-- One real elapsed 24-hour interval = one in-game calendar day.
-- No release rows, secrets or launch dates are inserted by this migration.
-- All game worlds remain planned, flight activation and payroll remain off.

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_clock_producer_schedule_v1(
 world_id smallint PRIMARY KEY REFERENCES public.airlinerra_game_worlds(id)
   CHECK(world_id=1),
 start_game_date date NOT NULL CHECK(start_game_date BETWEEN
   DATE '2000-01-01' AND DATE '2199-01-01'),
 official_world_opens_at timestamptz NOT NULL,
 producer_status text NOT NULL DEFAULT 'paused'
   CHECK(producer_status IN('paused','enabled')),
 admin_release_reference text NOT NULL CHECK(
   char_length(admin_release_reference) BETWEEN 16 AND 160),
 configured_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 enabled_at timestamptz,
 CHECK((producer_status='paused' AND enabled_at IS NULL) OR
       (producer_status='enabled' AND enabled_at IS NOT NULL))
);
ALTER TABLE airlinerra_game.section9_clock_producer_schedule_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_clock_producer_schedule_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.section9_clock_producer_schedule_v1 IS
 'Private release-controlled 24-hour game-day anchor. No row is inserted until an administrator has opened World1 and explicitly chosen its in-game starting date.';

CREATE OR REPLACE FUNCTION airlinerra_game.section9_configure_clock_producer_v1(
 p_world smallint,p_start_game_date date,p_release_reference text
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE w record; existing record;
BEGIN
 IF p_world IS DISTINCT FROM 1 OR p_start_game_date IS NULL OR
  p_start_game_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-01-01' OR
  length(coalesce(p_release_reference,'')) NOT BETWEEN 16 AND 160
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_CLOCK_PRODUCER_RELEASE';END IF;
 SELECT state,opens_at INTO w
 FROM public.airlinerra_game_worlds WHERE id=p_world FOR SHARE;
 IF NOT FOUND OR w.state<>'active' OR w.opens_at IS NULL OR
    w.opens_at>clock_timestamp()
 THEN RETURN jsonb_build_object('status','blocked_world_not_open',
   'configured',false,'enabled',false);END IF;
 PERFORM 1 FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=p_world AND clock_source='not_connected'
 AND confirmed_game_date IS NULL FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_CLOCK_ALREADY_STARTED';END IF;
 INSERT INTO airlinerra_game.section9_clock_producer_schedule_v1(
  world_id,start_game_date,official_world_opens_at,admin_release_reference)
 VALUES(p_world,p_start_game_date,w.opens_at,p_release_reference)
 ON CONFLICT(world_id) DO NOTHING;
 SELECT * INTO existing
 FROM airlinerra_game.section9_clock_producer_schedule_v1
 WHERE world_id=p_world FOR UPDATE;
 IF existing.start_game_date IS DISTINCT FROM p_start_game_date OR
  existing.official_world_opens_at IS DISTINCT FROM w.opens_at OR
  existing.admin_release_reference IS DISTINCT FROM p_release_reference
 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_CLOCK_RELEASE_CONFIGURATION_CONFLICT';END IF;
 RETURN jsonb_build_object('status',existing.producer_status,
  'configured',true,'enabled',existing.producer_status='enabled',
  'worldId',p_world,'startGameDate',existing.start_game_date,
  'worldOpensAt',existing.official_world_opens_at,
  'noFlightActivation',true,'noPayroll',true);
END $f$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_configure_clock_producer_v1(smallint,date,text)
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_enable_clock_producer_v1(
 p_world smallint,p_release_reference text
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE w record; s record; c record;
BEGIN
 IF p_world IS DISTINCT FROM 1 OR p_release_reference IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_CLOCK_PRODUCER_ENABLE';END IF;
 SELECT state,opens_at INTO w
 FROM public.airlinerra_game_worlds WHERE id=p_world FOR SHARE;
 SELECT * INTO s FROM airlinerra_game.section9_clock_producer_schedule_v1
 WHERE world_id=p_world FOR UPDATE;
 SELECT clock_source,confirmed_game_date INTO c
 FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=p_world FOR SHARE;
 IF NOT FOUND OR s.world_id IS NULL OR
  w.state IS DISTINCT FROM 'active' OR w.opens_at IS NULL OR
  w.opens_at>clock_timestamp() OR
  w.opens_at IS DISTINCT FROM s.official_world_opens_at OR
  p_release_reference IS DISTINCT FROM s.admin_release_reference OR
  (c.clock_source='not_connected' AND c.confirmed_game_date IS NOT NULL) OR
  c.clock_source NOT IN ('not_connected','authoritative_game_engine')
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_CLOCK_PRODUCER_RELEASE_NOT_AUTHORIZED';END IF;
 IF c.clock_source='authoritative_game_engine'
   AND (c.confirmed_game_date<s.start_game_date OR
     c.confirmed_game_date IS NULL)
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_EXISTING_CLOCK_OUTSIDE_RELEASE';END IF;
 UPDATE airlinerra_game.section9_clock_producer_schedule_v1
 SET producer_status='enabled',
 enabled_at=coalesce(enabled_at,clock_timestamp())
 WHERE world_id=p_world;
 RETURN jsonb_build_object('status','enabled','worldId',p_world,
  'startGameDate',s.start_game_date,'worldOpensAt',s.official_world_opens_at,
  'noPayroll',true,'noFlightActivation',true);
END $f$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_enable_clock_producer_v1(smallint,text)
 FROM PUBLIC,anon,authenticated;

-- Private producer uses only the DATABASE clock and persisted, administrator-
-- approved world opening. It never trusts the caller's date/time.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_clock_producer_due_v1(
 p_world smallint DEFAULT 1
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE w record;s record;c record;
 elapsed int; next_index int;due_at timestamptz;next_day date;
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
 elapsed:=floor(extract(epoch FROM (clock_timestamp()-w.opens_at))/86400.0)::int;
 IF elapsed<next_index THEN
  RETURN jsonb_build_object('status','caught_up','worldId',p_world,
   'currentGameDate',c.confirmed_game_date,
   'readOnly',true,'clockAdvanced',false,'daysBehind',0);END IF;
 next_day:=s.start_game_date+next_index;
 IF next_day>DATE '2199-12-31' THEN
  RETURN jsonb_build_object('status','clock_date_limit',
   'worldId',p_world,'readOnly',true,'clockAdvanced',false);END IF;
 due_at:=w.opens_at+make_interval(days=>next_index);
 RETURN jsonb_build_object('status','due','worldId',p_world,
  'gameDate',next_day,
  'eventId','horizon-world1-day-'||to_char(next_day,'YYYY-MM-DD'),
  'dueAtUtc',due_at,
  'daysBehind',elapsed-next_index,
  'readOnly',true,'clockAdvanced',false,
  'payrollPosted',false,'bookingsCreated',false);
END $f$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_clock_producer_due_v1(smallint)
 FROM PUBLIC,anon,authenticated;

-- The producer's actual clock update is a SINGLE atomic transaction with
-- a second inside-DB date due check. Concurrent/replayed calls cannot
-- advance prematurely, even if the producer's first read became stale.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_accept_scheduled_game_tick_v1(
 p_world smallint,p_day date,p_event_id text,p_verified_hmac text
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE w record;s record; c record;due jsonb;current_row record;
BEGIN
 IF p_world IS DISTINCT FROM 1 OR p_day IS NULL OR
  p_event_id IS NULL OR p_verified_hmac IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_SCHEDULED_TICK';END IF;
 SELECT state,opens_at INTO w FROM public.airlinerra_game_worlds
 WHERE id=p_world FOR SHARE;
 SELECT * INTO s FROM airlinerra_game.section9_clock_producer_schedule_v1
 WHERE world_id=p_world FOR SHARE;
 IF w.state IS DISTINCT FROM 'active' OR w.opens_at IS NULL
    OR w.opens_at>clock_timestamp() OR s.producer_status IS DISTINCT FROM 'enabled'
    OR s.official_world_opens_at IS DISTINCT FROM w.opens_at THEN
  RETURN jsonb_build_object('status','blocked_world_not_open',
    'worldId',p_world,'clockAdvanced',false,
    'forecastEnqueued',false,'payrollPosted',false,'bookingsCreated',false);
 END IF;
 -- lock clock while checking due: exact replay is accepted separately.
 SELECT * INTO current_row FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=p_world FOR UPDATE;
 IF current_row.clock_source='authoritative_game_engine'
   AND current_row.confirmed_game_date=p_day
 THEN
  SELECT * INTO c FROM airlinerra_game.section9_verified_game_tick_receipts_v1
  WHERE world_id=p_world AND game_date=p_day;
  IF FOUND AND c.engine_event_id=p_event_id AND c.event_hmac_sha256=p_verified_hmac THEN
   RETURN airlinerra_game.section9_accept_verified_game_tick_v1(
    p_world,p_day,p_event_id,p_verified_hmac);
  END IF;
 END IF;
 due:=airlinerra_game.section9_clock_producer_due_v1(p_world);
 IF due->>'status'<>'due'
  OR (due->>'gameDate')::date IS DISTINCT FROM p_day
  OR due->>'eventId' IS DISTINCT FROM p_event_id
  OR (due->>'dueAtUtc')::timestamptz>clock_timestamp()
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_SCHEDULED_DAY_NOT_DUE';END IF;
 RETURN airlinerra_game.section9_accept_verified_game_tick_v1(
  p_world,p_day,p_event_id,p_verified_hmac);
END $f$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_accept_scheduled_game_tick_v1(
  smallint,date,text,text) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section9_accept_scheduled_game_tick_v1(
 smallint,date,text,text) IS
 'Private due-time-gated event acceptance. Always verify HMAC before invoking through the trusted service. No direct player SQL access.';
