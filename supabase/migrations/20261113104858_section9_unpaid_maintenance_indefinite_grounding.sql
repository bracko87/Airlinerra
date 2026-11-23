-- An unpaid completed-in-time maintenance job never releases the aircraft.
-- Hold the aircraft even after its scheduled service hours expire, until an
-- exactly-once game expense is posted and the service receipt exists.
BEGIN;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_game_maintenance_due_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_game_day date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
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
   AND r.aircraft_inventory_id=p_aircraft AND r.check_code=policy.check_code
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
  IF due THEN due_count:=due_count+1;END IF;
  checks:=checks||jsonb_build_array(jsonb_build_object(
   'checkCode',policy.check_code,'name',policy.display_name,
   'dueGameDate',due_day,'dueAtSinceAllocationHours',due_hours,
   'currentlyDue',due,'groundOnDue',true,
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
  'gameConditionPct',base.game_condition_pct,
  'gameBaselineSource',base.source_kind,
  'physicallyInspected',false,'realManufactureYearVerified',false,
  'gameMaintenanceGrounded',(due_count>0 OR job_block),'gameJobBlocksDate',job_block,'dueCheckCount',due_count,
  'checks',checks,'gameDatePrecisionOnly',true,
  'hourlyGroundingEnforced',false,'maintenanceCompletionSchedulingConnected',true,
  'maintenanceReady',false,'dispatchApproved',false,
  'flightActivated',false,'ledgerPosted',false);
END $fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_game_maintenance_flight_window_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,
 p_departure_utc timestamptz,p_arrival_utc timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO airlinerra_game,pg_catalog AS $fn$
DECLARE v_now timestamptz; d date; first_day date; last_day date;
 result jsonb; reasons text[]:=ARRAY[]::text[];
 overlapping_jobs integer:=0; due_codes text[];
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_MAINTENANCE_FLIGHT_OWNER_MISSING';END IF;
 IF NOT EXISTS(
 SELECT 1 FROM airlinerra_game.airline_aircraft_inventory f
 JOIN airlinerra_game.airlines a ON a.id=f.airline_id
  AND a.owner_player_id=p_player AND a.world_id=1
 JOIN airlinerra_game.world_memberships w ON w.player_id=p_player
  AND w.world_id=1 AND w.state='active'
 WHERE f.id=p_aircraft AND f.airline_id=p_airline
 AND f.ownership_type IN ('owned','leased')
 ) THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_GAME_MAINTENANCE_FLIGHT_NOT_OWNED';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF p_departure_utc IS NULL OR p_arrival_utc IS NULL
 OR p_arrival_utc<=p_departure_utc
 OR p_arrival_utc>p_departure_utc+interval '72 hours'
 OR p_departure_utc<v_now OR p_departure_utc>v_now+interval '42 days'
 THEN RETURN jsonb_build_object('status','invalid_or_unverified_flight_window',
  'flightWindowClear',false,'readOnly',true,'hourlyJobOverlapChecked',false,
  'dispatchApproved',false,'flightActivated',false,'ledgerPosted',false,
  'blockers',jsonb_build_array('GAME_MAINTENANCE_FLIGHT_TIMES_NOT_VERIFIED'));END IF;

 first_day:=(p_departure_utc AT TIME ZONE 'Europe/Berlin')::date;
 last_day:=(p_arrival_utc AT TIME ZONE 'Europe/Berlin')::date;
 FOR d IN SELECT x::date FROM generate_series(
  first_day::timestamp,last_day::timestamp,interval '1 day') AS x
 LOOP
  result:=airlinerra_game.section9_owned_game_maintenance_due_v1(
   p_player,p_airline,p_aircraft,d);
  IF result->>'readOnly' IS DISTINCT FROM 'true'
   OR result->>'maintenanceReady' IS DISTINCT FROM 'false'
   OR result->>'dispatchApproved' IS DISTINCT FROM 'false'
   OR result->>'gameDatePrecisionOnly' IS DISTINCT FROM 'true'
   OR result->>'dueCheckCount' IS NULL
  THEN RETURN jsonb_build_object('status','maintenance_daily_evidence_missing',
   'readOnly',true,'flightWindowClear',false,'hourlyJobOverlapChecked',false,
   'dispatchApproved',false,'flightActivated',false,'ledgerPosted',false,
   'blockers',jsonb_build_array('GAME_MAINTENANCE_DAILY_EVIDENCE_MISSING'));END IF;
  IF (result->>'dueCheckCount')::integer>0 THEN
   reasons:=array_append(reasons,'GAME_MAINTENANCE_CHECK_DUE');
  END IF;
 END LOOP;

 SELECT count(*)::integer INTO overlapping_jobs
 FROM airlinerra_game.section9_game_maintenance_jobs_v1 j
 WHERE j.world_id=1 AND j.airline_id=p_airline AND j.aircraft_inventory_id=p_aircraft
  AND j.game_start_utc<p_arrival_utc
  AND ((j.status IN ('scheduled','in_progress') AND j.game_end_utc>p_departure_utc)
       OR j.status='payment_required');
 IF overlapping_jobs>0 THEN
  reasons:=array_append(reasons,'GAME_MAINTENANCE_JOB_TIME_OVERLAP');END IF;
 reasons:=ARRAY(SELECT DISTINCT x FROM unnest(reasons) AS x ORDER BY x);
 RETURN jsonb_build_object(
  'status',CASE WHEN cardinality(reasons)=0
      THEN 'game_maintenance_window_no_conflict'
      ELSE 'game_maintenance_flight_window_blocked' END,
  'worldId',1,'readOnly',true,
  'departureUtc',p_departure_utc,'arrivalUtc',p_arrival_utc,
  'flightWindowClear',cardinality(reasons)=0,
  'hourlyJobOverlapChecked',true,'crossDayDueConservative',true,
  'overlappingGameMaintenanceJobs',overlapping_jobs,
  'blockers',to_jsonb(reasons),
  'flightActivated',false,'dispatchApproved',false,'ledgerPosted',false);
END $fn$;
COMMIT;