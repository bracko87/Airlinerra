-- Isolated cancellation transaction research; NEVER install as production migration.
-- This synthetic candidate is NOT a safe, released active-flight cancellation API.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regnamespace('cancellation_lab') IS NOT NULL THEN
  RAISE EXCEPTION 'CANCELLATION_LAB_DISPOSABLE_ONLY';
 END IF;
END $guard$;
CREATE SCHEMA cancellation_lab;
CREATE TABLE cancellation_lab.schedules(
 id uuid PRIMARY KEY,owner_id uuid NOT NULL,version int NOT NULL,
 status text NOT NULL,operationally_verified boolean NOT NULL);
CREATE TABLE cancellation_lab.slots(schedule_id uuid NOT NULL,slot_id int NOT NULL,PRIMARY KEY(schedule_id,slot_id));
CREATE TABLE cancellation_lab.occurrences(
 id uuid PRIMARY KEY,schedule_id uuid NOT NULL,
 booked_seats int NOT NULL DEFAULT 0,
 recognized_revenue_usd numeric NOT NULL DEFAULT 0);
CREATE TABLE cancellation_lab.reservations(
 id uuid PRIMARY KEY,occurrence_id uuid NOT NULL,seats int NOT NULL);
CREATE TABLE cancellation_lab.movements(
 id uuid PRIMARY KEY,schedule_id uuid NOT NULL);
CREATE TABLE cancellation_lab.audit(
 id int GENERATED ALWAYS AS IDENTITY PRIMARY KEY,schedule_id uuid NOT NULL,
 event text NOT NULL);
CREATE TABLE cancellation_lab.failure_switch(enabled boolean NOT NULL);
INSERT INTO cancellation_lab.failure_switch VALUES (false);
CREATE FUNCTION cancellation_lab.try_cancel(
 p_owner uuid,p_schedule uuid,p_expected_version int)
 RETURNS text LANGUAGE plpgsql AS $fn$
DECLARE target cancellation_lab.schedules%ROWTYPE;
 count_slots int;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres' THEN
  RAISE EXCEPTION 'CANCELLATION_LAB_DISPOSABLE_ONLY';
 END IF;
 SELECT * INTO target FROM cancellation_lab.schedules
 WHERE id=p_schedule AND owner_id=p_owner FOR UPDATE;
 IF NOT FOUND THEN RETURN 'denied_owner'; END IF;
 IF p_expected_version IS DISTINCT FROM target.version THEN RETURN 'denied_stale';END IF;
 IF target.status='cancelled' THEN RETURN 'already_cancelled';END IF;
 IF target.status<>'active' OR target.operationally_verified IS DISTINCT FROM true
 THEN RETURN 'denied_not_active';END IF;
 -- No proposed cancellation is allowed while *any* passenger claims,
 -- movements, financial settlement, or historic occurrence bookings exist.
 IF EXISTS(SELECT 1 FROM cancellation_lab.reservations b
   JOIN cancellation_lab.occurrences o ON o.id=b.occurrence_id WHERE o.schedule_id=p_schedule)
 OR EXISTS(SELECT 1 FROM cancellation_lab.occurrences
   WHERE schedule_id=p_schedule AND (booked_seats>0 OR recognized_revenue_usd<>0))
 THEN RETURN 'denied_reservations_or_finance'; END IF;
 IF EXISTS(SELECT 1 FROM cancellation_lab.movements WHERE schedule_id=p_schedule)
 THEN RETURN 'denied_operated_movements';END IF;
 -- Rows are locked before any mutation, to model competing ticket writes.
 PERFORM 1 FROM cancellation_lab.occurrences WHERE schedule_id=p_schedule FOR UPDATE;
 PERFORM 1 FROM cancellation_lab.slots WHERE schedule_id=p_schedule FOR UPDATE;
 DELETE FROM cancellation_lab.occurrences WHERE schedule_id=p_schedule;
 DELETE FROM cancellation_lab.slots WHERE schedule_id=p_schedule;
 GET DIAGNOSTICS count_slots=ROW_COUNT;
 UPDATE cancellation_lab.schedules SET status='cancelled',operationally_verified=false,
 version=version+1 WHERE id=p_schedule AND version=p_expected_version;
 IF NOT FOUND THEN RAISE EXCEPTION 'CANCELLATION_LAB_STALE_WRITE';END IF;
 -- Simulate a downstream failure AFTER row and slot writes.
 IF (SELECT enabled FROM cancellation_lab.failure_switch) THEN
  RAISE EXCEPTION 'CANCELLATION_LAB_DOWNSTREAM_FAILURE';
 END IF;
 INSERT INTO cancellation_lab.audit(schedule_id,event) VALUES(p_schedule,'cancelled');
 RETURN 'cancelled_slots_'||count_slots::text;
END $fn$;

DO $tests$
DECLARE
 owner_id uuid:='11111111-1111-4111-8111-111111111111';
 other_id uuid:='22222222-2222-4222-8222-222222222222';
 target_schedule uuid:='33333333-3333-4333-8333-333333333333';
 occ_id uuid:='44444444-4444-4444-8444-444444444444';
 action text;failed boolean;
BEGIN
 INSERT INTO cancellation_lab.schedules VALUES(target_schedule,owner_id,7,'active',true);
 INSERT INTO cancellation_lab.slots VALUES(target_schedule,1),(target_schedule,2);
 INSERT INTO cancellation_lab.occurrences VALUES(occ_id,target_schedule,0,0);
 INSERT INTO cancellation_lab.audit(schedule_id,event) VALUES(target_schedule,'certified');
 -- Wrong owner and stale version must be no-ops.
 action:=cancellation_lab.try_cancel(other_id,target_schedule,7);
 IF action<>'denied_owner' THEN RAISE EXCEPTION 'Owner bypass';END IF;
 action:=cancellation_lab.try_cancel(owner_id,target_schedule,6);
 IF action<>'denied_stale' THEN RAISE EXCEPTION 'Version bypass';END IF;
 INSERT INTO cancellation_lab.reservations VALUES('55555555-5555-4555-8555-555555555555',occ_id,2);
 action:=cancellation_lab.try_cancel(owner_id,target_schedule,7);
 IF action<>'denied_reservations_or_finance' THEN RAISE EXCEPTION 'Reservation bypass';END IF;
 DELETE FROM cancellation_lab.reservations;
 UPDATE cancellation_lab.occurrences SET booked_seats=2;
 action:=cancellation_lab.try_cancel(owner_id,target_schedule,7);
 IF action<>'denied_reservations_or_finance' THEN RAISE EXCEPTION 'Seat evidence bypass';END IF;
 UPDATE cancellation_lab.occurrences SET booked_seats=0,recognized_revenue_usd=125;
 action:=cancellation_lab.try_cancel(owner_id,target_schedule,7);
 IF action<>'denied_reservations_or_finance' THEN RAISE EXCEPTION 'Finance bypass';END IF;
 UPDATE cancellation_lab.occurrences SET recognized_revenue_usd=0;
 INSERT INTO cancellation_lab.movements VALUES('66666666-6666-4666-8666-666666666666',target_schedule);
 action:=cancellation_lab.try_cancel(owner_id,target_schedule,7);
 IF action<>'denied_operated_movements' THEN RAISE EXCEPTION 'Movement bypass';END IF;
 DELETE FROM cancellation_lab.movements;
 -- An exception after updating all rows MUST roll back the whole subtransaction.
 UPDATE cancellation_lab.failure_switch SET enabled=true;
 failed:=false;
 BEGIN
  action:=cancellation_lab.try_cancel(owner_id,target_schedule,7);
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM='CANCELLATION_LAB_DOWNSTREAM_FAILURE' THEN failed:=true; ELSE RAISE;END IF;
 END;
 IF NOT failed
 OR (SELECT status FROM cancellation_lab.schedules WHERE id=target_schedule)<>'active'
 OR (SELECT version FROM cancellation_lab.schedules WHERE id=target_schedule)<>7
 OR (SELECT count(*) FROM cancellation_lab.slots WHERE schedule_id=target_schedule)<>2
 OR (SELECT count(*) FROM cancellation_lab.occurrences WHERE schedule_id=target_schedule)<>1
 OR (SELECT count(*) FROM cancellation_lab.audit WHERE schedule_id=target_schedule)<>1
 THEN RAISE EXCEPTION 'Atomic rollback failed';END IF;
 UPDATE cancellation_lab.failure_switch SET enabled=false;
 action:=cancellation_lab.try_cancel(owner_id,target_schedule,7);
 IF action<>'cancelled_slots_2'
 OR (SELECT status FROM cancellation_lab.schedules WHERE id=target_schedule)<>'cancelled'
 OR (SELECT version FROM cancellation_lab.schedules WHERE id=target_schedule)<>8
 OR EXISTS(SELECT 1 FROM cancellation_lab.slots WHERE schedule_id=target_schedule)
 OR EXISTS(SELECT 1 FROM cancellation_lab.occurrences WHERE schedule_id=target_schedule)
 OR (SELECT count(*) FROM cancellation_lab.audit WHERE schedule_id=target_schedule)<>2
 THEN RAISE EXCEPTION 'Candidate cancellation did not commit atomically';END IF;
 action:=cancellation_lab.try_cancel(owner_id,target_schedule,7);
 IF action<>'denied_stale' THEN RAISE EXCEPTION 'Old-version replay bypass';END IF;
 action:=cancellation_lab.try_cancel(owner_id,target_schedule,8);
 IF action<>'already_cancelled' THEN RAISE EXCEPTION 'Same-version replay bypass';END IF;
 IF (SELECT count(*) FROM cancellation_lab.audit WHERE schedule_id=target_schedule)<>2
 THEN RAISE EXCEPTION 'Replay created extra history';END IF;
 RAISE NOTICE 'PASS synthetic cancellation transaction guards, rollback and replay';
END $tests$;
