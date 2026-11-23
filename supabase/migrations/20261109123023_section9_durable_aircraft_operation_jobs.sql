-- Section 9, World 1: private durable aircraft/day operations work queue.
-- A queue job is NOT an authorization to operate a flight. Actual movements
-- require a trusted independent decision, signed ingest and THIS lease fence.
-- No world opening, flight activation, bookings or ledger writes.

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_aircraft_day_operations_jobs_v1(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id) ON DELETE RESTRICT,
 aircraft_inventory_id uuid NOT NULL REFERENCES
  airlinerra_game.airline_aircraft_inventory(id) ON DELETE RESTRICT,
 game_date date NOT NULL CHECK(game_date BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'),
 status text NOT NULL DEFAULT 'queued'
  CHECK(status IN ('queued','running','completed','failed')),
 attempt integer NOT NULL DEFAULT 0 CHECK(attempt BETWEEN 0 AND 5),
 next_attempt_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 lease_token uuid,
 lease_until timestamptz,
 processed_events integer CHECK(processed_events BETWEEN 0 AND 500),
 replayed_events integer CHECK(replayed_events BETWEEN 0 AND 500),
 failure_code text,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 completed_at timestamptz,
 UNIQUE(world_id,aircraft_inventory_id,game_date),
 CONSTRAINT section9_aircraft_job_lease_state CHECK(
  (status='running' AND lease_token IS NOT NULL AND lease_until IS NOT NULL)
  OR (status<>'running' AND lease_token IS NULL AND lease_until IS NULL)),
 CONSTRAINT section9_aircraft_job_completion CHECK (
  status<>'completed' OR (completed_at IS NOT NULL
   AND processed_events IS NOT NULL
   AND replayed_events IS NOT NULL AND replayed_events<=processed_events))
);
ALTER TABLE airlinerra_game.section9_aircraft_day_operations_jobs_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aircraft_day_operations_jobs_v1
 FROM PUBLIC,anon,authenticated;
-- Absolute exclusion: even workers claiming DIFFERENT dates cannot
-- simultaneously hold running jobs for the same physical aircraft.
CREATE UNIQUE INDEX IF NOT EXISTS section9_one_running_job_per_aircraft_idx
 ON airlinerra_game.section9_aircraft_day_operations_jobs_v1(aircraft_inventory_id)
 WHERE status='running';
CREATE INDEX IF NOT EXISTS section9_aircraft_job_claim_idx
 ON airlinerra_game.section9_aircraft_day_operations_jobs_v1
  (status,next_attempt_at,game_date,created_at,id)
 WHERE status='queued';
CREATE INDEX IF NOT EXISTS section9_aircraft_job_chronology_idx
 ON airlinerra_game.section9_aircraft_day_operations_jobs_v1
  (aircraft_inventory_id,game_date,status);

-- Keyset pagination allows thousands of aircraft to be enqueued in bounded
-- batches after an ACTUAL, independently signed game-day receipt exists.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_enqueue_aircraft_operations_batch_v1(
 p_game_date date,p_after_aircraft uuid DEFAULT NULL,p_limit integer DEFAULT 100
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE w record;c record;new_rows integer;page_rows integer;
 selected_rows integer;cursor_id uuid;more boolean;
BEGIN
 IF p_game_date IS NULL OR
  p_game_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-31' OR
  p_limit NOT BETWEEN 1 AND 200
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_OPERATIONS_ENQUEUE_BATCH';END IF;
 SELECT state,opens_at INTO w FROM public.airlinerra_game_worlds WHERE id=1;
 SELECT confirmed_game_date,clock_source,last_verified_at,engine_proof_ref
 INTO c FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=1;
 IF w.state IS DISTINCT FROM 'active' OR w.opens_at IS NULL
 OR w.opens_at>clock_timestamp()
 OR c.clock_source IS DISTINCT FROM 'authoritative_game_engine'
 OR c.last_verified_at IS NULL OR
 length(coalesce(c.engine_proof_ref,''))<12 OR
 c.confirmed_game_date<p_game_date OR
 NOT EXISTS (SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1 t
  WHERE t.world_id=1 AND t.game_date=p_game_date)
 THEN RETURN jsonb_build_object(
  'status','blocked_unverified_world_or_game_day',
  'readOnly',false,'jobsEnqueued',0,'hasMore',false,
  'flightActivated',false,'movementRecorded',false,'ledgerPosted',false);
 END IF;
 WITH eligible AS MATERIALIZED (
  SELECT DISTINCT s.aircraft_inventory_id,s.airline_id
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
  JOIN airlinerra_game.airline_aircraft_inventory f
   ON f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id
   AND f.fleet_status='in_service' AND f.configuration_id=s.configuration_id
  JOIN airlinerra_game.section9_verified_schedule_capacity_v1 cap
   ON cap.schedule_id=s.id AND cap.airline_id=s.airline_id
   AND cap.schedule_version=s.version
  WHERE s.world_id=1 AND s.status='active'
    AND s.operationally_verified=true
    AND (p_after_aircraft IS NULL OR s.aircraft_inventory_id>p_after_aircraft)
 ),
 page AS MATERIALIZED (
  SELECT * FROM eligible ORDER BY aircraft_inventory_id LIMIT p_limit+1
 ),
 chosen AS MATERIALIZED (
  SELECT * FROM page ORDER BY aircraft_inventory_id LIMIT p_limit
 ),
 inserted AS (
  INSERT INTO airlinerra_game.section9_aircraft_day_operations_jobs_v1(
    world_id,airline_id,aircraft_inventory_id,game_date)
  SELECT 1,airline_id,aircraft_inventory_id,p_game_date FROM chosen
  ON CONFLICT(world_id,aircraft_inventory_id,game_date) DO NOTHING
  RETURNING id
 )
 SELECT (SELECT count(*) FROM inserted),
  (SELECT count(*) FROM page),
  (SELECT count(*) FROM chosen),
  (SELECT max(aircraft_inventory_id) FROM chosen),
  (SELECT count(*) FROM page)>(SELECT count(*) FROM chosen)
 INTO new_rows,page_rows,selected_rows,cursor_id,more;
 RETURN jsonb_build_object(
  'status','aircraft_operation_jobs_enqueued','worldId',1,
  'gameDate',p_game_date,'jobsEnqueued',new_rows,
  'aircraftScanned',selected_rows,'afterAircraftId',cursor_id,
  'hasMore',more,'flightActivated',false,
  'movementRecorded',false,'ledgerPosted',false);
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_enqueue_aircraft_operations_batch_v1(date,uuid,integer)
 FROM PUBLIC,anon,authenticated;

-- Recover only EXPIRED leases. A stale worker can never complete or move
-- an aircraft after this transition; see the fenced movement function below.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_recover_expired_aircraft_jobs_v1(
 p_limit integer DEFAULT 50
) RETURNS integer LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE recovered integer;
BEGIN
 IF p_limit NOT BETWEEN 1 AND 200 THEN RAISE EXCEPTION USING
  ERRCODE='22023',MESSAGE='SECTION9_INVALID_RECOVERY_LIMIT';END IF;
 WITH expired AS (
  SELECT id FROM airlinerra_game.section9_aircraft_day_operations_jobs_v1
  WHERE status='running' AND lease_until<=clock_timestamp()
  ORDER BY lease_until,id FOR UPDATE SKIP LOCKED LIMIT p_limit
 ),
 updated AS (
  UPDATE airlinerra_game.section9_aircraft_day_operations_jobs_v1 j
  SET status=CASE WHEN j.attempt>=5 THEN 'failed' ELSE 'queued' END,
   lease_token=NULL,lease_until=NULL,
   next_attempt_at=clock_timestamp()+
    make_interval(mins=>least(60,2*(1<<greatest(j.attempt-1,0)))),
   failure_code='WORKER_LEASE_EXPIRED',updated_at=clock_timestamp()
  FROM expired e WHERE j.id=e.id RETURNING j.id
 ) SELECT count(*)::integer INTO recovered FROM updated;
 RETURN recovered;
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_recover_expired_aircraft_jobs_v1(integer)
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_claim_aircraft_operations_v1()
RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j airlinerra_game.section9_aircraft_day_operations_jobs_v1%ROWTYPE;
 token uuid:=gen_random_uuid();
BEGIN
 -- Bounded recovery; no unbounded sweep in one worker invocation.
 PERFORM airlinerra_game.section9_recover_expired_aircraft_jobs_v1(50);
 SELECT * INTO j
 FROM airlinerra_game.section9_aircraft_day_operations_jobs_v1 q
 WHERE q.status='queued' AND q.attempt<5 AND q.next_attempt_at<=clock_timestamp()
 AND NOT EXISTS (
  SELECT 1 FROM airlinerra_game.section9_aircraft_day_operations_jobs_v1 older
  WHERE older.aircraft_inventory_id=q.aircraft_inventory_id
   AND older.game_date<q.game_date AND older.status<>'completed'
 )
 AND EXISTS (
  SELECT 1 FROM public.airlinerra_game_worlds w
  JOIN airlinerra_game.holding_world_clock_v1 c ON c.world_id=w.id
  JOIN airlinerra_game.section9_verified_game_tick_receipts_v1 t
   ON t.world_id=w.id AND t.game_date=q.game_date
  WHERE w.id=1 AND w.state='active' AND w.opens_at<=clock_timestamp()
    AND c.clock_source='authoritative_game_engine'
    AND c.confirmed_game_date>=q.game_date
    AND c.last_verified_at IS NOT NULL
    AND length(coalesce(c.engine_proof_ref,''))>=12
 )
 ORDER BY q.game_date,q.created_at,q.id
 FOR UPDATE OF q SKIP LOCKED LIMIT 1;
 IF NOT FOUND THEN RETURN NULL;END IF;
 UPDATE airlinerra_game.section9_aircraft_day_operations_jobs_v1
 SET status='running',attempt=j.attempt+1,
  lease_token=token,lease_until=clock_timestamp()+interval '3 minutes',
  failure_code=NULL,updated_at=clock_timestamp()
 WHERE id=j.id;
 RETURN jsonb_build_object(
  'status','claimed','jobId',j.id,'worldId',1,
  'airlineId',j.airline_id,'aircraftId',j.aircraft_inventory_id,
  'gameDate',j.game_date,'attempt',j.attempt+1,'leaseToken',token,
  'leaseSeconds',180,'flightActivated',false);
END $f$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_claim_aircraft_operations_v1()
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_heartbeat_aircraft_operations_v1(
 p_job uuid,p_token uuid
) RETURNS boolean LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE ok boolean;
BEGIN
 UPDATE airlinerra_game.section9_aircraft_day_operations_jobs_v1
 SET lease_until=clock_timestamp()+interval '3 minutes',updated_at=clock_timestamp()
 WHERE id=p_job AND status='running' AND lease_token=p_token
  AND lease_until>clock_timestamp() RETURNING true INTO ok;
 IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION USING
  ERRCODE='42501',MESSAGE='SECTION9_STALE_AIRCRAFT_OPERATIONS_WORKER';END IF;
 RETURN true;
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_heartbeat_aircraft_operations_v1(uuid,uuid)
 FROM PUBLIC,anon,authenticated;

-- CRITICAL: movement lease validity and movement SQL run in ONE DATABASE
-- transaction under a locked job row. Expired/reclaimed workers cannot
-- update the operated ledger even if they still hold an old signed event.
CREATE OR REPLACE FUNCTION
 airlinerra_game.section9_record_leased_operated_flight_movement_v1(
 p_job uuid,p_token uuid,
 p_airline uuid,p_schedule uuid,p_schedule_version integer,
 p_local_date date,p_weekly_entry integer,p_phase text,
 p_event_utc timestamptz,p_event_id text,p_verified_hmac text
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE j record;f record;
BEGIN
 SELECT * INTO j
 FROM airlinerra_game.section9_aircraft_day_operations_jobs_v1
 WHERE id=p_job FOR UPDATE;
 IF NOT FOUND OR j.status IS DISTINCT FROM 'running'
 OR j.lease_token IS DISTINCT FROM p_token
 OR j.lease_until<=clock_timestamp()
 OR j.airline_id IS DISTINCT FROM p_airline
 OR j.game_date IS DISTINCT FROM (p_event_utc AT TIME ZONE 'UTC')::date
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_STALE_OR_MISMATCHED_AIRCRAFT_WORKER';END IF;
 SELECT aircraft_inventory_id INTO f
 FROM airlinerra_game.airline_flight_schedule_drafts_v1
 WHERE id=p_schedule AND airline_id=p_airline AND world_id=1;
 IF NOT FOUND OR f.aircraft_inventory_id IS DISTINCT FROM j.aircraft_inventory_id
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_AIRCRAFT_JOB_SCHEDULE_MISMATCH';END IF;
 RETURN airlinerra_game.section9_record_signed_operated_flight_movement_v1(
 p_airline,p_schedule,p_schedule_version,p_local_date,p_weekly_entry,
 p_phase,p_event_utc,p_event_id,p_verified_hmac);
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_record_leased_operated_flight_movement_v1(
 uuid,uuid,uuid,uuid,integer,date,integer,text,timestamptz,text,text)
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_complete_aircraft_operations_v1(
 p_job uuid,p_token uuid,p_processed integer,p_replayed integer
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j record;plan jsonb;expected integer;
BEGIN
 SELECT * INTO j FROM airlinerra_game.section9_aircraft_day_operations_jobs_v1
 WHERE id=p_job FOR UPDATE;
 IF NOT FOUND OR j.status IS DISTINCT FROM 'running'
 OR j.lease_token IS DISTINCT FROM p_token OR j.lease_until<=clock_timestamp()
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_STALE_AIRCRAFT_OPERATIONS_WORKER';END IF;
 IF p_processed NOT BETWEEN 0 AND 500 OR p_replayed NOT BETWEEN 0 AND p_processed
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_OPERATION_COMPLETION_COUNTS';END IF;
 plan:=airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(
  j.airline_id,j.aircraft_inventory_id,j.game_date);
 IF plan->>'status'<>'verified_operational_candidates_only' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_OPERATION_CANDIDATE_SOURCE_NOT_VERIFIED';END IF;
 expected:=(plan->>'eventCount')::integer;
 IF expected IS DISTINCT FROM p_processed OR EXISTS(
  SELECT 1 FROM jsonb_array_elements(plan->'candidates') AS c(event)
  WHERE NOT EXISTS (
   SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
   WHERE m.engine_event_id=c.event->>'eventId'
   AND m.airline_id=j.airline_id
   AND m.aircraft_inventory_id=j.aircraft_inventory_id
   AND m.schedule_id=(c.event->>'scheduleId')::uuid
   AND m.schedule_version=(c.event->>'scheduleVersion')::integer
   AND m.flight_local_date=(c.event->>'flightLocalDate')::date
   AND m.weekly_entry=(c.event->>'weeklyEntry')::integer
   AND m.phase=c.event->>'phase'
   AND (m.actual_event_utc AT TIME ZONE 'UTC')::date=j.game_date
  )
 ) THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_AIRCRAFT_JOB_UNCONFIRMED_MOVEMENT_EVENTS';END IF;
 UPDATE airlinerra_game.section9_aircraft_day_operations_jobs_v1
 SET status='completed',lease_token=NULL,lease_until=NULL,
  processed_events=p_processed,replayed_events=p_replayed,
  completed_at=clock_timestamp(),updated_at=clock_timestamp()
 WHERE id=p_job;
 RETURN jsonb_build_object('status','completed',
  'jobId',p_job,'processed',p_processed,'replayed',p_replayed,
  'movementEventsConfirmed',true,'flightActivated',false,
  'bookingsCreated',false,'ledgerPosted',false);
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_complete_aircraft_operations_v1(uuid,uuid,integer,integer)
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_fail_aircraft_operations_v1(
 p_job uuid,p_token uuid,p_code text
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j record;new_state text;
BEGIN
 SELECT * INTO j FROM airlinerra_game.section9_aircraft_day_operations_jobs_v1
 WHERE id=p_job FOR UPDATE;
 IF NOT FOUND OR j.status IS DISTINCT FROM 'running'
 OR j.lease_token IS DISTINCT FROM p_token OR j.lease_until<=clock_timestamp()
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_STALE_AIRCRAFT_OPERATIONS_WORKER';END IF;
 IF p_code NOT IN ('OPERATION_DECISION_MISSING','MOVEMENT_INGEST_BLOCKED',
  'READINESS_UNVERIFIED','CLOCK_NOT_VERIFIED','ENGINE_EXCEPTION')
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_OPERATION_FAILURE_CODE';END IF;
 new_state:=CASE WHEN j.attempt>=5 THEN 'failed' ELSE 'queued' END;
 UPDATE airlinerra_game.section9_aircraft_day_operations_jobs_v1
 SET status=new_state,lease_token=NULL,lease_until=NULL,
  failure_code=p_code,
  next_attempt_at=clock_timestamp()+
    make_interval(mins=>least(60,2*(1<<greatest(j.attempt-1,0)))),
  updated_at=clock_timestamp()
 WHERE id=p_job;
 RETURN jsonb_build_object(
  'status',new_state,'jobId',p_job,'attempt',j.attempt,
  'failureCode',p_code,'flightActivated',false);
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_fail_aircraft_operations_v1(uuid,uuid,text)
 FROM PUBLIC,anon,authenticated;

COMMENT ON TABLE airlinerra_game.section9_aircraft_day_operations_jobs_v1
 IS 'Private per-aircraft/day durable operations queue. Work is impossible until verified game day and active schedules. Leases are fenced inside movement transaction, not only in worker memory. No automatic dispatch deployment.';
