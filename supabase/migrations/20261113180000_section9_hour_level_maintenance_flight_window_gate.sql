-- World1: exact UTC flight window versus verified game service jobs.
-- Cross-day maintenance DUE is deliberately day-granular and fail-closed.
BEGIN;
CREATE FUNCTION airlinerra_game.section9_owned_game_maintenance_flight_window_v1(
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
  AND j.status IN ('scheduled','in_progress')
  AND j.game_start_utc<p_arrival_utc
  AND j.game_end_utc>p_departure_utc;
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
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_game_maintenance_flight_window_v1(
 uuid,uuid,uuid,timestamptz,timestamptz)
 FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON FUNCTION airlinerra_game.section9_owned_game_maintenance_flight_window_v1(
 uuid,uuid,uuid,timestamptz,timestamptz) IS
 'Read-only exact hour overlap check for game maintenance reservations, plus conservative game-day due checks; never grants dispatch approval.';
COMMIT;