BEGIN;
ALTER TABLE airlinerra_game.section9_game_maintenance_jobs_v1
 ADD COLUMN quoted_cost_usd numeric(12,2) CHECK(quoted_cost_usd>0),
 ADD COLUMN paid_ledger_entry_id bigint UNIQUE REFERENCES airlinerra_game.airline_ledger(id);
ALTER TABLE airlinerra_game.section9_game_maintenance_jobs_v1
 DROP CONSTRAINT section9_game_maintenance_jobs_v1_status_check,
 DROP CONSTRAINT section9_game_maintenance_jobs_v1_check2;
ALTER TABLE airlinerra_game.section9_game_maintenance_jobs_v1
 ADD CONSTRAINT section9_game_maintenance_jobs_v1_status_check
 CHECK(status IN ('scheduled','in_progress','payment_required','completed','cancelled')),
 ADD CONSTRAINT section9_game_maintenance_jobs_v1_check2
 CHECK(engine_start_observed_at IS NULL OR status IN ('in_progress','payment_required','completed')),
 ADD CONSTRAINT section9_game_maintenance_payment_required_before_release_v1
 CHECK((status='completed')=(paid_ledger_entry_id IS NOT NULL));
DROP INDEX airlinerra_game.section9_one_unfinished_game_maintenance_job_per_aircraft_v1;
CREATE UNIQUE INDEX section9_one_unfinished_game_maintenance_job_per_aircraft_v1
 ON airlinerra_game.section9_game_maintenance_jobs_v1(aircraft_inventory_id)
 WHERE status IN ('scheduled','in_progress','payment_required');
ALTER TABLE airlinerra_game.section9_game_maintenance_service_receipts_v1
 ADD COLUMN paid_ledger_entry_id bigint UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 ADD COLUMN settled_cost_usd numeric(12,2) CHECK(settled_cost_usd>0);
ALTER TABLE airlinerra_game.section9_game_maintenance_service_receipts_v1
 ADD CONSTRAINT section9_game_service_paid_receipt_v1
 CHECK(paid_ledger_entry_id IS NOT NULL AND settled_cost_usd IS NOT NULL);
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_game_maintenance_job_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_action text,
 p_check_code text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO airlinerra_game,pg_catalog AS $fn$
DECLARE
 v_now timestamptz; f record; pos jsonb; policy record;
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
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
  WHERE s.airline_id=p_airline AND s.aircraft_inventory_id=p_aircraft
  AND s.status='active')
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 fo
  WHERE fo.airline_id=p_airline AND fo.aircraft_inventory_id=p_aircraft
  AND fo.arrival_utc>=next_start)
 THEN RETURN jsonb_build_object('status','aircraft_flight_or_slot_conflict_not_clear',
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
  policy.downtime_hours,setup.game_condition_pct,setup.tracked_flight_hours,quote_usd)
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
END $fn$;
COMMIT;