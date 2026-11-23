-- Disposable-only connecting-journey guard acceptance.
-- Real itinerary hold/leg relationships represented in synthetic fixtures.
-- No production cancellation or booking function is modified.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.section9_atomic_itinerary_holds_v1') IS NOT NULL
 THEN RAISE EXCEPTION 'ITINERARY_GUARD_DISPOSABLE_ONLY';END IF;
END $guard$;
CREATE TABLE airlinerra_game.section9_atomic_itinerary_holds_v1(
 source_allocation_key text PRIMARY KEY,physical_flight_ids text[] NOT NULL,
 passengers int NOT NULL,cargo_tonnes numeric NOT NULL,status text NOT NULL);
CREATE TABLE airlinerra_game.section9_atomic_itinerary_hold_legs_v1(
 source_allocation_key text NOT NULL,leg_number smallint NOT NULL,
 physical_flight_id text NOT NULL,PRIMARY KEY(source_allocation_key,leg_number));
CREATE TABLE airlinerra_game.section9_capacity_hold_plan_items_v1(
 allocation_key text PRIMARY KEY,physical_flight_ids text[] NOT NULL,
 passengers int NOT NULL,cargo_tonnes numeric NOT NULL);

-- This function is a read-only cancellation gate for testing, not a release.
CREATE FUNCTION real_booking_cancel_lab.inspect_connecting_hold(
 p_schedule uuid) RETURNS text LANGUAGE plpgsql AS $fn$
DECLARE n_hold int;n_plan int;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'ITINERARY_GUARD_DISPOSABLE_ONLY';END IF;
 SELECT count(*) INTO n_hold
 FROM airlinerra_game.section9_atomic_itinerary_hold_legs_v1 l
 JOIN airlinerra_game.section9_atomic_itinerary_holds_v1 h
 ON h.source_allocation_key=l.source_allocation_key
 WHERE split_part(l.physical_flight_id,':',1)=p_schedule::text
  AND cardinality(h.physical_flight_ids)=2
  AND h.status='preflight_only';
 SELECT count(*) INTO n_plan
 FROM airlinerra_game.section9_capacity_hold_plan_items_v1 i
 WHERE cardinality(i.physical_flight_ids)=2
  AND EXISTS(SELECT 1 FROM unnest(i.physical_flight_ids) f(flight_id)
   WHERE split_part(f.flight_id,':',1)=p_schedule::text);
 IF n_hold>0 OR n_plan>0 THEN RETURN 'blocked_connecting_journey';END IF;
 RETURN 'no_connecting_hold_found';
END $fn$;

INSERT INTO airlinerra_game.section9_atomic_itinerary_holds_v1 VALUES(
 's9g1:'||repeat('a',64),
 ARRAY['66666666-6666-4666-8666-666666666666:2026-11-21:1',
       '77777777-7777-4777-8777-777777777777:2026-11-21:1'],
 2,0,'preflight_only');
INSERT INTO airlinerra_game.section9_atomic_itinerary_hold_legs_v1 VALUES
 ('s9g1:'||repeat('a',64),1,'66666666-6666-4666-8666-666666666666:2026-11-21:1'),
 ('s9g1:'||repeat('a',64),2,'77777777-7777-4777-8777-777777777777:2026-11-21:1');
INSERT INTO airlinerra_game.section9_capacity_hold_plan_items_v1 VALUES(
 's9g1:'||repeat('a',64),
 ARRAY['66666666-6666-4666-8666-666666666666:2026-11-21:1',
       '77777777-7777-4777-8777-777777777777:2026-11-21:1'],2,0);
DO $assert$
DECLARE x text;
BEGIN
 SELECT real_booking_cancel_lab.inspect_connecting_hold(
 '66666666-6666-4666-8666-666666666666') INTO x;
 IF x<>'blocked_connecting_journey' THEN RAISE EXCEPTION 'Origin leg not protected';END IF;
 SELECT real_booking_cancel_lab.inspect_connecting_hold(
 '77777777-7777-4777-8777-777777777777') INTO x;
 IF x<>'blocked_connecting_journey' THEN RAISE EXCEPTION 'Connection leg not protected';END IF;
 SELECT real_booking_cancel_lab.inspect_connecting_hold(
 '44444444-4444-4444-8444-444444444444') INTO x;
 IF x<>'no_connecting_hold_found' THEN RAISE EXCEPTION 'Unrelated flight incorrectly flagged';END IF;

 UPDATE airlinerra_game.section9_atomic_itinerary_holds_v1 SET status='expired';
 -- Even after the specific itinerary record expires, a staged plan may
 -- still represent a claim; the cancellation preview remains conservative.
 SELECT real_booking_cancel_lab.inspect_connecting_hold(
 '66666666-6666-4666-8666-666666666666') INTO x;
 IF x<>'blocked_connecting_journey' THEN RAISE EXCEPTION 'Staged plan not protected';END IF;
 DELETE FROM airlinerra_game.section9_capacity_hold_plan_items_v1;
 SELECT real_booking_cancel_lab.inspect_connecting_hold(
 '66666666-6666-4666-8666-666666666666') INTO x;
 IF x<>'no_connecting_hold_found' THEN RAISE EXCEPTION 'Expired and cleared hold should disappear';END IF;
 RAISE NOTICE 'PASS: both connecting legs blocked, staged hold preserved, unrelated route unaffected';
END $assert$;
