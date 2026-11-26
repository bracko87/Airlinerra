-- Disposable test transaction only. Signed arrival fixture precedes this test.
DO $test$
DECLARE r record; m record; d record; j jsonb; before_total numeric; after_total numeric;
BEGIN
 SELECT q.* INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 q JOIN airlinerra_game.section9_operated_flight_movements_v1 mv ON mv.storage_request_id=q.id AND mv.phase='arrived';
 IF NOT FOUND THEN RAISE EXCEPTION 'arrival fixture missing';END IF;
 SELECT * INTO m FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND phase='arrived';
 SELECT * INTO d FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND phase='departed';
 SELECT sum(amount_usd) INTO before_total FROM airlinerra_game.airline_ledger WHERE airline_id=r.airline_id;
 BEGIN
 PERFORM airlinerra_game.cancel_aircraft_storage_relocation_request_v1(r.owner_player_id,r.airline_id,r.id);
 RAISE EXCEPTION 'departed request cancelled';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'STORAGE_FLIGHT_ALREADY_DEPARTED' THEN RAISE;END IF;END;
 BEGIN
 PERFORM airlinerra_game.complete_aircraft_storage_arrival_v1(r.id);
 RAISE EXCEPTION 'missing fuel accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'STORAGE_FUEL_BURN_NOT_PROVEN' THEN RAISE;END IF;END;
 INSERT INTO airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 VALUES(m.flight_occurrence_id,r.airline_id,r.aircraft_inventory_id,m.engine_event_id,1000,r.destination_airport_key);
 BEGIN
 PERFORM airlinerra_game.complete_aircraft_storage_arrival_v1(r.id);
 RAISE EXCEPTION 'missing usage accepted';
 EXCEPTION WHEN raise_exception THEN IF SQLERRM<>'STORAGE_AIRFRAME_USAGE_NOT_PROVEN' THEN RAISE;END IF;END;
 INSERT INTO airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 VALUES(m.flight_occurrence_id,r.airline_id,r.aircraft_inventory_id,m.engine_event_id,d.engine_event_id,1,1);
 j:=airlinerra_game.complete_aircraft_storage_arrival_v1(r.id);
 IF j->>'status' IS DISTINCT FROM 'aircraft_stored' OR j->>'ledgerPosted' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'storage completion: %',j;END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND fleet_status='stored') OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE request_id=r.id AND airport_key=r.destination_airport_key AND storage_started_utc=m.actual_event_utc AND storage_ended_utc IS NULL) THEN RAISE EXCEPTION 'storage session missing';END IF;
 j:=airlinerra_game.complete_aircraft_storage_arrival_v1(r.id);
 IF j->>'replayed' IS DISTINCT FROM 'true' OR j->>'ledgerPosted' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'completion replay: %',j;END IF;
 SELECT sum(amount_usd) INTO after_total FROM airlinerra_game.airline_ledger WHERE airline_id=r.airline_id;
 IF after_total IS DISTINCT FROM before_total-r.quoted_cost_usd THEN RAISE EXCEPTION 'expense duplicated or missing';END IF;
 RAISE NOTICE 'Storage arrival and exactly-once expense acceptance passed';
END $test$;
ROLLBACK;
