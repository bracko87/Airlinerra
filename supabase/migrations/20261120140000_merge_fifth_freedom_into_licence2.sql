-- Consolidation: Fifth Freedom is NO LONGER a separately purchasable game licence.
-- Licence 2 owns foreign-network eligibility. Independent traffic-rights verification
-- still applies to each foreign segment; this migration never grants flight access.
DO $cron$
BEGIN
 IF EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-licence6-fifth-review-v1')
 THEN PERFORM cron.unschedule('airlinerra-licence6-fifth-review-v1'); END IF;
END $cron$;
-- Retain inert historical tables for audit/rollback compatibility. Hard issuance
-- release constraint remains in place and is not modified.
UPDATE airlinerra_game.business_permission_catalog_v1
SET game_fee_usd=NULL,processing_game_days=NULL,
 purpose='Historical Fifth Freedom reference only. Foreign-to-foreign game network expansion is handled by Licence 2 with independent route/country traffic-rights enforcement. No separate Licence 6 purchase.',
 application_guidance='Retired as a player licence. Check Licence 2 for foreign-network routes. Real traffic rights remain separately verified; this is never a blanket authorization.',
 updated_at=clock_timestamp()
WHERE permission_code='FIFTH_FREEDOM' AND enabled_in_game=false;

CREATE OR REPLACE FUNCTION airlinerra_game.licence2_home_connected_foreign_segment_v1(
 p_airline uuid,p_home text,p_stop text,p_destination text,
 p_service text,p_target_market text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE home_country text; stop_country text; destination_country text;
 operator_country text; market_result jsonb; rights_preview jsonb; day_now date;
BEGIN
 IF p_airline IS NULL OR p_home IS NULL OR p_stop IS NULL
  OR p_destination IS NULL OR p_service NOT IN ('passenger','cargo')
  OR p_home=p_stop OR p_stop=p_destination OR p_home=p_destination
  OR length(p_home)>120 OR length(p_stop)>120 OR length(p_destination)>120
 THEN RETURN jsonb_build_object('decision','INVALID_ITINERARY',
  'handledByLicence',2,'separateLicence6Required',false,
  'additionalLicence6FeeUsd',0,'canActivateFlights',false);
 END IF;
 SELECT p.country_iso INTO operator_country
 FROM airlinerra_game.airlines a
 JOIN airlinerra_game.airport_reference_profiles p
 ON p.airport_key=a.home_airport_key AND p.world_id=a.world_id
 WHERE a.id=p_airline AND a.world_id=1;
 SELECT country_iso INTO home_country FROM airlinerra_game.airport_reference_profiles
 WHERE world_id=1 AND airport_key=p_home;
 SELECT country_iso INTO stop_country FROM airlinerra_game.airport_reference_profiles
 WHERE world_id=1 AND airport_key=p_stop;
 SELECT country_iso INTO destination_country FROM airlinerra_game.airport_reference_profiles
 WHERE world_id=1 AND airport_key=p_destination;
 IF operator_country IS NULL OR home_country IS NULL
  OR stop_country IS NULL OR destination_country IS NULL
 THEN RETURN jsonb_build_object('decision','UNVERIFIED_AIRPORT_COUNTRIES',
  'handledByLicence',2,'separateLicence6Required',false,
  'additionalLicence6FeeUsd',0,'canActivateFlights',false);END IF;
 IF operator_country<>home_country OR home_country=stop_country
 OR home_country=destination_country OR stop_country=destination_country
 THEN RETURN jsonb_build_object('decision','NOT_HOME_CONNECTED_FIFTH_FREEDOM',
  'handledByLicence',2,'separateLicence6Required',false,
  'additionalLicence6FeeUsd',0,'canActivateFlights',false);END IF;

 -- Existing Licence 2 policy determines the foreign-to-foreign network
 -- entitlement, including its market level, hub and directed-route quota.
 market_result:=airlinerra_game.licence2_foreign_route_preview_v1(
  p_airline,p_stop,p_destination,p_target_market);
 day_now:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF day_now IS NOT NULL THEN
  rights_preview:=airlinerra_game.aviation_route_rights_preview_v1(
   operator_country,stop_country,destination_country,p_service,day_now);
 END IF;
 RETURN jsonb_build_object(
 'decision',CASE
   WHEN market_result->>'decision'='L1_HOME_MARKET_ROUTE'
    THEN 'INTEGRATED_MARKET_RIGHTS_REVIEW'
   WHEN market_result->>'decision'='L2_NEEDS_DIRECTED_ROUTE_QUOTA_CHECK'
    THEN 'LICENCE2_ELIGIBLE_ROUTE_RIGHTS_REVIEW'
   ELSE 'LICENCE2_MARKET_REQUIREMENTS_NOT_MET' END,
 'handledByLicence',2,'separateLicence6Required',false,
 'additionalLicence6FeeUsd',0,
 'licence2RouteDecision',market_result->>'decision',
 'licence2Market',market_result->>'market',
 'homeCountry',home_country,'firstForeignCountry',stop_country,
 'secondForeignCountry',destination_country,
 'internationalTrafficRightsStatus',rights_preview->>'status',
 'internationalTrafficRightsVerified',false,
 'requiresSeparateCountryRightsEvidence',true,
 'requiresExistingDirectedRouteChecks',true,
 'canActivateFlights',false,'ticketsAuthorized',false,
 'cargoSalesAuthorized',false,
 'note','Licence 2 replaces standalone Licence 6; country rights, schedule, slots, AOC and market allocation still require independent verification');
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.licence2_home_connected_foreign_segment_v1(
 uuid,text,text,text,text,text) FROM PUBLIC,anon,authenticated,service_role;
