BEGIN;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_cancel_reserved_relocation_v1(p_player uuid,p_airline uuid,p_trip uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE t record; pos jsonb; departed boolean; arrived boolean; paid numeric; n int; expected_airport text;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_RELOCATION_CANCEL_ONLY';END IF;
 SELECT r.* INTO t FROM airlinerra_game.section9_maintenance_relocation_trips_v1 r JOIN airlinerra_game.airlines a ON a.id=r.airline_id AND a.owner_player_id=p_player AND a.world_id=1 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active' WHERE r.id=p_trip AND r.airline_id=p_airline AND r.owner_player_id=p_player FOR UPDATE OF r;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='RELOCATION_NOT_OWNED';END IF;
 IF t.status='cancelled' THEN RETURN jsonb_build_object('status','cancelled','cancelled',true,'replayed',true,'ledgerPosted',false);END IF;
 IF t.status<>'reserved' THEN RETURN jsonb_build_object('status','relocation_not_cancellable','cancelled',false,'ledgerPosted',false);END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=t.aircraft_inventory_id AND airline_id=p_airline FOR UPDATE;
 SELECT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=p_trip AND weekly_entry=1 AND phase='departed'),EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=p_trip AND weekly_entry=1 AND phase='arrived') INTO departed,arrived;
 IF (departed AND NOT arrived) OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=p_trip AND weekly_entry=2 AND phase='departed') THEN RETURN jsonb_build_object('status','relocation_aircraft_in_flight_or_return_started','cancelled',false,'ledgerPosted',false);END IF;
 IF arrived AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 j JOIN airlinerra_game.section9_game_maintenance_service_receipts_v1 m ON m.job_id=j.job_id WHERE j.job_id=t.maintenance_job_id AND j.status='completed' AND m.paid_ledger_entry_id IS NOT NULL) THEN RETURN jsonb_build_object('status','relocation_service_not_completed','cancelled',false,'ledgerPosted',false);END IF;
 expected_airport:=CASE WHEN arrived THEN t.provider_airport_key ELSE t.origin_airport_key END;
 pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(p_player,p_airline,t.aircraft_inventory_id,airlinerra_game.section9_verified_permission_game_day_v1());
 IF pos->>'verified' IS DISTINCT FROM 'true' OR pos->>'atGroundAirport' IS DISTINCT FROM 'true' OR pos->>'airportKey' IS DISTINCT FROM expected_airport THEN RETURN jsonb_build_object('status','relocation_position_unverified','cancelled',false,'ledgerPosted',false);END IF;
 SELECT coalesce(sum(fuel_cost_usd+airport_fees_usd),0) INTO paid FROM airlinerra_game.section9_relocation_leg_expense_receipts_v1 WHERE trip_id=p_trip;
 IF arrived THEN SELECT paid+settled_cost_usd INTO paid FROM airlinerra_game.section9_game_maintenance_service_receipts_v1 WHERE job_id=t.maintenance_job_id;END IF;
 DELETE FROM airlinerra_game.section6_dated_relocation_slots_v1 WHERE trip_id=p_trip AND (NOT departed OR leg='return');
 GET DIAGNOSTICS n=ROW_COUNT;
 UPDATE airlinerra_game.section9_maintenance_relocation_trips_v1 SET status='cancelled',last_attempt_at=airlinerra_game.section9_verified_world_instant_v1(),last_result=CASE WHEN arrived THEN 'return_cancelled_aircraft_remains_at_provider' ELSE 'cancelled_before_departure' END WHERE id=p_trip;
 RETURN jsonb_build_object('status','cancelled','cancelled',true,'slotsReleased',n,'airportKey',expected_airport,'expensesAlreadyPaidUsd',paid,'ledgerPosted',false,'replayed',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_cancel_reserved_relocation_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_advance_maintenance_relocations_v1(p_limit integer DEFAULT 25)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE t record; v_now timestamptz; r jsonb; p_leg int; p_phase text; attempted int:=0; moved int:=0; completed int:=0; blocked int:=0; decision text;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_RELOCATION_WORKER_ONLY';END IF;
 IF p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'INVALID_RELOCATION_WORKER_LIMIT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_relocation_release_v1 WHERE world_id=1 AND reservation_enabled AND execution_enabled) THEN RETURN jsonb_build_object('status','relocation_execution_not_released','checked',0,'movements',0,'completed',0);END IF;
 IF NOT pg_try_advisory_xact_lock(583734,45) THEN RETURN jsonb_build_object('status','relocation_worker_already_running');END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 FOR t IN SELECT * FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE status='reserved' AND departure_utc<=v_now ORDER BY last_attempt_at NULLS FIRST,departure_utc LIMIT p_limit FOR UPDATE SKIP LOCKED
 LOOP
  attempted:=attempted+1;
  BEGIN
   p_leg:=NULL;p_phase:=NULL;
   IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=t.id AND weekly_entry=1 AND phase='departed') THEN p_leg:=1;p_phase:='departed';
   ELSIF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=t.id AND weekly_entry=1 AND phase='arrived') THEN IF (t.quote#>>'{outbound,arrivalUtc}')::timestamptz<=v_now THEN p_leg:=1;p_phase:='arrived';END IF;
   ELSIF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=t.id AND weekly_entry=2 AND phase='departed') THEN IF (t.quote#>>'{return,departureUtc}')::timestamptz<=v_now THEN p_leg:=2;p_phase:='departed';END IF;
   ELSIF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=t.id AND weekly_entry=2 AND phase='arrived') THEN IF (t.quote#>>'{return,arrivalUtc}')::timestamptz<=v_now THEN p_leg:=2;p_phase:='arrived';END IF;
   ELSIF t.available_utc<=v_now AND (SELECT count(*) FROM airlinerra_game.section9_relocation_leg_expense_receipts_v1 WHERE trip_id=t.id)=2 AND EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 j JOIN airlinerra_game.section9_game_maintenance_service_receipts_v1 m ON m.job_id=j.job_id WHERE j.job_id=t.maintenance_job_id AND j.status='completed' AND m.paid_ledger_entry_id IS NOT NULL) THEN
    UPDATE airlinerra_game.section9_maintenance_relocation_trips_v1 SET status='completed',completed_at=v_now,last_attempt_at=v_now,last_result='completed' WHERE id=t.id;
    completed:=completed+1;CONTINUE;
   END IF;
   IF p_leg=1 AND p_phase='departed' AND t.departure_utc<=v_now-interval '10 minutes' THEN
    r:=airlinerra_game.section9_cancel_reserved_relocation_v1(t.owner_player_id,t.airline_id,t.id);
    IF r->>'cancelled'='true' THEN UPDATE airlinerra_game.section9_maintenance_relocation_trips_v1 SET last_result='outbound_missed_cancelled' WHERE id=t.id;CONTINUE;END IF;
   END IF;
   IF p_leg=2 AND p_phase='departed' AND (t.quote#>>'{return,departureUtc}')::timestamptz<=v_now-interval '10 minutes' THEN
    UPDATE airlinerra_game.section9_maintenance_relocation_trips_v1 SET last_attempt_at=v_now,last_result='return_recovery_required' WHERE id=t.id;
    blocked:=blocked+1;CONTINUE;
   END IF;
   decision:='awaiting_next_event_or_service';
   IF p_leg IS NOT NULL THEN
    r:=airlinerra_game.section9_execute_relocation_leg_event_v1(t.id,p_leg,p_phase);
    decision:=coalesce(r->>'status','event_not_verified');
    IF r->>'movementRecorded'='true' THEN moved:=moved+1;ELSE blocked:=blocked+1;END IF;
   END IF;
   UPDATE airlinerra_game.section9_maintenance_relocation_trips_v1 SET last_attempt_at=v_now,last_result=decision WHERE id=t.id;
  EXCEPTION WHEN OTHERS THEN
   blocked:=blocked+1;
   UPDATE airlinerra_game.section9_maintenance_relocation_trips_v1 SET last_attempt_at=v_now,last_result='relocation_event_failed' WHERE id=t.id;
  END;
 END LOOP;
 RETURN jsonb_build_object('status','relocation_worker_processed','checked',attempted,'movements',moved,'completed',completed,'blocked',blocked);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_game_maintenance_due_v1(p_player uuid, p_airline uuid, p_aircraft uuid, p_game_day date)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 base record;
 state record;
 clock record;
 policy record;
 latest record;
 last_anchor date;
 last_hours numeric;
 has_receipt boolean:=false;
 job_block boolean:=false;
 day_start_utc timestamptz;
 day_end_utc timestamptz;
 due_day date;
 due_hours numeric;
 due boolean;
 due_count integer:=0;
 total integer:=0;
 checks jsonb:='[]'::jsonb;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL OR p_game_day IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_INVALID_GAME_MAINTENANCE_DUE_REQUEST';END IF;
 IF NOT EXISTS (
  SELECT 1 FROM airlinerra_game.airline_aircraft_inventory f
  JOIN airlinerra_game.airlines a ON a.id=f.airline_id AND a.world_id=1
   AND a.owner_player_id=p_player
  JOIN airlinerra_game.world_memberships w
   ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
  WHERE f.id=p_aircraft AND f.airline_id=p_airline
  AND f.ownership_type IN ('owned','leased')
 ) THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_GAME_MAINTENANCE_NOT_OWNED';END IF;
 SELECT c.confirmed_game_date,c.clock_source,c.last_verified_at,
        w.state AS world_state
 INTO clock FROM airlinerra_game.holding_world_clock_v1 c
 JOIN public.airlinerra_game_worlds w ON w.id=c.world_id
 WHERE c.world_id=1;
 IF NOT FOUND OR clock.world_state IS DISTINCT FROM 'active'
 OR clock.clock_source IS DISTINCT FROM 'authoritative_game_engine'
 OR clock.last_verified_at IS NULL OR clock.confirmed_game_date IS NULL
 OR p_game_day<clock.confirmed_game_date OR p_game_day>clock.confirmed_game_date+42
 THEN RETURN jsonb_build_object('status','game_clock_unavailable_or_outside_42_day_window',
  'readOnly',true,'gameMaintenanceGrounded',true,'maintenanceReady',false,
  'dispatchApproved',false,'flightActivated',false,'ledgerPosted',false,
  'reason','AUTHORITATIVE_GAME_DATE_REQUIRED'); END IF;
 SELECT b.* INTO base
 FROM airlinerra_game.section9_starter_game_airframe_baselines_v1 b
 WHERE b.aircraft_inventory_id=p_aircraft AND b.airline_id=p_airline
  AND b.owner_player_id=p_player AND b.world_id=1;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','game_baseline_missing',
  'readOnly',true,'gameMaintenanceGrounded',true,
  'maintenanceReady',false,'dispatchApproved',false,
  'flightActivated',false,'ledgerPosted',false,
  'reason','STARTER_GAME_MAINTENANCE_BASELINE_NOT_ESTABLISHED');END IF;
 IF p_game_day<base.game_baseline_date THEN RETURN jsonb_build_object(
  'status','game_baseline_in_future','readOnly',true,'gameMaintenanceGrounded',true,
  'maintenanceReady',false,'dispatchApproved',false,'flightActivated',false,
  'ledgerPosted',false);END IF;
 SELECT m.* INTO state FROM airlinerra_game.aircraft_maintenance_state_v1 m
 WHERE m.aircraft_inventory_id=p_aircraft AND m.airline_id=p_airline;
 IF NOT FOUND OR state.tracked_flight_hours IS NULL OR
   state.tracked_flight_cycles IS NULL OR
   state.tracked_flight_hours<0 OR state.tracked_flight_cycles<0 OR
   state.verified_tracking_started_utc IS NULL
 THEN RETURN jsonb_build_object('status','game_usage_missing',
  'readOnly',true,'gameMaintenanceGrounded',true,
  'maintenanceReady',false,'dispatchApproved',false,
  'flightActivated',false,'ledgerPosted',false);END IF;
 day_start_utc:=p_game_day::timestamp AT TIME ZONE 'Europe/Berlin';
 day_end_utc:=(p_game_day+1)::timestamp AT TIME ZONE 'Europe/Berlin';
 SELECT EXISTS(SELECT 1
  FROM airlinerra_game.section9_game_maintenance_jobs_v1 j
  WHERE j.world_id=1 AND j.airline_id=p_airline AND j.aircraft_inventory_id=p_aircraft
  AND j.game_start_utc<day_end_utc
  AND ((j.status IN ('scheduled','in_progress') AND j.game_end_utc>day_start_utc)
       OR j.status='payment_required'))
 INTO job_block;
 FOR policy IN SELECT * FROM airlinerra_game.maintenance_check_policy_v1
 ORDER BY CASE check_code WHEN 'daily' THEN 1 WHEN 'weekly' THEN 2
  WHEN 'a' THEN 3 WHEN 'b' THEN 4 WHEN 'c' THEN 5 WHEN 'd' THEN 6
  ELSE 7 END LOOP
  total:=total+1;
  due_day:=NULL; due_hours:=NULL; latest:=NULL;
  SELECT r.* INTO latest FROM airlinerra_game.section9_game_maintenance_service_receipts_v1 r
  WHERE r.world_id=1 AND r.airline_id=p_airline
   AND r.aircraft_inventory_id=p_aircraft AND (r.check_code=policy.check_code OR (policy.check_code='daily' AND r.check_code IN ('weekly','a','b','c','d')) OR (policy.check_code='weekly' AND r.check_code IN ('a','b','c','d')))
   AND r.source_kind='verified_game_service_job_v1'
   AND r.paid_ledger_entry_id IS NOT NULL
   AND r.settled_cost_usd>0
   AND EXISTS (
    SELECT 1 FROM airlinerra_game.airline_ledger ledger
    WHERE ledger.id=r.paid_ledger_entry_id
     AND ledger.airline_id=r.airline_id
     AND ledger.entry_kind='EXPENSE'
     AND ledger.amount_usd=-r.settled_cost_usd
   )
   AND r.game_completed_at_utc<day_end_utc
  ORDER BY r.game_completed_at_utc DESC,r.created_at DESC LIMIT 1;
  has_receipt:=FOUND;
  last_anchor:=CASE WHEN has_receipt THEN
     (latest.game_completed_at_utc AT TIME ZONE 'Europe/Berlin')::date
     ELSE base.game_baseline_date END;
  last_hours:=CASE WHEN has_receipt THEN latest.flight_hours_at_game_completion
     ELSE 0::numeric END;
  IF policy.calendar_interval_hours IS NOT NULL THEN
   -- Conservative date-only gate; a more precise flight check is still required.
   due_day:=last_anchor+ceil(policy.calendar_interval_hours::numeric/24)::integer;
  ELSIF policy.calendar_interval_months IS NOT NULL THEN
   due_day:=(last_anchor+make_interval(months=>policy.calendar_interval_months))::date;
  END IF;
  IF policy.flight_hour_interval IS NOT NULL THEN
   due_hours:=last_hours+policy.flight_hour_interval;
  END IF;
  due:=(due_day IS NOT NULL AND p_game_day>=due_day)
    OR (due_hours IS NOT NULL AND state.tracked_flight_hours>=due_hours);
  IF has_receipt AND policy.check_code IN ('daily','weekly') AND p_game_day=(airlinerra_game.section9_verified_world_instant_v1() AT TIME ZONE 'Europe/Berlin')::date THEN
   due:=airlinerra_game.section9_verified_world_instant_v1()>=latest.game_completed_at_utc+make_interval(hours=>policy.calendar_interval_hours);
  END IF;
  IF due THEN due_count:=due_count+1;END IF;
  checks:=checks||jsonb_build_array(jsonb_build_object(
   'checkCode',policy.check_code,'name',policy.display_name,
   'dueGameDate',due_day,'dueAtSinceAllocationHours',due_hours,
   'currentlyDue',due,'groundOnDue',true,'lastSatisfyingCheckCode',CASE WHEN has_receipt THEN latest.check_code ELSE NULL END,'dueAtUtc',CASE WHEN has_receipt AND policy.check_code IN ('daily','weekly') THEN latest.game_completed_at_utc+make_interval(hours=>policy.calendar_interval_hours) ELSE NULL END,
   'downtimeHours',policy.downtime_hours,
   'airportScope',policy.airport_scope,
   'lastCompletedGameCheck',CASE WHEN has_receipt THEN latest.game_completed_at_utc ELSE NULL END,
   'baselineSource',CASE WHEN has_receipt THEN
       'verified_game_service_job_not_physical_airworthiness'
       ELSE 'game_assumed_current_at_commissioning_NOT_actual_completion' END));
 END LOOP;
 IF total<>6 THEN RETURN jsonb_build_object('status','maintenance_policy_incomplete',
  'readOnly',true,'gameMaintenanceGrounded',true,
  'maintenanceReady',false,'dispatchApproved',false,
  'flightActivated',false,'ledgerPosted',false);END IF;
 RETURN jsonb_build_object(
  'status',CASE WHEN due_count>0 THEN 'game_maintenance_due' WHEN job_block THEN 'game_maintenance_job_reserved' ELSE
   'game_maintenance_preview_not_dispatch_approved' END,
  'readOnly',true,'worldId',1,'aircraftInventoryId',p_aircraft,
  'requestedGameDate',p_game_day,'authoritativeGameDate',clock.confirmed_game_date,
  'gameBaselineDate',base.game_baseline_date,
  'gameAgeYears',base.game_age_years,
  'gameConditionPct',(airlinerra_game.section9_game_airframe_condition_v1(p_airline,p_aircraft,airlinerra_game.section9_verified_world_instant_v1())->>'conditionPct')::numeric,
  'gameBaselineSource',base.source_kind,
  'physicallyInspected',false,'realManufactureYearVerified',false,
  'gameMaintenanceGrounded',(due_count>0 OR job_block),'gameJobBlocksDate',job_block,'dueCheckCount',due_count,
  'checks',checks,'gameDatePrecisionOnly',true,
  'hourlyGroundingEnforced',false,'maintenanceCompletionSchedulingConnected',true,
  'maintenanceReady',false,'dispatchApproved',false,
  'flightActivated',false,'ledgerPosted',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(p_owner uuid, p_airline uuid, p_aircraft uuid, p_depart_utc timestamp with time zone, p_arrive_utc timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 hour_proof jsonb;
 state_row record;
 due jsonb;item jsonb;
 current_hour timestamptz;
 check_day date;
 first_day date;
 last_day date;
 flight_hours numeric;
 pending_jobs integer:=0;
 blocked text[]:=ARRAY[]::text[];
 max_due_count integer:=0;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
   RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_TRUSTED_MAINTENANCE_WINDOW_ONLY';END IF;
 IF p_owner IS NULL OR p_airline IS NULL OR p_aircraft IS NULL
 OR p_depart_utc IS NULL OR p_arrive_utc IS NULL
 OR p_arrive_utc<=p_depart_utc OR
 p_arrive_utc>p_depart_utc+interval '72 hours'
 THEN RETURN jsonb_build_object('status','invalid_maintenance_dispatch_window',
  'readOnly',true,'gameMaintenanceClear',false,
  'dispatchApproved',false,'ledgerPosted',false);END IF;
 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_hour',
  'readOnly',true,'gameMaintenanceClear',false,
  'dispatchApproved',false,'ledgerPosted',false);END IF;
 current_hour:=(hour_proof->>'gameHourUtc')::timestamptz;
 IF p_depart_utc<current_hour-interval '15 minutes'
 OR p_depart_utc>current_hour+interval '42 days'
 THEN RETURN jsonb_build_object('status','blocked_maintenance_flight_window_outside_verified_clock',
  'readOnly',true,'gameMaintenanceClear',false,
  'dispatchApproved',false,'ledgerPosted',false);END IF;
 SELECT m.tracked_flight_hours,m.tracked_flight_cycles,
  m.verified_tracking_started_utc
 INTO state_row
 FROM airlinerra_game.aircraft_maintenance_state_v1 m
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=m.aircraft_inventory_id AND f.airline_id=m.airline_id
 JOIN airlinerra_game.airlines a
  ON a.id=f.airline_id AND a.owner_player_id=p_owner AND a.world_id=1
 JOIN airlinerra_game.world_memberships w
  ON w.world_id=1 AND w.player_id=p_owner AND w.state='active'
 WHERE m.aircraft_inventory_id=p_aircraft AND m.airline_id=p_airline
  AND f.fleet_status='in_service' AND f.ownership_type IN('owned','leased');
 IF NOT FOUND OR state_row.tracked_flight_hours IS NULL
 OR state_row.tracked_flight_hours<0
 OR state_row.tracked_flight_cycles IS NULL
 OR state_row.tracked_flight_cycles<0
 OR state_row.verified_tracking_started_utc IS NULL
 THEN RETURN jsonb_build_object('status','blocked_game_aircraft_usage_missing',
  'readOnly',true,'gameMaintenanceClear',false,
  'dispatchApproved',false,'ledgerPosted',false);END IF;
 flight_hours:=extract(epoch FROM(p_arrive_utc-p_depart_utc))/3600;
 first_day:=(p_depart_utc AT TIME ZONE 'Europe/Berlin')::date;
 last_day:=(p_arrive_utc AT TIME ZONE 'Europe/Berlin')::date;
 FOR check_day IN
  SELECT g::date FROM generate_series(
   first_day::timestamp,last_day::timestamp,interval '1 day') g
 LOOP
  due:=airlinerra_game.section9_owned_game_maintenance_due_v1(
   p_owner,p_airline,p_aircraft,check_day);
  IF due->>'readOnly' IS DISTINCT FROM 'true'
   OR due->>'dueCheckCount' IS NULL
   OR due->>'gameJobBlocksDate' IS NULL
   OR due->>'status' NOT IN
     ('game_maintenance_due','game_maintenance_job_reserved',
      'game_maintenance_preview_not_dispatch_approved')
   OR jsonb_typeof(due->'checks')<>'array'
   OR jsonb_array_length(due->'checks')<>6
  THEN blocked:=array_append(blocked,'MAINTENANCE_DUE_EVIDENCE_UNAVAILABLE');
   CONTINUE;END IF;
  max_due_count:=greatest(max_due_count,(due->>'dueCheckCount')::int);
  -- Exact job overlap is evaluated below; a check on the same date alone is not a conflict.
  FOR item IN SELECT value FROM jsonb_array_elements(due->'checks')
  LOOP
    IF item->>'checkCode' IN ('daily','weekly') AND item->>'lastCompletedGameCheck' IS NOT NULL THEN
     IF (item->>'lastCompletedGameCheck')::timestamptz>p_depart_utc THEN blocked:=array_append(blocked,'MAINTENANCE_SERVICE_NOT_COMPLETED_AT_DEPARTURE');
     ELSIF p_arrive_utc>=(item->>'lastCompletedGameCheck')::timestamptz+make_interval(hours=>CASE item->>'checkCode' WHEN 'daily' THEN 24 ELSE 168 END) THEN blocked:=array_append(blocked,'MAINTENANCE_CHECK_DUE_'||upper(item->>'checkCode'));END IF;
    ELSIF item->>'currentlyDue'='true' THEN
     blocked:=array_append(blocked,
      'MAINTENANCE_CHECK_DUE_'||upper(coalesce(item->>'checkCode','UNKNOWN')));
    ELSIF item->>'dueAtSinceAllocationHours' IS NOT NULL
     AND (item->>'dueAtSinceAllocationHours')::numeric
      <=state_row.tracked_flight_hours+flight_hours
    THEN blocked:=array_append(blocked,
      'MAINTENANCE_HOUR_LIMIT_BEFORE_ARRIVAL_'||
      upper(coalesce(item->>'checkCode','UNKNOWN')));
    END IF;
  END LOOP;
 END LOOP;
 SELECT count(*) INTO pending_jobs
 FROM airlinerra_game.section9_game_maintenance_jobs_v1 j
 WHERE j.world_id=1 AND j.airline_id=p_airline
  AND j.aircraft_inventory_id=p_aircraft
  AND ((j.status IN('scheduled','in_progress')
    AND j.game_start_utc<p_arrive_utc
    AND j.game_end_utc>p_depart_utc)
   OR j.status='payment_required');
 IF pending_jobs>0 THEN
  blocked:=array_append(blocked,'MAINTENANCE_JOB_OVERLAP_OR_UNPAID');END IF;
 blocked:=ARRAY(SELECT DISTINCT val FROM unnest(blocked) val ORDER BY val);
 RETURN jsonb_build_object(
  'status',CASE WHEN cardinality(blocked)=0
    THEN 'game_maintenance_window_clear_for_dispatch_preflight'
    ELSE 'game_maintenance_window_blocked' END,
  'readOnly',true,'worldId',1,
  'modelVersion','GAME_MAINTENANCE_HOUR_WINDOW_V1',
  'departureUtc',p_depart_utc,'arrivalUtc',p_arrive_utc,
  'trackedFlightHoursAtCheck',state_row.tracked_flight_hours,
  'flightHoursPlanned',round(flight_hours,3),
  'dailyCheckCountDue',max_due_count,'overlappingMaintenanceJobs',pending_jobs,
  'gameMaintenanceClear',cardinality(blocked)=0,
  'blockers',to_jsonb(blocked),
  'realWorldAirworthinessVerified',false,
  'independentOperatingReleaseVerified',false,
  'dispatchApproved',false,'movementRecorded',false,'ledgerPosted',false);
END $function$;
COMMIT;
