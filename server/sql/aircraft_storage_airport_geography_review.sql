-- REVIEW ONLY. Candidate geography, not operational approval.
-- Run after storage facilities review. No capacity limits and no commercial writes.
BEGIN;
CREATE VIEW airlinerra_game.aircraft_storage_airport_geography_v1
WITH (security_invoker=true) AS
SELECT f.world_id,f.airport_key,r.airport_name,r.country_iso,r.municipality,
 r.source_ident,r.source_gps_code,r.latitude_deg,r.longitude_deg,
 r.longest_qualifying_runway_m AS registry_runway_length_m,
 p.timezone_iana,p.coordinates_verification,p.profile_release_status,
 w.source_runway_id,w.length_m AS observed_runway_length_m,w.width_m,
 w.surface_reported,w.verification AS runway_verification,w.operational_status,
 t.landing_base_for_reference_aircraft_usd,t.departure_movement_fraction,
 f.admission_scope,f.review_state,
 true AS storage_capacity_unlimited,
 false AS dispatch_authorized
FROM airlinerra_game.aircraft_storage_facilities_v1 f
JOIN airlinerra.airport_registry r ON r.airport_key=f.airport_key
LEFT JOIN airlinerra_game.airport_reference_profiles p ON p.world_id=f.world_id AND p.airport_key=f.airport_key
LEFT JOIN LATERAL (
 SELECT x.* FROM airlinerra_game.airport_runway_inventory x
 WHERE x.world_id=f.world_id AND x.airport_key=f.airport_key
 ORDER BY x.length_m DESC NULLS LAST,x.source_runway_id LIMIT 1
) w ON true
LEFT JOIN airlinerra_game.section8_airport_operating_tariffs_v1 t ON t.world_id=f.world_id AND t.airport_key=f.airport_key
WHERE f.airport_key<>'OURAIRPORTS:19330';
REVOKE ALL ON airlinerra_game.aircraft_storage_airport_geography_v1 FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
