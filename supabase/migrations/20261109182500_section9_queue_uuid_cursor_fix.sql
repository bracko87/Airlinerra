-- PostgreSQL UUID has no MAX aggregate: use ordered keyset endpoint.
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
  (SELECT aircraft_inventory_id FROM chosen ORDER BY aircraft_inventory_id DESC LIMIT 1),
  (SELECT count(*) FROM page)>(SELECT count(*) FROM chosen)
 INTO new_rows,page_rows,selected_rows,cursor_id,more;
 RETURN jsonb_build_object(
  'status','aircraft_operation_jobs_enqueued','worldId',1,
  'gameDate',p_game_date,'jobsEnqueued',new_rows,
  'aircraftScanned',selected_rows,'afterAircraftId',cursor_id,
  'hasMore',more,'flightActivated',false,
  'movementRecorded',false,'ledgerPosted',false);
END $f$;
