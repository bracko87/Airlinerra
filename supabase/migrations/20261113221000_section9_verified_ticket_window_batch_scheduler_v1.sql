-- Private Airlinerra verified-game-day next-seven-days ticket-window scheduler.
-- Allows no sales before the *complete* signed operating release. With the
-- current state (paused), each run is a harmless no-op.
-- Same-day departures are blocked until an authoritative hour-level clock.
-- Repeated runs are idempotent: skip existing dated occurrences and
-- enforce unique schedule/date/weekday-entry keys within opening function.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_open_verified_ticket_window_batch_v1(p_limit integer DEFAULT 50)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 game_day date;
 activation record; execution record; ready record;
 entry record;opened integer:=0;inspected integer:=0;already_open integer:=0;
 blocked integer:=0;result jsonb;failure_status text;blocked_by_status jsonb:='{}'::jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_TICKET_WINDOW_SCHEDULER_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 200 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_TICKET_WINDOW_BATCH_LIMIT_INVALID';END IF;
 game_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF game_day IS NULL THEN
  RETURN jsonb_build_object('status','blocked_unverified_game_clock',
   'opened',0,'bookingsCreated',false,'ledgerPosted',false);END IF;
 SELECT release_state,enabled_at,crew_mode INTO activation
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT release_state,enabled_at INTO execution
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO ready
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF activation.release_state IS DISTINCT FROM 'enabled'
  OR activation.enabled_at IS NULL
  OR activation.crew_mode IS DISTINCT FROM 'deferred_phase1'
  OR execution.release_state IS DISTINCT FROM 'enabled'
  OR execution.enabled_at IS NULL
  OR ready.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
  OR ready.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
  OR ready.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN
  RETURN jsonb_build_object('status','blocked_unreleased_flight_engine',
   'opened',0,'bookingsCreated',false,'ledgerPosted',false);END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583729,10027) THEN
  RETURN jsonb_build_object('status','ticket_window_worker_in_progress',
   'opened',0,'bookingsCreated',false,'ledgerPosted',false);END IF;
 FOR entry IN
  SELECT d.id AS schedule_id,day_value.day_value::date AS local_date,
    w.ordinality::int AS entry_no
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
  JOIN airlinerra_game.section9_verified_schedule_capacity_v1 cap
    ON cap.schedule_id=d.id AND cap.airline_id=d.airline_id
    AND cap.schedule_version=d.version AND cap.passenger_seats>0
  JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
    ON plan.schedule_id=d.id AND plan.airline_id=d.airline_id
    AND plan.economy_fare_usd>0
  CROSS JOIN LATERAL generate_series(
     (game_day+1)::timestamp,(game_day+7)::timestamp,interval '1 day'
   ) day_value(day_value)
  CROSS JOIN LATERAL jsonb_array_elements(d.weekly_schedule)
    WITH ORDINALITY w(item,ordinality)
  WHERE d.world_id=1 AND d.status='active'
    AND d.operationally_verified=true
    AND w.ordinality BETWEEN 1 AND 7
    AND coalesce(w.item->>'day','') ~ '^[0-6]$'
    AND coalesce(w.item->>'time','') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
    AND (w.item->>'day')::integer=
      extract(isodow FROM day_value.day_value)::integer-1
    AND NOT EXISTS (
      SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
      WHERE o.schedule_id=d.id
      AND o.flight_local_date=day_value.day_value::date
      AND o.weekly_entry=w.ordinality)
  ORDER BY day_value.day_value,d.airline_id,d.id,w.ordinality
  LIMIT p_limit
 LOOP
  result:=airlinerra_game.section9_open_verified_game_ticket_occurrence_v1(
    entry.schedule_id,entry.local_date,entry.entry_no);
  inspected:=inspected+1;
  IF result->>'status'='verified_ticket_sales_open'
   AND result->>'ledgerPosted'='false'
   AND result->>'bookingsCreated'='false'
  THEN
   IF result->>'newOccurrence'='true' THEN
    opened:=opened+1;
   ELSE already_open:=already_open+1;END IF;
  ELSIF result->>'status' IN (
   'blocked_game_date_or_seven_day_window',
   'blocked_unreleased_flight_engine',
   'blocked_unverified_schedule_capacity_or_fare',
   'blocked_game_turnaround_policy_missing'
  ) AND result->>'ledgerPosted'='false' THEN
   blocked:=blocked+1;
   failure_status:=result->>'status';
   blocked_by_status:=jsonb_set(blocked_by_status,ARRAY[failure_status],
     to_jsonb(coalesce((blocked_by_status->>failure_status)::integer,0)+1),true);
  ELSE
   RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_UNSAFE_TICKET_WINDOW_WORKER_RESPONSE';END IF;
 END LOOP;
 RETURN jsonb_build_object('status','ticket_window_batch_completed',
 'verifiedGameDate',game_day,'daysAhead',7,
 'scanned',inspected,'opened',opened,
 'previouslyOpened',already_open,'blocked',blocked,
 'blockedReasons',blocked_by_status,
 'ledgerPosted',false,'bookingsCreated',false,
 'hourAccurateSameDayBookingActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_open_verified_ticket_window_batch_v1(integer)
 FROM PUBLIC,anon,authenticated,service_role;

DO $ticket_cron$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-game-ticket-window-v1')
 THEN
  PERFORM cron.schedule('airlinerra-game-ticket-window-v1','*/5 * * * *',
   'SELECT airlinerra_game.section9_open_verified_ticket_window_batch_v1(50);');
 END IF;
END $ticket_cron$;
