-- Run after review DDL in its transaction; final rollback is mandatory.
DO $test$
DECLARE a uuid:='00000000-0000-0000-0000-000000000001';p uuid:='00000000-0000-0000-0000-000000000002';f uuid:='00000000-0000-0000-0000-000000000003'; k uuid:=gen_random_uuid(); r uuid; j jsonb; l record; departure timestamptz:=date_trunc('second',clock_timestamp()-interval '4 hours'); physical text; phase text; event_time timestamptz; event_id text; signature text;
BEGIN
 PERFORM set_config('test.storage_hour',(departure-interval '1 hour')::text,true);
 j:=airlinerra_game.request_aircraft_storage_relocation_v1(p,a,f,'OURAIRPORTS:316427',departure,2698.13,k);
 IF j->>'created' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'request fixture failed: %',j;END IF;
 r:=(j->>'requestId')::uuid;
 j:=airlinerra_game.reserve_aircraft_storage_slots_v1(p,a,r);
 IF j->>'slotsReserved' IS DISTINCT FROM '2' THEN RAISE EXCEPTION 'slot fixture failed: %',j;END IF;
 -- First reserve and cancel, verifying the hold is fully returned.
 j:=airlinerra_game.hold_aircraft_storage_funds_v1(p,a,r);
 IF j->>'fundsHeld' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'cancellation hold failed: %',j;END IF;
 j:=airlinerra_game.cancel_aircraft_storage_relocation_request_v1(p,a,r);
 IF j->>'status' IS DISTINCT FROM 'cancelled' OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=a)<>5000000 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_funds_v1 WHERE request_id=r AND status='refunded') THEN RAISE EXCEPTION 'hold refund failed: %',j;END IF;
 j:=airlinerra_game.cancel_aircraft_storage_relocation_request_v1(p,a,r);
 IF j->>'replayed' IS DISTINCT FROM 'true' OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=a)<>5000000 THEN RAISE EXCEPTION 'refund replay failed: %',j;END IF;
 k:=gen_random_uuid();
 j:=airlinerra_game.request_aircraft_storage_relocation_v1(p,a,f,'OURAIRPORTS:316427',departure,2698.13,k);
 IF j->>'created' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'second request failed: %',j;END IF;
 r:=(j->>'requestId')::uuid;
 j:=airlinerra_game.reserve_aircraft_storage_slots_v1(p,a,r);
 IF j->>'slotsReserved' IS DISTINCT FROM '2' THEN RAISE EXCEPTION 'second reservation failed: %',j;END IF;
 physical:=r::text||':'||(departure AT TIME ZONE 'UTC')::date::text||':1';
 SELECT * INTO l FROM airlinerra_game.aircraft_storage_leg_evidence_v1(physical);
 IF NOT FOUND THEN RAISE EXCEPTION 'fixture evidence missing';END IF;
 j:=airlinerra_game.hold_aircraft_storage_funds_v1(p,a,r);
 IF j->>'fundsHeld' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'hold failed: %',j;END IF;
 j:=airlinerra_game.hold_aircraft_storage_funds_v1(p,a,r);
 IF j->>'replayed' IS DISTINCT FROM 'true' OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=a)<>4997301.87 THEN RAISE EXCEPTION 'hold replay incorrect: %',j;END IF;
 PERFORM set_config('test.storage_hour',departure::text,true);
 event_id:='storage-v1:'||physical||':departed';
 signature:=encode(extensions.hmac(convert_to(airlinerra_game.aircraft_storage_event_signing_payload_v1(physical,'departed'),'UTF8'),convert_to(repeat('a',64),'UTF8'),'sha256'),'hex');
 BEGIN
 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,storage_request_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc)
 VALUES(1,event_id,signature,a,f,r,1,1,l.flight_local_date,physical,'departed',l.origin_airport_key,l.destination_airport_key,l.departure_utc,l.arrival_utc,l.departure_utc);
 RAISE EXCEPTION 'disabled gate accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'STORAGE_SIGNED_MOVEMENT_NOT_RELEASED' THEN RAISE;END IF;END;
 UPDATE airlinerra_game.aircraft_storage_signed_movement_release_v1 SET enabled=true WHERE world_id=1;
 PERFORM set_config('test.storage_hour',l.arrival_utc::text,true);
 BEGIN
 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,storage_request_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc)
 VALUES(1,'storage-v1:'||physical||':arrived',repeat('b',64),a,f,r,1,1,l.flight_local_date,physical,'arrived',l.origin_airport_key,l.destination_airport_key,l.departure_utc,l.arrival_utc,l.arrival_utc);
 RAISE EXCEPTION 'arrival without departure accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'STORAGE_ARRIVAL_WITHOUT_DEPARTURE' THEN RAISE;END IF;END;
 FOREACH phase IN ARRAY ARRAY['departed','arrived'] LOOP
 IF phase='arrived' THEN
  UPDATE airlinerra_game.aircraft_storage_facilities_v1 SET review_state='suspended',monthly_narrowbody_usd=9900 WHERE airport_key=l.destination_airport_key;
  IF airlinerra_game.aircraft_storage_airport_admission_v1(l.destination_airport_key,'storage_inbound')->>'eligible' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'suspended facility accepts new flights';END IF;
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_inbound_departure_evidence_v1 WHERE request_id=r AND monthly_usd=8000 AND billing_class='narrowbody') THEN RAISE EXCEPTION 'signed departure price not frozen';END IF;
  BEGIN
   UPDATE airlinerra_game.aircraft_storage_relocation_requests_v1 SET quote=quote||jsonb_build_object('tampered',true) WHERE id=r;
   RAISE EXCEPTION 'departure quote mutation accepted';
  EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'STORAGE_INBOUND_DEPARTURE_FROZEN' THEN RAISE;END IF;END;
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_leg_evidence_v1(physical) e WHERE e.request_id=r AND e.quote=l.quote) THEN RAISE EXCEPTION 'signed inbound arrival evidence lost';END IF;
 END IF;
 event_time:=CASE WHEN phase='departed' THEN l.departure_utc ELSE l.arrival_utc END;
 PERFORM set_config('test.storage_hour',event_time::text,true);
 event_id:='storage-v1:'||physical||':'||phase;
 signature:=encode(extensions.hmac(convert_to(airlinerra_game.aircraft_storage_event_signing_payload_v1(physical,phase),'UTF8'),convert_to(repeat('a',64),'UTF8'),'sha256'),'hex');
 BEGIN
 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,storage_request_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc)
 VALUES(1,event_id,repeat('b',64),a,f,r,1,1,l.flight_local_date,physical,phase,l.origin_airport_key,l.destination_airport_key,l.departure_utc,l.arrival_utc,event_time);
 RAISE EXCEPTION 'invalid signature accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'STORAGE_SIGNATURE_INVALID' THEN RAISE;END IF;END;
 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,storage_request_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc)
 VALUES(1,event_id,signature,a,f,r,1,1,l.flight_local_date,physical,phase,l.origin_airport_key,l.destination_airport_key,l.departure_utc,l.arrival_utc,event_time);
 INSERT INTO airlinerra_game.section9_aircraft_current_position_v1(aircraft_inventory_id,world_id,airline_id,location_status,airport_key,current_flight_occurrence_id,last_event_utc,last_departure_utc,last_arrival_utc,last_engine_event_id,storage_request_id)
 VALUES(f,1,a,CASE WHEN phase='departed' THEN 'in_flight' ELSE 'grounded' END,CASE WHEN phase='arrived' THEN l.destination_airport_key END,CASE WHEN phase='departed' THEN physical END,event_time,l.departure_utc,CASE WHEN phase='arrived' THEN event_time END,event_id,r)
 ON CONFLICT(aircraft_inventory_id) DO UPDATE SET location_status=excluded.location_status,airport_key=excluded.airport_key,current_flight_occurrence_id=excluded.current_flight_occurrence_id,last_event_utc=excluded.last_event_utc,last_arrival_utc=excluded.last_arrival_utc,last_engine_event_id=excluded.last_engine_event_id,storage_request_id=excluded.storage_request_id;
 END LOOP;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aircraft_current_position_v1 WHERE aircraft_inventory_id=f AND airport_key=l.destination_airport_key AND location_status='grounded') THEN RAISE EXCEPTION 'arrival position missing';END IF;
 BEGIN
 UPDATE airlinerra_game.section9_aircraft_current_position_v1 SET airport_key='OURAIRPORTS:999' WHERE aircraft_inventory_id=f;
 RAISE EXCEPTION 'incorrect position accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'STORAGE_POSITION_EVIDENCE_MISMATCH' THEN RAISE;END IF;END;
 BEGIN
 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc)
 VALUES(1,'legacy-test-event',signature,a,f,k,1,1,l.flight_local_date,k::text||':'||l.flight_local_date::text||':1','departed',l.origin_airport_key,l.destination_airport_key,l.departure_utc,l.arrival_utc,l.departure_utc);
 RAISE EXCEPTION 'legacy flight accepted unapproved destination';
 EXCEPTION WHEN foreign_key_violation THEN NULL;END;
 RAISE NOTICE 'Signed inbound movement completed after destination suspension and tariff change';
END $test$;
