-- Captured production definitions, compile-only fixture. No production data.
SET LOCAL check_function_bodies=off;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aircraft_movement_decision_v1(p_phase text, p_state text, p_current_airport text, p_current_occurrence text, p_last_event_utc timestamp with time zone, p_last_departure_utc timestamp with time zone, p_origin text, p_destination text, p_occurrence text, p_event_utc timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 IMMUTABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE reason text;
BEGIN
 IF p_phase IS NULL OR p_phase NOT IN ('departed','arrived') OR
  p_state IS NULL OR p_state NOT IN ('grounded','in_flight') OR
  p_origin IS NULL OR p_destination IS NULL OR
  p_origin=p_destination OR p_occurrence IS NULL OR
  p_event_utc IS NULL OR
  (p_event_utc AT TIME ZONE 'UTC')::date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_MOVEMENT_TRANSITION';END IF;
 reason:=CASE
  WHEN p_last_event_utc IS NOT NULL AND p_event_utc<=p_last_event_utc
   THEN 'NON_MONOTONIC_AIRCRAFT_EVENT'
  WHEN p_phase='departed' AND p_state='in_flight'
   THEN 'AIRCRAFT_ALREADY_IN_FLIGHT'
  WHEN p_phase='departed' AND p_state='grounded'
   AND p_current_airport IS DISTINCT FROM p_origin
   THEN 'AIRCRAFT_AT_WRONG_AIRPORT'
  WHEN p_phase='arrived' AND p_state<>'in_flight'
   THEN 'AIRCRAFT_HAS_NO_DEPARTURE'
  WHEN p_phase='arrived' AND
   p_current_occurrence IS DISTINCT FROM p_occurrence
   THEN 'ARRIVAL_NOT_FOR_CURRENT_FLIGHT'
  WHEN p_phase='arrived' AND
   (p_last_departure_utc IS NULL OR
    p_event_utc<=p_last_departure_utc)
   THEN 'ARRIVAL_NOT_AFTER_DEPARTURE'
  ELSE NULL END;
 IF reason IS NOT NULL THEN
  RETURN jsonb_build_object('allowed',false,'reason',reason,
   'newState',NULL,'newAirport',NULL);
 END IF;
 RETURN jsonb_build_object('allowed',true,'reason','ok',
  'newState',CASE WHEN p_phase='departed' THEN 'in_flight'
                 ELSE 'grounded' END,
  'newAirport',CASE WHEN p_phase='departed' THEN NULL
                   ELSE p_destination END);
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
SET LOCAL check_function_bodies=on;
