-- A worker that exhausted its fifth lease must become visibly failed,
-- not remain forever in an expired running state.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_claim_forecast_v1()
 RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j airlinerra_game.section9_demand_jobs_v1%ROWTYPE;
 new_token uuid:=gen_random_uuid();
BEGIN
 -- Skip actively locked jobs; never interfere with an ongoing transaction.
 WITH expired AS (
  SELECT id FROM airlinerra_game.section9_demand_jobs_v1
  WHERE status='running' AND attempt>=5 AND lease_until<clock_timestamp()
  ORDER BY game_date,id FOR UPDATE SKIP LOCKED LIMIT 100
 )
 UPDATE airlinerra_game.section9_demand_jobs_v1 job
 SET status='failed',lease_token=NULL,lease_until=NULL,
  failure_code='TIMEOUT',updated_at=clock_timestamp()
 FROM expired e WHERE job.id=e.id;

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
