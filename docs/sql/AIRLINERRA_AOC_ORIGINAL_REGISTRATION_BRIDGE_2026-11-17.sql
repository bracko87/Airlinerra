-- AOC original-airline registration bridge, dormant until release.
-- Called INSIDE existing create_airline_with_codes transaction by trusted
-- onboarding service. Never charges/creates AOCs when release disabled.
-- Existing registered original airline can be backfilled once with same path.
-- The starter company's current default commercial type is passenger;
-- service types/aircraft clearances remain independent game systems.

CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_original_registration_bridge_v1(
 p_player uuid,p_world smallint,p_airline uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE company airlinerra_game.airlines%ROWTYPE; issuance jsonb;
 registry record;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_world IS DISTINCT FROM 1
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='AOC_ORIGINAL_REGISTRATION_INVALID_SCOPE';END IF;

 -- Dormant deployments NEVER change registration behaviour or data.
 IF NOT EXISTS (
  SELECT 1 FROM airlinerra_game.section9_aoc_release_policy_v1
  WHERE world_id=1 AND issuance_enabled=true
 ) THEN RETURN jsonb_build_object('status','aoc_not_released',
   'issued',false,'charged',false,'flightActivated',false);END IF;

 IF current_user IS DISTINCT FROM 'postgres'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='AOC_ORIGINAL_REGISTRATION_POSTGRES_ONLY';END IF;

 -- The user/airline/world identity must come from the just-verified server
 -- registration transaction, NOT a client-provided identity claim.
 SELECT * INTO company FROM airlinerra_game.airlines a
 WHERE a.id=p_airline AND a.owner_player_id=p_player
  AND a.world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='AOC_ORIGINAL_REGISTRATION_NOT_OWNED';END IF;

 -- The primary signup function enforces one original airline per world.
 -- Never classify a later subsidiary as a free original airline.
 IF (SELECT count(*) FROM airlinerra_game.airlines a
     WHERE a.owner_player_id=p_player AND a.world_id=1)<>1
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='AOC_ORIGINAL_REGISTRATION_MULTIPLE_AIRLINES';END IF;

 SELECT * INTO registry
 FROM airlinerra_game.section9_aoc_operating_companies_v1 oc
 WHERE oc.airline_id=p_airline FOR UPDATE;
 IF FOUND AND (registry.company_source<>'original' OR
   registry.world_id<>1)
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='AOC_ORIGINAL_REGISTRATION_COMPANY_SCOPE_CONFLICT';END IF;

 IF NOT FOUND THEN
  INSERT INTO airlinerra_game.section9_aoc_operating_companies_v1
   (airline_id,world_id,company_source,business_kind,
    identity_evidence_reference)
  VALUES(p_airline,1,'original','passenger',
   'verified-original-airline-registration-v1-'||p_airline::text);
 END IF;

 issuance:=airlinerra_game.section9_aoc_issue_original_v1(p_airline);
 IF issuance->>'status' NOT IN('aoc_original_issued','aoc_already_recorded')
 OR issuance->>'charged' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='AOC_ORIGINAL_REGISTRATION_ISSUE_INCOMPLETE',
   DETAIL=issuance::text;END IF;
 RETURN jsonb_build_object('status',issuance->>'status',
  'issued',issuance->>'issued'='true','charged',false,
  'airlineId',p_airline,'flightActivated',false);
END $fn$;

REVOKE ALL ON FUNCTION
 airlinerra_game.section9_aoc_original_registration_bridge_v1(
 uuid,smallint,uuid)
 FROM PUBLIC,anon,authenticated,service_role;
