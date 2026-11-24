-- Fix first REAL certification concurrency blocker discovered 2026-11-24:
-- six independent game-issuer connections on one schedule deadlocked in
-- section9_record_verified_certification_event_v1 FOR UPDATE OF sch.
-- Root cause: issuer's operator/traffic/slot source readers take FOR SHARE
-- on the same schedule before its final sink tries to upgrade to FOR UPDATE.
-- Resolve by acquiring the schedule's exclusive lock FIRST in the issuer.
-- Immutable receipt, HMAC signing, source verification and issuer/sink ACLs
-- remain unchanged. Forward-only, transactional, source-shape drift guarded.
-- GitHub migration only; do NOT apply to Supabase without production release.
BEGIN;

DO $repair$
DECLARE
  oid_src oid;
  definition text;
  old_guard text:=$old$ IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_GAME_CLEARANCE_ONLY';END IF;$old$;
  extra_lock text:=$new$
 -- Serialize competing issuer requests BEFORE FOR SHARE source readers.
 -- Reacquiring the same row as FOR UPDATE in the verified event sink is
 -- safe: one transaction now owns the strongest lock from the start.
 -- No route, slot, licence or financial authorization is issued by this lock.
 PERFORM 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 sch
 WHERE sch.id=p_schedule AND sch.airline_id=p_airline AND sch.world_id=1
 FOR UPDATE OF sch;$new$;
BEGIN
 SELECT to_regprocedure(
  'airlinerra_game.section9_issue_queued_game_clearance_v1(uuid,uuid,integer,date,text)'
 )::oid INTO oid_src;
 IF oid_src IS NULL THEN
  RAISE EXCEPTION 'SECTION9_GAME_ISSUER_FUNCTION_MISSING_NO_DEPLOY';
 END IF;
 SELECT pg_get_functiondef(oid_src) INTO definition;
 IF definition IS NULL
 OR position('section9_record_verified_certification_event_v1' IN definition)=0
 OR position('vault.decrypted_secrets' IN definition)=0
 OR position('extensions.hmac' IN definition)=0
 OR position('section9_verify_game_operator_licence_v1' IN definition)=0
 OR position('section9_verify_game_route_traffic_rights_v1' IN definition)=0
 OR position('section9_verify_slot_clearance_source_v1' IN definition)=0
 THEN RAISE EXCEPTION 'SECTION9_GAME_ISSUER_DEFINITION_DRIFT_NO_DEPLOY';END IF;
 -- Idempotence: only accept our complete previously installed lock order.
 IF position(extra_lock IN definition)>0 THEN
   IF position(old_guard||extra_lock IN definition)=0 THEN
    RAISE EXCEPTION 'SECTION9_GAME_ISSUER_PARTIAL_LOCK_MIGRATION';END IF;
   RETURN;
 END IF;
 IF position(old_guard IN definition)=0 OR
  length(definition)-length(replace(definition,old_guard,''))<>length(old_guard)
 THEN RAISE EXCEPTION 'SECTION9_GAME_ISSUER_GUARD_SHAPE_UNEXPECTED_NO_DEPLOY';END IF;
 definition:=replace(definition,old_guard,old_guard||extra_lock);
 IF position(old_guard||extra_lock IN definition)=0
 THEN RAISE EXCEPTION 'SECTION9_GAME_ISSUER_LOCK_INSERT_INCOMPLETE';END IF;
 EXECUTE definition;
 IF position(old_guard||extra_lock IN pg_get_functiondef(oid_src))=0
 THEN RAISE EXCEPTION 'SECTION9_GAME_ISSUER_LOCK_INSTALL_NOT_VERIFIED';END IF;
END $repair$;

COMMIT;
