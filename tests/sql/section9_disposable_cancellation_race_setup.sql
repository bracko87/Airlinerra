-- Disposable concurrency fixtures; all writes stay in airlinerra_disposable.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres' OR
  to_regnamespace('cancellation_lab') IS NULL THEN
  RAISE EXCEPTION 'CONCURRENT_CANCELLATION_DISPOSABLE_ONLY';
 END IF;
END $guard$;
CREATE OR REPLACE FUNCTION cancellation_lab.try_book(
 p_owner uuid,p_schedule uuid,p_occurrence uuid,p_booking uuid)
 RETURNS text LANGUAGE plpgsql AS $fn$
DECLARE s cancellation_lab.schedules%ROWTYPE;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'CONCURRENT_BOOKING_DISPOSABLE_ONLY'; END IF;
 -- Both competing writers first take the SAME schedule row lock.
 SELECT * INTO s FROM cancellation_lab.schedules
 WHERE id=p_schedule AND owner_id=p_owner FOR UPDATE;
 IF NOT FOUND THEN RETURN 'denied_owner';END IF;
 IF s.status<>'active' OR s.operationally_verified IS DISTINCT FROM true
 THEN RETURN 'denied_inactive';END IF;
 PERFORM 1 FROM cancellation_lab.occurrences
 WHERE id=p_occurrence AND schedule_id=p_schedule FOR UPDATE;
 IF NOT FOUND THEN RETURN 'denied_missing_occurrence';END IF;
 INSERT INTO cancellation_lab.reservations VALUES(p_booking,p_occurrence,1);
 UPDATE cancellation_lab.occurrences SET booked_seats=booked_seats+1
 WHERE id=p_occurrence AND schedule_id=p_schedule;
 RETURN 'booked';
END $fn$;
-- Two independent synthetic routes for both orderings.
INSERT INTO cancellation_lab.schedules VALUES
 ('77777777-7777-4777-8777-777777777777','11111111-1111-4111-8111-111111111111',1,'active',true),
 ('88888888-8888-4888-8888-888888888888','11111111-1111-4111-8111-111111111111',1,'active',true);
INSERT INTO cancellation_lab.slots VALUES
 ('77777777-7777-4777-8777-777777777777',1),
 ('88888888-8888-4888-8888-888888888888',1);
INSERT INTO cancellation_lab.occurrences VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','77777777-7777-4777-8777-777777777777',0,0),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','88888888-8888-4888-8888-888888888888',0,0);
