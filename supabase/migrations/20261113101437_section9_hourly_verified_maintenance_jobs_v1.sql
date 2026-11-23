-- World 1 Phase 1: 1:1 authoritative game-hour source and private GAME maintenance jobs.
-- Automatic in-game services are NOT real-life airworthiness inspections.
BEGIN;

CREATE FUNCTION airlinerra_game.section9_verified_world_instant_v1()
RETURNS timestamptz LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO airlinerra_game,pg_catalog AS $fn$
DECLARE x timestamptz:=clock_timestamp(); c record; 
BEGIN
 SELECT h.confirmed_game_date,h.clock_source,h.engine_proof_ref,h.last_verified_at,
        w.state,p.producer_status INTO c
 FROM airlinerra_game.holding_world_clock_v1 h
 JOIN public.airlinerra_game_worlds w ON w.id=h.world_id
 JOIN airlinerra_game.section9_clock_producer_schedule_v1 p ON p.world_id=h.world_id
 WHERE h.world_id=1;
 IF NOT FOUND OR c.state IS DISTINCT FROM 'active'
 OR c.producer_status IS DISTINCT FROM 'enabled'
 OR c.clock_source IS DISTINCT FROM 'authoritative_game_engine'
 OR c.confirmed_game_date IS DISTINCT FROM (x AT TIME ZONE 'Europe/Berlin')::date
 OR c.last_verified_at IS NULL OR c.last_verified_at>x
 OR c.last_verified_at<x-interval '26 hours'
 OR NOT EXISTS (
   SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1 r
   WHERE r.world_id=1 AND r.game_date=c.confirmed_game_date
     AND r.engine_event_id=c.engine_proof_ref
     AND length(r.event_hmac_sha256)=64
     AND r.accepted_at<=x
     AND r.accepted_at>=
       (c.confirmed_game_date::timestamp AT TIME ZONE 'Europe/Berlin')
 )
 THEN RAISE EXCEPTION USING ERRCODE='55000',
 MESSAGE='SECTION9_SIGNED_HOUR_GAME_CLOCK_NOT_VERIFIED';END IF;
 RETURN x;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_verified_world_instant_v1()
 FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON FUNCTION airlinerra_game.section9_verified_world_instant_v1() IS
 '1:1 Europe/Berlin live hour sample, guarded by matching signed World1 day receipt. NULL is never trusted.';

CREATE TABLE airlinerra_game.section9_game_maintenance_jobs_v1(
 job_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 owner_player_id uuid NOT NULL,
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 check_code text NOT NULL REFERENCES airlinerra_game.maintenance_check_policy_v1(check_code),
 airport_key text NOT NULL,
 game_start_utc timestamptz NOT NULL,
 game_end_utc timestamptz NOT NULL,
 duration_hours integer NOT NULL CHECK(duration_hours BETWEEN 1 AND 504),
 status text NOT NULL DEFAULT 'scheduled'
 CHECK(status IN ('scheduled','in_progress','completed','cancelled')),
 condition_before_game_pct numeric(5,2) CHECK(condition_before_game_pct BETWEEN 0 AND 100),
 flight_hours_at_book numeric NOT NULL CHECK(flight_hours_at_book>=0),
 engine_start_observed_at timestamptz,
 engine_completion_observed_at timestamptz,
 cost_usd numeric,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 source_kind text NOT NULL DEFAULT 'owner_booked_game_service_v1'
 CHECK(source_kind='owner_booked_game_service_v1'),
 CHECK(game_end_utc=game_start_utc+make_interval(hours=>duration_hours)),
 CHECK(cost_usd IS NULL),
 CHECK(engine_completion_observed_at IS NULL OR
       status='completed'),
 CHECK(engine_start_observed_at IS NULL OR status IN ('in_progress','completed'))
);
CREATE UNIQUE INDEX section9_one_unfinished_game_maintenance_job_per_aircraft_v1
 ON airlinerra_game.section9_game_maintenance_jobs_v1(aircraft_inventory_id)
 WHERE status IN ('scheduled','in_progress');
CREATE INDEX section9_game_maintenance_due_jobs_v1
 ON airlinerra_game.section9_game_maintenance_jobs_v1(status,game_end_utc);
ALTER TABLE airlinerra_game.section9_game_maintenance_jobs_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_game_maintenance_jobs_v1
 FROM PUBLIC,anon,authenticated,service_role;

CREATE TABLE airlinerra_game.section9_game_maintenance_service_receipts_v1(
 job_id uuid PRIMARY KEY REFERENCES airlinerra_game.section9_game_maintenance_jobs_v1(job_id),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airline_id uuid NOT NULL,
 aircraft_inventory_id uuid NOT NULL,
 check_code text NOT NULL REFERENCES airlinerra_game.maintenance_check_policy_v1(check_code),
 game_completed_at_utc timestamptz NOT NULL,
 flight_hours_at_game_completion numeric NOT NULL CHECK(flight_hours_at_game_completion>=0),
 source_kind text NOT NULL DEFAULT 'verified_game_service_job_v1'
 CHECK(source_kind='verified_game_service_job_v1'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 paid_usd numeric CHECK(paid_usd IS NULL)
);
CREATE INDEX section9_game_maintenance_receipts_history_v1
 ON airlinerra_game.section9_game_maintenance_service_receipts_v1(
 aircraft_inventory_id,check_code,game_completed_at_utc DESC);
ALTER TABLE airlinerra_game.section9_game_maintenance_service_receipts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_game_maintenance_service_receipts_v1
 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.section9_owned_game_maintenance_job_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_action text,
 p_check_code text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO airlinerra_game,pg_catalog AS $fn$
DECLARE
 v_now timestamptz; f record; pos jsonb; policy record;
 active_job record; next_start timestamptz;
 j_id uuid; jobs jsonb; completed integer; setup record;
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
  'status',j.status,'costPosted',false,'isGameService',true)
  ORDER BY j.created_at DESC)
 INTO jobs FROM (
  SELECT * FROM airlinerra_game.section9_game_maintenance_jobs_v1
  WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft
  ORDER BY created_at DESC LIMIT 15
 ) j;
 IF p_action='status' THEN
  RETURN jsonb_build_object('status','game_maintenance_jobs',
   'jobs',coalesce(jobs,'[]'::jsonb),
   'gameNowUtc',v_now,'aircraftGroundedForJob',
   EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1
    WHERE aircraft_inventory_id=p_aircraft AND status='in_progress'),
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
  AND j.status IN ('scheduled','in_progress'))
 THEN RETURN jsonb_build_object('status','aircraft_already_booked_for_maintenance',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
  WHERE s.airline_id=p_airline AND s.aircraft_inventory_id=p_aircraft
  AND s.status='active')
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 f
  WHERE f.airline_id=p_airline AND f.aircraft_inventory_id=p_aircraft
  AND f.arrival_utc>=next_start)
 THEN RETURN jsonb_build_object('status','aircraft_flight_or_slot_conflict_not_clear',
  'created',false,'flightActivated',false,'ledgerPosted',false);END IF;
 INSERT INTO airlinerra_game.section9_game_maintenance_jobs_v1
  (owner_player_id,airline_id,aircraft_inventory_id,check_code,airport_key,
   game_start_utc,game_end_utc,duration_hours,condition_before_game_pct,
   flight_hours_at_book)
 VALUES(p_player,p_airline,p_aircraft,policy.check_code,pos->>'airportKey',
  next_start,next_start+make_interval(hours=>policy.downtime_hours),
  policy.downtime_hours,setup.game_condition_pct,setup.tracked_flight_hours)
 RETURNING job_id INTO j_id;
 RETURN jsonb_build_object('status','scheduled','created',true,
  'jobId',j_id,'checkCode',policy.check_code,'airportKey',pos->>'airportKey',
  'startUtc',next_start,
  'endUtc',next_start+make_interval(hours=>policy.downtime_hours),
  'gameJobOnly',true,'groundDuringService',true,
  'physicalInspectionVerified',false,'flightActivated',false,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_owned_game_maintenance_job_v1(uuid,uuid,uuid,text,text)
 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.section9_advance_game_maintenance_jobs_v1()
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO airlinerra_game,pg_catalog AS $fn$
DECLARE v_now timestamptz; j record; begun integer:=0; finished integer:=0;
BEGIN
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 FOR j IN
 SELECT * FROM airlinerra_game.section9_game_maintenance_jobs_v1
 WHERE status IN ('scheduled','in_progress') AND game_start_utc<=v_now
 ORDER BY game_start_utc,job_id FOR UPDATE SKIP LOCKED
 LOOP
   IF j.status='scheduled' THEN
      UPDATE airlinerra_game.section9_game_maintenance_jobs_v1
       SET status='in_progress',engine_start_observed_at=v_now
       WHERE job_id=j.job_id AND status='scheduled';
      begun:=begun+1;
   END IF;
   IF j.game_end_utc<=v_now THEN
     -- No real-world inspection claim: this is the game's timed service event.
     UPDATE airlinerra_game.section9_game_maintenance_jobs_v1
     SET status='completed',engine_completion_observed_at=v_now
     WHERE job_id=j.job_id AND status='in_progress';
     INSERT INTO airlinerra_game.section9_game_maintenance_service_receipts_v1
      (job_id,airline_id,aircraft_inventory_id,check_code,
       game_completed_at_utc,flight_hours_at_game_completion)
     VALUES(j.job_id,j.airline_id,j.aircraft_inventory_id,j.check_code,
            j.game_end_utc,j.flight_hours_at_book)
     ON CONFLICT(job_id) DO NOTHING;
     finished:=finished+1;
   END IF;
 END LOOP;
 RETURN jsonb_build_object('status','processed','gameNowUtc',v_now,
  'started',begun,'completed',finished,
  'physicalInspectionsRecorded',0,'financialPostings',0,'flightsActivated',0);
END $fn$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_advance_game_maintenance_jobs_v1()
 FROM PUBLIC,anon,authenticated,service_role;
COMMIT;