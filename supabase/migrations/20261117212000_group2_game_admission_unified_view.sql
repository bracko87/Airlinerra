-- Airport GAME admission is separate from official operational authorisation.
-- `operationally_authorized` stays on prior evidence based release; no commercial flight activation.
create or replace view airlinerra_game.airport_unified_operations_v1 as
 SELECT c.world_id,
    c.airport_key,
    c.source_group,
    c.airport_name,
    c.game_lookup_code,
    c.country_iso,
    c.game_category,
    c.latitude_deg,
    c.longitude_deg,
    c.timezone_iana,
    c.game_runway_length_m,
    c.game_terminal_count,
    c.game_terminal_stands,
    c.game_remote_stands,
    c.game_cargo_stands,
    c.game_terminal_slot_per_10m,
    c.game_remote_slot_per_10m,
    c.game_cargo_slot_per_10m,
    c.game_nighttime_ban,
    c.game_noise_restrictions,
    c.restriction_basis,
    c.game_daily_outbound_passengers,
    c.game_daily_outbound_cargo_tonnes,
    c.game_season_profile,
    c.game_landing_fee_usd,
    c.game_parking_per_day_usd,
    c.game_departing_pax_fee_usd,
    c.game_data_status,
    true AS included_in_unified_catalogue,
        CASE
            WHEN c.source_group = 'GROUP_1'::text THEN true
            ELSE COALESCE(r.ready_for_owner_release_review, false)
        END AS admission_review_ready,
        CASE
            WHEN c.source_group = 'GROUP_1'::text THEN true
            ELSE sim.admission_scope = 'GAME_SIMULATION_ONLY'::text AND COALESCE(r.documented_commercial_prohibition,false)=false
        END AS admitted_to_world,
        CASE
            WHEN c.source_group = 'GROUP_1'::text THEN true
            ELSE COALESCE(r.ready_for_owner_release_review, false) AND rel.release_status = 'approved'::text
        END AS operationally_authorized,
        CASE
            WHEN c.source_group = 'GROUP_1'::text THEN true
            ELSE sim.admission_scope = 'GAME_SIMULATION_ONLY'::text AND COALESCE(r.documented_commercial_prohibition,false)=false
        END AS dispatch_eligible_by_airport_admission,
        CASE
            WHEN c.source_group = 'GROUP_1'::text THEN 'EXISTING_APPROVED'::text
            WHEN COALESCE(r.documented_commercial_prohibition, false) THEN 'DOCUMENTED_PROHIBITION'::text
            WHEN sim.admission_scope = 'GAME_SIMULATION_ONLY'::text THEN 'GAME_SIMULATION_ADMITTED_REAL_WORLD_EVIDENCE_UNVERIFIED'::text
            ELSE COALESCE(r.readiness_status, 'ADMISSION_REVIEW_UNAVAILABLE'::text)
        END AS admission_status,
        CASE
            WHEN c.source_group = 'GROUP_1'::text THEN ARRAY[]::text[]
            ELSE COALESCE(r.unresolved_gates, ARRAY['admission_review_unavailable'::text])
        END AS unresolved_admission_gates,
        CASE
            WHEN c.source_group = 'GROUP_1'::text THEN ( SELECT p.game_municipality
               FROM airlinerra_game.airport_reference_profiles p
              WHERE p.world_id = c.world_id AND p.airport_key = c.airport_key)
            ELSE ( SELECT g.game_locality_display
               FROM airlinerra_game.airport_group2_game_profiles_v1 g
              WHERE g.airport_key = c.airport_key)
        END AS game_municipality
   FROM airlinerra_game.airport_sections1_8_combined_catalog_v1 c
     LEFT JOIN airlinerra_game.airport_group2_admission_readiness_v1 r ON c.source_group = 'GROUP_2'::text AND c.airport_key = r.airport_key
     LEFT JOIN airlinerra_game.airport_group2_operational_releases_v1 rel ON c.source_group = 'GROUP_2'::text AND rel.world_id = c.world_id AND rel.airport_key = c.airport_key
     LEFT JOIN airlinerra_game.airport_group2_simulation_admissions_v1 sim ON c.source_group = 'GROUP_2'::text AND sim.world_id=c.world_id AND sim.airport_key=c.airport_key;
