-- Airlinerra Group 3 Step 4: source-aware aircraft performance, noise and airport planning.
-- Validates 39 source records, 122,499 airport-aircraft research screens.
-- A model-specific noise TCDSN match does not equal individual registered-aircraft permission.
DO $g3perf$
DECLARE n bigint;
BEGIN
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_performance_noise_audit_v1;
 IF n<>39 THEN RAISE EXCEPTION '39 Group3 technical provenance audits required; got %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_performance_noise_audit_v1
 WHERE source_url IS NOT NULL AND engine_option_for_game IS NOT NULL
 AND source_scope IS NOT NULL AND noise_match_scope IS NOT NULL
 AND official_airframe_noise_permission_issued=false AND released_for_gameplay=false
 AND game_chapter_is_not_automatic_dispatch_permission
 AND airport_runway_screen_is_not_certified_operation;
 IF n<>39 THEN RAISE EXCEPTION 'Only %/39 research sources retain engine/noise safety flags',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_unified_game_data_v1
 WHERE has_all_planning_game_sections_populated;
 IF n<>39 THEN RAISE EXCEPTION 'Only %/39 Group3 game-performance records remain complete',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_performance_noise_audit_v1
 WHERE noise_match_scope='SELECTED_TYPE_ENGINE_MASS_CERTIFICATE_MATCH';
 IF n<>1 THEN RAISE EXCEPTION 'Expected exactly one selected variant/engine/MTOW+MLW certificate match, got %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_performance_noise_audit_v1
 WHERE noise_match_scope='DONOR_TYPE_ENGINE_PROP_MASS_MATCH_CONVERSION_UNVERIFIED';
 IF n<>2 THEN RAISE EXCEPTION 'Two donor-only ATR42 noise references expected, got %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_performance_noise_audit_v1
 WHERE published_takeoff_field_length_m>0 AND published_landing_field_length_m>0;
 IF n<>5 THEN RAISE EXCEPTION 'Five actual OEM donor/development field-length reference pairs expected, got %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3 g
 JOIN airlinerra.aircraft_expansion_group3_planning_seed s USING(entry_no)
 JOIN airlinerra.aircraft_technical_specs t ON t.configuration_id=g.configuration_id AND t.spec_label='base'
 JOIN airlinerra.aircraft_expansion_group3_unified_game_data_v1 u USING(entry_no)
 WHERE s.fuel_l>0 AND s.fuel_density_kg_per_l BETWEEN .70 AND .90
 AND ABS(u.game_usable_fuel_kg-(s.fuel_l*s.fuel_density_kg_per_l))<.001
 AND t.maximum_fuel_capacity_l=s.fuel_l;
 IF n<>39 THEN RAISE EXCEPTION 'Only %/39 aircraft consistent between source fuel, density, model fuel mass',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3 g
 JOIN airlinerra.aircraft_expansion_group3_planning_seed s USING(entry_no)
 JOIN airlinerra.aircraft_technical_specs t ON t.configuration_id=g.configuration_id AND t.spec_label='base'
 JOIN airlinerra.aircraft_expansion_group3_performance_noise_audit_v1 a USING(entry_no)
 JOIN airlinerra_game.section5_icao_aircraft_certification_v2 ic ON ic.configuration_id=g.configuration_id
 WHERE g.entry_no=1
 AND s.mtow_kg=372000 AND s.mlw_kg=243000 AND s.mzfw_kg=230000
 AND s.oew_kg=170048
 AND s.fuel_l=216622 AND s.fuel_density_kg_per_l=.785
 AND ABS(s.fuel_l*s.fuel_density_kg_per_l-170048)<1
 AND t.maximum_landing_weight_kg=s.mlw_kg
 AND a.source_scope='EXACT_SELECTED_WEIGHT_VARIANT'
 AND a.original_manufacturer_mtow_kg=372000
 AND a.original_manufacturer_mlw_kg=243000
 AND ic.official_icao_chapter=14
 AND ic.certified_mtow_kg=372000
 AND ic.noise_certificate_status='CERTIFICATE_CONFIGURATION_MATCHED'
 AND NOT ic.airframe_registration_specific;
 IF n<>1 THEN RAISE EXCEPTION 'A340-541 WV102 Airbus weights/fuel + EASA A5929 Chapter14 mismatch'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3 g
 JOIN airlinerra.aircraft_expansion_group3_planning_seed s USING(entry_no)
 JOIN airlinerra.aircraft_expansion_group3_performance_noise_audit_v1 a USING(entry_no)
 JOIN airlinerra_game.section5_aircraft_representative_noise_baseline_v1 no ON no.configuration_id=g.configuration_id
 WHERE g.entry_no=3 AND s.mtow_kg=16700 AND s.mlw_kg=16400 AND s.mzfw_kg=15200
 AND s.oew_kg=10900 AND s.burn_kg_h=568 AND s.cargo_kg=2100
 AND a.published_takeoff_field_length_m=1090 AND a.published_landing_field_length_m=887
 AND a.published_cruise_fuel_kg_per_hour=568
 AND a.official_noise_chapter_in_related_reference=14
 AND no.game_chapter_assumption=14 AND no.official_icao_chapter IS NULL
 AND NOT no.real_world_noise_operational_permission;
 IF n<>1 THEN RAISE EXCEPTION 'ATR42-300 donor spec or combi-only noise scope invalid'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3 g
 JOIN airlinerra.aircraft_expansion_group3_planning_seed s USING(entry_no)
 JOIN airlinerra.aircraft_expansion_group3_performance_noise_audit_v1 a USING(entry_no)
 JOIN airlinerra_game.section5_aircraft_representative_noise_baseline_v1 no ON no.configuration_id=g.configuration_id
 WHERE g.entry_no=4 AND s.mtow_kg=16700 AND s.mlw_kg=16400 AND s.mzfw_kg=15200
 AND s.oew_kg=10900 AND s.burn_kg_h=584
 AND a.published_takeoff_field_length_m=1041 AND a.published_landing_field_length_m=887
 AND a.published_cruise_fuel_kg_per_hour=584
 AND no.game_chapter_assumption=14 AND no.official_icao_chapter IS NULL;
 IF n<>1 THEN RAISE EXCEPTION 'ATR42-320 PW121 donor performance and acoustics missing'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_unified_game_data_v1 u
 JOIN airlinerra.aircraft_expansion_group3_performance_noise_audit_v1 a USING(entry_no)
 WHERE u.entry_no=20 AND u.advertised_or_estimated_max_cargo_kg=118000
 AND a.published_range_km=9260 AND a.published_range_payload_kg=110000
 AND u.conservative_reference_payload_game_range_km<9260
 AND u.nominal_range_derated_for_payload_and_fuel;
 IF n<>1 THEN RAISE EXCEPTION 'Boeing 777-8F 9260km @110t confused with 118t structural max'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_unified_game_data_v1 u
 JOIN airlinerra.aircraft_expansion_group3_planning_seed s USING(entry_no)
 JOIN airlinerra.aircraft_expansion_group3_performance_noise_audit_v1 a USING(entry_no)
 WHERE u.entry_no=21 AND s.mtow_kg=21523 AND s.fuel_l=5300
 AND s.fuel_density_kg_per_l=.8028
 AND ABS(u.game_usable_fuel_kg-4254.84)<.001
 AND a.published_usable_fuel_mass_kg=4254.84;
 IF n<>1 THEN RAISE EXCEPTION 'Bombardier CRJ100 not differentiated from 8082L CRJ100ER'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_performance_noise_audit_v1 a
 JOIN airlinerra.aircraft_expansion_group3 g USING(entry_no)
 WHERE g.entry_no=25 AND a.original_manufacturer_mtow_kg=15660
 AND a.original_manufacturer_mlw_kg=15160 AND a.original_manufacturer_mzfw_kg=14350
 AND a.original_reference_oew_kg=10150 AND a.published_usable_fuel_mass_kg=3615
 AND a.published_takeoff_field_length_m=1082 AND a.published_landing_field_length_m=965
 AND a.published_cruise_fuel_kg_per_hour=480
 AND a.published_range_km=1213
 AND a.official_noise_chapter_in_related_reference IS NULL;
 IF n<>1 THEN RAISE EXCEPTION 'D328eco OEM future model performance or uncertified noise not preserved'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_performance_noise_audit_v1 a
 WHERE entry_no IN(23,24) AND source_scope='OEM_DONOR_AIRFRAME_NOT_CONVERSION'
 AND a.original_manufacturer_mtow_kg=29574 AND a.original_manufacturer_mlw_kg=28123
 AND a.published_usable_fuel_mass_kg=5318 AND a.published_takeoff_field_length_m=1277
 AND a.published_landing_field_length_m=1268
 AND a.noise_match_scope='MANUFACTURER_BASE_MODEL_ONLY';
 IF n<>2 THEN RAISE EXCEPTION 'Both Dash8-400 cargo versions must preserve passenger donor vs conversion provenance'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_unified_game_data_v1
 WHERE nominal_range_derated_for_payload_and_fuel;
 IF n<>15 THEN RAISE EXCEPTION 'Expected 15 conservative full reference-load planning range reductions, found %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.section5_group3_airport_aircraft_readiness_v1;
 IF n<>122499 THEN RAISE EXCEPTION 'Expected 39 aircraft x3141 airport screens, found %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.section5_group3_airport_aircraft_readiness_v1
 WHERE world_id IS NOT NULL AND airport_key IS NOT NULL AND game_chapter_with_cert_candidate IS NOT NULL
 AND no_real_world_dispatch_certification AND NOT real_world_operating_clearance
 AND NOT game_ordering_enabled AND NOT game_flight_operations_enabled
 AND NOT game_release_automatically_authorized AND NOT real_world_airport_and_aircraft_dispatch_approved;
 IF n<>122499 THEN RAISE EXCEPTION 'Group3 airport grid contains an uncertified/unguarded row, safe=%',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.section5_group3_airport_aircraft_readiness_v1
 WHERE documented_type_configuration_icao_chapter=14 AND entry_no=1;
 IF n<>3141 THEN RAISE EXCEPTION 'Exact A340-541 type noise reference not joined to all airport research screens'; END IF;
 SELECT COUNT(*) INTO n FROM airlinerra_game.section5_group3_airport_aircraft_readiness_v1
 WHERE entry_no<>1 AND documented_type_configuration_icao_chapter IS NOT NULL;
 IF n<>0 THEN RAISE EXCEPTION 'A combi, conversion or future aircraft falsely assigned exact noise certificate'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.section5_full_weight_airport_aircraft_screen_v2 s
 JOIN airlinerra.aircraft_expansion_group3 g USING(configuration_id)
 JOIN airlinerra.aircraft_expansion_group3_planning_seed src USING(entry_no)
 WHERE s.aircraft_mtow_kg IS DISTINCT FROM src.mtow_kg
 OR s.aircraft_mlw_kg IS DISTINCT FROM src.mlw_kg
 OR s.full_weight_takeoff_required_m IS DISTINCT FROM CEIL(s.base_full_weight_takeoff_m*s.elevation_factor)
 OR s.full_weight_landing_required_m IS DISTINCT FROM CEIL(s.base_full_weight_landing_m*s.elevation_factor)
 OR NOT s.no_real_world_dispatch_certification;
 IF n<>0 THEN RAISE EXCEPTION 'Full-weight runway screening mismatches against source for % airport pairs',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_release_gate_v1
 WHERE game_aircraft_orderable OR game_flight_operations_enabled OR automatically_released;
 IF n<>0 THEN RAISE EXCEPTION 'No Group3 aircraft may be auto-released during research'; END IF;
END $g3perf$;
SELECT 'GROUP3_39_NOISE_FUEL_RUNWAY_RANGE_AUDIT_PASSED' AS result;
