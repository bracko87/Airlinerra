-- Licence 6: Fifth Freedom (Airlinerra game-only, route-specific).
-- A home-connected A->B->C itinerary where A is the airline home country
-- and B,C are distinct foreign countries. This does not create real-world rights.
-- Fee remains unset until a market-specific game tariff is approved.
UPDATE airlinerra_game.business_permission_catalog_v1
 SET processing_game_days=7,
 purpose='Game-only airline permission for one specified foreign-to-foreign segment of a home-connected itinerary; no seventh freedom, cabotage, unrestricted routes or actual flight activation.',
 requirements='Own active AOC, verified home-country to foreign A to foreign B itinerary, underlying international rights, explicit applicable market authority, seven game days, market-specific fee within $100,000 to $250,000.',
 application_guidance='Licence 6 is route-specific, not a worldwide airline licence. Submission remains locked until an independent country-pair approval and a fee are verified. A route slot, flight, sale or real-world authorization is never granted automatically.',
 updated_at=clock_timestamp()
 WHERE permission_code='FIFTH_FREEDOM' AND enabled_in_game=false;
CREATE TABLE airlinerra_game.licence6_fifth_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 issuance_enabled boolean NOT NULL DEFAULT false,
 fee_review_verified boolean NOT NULL DEFAULT false,
 market_authority_verified boolean NOT NULL DEFAULT false,
 route_enforcement_verified boolean NOT NULL DEFAULT false,
 release_reference text,
 CONSTRAINT licence6_fifth_hard_release_lock_v1
 CHECK (issuance_enabled=false AND fee_review_verified=false AND
       market_authority_verified=false AND route_enforcement_verified=false)
);
INSERT INTO airlinerra_game.licence6_fifth_release_v1(world_id) VALUES(1);
CREATE TABLE airlinerra_game.licence6_fifth_market_policies_v1(
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 operator_country_iso2 text NOT NULL CHECK(operator_country_iso2~'^[A-Z]{2}$'),
 first_foreign_country_iso2 text NOT NULL CHECK(first_foreign_country_iso2~'^[A-Z]{2}$'),
 second_foreign_country_iso2 text NOT NULL CHECK(second_foreign_country_iso2~'^[A-Z]{2}$'),
 service_type text NOT NULL CHECK(service_type IN ('passenger','cargo')),
 fee_usd numeric CHECK(fee_usd BETWEEN 100000 AND 250000),
 country_rights_verified boolean NOT NULL DEFAULT false,
 independent_review_reference text,
 approved_from_game_day date,
 expires_game_day date,
 PRIMARY KEY(world_id,operator_country_iso2,first_foreign_country_iso2,second_foreign_country_iso2,service_type),
 CHECK(operator_country_iso2<>first_foreign_country_iso2 AND
       operator_country_iso2<>second_foreign_country_iso2 AND
       first_foreign_country_iso2<>second_foreign_country_iso2),
 CHECK(NOT country_rights_verified OR
       (fee_usd IS NOT NULL AND length(independent_review_reference)>=16 AND
        approved_from_game_day IS NOT NULL AND expires_game_day>approved_from_game_day))
);
ALTER TABLE airlinerra_game.licence6_fifth_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.licence6_fifth_market_policies_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.licence6_fifth_release_v1,
 airlinerra_game.licence6_fifth_market_policies_v1
 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.licence6_fifth_readiness_v1(
 p_airline uuid,p_home_airport text,p_foreign_stop text,
 p_foreign_destination text,p_service_type text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE
 a record; h text; b text; c text; d date; policy record;
 issues text[]:=array[]::text[];
 own_aoc boolean:=false;fee numeric:=NULL;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE6_TRUSTED_READ_ONLY';
 END IF;
 IF p_airline IS NULL OR p_home_airport IS NULL OR
  p_foreign_stop IS NULL OR p_foreign_destination IS NULL OR
  p_service_type NOT IN('passenger','cargo') OR
  length(p_home_airport)>120 OR length(p_foreign_stop)>120 OR length(p_foreign_destination)>120
 THEN RETURN jsonb_build_object('status','INVALID_ITINERARY','eligible',false,
  'canApply',false,'permissionCode','FIFTH_FREEDOM','feeUsd',NULL,
  'processingGameDays',7,'routeAuthorized',false,'flightActivated',false);END IF;
 SELECT * INTO a FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','AIRLINE_NOT_FOUND',
  'eligible',false,'canApply',false,'permissionCode','FIFTH_FREEDOM',
  'feeUsd',NULL,'routeAuthorized',false,'flightActivated',false);END IF;
 SELECT country_iso INTO h FROM airlinerra_game.airport_reference_profiles
 WHERE world_id=1 AND airport_key=p_home_airport;
 SELECT country_iso INTO b FROM airlinerra_game.airport_reference_profiles
 WHERE world_id=1 AND airport_key=p_foreign_stop;
 SELECT country_iso INTO c FROM airlinerra_game.airport_reference_profiles
 WHERE world_id=1 AND airport_key=p_foreign_destination;
 IF h IS NULL OR b IS NULL OR c IS NULL THEN
  issues:=array_append(issues,'VERIFIED_AIRPORT_COUNTRIES_REQUIRED');
 END IF;
 IF p_home_airport=p_foreign_stop OR p_foreign_stop=p_foreign_destination
   OR p_home_airport=p_foreign_destination OR
   h IS NULL OR b IS NULL OR c IS NULL OR
   h=b OR h=c OR b=c THEN
  issues:=array_append(issues,'HOME_CONNECTED_THREE_COUNTRY_ITINERARY_REQUIRED');
 END IF;
 IF NOT EXISTS(
  SELECT 1 FROM airlinerra_game.airport_reference_profiles home
  WHERE home.world_id=1 AND home.airport_key=a.home_airport_key
   AND home.country_iso=h)
 THEN issues:=array_append(issues,'AIRLINE_HOME_COUNTRY_REQUIRED');END IF;
 d:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF d IS NULL THEN issues:=array_append(issues,'VERIFIED_GAME_CLOCK_REQUIRED');END IF;
 SELECT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_aoc_certificates_v1 cert
  WHERE cert.world_id=1 AND cert.airline_id=p_airline AND cert.status='active'
   AND d>=cert.issued_game_day AND d<cert.expires_game_day
 ) INTO own_aoc;
 IF NOT own_aoc THEN issues:=array_append(issues,'ACTIVE_COMPANY_AOC_REQUIRED');END IF;
 -- Do not mistake theoretical foreign-network access for specific fifth freedom.
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.licence2_airline_market_permits_v1 l2
  WHERE l2.world_id=1 AND l2.airline_id=p_airline AND l2.status='active')
 THEN issues:=array_append(issues,'ACTIVE_FOREIGN_NETWORK_PERMISSION_REQUIRED');END IF;
 IF h IS NOT NULL AND b IS NOT NULL AND c IS NOT NULL AND d IS NOT NULL THEN
  SELECT * INTO policy FROM airlinerra_game.licence6_fifth_market_policies_v1
  WHERE world_id=1 AND operator_country_iso2=h
   AND first_foreign_country_iso2=b AND second_foreign_country_iso2=c
   AND service_type=p_service_type;
  IF FOUND THEN fee:=policy.fee_usd;END IF;
 END IF;
 IF fee IS NULL THEN issues:=array_append(issues,'MARKET_SPECIFIC_FEE_UNDECIDED');END IF;
 IF NOT FOUND OR policy.country_rights_verified IS DISTINCT FROM true
  OR d IS NULL OR policy.approved_from_game_day>d
  OR policy.expires_game_day<=d+7
 THEN issues:=array_append(issues,'INDEPENDENT_FIFTH_FREEDOM_MARKET_PROOF_REQUIRED');END IF;
 IF fee IS NOT NULL AND a.cash_usd<fee
 THEN issues:=array_append(issues,'INSUFFICIENT_COMPANY_FUNDS');END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.licence6_fifth_release_v1
  WHERE world_id=1 AND issuance_enabled AND fee_review_verified
   AND market_authority_verified AND route_enforcement_verified)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.business_permission_catalog_v1
  WHERE permission_code='FIFTH_FREEDOM' AND enabled_in_game)
 THEN issues:=array_append(issues,'LICENCE6_NOT_RELEASED');END IF;
 RETURN jsonb_build_object(
 'status','LICENCE6_FIFTH_FREEDOM_READINESS','airlineId',p_airline,
 'permissionCode','FIFTH_FREEDOM','serviceType',p_service_type,
 'homeCountry',h,'firstForeignCountry',b,'secondForeignCountry',c,
 'homeAirport',p_home_airport,'foreignStop',p_foreign_stop,
 'foreignDestination',p_foreign_destination,'gameDay',d,
 'feeUsd',fee,'proposedFeeMinUsd',100000,'proposedFeeMaxUsd',250000,
 'processingGameDays',7,'eligible',cardinality(issues)=0,'canApply',false,
 'issues',to_jsonb(issues),'routeAuthorized',false,
 'foreignSegmentAuthorized',false,'flightActivated',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.licence6_fifth_readiness_v1(uuid,text,text,text,text)
 FROM PUBLIC,anon,authenticated,service_role;
