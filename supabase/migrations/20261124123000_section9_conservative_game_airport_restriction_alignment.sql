-- Airlinerra World 1 / Section 5: CONSERVATIVE game-airport restriction
-- read-model alignment. Both catalogs remain immutable and independently
-- traceable. No licence, flight, certificate or source-proof is issued here.
--
-- WHY: 2026-11-24 read-only production comparison showed 360 Group 1
-- airport noise restrictions and 179 Group 1 night bans appearing in the
-- simplified game rule but not the unified airport list, and 1077 Group 1
-- night bans appearing in the catalog but not simplified rules.
-- Group 2 matches. Source authority is disputed; do not silently overwrite.
--
-- Effective display flags use inclusive OR (fail-safe disclosure), not the
-- unreliable assumption that a false on EITHER side verifies no restrictions.
-- The detailed Section 5 flight-time, runway and verified noise certificate
-- gate remains unchanged. A conflict is REVIEW_REQUIRED; NOT approval.
-- Reapply existing column types/order, invoker RLS and Group 2 admission
-- semantics of the live 2026-11-24 view; no release switches touched.

CREATE OR REPLACE VIEW airlinerra_game.airport_unified_operations_v1
WITH (security_invoker = true)
AS
SELECT c.world_id,c.airport_key,c.source_group,c.airport_name,
 c.game_lookup_code,c.country_iso,c.game_category,
 c.latitude_deg,c.longitude_deg,c.timezone_iana,
 c.game_runway_length_m,c.game_terminal_count,c.game_terminal_stands,
 c.game_remote_stands,c.game_cargo_stands,
 c.game_terminal_slot_per_10m,c.game_remote_slot_per_10m,c.game_cargo_slot_per_10m,
 (coalesce(c.game_nighttime_ban,false) OR coalesce(sr.nighttime_ban,false))
   AS game_nighttime_ban,
 (coalesce(c.game_noise_restrictions,false) OR coalesce(sr.noise_restrictions,false))
   AS game_noise_restrictions,
 c.restriction_basis,
 c.game_daily_outbound_passengers,c.game_daily_outbound_cargo_tonnes,
 c.game_season_profile,
 c.game_landing_fee_usd,c.game_parking_per_day_usd,c.game_departing_pax_fee_usd,
 c.game_data_status,
 true AS included_in_unified_catalogue,
 CASE WHEN c.source_group='GROUP_1' THEN true
      ELSE coalesce(r.ready_for_owner_release_review,false) END
   AS admission_review_ready,
 CASE WHEN c.source_group='GROUP_1' THEN true
      ELSE sim.admission_scope='GAME_SIMULATION_ONLY'
           AND coalesce(r.documented_commercial_prohibition,false)=false END
   AS admitted_to_world,
 CASE WHEN c.source_group='GROUP_1' THEN true
      ELSE coalesce(r.ready_for_owner_release_review,false)
           AND rel.release_status='approved' END
   AS operationally_authorized,
 CASE WHEN c.source_group='GROUP_1' THEN true
      ELSE sim.admission_scope='GAME_SIMULATION_ONLY'
           AND coalesce(r.documented_commercial_prohibition,false)=false END
   AS dispatch_eligible_by_airport_admission,
 CASE WHEN c.source_group='GROUP_1' THEN 'EXISTING_APPROVED'
      WHEN coalesce(r.documented_commercial_prohibition,false)
        THEN 'DOCUMENTED_PROHIBITION'
      WHEN sim.admission_scope='GAME_SIMULATION_ONLY'
        THEN 'GAME_SIMULATION_ADMITTED_REAL_WORLD_EVIDENCE_UNVERIFIED'
      ELSE coalesce(r.readiness_status,'ADMISSION_REVIEW_UNAVAILABLE') END
   AS admission_status,
 CASE WHEN c.source_group='GROUP_1' THEN ARRAY[]::text[]
      ELSE coalesce(r.unresolved_gates,
                    ARRAY['admission_review_unavailable']::text[]) END
   AS unresolved_admission_gates,
 CASE WHEN c.source_group='GROUP_1' THEN
       (SELECT p.game_municipality
          FROM airlinerra_game.airport_reference_profiles p
         WHERE p.world_id=c.world_id AND p.airport_key=c.airport_key)
      ELSE
       (SELECT g.game_locality_display
          FROM airlinerra_game.airport_group2_game_profiles_v1 g
         WHERE g.airport_key=c.airport_key) END
   AS game_municipality
FROM airlinerra_game.airport_sections1_8_combined_catalog_v1 c
LEFT JOIN airlinerra_game.airport_group2_admission_readiness_v1 r
  ON c.source_group='GROUP_2' AND c.airport_key=r.airport_key
LEFT JOIN airlinerra_game.airport_group2_operational_releases_v1 rel
  ON c.source_group='GROUP_2' AND rel.world_id=c.world_id
 AND rel.airport_key=c.airport_key
LEFT JOIN airlinerra_game.airport_group2_simulation_admissions_v1 sim
  ON c.source_group='GROUP_2' AND sim.world_id=c.world_id
 AND sim.airport_key=c.airport_key
LEFT JOIN airlinerra_game.section5_airport_simplified_game_rules_v1 sr
  ON sr.world_id=c.world_id AND sr.airport_key=c.airport_key;

COMMENT ON VIEW airlinerra_game.airport_unified_operations_v1 IS
 'World 1 Group 1/2 airport game operations. Conservative nighttime/noise display flags = catalog OR Section5 simplified. Conflicts require separate review; no per-hour curfew, runway/certificate clearance or commercial flight authorization is conveyed. Group 2 admission logic unchanged.';

-- Explain EACH discrepancy without erasing or deciding which source is correct.
-- Private invoker view: no Data API grant. Applies to all 4,259 World 1 rows.
CREATE OR REPLACE VIEW airlinerra_game.section9_airport_game_restriction_alignment_v1
WITH (security_invoker = true)
AS
SELECT c.world_id,c.airport_key,c.source_group,c.game_lookup_code,
 c.game_nighttime_ban AS catalog_nighttime_ban,
 sr.nighttime_ban AS simplified_nighttime_ban,
 c.game_noise_restrictions AS catalog_noise_restrictions,
 sr.noise_restrictions AS simplified_noise_restrictions,
 sr.simplified_nighttime_window,
 sr.permitted_noise_chapters,
 sr.source_status AS simplified_source_status,
 c.restriction_basis AS catalog_restriction_basis,
 (sr.airport_key IS NULL) AS simplified_rule_missing,
 (sr.airport_key IS NOT NULL AND
    c.game_nighttime_ban IS DISTINCT FROM sr.nighttime_ban)
    AS nighttime_rule_conflict,
 (sr.airport_key IS NOT NULL AND
    c.game_noise_restrictions IS DISTINCT FROM sr.noise_restrictions)
    AS noise_rule_conflict,
 (coalesce(c.game_nighttime_ban,false) OR coalesce(sr.nighttime_ban,false))
    AS conservative_game_nighttime_ban,
 (coalesce(c.game_noise_restrictions,false) OR coalesce(sr.noise_restrictions,false))
    AS conservative_game_noise_restrictions,
 CASE
   WHEN sr.airport_key IS NULL THEN 'SIMPLIFIED_GAME_RULE_MISSING'
   WHEN c.game_nighttime_ban IS DISTINCT FROM sr.nighttime_ban
     OR c.game_noise_restrictions IS DISTINCT FROM sr.noise_restrictions
    THEN 'CATALOG_AND_SIMPLIFIED_RULES_DISAGREE_REVIEW_REQUIRED'
   ELSE 'GAME_RULE_SOURCES_AGREE'
 END AS restriction_alignment_status,
 false AS real_world_certification_granted,
 false AS flight_clearance_granted
FROM airlinerra_game.airport_sections1_8_combined_catalog_v1 c
LEFT JOIN airlinerra_game.section5_airport_simplified_game_rules_v1 sr
 ON sr.world_id=c.world_id AND sr.airport_key=c.airport_key;

COMMENT ON VIEW airlinerra_game.section9_airport_game_restriction_alignment_v1 IS
 'Read-only, invoker RLS, explicit catalog versus simplified airport night/noise audit. Conservative flags are NOT approved curfew hours or an aircraft noise certificate. No automatic override of real dispatch authorization.';

REVOKE ALL ON airlinerra_game.section9_airport_game_restriction_alignment_v1
 FROM PUBLIC,anon,authenticated,service_role;
