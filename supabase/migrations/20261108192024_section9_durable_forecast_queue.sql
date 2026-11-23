-- Section 9: durable, fail-closed processing lifecycle for read-only forecasts.
-- Does NOT activate flights, reserve seats, alter airport slots or post to
-- airline_ledger. It is safe to deploy before the commercial flight engine.
--
-- One job per world/date/model is processed by one leased worker at a time.
-- A fencing token rejects stale workers. Chunks are invisible to player APIs
-- until the worker has finished and validated the expected counts.

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_demand_jobs_v1(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK (world_id=1),
 game_date date NOT NULL,
 model_version text NOT NULL DEFAULT 'network_forecast_v1'
   CHECK(model_version='network_forecast_v1'),
 status text NOT NULL DEFAULT 'queued'
   CHECK(status IN ('queued','running','completed','failed')),
 attempt integer NOT NULL DEFAULT 0 CHECK(attempt BETWEEN 0 AND 5),
 lease_token uuid,
 lease_until timestamptz,
 expected_flight_rows integer,
 expected_market_rows integer,
 completed_flight_rows integer,
 completed_market_rows integer,
 failure_code text,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 started_at timestamptz,
 completed_at timestamptz,
 UNIQUE(world_id,game_date,model_version),
 CONSTRAINT section9_job_running_lease_check CHECK (
  (status='running' AND lease_token IS NOT NULL AND lease_until IS NOT NULL)
  OR (status<>'running' AND lease_token IS NULL AND lease_until IS NULL)
 ),
 CONSTRAINT section9_job_completed_counts_check CHECK (
  status<>'completed' OR
  (completed_at IS NOT NULL AND expected_flight_rows=completed_flight_rows
   AND expected_market_rows=completed_market_rows
   AND completed_flight_rows>=0 AND completed_market_rows>=0)
 )
);
ALTER TABLE airlinerra_game.section9_demand_jobs_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_demand_jobs_v1 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_jobs_claim_idx
 ON airlinerra_game.section9_demand_jobs_v1(status,game_date,created_at)
 WHERE status IN ('queued','running');

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_demand_job_chunks_v1(
 job_id uuid NOT NULL REFERENCES airlinerra_game.section9_demand_jobs_v1(id)
   ON DELETE CASCADE,
 attempt integer NOT NULL CHECK(attempt BETWEEN 1 AND 5),
 chunk_kind text NOT NULL CHECK(chunk_kind IN ('flight','market')),
 chunk_number integer NOT NULL CHECK(chunk_number BETWEEN 0 AND 9999),
 result_rows jsonb NOT NULL CHECK(jsonb_typeof(result_rows)='array'
   AND jsonb_array_length(result_rows) BETWEEN 1 AND 500),
 row_count integer NOT NULL CHECK(row_count BETWEEN 1 AND 500),
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(job_id,attempt,chunk_kind,chunk_number),
 CONSTRAINT section9_chunk_count_check CHECK(
  jsonb_array_length(result_rows)=row_count),
 CONSTRAINT section9_chunk_size_check CHECK(
  octet_length(result_rows::text)<=500000)
);
ALTER TABLE airlinerra_game.section9_demand_job_chunks_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_demand_job_chunks_v1 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.section9_demand_job_chunks_v1 IS
 'Write-once bounded server-only PREVIEW chunks. No bookings or revenue settlements.';

CREATE OR REPLACE VIEW airlinerra_game.section9_completed_forecast_health_v1
 WITH (security_invoker=true) AS
SELECT world_id,game_date,model_version,status,attempt,
 completed_flight_rows,completed_market_rows,created_at,updated_at,
 started_at,completed_at,failure_code
FROM airlinerra_game.section9_demand_jobs_v1;
REVOKE ALL ON airlinerra_game.section9_completed_forecast_health_v1
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_enqueue_forecast_day_v1(
 p_world smallint,p_day date
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j airlinerra_game.section9_demand_jobs_v1%ROWTYPE;
BEGIN
 IF p_world<>1 OR p_day IS NULL OR p_day NOT BETWEEN DATE '2000-01-01' AND DATE '2200-12-31'
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_GAME_DATE'; END IF;
 INSERT INTO airlinerra_game.section9_demand_jobs_v1(world_id,game_date)
 VALUES(p_world,p_day)
 ON CONFLICT(world_id,game_date,model_version) DO NOTHING;
 SELECT * INTO j FROM airlinerra_game.section9_demand_jobs_v1
 WHERE world_id=p_world AND game_date=p_day AND model_version='network_forecast_v1';
 RETURN jsonb_build_object('jobId',j.id,'gameDate',j.game_date,
  'status',j.status,'attempt',j.attempt,'readOnly',true);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_enqueue_forecast_day_v1(
 smallint,date) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_claim_forecast_v1()
 RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j airlinerra_game.section9_demand_jobs_v1%ROWTYPE;
 new_token uuid:=gen_random_uuid();
BEGIN
 SELECT * INTO j FROM airlinerra_game.section9_demand_jobs_v1
 WHERE attempt<5 AND (status='queued'
   OR (status='running' AND lease_until<clock_timestamp()))
 ORDER BY game_date,created_at,id
 FOR UPDATE SKIP LOCKED LIMIT 1;
 IF NOT FOUND THEN RETURN NULL;END IF;
 DELETE FROM airlinerra_game.section9_demand_job_chunks_v1 WHERE job_id=j.id;
 UPDATE airlinerra_game.section9_demand_jobs_v1
 SET status='running',attempt=j.attempt+1,lease_token=new_token,
 lease_until=clock_timestamp()+interval '10 minutes',
 expected_flight_rows=NULL,expected_market_rows=NULL,
 completed_flight_rows=NULL,completed_market_rows=NULL,
 failure_code=NULL,completed_at=NULL,started_at=clock_timestamp(),updated_at=clock_timestamp()
 WHERE id=j.id;
 RETURN jsonb_build_object('jobId',j.id,'gameDate',j.game_date,
  'attempt',j.attempt+1,'leaseToken',new_token,'readOnly',true);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_claim_forecast_v1()
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_extend_forecast_lease_v1(
 p_job uuid,p_token uuid
) RETURNS boolean LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE ok boolean;
BEGIN
 UPDATE airlinerra_game.section9_demand_jobs_v1
 SET lease_until=clock_timestamp()+interval '10 minutes',
 updated_at=clock_timestamp()
 WHERE id=p_job AND lease_token=p_token AND status='running'
  AND lease_until>clock_timestamp()
 RETURNING true INTO ok;
 IF ok IS DISTINCT FROM true THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_STALE_WORKER';
 END IF;
 RETURN true;
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_extend_forecast_lease_v1(
 uuid,uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_stage_forecast_chunk_v1(
 p_job uuid,p_token uuid,p_kind text,p_number integer,p_rows jsonb
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j airlinerra_game.section9_demand_jobs_v1%ROWTYPE;existing jsonb; count_rows int;
BEGIN
 SELECT * INTO j FROM airlinerra_game.section9_demand_jobs_v1
 WHERE id=p_job FOR UPDATE;
 IF NOT FOUND OR j.status<>'running' OR j.lease_token IS DISTINCT FROM p_token
   OR j.lease_until<=clock_timestamp()
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_STALE_WORKER';END IF;
 IF p_kind NOT IN ('flight','market') OR p_number NOT BETWEEN 0 AND 9999
   OR p_rows IS NULL OR jsonb_typeof(p_rows)<>'array'
   OR jsonb_array_length(p_rows) NOT BETWEEN 1 AND 500
   OR octet_length(p_rows::text)>500000
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_RESULT_CHUNK';END IF;
 count_rows:=jsonb_array_length(p_rows);
 -- Correct, bounded, non-negative numerical data only. Neither kind is ever
 -- interpreted as a financial transaction.
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_rows) x
  WHERE jsonb_typeof(x)<>'object'
   OR (p_kind='flight' AND (
    jsonb_typeof(x->'flightId')<>'string' OR
    jsonb_typeof(x->'passengers')<>'number' OR
    jsonb_typeof(x->'cargoTonnes')<>'number'))
   OR (p_kind='market' AND (
    jsonb_typeof(x->'marketId')<>'string' OR
    jsonb_typeof(x->'demand')<>'number' OR
    jsonb_typeof(x->'allocated')<>'number'))
 ) THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_RESULT_ROW';END IF;
 INSERT INTO airlinerra_game.section9_demand_job_chunks_v1(
  job_id,attempt,chunk_kind,chunk_number,result_rows,row_count)
 VALUES(p_job,j.attempt,p_kind,p_number,p_rows,count_rows)
 ON CONFLICT DO NOTHING;
 SELECT result_rows INTO existing FROM airlinerra_game.section9_demand_job_chunks_v1
 WHERE job_id=p_job AND attempt=j.attempt AND chunk_kind=p_kind
   AND chunk_number=p_number;
 IF existing IS DISTINCT FROM p_rows THEN
  RAISE EXCEPTION USING ERRCODE='23505',MESSAGE='SECTION9_RESULT_CHUNK_CONFLICT';
 END IF;
 RETURN jsonb_build_object('jobId',j.id,'attempt',j.attempt,
  'chunkKind',p_kind,'chunkNumber',p_number,'rows',count_rows,'staged',true);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_stage_forecast_chunk_v1(
 uuid,uuid,text,integer,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_complete_forecast_v1(
 p_job uuid,p_token uuid,p_flights integer,p_markets integer
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j airlinerra_game.section9_demand_jobs_v1%ROWTYPE; count_f int;count_m int;
BEGIN
 SELECT * INTO j FROM airlinerra_game.section9_demand_jobs_v1
 WHERE id=p_job FOR UPDATE;
 IF NOT FOUND OR j.status<>'running' OR j.lease_token IS DISTINCT FROM p_token
   OR j.lease_until<=clock_timestamp()
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_STALE_WORKER';END IF;
 IF p_flights NOT BETWEEN 0 AND 300000 OR p_markets NOT BETWEEN 0 AND 100000
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_EXPECTED_COUNTS';END IF;
 SELECT coalesce(sum(row_count) FILTER(WHERE chunk_kind='flight'),0)::int,
        coalesce(sum(row_count) FILTER(WHERE chunk_kind='market'),0)::int
 INTO count_f,count_m FROM airlinerra_game.section9_demand_job_chunks_v1
 WHERE job_id=p_job AND attempt=j.attempt;
 IF count_f<>p_flights OR count_m<>p_markets THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INCOMPLETE_RESULT';
 END IF;
 UPDATE airlinerra_game.section9_demand_jobs_v1
 SET status='completed',lease_token=NULL,lease_until=NULL,
 expected_flight_rows=p_flights,expected_market_rows=p_markets,
 completed_flight_rows=count_f,completed_market_rows=count_m,
 updated_at=clock_timestamp(),completed_at=clock_timestamp()
 WHERE id=j.id;
 RETURN jsonb_build_object('jobId',j.id,'status','completed',
  'flightRows',count_f,'marketRows',count_m,'readOnly',true,
  'bookingsCreated',false,'ledgerPosted',false);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_complete_forecast_v1(
 uuid,uuid,integer,integer) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_fail_forecast_v1(
 p_job uuid,p_token uuid,p_code text
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j airlinerra_game.section9_demand_jobs_v1%ROWTYPE;
BEGIN
 SELECT * INTO j FROM airlinerra_game.section9_demand_jobs_v1 WHERE id=p_job FOR UPDATE;
 IF NOT FOUND OR j.status<>'running' OR j.lease_token IS DISTINCT FROM p_token
  OR j.lease_until<=clock_timestamp()
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_STALE_WORKER';END IF;
 IF p_code IS NULL OR p_code NOT IN(
 'INVALID_SOURCE','MARKET_DATA_UNAVAILABLE','CAPACITY_INVALID',
 'CONNECTIONS_INVALID','TIMEOUT','INTERNAL_ERROR','RESULT_INVALID')
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_FAILURE_CODE';END IF;
 UPDATE airlinerra_game.section9_demand_jobs_v1
 SET status=CASE WHEN attempt>=5 THEN 'failed' ELSE 'queued' END,
 lease_token=NULL,lease_until=NULL,failure_code=p_code,
 updated_at=clock_timestamp()
 WHERE id=j.id;
 RETURN jsonb_build_object('jobId',j.id,
  'status',CASE WHEN j.attempt>=5 THEN 'failed' ELSE 'queued' END,
  'attempt',j.attempt,'readOnly',true);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_fail_forecast_v1(
 uuid,uuid,text) FROM PUBLIC,anon,authenticated;

COMMENT ON TABLE airlinerra_game.section9_demand_jobs_v1 IS
 'Server-only durable forecasting queue with leased/fenced retry, not a live settlement service.';
