-- Runs inside the disposable signed-arrival transaction.
DO $reactivation$
DECLARE s record; r record; owner_id uuid; k uuid:=gen_random_uuid(); departure timestamptz; j jsonb; id_request uuid; balance numeric;
BEGIN
 SELECT * INTO s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
 SELECT owner_player_id INTO owner_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=s.request_id;
 departure:=date_trunc('second',airlinerra_game.section9_verified_world_instant_v1()+interval '1 hour');
 SELECT cash_usd INTO balance FROM airlinerra_game.airlines WHERE id=s.airline_id;
 j:=airlinerra_game.request_aircraft_storage_reactivation_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'OURAIRPORTS:999',departure,1,k);
 IF j->>'status' IS DISTINCT FROM 'storage_price_changed' THEN RAISE EXCEPTION 'reactivation price check failed: %',j;END IF;
 j:=airlinerra_game.request_aircraft_storage_reactivation_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'OURAIRPORTS:999',departure,2688.13,k);
 IF j->>'created' IS DISTINCT FROM 'true' OR j->>'aircraftStillStored' IS DISTINCT FROM 'true' OR j#>>'{billing,status}' IS DISTINCT FROM 'storage_billing_due' THEN RAISE EXCEPTION 'reactivation request failed: %',j;END IF;
 id_request:=(j->>'requestId')::uuid;
 j:=airlinerra_game.request_aircraft_storage_reactivation_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'OURAIRPORTS:999',departure,2688.13,k);
 IF j->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'reactivation replay failed: %',j;END IF;
 j:=airlinerra_game.request_aircraft_storage_reactivation_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'OURAIRPORTS:999',departure,2688.13,gen_random_uuid());
 IF j->>'status' IS DISTINCT FROM 'storage_request_already_pending' THEN RAISE EXCEPTION 'duplicate reactivation accepted: %',j;END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_leg_evidence_v1(id_request::text||':'||(departure AT TIME ZONE 'UTC')::date::text||':1')) THEN RAISE EXCEPTION 'outbound request accepted by inbound worker';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=id_request AND purpose='storage_reactivation' AND storage_session_id=s.request_id AND origin_airport_key=s.airport_key) THEN RAISE EXCEPTION 'reactivation linkage missing';END IF;
 j:=airlinerra_game.hold_aircraft_reactivation_funds_v1(owner_id,s.airline_id,id_request);
 IF j->>'status' IS DISTINCT FROM 'storage_hold_not_ready' THEN RAISE EXCEPTION 'hold accepted before slots: %',j;END IF;
 -- Block arrival at the commercial destination, after storage departure
 -- slot insertion, to prove the entire pair rolls back on conflict.
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=id_request;
 INSERT INTO airlinerra_game.section6_weekly_airport_slot_reservations_v1
 VALUES(1,'OURAIRPORTS:999','remote','arrival',extract(isodow FROM r.arrival_utc AT TIME ZONE 'Europe/Paris')::int-1,extract(hour FROM r.arrival_utc AT TIME ZONE 'Europe/Paris')::int*60+(extract(minute FROM r.arrival_utc AT TIME ZONE 'Europe/Paris')::int/10)*10);
 j:=airlinerra_game.reserve_aircraft_reactivation_slots_v1(owner_id,s.airline_id,id_request);
 IF j->>'status' IS DISTINCT FROM 'STORAGE_FLIGHT_SLOT_UNAVAILABLE' OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_flight_slots_v1 WHERE request_id=id_request) THEN RAISE EXCEPTION 'outbound atomic reservation failure: %',j;END IF;
 DELETE FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 WHERE airport_key='OURAIRPORTS:999' AND direction='arrival';
 j:=airlinerra_game.reserve_aircraft_reactivation_slots_v1(owner_id,s.airline_id,id_request);
 IF j->>'slotsReserved' IS DISTINCT FROM '2' OR j->>'flightScheduled' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'outbound slot reservation failed: %',j;END IF;
 IF NOT airlinerra_game.reactivation_reservation_evidence_v1(id_request) THEN RAISE EXCEPTION 'outbound reservation evidence missing';END IF;
 j:=airlinerra_game.reserve_aircraft_reactivation_slots_v1(owner_id,s.airline_id,id_request);
 IF j->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'outbound slot replay failed: %',j;END IF;
 j:=airlinerra_game.hold_aircraft_reactivation_funds_v1(owner_id,s.airline_id,id_request);
 IF j->>'fundsHeld' IS DISTINCT FROM 'true' OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id) IS DISTINCT FROM balance-2688.13 THEN RAISE EXCEPTION 'outbound hold failed: %',j;END IF;
 j:=airlinerra_game.hold_aircraft_reactivation_funds_v1(owner_id,s.airline_id,id_request);
 IF j->>'replayed' IS DISTINCT FROM 'true' OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id) IS DISTINCT FROM balance-2688.13 THEN RAISE EXCEPTION 'outbound hold replay failed: %',j;END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_leg_evidence_v1(id_request::text||':'||(departure AT TIME ZONE 'UTC')::date::text||':1')) THEN RAISE EXCEPTION 'reserved outbound consumed by inbound worker';END IF;
 j:=airlinerra_game.cancel_aircraft_storage_relocation_request_v1(owner_id,s.airline_id,id_request);
 IF j->>'status' IS DISTINCT FROM 'cancelled' OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_flight_slots_v1 WHERE request_id=id_request) OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_funds_v1 WHERE request_id=id_request AND status='refunded') THEN RAISE EXCEPTION 'reactivation cancellation failed: %',j;END IF;
 IF (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=s.airline_id) IS DISTINCT FROM balance OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE request_id=s.request_id AND storage_ended_utc IS NULL) OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=s.aircraft_inventory_id AND fleet_status='stored') THEN RAISE EXCEPTION 'reactivation changed storage or cash';END IF;
 UPDATE airlinerra_game.aircraft_storage_facilities_v1 SET reactivation_allowed=false WHERE airport_key=s.airport_key;
 j:=airlinerra_game.request_aircraft_storage_reactivation_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'OURAIRPORTS:999',departure,2688.13,gen_random_uuid());
 IF j->>'status' IS DISTINCT FROM 'storage_reactivation_not_approved' THEN RAISE EXCEPTION 'unauthorized reactivation accepted: %',j;END IF;
 UPDATE airlinerra_game.aircraft_storage_facilities_v1 SET reactivation_allowed=true WHERE airport_key=s.airport_key;
 RAISE NOTICE 'Storage reactivation request acceptance passed';
END $reactivation$;
