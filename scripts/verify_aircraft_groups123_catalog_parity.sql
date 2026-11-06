-- Airlinerra Group 1 / 2 / 3 audit. Keep researched eligibility distinct from live release.
-- Owner asks Groups 2 and 3 to match Group 1; this does not invent working player UI.
DO $audit$
DECLARE n bigint;
BEGIN
 SELECT COUNT(*) INTO n FROM airlinerra_game.aircraft_groups123_parity_v1;
 IF n<>272 THEN RAISE EXCEPTION 'Expected 272 group1+group2+group3 configs, got %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.aircraft_groups123_parity_v1 WHERE aircraft_group=1;
 IF n<>186 THEN RAISE EXCEPTION 'Group1 count differs: %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.aircraft_groups123_parity_v1
 WHERE aircraft_group=2 AND core_technical_sections_populated AND catalog_core_fields_populated
 AND model_research_data_assigned AND commercial_service_audit_exists;
 IF n<>47 THEN RAISE EXCEPTION 'Group2 not fully covered on baseline model and service AUDIT slots: % of47',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.aircraft_groups123_parity_v1
 WHERE aircraft_group=3 AND core_technical_sections_populated AND catalog_core_fields_populated
 AND model_research_data_assigned AND commercial_service_audit_exists;
 IF n<>39 THEN RAISE EXCEPTION 'Group3 not fully covered on baseline model and service AUDIT slots: % of39',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group2_commercial_service_audit;
 IF n<>47 THEN RAISE EXCEPTION 'Group2 commercial service audit incomplete'; END IF;
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_commercial_service_audit;
 IF n<>39 THEN RAISE EXCEPTION 'Group3 commercial service audit incomplete'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group2_commercial_service_audit
 WHERE exact_role_verified AND evidence_source_url IS NOT NULL;
 IF n<30 THEN RAISE EXCEPTION 'Group2 role-specific evidence unexpectedly regressed: %',n; END IF;
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_commercial_service_audit
 WHERE exact_role_verified AND evidence_source_url IS NOT NULL;
 IF n<30 THEN RAISE EXCEPTION 'Group3 role-specific historic/commercial service evidence unexpectedly regressed: %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_commercial_service_audit
 WHERE verified_2026_current AND service_assessment='confirmed_current_2026'
 AND exact_role_verified AND evidence_source_url IS NOT NULL;
 IF n<1 THEN RAISE EXCEPTION 'IAI B777-300ERSF verified 2026 operator service missing'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_commercial_service_audit
 WHERE entry_no=5 AND exact_role_verified AND verified_2026_current=false
 AND operator_name LIKE 'PNG Air%';
 IF n<>1 THEN RAISE EXCEPTION 'ATR72-600 actual historical COMBI operator missing'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_production_history
 WHERE entry_no=5 AND first_documented_delivery_year=2015
 AND first_documented_service_year=2015 AND first_customer_delivery_confirmed=true;
 IF n<>1 THEN RAISE EXCEPTION 'Actual 2015 PNG Air combi customer delivery/service missing'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group2
 WHERE availability_intent IN('advance_order_requested','visible_not_orderable');
 IF n<>7 THEN RAISE EXCEPTION 'Group2 future aircraft options changed without review: %',n; END IF;
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3
 WHERE availability_intent='visible_not_orderable' AND entry_no IN(2,20,25);
 IF n<>3 THEN RAISE EXCEPTION '3 Group3 undispatched future program flags missing'; END IF;
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_commercial_service_audit
 WHERE entry_no IN(2,20,24,25) AND service_assessment='future_not_in_service'
 AND NOT verified_2026_current;
 IF n<>4 THEN RAISE EXCEPTION 'Unlaunched/future program status not verified for all 4'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group2_release_gate_v1
 WHERE ordering_enabled OR operations_enabled OR auto_release_granted;
 IF n<>0 THEN RAISE EXCEPTION 'Group2 falsely unlocked before owner-approved game release'; END IF;
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_release_gate_v1
 WHERE game_aircraft_orderable OR game_flight_operations_enabled OR automatically_released;
 IF n<>0 THEN RAISE EXCEPTION 'Group3 falsely unlocked before owner-approved game release'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.aircraft_groups123_parity_v1
 WHERE aircraft_group=2 AND exact_configuration_image_approved;
 IF n<>47 THEN RAISE EXCEPTION 'Group2 approved configuration artwork unexpectedly missing: %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.aircraft_groups123_parity_v1
 WHERE aircraft_group=3 AND evidence_supports_requested_historical_role
 AND catalog_status NOT IN('service_verified','technical_verified','released');
 IF n<>0 THEN RAISE EXCEPTION 'Some Group3 role-verified models remain unpromoted from basic research: %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.aircraft_groups123_parity_v1
 WHERE aircraft_group=2 AND evidence_supports_requested_historical_role
 AND catalog_status NOT IN('service_verified','technical_verified','released');
 IF n<>0 THEN RAISE EXCEPTION 'Some Group2 role-verified models remain unpromoted from basic research: %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.aircraft_groups123_parity_v1
 WHERE fuel_gameplay_enabled OR platform_released;
 IF n<>0 THEN RAISE EXCEPTION 'Project was unexpectedly published or fuel enabled without game rollout'; END IF;
END $audit$;
SELECT 'GROUP123_272_CATALOG_PARITY_NO_FALSE_RELEASE_TESTS_PASSED' AS result;
