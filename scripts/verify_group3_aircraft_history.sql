-- Airlinerra Group 3 historical timeline and research market-year validation.
-- READ ONLY assertions. Even a matching calendar year does NOT authorize purchases,
-- production, used-market availability, aircraft delivery or operational permission.
DO $history$
DECLARE n bigint;
BEGIN
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_production_history;
 IF n<>39 THEN RAISE EXCEPTION 'Expected 39 Group 3 production-history entries, found %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_history_availability_v1;
 IF n<>39 THEN RAISE EXCEPTION 'Expected 39 historical-availability view rows, found %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_production_history
 WHERE primary_source_url IS NULL
 OR chronology_evidence_class IS NULL
 OR game_market_year_basis IS NULL
 OR history_scope IS NULL
 OR lifecycle_status IS NULL;
 IF n<>0 THEN RAISE EXCEPTION 'Missing Group 3 researched production history provenance on % entries',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_production_history
 WHERE production_start_year IS NOT NULL
 AND production_end_year IS NOT NULL AND production_end_year < production_start_year;
 IF n<>0 THEN RAISE EXCEPTION 'Invalid Group 3 manufacturing date order on % entries',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_production_history
 WHERE first_game_market_year_estimate IS NOT NULL
 AND last_game_new_build_year_estimate IS NOT NULL
 AND last_game_new_build_year_estimate < first_game_market_year_estimate;
 IF n<>0 THEN RAISE EXCEPTION 'Invalid Group 3 game market-year order on % entries',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3
 WHERE availability_intent='visible_not_orderable' AND entry_no IN(2,20,25);
 IF n<>3 THEN RAISE EXCEPTION 'A350-1000ULR, 777-8F, D328eco must remain display-only future'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_history_availability_v1
 WHERE future_or_unlaunched_locked AND entry_no IN(2,20,24,25);
 IF n<>4 THEN RAISE EXCEPTION 'Future / unlaunched model locks are incomplete'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_production_history
 WHERE entry_no=2 AND model_first_flight_year=2026
 AND first_documented_delivery_year IS NULL AND first_game_market_year_estimate=2027
 AND NOT first_customer_delivery_confirmed;
 IF n<>1 THEN RAISE EXCEPTION 'Airbus A350-1000ULR real 2026 flight vs scheduled 2027 delivery incorrect'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_production_history
 WHERE entry_no=20 AND first_documented_delivery_year IS NULL
 AND first_game_market_year_estimate=2029
 AND lifecycle_status='future_not_delivered';
 IF n<>1 THEN RAISE EXCEPTION 'Boeing 777-8F projected not-delivered 2029 planning baseline incorrect'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_production_history
 WHERE entry_no=25 AND model_first_flight_year IS NULL
 AND first_documented_delivery_year IS NULL
 AND first_game_market_year_estimate=2029
 AND lifecycle_status='future_not_delivered';
 IF n<>1 THEN RAISE EXCEPTION 'Deutsche Aircraft D328eco 2029 forecast / no actual first flight incorrect'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_production_history
 WHERE entry_no=19 AND first_documented_service_year=2025
 AND donor_airframe_production_start_year=2004
 AND history_scope='conversion';
 IF n<>1 THEN RAISE EXCEPTION 'IAI 777-300ERSF 2025 service must not be treated as donor build date'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_production_history
 WHERE entry_no=24 AND first_game_market_year_estimate IS NULL
 AND first_documented_delivery_year IS NULL AND history_scope='unlaunched_option';
 IF n<>1 THEN RAISE EXCEPTION 'Dash 8-400 CC has unlaunched certified retrofit and must remain blocked'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_production_history
 WHERE entry_no=27 AND first_game_market_year_estimate IS NULL
 AND first_documented_delivery_year IS NULL AND history_scope='conversion';
 IF n<>1 THEN RAISE EXCEPTION 'Do not infer Embraer E195F delivery from distinct E190F certification'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_production_history
 WHERE entry_no=35 AND first_documented_delivery_year=1991
 AND production_start_year=1991 AND production_end_year=1992
 AND history_scope='model_variant';
 IF n<>1 THEN RAISE EXCEPTION 'MD-11C must be distinct from MD-11 or MD-11CF'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_research_check_year_v1(2000);
 IF n<>39 THEN RAISE EXCEPTION 'Year-dependent research view 2000 missing models'; END IF;
 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_research_check_year_v1(2030);
 IF n<>39 THEN RAISE EXCEPTION 'Year-dependent research view 2030 missing models'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_history_availability_v1
 WHERE new_aircraft_purchasing_enabled OR historical_fleet_spawn_enabled
 OR future_preorder_enabled OR operations_release_approved;
 IF n<>0 THEN RAISE EXCEPTION 'Research-only history must not activate any aircraft'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_research_check_year_v1(2000)
 WHERE can_purchase_in_game OR can_preorder_in_game;
 IF n<>0 THEN RAISE EXCEPTION 'Game year 2000 check unexpectedly unlocks aircraft'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_research_check_year_v1(2030)
 WHERE can_purchase_in_game OR can_preorder_in_game;
 IF n<>0 THEN RAISE EXCEPTION 'Game year 2030 check unexpectedly unlocks aircraft'; END IF;
END
$history$;
SELECT 'GROUP3_39_HISTORY_AND_AVAILABILITY_TESTS_PASSED' AS result;