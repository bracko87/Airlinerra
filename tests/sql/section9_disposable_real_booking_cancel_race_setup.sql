-- Disposable only. Two new active schedules + unchanged direct-booking SQL.
-- The proposed cancellation procedure is a test fixture, NOT a deployable API.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable'
 OR current_user<>'postgres'
 OR to_regnamespace('real_booking_cancel_lab') IS NOT NULL
 THEN RAISE EXCEPTION 'REAL_BOOKING_CANCELLATION_DISPOSABLE_ONLY';END IF;
END $guard$;
CREATE SCHEMA real_booking_cancel_lab;
CREATE TABLE real_booking_cancel_lab.audit(
 schedule_id uuid NOT NULL,event text NOT NULL
);
INSERT INTO airlinerra_game.airline_flight_schedule_drafts_v1 VALUES
 ('66666666-6666-4666-8666-666666666666',1,
 '11111111-1111-4111-8111-111111111111',
 '33333333-3333-4333-8333-333333333333',100,1,'active',true,
 'OURAIRPORTS:2212','OURAIRPORTS:2218','AL106','[]'::jsonb),
 ('77777777-7777-4777-8777-777777777777',1,
 '11111111-1111-4111-8111-111111111111',
 '33333333-3333-4333-8333-333333333333',100,1,'active',true,
 'OURAIRPORTS:2218','OURAIRPORTS:2212','AL107','[]'::jsonb);
INSERT INTO airlinerra_game.section9_route_commercial_plans_v1 VALUES
 ('66666666-6666-4666-8666-666666666666',
  '11111111-1111-4111-8111-111111111111',1,85,0),
 ('77777777-7777-4777-8777-777777777777',
  '11111111-1111-4111-8111-111111111111',1,85,0);
INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1 VALUES
 ('cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '11111111-1111-4111-8111-111111111111',
  '66666666-6666-4666-8666-666666666666',
  '33333333-3333-4333-8333-333333333333',
  1,1,DATE '2026-11-21',110,0,'open',
  'game_verified_saleable_schedule_v1','2026-11-21T10:00:00Z'),
 ('dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '11111111-1111-4111-8111-111111111111',
  '77777777-7777-4777-8777-777777777777',
  '33333333-3333-4333-8333-333333333333',
  1,1,DATE '2026-11-21',110,0,'open',
  'game_verified_saleable_schedule_v1','2026-11-21T10:00:00Z');
INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1 VALUES
 ('66666666-6666-4666-8666-666666666666:2026-11-21:1',
  '66666666-6666-4666-8666-666666666666',
  '11111111-1111-4111-8111-111111111111',1,1,110,0,'preflight_only'),
 ('77777777-7777-4777-8777-777777777777:2026-11-21:1',
  '77777777-7777-4777-8777-777777777777',
  '11111111-1111-4111-8111-111111111111',1,1,110,0,'preflight_only');
INSERT INTO airlinerra_game.section6_weekly_airport_slot_reservations_v1 VALUES
 ('66666666-6666-4666-8666-666666666666','departure'),
 ('66666666-6666-4666-8666-666666666666','arrival'),
 ('77777777-7777-4777-8777-777777777777','departure'),
 ('77777777-7777-4777-8777-777777777777','arrival');

-- Model the proposed cancellation side ONLY, with real game fixture tables.
-- Lock order: capacity inventory, occurrence, schedule. This function
-- deliberately refuses any passengers/revenue and never changes a paid claim.
CREATE FUNCTION real_booking_cancel_lab.proposed_cancel(
 p_owner uuid,p_airline uuid,p_schedule uuid,p_expected_version int)
 RETURNS text LANGUAGE plpgsql AS $fn$
DECLARE cap record;occ record;sched record;rows_changed int;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'REAL_BOOKING_CANCELLATION_DISPOSABLE_ONLY';END IF;
 SELECT c.* INTO cap
 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 c
 WHERE c.schedule_id=p_schedule FOR UPDATE;
 IF NOT FOUND THEN RETURN 'blocked_missing_inventory';END IF;
 SELECT o.* INTO occ
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 WHERE o.schedule_id=p_schedule FOR UPDATE;
 IF NOT FOUND THEN RETURN 'blocked_missing_flight';END IF;
 SELECT s.* INTO sched
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a ON a.id=s.airline_id
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND a.owner_player_id=p_owner
 FOR UPDATE OF s;
 IF NOT FOUND THEN RETURN 'blocked_owner';END IF;
 IF sched.version IS DISTINCT FROM p_expected_version THEN RETURN 'blocked_stale';END IF;
 IF sched.status<>'active' OR sched.operationally_verified IS DISTINCT FROM true
 THEN RETURN 'blocked_not_active';END IF;
 IF cap.passengers_held<>0 OR occ.booked_seats<>0
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_passenger_reservation_batches_v1 b
  WHERE b.occurrence_id=occ.id)
 THEN RETURN 'blocked_reserved_seats';END IF;
 DELETE FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1
 WHERE schedule_id=p_schedule;
 DELETE FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=occ.id;
 DELETE FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
 WHERE physical_flight_id=cap.physical_flight_id;
 UPDATE airlinerra_game.airline_flight_schedule_drafts_v1
 SET status='cancelled',operationally_verified=false,version=version+1
 WHERE id=p_schedule AND version=p_expected_version;
 GET DIAGNOSTICS rows_changed=ROW_COUNT;
 IF rows_changed<>1 THEN RAISE EXCEPTION 'STALE_CANCELLATION_AFTER_LOCK';END IF;
 INSERT INTO real_booking_cancel_lab.audit VALUES(p_schedule,'cancelled');
 RETURN 'candidate_cancelled';
END $fn$;
