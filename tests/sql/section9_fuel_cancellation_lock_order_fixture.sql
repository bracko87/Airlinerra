-- DISPOSABLE PostgreSQL lock-order fixture, not production deployment.
-- It deliberately models the transaction-critical statements of the production
-- fuel preflight + signed dispatch / cancellation conflict.
CREATE SCHEMA release_test;
CREATE TABLE release_test.fuel (aircraft_id int PRIMARY KEY, onboard_kg numeric NOT NULL);
CREATE TABLE release_test.occurrence (id int PRIMARY KEY, aircraft_id int NOT NULL, booking_status text NOT NULL);
CREATE TABLE release_test.movement (occurrence_id int PRIMARY KEY);
INSERT INTO release_test.fuel VALUES (1,500);
INSERT INTO release_test.occurrence VALUES (1,1,'open'),(2,1,'open');

CREATE FUNCTION release_test.dispatch(p_id int) RETURNS text
LANGUAGE plpgsql AS $$
DECLARE aircraft int; changed int;
BEGIN
 -- Matches production dispatch's shared cancellation advisory key.
 IF NOT pg_try_advisory_xact_lock(583729,10041) THEN RETURN 'dispatch_busy'; END IF;
 SELECT aircraft_id INTO aircraft FROM release_test.occurrence WHERE id=p_id;
 -- Models the custody row lock held across the signed movement.
 PERFORM 1 FROM release_test.fuel WHERE aircraft_id=aircraft FOR UPDATE;
 INSERT INTO release_test.movement VALUES(p_id);
 UPDATE release_test.occurrence SET booking_status='closed'
 WHERE id=p_id AND booking_status='open';
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'SECTION9_DEPARTURE_BOOKING_CLOSE_UNCONFIRMED_ROLLBACK'; END IF;
 RETURN 'departed';
END $$;

CREATE FUNCTION release_test.cancel(p_id int) RETURNS text
LANGUAGE plpgsql AS $$
DECLARE state text; aircraft int;
BEGIN
 -- Matches production cancellation's shared advisory lock.
 PERFORM pg_advisory_xact_lock(583729,10041);
 SELECT booking_status,aircraft_id INTO state,aircraft
 FROM release_test.occurrence WHERE id=p_id FOR UPDATE;
 IF state<>'open' THEN RETURN 'not_cancellable'; END IF;
 IF EXISTS (SELECT 1 FROM release_test.movement WHERE occurrence_id=p_id)
 THEN RETURN 'already_operated'; END IF;
 UPDATE release_test.occurrence SET booking_status='cancelled' WHERE id=p_id;
 RETURN 'cancelled';
END $$;
