-- Licence 6 is retired and its function/table plumbing is removed.
-- Destructive cleanup is allowed ONLY if there are zero real records.
-- Historical migrations in git preserve provenance; new entitlement lives in L2.
DO $guard$
BEGIN
 IF EXISTS (SELECT 1 FROM airlinerra_game.licence6_fifth_applications_v1)
 OR EXISTS (SELECT 1 FROM airlinerra_game.licence6_fifth_approvals_v1)
 OR EXISTS (SELECT 1 FROM airlinerra_game.licence6_fifth_market_policies_v1)
 THEN RAISE EXCEPTION 'CANNOT_RETIRE_LICENCE6_WITH_PLAYER_OR_MARKET_RECORDS';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.licence6_fifth_release_v1 WHERE issuance_enabled
 OR fee_review_verified OR market_authority_verified OR route_enforcement_verified)
 THEN RAISE EXCEPTION 'CANNOT_RETIRE_RELEASED_LICENCE6';END IF;
 IF EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-licence6-fifth-review-v1')
 THEN RAISE EXCEPTION 'CANNOT_RETIRE_LICENCE6_WHILE_REVIEW_WORKER_ENABLED';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.business_permission_catalog_v1
 WHERE permission_code='FIFTH_FREEDOM' AND enabled_in_game)
 THEN RAISE EXCEPTION 'CANNOT_RETIRE_ACTIVE_FIFTH_FREEDOM_CATALOGUE';END IF;
END $guard$;
DROP FUNCTION IF EXISTS airlinerra_game.licence6_fifth_grant_scope_v1(uuid,text,text,text,text);
DROP FUNCTION IF EXISTS airlinerra_game.licence6_review_due_fifth_applications_v1(integer);
DROP FUNCTION IF EXISTS airlinerra_game.licence6_submit_fifth_application_v1(uuid,uuid,text,text,text,text,uuid);
DROP FUNCTION IF EXISTS airlinerra_game.licence6_fifth_readiness_v1(uuid,text,text,text,text);
DROP TABLE airlinerra_game.licence6_fifth_approvals_v1;
DROP TABLE airlinerra_game.licence6_fifth_applications_v1;
DROP TABLE airlinerra_game.licence6_fifth_market_policies_v1;
DROP TABLE airlinerra_game.licence6_fifth_release_v1;
