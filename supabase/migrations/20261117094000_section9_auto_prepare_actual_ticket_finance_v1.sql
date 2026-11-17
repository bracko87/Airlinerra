-- Airlinerra: automatic, bounded, read-only-in-financial-terms
-- post-arrival preparation. One signed arrival+usage receipt generates
-- ONE UNPOSTED_GAME_ESTIMATE record. Never posts revenue or expenses.
-- No conversion of prior demand forecasts into fictitious ticket sales.
-- All public/client roles are denied.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_prepare_arrived_actual_ticket_finance_batch_v1(p_limit integer DEFAULT 25)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 game_hour jsonb;
 next_flight record;
 result jsonb;
 state text;
 scanned integer:=0;
 prepared integer:=0;
 skipped integer:=0;
 blocked integer:=0;
 blockers jsonb:='{}'::jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_PRIVATE_ACTUAL_FINANCE_PREPARATION_BATCH_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_ACTUAL_FINANCE_BATCH_LIMIT';END IF;
 game_hour:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF game_hour->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_hour',
  'inspected',0,'prepared',0,'ledgerPosted',false,'flightActivated',false);END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583729,10043) THEN
  RETURN jsonb_build_object('status','actual_finance_preparation_in_progress',
   'inspected',0,'prepared',0,'ledgerPosted',false,'flightActivated',false);END IF;
 FOR next_flight IN
  SELECT m.flight_occurrence_id
  FROM airlinerra_game.section9_operated_flight_movements_v1 m
  JOIN airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 r
   ON r.physical_flight_id=m.flight_occurrence_id
    AND r.arrived_engine_event_id=m.engine_event_id
  WHERE m.world_id=1 AND m.phase='arrived'
   AND m.actual_event_utc<=(game_hour->>'gameHourUtc')::timestamptz
   AND NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1 existing
    WHERE existing.physical_flight_id=m.flight_occurrence_id)
   AND NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 posted
    WHERE posted.physical_flight_id=m.flight_occurrence_id)
  ORDER BY m.actual_event_utc,m.flight_occurrence_id
  LIMIT p_limit
 LOOP
  scanned:=scanned+1;
  result:=airlinerra_game.section9_prepare_actual_ticket_postarrival_finance_v1(
    next_flight.flight_occurrence_id);
  state:=result->>'status';
  IF state='actual_ticket_estimate_prepared'
   AND result->>'created'='true'
   AND result->>'ledgerPosted'='false'
   AND result->>'readyToPost'='false'
  THEN prepared:=prepared+1;
  ELSIF state='actual_ticket_estimate_replayed'
   AND result->>'ledgerPosted'='false'
  THEN skipped:=skipped+1;
  ELSIF state IN(
    'blocked_unverified_arrival_or_unsupported_cargo',
    'blocked_missing_signed_arrival_and_aircraft_usage',
    'blocked_unverified_postarrival_game_hour',
    'blocked_already_posted_do_not_prepare_twice',
    'blocked_ticket_or_provisional_cost_evidence',
    'finance_preparation_running'
   )
   AND result->>'ledgerPosted'='false'
  THEN
   blocked:=blocked+1;
   blockers:=jsonb_set(blockers,ARRAY[state],
     to_jsonb(coalesce((blockers->>state)::integer,0)+1),true);
  ELSE RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_UNSAFE_ACTUAL_TICKET_FINANCE_PREPARATION_BATCH_RESPONSE';END IF;
 END LOOP;
 RETURN jsonb_build_object(
  'status','verified_arrival_actual_ticket_finance_preflight_complete',
  'verifiedGameHourUtc',game_hour->>'gameHourUtc',
  'inspected',scanned,'prepared',prepared,
  'replayedOrSkipped',skipped,'blocked',blocked,
  'blockerCounts',blockers,
  'ledgerPosted',false,'ticketRevenueRecognized',false,
  'fuelChargePosted',false,'flightActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_prepare_arrived_actual_ticket_finance_batch_v1(integer)
 FROM PUBLIC,anon,authenticated,service_role;
DO $setup$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job
 WHERE jobname='airlinerra-game-postarrival-finance-preflight-v1') THEN
  PERFORM cron.schedule('airlinerra-game-postarrival-finance-preflight-v1',
   '7,17,27,37,47,57 * * * *',
   'SELECT airlinerra_game.section9_prepare_arrived_actual_ticket_finance_batch_v1(25);');
 END IF;
END $setup$;