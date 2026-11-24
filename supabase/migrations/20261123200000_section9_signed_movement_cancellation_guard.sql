-- Safe, drift-guarded replacement for the obsolete FULL-FUNCTION rewrite
-- previously stored at this timestamp. That full rewrite would DELETE
-- existing production delayed flights/turnaround and source-alias fixes.
--
-- This migration changes ONLY the CURRENT deployed signed-movement writer:
-- (1) obtain the cancellation/dispatch shared advisory transaction lock
--     BEFORE reading the schedule;
-- (2) require a real saleable, not-cancelled, dated occurrence for departure.
-- Open OR closed booking status is permitted because the live dispatcher
-- explicitly accepts both; cancelled/not_open/missing are rejected.
-- No approved delayed time, aircraft position, real HMAC, release or fuel
-- logic is removed. Applies on the actual NEWER function definition only.
-- Transactional and idempotent. NO production application without approval.
BEGIN;
DO $correct_live_movement$
DECLARE
 fn_oid oid;
 body text;
 anchor_schedule text:=$a$ SELECT d.id,d.airline_id,d.aircraft_inventory_id,d.configuration_id,$a$;
 lock_stmt text:=$lock$
 -- Serialize direct signed calls with cancellation AND automatic dispatch.
 -- Cancellation obtains the same global lock before touching occurrence.
 PERFORM pg_catalog.pg_advisory_xact_lock(583729,10041);
$lock$;
 anchor_occurrence text:=$a$ occurrence:=p_schedule::text||':'||p_local_date::text||':'||
  p_weekly_entry::text;$a$;
 guard_stmt text:=$guard$

 -- A genuine HMAC never authorizes a cancelled, absent or unsaleable leg.
 -- Booking may already be CLOSED when departure executes; both open/closed
 -- are legitimate for dispatch and cannot be cancelled as unflown OPEN.
 IF p_phase='departed' THEN
  PERFORM 1
  FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
  WHERE o.world_id=1 AND o.airline_id=p_airline
    AND o.schedule_id=p_schedule AND o.schedule_version=p_schedule_version
    AND o.flight_local_date=p_local_date AND o.weekly_entry=p_weekly_entry
    AND o.source_kind='game_verified_saleable_schedule_v1'
    AND o.booking_status IN ('open','closed')
  FOR SHARE;
  IF NOT FOUND THEN
   RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_SIGNED_DEPARTURE_OCCURRENCE_NOT_ELIGIBLE';
  END IF;
 END IF;
$guard$;
BEGIN
 SELECT to_regprocedure(
  'airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)'
 )::oid INTO fn_oid;
 IF fn_oid IS NULL THEN
  RAISE EXCEPTION 'SECTION9_MOVEMENT_WRITER_NOT_FOUND_NO_DEPLOY';
 END IF;
 SELECT pg_get_functiondef(fn_oid) INTO body;
 -- If the live function is not the *current* delayed-aware writer, FAIL.
 IF body IS NULL
    OR position('timing record; dated_id uuid; dated_status text;' IN body)=0
    OR position('section9_effective_dispatch_window_v1' IN body)=0
    OR position('SECTION9_CANCELLED_OCCURRENCE_MOVEMENT_FORBIDDEN' IN body)=0
    OR position('section9_delayed_turnaround_clear_v1' IN body)=0
    OR position('extensions.hmac' IN body)=0
    OR position('SECTION9_OPERATED_EVENT_REPLAY_CONFLICT' IN body)=0
 THEN RAISE EXCEPTION 'SECTION9_MOVEMENT_SOURCE_VERSION_DRIFT_NO_DEPLOY';
 END IF;
 -- Reapplication is okay only when BOTH new safeguards are installed.
 IF position('SECTION9_SIGNED_DEPARTURE_OCCURRENCE_NOT_ELIGIBLE' IN body)>0
    OR position(lock_stmt IN body)>0 THEN
    IF position('SECTION9_SIGNED_DEPARTURE_OCCURRENCE_NOT_ELIGIBLE' IN body)=0
      OR position(lock_stmt IN body)=0
    THEN RAISE EXCEPTION 'SECTION9_MOVEMENT_PARTIAL_GUARD_NO_DEPLOY';END IF;
    RETURN;
 END IF;
 IF position(anchor_schedule IN body)=0
    OR position(anchor_occurrence IN body)=0
    OR length(body)-length(replace(body,anchor_schedule,''))<>length(anchor_schedule)
    OR length(body)-length(replace(body,anchor_occurrence,''))<>length(anchor_occurrence)
 THEN RAISE EXCEPTION 'SECTION9_MOVEMENT_INSERT_ANCHOR_MISMATCH_NO_DEPLOY';END IF;
 body:=replace(body,anchor_schedule,lock_stmt||anchor_schedule);
 body:=replace(body,anchor_occurrence,anchor_occurrence||guard_stmt);
 IF position(lock_stmt IN body)=0
    OR position('SECTION9_SIGNED_DEPARTURE_OCCURRENCE_NOT_ELIGIBLE' IN body)=0
 THEN RAISE EXCEPTION 'SECTION9_MOVEMENT_PATCH_INCOMPLETE';END IF;
 EXECUTE body;
 IF NOT EXISTS(SELECT 1 FROM pg_proc p WHERE p.oid=fn_oid AND
  position('SECTION9_SIGNED_DEPARTURE_OCCURRENCE_NOT_ELIGIBLE' IN pg_get_functiondef(p.oid))>0
  AND position('section9_effective_dispatch_window_v1' IN pg_get_functiondef(p.oid))>0)
 THEN RAISE EXCEPTION 'SECTION9_MOVEMENT_GUARD_RECHECK_FAILED';END IF;
END $correct_live_movement$;
COMMIT;
