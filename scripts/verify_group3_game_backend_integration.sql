-- Airlinerra Group 3 controlled backend integration verification.
-- Research-only market, fleet inventory integrity, loading, airport noise/time/runway gate.
-- This script contains no permanent INSERTs or ownership or fleet modifications.
DO $group3$
DECLARE n bigint; j jsonb; message_text text; v_airline uuid;
v_other bigint; v_group3 bigint; blocked boolean:=false; control_pass boolean:=false;
BEGIN
 SELECT COUNT(*) INTO n FROM airlinerra_game.group3_aircraft_market_catalog_v1
 WHERE complete_planning_card AND NOT player_market_visible
 AND NOT game_new_purchase_enabled AND NOT game_used_purchase_enabled
 AND NOT game_lease_enabled AND NOT game_preorder_enabled
 AND NOT game_flight_assignment_enabled;
 IF n<>39 THEN RAISE EXCEPTION '39 complete but unreleased private Group3 market cards required, found %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.group3_game_integration_status_v1
 WHERE complete_planning_card AND loading_layouts_ready AND loading_weights_valid
 AND private_market_preview_available AND private_loading_preview_available
 AND private_airport_rule_preview_available
 AND NOT live_purchase_or_leasing_activated AND NOT live_airline_fleet_assignment_activated
 AND NOT live_flight_scheduling_activated AND NOT game_release_authorized;
 IF n<>39 THEN RAISE EXCEPTION '39 Group3 backend readiness rows expected, got %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.group3_aircraft_market_catalog_v1
 WHERE approved_exact_image_available;
 IF n<>0 THEN RAISE EXCEPTION 'Group3 images unexpectedly approved; review before changing test baseline'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.group3_market_year_preview_v1(2000)
 WHERE can_purchase OR can_lease OR can_preorder;
 IF n<>0 THEN RAISE EXCEPTION 'Group3 model was purchaseable in research year 2000'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.group3_market_year_preview_v1(2030)
 WHERE can_purchase OR can_lease OR can_preorder;
 IF n<>0 THEN RAISE EXCEPTION 'A future Group3 model was automatically released in 2030'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.group3_market_year_preview_v1(2030)
 WHERE entry_no IN(2,20,24,25) AND future_or_unlaunched;
 IF n<>4 THEN RAISE EXCEPTION 'Future/unlaunched aircraft lock absent: %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.group3_market_year_preview_v1(2030)
 WHERE entry_no IN(24,27) AND first_market_year IS NULL;
 IF n<>2 THEN RAISE EXCEPTION 'Unverified Dash8-400 CC / E195F dates must stay NULL'; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra_game.section5_group3_airport_aircraft_readiness_v1;
 IF n<>122499 THEN RAISE EXCEPTION 'World1 Group3 airport screen must have 39 x 3141 rows, found %',n; END IF;

 SELECT COUNT(*) INTO n FROM airlinerra.aircraft_expansion_group3_loading_layout_v1;
 IF n<>41 THEN RAISE EXCEPTION 'Group3 layout screen must have 41 physically distinct modes'; END IF;

 SELECT airlinerra_game.group3_flight_route_preview_v1(
 1::smallint,'OURAIRPORTS:3176','OURAIRPORTS:2060',
 (SELECT configuration_id FROM airlinerra.aircraft_expansion_group3 WHERE entry_no=9),
 '2026-11-10T10:00:00+00'::timestamptz,'2026-11-10T12:00:00+00'::timestamptz,
 'COMBI',70,6804,35,4000,1000,2026,NULL,NULL) INTO j;
 IF (j->>'researchLoadPass')::boolean IS DISTINCT FROM true
 OR (j->>'gameHardBlocked')::boolean IS DISTINCT FROM true
 OR (j->>'canScheduleNormalFlight')::boolean IS DISTINCT FROM false
 OR j->>'decision'<>'BLOCKED_GROUP3_GAME_RELEASE_PENDING'
 OR j->'airportRulesPreliminaryResult' IS NULL
 THEN RAISE EXCEPTION 'Group3 737-700C valid combi preview / safe hold failure: %',j; END IF;

 SELECT airlinerra_game.group3_flight_route_preview_v1(
 1::smallint,'OURAIRPORTS:3176','OURAIRPORTS:2060',
 (SELECT configuration_id FROM airlinerra.aircraft_expansion_group3 WHERE entry_no=9),
 '2026-11-10T10:00:00+00'::timestamptz,'2026-11-10T12:00:00+00'::timestamptz,
 'PASSENGER',121,6804,35,4000,1000,2026,NULL,NULL) INTO j;
 IF (j->>'researchLoadPass')::boolean IS DISTINCT FROM false
 OR j->>'researchLoadingResult'<>'CARGO_WEIGHT_EXCEEDS_SELECTED_LAYOUT'
 OR (j->>'canScheduleNormalFlight')::boolean IS DISTINCT FROM false
 THEN RAISE EXCEPTION '737-700C illegal mixed passenger/cargo config passed: %',j; END IF;

 SELECT airlinerra_game.group3_flight_route_preview_v1(
 1::smallint,'OURAIRPORTS:3176','OURAIRPORTS:2060',
 (SELECT configuration_id FROM airlinerra.aircraft_expansion_group3 WHERE entry_no=20),
 '2026-11-10T10:00:00+00'::timestamptz,'2026-11-10T12:00:00+00'::timestamptz,
 'CARGO',0,50000,350,20000,1000,2026,NULL,NULL) INTO j;
 IF j->>'yearBasedMarketStatus'<>'FUTURE_OR_UNLAUNCHED_NOT_AVAILABLE'
 OR (j->>'gameHardBlocked')::boolean IS DISTINCT FROM true
 OR (j->>'canScheduleNormalFlight')::boolean IS DISTINCT FROM false
 THEN RAISE EXCEPTION 'Future 777-8F incorrectly enabled in route preview: %',j; END IF;

 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory
 WHERE configuration_id IN(SELECT configuration_id FROM airlinerra.aircraft_expansion_group3))
 THEN RAISE EXCEPTION 'Research-only Group3 model appears in live fleet'; END IF;

 SELECT id INTO v_airline FROM airlinerra_game.airlines ORDER BY created_at LIMIT 1;
 SELECT configuration_id INTO v_group3 FROM airlinerra.aircraft_expansion_group3 WHERE entry_no=9;
 SELECT c.id INTO v_other FROM airlinerra.aircraft_configurations c
 WHERE NOT EXISTS(SELECT 1 FROM airlinerra.aircraft_expansion_group3 g WHERE g.configuration_id=c.id)
 ORDER BY c.id LIMIT 1;
 IF v_airline IS NULL OR v_other IS NULL OR v_group3 IS NULL THEN
 RAISE EXCEPTION 'Fleet integrity test requires one existing airline and Group1/Group3 configurations'; END IF;

 -- Nested exception is a subtransaction. Any test row is rolled back.
 BEGIN
 INSERT INTO airlinerra_game.airline_aircraft_inventory
 (id,airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(gen_random_uuid(),v_airline,v_group3,'TEST-G3-GUARD-ROLLBACK','leased','stored');
 RAISE EXCEPTION 'INTEGRITY_ERROR_GROUP3_FLEET_INSERT_ACCEPTED';
 EXCEPTION WHEN SQLSTATE 'P0001' THEN
 GET STACKED DIAGNOSTICS message_text=MESSAGE_TEXT;
 IF message_text<>'GROUP3_AIRCRAFT_NOT_RELEASED_FOR_FLEET' THEN RAISE; END IF;
 blocked:=true;
 END;
 IF NOT blocked THEN RAISE EXCEPTION 'Group3 fleet integrity guard absent'; END IF;

 BEGIN
 INSERT INTO airlinerra_game.airline_aircraft_inventory
 (id,airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(gen_random_uuid(),v_airline,v_other,'TEST-G1-GUARD-ROLLBACK','owned','stored');
 RAISE EXCEPTION USING ERRCODE='P0042',MESSAGE='EXPECTED_LEGACY_FLEET_TEST_ROLLBACK';
 EXCEPTION WHEN SQLSTATE 'P0042' THEN
 GET STACKED DIAGNOSTICS message_text=MESSAGE_TEXT;
 IF message_text<>'EXPECTED_LEGACY_FLEET_TEST_ROLLBACK' THEN RAISE; END IF;
 control_pass:=true;
 END;
 IF NOT control_pass THEN RAISE EXCEPTION 'Group1/2 fleet guard control failed'; END IF;

 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory WHERE registration
 IN ('TEST-G3-GUARD-ROLLBACK','TEST-G1-GUARD-ROLLBACK'))
 THEN RAISE EXCEPTION 'Verification left temporary aircraft in airline fleet'; END IF;

 IF has_function_privilege('anon',
 'airlinerra_game.group3_flight_route_preview_v1(smallint,text,text,bigint,timestamp with time zone,timestamp with time zone,text,integer,numeric,numeric,numeric,numeric,integer,text,text)','EXECUTE')
 OR has_function_privilege('authenticated',
 'airlinerra_game.group3_flight_route_preview_v1(smallint,text,text,bigint,timestamp with time zone,timestamp with time zone,text,integer,numeric,numeric,numeric,numeric,integer,text,text)','EXECUTE')
 THEN RAISE EXCEPTION 'Group3 unpublished route preview is exposed to public clients'; END IF;

 IF EXISTS(SELECT 1 FROM airlinerra_game.platform_release_gate WHERE enabled=true)
 THEN RAISE EXCEPTION 'Platform was unexpectedly made production-live'; END IF;
END $group3$;
SELECT 'GROUP3_39_GAME_BACKEND_SAFE_INTEGRATION_TESTS_PASSED' AS result;
