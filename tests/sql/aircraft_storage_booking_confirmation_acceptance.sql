-- Synthetic approval only. Confirm both slots and funds atomically; never deploy.
SAVEPOINT storage_booking;
DO $booking$
DECLARE s record; owner_id uuid; q jsonb; j jsonb; dep timestamptz; k uuid:=gen_random_uuid(); rid uuid; balance numeric; n bigint; approval_id uuid;
BEGIN
 SELECT * INTO STRICT s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
 SELECT owner_player_id INTO STRICT owner_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=s.request_id;
 PERFORM set_config('test.storage_hour',s.storage_started_utc::text,true);
 dep:=date_trunc('second',s.storage_started_utc+interval '1 hour');
 SELECT cash_usd INTO balance FROM airlinerra_game.airlines WHERE id=s.airline_id;
 SELECT count(*) INTO n FROM airlinerra_game.aircraft_storage_relocation_requests_v1;
 j:=airlinerra_game.confirm_owned_aircraft_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'status' IS DISTINCT FROM 'storage_booking_not_released' THEN RAISE EXCEPTION 'booking release bypass: %',j;END IF;
 UPDATE airlinerra_game.aircraft_storage_booking_release_v1 SET enabled=true;
 UPDATE airlinerra_game.aircraft_storage_execution_release_v1 SET execution_enabled=true,fuel_adapter_enabled=true;
 UPDATE airlinerra_game.aircraft_storage_signed_movement_release_v1 SET enabled=true;
 UPDATE airlinerra_game.aircraft_storage_reactivation_release_v1 SET enabled=true;
 j:=airlinerra_game.confirm_owned_aircraft_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,1,k);
 IF j->>'status' IS DISTINCT FROM 'storage_price_changed' THEN RAISE EXCEPTION 'booking price bypass: %',j;END IF;
 j:=airlinerra_game.confirm_owned_aircraft_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'status' IS DISTINCT FROM 'storage_booking_clearance_missing' THEN RAISE EXCEPTION 'booking clearance bypass: %',j;END IF;
 q:=airlinerra_game.owned_aircraft_storage_cost_preview_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep);
 INSERT INTO airlinerra_game.aircraft_storage_booking_approvals_v1(airline_id,aircraft_inventory_id,purpose,configuration_id,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,relocation_usd,runway_review_reference,airport_restriction_review_reference,ferry_licence_review_reference,crew_review_reference,approved_at)
 VALUES(s.airline_id,s.aircraft_inventory_id,'storage_reactivation',1,s.airport_key,'OURAIRPORTS:999',dep,(q->>'arrivalUtc')::timestamptz,2688.13,'fixture','fixture','fixture','fixture',s.storage_started_utc) RETURNING id INTO approval_id;
 INSERT INTO airlinerra_game.section6_weekly_airport_slot_reservations_v1
 VALUES(1,'OURAIRPORTS:999','remote','arrival',extract(isodow FROM (q->>'arrivalUtc')::timestamptz AT TIME ZONE 'Europe/Paris')::int-1,extract(hour FROM (q->>'arrivalUtc')::timestamptz AT TIME ZONE 'Europe/Paris')::int*60+(extract(minute FROM (q->>'arrivalUtc')::timestamptz AT TIME ZONE 'Europe/Paris')::int/10)*10);
 j:=airlinerra_game.confirm_owned_aircraft_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'status' IS DISTINCT FROM 'STORAGE_FLIGHT_SLOT_UNAVAILABLE' OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_relocation_requests_v1)<>n OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id)<>balance OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_booking_approvals_v1 WHERE id=approval_id AND consumed_request_id IS NOT NULL) THEN RAISE EXCEPTION 'booking rollback failed: %',j;END IF;
 DELETE FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 WHERE airport_key='OURAIRPORTS:999' AND direction='arrival';
 j:=airlinerra_game.confirm_owned_aircraft_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'booked' IS DISTINCT FROM 'true' OR j->>'slotsReserved' IS DISTINCT FROM '2' OR j->>'fundsHeld' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'booking failed: %',j;END IF;
 rid:=(j->>'requestId')::uuid;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_dispatch_clearance_v1 WHERE request_id=rid) OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id)<>balance-2688.13 THEN RAISE EXCEPTION 'booking evidence incomplete';END IF;
 j:=airlinerra_game.confirm_owned_aircraft_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'storage_reactivation','OURAIRPORTS:999',dep,2688.13,k);
 IF j->>'replayed' IS DISTINCT FROM 'true' OR j->>'requestId' IS DISTINCT FROM rid::text OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id)<>balance-2688.13 THEN RAISE EXCEPTION 'booking replay failed';END IF;
 j:=airlinerra_game.cancel_aircraft_storage_relocation_request_v1(owner_id,s.airline_id,rid);
 IF j->>'status' IS DISTINCT FROM 'cancelled' OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id)<>balance OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_flight_slots_v1 WHERE request_id=rid) THEN RAISE EXCEPTION 'booking cancellation failed';END IF;
 RAISE NOTICE 'Atomic outbound storage booking acceptance passed';
END $booking$;
ROLLBACK TO SAVEPOINT storage_booking;
