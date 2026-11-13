-- Hour-accurate GAME maintenance departure preflight for every aircraft.
-- Independent of any browser, row scoped to airline owner and active World1 membership.
-- Check daily / weekly / A/B/C/D due dates, cycles/hours and future flight-
-- hour threshold crossing; no new flight may depart if a required check is due.
-- Recheck overlapping maintenance jobs and unpaid work.
-- An unverified airframe/year is *not* described as physical airworthiness.
-- This function alone never grants flight-release approval.
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
  IF (due->>'gameJobBlocksDate')::boolean THEN
   blocked:=array_append(blocked,'SCHEDULED_MAINTENANCE_BLOCKS_FLIGHT');END IF;
  FOR item IN SELECT value FROM jsonb_array_elements(due->'checks')
  LOOP
    IF item->>'currentlyDue'='true' THEN
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
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(
 uuid,uuid,uuid,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
