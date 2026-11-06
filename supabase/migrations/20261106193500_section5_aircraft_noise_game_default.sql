CREATE OR REPLACE VIEW airlinerra_game.section5_aircraft_noise_game_fallback_v1
WITH (security_invoker=true) AS
SELECT c.configuration_id,c.manufacturer_name,c.model_name,c.use_type,
 n.noise_certificate_status,n.official_icao_chapter,
 n.certification_match_basis,
 CASE WHEN n.noise_certificate_status='CERTIFICATE_CONFIGURATION_MATCHED'
  THEN 'USE_VERIFIED_CONFIGURATION_CHAPTER_FOR_APPLICABLE_AIRPORT_BANS'
 ELSE 'NO_ADDITIONAL_GAME_NOISE_BAN_WITHOUT_MATCHED_CERTIFICATE'
 END AS game_noise_fallback,
 n.noise_certificate_status='CERTIFICATE_CONFIGURATION_MATCHED' AS can_enforce_verified_chapter,
 false::boolean AS real_world_noise_clearance,
 'Missing or model-only noise certificates do not create a game ban, but this is a GAME fallback and never a declaration of official aircraft compliance.'::text AS interpretation
FROM airlinerra.aircraft_catalog_configuration_inventory c
LEFT JOIN airlinerra_game.section5_icao_aircraft_certification_v2 n USING(configuration_id);
REVOKE ALL ON airlinerra_game.section5_aircraft_noise_game_fallback_v1 FROM PUBLIC,anon,authenticated;
COMMENT ON VIEW airlinerra_game.section5_aircraft_noise_game_fallback_v1 IS
'User-selected no additional game noise ban when no configuration-matched certificate is available; official uncertainty retained. Dynamic for future aircraft.';
