-- Continue settling permanent salaries separately. Only the verified temporary
-- flight contract enters this flight's crew expense, through the existing cash/ledger transaction.
ALTER TABLE airlinerra_game.section9_flight_final_cost_approvals_v1 DROP CONSTRAINT section9_flight_final_cost_approvals_v1_crew_cost_usd_check;
ALTER TABLE airlinerra_game.section9_flight_final_cost_approvals_v1 ADD CONSTRAINT section9_final_external_crew_cost_bounds CHECK(crew_cost_usd>=0 AND crew_cost_usd<=100000000);
CREATE OR REPLACE FUNCTION airlinerra_game.section9_approve_completed_game_flight_cost_v1(p_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 p record; d record; a record; model record; s record; movement record;
 policy record; engine record; hour_proof jsonb; signed_proof jsonb; ticket jsonb; quote jsonb;
 fee_lines jsonb; fee numeric; usd_per_kg numeric; fuel_cost numeric;
 reserve numeric; fee_key text; price_count integer; price_max numeric;
 approval_ref text; fuel_ref text; tariff_ref text;
 inserted integer;external_crew_cost numeric;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION 'SECTION9_PRIVATE_GAME_COST_APPROVAL_ONLY' USING ERRCODE='42501';END IF;
 IF p_id IS NULL OR p_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$' THEN
  RAISE EXCEPTION 'SECTION9_GAME_COST_INVALID_FLIGHT' USING ERRCODE='22023';END IF;
 SELECT * INTO policy FROM airlinerra_game.section9_flight_finance_posting_release_v1 WHERE world_id=1 FOR SHARE;
 SELECT * INTO engine FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF policy.release_state IS DISTINCT FROM 'approved' OR policy.approved_at IS NULL
 OR length(coalesce(policy.approval_reference,''))<20
 OR engine.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_game_cost_release','approved',false);END IF;
 IF NOT pg_try_advisory_xact_lock(583731,hashtext(p_id)) THEN
  RETURN jsonb_build_object('status','game_cost_approval_busy','approved',false);END IF;
 SELECT * INTO p FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1
 WHERE physical_flight_id=p_id FOR UPDATE;
 IF NOT FOUND OR p.preparation_status IS DISTINCT FROM 'UNPOSTED_GAME_ESTIMATE'
 OR p.source_version IS DISTINCT FROM 'ACTUAL_TICKET_POSTARRIVAL_PREP_V1'
 THEN RETURN jsonb_build_object('status','blocked_missing_arrival_preparation','approved',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 WHERE physical_flight_id=p_id)
 THEN RETURN jsonb_build_object('status','game_cost_already_settled','approved',false);END IF;
 SELECT * INTO s FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE id=p.schedule_id AND airline_id=p.airline_id FOR SHARE;
 SELECT * INTO model FROM airlinerra_game.section9_game_fuel_model_snapshot_v1 WHERE configuration_id=s.configuration_id FOR SHARE;
 IF s.status IS DISTINCT FROM 'active' OR s.operationally_verified IS DISTINCT FROM true
 OR model.game_calculation_ready IS DISTINCT FROM true OR model.financial_settlement_release IS DISTINCT FROM 'RELEASED'
 OR model.operational_dispatch_release IS DISTINCT FROM 'RELEASED'
 THEN RETURN jsonb_build_object('status','blocked_unreleased_fuel_model','approved',false);END IF;
 SELECT * INTO d FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 WHERE physical_flight_id=p_id FOR SHARE;
 SELECT * INTO a FROM airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 WHERE physical_flight_id=p_id FOR SHARE;
 SELECT * INTO movement FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id=p_id AND phase='arrived' FOR SHARE;
 signed_proof:=airlinerra_game.section9_verify_operated_flight_hmac_pair_v1(p_id);
 hour_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF signed_proof->>'signatureVerified' IS DISTINCT FROM 'true'
 OR signed_proof->>'status' IS DISTINCT FROM 'signed_departure_and_arrival_verified'
 OR signed_proof->>'airlineId' IS DISTINCT FROM p.airline_id::text
 OR signed_proof->>'scheduleId' IS DISTINCT FROM p.schedule_id::text
 OR signed_proof->>'arrivalEventId' IS DISTINCT FROM p.arrival_event_id
 OR hour_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 OR movement.actual_event_utc IS NULL OR movement.actual_event_utc>(hour_proof->>'gameHourUtc')::timestamptz
 OR movement.schedule_version IS DISTINCT FROM s.version
 OR d.airline_id IS DISTINCT FROM p.airline_id OR a.airline_id IS DISTINCT FROM p.airline_id
 OR d.configuration_id IS DISTINCT FROM s.configuration_id
 OR d.aircraft_inventory_id IS DISTINCT FROM movement.aircraft_inventory_id
 OR a.aircraft_inventory_id IS DISTINCT FROM movement.aircraft_inventory_id
 OR a.arrival_engine_event_id IS DISTINCT FROM p.arrival_event_id
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
  WHERE m.flight_occurrence_id=p_id AND m.phase='departed' AND m.engine_event_id=d.departure_engine_event_id)
 OR a.trip_burn_kg IS NULL OR a.trip_burn_kg<=0 OR a.trip_burn_kg IS DISTINCT FROM d.planned_trip_burn_kg
 OR d.onboard_at_departure_kg IS NULL OR a.onboard_after_arrival_kg IS NULL
 OR a.onboard_after_arrival_kg IS DISTINCT FROM d.onboard_at_departure_kg-a.trip_burn_kg
 OR d.planned_holding_reserve_kg IS NULL OR d.planned_holding_reserve_kg<=0
 OR d.planned_contingency_kg IS NULL OR d.planned_contingency_kg<0
 OR a.onboard_after_arrival_kg<d.planned_holding_reserve_kg+d.planned_contingency_kg
 THEN RETURN jsonb_build_object('status','blocked_signed_fuel_or_movement_evidence','approved',false);END IF;
 ticket:=airlinerra_game.section9_postarrival_ticket_reconciliation_v1(p_id);
 quote:=airlinerra_game.section9_completed_flight_game_cost_preview_v1(p_id);
 IF ticket->>'status' IS DISTINCT FROM 'postarrival_ticket_totals_reconciled'
 OR ticket->>'reconciled' IS DISTINCT FROM 'true'
 OR ticket->>'financeAlreadyPosted' IS DISTINCT FROM 'false'
 OR (ticket->>'ticketPassengers')::int IS DISTINCT FROM p.passenger_count
 OR (ticket->>'ticketIncomeUsd')::numeric IS DISTINCT FROM p.ticket_quote_usd
 OR quote->>'status' IS DISTINCT FROM 'game_only_completed_flight_cost_estimate'
 OR quote->>'physicalFlightId' IS DISTINCT FROM p_id
 OR (quote->>'bookedPassengers')::int IS DISTINCT FROM p.passenger_count
 OR (quote->>'quotedTicketFareUsd')::numeric IS DISTINCT FROM p.ticket_quote_usd
 OR quote->>'airportTariffSource' IS DISTINCT FROM 'SECTION8_PROVISIONAL_GAME_TARIFF_NOT_REAL_BILL'
 OR quote->>'feeLinesAreItemized' IS DISTINCT FROM 'true'
 OR length(coalesce(quote->>'airportFeeQuoteModelVersion',''))<=12
 OR coalesce(quote->>'originTariffVersion','')='' OR coalesce(quote->>'destinationTariffVersion','')=''
 THEN RETURN jsonb_build_object('status','blocked_ticket_or_tariff_evidence','approved',false);END IF;
 -- Charge actual recorded game burn, not reserve or a recomputed forecast.
 SELECT count(*),min(fuel_price_assumption_usd_per_kg),max(fuel_price_assumption_usd_per_kg)
 INTO price_count,usd_per_kg,price_max
 FROM airlinerra.aircraft_expansion_group3_economics_v1;
 IF price_count<1 OR usd_per_kg IS NULL OR usd_per_kg<=0 OR usd_per_kg IS DISTINCT FROM price_max
 OR EXISTS(SELECT 1 FROM airlinerra.aircraft_expansion_group3_economics_v1 WHERE fuel_price_assumption_usd_per_kg IS NULL)
 OR usd_per_kg IS DISTINCT FROM (quote->>'fuelPriceAssumptionUsdPerKg')::numeric
 THEN RETURN jsonb_build_object('status','blocked_game_fuel_price','approved',false);END IF;
 fee_lines:=quote->'airportFeeLinesUsd';
 IF jsonb_typeof(fee_lines) IS DISTINCT FROM 'object' THEN
  RETURN jsonb_build_object('status','blocked_game_fee_lines','approved',false);END IF;
 FOREACH fee_key IN ARRAY ARRAY[
 'departureAirportMovementUsd','arrivalLandingUsd','departureGroundHandlingUsd','arrivalStandParkingUsd',
 'departureTerminalAirTrafficControlUsd','enrouteAirTrafficControlUsd','departingPassengerFacilityUsd',
 'departingPassengerSecurityUsd','internationalPassengerProcessingUsd','originCargoHandlingUsd','destinationCargoHandlingUsd']
 LOOP
  IF jsonb_typeof(fee_lines->fee_key) IS DISTINCT FROM 'number' OR (fee_lines->>fee_key)::numeric<0
  THEN RETURN jsonb_build_object('status','blocked_game_fee_lines','approved',false);END IF;
 END LOOP;
 IF (SELECT count(*) FROM jsonb_object_keys(fee_lines))<>11 THEN
  RETURN jsonb_build_object('status','blocked_game_fee_lines','approved',false);END IF;
 SELECT round(sum(value::numeric),2) INTO fee FROM jsonb_each_text(fee_lines);
 fuel_cost:=round(a.trip_burn_kg*usd_per_kg,2);
 reserve:=d.planned_holding_reserve_kg;
 IF fee IS DISTINCT FROM (quote->>'airportCostEstimateUsd')::numeric OR fee<0 OR fee>100000000
 OR fuel_cost<=0 OR fuel_cost>100000000
 THEN RETURN jsonb_build_object('status','blocked_game_cost_total','approved',false);END IF;
 fuel_ref:='game-actual-fuel-v1-'||md5(concat_ws('|',p_id,d.departure_engine_event_id,a.arrival_engine_event_id,a.trip_burn_kg,reserve,usd_per_kg));
 tariff_ref:='game-airport-tariff-v1-'||md5(concat_ws('|',p_id,quote->>'originTariffVersion',quote->>'destinationTariffVersion',fee_lines::text));
 external_crew_cost:=airlinerra_game.section9_completed_external_crew_cost_v1(p.airline_id,p_id,p.arrival_event_id);
 approval_ref:='game-completed-cost-v1-'||md5(concat_ws('|',p_id,policy.approval_reference,fuel_ref,tariff_ref,CASE WHEN external_crew_cost>0 THEN 'external-crew:'||external_crew_cost::text END));
 INSERT INTO airlinerra_game.section9_flight_final_cost_approvals_v1(
 physical_flight_id,airline_id,arrived_event_id,approval_state,approved_at,approval_reference,
 fuel_reserve_verified,fuel_reserve_kg,fuel_source_reference,tariff_source_reference,
 fuel_cost_usd,airport_navigation_cost_usd,crew_cost_usd,maintenance_cost_usd,ownership_cost_usd,other_cost_usd,
 airport_fee_lines,tariff_model_version)
 VALUES(p_id,p.airline_id,p.arrival_event_id,'approved',clock_timestamp(),approval_ref,
 true,reserve,fuel_ref,tariff_ref,fuel_cost,fee,external_crew_cost,0,0,0,fee_lines,quote->>'airportFeeQuoteModelVersion')
 ON CONFLICT(physical_flight_id) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_final_cost_approvals_v1 c
  WHERE c.physical_flight_id=p_id AND c.airline_id=p.airline_id AND c.arrived_event_id=p.arrival_event_id
  AND c.approval_state='approved' AND c.approval_reference=approval_ref
  AND c.fuel_cost_usd=fuel_cost AND c.airport_navigation_cost_usd=fee
  AND c.fuel_reserve_kg=reserve AND c.fuel_reserve_verified=true AND c.airport_fee_lines=fee_lines
  AND c.fuel_source_reference=fuel_ref AND c.tariff_source_reference=tariff_ref
  AND c.tariff_model_version=quote->>'airportFeeQuoteModelVersion'
  AND c.crew_cost_usd=external_crew_cost AND c.maintenance_cost_usd=0 AND c.ownership_cost_usd=0 AND c.other_cost_usd=0)
 THEN RAISE EXCEPTION 'SECTION9_GAME_COST_APPROVAL_REPLAY_CONFLICT' USING ERRCODE='23505';END IF;
 RETURN jsonb_build_object('status',CASE WHEN inserted=1 THEN 'game_flight_cost_approved' ELSE 'game_flight_cost_approval_replayed' END,
 'approved',true,'fuelCostUsd',fuel_cost,'airportCostUsd',fee,'externalCrewCostUsd',external_crew_cost,'ledgerPosted',false);
END $function$
;
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
 v_onboard jsonb;v_onboard_revenue numeric(16,2):=0;v_onboard_cost numeric(16,2):=0;v_external_crew_cost numeric(16,2);
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

 v_external_crew_cost:=airlinerra_game.section9_completed_external_crew_cost_v1(v_prepared.airline_id,p_physical_flight_id,v_prepared.arrival_event_id);
 IF v_approved.crew_cost_usd IS DISTINCT FROM v_external_crew_cost THEN
 RETURN jsonb_build_object('status','blocked_external_crew_cost_mismatch','posted',false,'ledgerPosted',false,'cashChanged',false);END IF;
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
   OR v_existing.crew_cost_usd IS DISTINCT FROM v_external_crew_cost
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
 OR v_approved.crew_cost_usd<0
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
  v_external_crew_cost,0,0,v_onboard_cost,v_approved.airport_fee_lines,
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
  'crewIncluded',v_external_crew_cost>0,'externalCrewCostUsd',v_external_crew_cost,'maintenanceRecharged',false,
  'fuelModelReleased',true,'gameFinanceApproved',true);
END $function$
;
