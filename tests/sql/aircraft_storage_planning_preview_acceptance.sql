-- Test read-only storage planning with synthetic airport metadata and aircraft.
SAVEPOINT storage_planning;
ALTER TABLE airlinerra.airport_registry ADD COLUMN airport_name text, ADD COLUMN source_gps_code text, ADD COLUMN source_ident text, ADD COLUMN country_iso text;
UPDATE airlinerra.airport_registry SET airport_name=CASE airport_key WHEN 'OURAIRPORTS:316427' THEN 'Teruel' WHEN 'OURAIRPORTS:999' THEN 'Test commercial airport' ELSE airport_key END, source_gps_code=CASE airport_key WHEN 'OURAIRPORTS:316427' THEN 'LETL' WHEN 'OURAIRPORTS:999' THEN 'TEST' ELSE NULL END,country_iso='XX';
DO $test$
DECLARE s record; owner_id uuid; tail uuid:=gen_random_uuid(); j jsonb; dep timestamptz; balance numeric; count_requests bigint; denied boolean:=false;
BEGIN
 SELECT * INTO STRICT s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
 SELECT owner_player_id INTO STRICT owner_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=s.request_id;
 PERFORM set_config('test.storage_hour',s.storage_started_utc::text,true);
 dep:=date_trunc('second',s.storage_started_utc+interval '1 hour');
 SELECT cash_usd INTO balance FROM airlinerra_game.airlines WHERE id=s.airline_id;
 SELECT count(*) INTO count_requests FROM airlinerra_game.aircraft_storage_relocation_requests_v1;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(id,airline_id,configuration_id,ownership_type,fleet_status) VALUES(tail,s.airline_id,1,'owned','in_service');
 j:=airlinerra_game.owned_aircraft_storage_destinations_v1(owner_id,s.airline_id,tail,'storage_inbound','');
 IF j->>'status' IS DISTINCT FROM 'storage_destinations_verified' OR jsonb_array_length(j->'airports')<>1 OR j#>>'{airports,0,airportKey}' IS DISTINCT FROM 'OURAIRPORTS:316427' THEN RAISE EXCEPTION 'inbound facility search incorrect: %',j;END IF;
 j:=airlinerra_game.owned_aircraft_storage_cost_preview_v1(owner_id,s.airline_id,tail,'storage_inbound','OURAIRPORTS:316427',dep);
 IF j->>'status' IS DISTINCT FROM 'storage_cost_preview_verified' OR (j->>'relocationUsd')::numeric IS DISTINCT FROM 2698.13::numeric OR (j->>'monthlyStorageUsd')::numeric IS DISTINCT FROM 5000::numeric OR j->>'bookable' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'inbound quote incorrect: %',j;END IF;
 j:=airlinerra_game.owned_aircraft_storage_destinations_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','');
 IF j->>'searchRequired' IS DISTINCT FROM 'true' OR jsonb_array_length(j->'airports')<>0 THEN RAISE EXCEPTION 'outbound search must be bounded: %',j;END IF;
 j:=airlinerra_game.owned_aircraft_storage_destinations_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','TEST');
 IF j#>>'{airports,0,airportKey}' IS DISTINCT FROM 'OURAIRPORTS:999' THEN RAISE EXCEPTION 'return airport search incorrect: %',j;END IF;
 j:=airlinerra_game.owned_aircraft_storage_cost_preview_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep);
 IF j->>'status' IS DISTINCT FROM 'storage_cost_preview_verified' OR (j->>'relocationUsd')::numeric IS DISTINCT FROM 2688.13::numeric OR j#>>'{billingAtDeparture,status}' IS DISTINCT FROM 'storage_billing_due' THEN RAISE EXCEPTION 'return estimate incorrect: %',j;END IF;
 j:=airlinerra_game.owned_aircraft_storage_cost_preview_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep+interval '8 days');
 IF j->>'status' IS DISTINCT FROM 'storage_departure_unverified' THEN RAISE EXCEPTION 'invalid departure accepted: %',j;END IF;
 BEGIN
 PERFORM airlinerra_game.owned_aircraft_storage_destinations_v1(gen_random_uuid(),s.airline_id,tail,'storage_inbound','');
 EXCEPTION WHEN insufficient_privilege THEN denied:=true;
 END;
 IF NOT denied OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_relocation_requests_v1)<>count_requests OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id) IS DISTINCT FROM balance THEN RAISE EXCEPTION 'preview access or mutation failure';END IF;
 RAISE NOTICE 'Storage airport selection and read-only price preview acceptance passed';
END $test$;
ROLLBACK TO SAVEPOINT storage_planning;
