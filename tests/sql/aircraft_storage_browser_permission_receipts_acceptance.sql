-- Verify actual browser-created booking evidence after its full lifecycle.
BEGIN TRANSACTION READ ONLY;
DO $test$
DECLARE a uuid:='00000000-0000-4000-8000-000000000001'; n int;
BEGIN
 IF current_database()<>'review' THEN RAISE EXCEPTION 'disposable review database required';END IF;
 SELECT count(*) INTO n FROM airlinerra_game.storage_game_permission_receipts_v1 p
 JOIN airlinerra_game.aircraft_storage_relocation_requests_v1 r ON r.id=p.request_id
 JOIN airlinerra_game.aircraft_storage_automatic_booking_evidence_v1 e ON e.request_id=r.id AND e.approval_id=p.approval_id
 WHERE r.airline_id=a AND p.airline_id=r.airline_id AND p.aircraft_inventory_id=r.aircraft_inventory_id
 AND p.airport_key='OURAIRPORTS:316427' AND p.flight_departure_utc=r.departure_utc
 AND p.granted_at=e.checked_at AND p.revoked_at IS NULL
 AND p.review_snapshot#>>'{permissionPolicy,minimum_notice_minutes}'='120'
 AND ((r.purpose='storage_reactivation' AND p.operation='departure' AND p.event_utc=r.departure_utc)
 OR (r.purpose='storage_inbound' AND p.operation='arrival' AND p.event_utc=r.arrival_utc));
 IF n<>3 THEN RAISE EXCEPTION 'expected three matching browser permission receipts, found %',n;END IF;
 IF (SELECT count(*) FROM airlinerra_game.storage_game_permission_receipts_v1)<>3 THEN RAISE EXCEPTION 'unexpected permission receipt';END IF;
 IF (SELECT count(*) FROM airlinerra_game.storage_game_permission_receipts_v1 p JOIN airlinerra_game.aircraft_storage_relocation_requests_v1 r ON r.id=p.request_id WHERE r.airline_id=a AND r.status='completed')<>2
 OR (SELECT count(*) FROM airlinerra_game.storage_game_permission_receipts_v1 p JOIN airlinerra_game.aircraft_storage_relocation_requests_v1 r ON r.id=p.request_id WHERE r.airline_id=a AND r.status='cancelled')<>1
 THEN RAISE EXCEPTION 'permission history does not match completed and cancelled flights';END IF;
 RAISE NOTICE 'Browser PPR receipts matched all three actual bookings, including cancelled history and both completed directions';
END $test$;
ROLLBACK;
