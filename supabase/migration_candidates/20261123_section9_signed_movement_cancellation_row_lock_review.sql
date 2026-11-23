-- REVIEW ONLY, NOT A MIGRATION. Do not apply to production without
-- independent review, signed-movement HMAC acceptance and staging rollout.
-- Expected deployed original: section9_record_signed_operated_flight_movement_v1
-- Changes exactly the occurrence status read to take a shared row lock
-- until movement insertion commits. PostgreSQL cancellation uses FOR UPDATE.
--
-- IMPORTANT: additional fleet/capacity lock-order and release analysis is
-- required; this is an undeployed candidate, not a completed fix.
BEGIN;
DO $review$
DECLARE original_source text; patched_source text;
 original_read text:=$anchor$
  SELECT o.id,o.booking_status INTO dated_id,dated_status
  FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
  WHERE o.schedule_id=p_schedule AND o.schedule_version=p_schedule_version
  AND o.flight_local_date=p_local_date AND o.weekly_entry=p_weekly_entry AND o.airline_id=p_airline;
$anchor$;
 patched_read text:=$patched$
  SELECT o.id,o.booking_status INTO dated_id,dated_status
  FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
  WHERE o.schedule_id=p_schedule AND o.schedule_version=p_schedule_version
  AND o.flight_local_date=p_local_date AND o.weekly_entry=p_weekly_entry AND o.airline_id=p_airline
  FOR SHARE OF o;
$patched$;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO original_source
 FROM pg_proc p
 JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='airlinerra_game'
 AND p.proname='section9_record_signed_operated_flight_movement_v1'
 AND p.pronargs=9;
 IF original_source IS NULL
 OR (length(original_source)-length(replace(original_source,original_read,'')))<>length(original_read)
 OR original_source ILIKE '%FOR SHARE OF o;%' THEN
  RAISE EXCEPTION 'REVIEW_CANDIDATE_MOVEMENT_ORIGINAL_SOURCE_MISMATCH';
 END IF;
 patched_source:=replace(original_source,original_read,patched_read);
 IF patched_source=original_source THEN
  RAISE EXCEPTION 'REVIEW_CANDIDATE_PATCH_FAILED';END IF;
 EXECUTE patched_source;
END $review$;
-- No browser-facing rights. Keep original trusted-worker access model.
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_record_signed_operated_flight_movement_v1(
 uuid,uuid,integer,date,integer,text,timestamptz,text,text)
 FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
