-- Airlinerra Section 9 authoritative *event ingress* for game days.
-- NO synthetic clock, no date derived from the browser or server wall-clock.
-- Private app server MUST HMAC-verify the incoming trusted engine event
-- before invoking this internal SQL function. Database receives only
-- server-validated event identity and proof digest, not the signing secret.
-- Each accepted tick and its optional READ-ONLY demand forecast enqueue are
-- atomic in one transaction. Never activates flights or posts payroll.

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_verified_game_tick_receipts_v1 (
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1)
   REFERENCES public.airlinerra_game_worlds(id),
 game_date date NOT NULL CHECK(game_date BETWEEN
   DATE '2000-01-01' AND DATE '2199-12-31'),
 engine_event_id text NOT NULL CHECK(
  length(engine_event_id) BETWEEN 12 AND 128
  AND engine_event_id ~ '^[A-Za-z0-9._:-]+$'),
 event_hmac_sha256 text NOT NULL CHECK(event_hmac_sha256 ~ '^[0-9a-f]{64}$'),
 forecast_job_id uuid REFERENCES airlinerra_game.section9_demand_jobs_v1(id),
 dispatch_kind text NOT NULL CHECK(dispatch_kind IN(
   'no_verified_flights','read_only_forecast_enqueued')),
 accepted_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(world_id,game_date),
 UNIQUE(world_id,engine_event_id)
);
ALTER TABLE airlinerra_game.section9_verified_game_tick_receipts_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_verified_game_tick_receipts_v1
 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_game_tick_forecast_fk_idx
 ON airlinerra_game.section9_verified_game_tick_receipts_v1(forecast_job_id)
 WHERE forecast_job_id IS NOT NULL;

COMMENT ON TABLE airlinerra_game.section9_verified_game_tick_receipts_v1 IS
 'Private deduplicated signed game-engine tick receipts. Signatures MUST be checked in a non-browser trusted server with a secret not stored in the DB or repository. No economic or flight operations authority.';

CREATE OR REPLACE FUNCTION airlinerra_game.section9_accept_verified_game_tick_v1(
 p_world smallint,p_game_date date,p_engine_event_id text,
 p_verified_event_hmac_sha256 text
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE world_state record; clock_row record;
 previous record; eligible boolean; forecast jsonb;
 job uuid;kind text;
BEGIN
 IF p_world IS DISTINCT FROM 1 OR p_game_date IS NULL OR
  p_game_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-31' OR
  p_engine_event_id IS NULL OR
  length(p_engine_event_id) NOT BETWEEN 12 AND 128 OR
  p_engine_event_id !~ '^[A-Za-z0-9._:-]+$' OR
  p_verified_event_hmac_sha256 IS NULL OR
  p_verified_event_hmac_sha256 !~ '^[0-9a-f]{64}$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_TRUSTED_GAME_TICK'; END IF;

 -- Lock the world and clock rows first: a concurrent world closure or game
 -- day advance cannot race the proof and the forecast enqueue.
 SELECT state,opens_at INTO world_state
 FROM public.airlinerra_game_worlds WHERE id=p_world FOR SHARE;
 IF NOT FOUND OR world_state.state<>'active'
   OR world_state.opens_at IS NULL OR world_state.opens_at>clock_timestamp()
 THEN RETURN jsonb_build_object(
  'status','blocked_world_not_open','worldId',p_world,
  'clockAdvanced',false,'forecastEnqueued',false,
  'payrollPosted',false,'bookingsCreated',false);END IF;

 SELECT * INTO clock_row
 FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=p_world FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_WORLD_CLOCK_ROW_NOT_FOUND'; END IF;

 SELECT * INTO previous
 FROM airlinerra_game.section9_verified_game_tick_receipts_v1
 WHERE world_id=p_world AND game_date=p_game_date;

 IF FOUND THEN
  IF previous.engine_event_id IS DISTINCT FROM p_engine_event_id OR
   previous.event_hmac_sha256 IS DISTINCT FROM p_verified_event_hmac_sha256
  THEN RAISE EXCEPTION USING ERRCODE='23505',
    MESSAGE='SECTION9_GAME_TICK_REPLAY_EVIDENCE_MISMATCH'; END IF;
  IF clock_row.clock_source<>'authoritative_game_engine' OR
    clock_row.confirmed_game_date<p_game_date
  THEN RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_CLOCK_RECEIPT_WITHOUT_VERIFIED_DAY';END IF;
  RETURN jsonb_build_object(
   'status','already_applied','worldId',p_world,'gameDate',p_game_date,
   'engineEventId',p_engine_event_id,'clockAdvanced',false,
   'forecastEnqueued',previous.forecast_job_id IS NOT NULL,
   'forecastJobId',previous.forecast_job_id,
   'payrollPosted',false,'bookingsCreated',false,'replayed',true);
 END IF;

 IF clock_row.clock_source='not_connected' THEN
  IF clock_row.confirmed_game_date IS NOT NULL
   OR clock_row.engine_proof_ref IS NOT NULL
   OR clock_row.last_verified_at IS NOT NULL
  THEN RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_UNSAFE_DISCONNECTED_CLOCK_STATE';END IF;
 ELSIF clock_row.clock_source='authoritative_game_engine' THEN
  IF clock_row.confirmed_game_date IS NULL OR
    p_game_date<>clock_row.confirmed_game_date+1
  THEN RAISE EXCEPTION USING ERRCODE='22023',
    MESSAGE='SECTION9_GAME_TICKS_MUST_ADVANCE_ONE_DAY';END IF;
 ELSE RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_UNKNOWN_GAME_CLOCK_SOURCE';END IF;

 UPDATE airlinerra_game.holding_world_clock_v1 SET
  confirmed_game_date=p_game_date,
  clock_source='authoritative_game_engine',
  engine_proof_ref=p_engine_event_id,
  last_verified_at=clock_timestamp()
 WHERE world_id=p_world;

 -- A verified tick can request a READ-ONLY forecast only if the existing
 -- flight activation gate has already certified an active schedule and its
 -- effective simultaneous capacity. Actual tickets and revenue remain blocked.
 SELECT EXISTS(
  SELECT 1
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
  JOIN airlinerra_game.section9_verified_schedule_capacity_v1 cap
   ON cap.schedule_id=d.id AND cap.airline_id=d.airline_id
    AND cap.schedule_version=d.version
  WHERE d.world_id=p_world AND d.status='active'
   AND d.operationally_verified IS TRUE
 ) INTO eligible;

 IF eligible THEN
  forecast:=airlinerra_game.section9_enqueue_forecast_day_v1(
   p_world,p_game_date);
  IF forecast->>'readOnly'<>'true' OR forecast->>'jobId' IS NULL
  THEN RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_FORECAST_ENQUEUE_NOT_VERIFIED';END IF;
  job:=(forecast->>'jobId')::uuid;
  kind:='read_only_forecast_enqueued';
 ELSE
  kind:='no_verified_flights';
 END IF;

 INSERT INTO airlinerra_game.section9_verified_game_tick_receipts_v1(
  world_id,game_date,engine_event_id,event_hmac_sha256,
  forecast_job_id,dispatch_kind)
 VALUES(p_world,p_game_date,p_engine_event_id,
  p_verified_event_hmac_sha256,job,kind);

 RETURN jsonb_build_object('status','verified_tick_accepted',
  'worldId',p_world,'gameDate',p_game_date,
  'clockAdvanced',true,'forecastEnqueued',job IS NOT NULL,
  'forecastJobId',job,'dispatchKind',kind,
  'payrollPosted',false,'bookingsCreated',false,'replayed',false);
END $f$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_accept_verified_game_tick_v1(
  smallint,date,text,text) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION
 airlinerra_game.section9_accept_verified_game_tick_v1(
  smallint,date,text,text) IS
 'Trusted-backend-only signed tick admission, one in-game day at a time. World must be active/open. Signatures independently HMAC-verified in the private Node engine adapter. Atomic with optional read-only demand queue. No cash, payroll or flight activation.';

-- Private diagnostic, no clock or ledger mutations.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_world_clock_dispatch_readiness_v1(
 p_world smallint DEFAULT 1
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE w record;c record;n int;
BEGIN
 IF p_world IS DISTINCT FROM 1 THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_WORLD1_ONLY';END IF;
 SELECT state,opens_at INTO w FROM public.airlinerra_game_worlds WHERE id=p_world;
 SELECT confirmed_game_date,clock_source,engine_proof_ref,last_verified_at
 INTO c FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=p_world;
 SELECT count(*) INTO n FROM airlinerra_game.section9_verified_game_tick_receipts_v1
 WHERE world_id=p_world;
 RETURN jsonb_build_object('worldId',p_world,'worldState',w.state,
  'worldOpensAt',w.opens_at,
  'gameDate',c.confirmed_game_date,'clockSource',c.clock_source,
  'verifiedTickCount',n,'clockConnected',
  w.state='active' AND w.opens_at IS NOT NULL AND
  w.opens_at<=clock_timestamp() AND c.clock_source='authoritative_game_engine'
  AND c.confirmed_game_date IS NOT NULL AND c.last_verified_at IS NOT NULL,
  'engineEventProducerConnected',false,
  'automaticPayrollEnabled',false,'actualFlightBookingsEnabled',false,
  'readOnly',true);
END $f$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_world_clock_dispatch_readiness_v1(smallint)
 FROM PUBLIC,anon,authenticated;
