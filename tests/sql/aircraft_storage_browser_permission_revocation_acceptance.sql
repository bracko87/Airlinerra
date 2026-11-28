-- Run within the disposable browser booking transaction checkpoint.
-- All counterfactual worker executions and financial effects are rolled back.
SAVEPOINT permission_revocation_probe;
DO $test$
DECLARE r record;j jsonb;cash_before numeric;ledger_before bigint;slot_before bigint;crew_before bigint;
BEGIN
 IF current_database()<>'review' THEN RAISE EXCEPTION 'disposable review database required';END IF;
 SELECT q.* INTO STRICT r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 q
 JOIN airlinerra_game.storage_game_permission_receipts_v1 p ON p.request_id=q.id
 WHERE q.airline_id='00000000-0000-4000-8000-000000000001' AND q.status='reactivation_awaiting_review';
 PERFORM set_config('test.storage_hour',r.departure_utc::text,true);
 SELECT cash_usd INTO STRICT cash_before FROM airlinerra_game.airlines WHERE id=r.airline_id;
 SELECT count(*) INTO ledger_before FROM airlinerra_game.airline_ledger;
 SELECT count(*) INTO slot_before FROM airlinerra_game.aircraft_storage_flight_slots_v1 WHERE request_id=r.id;
 SELECT count(*) INTO crew_before FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=r.id;
 j:=airlinerra_game.revoke_storage_game_permission_v1(r.id);
 IF j->>'revoked' IS DISTINCT FROM 'true' OR j->>'replayed' IS DISTINCT FROM 'false' THEN RAISE EXCEPTION 'permission revocation failed: %',j;END IF;
 j:=airlinerra_game.revoke_storage_game_permission_v1(r.id);
 IF j->>'replayed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'permission revocation replay failed: %',j;END IF;
 j:=airlinerra_game.run_storage_background_tick_v1(25);
 IF NOT EXISTS(SELECT 1 FROM jsonb_array_elements(j->'results') x WHERE x->>'requestId'=r.id::text AND x->>'phase'='departed' AND x->>'sqlstate'='23514' AND x->>'status'='storage_background_item_rolled_back') THEN RAISE EXCEPTION 'revoked departure not blocked: %',j;END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id)
 OR (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=r.airline_id) IS DISTINCT FROM cash_before
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger)<>ledger_before
 OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_flight_slots_v1 WHERE request_id=r.id)<>slot_before
 OR (SELECT count(*) FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=r.id)<>crew_before
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_funds_v1 WHERE request_id=r.id AND status='held')
 THEN RAISE EXCEPTION 'revoked departure produced side effects';END IF;
 RAISE NOTICE 'Revoked browser PPR correctly blocked worker departure without movement or financial mutation';
END $test$;
ROLLBACK TO SAVEPOINT permission_revocation_probe;
RELEASE SAVEPOINT permission_revocation_probe;
