-- Route-level finance: trusted posted history plus read-only draft forecast.
-- Approved Section8 GAME costs are retained; NO real money is posted.
-- No fictitious "completed" flights may enter a player's route history.
CREATE TABLE airlinerra_game.section9_route_posted_flight_financials_v1 (
 physical_flight_id text PRIMARY KEY
  CHECK(length(physical_flight_id) BETWEEN 25 AND 180),
 schedule_id uuid NOT NULL REFERENCES
  airlinerra_game.airline_flight_schedule_drafts_v1(id) ON DELETE RESTRICT,
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 flown_game_day date NOT NULL CHECK(flown_game_day BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'),
 arrived_event_id text NOT NULL UNIQUE REFERENCES
  airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 passenger_count integer NOT NULL CHECK(passenger_count BETWEEN 0 AND 1000),
 cargo_tonnes numeric(10,2) NOT NULL CHECK(cargo_tonnes BETWEEN 0 AND 500),
 ticket_income_usd numeric(14,2) NOT NULL CHECK(ticket_income_usd>=0),
 cargo_income_usd numeric(14,2) NOT NULL CHECK(cargo_income_usd>=0),
 other_income_usd numeric(14,2) NOT NULL DEFAULT 0 CHECK(other_income_usd>=0),
 airport_navigation_cost_usd numeric(14,2) NOT NULL CHECK(airport_navigation_cost_usd>=0),
 fuel_cost_usd numeric(14,2) NOT NULL CHECK(fuel_cost_usd>=0),
 crew_cost_usd numeric(14,2) NOT NULL CHECK(crew_cost_usd>=0),
 maintenance_cost_usd numeric(14,2) NOT NULL CHECK(maintenance_cost_usd>=0),
 ownership_cost_usd numeric(14,2) NOT NULL CHECK(ownership_cost_usd>=0),
 other_cost_usd numeric(14,2) NOT NULL DEFAULT 0 CHECK(other_cost_usd>=0),
 airport_fee_lines jsonb NOT NULL
   CHECK(jsonb_typeof(airport_fee_lines)='object'),
 revenue_ledger_id bigint NOT NULL UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 expense_ledger_id bigint NOT NULL UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 tariff_model_version text NOT NULL CHECK(length(tariff_model_version)>12),
 settlement_source_reference text NOT NULL CHECK(length(settlement_source_reference)>15),
 record_status text NOT NULL DEFAULT 'posted_complete'
   CHECK(record_status='posted_complete'),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(revenue_ledger_id<>expense_ledger_id),
 CHECK(physical_flight_id LIKE schedule_id::text||':%')
);
ALTER TABLE airlinerra_game.section9_route_posted_flight_financials_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_route_posted_flight_financials_v1
 FROM PUBLIC,anon,authenticated;
CREATE INDEX section9_route_posted_flights_recent_idx
 ON airlinerra_game.section9_route_posted_flight_financials_v1
 (airline_id,schedule_id,flown_game_day DESC,recorded_at DESC,physical_flight_id DESC);
CREATE TRIGGER section9_route_posted_flights_append_only
 BEFORE UPDATE OR DELETE ON airlinerra_game.section9_route_posted_flight_financials_v1
 FOR EACH ROW EXECUTE FUNCTION
  airlinerra_game.section9_reject_certificate_audit_mutation_v1();
COMMENT ON TABLE airlinerra_game.section9_route_posted_flight_financials_v1 IS
 'FUTURE trusted settlement snapshots only. No public writer or producer deployed. Reader accepts snapshots only with signed ARRIVED movement and two reconciled posted airline ledger entries. Full detail retained privately for audit; page returns last seven only and aggregates older flights.';

CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_route_financial_dashboard_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,
 p_load_percent integer DEFAULT 100,p_parking_minutes integer DEFAULT 180
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path=airlinerra_game,airlinerra,pg_catalog
AS $f$
DECLARE sch record;cm record;capacity record;quote jsonb;
 pax integer;cargo numeric(10,2);
 ticket numeric(14,2);freight numeric(14,2);income numeric(14,2);
 partial_margin numeric(14,2);
 hist jsonb;fee_total numeric(14,2);
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_schedule IS NULL OR
   p_load_percent IS NULL OR p_load_percent NOT BETWEEN 0 AND 100 OR
   p_parking_minutes IS NULL OR p_parking_minutes NOT BETWEEN 0 AND 10080
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_ROUTE_FINANCE_REQUEST';END IF;
 SELECT s.* INTO sch
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a ON a.id=s.airline_id
 WHERE s.id=p_schedule AND s.airline_id=p_airline
  AND s.world_id=1 AND a.world_id=1 AND a.owner_player_id=p_player;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_ROUTE_FINANCIALS_NOT_OWNED';END IF;
 SELECT * INTO cm
 FROM airlinerra_game.section9_route_commercial_plans_v1
 WHERE schedule_id=p_schedule AND airline_id=p_airline;
 SELECT simultaneous_passenger_seats,simultaneous_freight_kg
 INTO capacity
 FROM airlinerra.aircraft_service_payload_game_v1
 WHERE configuration_id=sch.configuration_id;
 IF NOT FOUND OR capacity.simultaneous_passenger_seats IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_ROUTE_FINANCIAL_CAPACITY_UNKNOWN';END IF;
 pax:=round(capacity.simultaneous_passenger_seats*p_load_percent/100.0);
 cargo:=round(least(500::numeric,
  coalesce(capacity.simultaneous_freight_kg,0)::numeric/1000)
  *p_load_percent/100.0,2);
 quote:=airlinerra_game.section8_quote_flight_operating_fees_v1(
  1::smallint,sch.origin_airport_key,sch.destination_airport_key,
  sch.configuration_id,sch.departure_stand_type,
  sch.arrival_stand_type,pax,cargo,p_parking_minutes);
 IF quote->>'status'<>'game_operating_fee_preview_only' OR
   quote->>'cashPosted'<>'false' OR
   quote->>'canPostToLedger'<>'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_FINANCE_UNSAFE_AIRPORT_FEE_QUOTE';END IF;
 fee_total:=(quote->>'totalGameOperatingFeesUsd')::numeric;
 ticket:=CASE WHEN pax=0 THEN 0 WHEN cm.economy_fare_usd IS NULL
  THEN NULL ELSE round(pax*cm.economy_fare_usd,2) END;
 freight:=CASE WHEN cargo=0 THEN 0 WHEN cm.cargo_rate_usd_per_tonne IS NULL
  THEN NULL ELSE round(cargo*cm.cargo_rate_usd_per_tonne,2) END;
 income:=CASE WHEN ticket IS NULL OR freight IS NULL
  THEN NULL ELSE ticket+freight END;
 partial_margin:=CASE WHEN income IS NULL THEN NULL
   ELSE income-fee_total END;

 -- "Actual" is a stricter status than prepared/forecast revenue.
 -- Require signed arrived flight, both posted and fully matching ledgers,
 -- source-identified immutable settlement, all cost categories present.
 WITH verified AS (
  SELECT f.*,(
   f.ticket_income_usd+f.cargo_income_usd+f.other_income_usd
  ) AS total_revenue,(
   f.airport_navigation_cost_usd+f.fuel_cost_usd+f.crew_cost_usd+
   f.maintenance_cost_usd+f.ownership_cost_usd+f.other_cost_usd
  ) AS total_cost
  FROM airlinerra_game.section9_route_posted_flight_financials_v1 f
  JOIN airlinerra_game.section9_operated_flight_movements_v1 m
   ON m.engine_event_id=f.arrived_event_id
   AND m.phase='arrived'
   AND m.source_kind='signed_operated_game_flight_v1'
   AND m.flight_occurrence_id=f.physical_flight_id
   AND m.schedule_id=f.schedule_id AND m.airline_id=f.airline_id
   AND m.flight_local_date=f.flown_game_day
  JOIN airlinerra_game.airline_ledger revenue
   ON revenue.id=f.revenue_ledger_id
   AND revenue.airline_id=f.airline_id
   AND revenue.entry_kind='REVENUE'
   AND revenue.amount_usd=
     f.ticket_income_usd+f.cargo_income_usd+f.other_income_usd
  JOIN airlinerra_game.airline_ledger expense
   ON expense.id=f.expense_ledger_id
   AND expense.airline_id=f.airline_id
   AND expense.entry_kind='EXPENSE'
   AND expense.amount_usd=-(
    f.airport_navigation_cost_usd+f.fuel_cost_usd+f.crew_cost_usd+
    f.maintenance_cost_usd+f.ownership_cost_usd+f.other_cost_usd)
  WHERE f.schedule_id=p_schedule AND f.airline_id=p_airline
   AND f.record_status='posted_complete'
 ),ordered AS (
  SELECT verified.*,
   row_number() OVER(
    ORDER BY flown_game_day DESC,recorded_at DESC,physical_flight_id DESC
   ) AS sequence
  FROM verified
 )
 SELECT jsonb_build_object(
  'completedFlightCount',count(*)::integer,
  'totalRevenueUsd',coalesce(sum(total_revenue),0),
  'totalCostsUsd',coalesce(sum(total_cost),0),
  'totalProfitLossUsd',coalesce(sum(total_revenue-total_cost),0),
  'olderFlightCount',count(*) FILTER(WHERE sequence>7),
  'olderRevenueUsd',coalesce(sum(total_revenue) FILTER(WHERE sequence>7),0),
  'olderCostsUsd',coalesce(sum(total_cost) FILTER(WHERE sequence>7),0),
  'olderProfitLossUsd',coalesce(sum(total_revenue-total_cost)
    FILTER(WHERE sequence>7),0),
  'lastSevenFlights',
   coalesce(jsonb_agg(jsonb_build_object(
    'physicalFlightId',physical_flight_id,'gameDate',flown_game_day,
    'passengers',passenger_count,'cargoTonnes',cargo_tonnes,
    'ticketIncomeUsd',ticket_income_usd,
    'cargoIncomeUsd',cargo_income_usd,'otherIncomeUsd',other_income_usd,
    'revenueUsd',total_revenue,
    'fees',airport_fee_lines,
    'airportNavigationCostsUsd',airport_navigation_cost_usd,
    'fuelCostsUsd',fuel_cost_usd,'crewCostsUsd',crew_cost_usd,
    'maintenanceCostsUsd',maintenance_cost_usd,
    'ownershipCostsUsd',ownership_cost_usd,'otherCostsUsd',other_cost_usd,
    'totalCostsUsd',total_cost,
    'profitLossUsd',total_revenue-total_cost,
    'tariffVersion',tariff_model_version,
    'source','verified_arrival_and_posted_ledger'
   ) ORDER BY flown_game_day DESC,recorded_at DESC,physical_flight_id DESC)
    FILTER(WHERE sequence<=7),'[]'::jsonb),
  'olderFlightsDisplay','aggregate_only',
  'source','verified_arrival_and_posted_airline_ledger_only'
 ) INTO hist FROM ordered;
 RETURN jsonb_build_object(
  'status','route_financial_dashboard_read_only',
  'worldId',1,'airlineId',p_airline,'scheduleId',p_schedule,
  'flightNumber',sch.flight_number,'aircraftConfigurationId',sch.configuration_id,
  'readOnly',true,'cashPosted',false,'bookingsCreated',false,
  'flightActivated',false,
  'estimate',jsonb_build_object(
    'status','draft_not_earned','loadPercent',p_load_percent,
    'passengers',pax,'cargoTonnes',cargo,
    'plannedEconomyFareUsd',cm.economy_fare_usd,
    'plannedCargoRatePerTonneUsd',cm.cargo_rate_usd_per_tonne,
    'ticketIncomeIfSoldUsd',ticket,
    'cargoIncomeIfSoldUsd',freight,
    'potentialRevenueUsd',income,
    'knownAirportNavigationCostsUsd',fee_total,
    'partialMarginBeforeOtherCostsUsd',partial_margin,
    'airportFeeQuote',quote,'parkingMinutesAssumption',p_parking_minutes,
    'notIncludedCosts',jsonb_build_array('fuel','crew','maintenance',
      'aircraft_ownership_or_leasing','insurance','marketing_and_other_approved_charges'),
    'actualNetProfitKnown',false,
    'warning','Potential gross income only; full flight bookings and actual operating costs are not yet settled'
  ),
  'history',hist
 );
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_owned_route_financial_dashboard_v1(
  uuid,uuid,uuid,integer,integer) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section9_owned_route_financial_dashboard_v1(
 uuid,uuid,uuid,integer,integer) IS
 'Owner-only, read-only route earnings and cost preview; last seven verified posted flights with itemization; older verified posted flights retained privately and aggregated only. No flights/revenue fabricated.';

-- User accepted the previously tested Section 8 game pricing; no rate changed.
UPDATE airlinerra_game.world1_game_data_section_acceptance_v1
SET evidence=evidence||jsonb_build_object(
 'ownerAcceptedGameFeeRates',true,
 'ownerAcceptedOn','2026-11-09',
 'ownerAcceptedScope','section8_game_airport_and_navigation_fees',
 'actualAirlineSettlementEnabled',false),
 checked_at=clock_timestamp()
WHERE world_id=1 AND category_number=8;
