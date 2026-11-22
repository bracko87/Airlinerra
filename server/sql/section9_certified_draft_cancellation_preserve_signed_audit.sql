-- Phase 14AA: immutable signed certification audit with one-way draft cancellation.
-- No existing draft is cancelled by this migration; frontend API remains unchanged.
ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1 DROP CONSTRAINT section9_schedule_lifecycle_valid_v1;
ALTER TABLE airlinerra_game.airline_flight_schedule_drafts_v1 ADD CONSTRAINT section9_schedule_lifecycle_valid_v1 CHECK (
 (status='draft' AND operationally_verified=false) OR
 (status='active' AND operationally_verified=true) OR
 (status='cancelled' AND operationally_verified=false)
);
CREATE OR REPLACE FUNCTION airlinerra_game.section9_guard_schedule_activation_update_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE proof record; release_record record; clock_record record;
BEGIN
 -- Prevent direct INSERT of an active/verified schedule: every schedule
 -- must enter as a draft and only the guarded transition may activate it.
 IF TG_OP='INSERT' THEN
  IF NEW.status='draft' AND NEW.operationally_verified=false
  THEN RETURN NEW;END IF;
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_ACTIVE_SCHEDULE_INSERT_NOT_AUTHORIZED';
 END IF;
 IF OLD.status='cancelled' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_CANCELLED_CERTIFIED_DRAFT_IMMUTABLE';
 END IF;
 IF OLD.status='active' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_ACTIVE_SCHEDULE_IMMUTABLE';
 END IF;
 -- Audit preserving cancellation is a one-way, privileged state change.
 -- The original certification events retain their RESTRICT foreign key.
 IF OLD.status='draft' AND OLD.operationally_verified=false
  AND NEW.status='cancelled' AND NEW.operationally_verified=false
  AND current_user='postgres'
  AND current_setting('airlinerra.signed_draft_cancel',true) IS NOT DISTINCT FROM OLD.id::text
  AND (to_jsonb(NEW)-'status'-'updated_at')
      IS NOT DISTINCT FROM (to_jsonb(OLD)-'status'-'updated_at')
 THEN RETURN NEW;END IF;
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
 IF (airlinerra_game.section9_aoc_flight_release_readiness_v1(
      OLD.airline_id,clock_record.confirmed_game_date)->>'authorized') IS DISTINCT FROM 'true'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_AOC_NOT_VERIFIED_FOR_SCHEDULE_ACTIVATION';
 END IF;
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
END $function$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_cancel_certified_draft_and_release_slots_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,p_expected_version integer
) RETURNS jsonb LANGUAGE plpgsql AS $cancel$
DECLARE target record; released_slots integer:=0; previous_scope text; saved_events integer:=0;
BEGIN
 IF current_user<>'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_PRIVATE_DRAFT_CANCELLATION_ONLY';
 END IF;
 IF p_player IS NULL OR p_airline IS NULL OR p_schedule IS NULL
 OR p_expected_version IS NULL OR p_expected_version<1
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_DRAFT_CANCELLATION_SCOPE';END IF;
 SELECT s.* INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a ON a.id=s.airline_id AND a.owner_player_id=p_player AND a.world_id=1
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND s.world_id=1
 FOR UPDATE OF s;
 IF NOT FOUND THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_DRAFT_CANCELLATION_NOT_OWNED';
 END IF;
 IF target.version IS DISTINCT FROM p_expected_version THEN
  RETURN jsonb_build_object('status','blocked_stale_schedule_version','scheduleCancelled',false,
   'slotsReleased',0,'ledgerPosted',false,'flightActivated',false);
 END IF;
 IF target.status='cancelled' AND target.operationally_verified=false THEN
  RETURN jsonb_build_object('status','certified_draft_already_cancelled','scheduleCancelled',true,
   'replayed',true,'slotsReleased',0,'historicalEventsPreserved',true,
   'ledgerPosted',false,'flightActivated',false);
 END IF;
 IF target.status<>'draft' OR target.operationally_verified IS DISTINCT FROM false THEN
  RETURN jsonb_build_object('status','blocked_only_unactivated_draft_cancellable',
   'scheduleCancelled',false,'slotsReleased',0,'ledgerPosted',false,'flightActivated',false);
 END IF;
 -- Paid, booked and operating flights require the separate passenger recovery
 -- cancellation engine and cannot be erased by deleting a schedule draft.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
            WHERE o.schedule_id=p_schedule)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
            WHERE m.flight_occurrence_id LIKE p_schedule::text||':%')
 THEN RETURN jsonb_build_object('status','blocked_occurrence_or_operated_flight_exists',
   'scheduleCancelled',false,'slotsReleased',0,'ledgerPosted',false,'flightActivated',false);
 END IF;
 -- Serialize against the slot writer; lock both airport capacity rows in
 -- consistent order before releasing the current weekly reservations.
 PERFORM 1 FROM airlinerra_game.section6_airport_slot_capacity_v1 c
 WHERE c.world_id=1 AND c.airport_key IN (target.origin_airport_key,target.destination_airport_key)
 ORDER BY c.airport_key FOR UPDATE;
 saved_events:=(SELECT count(*) FROM airlinerra_game.section9_operational_certification_events_v1
   WHERE schedule_id=p_schedule);
 previous_scope:=current_setting('airlinerra.signed_draft_cancel',true);
 PERFORM set_config('airlinerra.signed_draft_cancel',p_schedule::text,true);
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET status='cancelled',operationally_verified=false,updated_at=clock_timestamp()
 WHERE id=p_schedule AND status='draft' AND operationally_verified=false
  AND version=p_expected_version;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_ATOMIC_DRAFT_CANCELLATION_FAILED';END IF;
 PERFORM set_config('airlinerra.signed_draft_cancel',coalesce(previous_scope,''),true);
 DELETE FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 WHERE schedule_id=p_schedule;
 GET DIAGNOSTICS released_slots=ROW_COUNT;
 DELETE FROM airlinerra_game.section9_schedule_activation_preparations_v1 WHERE schedule_id=p_schedule;
 IF (SELECT count(*) FROM airlinerra_game.section9_operational_certification_events_v1 WHERE schedule_id=p_schedule)<>saved_events
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_CERTIFICATION_AUDIT_MUST_BE_PRESERVED';END IF;
 RETURN jsonb_build_object('status','certified_draft_cancelled','scheduleId',p_schedule,
  'scheduleCancelled',true,'replayed',false,'slotsReleased',released_slots,
  'signedEventsPreserved',saved_events,'historicalEventsPreserved',true,
  'weeklyScheduleActivated',false,'flightActivated',false,'bookingsCreated',false,
  'movementRecorded',false,'ledgerPosted',false);
END $cancel$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_cancel_certified_draft_and_release_slots_v1(uuid,uuid,uuid,integer)
 FROM PUBLIC,anon,authenticated,service_role;