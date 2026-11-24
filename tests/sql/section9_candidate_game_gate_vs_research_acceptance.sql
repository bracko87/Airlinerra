-- Unchanged deployed candidate preflight -> surgical migration -> fixture
-- proof of the actual separate game gate. Disposable-only, no production.
\set ON_ERROR_STOP on
DO $safe$
DECLARE
 src text;acl aclitem[];
 a bool; b bool; c bool; d bool; e bool;
 good jsonb;
 muc jsonb;
 runway_invalid jsonb;
 omitted jsonb;
 prohibited jsonb;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'CANDIDATE_GAME_GATE_TEST_DISPOSABLE_ONLY';END IF;
 SELECT p.proacl INTO acl FROM pg_proc p WHERE p.oid=
 'airlinerra_game.section9_owned_candidate_slot_rights_preflight_v1(uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,text,text)'::regprocedure;
 IF has_function_privilege('service_role','airlinerra_game.section9_owned_candidate_slot_rights_preflight_v1(uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,text,text)','EXECUTE')
 OR has_function_privilege('authenticated','airlinerra_game.section9_owned_candidate_slot_rights_preflight_v1(uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,text,text)','EXECUTE')
 THEN RAISE EXCEPTION 'Candidate test fixture was exposed to service/authenticated roles';END IF;
 SELECT pg_get_functiondef(
  'airlinerra_game.section9_owned_candidate_slot_rights_preflight_v1(uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,text,text)'::regprocedure
 ) INTO src;
 IF position('game_restriction_clear boolean:=false;' IN src)=0
 OR position('section9_game_route_licence_scope_v1' IN src)=0
 OR position('gameRestrictionGuardPassed' IN src)=0
 OR position('researchDocumentationReviewPending' IN src)=0
 OR position('AND game_restriction_clear' IN src)=0
 OR position('OR restrict_preview->>''needsReview'' IS DISTINCT FROM ''false''' IN src)>0
 OR position('flightActivated'',false' IN src)=0
 OR position('ledgerPosted'',false' IN src)=0
 OR position('operatorLicenceOperationallyVerified'',false' IN src)=0
 THEN RAISE EXCEPTION 'Live licensed candidate source or read-only guard changed unexpectedly';END IF;
 IF (SELECT p.proacl FROM pg_proc p WHERE p.oid=
 'airlinerra_game.section9_owned_candidate_slot_rights_preflight_v1(uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,text,text)'::regprocedure)
 IS DISTINCT FROM acl
 THEN RAISE EXCEPTION 'Existing candidate function grants changed';END IF;

 good:=jsonb_build_object('weeklyTimetableChecked',true,'gameHardBlocked',false,'needsReview',true,
  'occurrences',jsonb_build_array(jsonb_build_object(
  'origin',jsonb_build_object('airportKey','BEG','gameHardBlocked',false,'requiredGameRunwayLengthM',1800,
   'simpleNightNoise',jsonb_build_object('needsReview',false,'gameHardBlocked',false)),
  'destination',jsonb_build_object('airportKey','GROUP2_READY','gameHardBlocked',false,
   'requiredGameRunwayLengthM',1800,
   'simpleNightNoise',jsonb_build_object('needsReview',false,'gameHardBlocked',false)))));
 a:=airlinerra_game.section9_game_route_restrictions_valid_v1('BEG','GROUP2_READY',good);
 IF a IS DISTINCT FROM true OR good->>'needsReview' IS DISTINCT FROM 'true'
 THEN RAISE EXCEPTION 'Only researched-but-not-certified runway status must NOT invent game curfew ban';END IF;
 -- Same evidence but destination MUC noise certificate still unverified:
 -- keep fail-closed even if overall gameHardBlocked=false.
 muc:=jsonb_set(good,'{occurrences,0,destination,airportKey}','"MUC"'::jsonb);
 muc:=jsonb_set(muc,'{occurrences,0,destination,simpleNightNoise,needsReview}','true'::jsonb);
 b:=airlinerra_game.section9_game_route_restrictions_valid_v1('BEG','MUC',muc);
 IF b IS DISTINCT FROM false THEN RAISE EXCEPTION 'Unverified MUC noise certificate passed game guard';END IF;
 runway_invalid:=jsonb_set(good,'{occurrences,0,destination,requiredGameRunwayLengthM}','99999'::jsonb);
 c:=airlinerra_game.section9_game_route_restrictions_valid_v1('BEG','GROUP2_READY',runway_invalid);
 IF c IS DISTINCT FROM false THEN RAISE EXCEPTION 'Insufficient real game runway model passed';END IF;
 omitted:=jsonb_set(good,'{occurrences,0,destination,simpleNightNoise}','{}'::jsonb);
 d:=airlinerra_game.section9_game_route_restrictions_valid_v1('BEG','GROUP2_READY',omitted);
 IF d IS DISTINCT FROM false THEN RAISE EXCEPTION 'Missing simplified gate was considered approval';END IF;
 prohibited:=jsonb_set(good,'{occurrences,0,destination,airportKey}','"GROUP2_PROHIBITED"'::jsonb);
 e:=airlinerra_game.section9_game_route_restrictions_valid_v1('BEG','GROUP2_PROHIBITED',prohibited);
 IF e IS DISTINCT FROM false THEN RAISE EXCEPTION 'Commercially prohibited airport passed admission guard';END IF;
 good:=jsonb_set(good,'{gameHardBlocked}','true'::jsonb);
 IF airlinerra_game.section9_game_route_restrictions_valid_v1('BEG','GROUP2_READY',good)
    IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'Hard game restriction was improperly ignored';END IF;
 RAISE NOTICE 'PASS: live licence-scope candidate compiled without lost privileges, 6 game hard/soft scenarios, research-only warning separate; no schedules, slots, permits or money created.';
END $safe$;
