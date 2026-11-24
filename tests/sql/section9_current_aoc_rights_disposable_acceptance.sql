-- Actual 2026-11-24 deployed canonical AOC + route source verifiers,
-- using synthetic original-airline provenance, jurisdiction and game tick.
-- No HMAC or operating clearance may be issued by this read-only test.
\set ON_ERROR_STOP on
BEGIN;
DO $accept$
DECLARE
 a uuid:='11111111-1111-4111-8111-111111111111';
 home_schedule uuid:='44444444-4444-4444-8444-444444444444';
 foreign_schedule uuid:='55555555-5555-4555-8555-555555555555';
 d date:=DATE '2026-11-24';
 t jsonb;v jsonb;src text; old_status text;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'CANONICAL_AOC_RIGHTS_ACCEPTANCE_DISPOSABLE_ONLY';END IF;
 IF EXISTS(SELECT 1 FROM information_schema.tables
    WHERE table_schema='airlinerra_game'
    AND table_name IN('section9_operator_licence_evidence_v1',
     'section9_route_operating_permission_evidence_v1',
     'business_permission_catalog_v1'))
 THEN RAISE EXCEPTION 'Legacy disabled licence catalogue tables should be absent';END IF;
 SELECT pg_get_functiondef(
 'airlinerra_game.section9_verify_game_operator_licence_v1(uuid,uuid,integer,date)'::regprocedure) INTO src;
 IF position('section9_canonical_aoc_covers_v1' IN src)=0
 OR position('business_permission_catalog_v1' IN src)>0
 OR position('current_setting(''airlinerra.active_recertification'',' IN src)=0
 THEN RAISE EXCEPTION 'Deployed canonical operator verifier reverted to obsolete permission policy';END IF;
 SELECT pg_get_functiondef(
 'airlinerra_game.section9_verify_game_route_traffic_rights_v1(uuid,uuid,integer,date)'::regprocedure) INTO src;
 IF position('section9_game_route_licence_scope_v1' IN src)=0
 OR position('business_permission_catalog_v1' IN src)>0
 OR position('current_setting(''airlinerra.active_recertification'',' IN src)=0
 THEN RAISE EXCEPTION 'Deployed L1/L2 traffic verifier reverted to obsolete grant policy';END IF;
 t:=airlinerra_game.section9_aoc_flight_release_readiness_v1(a,d);
 IF t->>'status'<>'AOC_FLIGHT_READY' OR t->>'authorized'<>'true'
 OR NOT airlinerra_game.section9_canonical_aoc_covers_v1(a,d,28)
 THEN RAISE EXCEPTION 'Original airline AOC 28-day source rejected: %',t;END IF;
 v:=airlinerra_game.section9_verify_game_operator_licence_v1(a,home_schedule,1,d);
 IF v->>'status'<>'verified_game_operator_licence'
 OR v->>'verified'<>'true' OR v->>'readOnly'<>'true'
 OR v->>'ledgerPosted'<>'false' OR v->>'flightActivated'<>'false'
 OR v->>'validThroughGameDate'<>'2026-12-22'
 THEN RAISE EXCEPTION 'Canonical operator licence source not verified: %',v;END IF;
 t:=airlinerra_game.section9_game_route_licence_scope_v1(
 a,'OURAIRPORTS:4610','OURAIRPORTS:3993',d,28);
 IF t->>'decision'<>'L1_HOME_MARKET_ROUTE'
 OR t->>'allowed'<>'true' OR t->>'licence'<>'1'
 THEN RAISE EXCEPTION 'BEG-ZAG game Licence1 scope incorrectly denied: %',t;END IF;
 v:=airlinerra_game.section9_verify_game_route_traffic_rights_v1(
 a,home_schedule,1,d);
 IF v->>'status'<>'verified_game_route_traffic_rights'
 OR v->>'verified'<>'true' OR v->>'verifiedServiceTypes'<>'1'
 OR v->>'requiredServiceTypes' IS NULL
 OR v->>'flightActivated'<>'false' OR v->>'bookingsCreated'<>'false'
 OR v->>'ledgerPosted'<>'false'
 THEN RAISE EXCEPTION 'Actual BEG-ZAG L1 passenger right source failed: %',v;END IF;

 -- No Serbia-home airline may fly domestic Germany without L2 permission.
 t:=airlinerra_game.section9_game_route_licence_scope_v1(
 a,'OURAIRPORTS:2212','OURAIRPORTS:2218',d,28);
 IF t->>'allowed'<>'false' OR t->>'decision'<>'L2_ISSUANCE_NOT_RELEASED'
 THEN RAISE EXCEPTION 'Foreign domestic FRA-MUC cabotage was allowed: %',t;END IF;
 v:=airlinerra_game.section9_verify_game_route_traffic_rights_v1(
 a,foreign_schedule,1,d);
 IF v->>'status'<>'blocked_game_route_traffic_rights'
 OR v->>'verified'<>'false' OR NOT(v->'blockers' ? 'PASSENGER_L2_ISSUANCE_NOT_RELEASED')
 THEN RAISE EXCEPTION 'Foreign domestic airline rights bypassed real L2 issuer: %',v;END IF;

 -- Expired canonical certificate should fail even when no legacy evidence
 -- exists: genuine AOC verifier must deny before route-rights checking.
 UPDATE airlinerra_game.section9_aoc_certificates_v1
 SET status='suspended' WHERE airline_id=a;
 t:=airlinerra_game.section9_aoc_flight_release_readiness_v1(a,d);
 v:=airlinerra_game.section9_verify_game_operator_licence_v1(a,home_schedule,1,d);
 IF t->>'authorized'<>'false'
 OR NOT(t->'issues' ? 'AOC_ACTIVE_CERTIFICATE_NOT_VERIFIED')
 OR v->>'status'<>'blocked_game_operator_licence'
 OR NOT(v->'blockers' ? 'VALID_COMPANY_AOC_REQUIRED')
 OR airlinerra_game.section9_canonical_aoc_covers_v1(a,d,28)
 THEN RAISE EXCEPTION 'Suspended AOC failed to ground game airline: % / %',t,v;END IF;
 UPDATE airlinerra_game.section9_aoc_certificates_v1
 SET status='active' WHERE airline_id=a;

 -- AOC safety policy below 70 must prevent flight.
 UPDATE airlinerra_game.fixture_safety_rating SET game_rating=69 WHERE airline_id=a;
 t:=airlinerra_game.section9_aoc_flight_release_readiness_v1(a,d);
 IF t->>'authorized'<>'false'
 OR NOT(t->'issues' ? 'AOC_SAFETY_RATING_BELOW_70')
 THEN RAISE EXCEPTION 'Safety under 70 was ignored by actual AOC source: %',t;END IF;
 UPDATE airlinerra_game.fixture_safety_rating SET game_rating=90 WHERE airline_id=a;

 -- A forged source identity cannot use a valid certificate.
 UPDATE airlinerra_game.section9_aoc_operating_companies_v1
 SET identity_evidence_reference='unverified-identity'
 WHERE airline_id=a;
 t:=airlinerra_game.section9_aoc_flight_release_readiness_v1(a,d);
 IF t->>'authorized'<>'false'
 OR NOT(t->'issues' ? 'AOC_ORIGINAL_ISSUE_PROVENANCE_INVALID')
 THEN RAISE EXCEPTION 'Incorrect company provenance passed AOC check: %',t;END IF;
 UPDATE airlinerra_game.section9_aoc_operating_companies_v1
 SET identity_evidence_reference='verified-original-airline-registration-v1-'||a
 WHERE airline_id=a;

 -- Verified clock/World1 receipt also mandatory, even for registered AOC.
 UPDATE airlinerra_game.holding_world_clock_v1 SET confirmed_game_date='2026-11-23';
 v:=airlinerra_game.section9_verify_game_operator_licence_v1(a,home_schedule,1,d);
 IF v->>'status'<>'blocked_unverified_world_or_game_day'
 THEN RAISE EXCEPTION 'Stale tick let private operator source pass: %',v;END IF;
 UPDATE airlinerra_game.holding_world_clock_v1 SET confirmed_game_date=d;
 IF (airlinerra_game.section9_verify_game_operator_licence_v1(
      a,home_schedule,1,d)->>'status')<>'verified_game_operator_licence'
 THEN RAISE EXCEPTION 'Restored positive licence did not recover';END IF;

 -- This is source verification ONLY; no signing key, certificate event,
 -- slot reservation, wallet transaction, schedule activation or passenger row.
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1
    WHERE status='active' OR operationally_verified=true)
 THEN RAISE EXCEPTION 'Read-only verification activated a flight';END IF;
 RAISE NOTICE 'PASS: actual CURRENT AOC verification + L1 BEG-ZAG passenger game rights; suspended AOC, low safety, forged identity, stale clock and L2 FRA-MUC all DENIED; 0 certificates signed or player state changed.';
END $accept$;
ROLLBACK;
