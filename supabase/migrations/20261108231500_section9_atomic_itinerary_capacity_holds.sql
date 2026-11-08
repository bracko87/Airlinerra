-- SECTION 9: PRIVATE, fail-closed physical-occurrence capacity preflight holds.
-- These are NOT tickets, passenger bookings, marketing charges or credits.
-- Activation checks remain unchanged: existing schedule table permits DRAFT ONLY.
-- A future separate verified operations process must enable commercial flights.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_occurrence_capacity_inventory_v1(
 physical_flight_id text PRIMARY KEY,
 schedule_id uuid NOT NULL REFERENCES airlinerra_game.airline_flight_schedule_drafts_v1(id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 local_departure_date date NOT NULL,
 weekly_entry integer NOT NULL CHECK(weekly_entry BETWEEN 1 AND 10000),
 schedule_version integer NOT NULL CHECK(schedule_version>=1),
 commercial_version integer NOT NULL CHECK(commercial_version>=1),
 origin_airport_key text NOT NULL,
 destination_airport_key text NOT NULL,
 departure_utc timestamptz NOT NULL,
 arrival_utc timestamptz NOT NULL,
 passenger_capacity integer NOT NULL CHECK(passenger_capacity BETWEEN 0 AND 1000),
 cargo_capacity_tonnes numeric(12,3) NOT NULL CHECK(cargo_capacity_tonnes BETWEEN 0 AND 1000),
 passengers_held integer NOT NULL DEFAULT 0 CHECK(passengers_held>=0),
 cargo_held_tonnes numeric(12,3) NOT NULL DEFAULT 0 CHECK(cargo_held_tonnes>=0),
 status text NOT NULL DEFAULT 'preflight_only' CHECK(status='preflight_only'),
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT section9_occurrence_inventory_identity CHECK(
  physical_flight_id=schedule_id::text||':'||local_departure_date::text||':'||weekly_entry::text),
 CONSTRAINT section9_occurrence_inventory_route CHECK(
  origin_airport_key<>destination_airport_key AND arrival_utc>departure_utc),
 CONSTRAINT section9_occurrence_inventory_seats CHECK(passengers_held<=passenger_capacity),
 CONSTRAINT section9_occurrence_inventory_cargo CHECK(cargo_held_tonnes<=cargo_capacity_tonnes)
);
ALTER TABLE airlinerra_game.section9_occurrence_capacity_inventory_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_occurrence_capacity_inventory_v1
 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_occurrence_capacity_schedule_idx
 ON airlinerra_game.section9_occurrence_capacity_inventory_v1(schedule_id,local_departure_date);
CREATE INDEX IF NOT EXISTS section9_occurrence_capacity_airline_idx
 ON airlinerra_game.section9_occurrence_capacity_inventory_v1(airline_id,local_departure_date);

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_atomic_itinerary_holds_v1(
 source_allocation_key text PRIMARY KEY
    CHECK(length(source_allocation_key) BETWEEN 8 AND 160
      AND source_allocation_key ~ '^[A-Za-z0-9_.:|/-]+$'),
 physical_flight_ids text[] NOT NULL
   CHECK(cardinality(physical_flight_ids) BETWEEN 1 AND 2),
 passengers integer NOT NULL CHECK(passengers BETWEEN 0 AND 1000),
 cargo_tonnes numeric(12,3) NOT NULL CHECK(cargo_tonnes BETWEEN 0 AND 1000),
 status text NOT NULL DEFAULT 'preflight_only' CHECK(status='preflight_only'),
 created_at timestamptz NOT NULL DEFAULT now(),
 CHECK(passengers>0 OR cargo_tonnes>0)
);
ALTER TABLE airlinerra_game.section9_atomic_itinerary_holds_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_atomic_itinerary_holds_v1
 FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_atomic_itinerary_hold_legs_v1(
 source_allocation_key text NOT NULL REFERENCES
  airlinerra_game.section9_atomic_itinerary_holds_v1(source_allocation_key),
 leg_number smallint NOT NULL CHECK(leg_number BETWEEN 1 AND 2),
 physical_flight_id text NOT NULL REFERENCES
  airlinerra_game.section9_occurrence_capacity_inventory_v1(physical_flight_id),
 PRIMARY KEY(source_allocation_key,leg_number),
 UNIQUE(source_allocation_key,physical_flight_id)
);
ALTER TABLE airlinerra_game.section9_atomic_itinerary_hold_legs_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_atomic_itinerary_hold_legs_v1
 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_atomic_itinerary_hold_flight_idx
 ON airlinerra_game.section9_atomic_itinerary_hold_legs_v1(physical_flight_id);

COMMENT ON TABLE airlinerra_game.section9_atomic_itinerary_holds_v1 IS
 'Only internal preflight capacity holds; no ticket issuance, passenger identity, allocation proof or financial posting.';

-- Register only an activated, version-matched, physically plausible and
-- capacity-verified specific departure. Draft schedules cannot pass.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_initialize_verified_occurrence_v1(
 p_schedule_id uuid,p_local_date date,p_weekly_entry integer
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $function$
DECLARE r record; existing record; weekly_item jsonb;
 local_departure timestamp; actual_departure timestamptz;
 actual_arrival timestamptz; physical_id text;
 expected_slots integer; matched_slots integer;
 dep_slots integer; arr_slots integer; inserted integer;
BEGIN
 IF p_schedule_id IS NULL OR p_local_date IS NULL OR
   p_local_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01' OR
   p_weekly_entry NOT BETWEEN 1 AND 10000
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_VERIFIED_OCCURRENCE_INPUT'; END IF;
 SELECT d.id,d.world_id,d.airline_id,d.status,d.operationally_verified,
  d.version,d.weekly_schedule,d.origin_airport_key,d.destination_airport_key,
  d.reference_departure_utc,d.reference_arrival_utc,
  d.departure_stand_type,d.arrival_stand_type,
  f.fleet_status,f.configuration_id AS fleet_configuration,d.configuration_id,
  cap.schedule_version AS capacity_version,cap.passenger_seats,
  cap.cargo_capacity_tonnes,cap.verification_source,
  plan.version AS commercial_version,
  tz.timezone_iana AS origin_timezone
 INTO r
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=d.aircraft_inventory_id AND f.airline_id=d.airline_id
 JOIN airlinerra_game.section9_verified_schedule_capacity_v1 cap
  ON cap.schedule_id=d.id AND cap.airline_id=d.airline_id
 JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
  ON plan.schedule_id=d.id AND plan.airline_id=d.airline_id
 JOIN airlinerra_game.airport_reference_profiles tz
  ON tz.world_id=d.world_id AND tz.airport_key=d.origin_airport_key
 WHERE d.id=p_schedule_id
 FOR SHARE OF d,f,cap,plan;
 IF NOT FOUND OR r.world_id<>1 OR r.status<>'active'
    OR r.operationally_verified IS DISTINCT FROM true OR
    r.fleet_status<>'in_service' OR
    r.fleet_configuration<>r.configuration_id OR
    r.capacity_version<>r.version OR
    length(coalesce(r.verification_source,''))<6 OR
    r.origin_timezone IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_FLIGHT_ACTIVATION_OR_PAYLOAD_UNVERIFIED'; END IF;
 IF jsonb_typeof(r.weekly_schedule)<>'array' OR
   p_weekly_entry>jsonb_array_length(r.weekly_schedule)
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_WEEKLY_ENTRY_MISSING'; END IF;
 weekly_item:=r.weekly_schedule->(p_weekly_entry-1);
 IF jsonb_typeof(weekly_item)<>'object' OR
  coalesce(weekly_item->>'day','') !~ '^[0-6]$' OR
  coalesce(weekly_item->>'time','') !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$' OR
  (weekly_item->>'day')::integer<>extract(isodow from p_local_date)::integer-1
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_WEEKLY_FLIGHT_NOT_ON_DATE'; END IF;
 local_departure:=p_local_date::timestamp+(weekly_item->>'time')::time::interval;
 actual_departure:=local_departure AT TIME ZONE r.origin_timezone;
 IF (actual_departure AT TIME ZONE r.origin_timezone) IS DISTINCT FROM
   local_departure OR
   (actual_departure-interval '1 hour') AT TIME ZONE r.origin_timezone =
      local_departure OR
   (actual_departure+interval '1 hour') AT TIME ZONE r.origin_timezone =
      local_departure
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_AMBIGUOUS_OR_INVALID_LOCAL_DEPARTURE'; END IF;
 actual_arrival:=actual_departure+
  (r.reference_arrival_utc-r.reference_departure_utc);
 -- The ORIGINAL saved weekly slot proposal (all departures and arrivals)
 -- must match the exact currently reserved airport/time/stand windows.
 WITH expected AS (
  SELECT DISTINCT e.airport_key,e.stand_type,e.direction,e.weekday,e.minute_of_day
  FROM airlinerra_game.section6_weekly_slot_proposals_v1(
   1::smallint,r.origin_airport_key,r.destination_airport_key,
   r.reference_departure_utc,r.reference_arrival_utc,r.weekly_schedule,
   r.departure_stand_type,r.arrival_stand_type) e
 )
 SELECT count(*)::int,
  count(*) FILTER(WHERE EXISTS (
   SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 z
   WHERE z.schedule_id=r.id AND z.world_id=1
    AND z.airport_key=e.airport_key AND z.stand_type=e.stand_type
    AND z.direction=e.direction AND z.weekday=e.weekday
    AND z.minute_of_day=e.minute_of_day))::int,
  count(*) FILTER(WHERE e.direction='departure')::int,
  count(*) FILTER(WHERE e.direction='arrival')::int
 INTO expected_slots,matched_slots,dep_slots,arr_slots FROM expected e;
 IF expected_slots=0 OR matched_slots<>expected_slots OR
    dep_slots=0 OR arr_slots=0
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_WEEKLY_AIRPORT_SLOT_PROOFS_MISSING'; END IF;
 physical_id:=r.id::text||':'||p_local_date::text||':'||p_weekly_entry::text;
 INSERT INTO airlinerra_game.section9_occurrence_capacity_inventory_v1(
  physical_flight_id,schedule_id,airline_id,local_departure_date,
  weekly_entry,schedule_version,commercial_version,
  origin_airport_key,destination_airport_key,departure_utc,arrival_utc,
  passenger_capacity,cargo_capacity_tonnes)
 VALUES(physical_id,r.id,r.airline_id,p_local_date,p_weekly_entry,
  r.version,r.commercial_version,r.origin_airport_key,
  r.destination_airport_key,actual_departure,actual_arrival,
  r.passenger_seats,r.cargo_capacity_tonnes)
 ON CONFLICT(physical_flight_id) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 SELECT * INTO existing FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
 WHERE physical_flight_id=physical_id FOR SHARE;
 IF NOT FOUND OR existing.schedule_version<>r.version OR
  existing.commercial_version<>r.commercial_version OR
  existing.airline_id<>r.airline_id OR
  existing.passenger_capacity<>r.passenger_seats OR
  existing.cargo_capacity_tonnes<>r.cargo_capacity_tonnes OR
  existing.origin_airport_key<>r.origin_airport_key OR
  existing.destination_airport_key<>r.destination_airport_key OR
  existing.departure_utc<>actual_departure OR
  existing.arrival_utc<>actual_arrival
 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_OCCURRENCE_PROOF_VERSION_CONFLICT'; END IF;
 RETURN jsonb_build_object('physicalFlightId',physical_id,
  'status','capacity_preflight_initialized','inserted',inserted=1,
  'passengerSeats',existing.passenger_capacity,
  'cargoTonnes',existing.cargo_capacity_tonnes,
  'readOnlyForPlayers',true,'bookingsCreated',false,'ledgerPosted',false);
END $function$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_initialize_verified_occurrence_v1(uuid,date,integer)
 FROM PUBLIC,anon,authenticated;

-- One database transaction either reserves BOTH physical flight legs,
-- or none. Deterministic locks avoid opposite-order deadlocks.
-- The source allocation key is an INTERNAL idempotency key, not proof that
-- demand has been allocated. No end-user booking or revenue occurs here.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_hold_verified_itinerary_v1(
 p_source_allocation_key text,p_flight_ids text[],
 p_passengers integer,p_cargo_tonnes numeric
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $function$
DECLARE existing record; first_leg record;second_leg record; v record;
 id text; sorted_ids text[];n integer; idx integer:=0;inserted integer;
 mct integer;layover_minutes numeric;owner_airline uuid;
BEGIN
 IF p_source_allocation_key IS NULL OR
  length(p_source_allocation_key) NOT BETWEEN 8 AND 160 OR
  p_source_allocation_key !~ '^[A-Za-z0-9_.:|/-]+$' OR
  p_flight_ids IS NULL OR cardinality(p_flight_ids) NOT BETWEEN 1 AND 2
  OR array_position(p_flight_ids,NULL) IS NOT NULL OR
  (cardinality(p_flight_ids)=2 AND p_flight_ids[1]=p_flight_ids[2])
  OR p_passengers IS NULL OR p_passengers NOT BETWEEN 0 AND 1000 OR
  p_cargo_tonnes IS NULL OR p_cargo_tonnes NOT BETWEEN 0 AND 1000
  OR (p_passengers=0 AND p_cargo_tonnes=0)
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_ATOMIC_HOLD_REQUEST'; END IF;

 -- Serialize identical allocation keys. A replay with identical amounts
 -- must NEVER consume more capacity; a changed replay must raise.
 SELECT * INTO existing FROM airlinerra_game.section9_atomic_itinerary_holds_v1
 WHERE source_allocation_key=p_source_allocation_key FOR UPDATE;
 IF FOUND THEN
  IF existing.physical_flight_ids<>p_flight_ids OR
   existing.passengers<>p_passengers OR
   existing.cargo_tonnes<>p_cargo_tonnes
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_HOLD_IDEMPOTENCY_CONFLICT'; END IF;
  RETURN jsonb_build_object('status','preflight_held',
   'replayed',true,'sourceAllocationKey',p_source_allocation_key,
   'bookingsCreated',false,'ledgerPosted',false);
 END IF;

 SELECT array_agg(x ORDER BY x) INTO sorted_ids
 FROM unnest(p_flight_ids) x;
 -- Lock active source schedule rows in stable order FIRST, then inventories.
 -- Never allow a concurrent version/configuration change during reservation.
 FOR v IN
  SELECT d.id FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
  JOIN airlinerra_game.section9_occurrence_capacity_inventory_v1 i
   ON i.schedule_id=d.id
  WHERE i.physical_flight_id=ANY(p_flight_ids)
  GROUP BY d.id ORDER BY d.id
 LOOP
  PERFORM 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
   WHERE d.id=v.id FOR SHARE;
 END LOOP;
 FOREACH id IN ARRAY sorted_ids LOOP
  SELECT i.* INTO v FROM airlinerra_game.section9_occurrence_capacity_inventory_v1 i
   WHERE i.physical_flight_id=id FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_OCCURRENCE_NOT_OPERATIONALLY_VERIFIED';END IF;
  IF NOT EXISTS (
   SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
   JOIN airlinerra_game.section9_verified_schedule_capacity_v1 cap
    ON cap.schedule_id=d.id AND cap.airline_id=d.airline_id
   JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
    ON plan.schedule_id=d.id AND plan.airline_id=d.airline_id
   JOIN airlinerra_game.airline_aircraft_inventory a
    ON a.id=d.aircraft_inventory_id AND a.airline_id=d.airline_id
   WHERE d.id=v.schedule_id AND d.status='active'
    AND d.operationally_verified IS TRUE AND a.fleet_status='in_service'
    AND v.airline_id=d.airline_id
    AND v.schedule_version=d.version
    AND v.schedule_version=cap.schedule_version
    AND v.commercial_version=plan.version
    AND v.passenger_capacity=cap.passenger_seats
    AND v.cargo_capacity_tonnes=cap.cargo_capacity_tonnes
  ) THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_OCCURRENCE_VERSION_OR_ACTIVATION_CHANGED';END IF;
  IF v.passengers_held+p_passengers>v.passenger_capacity OR
   v.cargo_held_tonnes+p_cargo_tonnes>v.cargo_capacity_tonnes
  THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_ATOMIC_FLIGHT_CAPACITY_EXCEEDED';END IF;
 END LOOP;

 SELECT * INTO first_leg FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
 WHERE physical_flight_id=p_flight_ids[1];
 IF cardinality(p_flight_ids)=2 THEN
  SELECT * INTO second_leg FROM airlinerra_game.section9_occurrence_capacity_inventory_v1
   WHERE physical_flight_id=p_flight_ids[2];
  SELECT minimum_transfer_minutes INTO mct
  FROM airlinerra_game.section9_airport_transfer_policy_v1
  WHERE world_id=1 AND airport_key=first_leg.destination_airport_key;
  layover_minutes:=extract(epoch FROM
     (second_leg.departure_utc-first_leg.arrival_utc))/60;
  IF first_leg.destination_airport_key<>second_leg.origin_airport_key
    OR mct IS NULL OR layover_minutes<mct OR layover_minutes>720
    OR first_leg.departure_utc>=second_leg.departure_utc
  THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_TWO_LEG_CONNECTION'; END IF;
  IF p_cargo_tonnes>0 AND NOT EXISTS (
   SELECT 1 FROM airlinerra_game.airport_facilities f
   WHERE f.world_id=1 AND f.airport_key=first_leg.destination_airport_key
    AND f.cargo_handling_available IS TRUE)
  THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_CARGO_TRANSFER_NOT_SUPPORTED';END IF;
  IF first_leg.airline_id<>second_leg.airline_id
    AND NOT EXISTS (
      SELECT 1 FROM airlinerra_game.section9_interline_agreements_v1 ag
      WHERE ag.world_id=1 AND ag.agreement_status='active'
       AND ag.left_approved_at IS NOT NULL AND ag.right_approved_at IS NOT NULL
       AND ((ag.left_airline_id=first_leg.airline_id AND
             ag.right_airline_id=second_leg.airline_id)
         OR (ag.right_airline_id=first_leg.airline_id AND
             ag.left_airline_id=second_leg.airline_id))
       AND ag.valid_from<=first_leg.departure_utc
       AND (ag.valid_until IS NULL OR ag.valid_until>second_leg.arrival_utc)
    )
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_BILATERAL_CONNECTION_NOT_AUTHORIZED';END IF;
 END IF;
 INSERT INTO airlinerra_game.section9_atomic_itinerary_holds_v1(
  source_allocation_key,physical_flight_ids,passengers,cargo_tonnes)
 VALUES(p_source_allocation_key,p_flight_ids,p_passengers,p_cargo_tonnes)
 ON CONFLICT(source_allocation_key) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 IF inserted=0 THEN
  SELECT * INTO existing FROM airlinerra_game.section9_atomic_itinerary_holds_v1
  WHERE source_allocation_key=p_source_allocation_key;
  IF existing.physical_flight_ids IS DISTINCT FROM p_flight_ids OR
   existing.passengers IS DISTINCT FROM p_passengers OR
   existing.cargo_tonnes IS DISTINCT FROM p_cargo_tonnes
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_HOLD_IDEMPOTENCY_CONFLICT';END IF;
  RETURN jsonb_build_object('status','preflight_held','replayed',true,
   'sourceAllocationKey',p_source_allocation_key,
   'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 FOR idx IN 1..cardinality(p_flight_ids) LOOP
  INSERT INTO airlinerra_game.section9_atomic_itinerary_hold_legs_v1(
   source_allocation_key,leg_number,physical_flight_id)
  VALUES(p_source_allocation_key,idx,p_flight_ids[idx]);
 END LOOP;
 FOREACH id IN ARRAY sorted_ids LOOP
  UPDATE airlinerra_game.section9_occurrence_capacity_inventory_v1
  SET passengers_held=passengers_held+p_passengers,
   cargo_held_tonnes=cargo_held_tonnes+p_cargo_tonnes
  WHERE physical_flight_id=id
   AND passengers_held+p_passengers<=passenger_capacity
   AND cargo_held_tonnes+p_cargo_tonnes<=cargo_capacity_tonnes;
  GET DIAGNOSTICS inserted=ROW_COUNT;
  IF inserted<>1 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_ATOMIC_RESERVATION_CAPACITY_CONFLICT';END IF;
 END LOOP;
 RETURN jsonb_build_object('status','preflight_held','replayed',false,
  'sourceAllocationKey',p_source_allocation_key,'legs',cardinality(p_flight_ids),
  'passengers',p_passengers,'cargoTonnes',p_cargo_tonnes,
  'bookingsCreated',false,'ledgerPosted',false,'readOnlyForPlayers',true);
END $function$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_hold_verified_itinerary_v1(
 text,text[],integer,numeric) FROM PUBLIC,anon,authenticated;
