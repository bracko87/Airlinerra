-- Airlinerra Phase 1: guarded, GAME-WIDE passenger reservations.
-- No browser, player or direct service_role access to either private writer.
-- All reservations are booked by the verified game demand engine only.
-- Payment/financial ledger remains postponed until the ACTUAL flight
-- completion, preserving existing no-upfront-charge protections.
-- The verified DATE-ONLY game clock supports TOMORROW through 7 days out,
-- not same-day booking. Same-day requires trusted hour-accurate clock proof.
-- No existing status or constraints are relaxed for unauthenticated clients.
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1
 DROP CONSTRAINT section9_dated_flight_occurrences_v1_booking_status_check;
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1
 ADD CONSTRAINT section9_dated_flight_occurrences_v1_booking_status_check
 CHECK (booking_status IN ('not_open','open','closed'));
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1
 DROP CONSTRAINT section9_dated_flight_occurrences_v1_booked_seats_check;
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1
 ADD CONSTRAINT section9_dated_flight_occurrences_v1_booked_seats_check
 CHECK (booked_seats BETWEEN 0 AND coalesce(verified_passenger_seats,0));
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1
 DROP CONSTRAINT section9_dated_flight_occurrences_v1_source_kind_check;
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1
 ADD CONSTRAINT section9_dated_flight_occurrences_v1_source_kind_check
 CHECK (source_kind IN ('verified_schedule_preview_not_saleable',
                       'game_verified_saleable_schedule_v1'));
ALTER TABLE airlinerra_game.section9_dated_flight_occurrences_v1
 ADD CONSTRAINT section9_saleable_occurrence_state_v1
 CHECK ((source_kind='verified_schedule_preview_not_saleable' AND
          booking_status='not_open' AND booked_seats=0)
   OR (source_kind='game_verified_saleable_schedule_v1' AND
       verified_passenger_seats IS NOT NULL AND verified_passenger_seats>0));
ALTER TABLE airlinerra_game.section9_passenger_reservation_batches_v1
 DROP CONSTRAINT section9_passenger_reservation_batches_reservation_status_check;
ALTER TABLE airlinerra_game.section9_passenger_reservation_batches_v1
 ADD CONSTRAINT section9_passenger_reservation_batches_reservation_status_check
 CHECK (reservation_status IN ('unissued','reserved','cancelled'));

CREATE OR REPLACE FUNCTION airlinerra_game.section9_open_verified_game_ticket_occurrence_v1(p_schedule uuid, p_local_date date, p_weekly_entry integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 s record; guard record; execution_guard record; readiness record;
 verified_date date;
 seat record; proof jsonb; capacity record;
 existing record; inserted integer;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_TRUSTED_TICKET_ENGINE_ONLY';END IF;
 IF p_schedule IS NULL OR p_local_date IS NULL OR
    p_weekly_entry IS NULL OR p_weekly_entry NOT BETWEEN 1 AND 7
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_GAME_TICKET_OCCURRENCE';END IF;
 verified_date:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF verified_date IS NULL OR p_local_date<=verified_date
    OR p_local_date>verified_date+7 THEN
  RETURN jsonb_build_object('status','blocked_game_date_or_seven_day_window',
   'opened',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 SELECT release_state,enabled_at,crew_mode INTO guard
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT release_state,enabled_at INTO execution_guard
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO readiness
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF guard.release_state IS DISTINCT FROM 'enabled'
 OR guard.enabled_at IS NULL OR guard.crew_mode IS DISTINCT FROM 'deferred_phase1'
 OR execution_guard.release_state IS DISTINCT FROM 'enabled'
 OR execution_guard.enabled_at IS NULL
 OR readiness.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR readiness.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR readiness.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_unreleased_flight_engine',
  'opened',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 SELECT d.id,d.world_id,d.airline_id,d.aircraft_inventory_id,
  d.version,d.configuration_id,d.status,d.operationally_verified,
  d.origin_airport_key,d.destination_airport_key,
  c.passenger_seats,c.schedule_version,
  c.verification_source,
  commercial.economy_fare_usd,
  commercial.version as commercial_version
 INTO s
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 JOIN airlinerra_game.airline_aircraft_inventory fleet
  ON fleet.id=d.aircraft_inventory_id
   AND fleet.airline_id=d.airline_id AND fleet.fleet_status='in_service'
 JOIN airlinerra_game.section9_verified_schedule_capacity_v1 c
  ON c.schedule_id=d.id AND c.airline_id=d.airline_id
 JOIN airlinerra_game.section9_route_commercial_plans_v1 commercial
  ON commercial.schedule_id=d.id AND commercial.airline_id=d.airline_id
 WHERE d.id=p_schedule
 FOR SHARE OF d,fleet,c,commercial;
 IF NOT FOUND OR s.world_id<>1 OR s.status<>'active'
 OR s.operationally_verified IS DISTINCT FROM true
 OR s.schedule_version IS DISTINCT FROM s.version
 OR length(coalesce(s.verification_source,''))<6
 OR s.passenger_seats IS NULL OR s.passenger_seats<=0
 OR s.economy_fare_usd IS NULL OR s.economy_fare_usd<=0
 OR s.commercial_version IS NULL THEN
  RETURN jsonb_build_object('status','blocked_unverified_schedule_capacity_or_fare',
   'opened',false,'bookingsCreated',false,'ledgerPosted',false);END IF;
 -- This initialization rechecks the ACTUAL matching weekly airport slots,
 -- local dates (including DST), aircraft and commercial version.
 proof:=airlinerra_game.section9_initialize_verified_occurrence_v1(
  p_schedule,p_local_date,p_weekly_entry);
 IF proof->>'status' IS DISTINCT FROM 'capacity_preflight_initialized'
 OR proof->>'bookingsCreated' IS DISTINCT FROM 'false'
 OR proof->>'ledgerPosted' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_TICKET_OCCURRENCE_CAPACITY_PROOF_UNSAFE';END IF;
 SELECT * INTO capacity
 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 c
 WHERE c.physical_flight_id=proof->>'physicalFlightId' FOR UPDATE;
 IF NOT FOUND OR capacity.airline_id IS DISTINCT FROM s.airline_id
 OR capacity.schedule_version IS DISTINCT FROM s.version
 OR capacity.commercial_version IS DISTINCT FROM s.commercial_version
 OR capacity.passenger_capacity IS DISTINCT FROM s.passenger_seats
 OR capacity.passengers_held<>0
 OR capacity.status<>'preflight_only'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_TICKET_CAPACITY_PROOF_CHANGED';END IF;
 -- The schedule must have never departed or arrived before tickets open.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 mv
   WHERE mv.schedule_id=p_schedule AND mv.flight_local_date=p_local_date
    AND mv.weekly_entry=p_weekly_entry)
 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_CANNOT_OPEN_ALREADY_OPERATED_FLIGHT';END IF;
 INSERT INTO airlinerra_game.section9_dated_flight_occurrences_v1(
  world_id,airline_id,schedule_id,aircraft_inventory_id,
  schedule_version,weekly_entry,flight_local_date,
  origin_airport_key,destination_airport_key,
  departure_utc,arrival_utc,turnaround_minutes,
  verified_passenger_seats,booking_status,booked_seats,
  source_kind)
 VALUES(1,s.airline_id,p_schedule,s.aircraft_inventory_id,
  s.version,p_weekly_entry,p_local_date,
  s.origin_airport_key,s.destination_airport_key,
  capacity.departure_utc,capacity.arrival_utc,45,
  s.passenger_seats,'open',0,'game_verified_saleable_schedule_v1')
 ON CONFLICT(schedule_id,flight_local_date,weekly_entry) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 SELECT * INTO existing
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 WHERE o.schedule_id=p_schedule AND o.flight_local_date=p_local_date
  AND o.weekly_entry=p_weekly_entry FOR UPDATE;
 IF NOT FOUND OR existing.world_id<>1
  OR existing.source_kind<>'game_verified_saleable_schedule_v1'
  OR existing.booking_status<>'open'
  OR existing.schedule_version<>s.version
  OR existing.airline_id<>s.airline_id
  OR existing.verified_passenger_seats<>s.passenger_seats
  OR existing.departure_utc<>capacity.departure_utc
  OR existing.arrival_utc<>capacity.arrival_utc
 THEN RAISE EXCEPTION USING ERRCODE='23505',
 MESSAGE='SECTION9_SALEABLE_TICKET_OCCURRENCE_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status','verified_ticket_sales_open',
 'occurrenceId',existing.id,'flightLocalDate',p_local_date,
 'passengerSeats',existing.verified_passenger_seats,
 'existingBookedSeats',existing.booked_seats,
 'newOccurrence',inserted=1,'farePerEconomySeatUsd',s.economy_fare_usd,
 'sevenDayWindowVerified',true,'bookingsCreated',false,
 'ledgerPosted',false,'flightActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_open_verified_game_ticket_occurrence_v1(uuid,date,integer)
 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(p_occurrence uuid, p_reservation_key text, p_fare_class text, p_seats integer)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 row_value record;capacity record;prior record;release_record record;
 execution_record record; readiness record;
 verified_day date; inserted_id uuid; updated_count integer;
BEGIN
 -- This is the signed/verified DEMAND ENGINE's private writer.
 -- A player cannot book fictional passengers to inflate income.
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_PASSENGER_RESERVATION_ENGINE_ONLY';END IF;
 IF p_occurrence IS NULL
 OR p_reservation_key IS NULL OR length(p_reservation_key) NOT BETWEEN 8 AND 100
 OR p_reservation_key !~ '^[A-Za-z0-9._:-]+$'
 OR p_fare_class IS DISTINCT FROM 'economy'
 OR p_seats IS NULL OR p_seats NOT BETWEEN 1 AND 1000 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_PASSENGER_RESERVATION';END IF;

 -- Lock physical occurrence and capacity BEFORE counting seats.
 SELECT o.*,s.status schedule_status,s.operationally_verified,
  s.version AS current_schedule_version,
  f.fleet_status,plan.economy_fare_usd,plan.version AS commercial_version
 INTO row_value
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
 ON s.id=o.schedule_id AND s.airline_id=o.airline_id
 JOIN airlinerra_game.airline_aircraft_inventory f
 ON f.id=o.aircraft_inventory_id AND f.airline_id=o.airline_id
 JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
 ON plan.schedule_id=o.schedule_id AND plan.airline_id=o.airline_id
 WHERE o.id=p_occurrence FOR UPDATE OF o;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','blocked_unknown_flight',
   'reserved',false,'chargedNow',false,'ledgerPosted',false); END IF;

 SELECT * INTO prior FROM airlinerra_game.section9_passenger_reservation_batches_v1 b
 WHERE b.occurrence_id=p_occurrence AND b.reservation_key=p_reservation_key
 FOR UPDATE;
 IF FOUND THEN
  IF prior.fare_class IS DISTINCT FROM p_fare_class
  OR prior.seats_requested IS DISTINCT FROM p_seats
  OR prior.quoted_fare_usd IS DISTINCT FROM row_value.economy_fare_usd
  THEN RAISE EXCEPTION USING ERRCODE='23505',
    MESSAGE='SECTION9_PASSENGER_RESERVATION_REPLAY_MISMATCH'; END IF;
  RETURN jsonb_build_object('status','game_passenger_reservation_replayed',
   'reservationId',prior.id,'reservationStatus',prior.reservation_status,
   'seats',prior.seats_requested,'replayed',true,'reservedNow',false,
   'chargedNow',false,'ledgerPosted',false,'flightActivated',false);
 END IF;

 verified_day:=airlinerra_game.section9_verified_permission_game_day_v1();
 SELECT release_state,enabled_at INTO release_record
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT release_state,enabled_at INTO execution_record
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO readiness
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF verified_day IS NULL
 OR row_value.flight_local_date<=verified_day
 OR row_value.flight_local_date>verified_day+7
 OR release_record.release_state IS DISTINCT FROM 'enabled'
 OR release_record.enabled_at IS NULL
 OR execution_record.release_state IS DISTINCT FROM 'enabled'
 OR execution_record.enabled_at IS NULL
 OR readiness.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR readiness.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR readiness.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_booking_window_or_unreleased_engine',
   'reserved',false,'chargedNow',false,'ledgerPosted',false);END IF;

 SELECT * INTO capacity
 FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 cap
 WHERE cap.physical_flight_id=row_value.schedule_id::text||':'||
  row_value.flight_local_date::text||':'||row_value.weekly_entry::text
 FOR UPDATE;
 IF NOT FOUND OR capacity.schedule_id<>row_value.schedule_id
 OR capacity.airline_id<>row_value.airline_id
 OR capacity.passenger_capacity<>row_value.verified_passenger_seats
 OR capacity.schedule_version<>row_value.schedule_version
 OR capacity.commercial_version<>row_value.commercial_version
 OR capacity.passengers_held<>row_value.booked_seats
 OR capacity.status<>'preflight_only'
 OR row_value.source_kind<>'game_verified_saleable_schedule_v1'
 OR row_value.booking_status<>'open'
 OR row_value.schedule_status<>'active'
 OR row_value.operationally_verified IS DISTINCT FROM true
 OR row_value.current_schedule_version<>row_value.schedule_version
 OR row_value.fleet_status<>'in_service'
 OR row_value.economy_fare_usd IS NULL OR row_value.economy_fare_usd<=0
 OR row_value.verified_passenger_seats IS NULL
 THEN RETURN jsonb_build_object('status','blocked_stale_or_unverified_saleable_inventory',
  'reserved',false,'chargedNow',false,'ledgerPosted',false);END IF;
 IF NOT EXISTS(
 SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slot
 WHERE slot.schedule_id=row_value.schedule_id AND slot.direction='departure')
 OR NOT EXISTS(
 SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slot
 WHERE slot.schedule_id=row_value.schedule_id AND slot.direction='arrival')
 OR EXISTS(
 SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.schedule_id=row_value.schedule_id
 AND m.flight_local_date=row_value.flight_local_date
 AND m.weekly_entry=row_value.weekly_entry)
 THEN RETURN jsonb_build_object('status','blocked_slots_or_flight_already_operated',
   'reserved',false,'chargedNow',false,'ledgerPosted',false);END IF;
 IF p_seats>capacity.passenger_capacity-capacity.passengers_held THEN
 RETURN jsonb_build_object('status','blocked_insufficient_available_seats',
  'availableSeats',capacity.passenger_capacity-capacity.passengers_held,
  'reserved',false,'chargedNow',false,'ledgerPosted',false);END IF;

 UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1
 SET passengers_held=passengers_held+p_seats
 WHERE physical_flight_id=capacity.physical_flight_id
 AND passengers_held=capacity.passengers_held
 AND passenger_capacity>=passengers_held+p_seats;
 GET DIAGNOSTICS updated_count=ROW_COUNT;
 IF updated_count<>1 THEN
  RAISE EXCEPTION USING ERRCODE='40001',
  MESSAGE='SECTION9_PASSENGER_CAPACITY_CHANGED_CONCURRENTLY';END IF;
 UPDATE airlinerra_game.section9_dated_flight_occurrences_v1
 SET booked_seats=booked_seats+p_seats
 WHERE id=p_occurrence AND booked_seats=row_value.booked_seats
 AND booked_seats+p_seats<=verified_passenger_seats;
 GET DIAGNOSTICS updated_count=ROW_COUNT;
 IF updated_count<>1 THEN
  RAISE EXCEPTION USING ERRCODE='40001',
  MESSAGE='SECTION9_PASSENGER_OCCURRENCE_CHANGED_CONCURRENTLY';END IF;

 INSERT INTO airlinerra_game.section9_passenger_reservation_batches_v1(
  occurrence_id,reservation_key,fare_class,seats_requested,
  quoted_fare_usd,reservation_status,paid_upfront,recognized_revenue_usd)
 VALUES(p_occurrence,p_reservation_key,'economy',p_seats,
  row_value.economy_fare_usd,'reserved',false,0)
 RETURNING id INTO inserted_id;

 RETURN jsonb_build_object(
  'status','game_passenger_seats_reserved',
  'reservationId',inserted_id,'occurrenceId',p_occurrence,
  'seatsReservedNow',p_seats,
  'totalSeatsBooked',row_value.booked_seats+p_seats,
  'remainingSeats',capacity.passenger_capacity-capacity.passengers_held-p_seats,
  'economyFarePerSeatUsd',row_value.economy_fare_usd,
  'quotedTotalFareUsd',row_value.economy_fare_usd*p_seats,
  'replayed',false,'chargedNow',false,
  'revenueRecognizedNow',false,'ledgerPosted',false,'flightActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_reserve_verified_game_passenger_seats_v1(uuid,text,text,integer)
 FROM PUBLIC,anon,authenticated,service_role;
