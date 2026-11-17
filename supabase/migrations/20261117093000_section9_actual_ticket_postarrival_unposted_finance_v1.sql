-- Airlinerra: actual-ticket post-arrival financial preparation.
-- Replaces the three-forecast dependency for NEW signed-arrival game flights,
-- but stores only an UNPOSTED, PROVISIONAL estimate (no earned revenue).
-- Flight must have actual booked seats, completed signed movements, matching
-- aircraft usage receipt, validated game hour and the read-only cost quote.
-- A single unique physical-flight key and immutable proofs stop duplicate work.
-- Flight fuel model, reserve and accounting release remain NOT APPROVED.
-- This migration neither changes those release flags nor credits/debits money.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_actual_ticket_finance_preparations_v1(
 physical_flight_id text PRIMARY KEY CHECK (
  physical_flight_id ~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 schedule_id uuid NOT NULL REFERENCES airlinerra_game.airline_flight_schedule_drafts_v1(id),
 flight_local_date date NOT NULL,
 arrival_event_id text NOT NULL UNIQUE REFERENCES
  airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 aircraft_usage_receipt_flight_id text NOT NULL UNIQUE REFERENCES
  airlinerra_game.section9_arrived_aircraft_usage_receipts_v1(physical_flight_id),
 passenger_count integer NOT NULL CHECK(passenger_count BETWEEN 0 AND 1000),
 ticket_quote_usd numeric(16,2) NOT NULL CHECK(ticket_quote_usd>=0),
 provisional_fuel_cost_usd numeric(16,2) NOT NULL CHECK(provisional_fuel_cost_usd>=0),
 provisional_airport_cost_usd numeric(16,2) NOT NULL CHECK(provisional_airport_cost_usd>=0),
 provisional_operating_cost_usd numeric(16,2) NOT NULL CHECK(
   provisional_operating_cost_usd=provisional_fuel_cost_usd+provisional_airport_cost_usd),
 ticket_reconciliation_proof jsonb NOT NULL CHECK(jsonb_typeof(ticket_reconciliation_proof)='object'),
 provisional_game_cost_proof jsonb NOT NULL CHECK(jsonb_typeof(provisional_game_cost_proof)='object'),
 source_version text NOT NULL DEFAULT 'ACTUAL_TICKET_POSTARRIVAL_PREP_V1'
 CHECK(source_version='ACTUAL_TICKET_POSTARRIVAL_PREP_V1'),
 preparation_status text NOT NULL DEFAULT 'UNPOSTED_GAME_ESTIMATE'
 CHECK(preparation_status='UNPOSTED_GAME_ESTIMATE'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CONSTRAINT actual_ticket_preparation_physical_identity_v1 CHECK (
   physical_flight_id=schedule_id::text||':'||flight_local_date::text||':'||
     split_part(physical_flight_id,':',3)),
 CONSTRAINT actual_ticket_preparation_same_usage_flight_v1 CHECK (
   aircraft_usage_receipt_flight_id=physical_flight_id)
);
ALTER TABLE airlinerra_game.section9_actual_ticket_finance_preparations_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_actual_ticket_finance_preparations_v1
 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_prepare_actual_ticket_postarrival_finance_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 occurrence record;
 receipt record;
 arrival record;
 old record;
 review jsonb;
 quote jsonb;
 now_guard jsonb;
 actual_seats integer;
 ticket_income numeric(16,2);
 fuel_est numeric(16,2);
 airport_est numeric(16,2);
 total_est numeric(16,2);
 inserted integer;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_VERIFIED_ARRIVAL_PREPARATION_TRUSTED_WORKER_ONLY';
 END IF;
 IF p_physical_flight_id IS NULL
 OR p_physical_flight_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_ACTUAL_TICKET_FINANCE_PHYSICAL_FLIGHT_ID';END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(
  583729,pg_catalog.hashtext(p_physical_flight_id))
 THEN RETURN jsonb_build_object('status','finance_preparation_running',
   'created',false,'ledgerPosted',false,'flightActivated',false);END IF;

 SELECT o.id,o.schedule_id,o.airline_id,o.flight_local_date,o.weekly_entry,
   o.booked_seats,o.verified_passenger_seats,o.booking_status,o.source_kind,
   s.status AS schedule_status,s.operationally_verified,
   o.schedule_version,s.version AS current_schedule_version,
   cap.cargo_held_tonnes,cap.passengers_held
 INTO occurrence
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s
  ON s.id=o.schedule_id AND s.airline_id=o.airline_id
 JOIN airlinerra_game.section9_occurrence_capacity_inventory_v1 cap
  ON cap.physical_flight_id=p_physical_flight_id
  AND cap.schedule_id=o.schedule_id AND cap.airline_id=o.airline_id
 WHERE o.schedule_id=split_part(p_physical_flight_id,':',1)::uuid
 AND o.flight_local_date=split_part(p_physical_flight_id,':',2)::date
 AND o.weekly_entry=split_part(p_physical_flight_id,':',3)::int
 FOR SHARE OF o,s,cap;
 IF NOT FOUND OR occurrence.booking_status<>'closed'
 OR occurrence.source_kind<>'game_verified_saleable_schedule_v1'
 OR occurrence.schedule_status<>'active'
 OR occurrence.operationally_verified IS DISTINCT FROM true
 OR occurrence.schedule_version IS DISTINCT FROM occurrence.current_schedule_version
 OR occurrence.verified_passenger_seats IS NULL
 OR occurrence.verified_passenger_seats<1
 OR occurrence.booked_seats>occurrence.verified_passenger_seats
 OR occurrence.passengers_held<occurrence.booked_seats
 OR occurrence.cargo_held_tonnes IS DISTINCT FROM 0
 THEN RETURN jsonb_build_object('status','blocked_unverified_arrival_or_unsupported_cargo',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;

 SELECT r.* INTO receipt
 FROM airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 r
 WHERE r.physical_flight_id=p_physical_flight_id;
 SELECT m.* INTO arrival
 FROM airlinerra_game.section9_operated_flight_movements_v1 m
 WHERE m.flight_occurrence_id=p_physical_flight_id
 AND m.phase='arrived';
 IF receipt.physical_flight_id IS NULL OR arrival.engine_event_id IS NULL
 OR receipt.airline_id<>occurrence.airline_id
 OR arrival.airline_id<>occurrence.airline_id
 OR receipt.arrived_engine_event_id<>arrival.engine_event_id
 OR receipt.source_kind<>'signed_operated_game_arrival_usage_v1'
 THEN RETURN jsonb_build_object('status','blocked_missing_signed_arrival_and_aircraft_usage',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;
 now_guard:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF now_guard->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 OR arrival.actual_event_utc>(now_guard->>'gameHourUtc')::timestamptz
 THEN RETURN jsonb_build_object('status','blocked_unverified_postarrival_game_hour',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1
 WHERE physical_flight_id=p_physical_flight_id)
 THEN RETURN jsonb_build_object('status','blocked_already_posted_do_not_prepare_twice',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;

 review:=airlinerra_game.section9_postarrival_ticket_reconciliation_v1(
  p_physical_flight_id);
 quote:=airlinerra_game.section9_completed_flight_game_cost_preview_v1(
  p_physical_flight_id);
 IF review->>'status' IS DISTINCT FROM 'postarrival_ticket_totals_reconciled'
 OR review->>'reconciled' IS DISTINCT FROM 'true'
 OR review->>'ledgerPosted' IS DISTINCT FROM 'false'
 OR review->>'financeAlreadyPosted' IS DISTINCT FROM 'false'
 OR quote->>'status' IS DISTINCT FROM 'game_only_completed_flight_cost_estimate'
 OR quote->>'sourceVersion' IS DISTINCT FROM 'GAME_COST_PREVIEW_V1_NEVER_POST'
 OR quote->>'readOnly' IS DISTINCT FROM 'true'
 OR quote->>'ledgerPosted' IS DISTINCT FROM 'false'
 OR quote->>'readyForActualExpensePosting' IS DISTINCT FROM 'false'
 OR quote->>'accountingApproved' IS DISTINCT FROM 'false'
 THEN RETURN jsonb_build_object('status','blocked_ticket_or_provisional_cost_evidence',
  'ticketProofStatus',review->>'status',
  'costProofStatus',quote->>'status',
  'created',false,'ledgerPosted',false,'flightActivated',false);END IF;
 IF review->>'physicalFlightId' IS DISTINCT FROM p_physical_flight_id
 OR quote->>'physicalFlightId' IS DISTINCT FROM p_physical_flight_id
 OR (quote->>'bookedPassengers')::integer
   IS DISTINCT FROM (review->>'ticketPassengers')::integer
 OR (quote->>'quotedTicketFareUsd')::numeric
   IS DISTINCT FROM (review->>'ticketIncomeUsd')::numeric
 THEN RAISE EXCEPTION USING ERRCODE='23505',
 MESSAGE='SECTION9_POSTARRIVAL_TICKET_COST_PROOFS_DISAGREE';END IF;

 actual_seats:=(review->>'ticketPassengers')::integer;
 ticket_income:=(review->>'ticketIncomeUsd')::numeric(16,2);
 fuel_est:=(quote->>'fuelCostEstimateUsd')::numeric(16,2);
 airport_est:=(quote->>'airportCostEstimateUsd')::numeric(16,2);
 total_est:=(quote->>'operatingCostEstimateUsd')::numeric(16,2);
 IF actual_seats<>occurrence.booked_seats
 OR ticket_income<0 OR ticket_income>1000000000
 OR fuel_est<=0 OR fuel_est>100000000
 OR airport_est<0 OR airport_est>100000000
 OR total_est IS DISTINCT FROM fuel_est+airport_est
 THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_POSTARRIVAL_FINANCE_GAME_ESTIMATE_INCONSISTENT';END IF;
 INSERT INTO airlinerra_game.section9_actual_ticket_finance_preparations_v1(
  physical_flight_id,airline_id,schedule_id,flight_local_date,
  arrival_event_id,aircraft_usage_receipt_flight_id,
  passenger_count,ticket_quote_usd,
  provisional_fuel_cost_usd,provisional_airport_cost_usd,
  provisional_operating_cost_usd,ticket_reconciliation_proof,
  provisional_game_cost_proof
 ) VALUES(
  p_physical_flight_id,occurrence.airline_id,occurrence.schedule_id,
  occurrence.flight_local_date,arrival.engine_event_id,receipt.physical_flight_id,
  actual_seats,ticket_income,fuel_est,airport_est,total_est,review,quote
 )
 ON CONFLICT(physical_flight_id) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 SELECT * INTO old
 FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1
 WHERE physical_flight_id=p_physical_flight_id FOR UPDATE;
 IF NOT FOUND OR old.airline_id IS DISTINCT FROM occurrence.airline_id
 OR old.schedule_id IS DISTINCT FROM occurrence.schedule_id
 OR old.flight_local_date IS DISTINCT FROM occurrence.flight_local_date
 OR old.arrival_event_id IS DISTINCT FROM arrival.engine_event_id
 OR old.aircraft_usage_receipt_flight_id IS DISTINCT FROM receipt.physical_flight_id
 OR old.passenger_count IS DISTINCT FROM actual_seats
 OR old.ticket_quote_usd IS DISTINCT FROM ticket_income
 OR old.provisional_fuel_cost_usd IS DISTINCT FROM fuel_est
 OR old.provisional_airport_cost_usd IS DISTINCT FROM airport_est
 OR old.provisional_operating_cost_usd IS DISTINCT FROM total_est
 OR old.ticket_reconciliation_proof IS DISTINCT FROM review
 OR old.provisional_game_cost_proof IS DISTINCT FROM quote
 OR old.preparation_status<>'UNPOSTED_GAME_ESTIMATE'
 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_REPLAYED_ACTUAL_FINANCE_PREPARATION_PROOF_CHANGED';END IF;
 RETURN jsonb_build_object(
  'status',CASE WHEN inserted=1 THEN 'actual_ticket_estimate_prepared'
   ELSE 'actual_ticket_estimate_replayed' END,
  'physicalFlightId',p_physical_flight_id,
  'passengers',actual_seats,
  'ticketIncomeEstimateUsd',ticket_income,
  'fuelCostEstimateUsd',fuel_est,
  'airportCostEstimateUsd',airport_est,
  'gameOperatingCostEstimateUsd',total_est,
  'created',inserted=1,'replayed',inserted=0,
  'source','SIGNED_ARRIVAL_BOOKED_TICKETS_PROVISIONAL_GAME_TARIFF',
  'requiresFuelAccountingRelease',true,
  'awaitsIndependentFinancialSettlement',true,
  'readyToPost',false,'ledgerPosted',false,'flightActivated',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_prepare_actual_ticket_postarrival_finance_v1(text)
 FROM PUBLIC,anon,authenticated,service_role;
