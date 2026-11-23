-- ORIGINAL deployed private cancellation worker, read-only snapshot 2026-11-23.
-- Disposable PG17 only; never deploy this test artifact.
DO $guard$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'CANCELLATION_TEST_SNAPSHOT_DISPOSABLE_ONLY';END IF;
END $guard$;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_cancel_unflown_occurrence_v1(p_occurrence uuid, p_reason text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE o record; c record; prior record; physical text; seats int; held int; gross numeric; n int; v_now timestamptz;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_FLIGHT_CANCELLATION';END IF;
 IF p_reason IS NULL OR p_reason NOT IN ('maximum_delay_exceeded','aircraft_at_wrong_airport') THEN RAISE EXCEPTION 'INVALID_CANCELLATION_REASON';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_disruption_release_v1 WHERE world_id=1 AND cancellation_enabled) THEN RETURN jsonb_build_object('status','flight_cancellation_not_released','cancelled',false,'ledgerPosted',false);END IF;
 -- Serialize against signed commercial dispatch.
 PERFORM pg_advisory_xact_lock(583729,10041);
 SELECT * INTO prior FROM airlinerra_game.section9_flight_cancellation_receipts_v1 WHERE occurrence_id=p_occurrence;
 IF FOUND THEN RETURN jsonb_build_object('status','flight_cancelled','cancelled',true,'replayed',true,'ledgerPosted',false);END IF;
 SELECT * INTO o FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=p_occurrence;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','unknown_occurrence','cancelled',false,'ledgerPosted',false);END IF;
 physical:=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text;
 -- Existing ticket writers lock capacity before occurrence.
 SELECT * INTO c FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 WHERE physical_flight_id=physical FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','capacity_missing','cancelled',false,'ledgerPosted',false);END IF;
 SELECT * INTO o FROM airlinerra_game.section9_dated_flight_occurrences_v1 WHERE id=p_occurrence FOR UPDATE;
 IF o.booking_status<>'open' OR o.source_kind<>'game_verified_saleable_schedule_v1' OR c.airline_id<>o.airline_id OR c.schedule_version<>o.schedule_version OR o.recognized_revenue_usd<>0 THEN RETURN jsonb_build_object('status','flight_not_cancellable','cancelled',false,'ledgerPosted',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id=physical) OR EXISTS(SELECT 1 FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1 WHERE physical_flight_id=physical) THEN RETURN jsonb_build_object('status','flight_already_operated_or_settled','cancelled',false,'ledgerPosted',false);END IF;
 -- Connecting journeys and mixed cargo require a separate atomic multi-leg
 -- cancellation transaction, not cancellation of half an itinerary.
 IF c.cargo_held_tonnes<>0 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_atomic_itinerary_holds_v1 h WHERE physical=ANY(h.physical_flight_ids) AND h.status='preflight_only' AND (cardinality(h.physical_flight_ids)<>1 OR h.cargo_tonnes<>0)) THEN RETURN jsonb_build_object('status','connecting_or_cargo_recovery_required','cancelled',false,'ledgerPosted',false);END IF;
 SELECT coalesce(sum(seats_requested),0),coalesce(sum(seats_requested*quoted_fare_usd),0) INTO seats,gross FROM airlinerra_game.section9_passenger_reservation_batches_v1 WHERE occurrence_id=o.id AND reservation_status='reserved' AND NOT paid_upfront AND recognized_revenue_usd=0;
 IF seats<>o.booked_seats OR c.passengers_held<seats OR EXISTS(SELECT 1 FROM airlinerra_game.section9_passenger_reservation_batches_v1 WHERE occurrence_id=o.id AND (paid_upfront OR recognized_revenue_usd<>0)) THEN RETURN jsonb_build_object('status','reservation_reconciliation_required','cancelled',false,'ledgerPosted',false);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();IF v_now IS NULL THEN RETURN jsonb_build_object('status','clock_unavailable','cancelled',false,'ledgerPosted',false);END IF;
 held:=c.passengers_held;
 UPDATE airlinerra_game.section9_passenger_reservation_batches_v1 SET reservation_status='cancelled' WHERE occurrence_id=o.id AND reservation_status IN ('reserved','unissued');
 UPDATE airlinerra_game.section9_atomic_itinerary_holds_v1 SET status='cancelled' WHERE physical=ANY(physical_flight_ids) AND status='preflight_only';
 GET DIAGNOSTICS n=ROW_COUNT;
 UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1 SET passengers_held=0 WHERE physical_flight_id=physical;
 UPDATE airlinerra_game.section9_dated_flight_occurrences_v1 SET booking_status='cancelled',booked_seats=0 WHERE id=o.id;
 INSERT INTO airlinerra_game.section9_flight_cancellation_receipts_v1 VALUES(o.id,physical,o.airline_id,v_now,p_reason,seats,held,n,gross);
 RETURN jsonb_build_object('status','flight_cancelled','cancelled',true,'replayed',false,'cancelledSeats',seats,'releasedHeldSeats',held,'cancelledHolds',n,'foregoneTicketQuoteUsd',gross,'refundUsd',0,'ledgerPosted',false,'weeklyScheduleRetained',true);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_cancel_unflown_occurrence_v1(uuid,text)
 FROM PUBLIC,anon,authenticated,service_role;
