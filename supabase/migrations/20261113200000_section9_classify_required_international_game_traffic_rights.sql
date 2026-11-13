-- Identify the TYPE of home-airline international third/fourth freedom grant required.
-- An unresolved bilateral agreement is NOT an approval; signed game grants and
-- operator licence, payment, airport restrictions and activation stay protected.
-- Reference: https://wasa.icao.int/aboutwasa/wasaexplanatorynotes

CREATE OR REPLACE FUNCTION airlinerra_game.section9_required_game_traffic_permission_v1(p_operator text, p_origin text, p_destination text, p_service_type text, p_game_day date)
 RETURNS text
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE preview jsonb;
BEGIN
 IF p_service_type NOT IN ('passenger','cargo') OR p_game_day IS NULL
 THEN RETURN NULL;END IF;
 preview:=airlinerra_game.aviation_route_rights_preview_v1(
  p_operator,p_origin,p_destination,p_service_type,p_game_day);
 IF preview->>'operationally_authorized' IS DISTINCT FROM 'false'
   OR preview->>'status' IN ('invalid_input','forbidden')
 THEN RETURN NULL;END IF;
 -- Classify the grant which MUST BE OBTAINED; do not imply that a grant exists.
 -- ICAO third/fourth freedom definition: home -> foreign or foreign -> home.
 -- An unresolved bilateral agreement remains unresolved in the independent
 -- game permission/evidence, operator licensing, and activation gates.
 IF preview->>'status'='agreement_check_required' THEN
  IF p_operator~'^[A-Z]{2}$' AND p_origin~'^[A-Z]{2}$'
   AND p_destination~'^[A-Z]{2}$' AND p_origin<>p_destination
   AND (p_operator=p_origin OR p_operator=p_destination)
  THEN RETURN 'THIRD_FOURTH_FREEDOM'; END IF;
  RETURN NULL;
 END IF;
 RETURN CASE
  WHEN preview->>'reason'='domestic_airline_own_jurisdiction'
   THEN 'DOMESTIC_TRAFFIC'
  WHEN preview->>'reason'='eea_licenced_carrier_intra_market'
   THEN 'INTEGRATED_MARKET'
  WHEN preview->>'reason' IN (
   'foreign_domestic_cabotage_not_automatically_granted',
   'anz_designation_for_foreign_domestic') THEN 'CABOTAGE'
  WHEN preview->>'required_freedom' IN ('3','4')
   THEN 'THIRD_FOURTH_FREEDOM'
  WHEN preview->>'required_freedom'='7'
   THEN 'SEVENTH_FREEDOM'
  WHEN preview->>'reason' IN (
   'serbia_ecaa_third_fourth_freedom_principle',
   'us_open_skies_international_principle')
   AND (p_operator=p_origin OR p_operator=p_destination)
   THEN 'THIRD_FOURTH_FREEDOM'
  ELSE NULL END;
END $function$
;
