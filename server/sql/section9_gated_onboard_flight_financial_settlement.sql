-- Integrate onboard consumption into the existing atomic flight settlement.
-- Release flags are unchanged. No extra ledger transaction or retroactive charging.
CREATE TABLE airlinerra_game.section9_onboard_finance_receipts_v1(
 physical_flight_id text PRIMARY KEY REFERENCES airlinerra_game.section9_route_posted_flight_financials_v1(physical_flight_id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 passengers integer NOT NULL CHECK(passengers BETWEEN 0 AND 1000),
 onboard_revenue_usd numeric(16,2) NOT NULL CHECK(onboard_revenue_usd>=0),
 onboard_cost_usd numeric(16,2) NOT NULL CHECK(onboard_cost_usd>=0),
 calculation jsonb NOT NULL CHECK(jsonb_typeof(calculation)='object' AND calculation->>'modelVersion'='GAME_CABIN_SERVICE_V2'),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE airlinerra_game.section9_onboard_finance_receipts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_onboard_finance_receipts_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER section9_onboard_finance_receipts_append_only BEFORE UPDATE OR DELETE ON airlinerra_game.section9_onboard_finance_receipts_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_reject_certificate_audit_mutation_v1();

CREATE OR REPLACE FUNCTION airlinerra_game.section9_prepare_onboard_financials_v1(p_physical text,p_airline uuid,p_arrival_event text,p_passengers integer)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE f record; calc jsonb; minutes numeric; cost numeric; revenue numeric;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_ONBOARD_FINANCE';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_onboard_service_release_v1 WHERE world_id=1 AND snapshot_enabled AND settlement_enabled) THEN RETURN jsonb_build_object('status','onboard_settlement_not_released');END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_onboard_departure_snapshots_v1 WHERE physical_flight_id=p_physical) THEN RETURN jsonb_build_object('status','onboard_snapshot_unavailable');END IF;
 SELECT s.*,d.actual_event_utc AS actual_dep,a.actual_event_utc AS actual_arr,o.booking_status,o.booked_seats
 INTO f FROM airlinerra_game.section9_onboard_departure_snapshots_v1 s
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=s.occurrence_id AND o.airline_id=s.airline_id AND o.world_id=1
 JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.flight_occurrence_id=s.physical_flight_id AND d.engine_event_id=s.departure_event_id AND d.airline_id=s.airline_id AND d.phase='departed'
 JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.flight_occurrence_id=s.physical_flight_id AND a.engine_event_id=p_arrival_event AND a.airline_id=s.airline_id AND a.phase='arrived'
 WHERE s.physical_flight_id=p_physical AND s.airline_id=p_airline;
 IF NOT FOUND OR f.model_version<>'GAME_CABIN_SERVICE_V2' OR f.booking_status<>'closed' OR f.passengers IS DISTINCT FROM p_passengers OR f.booked_seats IS DISTINCT FROM p_passengers OR f.departed_at IS DISTINCT FROM f.actual_dep OR f.actual_arr<=f.actual_dep THEN RETURN jsonb_build_object('status','onboard_snapshot_evidence_mismatch');END IF;
 minutes:=extract(epoch FROM f.actual_arr-f.actual_dep)/60;
 calc:=airlinerra_game.section9_onboard_service_calculate_v1(p_physical,f.package_items,p_passengers,minutes,f.reputation_score);
 IF calc->>'status' IS DISTINCT FROM 'onboard_service_game_calculated' OR calc->>'modelVersion' IS DISTINCT FROM 'GAME_CABIN_SERVICE_V2' THEN RETURN jsonb_build_object('status','onboard_calculation_failed','calculation',calc);END IF;
 cost:=(calc->>'costCents')::numeric/100;revenue:=(calc->>'revenueCents')::numeric/100;
 IF cost IS NULL OR revenue IS NULL OR cost<0 OR revenue<0 OR cost>10000000 OR revenue>10000000 THEN RETURN jsonb_build_object('status','onboard_calculation_invalid_amount');END IF;
 RETURN jsonb_build_object('status','onboard_finance_ready','costUsd',cost,'revenueUsd',revenue,'calculation',calc,'ledgerPosted',false);
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_prepare_onboard_financials_v1(text,uuid,text,integer) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_post_completed_flight_finance_once_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 v_policy record; v_activation record;v_execution record;v_readiness record;
 v_prepared record;v_approved record;v_schedule record;
 v_airline record;v_existing record;
 v_signatures jsonb;v_ticket_proof jsonb;v_hour jsonb;
 v_ledger_balance numeric; v_total_revenue numeric(16,2);
 v_total_expense numeric(16,2);v_net numeric(16,2);
 v_revenue_ledger_id bigint;v_expense_ledger_id bigint;
 v_revenue_inserted integer:=0;v_cash_updated integer:=0;
 v_fee_key text;v_fee_value numeric;v_target_currency text:='USD';
 v_onboard jsonb;v_onboard_revenue numeric(16,2):=0;v_onboard_cost numeric(16,2):=0;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_FINAL_FINANCE_POST_TRUSTED_WORKER_ONLY';END IF;
 IF p_physical_flight_id IS NULL
 OR p_physical_flight_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_FINAL_FINANCE_INVALID_FLIGHT_ID';END IF;
 SELECT * INTO v_policy
 FROM airlinerra_game.section9_flight_finance_posting_release_v1 WHERE world_id=1;
 SELECT * INTO v_activation
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT * INTO v_execution
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO v_readiness
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF v_policy.release_state IS DISTINCT FROM 'approved'
 OR v_policy.approved_at IS NULL
 OR length(coalesce(v_policy.approval_reference,''))<20
 OR v_activation.release_state IS DISTINCT FROM 'enabled'
 OR v_activation.enabled_at IS NULL
 OR v_activation.crew_mode IS DISTINCT FROM 'deferred_phase1'
 OR v_execution.release_state IS DISTINCT FROM 'enabled'
 OR v_execution.enabled_at IS NULL
 OR v_readiness.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR v_readiness.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR v_readiness.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object(
  'status','blocked_game_financial_or_flight_release',
  'posted',false,'ledgerPosted',false,'cashChanged',false);END IF;

 IF NOT pg_catalog.pg_try_advisory_xact_lock(
   583730,pg_catalog.hashtext(p_physical_flight_id))
 THEN RETURN jsonb_build_object('status','game_flight_finance_posting_busy',
  'posted',false,'ledgerPosted',false,'cashChanged',false);END IF;

 SELECT * INTO v_prepared
 FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1
 WHERE physical_flight_id=p_physical_flight_id FOR UPDATE;
 IF NOT FOUND OR v_prepared.preparation_status<>'UNPOSTED_GAME_ESTIMATE'
 OR v_prepared.source_version<>'ACTUAL_TICKET_POSTARRIVAL_PREP_V1'
 THEN RETURN jsonb_build_object('status','blocked_missing_completed_ticket_preparation',
  'posted',false,'ledgerPosted',false,'cashChanged',false);END IF;
 SELECT * INTO v_approved
 FROM airlinerra_game.section9_flight_final_cost_approvals_v1
 WHERE physical_flight_id=p_physical_flight_id FOR UPDATE;
 IF NOT FOUND OR v_approved.approval_state<>'approved'
 OR v_approved.approved_at IS NULL
 OR length(coalesce(v_approved.approval_reference,''))<20
 OR v_approved.fuel_reserve_verified IS DISTINCT FROM true
 OR v_approved.fuel_reserve_kg<=0
 OR length(coalesce(v_approved.fuel_source_reference,''))<16
 OR length(coalesce(v_approved.tariff_source_reference,''))<16
 OR v_approved.airline_id IS DISTINCT FROM v_prepared.airline_id
 OR v_approved.arrived_event_id IS DISTINCT FROM v_prepared.arrival_event_id
 THEN RETURN jsonb_build_object('status','blocked_unapproved_final_fuel_or_airport_cost',
  'posted',false,'ledgerPosted',false,'cashChanged',false);END IF;
 SELECT s.id,s.airline_id,s.version,s.configuration_id,s.status,
  s.operationally_verified,m.financial_settlement_release,
  m.operational_dispatch_release,m.game_calculation_ready
 INTO v_schedule
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.section9_game_fuel_model_snapshot_v1 m
   ON m.configuration_id=s.configuration_id
 WHERE s.id=v_prepared.schedule_id AND s.airline_id=v_prepared.airline_id;
 IF NOT FOUND OR v_schedule.status<>'active'
 OR v_schedule.operationally_verified IS DISTINCT FROM true
 OR v_schedule.game_calculation_ready IS DISTINCT FROM true
 OR v_schedule.financial_settlement_release IS DISTINCT FROM 'RELEASED'
 OR v_schedule.operational_dispatch_release IS DISTINCT FROM 'RELEASED'
 THEN RETURN jsonb_build_object('status','blocked_fuel_model_not_released_for_money',
  'posted',false,'ledgerPosted',false,'cashChanged',false);END IF;

 -- Verify BOTH stored operated-event HMAC signatures independently.
 v_signatures:=airlinerra_game.section9_verify_operated_flight_hmac_pair_v1(
   p_physical_flight_id);
 IF v_signatures->>'status' IS DISTINCT FROM
      'signed_departure_and_arrival_verified'
 OR v_signatures->>'signatureVerified' IS DISTINCT FROM 'true'
 OR v_signatures->>'arrivalEventId' IS DISTINCT FROM
    v_prepared.arrival_event_id
 OR v_signatures->>'scheduleId' IS DISTINCT FROM
    v_prepared.schedule_id::text
 OR v_signatures->>'airlineId' IS DISTINCT FROM
    v_prepared.airline_id::text
 THEN RETURN jsonb_build_object('status','blocked_unverified_signed_flight_movement',
  'posted',false,'ledgerPosted',false,'cashChanged',false);END IF;

 v_hour:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF v_hour->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_hour',
  'posted',false,'ledgerPosted',false,'cashChanged',false);END IF;

 SELECT * INTO v_existing
 FROM airlinerra_game.section9_route_posted_flight_financials_v1
 WHERE physical_flight_id=p_physical_flight_id FOR UPDATE;
 IF FOUND THEN
  IF v_existing.airline_id IS DISTINCT FROM v_prepared.airline_id
   OR v_existing.schedule_id IS DISTINCT FROM v_prepared.schedule_id
   OR v_existing.arrived_event_id IS DISTINCT FROM v_prepared.arrival_event_id
   OR v_existing.passenger_count IS DISTINCT FROM v_prepared.passenger_count
   OR v_existing.ticket_income_usd IS DISTINCT FROM v_prepared.ticket_quote_usd
   OR v_existing.fuel_cost_usd IS DISTINCT FROM v_approved.fuel_cost_usd
   OR v_existing.airport_navigation_cost_usd IS DISTINCT FROM
     v_approved.airport_navigation_cost_usd
   OR v_existing.expense_ledger_id IS NULL
   OR v_existing.record_status<>'posted_complete'
   THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_POSTED_FLIGHT_REPLAY_PROOF_CONFLICT';END IF;
  RETURN jsonb_build_object('status','complete_game_flight_finance_already_posted',
   'posted',true,'replayed',true,'ledgerPostedNow',false,
   'cashChangedNow',false,'physicalFlightId',p_physical_flight_id);
 END IF;

 v_ticket_proof:=airlinerra_game.section9_postarrival_ticket_reconciliation_v1(
  p_physical_flight_id);
 IF v_ticket_proof->>'status' IS DISTINCT FROM
       'postarrival_ticket_totals_reconciled'
 OR v_ticket_proof->>'reconciled' IS DISTINCT FROM 'true'
 OR v_ticket_proof->>'financeAlreadyPosted' IS DISTINCT FROM 'false'
 OR (v_ticket_proof->>'ticketPassengers')::integer
      IS DISTINCT FROM v_prepared.passenger_count
 OR (v_ticket_proof->>'ticketIncomeUsd')::numeric
      IS DISTINCT FROM v_prepared.ticket_quote_usd
 THEN RETURN jsonb_build_object('status','blocked_real_tickets_not_reconciled',
  'posted',false,'ledgerPosted',false,'cashChanged',false);END IF;

 -- No accounting item is silently negative, missing or unitemized.
 FOREACH v_fee_key IN ARRAY ARRAY[
  'departureAirportMovementUsd','arrivalLandingUsd',
  'departureGroundHandlingUsd','arrivalStandParkingUsd',
  'departureTerminalAirTrafficControlUsd','enrouteAirTrafficControlUsd',
  'departingPassengerFacilityUsd','departingPassengerSecurityUsd',
  'internationalPassengerProcessingUsd','originCargoHandlingUsd',
  'destinationCargoHandlingUsd'
 ] LOOP
  IF jsonb_typeof(v_approved.airport_fee_lines->v_fee_key)
    IS DISTINCT FROM 'number' THEN
   RAISE EXCEPTION USING ERRCODE='23514',
     MESSAGE='SECTION9_FINAL_AIRPORT_FEE_MISSING_ITEM';END IF;
  v_fee_value:=(v_approved.airport_fee_lines->>v_fee_key)::numeric;
  IF v_fee_value<0 OR v_fee_value>100000000 THEN
   RAISE EXCEPTION USING ERRCODE='23514',
     MESSAGE='SECTION9_FINAL_AIRPORT_FEE_NEGATIVE_OR_OVERLIMIT';END IF;
 END LOOP;
 IF v_approved.fuel_cost_usd<=0
 OR v_approved.airport_navigation_cost_usd<0
 OR v_approved.crew_cost_usd<>0
 OR v_approved.maintenance_cost_usd<>0
 OR v_approved.ownership_cost_usd<>0
 OR v_approved.other_cost_usd<>0
 THEN RAISE EXCEPTION USING ERRCODE='23514',
   MESSAGE='SECTION9_UNSUPPORTED_GAME_FINANCE_COST_TYPE';END IF;

 -- Existing signed-flight and ticket checks above remain mandatory.
 v_onboard:=airlinerra_game.section9_prepare_onboard_financials_v1(p_physical_flight_id,v_prepared.airline_id,v_prepared.arrival_event_id,v_prepared.passenger_count);
 IF v_onboard->>'status'='onboard_finance_ready' THEN
  v_onboard_revenue:=(v_onboard->>'revenueUsd')::numeric;
  v_onboard_cost:=(v_onboard->>'costUsd')::numeric;
 ELSIF v_onboard->>'status' NOT IN ('onboard_settlement_not_released','onboard_snapshot_unavailable') THEN
  RETURN jsonb_build_object('status','blocked_onboard_finance_evidence','detail',v_onboard,'posted',false,'ledgerPosted',false,'cashChanged',false);
 END IF;
 v_total_revenue:=v_prepared.ticket_quote_usd+v_onboard_revenue;
 v_total_expense:=(v_approved.fuel_cost_usd+
  v_approved.airport_navigation_cost_usd+
  v_approved.crew_cost_usd+v_approved.maintenance_cost_usd+
  v_approved.ownership_cost_usd+v_approved.other_cost_usd+v_onboard_cost)::numeric(16,2);
 v_net:=v_total_revenue-v_total_expense;
 IF v_total_revenue<0 OR v_total_revenue>1000000000
 OR v_total_expense<=0 OR v_total_expense>1000000000
 THEN RAISE EXCEPTION USING ERRCODE='23514',
    MESSAGE='SECTION9_FLIGHT_SETTLEMENT_AMOUNT_OUTSIDE_SAFETY_BOUNDS';END IF;

 -- Protect airline balance and every ledger write with ONE transaction.
 SELECT a.id,a.world_id,a.cash_usd INTO v_airline
 FROM airlinerra_game.airlines a
 WHERE a.id=v_prepared.airline_id FOR UPDATE;
 IF NOT FOUND OR v_airline.world_id<>1
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_FLIGHT_FINANCE_AIRLINE_MISSING';END IF;
 SELECT coalesce(sum(l.amount_usd),0) INTO v_ledger_balance
 FROM airlinerra_game.airline_ledger l WHERE l.airline_id=v_airline.id;
 IF v_airline.cash_usd IS DISTINCT FROM v_ledger_balance
 THEN RETURN jsonb_build_object('status','blocked_cash_ledger_reconciliation',
   'posted',false,'ledgerPosted',false,'cashChanged',false);END IF;
 IF v_airline.cash_usd+v_net<0
 THEN RETURN jsonb_build_object('status','blocked_insufficient_flight_settlement_funds',
   'posted',false,'ledgerPosted',false,'cashChanged',false);END IF;

 IF v_total_revenue>0 THEN
  INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
  VALUES(v_airline.id,'REVENUE',v_total_revenue)
  RETURNING id INTO v_revenue_ledger_id;
  v_revenue_inserted:=1;
 END IF;
 INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
 VALUES(v_airline.id,'EXPENSE',-v_total_expense)
 RETURNING id INTO v_expense_ledger_id;
 UPDATE airlinerra_game.airlines
 SET cash_usd=cash_usd+v_net
 WHERE id=v_airline.id
 AND cash_usd=v_airline.cash_usd AND cash_usd+v_net>=0;
 GET DIAGNOSTICS v_cash_updated=ROW_COUNT;
 IF v_cash_updated<>1 THEN
  RAISE EXCEPTION USING ERRCODE='40001',
   MESSAGE='SECTION9_FLIGHT_CASH_BALANCE_CHANGED_ROLLBACK';END IF;

 INSERT INTO airlinerra_game.section9_route_posted_flight_financials_v1(
  physical_flight_id,schedule_id,airline_id,flown_game_day,arrived_event_id,
  passenger_count,cargo_tonnes,ticket_income_usd,cargo_income_usd,
  other_income_usd,airport_navigation_cost_usd,fuel_cost_usd,
  crew_cost_usd,maintenance_cost_usd,ownership_cost_usd,other_cost_usd,
  airport_fee_lines,revenue_ledger_id,expense_ledger_id,
  tariff_model_version,settlement_source_reference,record_status
 ) VALUES(
  p_physical_flight_id,v_prepared.schedule_id,v_prepared.airline_id,
  v_prepared.flight_local_date,v_prepared.arrival_event_id,
  v_prepared.passenger_count,0,v_prepared.ticket_quote_usd,0,
  v_onboard_revenue,v_approved.airport_navigation_cost_usd,v_approved.fuel_cost_usd,
  0,0,0,v_onboard_cost,v_approved.airport_fee_lines,
  v_revenue_ledger_id,v_expense_ledger_id,
  v_approved.tariff_model_version,v_approved.approval_reference,'posted_complete'
 );
 IF v_onboard->>'status'='onboard_finance_ready' THEN
  INSERT INTO airlinerra_game.section9_onboard_finance_receipts_v1(physical_flight_id,airline_id,passengers,onboard_revenue_usd,onboard_cost_usd,calculation)
  VALUES(p_physical_flight_id,v_prepared.airline_id,v_prepared.passenger_count,v_onboard_revenue,v_onboard_cost,v_onboard->'calculation');
 END IF;
 RETURN jsonb_build_object('status','verified_complete_flight_finance_posted_once',
  'onboardSettlementStatus',v_onboard->>'status','onboardRevenueUsd',v_onboard_revenue,'onboardCostUsd',v_onboard_cost,
  'physicalFlightId',p_physical_flight_id,
  'revenueUsd',v_total_revenue,'expenseUsd',v_total_expense,
  'cashDeltaUsd',v_net,
  'revenueLedgerCreated',v_revenue_inserted=1,
  'expenseLedgerCreated',true,'cashChangedNow',true,
  'posted',true,'replayed',false,
  'crewIncluded',false,'maintenanceRecharged',false,
  'fuelModelReleased',true,'gameFinanceApproved',true);
END $function$;
