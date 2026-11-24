-- Airlinerra World 1 / Section 9: candidate-only game restriction reporting.
-- The established SECTION9 game restriction guard, not unrelated real-world
-- research-review flags, must decide the airport GAME restriction blocker.
-- Preserve actual simplified curfew/noise/aircraft Chapter REVIEW fail-closed.
--
-- IMPORTANT: The live owner candidate function's L1/L2 licence-scope code
-- differs from its historical repository migration. We patch its *deployed*
-- definition in place, and fail rather than overwrite that unrelated logic.
-- Owner/member identity checks, rotation feedback, traffic rights, operator
-- licence and activation/finance remain unchanged. No game state is written.
--
-- This migration is source code in GitHub only until separately approved
-- for production. It is safe to re-run and aborts on unexpected source drift.
BEGIN;

DO $candidate_game_guard_patch$
DECLARE
 fn_oid oid;
 ddl text;
 old_block text:=$old_block$IF restrict_preview->>'weeklyTimetableChecked' IS DISTINCT FROM 'true'
    OR restrict_preview->>'gameHardBlocked' IS DISTINCT FROM 'false'
    OR restrict_preview->>'needsReview' IS DISTINCT FROM 'false'
  THEN blockers:=array_append(blockers,'AIRPORT_GAME_RESTRICTIONS_NOT_CLEARED');END IF;$old_block$;
 new_block text:=$new_block$game_restriction_clear:=coalesce(
    airlinerra_game.section9_game_route_restrictions_valid_v1(
       p_origin,p_destination,restrict_preview),false);
  IF NOT game_restriction_clear
  THEN blockers:=array_append(blockers,'AIRPORT_GAME_RESTRICTIONS_NOT_CLEARED');END IF;$new_block$;
 old_preliminary text:='AND coalesce((restrict_preview->>''gameHardBlocked'')::boolean,true)=false';
 old_type text:='''gameModelEvidenceType'',''GAME_ESTIMATE_NOT_OFFICIAL_CLEARANCE'',';
 new_type text:=$new_type$'gameModelEvidenceType','GAME_ESTIMATE_NOT_OFFICIAL_CLEARANCE',
 'gameRestrictionGuardPassed',game_restriction_clear,
 'researchDocumentationReviewPending',
    coalesce((restrict_preview->>'needsReview')::boolean,true),$new_type$;
BEGIN
 SELECT to_regprocedure(
  'airlinerra_game.section9_owned_candidate_slot_rights_preflight_v1(uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,text,text)'
 )::oid INTO fn_oid;
 IF fn_oid IS NULL
 THEN RAISE EXCEPTION 'SECTION9_CANDIDATE_PREFLIGHT_FUNCTION_MISSING_NO_DEPLOY';END IF;
 IF to_regprocedure('airlinerra_game.section9_game_route_restrictions_valid_v1(text,text,jsonb)') IS NULL
 THEN RAISE EXCEPTION 'SECTION9_ENFORCEABLE_GAME_RESTRICTION_GUARD_MISSING_NO_DEPLOY';END IF;
 SELECT pg_get_functiondef(fn_oid) INTO ddl;
 IF ddl IS NULL OR position('flightActivated'',false' IN ddl)=0
 OR position('AIRPORT_GAME_RESTRICTIONS_NOT_CLEARED' IN ddl)=0
 OR position('operatorLicenceOperationallyVerified'',false' IN ddl)=0
 THEN RAISE EXCEPTION 'SECTION9_CANDIDATE_SOURCE_SHAPE_UNEXPECTED_NO_DEPLOY';END IF;
 -- Idempotence: do not make a second rewrite or relax a later source version.
 IF position('game_restriction_clear boolean:=false;' IN ddl)>0 THEN
   IF position('gameRestrictionGuardPassed' IN ddl)=0
      OR position('researchDocumentationReviewPending' IN ddl)=0
      OR position(old_block IN ddl)>0
   THEN RAISE EXCEPTION 'SECTION9_CANDIDATE_PARTIAL_MIGRATION_NO_DEPLOY';END IF;
   RETURN;
 END IF;
 IF position(old_block IN ddl)=0
    OR position(old_preliminary IN ddl)=0
    OR position(old_type IN ddl)=0
    OR position('restrict_preview jsonb:=NULL;' IN ddl)=0
    OR (position('section9_game_route_licence_scope_v1' IN ddl)=0
       AND position('section9_required_game_traffic_permission_v1' IN ddl)=0)
 THEN RAISE EXCEPTION 'SECTION9_CANDIDATE_GAME_GATE_DRIFT_NO_DEPLOY';END IF;
 ddl:=replace(ddl,'restrict_preview jsonb:=NULL;',
                  'restrict_preview jsonb:=NULL;'||chr(10)||
                  ' game_restriction_clear boolean:=false;');
 ddl:=replace(ddl,old_block,new_block);
 ddl:=replace(ddl,old_preliminary,'AND game_restriction_clear');
 ddl:=replace(ddl,old_type,new_type);
 IF position(old_block IN ddl)>0
    OR position('game_restriction_clear boolean:=false;' IN ddl)=0
    OR position('gameRestrictionGuardPassed' IN ddl)=0
 THEN RAISE EXCEPTION 'SECTION9_CANDIDATE_GAME_GATE_REWRITE_INCOMPLETE';END IF;
 EXECUTE ddl;
 IF NOT EXISTS(
  SELECT 1 FROM pg_proc p
  WHERE p.oid=fn_oid
    AND position('game_restriction_clear boolean:=false;' IN pg_get_functiondef(p.oid))>0
    AND position('gameRestrictionGuardPassed' IN pg_get_functiondef(p.oid))>0
    AND position(old_block IN pg_get_functiondef(p.oid))=0
 )
 THEN RAISE EXCEPTION 'SECTION9_CANDIDATE_GAME_GATE_INSTALL_NOT_VERIFIED';END IF;
END;
$candidate_game_guard_patch$;

COMMIT;
