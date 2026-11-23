-- Disposable PostgreSQL only; model inventory-first locking used by production bookers.
-- This is a research prototype, NOT a production cancellation function.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regnamespace('inventory_lock_lab') IS NOT NULL
 THEN RAISE EXCEPTION 'INVENTORY_LOCK_LAB_DISPOSABLE_ONLY';END IF;
END $guard$;
CREATE SCHEMA inventory_lock_lab;
CREATE TABLE inventory_lock_lab.schedules(
 id uuid PRIMARY KEY, owner_id uuid NOT NULL,version int NOT NULL,
 status text NOT NULL,verified boolean NOT NULL);
CREATE TABLE inventory_lock_lab.capacity(
 schedule_id uuid PRIMARY KEY,passenger_capacity int NOT NULL,
 held int NOT NULL DEFAULT 0);
CREATE TABLE inventory_lock_lab.occurrences(
 id uuid PRIMARY KEY,schedule_id uuid NOT NULL UNIQUE,
 booked int NOT NULL DEFAULT 0);
CREATE TABLE inventory_lock_lab.reservations(
 id uuid PRIMARY KEY,occurrence_id uuid NOT NULL,seats int NOT NULL);
CREATE TABLE inventory_lock_lab.slots(
 schedule_id uuid NOT NULL,slot_id int NOT NULL,PRIMARY KEY(schedule_id,slot_id));
CREATE TABLE inventory_lock_lab.journal(
 schedule_id uuid NOT NULL,event text NOT NULL);

-- Same lock order as the private direct booking writer:
-- 1. capacity inventory, 2. dated occurrence, 3. parent schedule.
CREATE FUNCTION inventory_lock_lab.book(
 p_owner uuid,p_schedule uuid,p_occurrence uuid,p_reservation uuid)
 RETURNS text LANGUAGE plpgsql AS $fn$
DECLARE c inventory_lock_lab.capacity%ROWTYPE;
 o inventory_lock_lab.occurrences%ROWTYPE;
 s inventory_lock_lab.schedules%ROWTYPE;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'INVENTORY_LOCK_LAB_DISPOSABLE_ONLY';END IF;
 SELECT * INTO c FROM inventory_lock_lab.capacity
  WHERE schedule_id=p_schedule FOR UPDATE;
 IF NOT FOUND THEN RETURN 'blocked_missing_capacity';END IF;
 SELECT * INTO o FROM inventory_lock_lab.occurrences
  WHERE id=p_occurrence AND schedule_id=p_schedule FOR UPDATE;
 IF NOT FOUND THEN RETURN 'blocked_missing_occurrence';END IF;
 SELECT * INTO s FROM inventory_lock_lab.schedules
  WHERE id=p_schedule AND owner_id=p_owner FOR UPDATE;
 IF NOT FOUND THEN RETURN 'blocked_owner';END IF;
 IF s.status<>'active' OR s.verified IS DISTINCT FROM true
 THEN RETURN 'blocked_not_active';END IF;
 IF o.booked>=c.passenger_capacity THEN RETURN 'blocked_full';END IF;
 INSERT INTO inventory_lock_lab.reservations VALUES(p_reservation,p_occurrence,1);
 UPDATE inventory_lock_lab.occurrences SET booked=booked+1 WHERE id=p_occurrence;
 UPDATE inventory_lock_lab.capacity SET held=held+1 WHERE schedule_id=p_schedule;
 RETURN 'booked';
END $fn$;

CREATE FUNCTION inventory_lock_lab.cancel(
 p_owner uuid,p_schedule uuid,p_expected_version int)
 RETURNS text LANGUAGE plpgsql AS $fn$
DECLARE c inventory_lock_lab.capacity%ROWTYPE;
 o inventory_lock_lab.occurrences%ROWTYPE;
 s inventory_lock_lab.schedules%ROWTYPE;
 changed int;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'INVENTORY_LOCK_LAB_DISPOSABLE_ONLY';END IF;
 -- Inventory-first, not schedule-first; avoid lock-order inversion.
 SELECT * INTO c FROM inventory_lock_lab.capacity
  WHERE schedule_id=p_schedule FOR UPDATE;
 IF NOT FOUND THEN RETURN 'blocked_missing_capacity';END IF;
 SELECT * INTO o FROM inventory_lock_lab.occurrences
  WHERE schedule_id=p_schedule FOR UPDATE;
 IF NOT FOUND THEN RETURN 'blocked_missing_occurrence';END IF;
 SELECT * INTO s FROM inventory_lock_lab.schedules
  WHERE id=p_schedule AND owner_id=p_owner FOR UPDATE;
 IF NOT FOUND THEN RETURN 'blocked_owner';END IF;
 IF s.version IS DISTINCT FROM p_expected_version THEN RETURN 'blocked_stale';END IF;
 IF s.status='cancelled' THEN RETURN 'already_cancelled';END IF;
 IF s.status<>'active' OR s.verified IS DISTINCT FROM true THEN RETURN 'blocked_state';END IF;
 -- Revalidate all booking claims AFTER all three locks have been acquired.
 IF c.held<>0 OR o.booked<>0 OR EXISTS(
  SELECT 1 FROM inventory_lock_lab.reservations r WHERE r.occurrence_id=o.id
 ) THEN RETURN 'blocked_reservations';END IF;
 DELETE FROM inventory_lock_lab.slots WHERE schedule_id=p_schedule;
 DELETE FROM inventory_lock_lab.occurrences WHERE id=o.id;
 DELETE FROM inventory_lock_lab.capacity WHERE schedule_id=p_schedule;
 UPDATE inventory_lock_lab.schedules
 SET status='cancelled',verified=false,version=version+1
 WHERE id=p_schedule AND version=p_expected_version;
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'STALE_AFTER_LOCK';END IF;
 INSERT INTO inventory_lock_lab.journal VALUES(p_schedule,'cancelled');
 RETURN 'cancelled';
END $fn$;

INSERT INTO inventory_lock_lab.schedules VALUES
 ('11111111-1111-4111-8111-111111111111','99999999-9999-4999-8999-999999999999',1,'active',true),
 ('22222222-2222-4222-8222-222222222222','99999999-9999-4999-8999-999999999999',1,'active',true);
INSERT INTO inventory_lock_lab.capacity VALUES
 ('11111111-1111-4111-8111-111111111111',90,0),
 ('22222222-2222-4222-8222-222222222222',90,0);
INSERT INTO inventory_lock_lab.occurrences VALUES
 ('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa','11111111-1111-4111-8111-111111111111',0),
 ('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb','22222222-2222-4222-8222-222222222222',0);
INSERT INTO inventory_lock_lab.slots VALUES
 ('11111111-1111-4111-8111-111111111111',1),
 ('22222222-2222-4222-8222-222222222222',1);
