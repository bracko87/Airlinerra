-- Section 9: read back ONLY completed immutable flight-forecast chunks.
-- Private backend pre-settlement guard, not an endpoint for player bookings.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_completed_flight_chunk_page_v1(
 p_world_id smallint,p_game_date date,p_after_chunk integer DEFAULT (-1),
 p_limit integer DEFAULT 5
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j airlinerra_game.section9_demand_jobs_v1%ROWTYPE;
 chunks jsonb;
BEGIN
 IF p_world_id<>1 OR p_game_date IS NULL
   OR p_game_date NOT BETWEEN DATE '2000-01-01' AND DATE '2200-12-31'
   OR p_after_chunk NOT BETWEEN (-1) AND 9999
   OR p_limit NOT BETWEEN 1 AND 5
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_COMPLETED_CHUNK_PAGE';END IF;

 SELECT * INTO j FROM airlinerra_game.section9_demand_jobs_v1
 WHERE world_id=p_world_id AND game_date=p_game_date
  AND model_version='network_forecast_v1';
 IF NOT FOUND THEN RETURN jsonb_build_object(
  'status','missing','gameDate',p_game_date,'readOnly',true,
  'flightRows',null,'chunks','[]'::jsonb);
 END IF;
 IF j.status<>'completed' THEN RETURN jsonb_build_object(
  'status','not_completed','gameDate',p_game_date,
  'jobStatus',j.status,'readOnly',true,
  'flightRows',null,'chunks','[]'::jsonb);
 END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
  'chunkNumber',c.chunk_number,'rows',c.result_rows)
   ORDER BY c.chunk_number),'[]'::jsonb)
 INTO chunks
 FROM (
  SELECT chunk_number,result_rows FROM
   airlinerra_game.section9_demand_job_chunks_v1
  WHERE job_id=j.id AND attempt=j.attempt AND chunk_kind='flight'
   AND chunk_number>p_after_chunk
  ORDER BY chunk_number
  LIMIT p_limit
 ) c;
 RETURN jsonb_build_object('status','completed',
  'jobId',j.id,'attempt',j.attempt,'gameDate',p_game_date,
  'flightRows',j.completed_flight_rows,
  'readOnly',true,'chunks',chunks);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_completed_flight_chunk_page_v1(
 smallint,date,integer,integer) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section9_completed_flight_chunk_page_v1(
 smallint,date,integer,integer) IS
 'Read-only private completed flight forecasts for cross-date capacity reconciliation; no ledger, ticket or cash side effects.';
