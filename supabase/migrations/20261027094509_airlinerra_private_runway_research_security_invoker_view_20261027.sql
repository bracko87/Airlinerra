
CREATE VIEW airlinerra.runway_research_facts
WITH (security_invoker = true)
AS
SELECT
  sv.id AS source_version_id,
  sv.airport_key,
  r.source_gps_code AS icao,
  sv.runway_pair,
  sv.source_effective_date,
  sv.observed_on,
  sv.source_authority,
  sv.source_url,
  sv.evidence_id,
  sv.validation_status,
  r.longest_qualifying_runway_m AS original_registry_longest_runway_m,
  p.physical_length_m,
  p.width_m,
  p.raw_surface,
  p.normalized_surface,
  p.material_verification,
  p.runway_operational_status,
  a.paved_runway_status AS existing_airport_review_material_status,
  a.civilian_access_status,
  a.commercial_permission_status,
  a.game_admission_status,
  p.caveat
FROM airlinerra.runway_source_versions sv
JOIN airlinerra.runway_physical_facts p ON p.source_version_id = sv.id
JOIN airlinerra.airport_registry r ON r.airport_key = sv.airport_key
JOIN airlinerra.airport_access_reviews a ON a.airport_key = sv.airport_key;
REVOKE ALL ON airlinerra.runway_research_facts FROM PUBLIC,anon,authenticated;
COMMENT ON VIEW airlinerra.runway_research_facts IS
 'PRIVATE research read-only join, security invoker, NOT an airport game admission view or operational flight-planning source.';
