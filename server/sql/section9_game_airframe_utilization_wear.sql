BEGIN;
-- Provisional game balancing values, not physical airworthiness data.
-- 18 flight hours in a rolling day = recommended utilization; no hard limit.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_game_utilization_wear_multiplier_v1(p_hours numeric)
RETURNS numeric LANGUAGE sql IMMUTABLE STRICT SECURITY INVOKER SET search_path TO 'pg_catalog' AS $fn$
 SELECT round(1+2*power(least(1::numeric,greatest(0::numeric,(p_hours-18)/6)),1.5::numeric),6)
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_game_utilization_wear_multiplier_v1(numeric) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_game_airframe_condition_v1(p_airline uuid,p_aircraft uuid,p_as_of timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE base numeric; condition_now numeric; e record; recent_hours numeric; factor numeric; loss numeric; repairs numeric; total_wear numeric:=0; total_restored numeric:=0; last_factor numeric:=1;
BEGIN
 SELECT b.game_condition_pct INTO base FROM airlinerra_game.section9_starter_game_airframe_baselines_v1 b
 WHERE b.world_id=1 AND b.airline_id=p_airline AND b.aircraft_inventory_id=p_aircraft;
 IF NOT FOUND OR base IS NULL OR p_as_of IS NULL THEN RETURN NULL;END IF;
 condition_now:=base;
 -- Receipts are the exactly-once accounting keys; planning and turnaround are excluded.
 FOR e IN
  SELECT a.actual_event_utc AS happened,'flight'::text AS kind,u.physical_flight_id AS key,u.elapsed_flight_hours AS hours, u.flight_cycles AS cycles,NULL::text AS check_code
  FROM airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 u
  JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.engine_event_id=u.arrived_engine_event_id AND a.flight_occurrence_id=u.physical_flight_id AND a.aircraft_inventory_id=u.aircraft_inventory_id AND a.airline_id=u.airline_id AND a.phase='arrived' AND a.source_kind='signed_operated_game_flight_v1'
  JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.engine_event_id=u.departed_engine_event_id AND d.flight_occurrence_id=u.physical_flight_id AND d.aircraft_inventory_id=u.aircraft_inventory_id AND d.airline_id=u.airline_id AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1'
  WHERE u.airline_id=p_airline AND u.aircraft_inventory_id=p_aircraft AND a.actual_event_utc<=p_as_of AND a.actual_event_utc>d.actual_event_utc
  UNION ALL
  SELECT m.game_completed_at_utc,'service',m.job_id::text,0::numeric,0,m.check_code
  FROM airlinerra_game.section9_game_maintenance_service_receipts_v1 m
  JOIN airlinerra_game.airline_ledger l ON l.id=m.paid_ledger_entry_id AND l.airline_id=m.airline_id AND l.entry_kind='EXPENSE' AND l.amount_usd=-m.settled_cost_usd
  WHERE m.world_id=1 AND m.airline_id=p_airline AND m.aircraft_inventory_id=p_aircraft AND m.game_completed_at_utc<=p_as_of AND m.source_kind='verified_game_service_job_v1' AND m.settled_cost_usd>0
  ORDER BY happened,kind,key
 LOOP
  IF e.kind='flight' THEN
   SELECT coalesce(sum(extract(epoch FROM greatest(interval '0',least(a.actual_event_utc,e.happened)-greatest(d.actual_event_utc,e.happened-interval '24 hours')))/3600),0) INTO recent_hours
   FROM airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 u
   JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.engine_event_id=u.arrived_engine_event_id AND a.phase='arrived' AND a.airline_id=u.airline_id AND a.aircraft_inventory_id=u.aircraft_inventory_id
   JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.engine_event_id=u.departed_engine_event_id AND d.phase='departed' AND d.airline_id=u.airline_id AND d.aircraft_inventory_id=u.aircraft_inventory_id
   WHERE u.airline_id=p_airline AND u.aircraft_inventory_id=p_aircraft AND a.actual_event_utc<=e.happened AND a.actual_event_utc>e.happened-interval '24 hours';
   factor:=airlinerra_game.section9_game_utilization_wear_multiplier_v1(recent_hours);
   loss:=round((e.hours*0.025+e.cycles*0.015)*factor,6);
   condition_now:=greatest(0,condition_now-loss);total_wear:=total_wear+loss;last_factor:=factor;
  ELSE
   repairs:=CASE e.check_code WHEN 'daily' THEN 0.1 WHEN 'weekly' THEN 0.5 WHEN 'a' THEN 3 WHEN 'b' THEN 6 WHEN 'c' THEN 15 WHEN 'd' THEN 100 ELSE 0 END;
   total_restored:=total_restored+least(repairs,100-condition_now);
   condition_now:=least(100,condition_now+repairs);
  END IF;
 END LOOP;
 RETURN jsonb_build_object('conditionPct',round(condition_now,2),'baselineConditionPct',base,'cumulativeWearPoints',round(total_wear,4),'restoredConditionPoints',round(total_restored,4),'lastFlightWearMultiplier',last_factor,'model','GAME_AIRFRAME_WEAR_V1','readOnly',true);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_game_airframe_condition_v1(uuid,uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
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
  'gameConditionPct',(airlinerra_game.section9_game_airframe_condition_v1(p_airline,p_aircraft,airlinerra_game.section9_verified_world_instant_v1())->>'conditionPct')::numeric,
  'gameBaselineSource',base.source_kind,
  'physicallyInspected',false,'realManufactureYearVerified',false,
  'gameMaintenanceGrounded',(due_count>0 OR job_block),'gameJobBlocksDate',job_block,'dueCheckCount',due_count,
  'checks',checks,'gameDatePrecisionOnly',true,
  'hourlyGroundingEnforced',false,'maintenanceCompletionSchedulingConnected',true,
  'maintenanceReady',false,'dispatchApproved',false,
  'flightActivated',false,'ledgerPosted',false);
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_game_maintenance_job_v1(p_player uuid, p_airline uuid, p_aircraft uuid, p_action text, p_check_code text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 v_now timestamptz; f record; pos jsonb; policy record; slot_proof jsonb;
 active_job record; next_start timestamptz;
 j_id uuid; jobs jsonb; completed integer; setup record;
 quote_usd numeric; available_usd numeric; quotes jsonb;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL
    OR p_action NOT IN ('status','book','cancel') OR p_action IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_INVALID_MAINTENANCE_JOB_ACTION';END IF;
 SELECT fleet.id,fleet.airline_id,fleet.registration,fleet.configuration_id,
        fleet.fleet_status,airline.home_airport_key
 INTO f FROM airlinerra_game.airline_aircraft_inventory fleet
 JOIN airlinerra_game.airlines airline ON airline.id=fleet.airline_id
   AND airline.world_id=1 AND airline.owner_player_id=p_player
 JOIN airlinerra_game.world_memberships w
 ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE fleet.id=p_aircraft AND fleet.airline_id=p_airline
 AND fleet.ownership_type IN ('owned','leased')
 FOR UPDATE OF fleet;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_MAINTENANCE_JOB_NOT_OWNED';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF f.fleet_status<>'in_service' THEN RAISE EXCEPTION USING ERRCODE='55000',
 MESSAGE='SECTION9_AIRCRAFT_NOT_IN_SERVICE';END IF;
 SELECT jsonb_agg(jsonb_build_object(
  'jobId',j.job_id,'checkCode',j.check_code,'airportKey',j.airport_key,
  'gameStartUtc',j.game_start_utc,'gameEndUtc',j.game_end_utc,
  'status',j.status,'quotedCostUsd',j.quoted_cost_usd,
  'costPosted',j.paid_ledger_entry_id IS NOT NULL,'isGameService',true)
  ORDER BY j.created_at DESC)
 INTO jobs FROM (
  SELECT * FROM airlinerra_game.section9_game_maintenance_jobs_v1
  WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft
  ORDER BY created_at DESC LIMIT 15
 ) j;
 SELECT jsonb_object_agg(check_code,base_estimate_usd) INTO quotes
 FROM airlinerra_game.aircraft_maintenance_check_overview_v1
 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft
 AND cost_evidence='provisional_game_tariff_not_vendor_quote' AND base_estimate_usd>0;
 IF p_action='status' THEN
  RETURN jsonb_build_object('status','game_maintenance_jobs',
   'jobs',coalesce(jobs,'[]'::jsonb),
   'quotedGameServicePricesUsd',coalesce(quotes,'{}'::jsonb),
   'tariffSource','provisional_game_tariff_not_vendor_quote',
   'gameNowUtc',v_now,'aircraftGroundedForJob',
   EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1
    WHERE aircraft_inventory_id=p_aircraft AND status IN ('in_progress','payment_required')),
   'flightActivated',false,'ledgerPosted',false);
 END IF;
 IF p_action='cancel' THEN
  UPDATE airlinerra_game.section9_game_maintenance_jobs_v1
  SET status='cancelled'
  WHERE aircraft_inventory_id=p_aircraft AND airline_id=p_airline
   AND status='scheduled' AND game_start_utc>v_now
  RETURNING job_id INTO j_id;
  IF j_id IS NULL THEN RETURN jsonb_build_object('status','no_cancelable_service',
    'changed',false,'flightActivated',false,'ledgerPosted',false);END IF;
  RETURN jsonb_build_object('status','cancelled','jobId',j_id,
   'changed',true,'flightActivated',false,'ledgerPosted',false);
 END IF;
 IF p_check_code IS NULL THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_MAINTENANCE_CHECK_REQUIRED';END IF;
 SELECT * INTO policy FROM airlinerra_game.maintenance_check_policy_v1
 WHERE check_code=p_check_code;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_UNKNOWN_MAINTENANCE_CHECK';END IF;
 -- Booking now must use only the fully trusted current instant; a future
 -- start can be added once reliable aircraft-time rotation reservations exist.
 next_start:=date_trunc('minute',v_now)+interval '2 minutes';
 SELECT * INTO setup
 FROM airlinerra_game.section9_starter_game_airframe_baselines_v1 b
 JOIN airlinerra_game.aircraft_maintenance_state_v1 m
 ON m.aircraft_inventory_id=b.aircraft_inventory_id
 AND m.airline_id=b.airline_id
 WHERE b.aircraft_inventory_id=p_aircraft AND b.airline_id=p_airline
 AND b.owner_player_id=p_player;
 IF NOT FOUND OR setup.tracked_flight_hours IS NULL OR
    setup.game_baseline_date> (v_now AT TIME ZONE 'Europe/Berlin')::date
 THEN RETURN jsonb_build_object('status','missing_game_airframe_baseline',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(
  p_player,p_airline,p_aircraft,(v_now AT TIME ZONE 'Europe/Berlin')::date);
 IF pos->>'verified'<>'true' OR pos->>'atGroundAirport'<>'true'
   OR pos->>'airportKey' IS NULL
 THEN RETURN jsonb_build_object('status','aircraft_location_unverified',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 IF NOT EXISTS (
  SELECT 1 FROM airlinerra_game.approved_game_airports a
  WHERE a.world_id=1 AND a.airport_key=pos->>'airportKey'
 ) THEN RETURN jsonb_build_object('status','airport_not_in_game',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 IF policy.airport_scope='type_approved_mro' AND NOT EXISTS(
 SELECT 1 FROM airlinerra_game.maintenance_airport_capabilities_v1 a
 WHERE a.world_id=1 AND a.airport_key=pos->>'airportKey'
 AND a.configuration_id=f.configuration_id
 AND a.check_code=policy.check_code
 AND a.approval_status='game_approved')
 THEN RETURN jsonb_build_object('status','airport_not_approved_for_heavy_check',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 IF EXISTS (SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 j
  WHERE j.aircraft_inventory_id=p_aircraft
  AND j.status IN ('scheduled','in_progress','payment_required'))
 THEN RETURN jsonb_build_object('status','aircraft_already_booked_for_maintenance',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 slot_proof:=airlinerra_game.section9_owned_hourly_maintenance_slot_preflight_v1(
    p_player,p_airline,p_aircraft,next_start,
    next_start+make_interval(hours=>policy.downtime_hours));
 IF slot_proof->>'status' IS DISTINCT FROM 'hourly_maintenance_slot_clear'
 OR slot_proof->>'slotClear' IS DISTINCT FROM 'true'
 OR slot_proof->>'readOnly' IS DISTINCT FROM 'true'
 OR slot_proof->>'ledgerPosted' IS DISTINCT FROM 'false'
 THEN RETURN jsonb_build_object(
   'status','aircraft_flight_or_slot_conflict_not_clear',
   'hourAccurateConflictCheck',true,
   'slotStatus',slot_proof->>'status',
   'slotEvidence',slot_proof,
   'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 SELECT base_estimate_usd INTO quote_usd
 FROM airlinerra_game.aircraft_maintenance_check_overview_v1
 WHERE aircraft_inventory_id=p_aircraft AND airline_id=p_airline
 AND check_code=policy.check_code
 AND cost_evidence='provisional_game_tariff_not_vendor_quote';
 IF NOT FOUND OR quote_usd IS NULL OR quote_usd<=0 THEN
  RETURN jsonb_build_object('status','game_maintenance_cost_unverified',
   'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 SELECT coalesce(sum(amount_usd),0) INTO available_usd
 FROM airlinerra_game.airline_ledger WHERE airline_id=p_airline;
 IF available_usd<quote_usd THEN
  RETURN jsonb_build_object('status','game_maintenance_insufficient_funds',
   'created',false,'requiredUsd',quote_usd,'balanceUsd',available_usd,
   'flightActivated',false,'ledgerPosted',false);END IF;
 INSERT INTO airlinerra_game.section9_game_maintenance_jobs_v1
  (owner_player_id,airline_id,aircraft_inventory_id,check_code,airport_key,
   game_start_utc,game_end_utc,duration_hours,condition_before_game_pct,
   flight_hours_at_book,quoted_cost_usd)
 VALUES(p_player,p_airline,p_aircraft,policy.check_code,pos->>'airportKey',
  next_start,next_start+make_interval(hours=>policy.downtime_hours),
  policy.downtime_hours,(airlinerra_game.section9_game_airframe_condition_v1(p_airline,p_aircraft,v_now)->>'conditionPct')::numeric,setup.tracked_flight_hours,quote_usd)
 RETURNING job_id INTO j_id;
 RETURN jsonb_build_object('status','scheduled','created',true,
  'jobId',j_id,'checkCode',policy.check_code,'airportKey',pos->>'airportKey',
  'startUtc',next_start,
  'endUtc',next_start+make_interval(hours=>policy.downtime_hours),
  'gameJobOnly',true,'groundDuringService',true,
  'quotedCostUsd',quote_usd,'chargedNow',false,
  'chargedAtServiceCompletion',true,
  'tariffSource','provisional_game_tariff_not_vendor_quote',
  'physicalInspectionVerified',false,'flightActivated',false,'ledgerPosted',false);
END $function$;
COMMIT;
