CREATE OR REPLACE VIEW airlinerra_game.section5_aircraft_noise_certification_queue_v1
WITH (security_invoker=true) AS
SELECT a.configuration_id,a.manufacturer_name,a.model_name,a.configuration_code,a.use_type,
 a.engine_option,a.mtow_kg,a.mlw_kg,a.technical_review_status,a.number_of_technical_options,
 c.official_icao_chapter,c.noise_certificate_status,c.certification_match_basis,
 c.certified_engine_or_variant,c.certified_mtow_kg,c.certificate_reference,
 c.evidence_url AS certificate_evidence_url,c.evidence_checked_on,
 c.airframe_registration_specific,c.candidate_note,
 CASE
  WHEN c.noise_certificate_status='CERTIFICATE_CONFIGURATION_MATCHED'
   THEN 'OFFICIAL_CONFIGURATION_MATCH_VERIFIED'
  WHEN c.official_icao_chapter IS NOT NULL
   THEN 'MODEL_OR_AUTHORITY_REPORTED_NOT_CERTIFICATE_MATCH'
  ELSE 'NO_CONFIG_MATCHED_CERTIFICATE_AVAILABLE'
 END AS game_noise_validation_status,
 CASE
  WHEN a.engine_option IS NULL OR btrim(a.engine_option)='' THEN 'MISSING_SELECTED_ENGINE'
  WHEN a.engine_option ~* '(or |/|choices|options|unconfirmed|pending)' THEN 'MULTIPLE_OR_UNCONFIRMED_ENGINE_OPTIONS'
  ELSE 'ENGINE_REPORTED_EXACT_VARIANT_NEEDS_CERTIFICATE_MATCH'
 END AS engine_resolution_status,
 CASE
  WHEN a.mtow_kg IS NULL THEN 'MISSING_GAME_MTOW'
  WHEN c.certified_mtow_kg IS NULL THEN 'CERTIFIED_WEIGHT_VARIANT_NOT_MATCHED'
  WHEN a.mtow_kg<>c.certified_mtow_kg THEN 'GAME_AND_CERTIFICATE_MTOW_DIFFER'
  ELSE 'GAME_AND_CERTIFICATE_MTOW_EQUAL'
 END AS weight_resolution_status,
 c.noise_certificate_status IS DISTINCT FROM 'CERTIFICATE_CONFIGURATION_MATCHED' AS needs_certificate_research,
 CASE
 WHEN a.use_type IN('passenger','cargo','combi')
 THEN 'https://www.easa.europa.eu/en/domains/environment/easa-certification-noise-levels'
 ELSE 'https://www.icao.int/environmental-protection/reduction-noise-source'
 END AS official_research_start_url,
 'Official Chapter must match the actual configuration, installed engine, weight variant and required modifications. Absence of certificate is NOT proof of a prohibited Chapter.'::text AS research_handling_policy
FROM airlinerra.aircraft_catalog_configuration_inventory a
LEFT JOIN airlinerra_game.section5_icao_aircraft_certification_v2 c
 ON c.configuration_id=a.configuration_id;
REVOKE ALL ON airlinerra_game.section5_aircraft_noise_certification_queue_v1 FROM PUBLIC,anon,authenticated;
COMMENT ON VIEW airlinerra_game.section5_aircraft_noise_certification_queue_v1 IS
'Dynamically includes all current and newly added catalog aircraft configurations. Shows verified official certification only when configuration matched. Unverified rows are research backlog, never fabricated Chapter bans.';
