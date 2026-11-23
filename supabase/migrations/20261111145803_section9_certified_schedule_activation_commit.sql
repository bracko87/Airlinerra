-- World1: final PRIVATE commit only after signed independent certification.
-- No automatic use: operational release is currently absent.
-- No bookings, movements, fuel or financial transactions.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_guard_schedule_activation_update_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $guard$
DECLARE proof record; release_record record; clock_record record;
BEGIN
 IF OLD.status='active' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_ACTIVE_SCHEDULE_IMMUTABLE';
 END IF;
 IF NEW.status IS NOT DISTINCT FROM OLD.status
    AND NEW.operationally_verified IS NOT DISTINCT FROM OLD.operationally_verified
 THEN RETURN NEW; END IF;
 IF OLD.status IS DISTINCT FROM 'draft'
    OR OLD.operationally_verified IS DISTINCT FROM false
    OR NEW.status IS DISTINCT FROM 'active'
    OR NEW.operationally_verified IS DISTINCT FROM true
    OR (to_jsonb(NEW)-'status'-'operationally_verified'-'updated_at')
       IS DISTINCT FROM
       (to_jsonb(OLD)-'status'-'operationally_verified'-'updated_at')
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_UNAUTHORIZED_SCHEDULE_STATE_CHANGE';
 END IF;
 SELECT * INTO proof
 FROM airlinerra_game.section9_schedule_activation_preparations_v1
 WHERE schedule_id=OLD.id AND schedule_version=OLD.version
    AND airline_id=OLD.airline_id AND aircraft_inventory_id=OLD.aircraft_inventory_id
 FOR SHARE;
 SELECT * INTO release_record
 FROM airlinerra_game.section9_activation_release_policy_v1
 WHERE world_id=1 FOR SHARE;
 SELECT confirmed_game_date,clock_source,last_verified_at
 INTO clock_record FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=1 FOR SHARE;
 IF proof.fingerprint_md5 IS DISTINCT FROM
     airlinerra_game.section9_activation_evidence_fingerprint_v1(OLD.id)
 OR proof.verified_game_date IS DISTINCT FROM clock_record.confirmed_game_date
 OR proof.release_reference IS DISTINCT FROM release_record.release_reference
 OR release_record.release_state IS DISTINCT FROM 'enabled'
 OR release_record.enabled_at IS NULL OR release_record.reviewed_at IS NULL
 OR clock_record.clock_source IS DISTINCT FROM 'authoritative_game_engine'
 OR clock_record.last_verified_at IS NULL
 OR NOT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1 r
   WHERE r.world_id=1 AND r.game_date=proof.verified_game_date
 )
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_SCHEDULE_ACTIVATION_NOT_PREPARED_OR_RELEASED';
 END IF;
 RETURN NEW;
END $guard$;

DROP TRIGGER IF EXISTS section9_schedule_activation_guard_v1
 ON airlinerra_game.airline_flight_schedule_drafts_v1;
CREATE TRIGGER section9_schedule_activation_guard_v1
BEFORE UPDATE ON airlinerra_game.airline_flight_schedule_drafts_v1
FOR EACH ROW EXECUTE FUNCTION
 airlinerra_game.section9_guard_schedule_activation_update_v1();

-- Original constraints intentionally disallowed ALL activation. Replace with
-- paired lifecycle check; trigger and preparation protect the transition.
ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1
 DROP CONSTRAINT airline_flight_schedule_drafts_v1_status_check,
 DROP CONSTRAINT airline_flight_schedule_drafts_v1_operationally_verified_check;
ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1
 ADD CONSTRAINT section9_schedule_lifecycle_valid_v1
 CHECK (
    (status='draft' AND operationally_verified=false)
 OR (status='active' AND operationally_verified=true)
 );

CREATE OR REPLACE FUNCTION airlinerra_game.section9_commit_certified_schedule_activation_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,
 p_expected_version integer,p_game_date date,p_days integer DEFAULT 28
) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $activate$
DECLARE target record; approval jsonb; proof record; changed integer;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_schedule IS NULL
    OR p_expected_version IS NULL OR p_expected_version<1
    OR p_game_date IS NULL
    OR p_game_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
    OR p_days IS NULL OR p_days NOT BETWEEN 7 AND 42
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_SCHEDULE_ACTIVATION_REQUEST'; END IF;
 SELECT s.id,s.world_id,s.version,s.status,s.operationally_verified,
        s.airline_id,s.aircraft_inventory_id
 INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a
   ON a.id=s.airline_id AND a.owner_player_id=p_player AND a.world_id=1
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND s.world_id=1
 FOR UPDATE OF s;
 IF NOT FOUND THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_SCHEDULE_ACTIVATION_NOT_OWNED';
 END IF;
 IF target.version IS DISTINCT FROM p_expected_version
 THEN RETURN jsonb_build_object(
   'status','blocked_stale_schedule_version','scheduleId',p_schedule,
   'scheduleActivated',false,'flightActivated',false,
   'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 IF target.status IS DISTINCT FROM 'draft'
    OR target.operationally_verified IS DISTINCT FROM false
 THEN RETURN jsonb_build_object(
   'status','blocked_schedule_not_draft','scheduleId',p_schedule,
   'scheduleActivated',false,'flightActivated',false,
   'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;

 -- Re-check full real-world and game certification, current clock, slots,
 -- crew, aircraft, route rights and source evidence inside the same lock.
 approval:=airlinerra_game.section9_prepare_certified_schedule_activation_v1(
   p_player,p_airline,p_schedule,p_expected_version,p_game_date,p_days);
 IF approval->>'status' IS DISTINCT FROM 'prepared_for_future_activation_commit'
    OR approval->>'prepared' IS DISTINCT FROM 'true'
    OR approval->>'flightActivated' IS DISTINCT FROM 'false'
    OR approval->>'movementRecorded' IS DISTINCT FROM 'false'
    OR approval->>'ledgerPosted' IS DISTINCT FROM 'false'
 THEN RETURN jsonb_build_object(
    'status','blocked_activation_not_fully_certified',
    'scheduleId',p_schedule,
    'blockers',coalesce(approval->'blockers','[]'::jsonb),
    'scheduleActivated',false,'flightActivated',false,
    'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 SELECT * INTO proof
 FROM airlinerra_game.section9_schedule_activation_preparations_v1
 WHERE schedule_id=p_schedule AND schedule_version=p_expected_version
 AND airline_id=p_airline AND aircraft_inventory_id=target.aircraft_inventory_id
 FOR SHARE;
 IF NOT FOUND
  OR proof.verified_game_date IS DISTINCT FROM p_game_date
  OR proof.certified_horizon_days IS DISTINCT FROM p_days
  OR proof.fingerprint_md5 IS DISTINCT FROM approval->>'fingerprint'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_ACTIVATION_PREPARATION_CHANGED';END IF;

 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET status='active',operationally_verified=true,updated_at=clock_timestamp()
 WHERE id=p_schedule AND version=p_expected_version AND world_id=1
   AND airline_id=p_airline AND status='draft' AND operationally_verified=false;
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_ACTIVATION_ATOMIC_UPDATE_NOT_CONFIRMED';END IF;
 RETURN jsonb_build_object(
  'status','certified_schedule_activated','worldId',1,
  'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
  'certifiedThroughGameDate',p_game_date+p_days,
  'scheduleActivated',true,'flightActivated',false,
  'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
END $activate$;

REVOKE ALL ON FUNCTION
 airlinerra_game.section9_commit_certified_schedule_activation_v1(
 uuid,uuid,uuid,integer,date,integer)
 FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_guard_schedule_activation_update_v1()
 FROM PUBLIC,anon,authenticated,service_role;

COMMENT ON FUNCTION
 airlinerra_game.section9_commit_certified_schedule_activation_v1(
 uuid,uuid,uuid,integer,date,integer)
 IS 'Private final certified schedule activation after independent proofs and live release; never operates a flight or charges an airline.';
