BEGIN;
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_disruption_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),decision_enabled boolean NOT NULL DEFAULT false,cancellation_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.section9_disruption_release_v1 VALUES(1,false,false) ON CONFLICT DO NOTHING;
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_flight_disruption_decisions_v1(
 occurrence_id uuid PRIMARY KEY REFERENCES airlinerra_game.section9_dated_flight_occurrences_v1(id),
 physical_flight_id text NOT NULL UNIQUE,airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 assessed_at timestamptz NOT NULL,condition_pct numeric(5,2) NOT NULL CHECK(condition_pct BETWEEN 0 AND 100),
 utilization_pct numeric(5,2) NOT NULL CHECK(utilization_pct BETWEEN 0 AND 100),overloaded boolean NOT NULL,
 delay_probability_pct numeric(5,2) NOT NULL CHECK(delay_probability_pct BETWEEN 0 AND 100),
 technical_delay_minutes integer NOT NULL CHECK(technical_delay_minutes BETWEEN 0 AND 240),
 model text NOT NULL DEFAULT 'GAME_OPERATIONAL_RELIABILITY_V1'
);
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_flight_cancellation_receipts_v1(
 occurrence_id uuid PRIMARY KEY REFERENCES airlinerra_game.section9_dated_flight_occurrences_v1(id),
 physical_flight_id text NOT NULL UNIQUE,airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 cancelled_at timestamptz NOT NULL,reason text NOT NULL CHECK(reason IN ('maximum_delay_exceeded','aircraft_at_wrong_airport')),
 cancelled_seats integer NOT NULL CHECK(cancelled_seats>=0),released_held_seats integer NOT NULL CHECK(released_held_seats>=cancelled_seats),
 cancelled_holds integer NOT NULL CHECK(cancelled_holds>=0),foregone_ticket_quote_usd numeric NOT NULL CHECK(foregone_ticket_quote_usd>=0)
);
ALTER TABLE airlinerra_game.section9_disruption_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_flight_disruption_decisions_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_flight_cancellation_receipts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_disruption_release_v1,airlinerra_game.section9_flight_disruption_decisions_v1,airlinerra_game.section9_flight_cancellation_receipts_v1 FROM PUBLIC,anon,authenticated,service_role;
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1 DROP CONSTRAINT section9_dated_flight_occurrences_v1_booking_status_check;
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1 ADD CONSTRAINT section9_dated_flight_occurrences_v1_booking_status_check CHECK(booking_status IN ('not_open','open','closed','cancelled'));
ALTER TABLE airlinerra_game.section9_atomic_itinerary_holds_v1 DROP CONSTRAINT section9_atomic_itinerary_holds_v1_status_check;
ALTER TABLE airlinerra_game.section9_atomic_itinerary_holds_v1 ADD CONSTRAINT section9_atomic_itinerary_holds_v1_status_check CHECK(status IN ('preflight_only','cancelled'));
CREATE OR REPLACE FUNCTION airlinerra_game.section9_assess_technical_disruption_v1(p_occurrence uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE o record; d record; r jsonb; key text; digest bytea; roll numeric; minutes int; v_now timestamptz; physical text;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_DISRUPTION_ASSESSMENT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_disruption_release_v1 WHERE world_id=1 AND decision_enabled) THEN RETURN jsonb_build_object('status','disruption_decisions_not_released','recorded',false);END IF;
 SELECT * INTO d FROM airlinerra_game.section9_flight_disruption_decisions_v1 WHERE occurrence_id=p_occurrence;
 IF FOUND THEN RETURN jsonb_build_object('status','technical_decision_recorded','technicalDelayMinutes',d.technical_delay_minutes,'recorded',false,'replayed',true);END IF;
 SELECT occ.*,a.owner_player_id INTO o FROM airlinerra_game.section9_dated_flight_occurrences_v1 occ JOIN airlinerra_game.airlines a ON a.id=occ.airline_id AND a.world_id=1 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=occ.schedule_id AND s.airline_id=occ.airline_id AND s.version=occ.schedule_version AND s.status='active' AND s.operationally_verified WHERE occ.id=p_occurrence AND occ.world_id=1 AND occ.booking_status='open' AND occ.source_kind='game_verified_saleable_schedule_v1' FOR UPDATE OF occ;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','disruption_occurrence_unavailable','recorded',false);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL OR v_now<o.departure_utc-interval '10 minutes' OR v_now>o.departure_utc+interval '10 minutes' THEN RETURN jsonb_build_object('status','disruption_outside_assessment_window','recorded',false);END IF;
 physical:=o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id=physical) THEN RETURN jsonb_build_object('status','flight_already_operated','recorded',false);END IF;
 r:=airlinerra_game.section9_owned_aircraft_reliability_v1(o.owner_player_id,o.airline_id,o.aircraft_inventory_id);
 IF r->>'status'<>'aircraft_reliability_preview' THEN RETURN jsonb_build_object('status','reliability_unavailable','recorded',false);END IF;
 SELECT decrypted_secret INTO key FROM vault.decrypted_secrets WHERE name='airlinerra_operated_flight_auto_signing_v1';
 IF key IS NULL OR length(key)<64 THEN RETURN jsonb_build_object('status','private_disruption_seed_unavailable','recorded',false);END IF;
 digest:=extensions.hmac(convert_to('airlinerra-disruption-v1:'||physical,'UTF8'),convert_to(key,'UTF8'),'sha256');
 roll:=(get_byte(digest,0)*256+get_byte(digest,1))*100.0/65536;
 minutes:=CASE WHEN roll<(r->>'technicalDelayProbabilityPct')::numeric THEN 15+15*(get_byte(digest,2)%16) ELSE 0 END;
 INSERT INTO airlinerra_game.section9_flight_disruption_decisions_v1(occurrence_id,physical_flight_id,airline_id,aircraft_inventory_id,assessed_at,condition_pct,utilization_pct,overloaded,delay_probability_pct,technical_delay_minutes)
 VALUES(o.id,physical,o.airline_id,o.aircraft_inventory_id,v_now,(r->>'conditionPct')::numeric,(r->>'utilizationPct')::numeric,(r->>'overloaded')::boolean,(r->>'technicalDelayProbabilityPct')::numeric,minutes) ON CONFLICT(occurrence_id) DO NOTHING;
 SELECT * INTO d FROM airlinerra_game.section9_flight_disruption_decisions_v1 WHERE occurrence_id=p_occurrence;
 RETURN jsonb_build_object('status','technical_decision_recorded','technicalDelayMinutes',d.technical_delay_minutes,'recorded',true,'replayed',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_assess_technical_disruption_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_cancel_unflown_occurrence_v1(p_occurrence uuid,p_reason text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
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
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_cancel_unflown_occurrence_v1(uuid,text) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;