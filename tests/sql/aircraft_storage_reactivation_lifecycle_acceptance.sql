-- Synthetic signed movements and receipts only; rollback to savepoint after test.
SAVEPOINT outbound_lifecycle;
CREATE TABLE airlinerra_game.section9_game_flight_fuel_departure_receipts_v1(physical_flight_id text PRIMARY KEY,airline_id uuid,aircraft_inventory_id uuid,departure_engine_event_id text,planned_trip_burn_kg numeric);
DO $outbound$
DECLARE s record; r record; owner_id uuid; j jsonb; rid uuid; dep timestamptz; physical text; phase text; eid text; signature text; event_time timestamptz; cash_before numeric; cash_after_hold numeric;
BEGIN
 SELECT * INTO s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
 SELECT owner_player_id INTO owner_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=s.request_id;
 PERFORM set_config('test.storage_hour',s.storage_started_utc::text,true);
 dep:=date_trunc('second',s.storage_started_utc+interval '2 minutes');
 j:=airlinerra_game.post_aircraft_storage_month_v1(s.airline_id,s.request_id,1);
 IF j->>'status' IS DISTINCT FROM 'paid' THEN RAISE EXCEPTION 'outbound fixture payment: %',j;END IF;
 SELECT cash_usd INTO cash_before FROM airlinerra_game.airlines WHERE id=s.airline_id;
 j:=airlinerra_game.request_aircraft_storage_reactivation_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'OURAIRPORTS:999',dep,2688.13,gen_random_uuid());
 IF j->>'created' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'outbound fixture request: %',j;END IF;
 rid:=(j->>'requestId')::uuid;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=rid;
 j:=airlinerra_game.reserve_aircraft_reactivation_slots_v1(owner_id,s.airline_id,rid);
 IF j->>'slotsReserved' IS DISTINCT FROM '2' THEN RAISE EXCEPTION 'outbound fixture slots: %',j;END IF;
 j:=airlinerra_game.hold_aircraft_reactivation_funds_v1(owner_id,s.airline_id,rid);
 IF j->>'fundsHeld' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'outbound fixture funds: %',j;END IF;
 cash_after_hold:=cash_before-r.quoted_cost_usd;
 physical:=rid::text||':'||(dep AT TIME ZONE 'UTC')::date::text||':1';
 PERFORM set_config('test.storage_hour',dep::text,true);
 eid:='storage-v1:'||physical||':departed';
 signature:=encode(extensions.hmac(convert_to(airlinerra_game.aircraft_storage_event_signing_payload_v1(physical,'departed'),'UTF8'),convert_to(repeat('a',64),'UTF8'),'sha256'),'hex');
 BEGIN
 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,storage_request_id,storage_reactivation,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc)
 VALUES(1,eid,signature,r.airline_id,r.aircraft_inventory_id,rid,true,1,1,(dep AT TIME ZONE 'UTC')::date,physical,'departed',r.origin_airport_key,r.destination_airport_key,dep,r.arrival_utc,dep);
 RAISE EXCEPTION 'disabled outbound gate accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'REACTIVATION_NOT_RELEASED' THEN RAISE;END IF;END;
 UPDATE airlinerra_game.aircraft_storage_reactivation_release_v1 SET enabled=true WHERE world_id=1;
 FOREACH phase IN ARRAY ARRAY['departed','arrived'] LOOP
  event_time:=CASE WHEN phase='departed' THEN dep ELSE r.arrival_utc END;
  PERFORM set_config('test.storage_hour',event_time::text,true);
  eid:='storage-v1:'||physical||':'||phase;
  signature:=encode(extensions.hmac(convert_to(airlinerra_game.aircraft_storage_event_signing_payload_v1(physical,phase),'UTF8'),convert_to(repeat('a',64),'UTF8'),'sha256'),'hex');
  INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,storage_request_id,storage_reactivation,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc)
  VALUES(1,eid,signature,r.airline_id,r.aircraft_inventory_id,rid,true,1,1,(dep AT TIME ZONE 'UTC')::date,physical,phase,r.origin_airport_key,r.destination_airport_key,dep,r.arrival_utc,event_time);
  UPDATE airlinerra_game.section9_aircraft_current_position_v1 SET storage_request_id=rid,storage_reactivation=true,location_status=CASE WHEN phase='departed' THEN 'in_flight' ELSE 'grounded' END,airport_key=CASE WHEN phase='arrived' THEN r.destination_airport_key END,current_flight_occurrence_id=CASE WHEN phase='departed' THEN physical END,last_event_utc=event_time,last_departure_utc=dep,last_arrival_utc=CASE WHEN phase='arrived' THEN event_time ELSE last_arrival_utc END,last_engine_event_id=eid WHERE aircraft_inventory_id=r.aircraft_inventory_id;
  IF phase='departed' THEN
   BEGIN
   PERFORM airlinerra_game.close_storage_at_reactivation_departure_v1(rid);
   RAISE EXCEPTION 'missing departure fuel accepted';
   EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'REACTIVATION_DEPARTURE_FUEL_MISSING' THEN RAISE;END IF;END;
   INSERT INTO airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 VALUES(physical,r.airline_id,r.aircraft_inventory_id,eid,1000);
   j:=airlinerra_game.close_storage_at_reactivation_departure_v1(rid);
   IF j->>'billingStopped' IS DISTINCT FROM 'true' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE request_id=s.request_id AND storage_ended_utc=dep) OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND fleet_status='stored') THEN RAISE EXCEPTION 'storage closure failed: %',j;END IF;
   j:=airlinerra_game.close_storage_at_reactivation_departure_v1(rid);
   IF j->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'closure replay failed';END IF;
   UPDATE airlinerra_game.aircraft_storage_facilities_v1 SET review_state='suspended' WHERE airport_key=r.origin_airport_key;
  ELSE
   INSERT INTO airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 VALUES(physical,r.airline_id,r.aircraft_inventory_id,eid,1000,r.destination_airport_key);
   INSERT INTO airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 VALUES(physical,r.airline_id,r.aircraft_inventory_id,eid,'storage-v1:'||physical||':departed',1,1);
   j:=airlinerra_game.complete_aircraft_reactivation_arrival_v1(rid);
   IF j->>'status' IS DISTINCT FROM 'aircraft_reactivated' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND fleet_status='in_service') THEN RAISE EXCEPTION 'reactivation arrival failed: %',j;END IF;
   j:=airlinerra_game.complete_aircraft_reactivation_arrival_v1(rid);
   IF j->>'replayed' IS DISTINCT FROM 'true' OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=r.airline_id) IS DISTINCT FROM cash_after_hold OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_funds_v1 WHERE request_id=rid AND status='settled') THEN RAISE EXCEPTION 'reactivation expense replay failed';END IF;
  END IF;
 END LOOP;
 RAISE NOTICE 'Outbound signed movement and storage lifecycle acceptance passed';
END $outbound$;
ROLLBACK TO SAVEPOINT outbound_lifecycle;
