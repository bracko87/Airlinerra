
-- Airlinerra Group 3: cargo + combi research planning tests.
-- All profiles remain private and never unlock purchase, leasing or dispatch.
DO $verify$
DECLARE n bigint; actual text; permitted boolean;
BEGIN
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3;
 IF n<>39 THEN RAISE EXCEPTION 'Expected 39 Group3 configs, found %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_loading_layout_v1;
 IF n<>41 THEN RAISE EXCEPTION 'Expected 41 distinct physical layout choices, found %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_loading_layout_v1 WHERE layout_code='COMBI';
 IF n<>8 THEN RAISE EXCEPTION 'Expected 8 combi layouts, found %',n; END IF;
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_loading_layout_v1 WHERE layout_code='CARGO';
 IF n<>9 THEN RAISE EXCEPTION 'Expected 9 cargo-mode layouts including 737-700C, found %',n; END IF;
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_loading_layout_v1 WHERE layout_code='PASSENGER';
 IF n<>24 THEN RAISE EXCEPTION 'Expected 24 passenger-mode layouts including 737-700C, found %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_loading_readiness_v1
 WHERE expected_layout_count_complete
 AND all_layout_maxima_within_estimated_mzfw
 AND all_layouts_within_catalog_caps
 AND model_cargo_cap_within_estimated_structural_margin;
 IF n<>39 THEN RAISE EXCEPTION 'Complete role-specific physical model for only % of 39 aircraft',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_unified_game_data_v1
 WHERE cargo_catalog_exceeds_structural_approximation OR reference_payload_derated;
 IF n<>0 THEN RAISE EXCEPTION 'There are % unbounded Group3 model cargo payload limits',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_cargo_reconciliation_v1;
 IF n<>3 THEN RAISE EXCEPTION 'Expect 3 preserved original/published payload audits, found %',n; END IF;
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_cargo_reconciliation_v1
 WHERE reconciliation_basis='GAME_SAFETY_CAP_PENDING_CONVERSION_WEIGHT_EVIDENCE';
 IF n<>2 THEN RAISE EXCEPTION 'Exactly 2 cargo conversion models still require tail-specific evidence'; END IF;
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_cargo_reconciliation_v1
 WHERE entry_no=33 AND original_catalog_cargo_kg=78000 AND source_published_payload_kg=74843
 AND audited_mzfw_kg=181892 AND audited_oew_kg=107049
 AND reconciled_capacity_kg=74843 AND reconciliation_basis='OPERATOR_MATCHED_MZFW_OEW';
 IF n<>1 THEN RAISE EXCEPTION 'DHL DC10-30F payload evidence not reconciled'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_planning_seed
 WHERE entry_no=9 AND mtow_kg=70080 AND mlw_kg=58604
 AND mzfw_kg=55202 AND oew_kg=37648 AND fuel_l=26024 AND cargo_kg=15876;
 IF n<>1 THEN RAISE EXCEPTION '737-700C Boeing ACAP weights/fuel baseline missing'; END IF;
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_planning_seed
 WHERE entry_no=5 AND seats=44 AND max_seats=44 AND cargo_kg=3000;
 IF n<>1 THEN RAISE EXCEPTION 'ATR72-600 Combi OEM 44-seat model missing'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_loading_layout_v1
 WHERE entry_no=9 AND
 ((layout_code='PASSENGER' AND maximum_passengers=121 AND maximum_freight_kg=0)
 OR (layout_code='CARGO' AND maximum_passengers=0 AND maximum_freight_kg=15876)
 OR (layout_code='COMBI' AND maximum_passengers=70 AND maximum_freight_kg=6804));
 IF n<>3 THEN RAISE EXCEPTION '737-700C Boeing C-40 layout categories incorrect'; END IF;
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_loading_layout_v1
 WHERE entry_no=4 AND layout_code='COMBI' AND maximum_passengers=22 AND maximum_freight_kg=2100;
 IF n<>1 THEN RAISE EXCEPTION 'ATR42-320 full mixed-load capped capacity incorrect'; END IF;
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_loading_layout_v1
 WHERE entry_no=24 AND layout_code='COMBI' AND maximum_passengers=68 AND maximum_freight_kg=2600;
 IF n<>1 THEN RAISE EXCEPTION 'Dash8-400 CC published 68 passenger / 2.6t layout missing'; END IF;

 -- Exhaustive planning-only positive sample: full capacity of every research layout at 100km
 -- with 10% reserve and fixed time allowance. Not a certified flight.
 SELECT COUNT(*) INTO n
 FROM airlinerra.aircraft_expansion_group3_loading_layout_v1 l
 JOIN airlinerra.aircraft_expansion_group3 g USING(entry_no)
 JOIN airlinerra.aircraft_expansion_group3_planning_seed s USING(entry_no)
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,l.layout_code,l.maximum_passengers,
 l.maximum_freight_kg,l.maximum_freight_volume_m3,
 CEIL((0.25::numeric+100::numeric/s.cruise_kmh)*s.burn_kg_h*1.10)+1,100
 ) chk
 WHERE chk.planning_load_allowed AND NOT chk.live_game_dispatch_approved;
 IF n<>41 THEN RAISE EXCEPTION 'Only %/41 max-layout 100km samples are planning consistent',n; END IF;

 -- 737-700C: 70 passengers plus 6804kg in the real C-40 military-derivative COMBI proxy.
 SELECT chk.planning_load_allowed INTO permitted
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'COMBI',70,6804,35,4000,1000) chk
 WHERE g.entry_no=9;
 IF permitted IS DISTINCT FROM TRUE THEN RAISE EXCEPTION '737-700C bounded combi scenario incorrectly denied'; END IF;

 -- 121 passengers cannot also carry cargo from a different 737-700C layout.
 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'PASSENGER',121,6804,35,4000,1000) chk WHERE g.entry_no=9;
 IF actual IS DISTINCT FROM 'CARGO_WEIGHT_EXCEEDS_SELECTED_LAYOUT'
 THEN RAISE EXCEPTION '737-700C incorrectly allows 121 seats + combi freight: %',actual; END IF;

 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'COMBI',71,6804,35,4000,1000) chk WHERE g.entry_no=9;
 IF actual IS DISTINCT FROM 'PASSENGER_COUNT_EXCEEDS_SELECTED_LAYOUT'
 THEN RAISE EXCEPTION '737-700C incorrectly allows 71-combi-passenger count: %',actual; END IF;

 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'COMBI',70,6805,35,4000,1000) chk WHERE g.entry_no=9;
 IF actual IS DISTINCT FROM 'CARGO_WEIGHT_EXCEEDS_SELECTED_LAYOUT'
 THEN RAISE EXCEPTION '737-700C incorrectly allows overweight combi freight: %',actual; END IF;

 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'CARGO',1,1000,5,4000,1000) chk WHERE g.entry_no=9;
 IF actual IS DISTINCT FROM 'PASSENGER_COUNT_EXCEEDS_SELECTED_LAYOUT'
 THEN RAISE EXCEPTION '737-700C cargo-only layout admits passengers: %',actual; END IF;

 -- ATR 42-320: 22 pax + 2200kg would exceed fixed combined payload envelope.
 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'COMBI',22,2200,18,1500,150) chk WHERE g.entry_no=4;
 IF actual IS DISTINCT FROM 'CARGO_WEIGHT_EXCEEDS_SELECTED_LAYOUT'
 THEN RAISE EXCEPTION 'ATR42-320 physical combi cap not enforced: %',actual; END IF;

 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'COMBI',45,2000,18,1500,150) chk WHERE g.entry_no=5;
 IF actual IS DISTINCT FROM 'PASSENGER_COUNT_EXCEEDS_SELECTED_LAYOUT'
 THEN RAISE EXCEPTION 'ATR72-600 Combi 44-seat cap not enforced: %',actual; END IF;

 -- 737-200F and E195F: published/original higher freight values remain evidence only.
 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'CARGO',0,14500,105,3500,500) chk WHERE g.entry_no=8;
 IF actual IS DISTINCT FROM 'CARGO_WEIGHT_EXCEEDS_SELECTED_LAYOUT'
 THEN RAISE EXCEPTION '737-200F game gross-load cap bypassed: %',actual; END IF;

 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'CARGO',0,14300,118,2000,200) chk WHERE g.entry_no=27;
 IF actual IS DISTINCT FROM 'CARGO_WEIGHT_EXCEEDS_SELECTED_LAYOUT'
 THEN RAISE EXCEPTION 'E195F game gross-load cap bypassed: %',actual; END IF;

 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'CARGO',0,78000,400,40000,2500) chk WHERE g.entry_no=33;
 IF actual IS DISTINCT FROM 'CARGO_WEIGHT_EXCEEDS_SELECTED_LAYOUT'
 THEN RAISE EXCEPTION 'DHL DC10-30F 74843kg max not enforced: %',actual; END IF;

 -- No positive mass without volume, or positive volume without mass.
 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'COMBI',70,6804,0,4000,1000) chk WHERE g.entry_no=9;
 IF actual IS DISTINCT FROM 'CARGO_VOLUME_REQUIRED_FOR_NONZERO_WEIGHT'
 THEN RAISE EXCEPTION 'Nonzero freight without stated volume incorrectly allowed: %',actual; END IF;

 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'COMBI',70,0,15,4000,1000) chk WHERE g.entry_no=9;
 IF actual IS DISTINCT FROM 'CARGO_WEIGHT_REQUIRED_FOR_NONZERO_VOLUME'
 THEN RAISE EXCEPTION 'Positive cargo volume without a reported mass incorrectly allowed: %',actual; END IF;

 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'COMBI',70,6804,50,4000,1000) chk WHERE g.entry_no=9;
 IF actual IS DISTINCT FROM 'CARGO_VOLUME_EXCEEDS_SELECTED_LAYOUT'
 THEN RAISE EXCEPTION '737-700C mode cargo volume cap bypassed: %',actual; END IF;

 -- Fuel and MTOW / MLW negative tests.
 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'PASSENGER',121,0,0,20819,100) chk WHERE g.entry_no=9;
 IF actual IS DISTINCT FROM 'MTOW_LIMIT_EXCEEDED'
 THEN RAISE EXCEPTION '737-700C game takeoff mass cap bypassed: %',actual; END IF;

 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'CARGO',0,15000,100,11000,100) chk WHERE g.entry_no=9;
 IF actual IS DISTINCT FROM 'MLW_LIMIT_EXCEEDED'
 THEN RAISE EXCEPTION '737-700C landing mass cap bypassed: %',actual; END IF;

 SELECT chk.blocking_reason INTO actual
 FROM airlinerra.aircraft_expansion_group3 g
 CROSS JOIN LATERAL airlinerra.aircraft_expansion_group3_check_loading_v1(
 g.configuration_id,'COMBI',70,6804,35,1000,1000) chk WHERE g.entry_no=9;
 IF actual IS DISTINCT FROM 'INSUFFICIENT_FUEL_WITH_MODEL_RESERVE'
 THEN RAISE EXCEPTION 'Group3 route model fuel reserve check bypassed: %',actual; END IF;

 -- All aircraft still locked, including future and unlaunched Dash8-400 CC.
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_release_gate_v1
 WHERE game_aircraft_orderable OR game_flight_operations_enabled OR automatically_released;
 IF n<>0 THEN RAISE EXCEPTION 'Unintended Group3 aircraft purchasing or dispatch release: %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_loading_layout_v1
 WHERE NOT planning_only OR game_maximums_simultaneously_certified;
 IF n<>0 THEN RAISE EXCEPTION 'Some layouts falsely marked certified or live'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_loading_readiness_v1
 WHERE flight_dispatch_unlocked OR aircraft_sale_unlocked;
 IF n<>0 THEN RAISE EXCEPTION 'Group3 cargo/combi research accidentally unlocked in game'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.section5_full_weight_airport_aircraft_screen_v2 r
 JOIN airlinerra.aircraft_expansion_group3 g USING(configuration_id)
 JOIN airlinerra.aircraft_expansion_group3_planning_seed s USING(entry_no)
 WHERE r.aircraft_mlw_kg IS DISTINCT FROM s.mlw_kg
 OR r.aircraft_mtow_kg IS DISTINCT FROM s.mtow_kg
 OR NOT r.no_real_world_dispatch_certification;
 IF n<>0 THEN RAISE EXCEPTION 'Airport runway screen weights or release out of sync on % rows',n; END IF;
END $verify$;
SELECT 'GROUP3_39_CARGO_COMBI_LOADING_RESEARCH_TESTS_PASSED' AS result;
