-- SECURITY PATCH: the actual signed-certification database sink currently
-- accepts future operations/finance source claims without independent
-- PostgreSQL re-verification (eligible:=true). Both authorities lack a
-- released trusted source producer. Force fail-closed until an independent
-- proof issuer + SAME-TRANSACTION database recheck is explicitly deployed.
-- Does NOT change any release flags, schedule states, licences or money.
DO $patch$
DECLARE
 definition text; old_block text; new_block text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO definition
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='airlinerra_game'
  AND p.proname='section9_record_verified_certification_event_v1'
  AND pg_get_function_identity_arguments(p.oid)=
  'p_airline uuid, p_schedule uuid, p_schedule_version integer, p_clearance_type text, p_action text, p_event_id text, p_source_reference text, p_reviewer_reference text, p_valid_from date, p_valid_until date, p_verified_hmac text';
 IF definition IS NULL THEN
  RAISE EXCEPTION 'SECTION9_CERTIFICATION_SINK_FUNCTION_NOT_FOUND';
 END IF;
 old_block:=$old$  ELSE
   -- There is no live trusted operations/settlement engine yet.
   -- An individually signed event from that future engine is required;
   -- source claims are cryptographically checked by a separate backend.
   eligible:=true;
  END IF;$old$;
 new_block:=$new$  ELSE
   -- Neither trusted flight execution nor commercial finance has an
   -- independently released live source verifier. A signed payload alone
   -- cannot certify operational readiness for either clearance type.
   -- This block must be replaced only alongside a verified private source
   -- reader, independent signing authority, and atomic SQL evidence recheck.
   RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_UNRELEASED_EXECUTION_OR_FINANCE_CERTIFICATION';
  END IF;$new$;
 IF position(old_block IN definition)=0 THEN
  IF position('SECTION9_UNRELEASED_EXECUTION_OR_FINANCE_CERTIFICATION' IN definition)>0
  THEN RAISE NOTICE 'Section 9 future authority certification already fail-closed';
  ELSE RAISE EXCEPTION 'SECTION9_CERTIFICATION_SINK_UNEXPECTED_DEFINITION_ABORTED';END IF;
 ELSE
  IF length(definition)-length(replace(definition,old_block,''))<>length(old_block)
  THEN RAISE EXCEPTION 'SECTION9_CERTIFICATION_SINK_AMBIGUOUS_REPLACEMENT'; END IF;
  EXECUTE replace(definition,old_block,new_block);
  RAISE NOTICE 'Section 9 future execution and finance certification now fail-closed';
 END IF;
END $patch$;
-- Preserve the original restricted execution access after replacement.
REVOKE ALL ON FUNCTION airlinerra_game.section9_record_verified_certification_event_v1(
 uuid,uuid,integer,text,text,text,text,text,date,date,text)
 FROM PUBLIC,anon,authenticated,service_role;
