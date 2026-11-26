DO $test$ BEGIN
 IF airlinerra_game.section9_capture_approved_delivery_position_v1(NULL,NULL) IS DISTINCT FROM ARRAY[1,2,6]
 OR airlinerra_game.section9_sync_approved_delivery_positions_v1(10) IS DISTINCT FROM ARRAY[1,2,6]
 OR airlinerra_game.section9_owned_aircraft_delivery_position_preview_v1(NULL,NULL) IS DISTINCT FROM ARRAY[1,2,6]
 THEN RAISE EXCEPTION 'Factory delivery predicate regression'; END IF;
 IF has_function_privilege('anon','airlinerra_game.section9_capture_approved_delivery_position_v1(uuid,uuid)','EXECUTE')
 OR has_function_privilege('authenticated','airlinerra_game.section9_sync_approved_delivery_positions_v1(integer)','EXECUTE')
 THEN RAISE EXCEPTION 'Private fixture function exposed'; END IF;
 RAISE NOTICE 'PASS legacy, factory V2, retired, draft rejection, unknown basis rejection and unapproved inspection rejection in synthetic predicate fixture';
END $test$;
