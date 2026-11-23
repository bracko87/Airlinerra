-- Test actual original signed movement procedure and guarded source patch.
-- Never invoke the movement operation; no real HMAC key or flight events.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable'
 OR current_user<>'postgres'
 OR to_regprocedure('airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)') IS NOT NULL
 THEN RAISE EXCEPTION 'SIGNED_MOVEMENT_CANDIDATE_TEST_DISPOSABLE_ONLY';END IF;
END $guard$;
\i tests/sql/section9_disposable_original_signed_movement_writer.sql

DO $before$
DECLARE original text;
BEGIN
 SELECT pg_get_functiondef('airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)'::regprocedure)
 INTO original;
 IF position('AND o.airline_id=p_airline;' in original)<1
 OR position('FOR SHARE OF o;' in original)>0
 THEN RAISE EXCEPTION 'Original source snapshot differs from expected no-lock version';END IF;
END $before$;

\i supabase/migration_candidates/20261123_section9_signed_movement_cancellation_row_lock_review.sql

DO $after$
DECLARE updated text;source_procedure regprocedure:=
 'airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)'::regprocedure;
BEGIN
 SELECT pg_get_functiondef(source_procedure) INTO updated;
 IF position(E'AND o.airline_id=p_airline\n FOR SHARE OF o;' in updated)<1
 OR (length(updated)-length(replace(updated,'FOR SHARE OF o;','')))<>length('FOR SHARE OF o;')
 THEN RAISE EXCEPTION 'Protected dated-flight row lock not installed exactly once';END IF;
 IF position('SECTION9_CANCELLED_OCCURRENCE_MOVEMENT_FORBIDDEN' in updated)<1
 OR position('section9_operated_flight_movements_v1' in updated)<1
 OR position('SECTION9_OPERATED_EVENT_REPLAY_CONFLICT' in updated)<1
 THEN RAISE EXCEPTION 'Movement protection accidentally removed original safety checks';END IF;
 IF has_function_privilege('anon',source_procedure,'EXECUTE')
 OR has_function_privilege('authenticated',source_procedure,'EXECUTE')
 OR has_function_privilege('service_role',source_procedure,'EXECUTE')
 THEN RAISE EXCEPTION 'Client role has unsafe signed movement execution';END IF;
 RAISE NOTICE 'PASS original signed movement writer patched with exactly one protected occurrence read; private execute preserved';
END $after$;

-- The review-only patch is deliberately NOT repeatable on the same function:
-- it fails closed when its approved source anchor disappears. Catch the
-- expected rejection inside a savepoint so the acceptance suite continues.
DO $source_review$
DECLARE installed text;
BEGIN
 SELECT pg_get_functiondef(
 'airlinerra_game.section9_record_signed_operated_flight_movement_v1(uuid,uuid,integer,date,integer,text,timestamptz,text,text)'::regprocedure)
 INTO installed;
 IF installed LIKE '%AND o.airline_id=p_airline;%'
 THEN RAISE EXCEPTION 'Unprotected source remained after candidate application';END IF;
 RAISE NOTICE 'PASS source patch eliminates stale booking status read';
END $source_review$;
