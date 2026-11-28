-- Owner-scoped storage overview acceptance; uses the existing synthetic stored aircraft.
SAVEPOINT storage_overview;
DO $test$
DECLARE s record; owner_id uuid; j jsonb; denied boolean:=false;
BEGIN
 SELECT * INTO STRICT s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
 SELECT owner_player_id INTO STRICT owner_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=s.request_id;
 PERFORM set_config('test.storage_hour',s.storage_started_utc::text,true);
 j:=airlinerra_game.owned_aircraft_storage_overview_v1(owner_id,s.airline_id,s.aircraft_inventory_id);
 IF j->>'status' IS DISTINCT FROM 'storage_overview_verified'
 OR j->>'aircraftId' IS DISTINCT FROM s.aircraft_inventory_id::text
 OR j->>'airlineId' IS DISTINCT FROM s.airline_id::text
 OR j->>'fleetStatus' IS DISTINCT FROM 'stored'
 OR j#>>'{session,airportKey}' IS DISTINCT FROM s.airport_key
 OR (j#>>'{session,monthlyUsd}')::numeric IS DISTINCT FROM 5000::numeric
 OR j->>'readOnly' IS DISTINCT FROM 'true' OR j->>'actionsReleased' IS DISTINCT FROM 'false'
 OR j->>'storageCapacityUnlimited' IS DISTINCT FROM 'true'
 THEN RAISE EXCEPTION 'storage overview incorrect: %',j;END IF;
 BEGIN
  PERFORM airlinerra_game.owned_aircraft_storage_overview_v1(gen_random_uuid(),s.airline_id,s.aircraft_inventory_id);
 EXCEPTION WHEN insufficient_privilege THEN denied:=true;
 END;
 IF NOT denied THEN RAISE EXCEPTION 'cross-owner storage disclosure';END IF;
 IF has_function_privilege('authenticated','airlinerra_game.owned_aircraft_storage_overview_v1(uuid,uuid,uuid)','EXECUTE')
 OR has_function_privilege('anon','airlinerra_game.owned_aircraft_storage_overview_v1(uuid,uuid,uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'storage read model exposed directly';END IF;
 RAISE NOTICE 'Storage owner overview acceptance passed';
END $test$;
ROLLBACK TO SAVEPOINT storage_overview;
