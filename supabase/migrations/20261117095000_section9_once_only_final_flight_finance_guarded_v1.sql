-- Airlinerra Section 9: final ONCE-ONLY game flight income and costs.
-- World 1: NOT RELEASED. Crew excluded, maintenance and aircraft ownership
-- already paid separately and NEVER charged again by this transaction.
-- Financial posting is possible ONLY after explicit finance approval,
-- approved exact airport fee breakdown, approved reserve-aware game fuel cost,
-- flight/movement releases and independent re-verification of signed events.
-- Ledger REVENUE, EXPENSE, cash balance and posted-complete identity are all
-- written within the SAME Postgres transaction. Any error ROLLS BACK ALL.
-- Existing game fuel models currently restrict financial_settlement_release
-- to NOT_RELEASED; this migration NEVER relaxes that constraint.

-- Game-wide financial posting is explicitly paused. Never implicitly enable it.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_flight_finance_posting_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 release_state text NOT NULL DEFAULT 'paused'
  CHECK(release_state IN ('paused','approved')),
 approved_at timestamptz,approval_reference text,
 CHECK (release_state='paused' OR
  (approved_at IS NOT NULL AND length(approval_reference)>=20))
);
ALTER TABLE airlinerra_game.section9_flight_finance_posting_release_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_flight_finance_posting_release_v1
 FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO airlinerra_game.section9_flight_finance_posting_release_v1(world_id,release_state)
VALUES(1,'paused') ON CONFLICT(world_id) DO NOTHING;

-- Independent and APPROVED final GAME cost proof, never a provisional preview.
-- Maintenance and ownership are already charged by separate workflows, so
-- they MUST NOT be charged a second time on flight completion.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_flight_final_cost_approvals_v1(
 physical_flight_id text PRIMARY KEY REFERENCES
  airlinerra_game.section9_actual_ticket_finance_preparations_v1(physical_flight_id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 arrived_event_id text NOT NULL UNIQUE REFERENCES
  airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 fuel_cost_usd numeric(16,2) NOT NULL CHECK(fuel_cost_usd>0),
 airport_navigation_cost_usd numeric(16,2) NOT NULL CHECK(airport_navigation_cost_usd>=0),
 airport_fee_lines jsonb NOT NULL CHECK(jsonb_typeof(airport_fee_lines)='object'),
 crew_cost_usd numeric(16,2) NOT NULL DEFAULT 0 CHECK(crew_cost_usd=0),
 maintenance_cost_usd numeric(16,2) NOT NULL DEFAULT 0 CHECK(maintenance_cost_usd=0),
 ownership_cost_usd numeric(16,2) NOT NULL DEFAULT 0 CHECK(ownership_cost_usd=0),
 other_cost_usd numeric(16,2) NOT NULL DEFAULT 0 CHECK(other_cost_usd=0),
 fuel_reserve_kg numeric(14,3) NOT NULL DEFAULT 0 CHECK(fuel_reserve_kg>=0),
 fuel_reserve_verified boolean NOT NULL DEFAULT false,
 fuel_source_reference text,
 tariff_model_version text NOT NULL CHECK(length(tariff_model_version)>12),
 tariff_source_reference text,
 model_version text NOT NULL DEFAULT 'GAME_FINAL_COST_APPROVAL_V1'
  CHECK(model_version='GAME_FINAL_COST_APPROVAL_V1'),
 approval_state text NOT NULL DEFAULT 'unapproved'
  CHECK(approval_state IN ('unapproved','approved')),
 approved_at timestamptz,approval_reference text,
 CONSTRAINT section9_final_cost_only_if_approved_evidence_v1
 CHECK(approval_state='unapproved' OR (
  approved_at IS NOT NULL AND length(approval_reference)>=20
  AND fuel_reserve_verified=true AND fuel_reserve_kg>0
  AND length(fuel_source_reference)>=16
  AND length(tariff_source_reference)>=16)),
 CONSTRAINT section9_final_cost_fee_itemization_v1 CHECK(
  (jsonb_typeof(airport_fee_lines->'departureAirportMovementUsd')='number')
  AND (jsonb_typeof(airport_fee_lines->'arrivalLandingUsd')='number')
  AND (jsonb_typeof(airport_fee_lines->'departureGroundHandlingUsd')='number')
  AND (jsonb_typeof(airport_fee_lines->'arrivalStandParkingUsd')='number')
  AND (jsonb_typeof(airport_fee_lines->'departureTerminalAirTrafficControlUsd')='number')
  AND (jsonb_typeof(airport_fee_lines->'enrouteAirTrafficControlUsd')='number')
  AND (jsonb_typeof(airport_fee_lines->'departingPassengerFacilityUsd')='number')
  AND (jsonb_typeof(airport_fee_lines->'departingPassengerSecurityUsd')='number')
  AND (jsonb_typeof(airport_fee_lines->'internationalPassengerProcessingUsd')='number')
  AND (jsonb_typeof(airport_fee_lines->'originCargoHandlingUsd')='number')
  AND (jsonb_typeof(airport_fee_lines->'destinationCargoHandlingUsd')='number')
  AND airport_navigation_cost_usd=round((
   (airport_fee_lines->>'departureAirportMovementUsd')::numeric+
   (airport_fee_lines->>'arrivalLandingUsd')::numeric+
   (airport_fee_lines->>'departureGroundHandlingUsd')::numeric+
   (airport_fee_lines->>'arrivalStandParkingUsd')::numeric+
   (airport_fee_lines->>'departureTerminalAirTrafficControlUsd')::numeric+
   (airport_fee_lines->>'enrouteAirTrafficControlUsd')::numeric+
   (airport_fee_lines->>'departingPassengerFacilityUsd')::numeric+
   (airport_fee_lines->>'departingPassengerSecurityUsd')::numeric+
   (airport_fee_lines->>'internationalPassengerProcessingUsd')::numeric+
   (airport_fee_lines->>'originCargoHandlingUsd')::numeric+
   (airport_fee_lines->>'destinationCargoHandlingUsd')::numeric
  ),2))
);
ALTER TABLE airlinerra_game.section9_flight_final_cost_approvals_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON TABLE airlinerra_game.section9_flight_final_cost_approvals_v1
 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_operated_flight_hmac_pair_v1(p_physical_flight_id text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 dep record;arr record;secret_value text;row_event record;
 payload text;expected text;checked integer:=0;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_SIGNED_MOVEMENT_VERIFICATION_PRIVATE_ONLY';END IF;
 IF p_physical_flight_id IS NULL OR
  p_physical_flight_id !~ '^[a-f0-9-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[1-7]$'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_SIGNED_MOVEMENT_INVALID_FLIGHT_ID';END IF;
 SELECT * INTO dep FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=p_physical_flight_id AND phase='departed';
 SELECT * INTO arr FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=p_physical_flight_id AND phase='arrived';
 IF dep.engine_event_id IS NULL OR arr.engine_event_id IS NULL
 OR dep.world_id<>1 OR arr.world_id<>1
 OR dep.source_kind<>'signed_operated_game_flight_v1'
 OR arr.source_kind<>'signed_operated_game_flight_v1'
 OR dep.airline_id IS DISTINCT FROM arr.airline_id
 OR dep.aircraft_inventory_id IS DISTINCT FROM arr.aircraft_inventory_id
 OR dep.schedule_id IS DISTINCT FROM arr.schedule_id
 OR dep.schedule_version IS DISTINCT FROM arr.schedule_version
 OR dep.flight_local_date IS DISTINCT FROM arr.flight_local_date
 OR dep.weekly_entry IS DISTINCT FROM arr.weekly_entry
 OR dep.scheduled_departure_utc IS DISTINCT FROM arr.scheduled_departure_utc
 OR dep.scheduled_arrival_utc IS DISTINCT FROM arr.scheduled_arrival_utc
 OR arr.actual_event_utc<=dep.actual_event_utc
 OR dep.flight_occurrence_id IS DISTINCT FROM arr.flight_occurrence_id
 THEN RETURN jsonb_build_object('status','blocked_movement_pair_mismatch',
  'signatureVerified',false,'readOnly',true,'ledgerPosted',false);END IF;
 SELECT decrypted_secret INTO secret_value FROM vault.decrypted_secrets
 WHERE name='airlinerra_operated_flight_auto_signing_v1';
 IF length(coalesce(secret_value,''))<64 THEN
  RETURN jsonb_build_object('status','blocked_movement_signature_key_missing',
   'signatureVerified',false,'readOnly',true,'ledgerPosted',false);END IF;
 FOR row_event IN
  SELECT * FROM airlinerra_game.section9_operated_flight_movements_v1 m
  WHERE m.flight_occurrence_id=p_physical_flight_id
  AND m.phase IN('departed','arrived')
  ORDER BY m.phase
 LOOP
  IF row_event.actual_event_utc IS NULL
   OR date_trunc('second',row_event.actual_event_utc)
      IS DISTINCT FROM row_event.actual_event_utc
   OR coalesce(row_event.event_hmac_sha256,'') !~ '^[a-f0-9]{64}$'
   THEN RETURN jsonb_build_object('status','blocked_invalid_operated_event_time_or_signature',
    'signatureVerified',false,'readOnly',true,'ledgerPosted',false);END IF;
  payload:=concat_ws(E'\n',
   'airlinerra-operated-game-event-v1','1',
   row_event.airline_id::text,row_event.schedule_id::text,
   row_event.schedule_version::text,row_event.flight_local_date::text,
   row_event.weekly_entry::text,row_event.phase,
   to_char(row_event.actual_event_utc AT TIME ZONE 'UTC',
    'YYYY-MM-DD"T"HH24:MI:SS"Z"'),
   row_event.engine_event_id);
  expected:=encode(extensions.hmac(
   pg_catalog.convert_to(payload,'UTF8'),
   pg_catalog.convert_to(secret_value,'UTF8'),'sha256'),'hex');
  IF expected IS DISTINCT FROM row_event.event_hmac_sha256 THEN
   RETURN jsonb_build_object('status','blocked_operated_event_signature_mismatch',
    'signatureVerified',false,'readOnly',true,'ledgerPosted',false);END IF;
  checked:=checked+1;
 END LOOP;
 IF checked<>2 THEN RETURN jsonb_build_object('status','blocked_unexpected_operated_events',
  'signatureVerified',false,'readOnly',true,'ledgerPosted',false);END IF;
 RETURN jsonb_build_object('status','signed_departure_and_arrival_verified',
   'physicalFlightId',p_physical_flight_id,'checkedEvents',checked,
   'airlineId',dep.airline_id,'aircraftInventoryId',dep.aircraft_inventory_id,
   'scheduleId',dep.schedule_id,'arrivalEventId',arr.engine_event_id,
   'signatureVerified',true,'readOnly',true,'ledgerPosted',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_verify_operated_flight_hmac_pair_v1(text) FROM PUBLIC,anon,authenticated,service_role;

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

 v_total_revenue:=v_prepared.ticket_quote_usd;
 v_total_expense:=(v_approved.fuel_cost_usd+
  v_approved.airport_navigation_cost_usd+
  v_approved.crew_cost_usd+v_approved.maintenance_cost_usd+
  v_approved.ownership_cost_usd+v_approved.other_cost_usd)::numeric(16,2);
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
  v_prepared.passenger_count,0,v_total_revenue,0,
  0,v_approved.airport_navigation_cost_usd,v_approved.fuel_cost_usd,
  0,0,0,0,v_approved.airport_fee_lines,
  v_revenue_ledger_id,v_expense_ledger_id,
  v_approved.tariff_model_version,v_approved.approval_reference,'posted_complete'
 );
 RETURN jsonb_build_object('status','verified_complete_flight_finance_posted_once',
  'physicalFlightId',p_physical_flight_id,
  'revenueUsd',v_total_revenue,'expenseUsd',v_total_expense,
  'cashDeltaUsd',v_net,
  'revenueLedgerCreated',v_revenue_inserted=1,
  'expenseLedgerCreated',true,'cashChangedNow',true,
  'posted',true,'replayed',false,
  'crewIncluded',false,'maintenanceRecharged',false,
  'fuelModelReleased',true,'gameFinanceApproved',true);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_post_completed_flight_finance_once_v1(text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_post_complete_game_flights_v1(p_limit integer DEFAULT 20)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 v_release record;v_activation record;v_execution record;v_engine record;
 target record;outcome jsonb;checked integer:=0;posted integer:=0;
 blocked integer:=0;reason text;reasons jsonb:='{}'::jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_PRIVATE_AUTOMATIC_FINAL_FINANCE_WORKER_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_FINAL_FINANCE_BATCH_LIMIT';END IF;
 SELECT * INTO v_release
 FROM airlinerra_game.section9_flight_finance_posting_release_v1 WHERE world_id=1;
 SELECT * INTO v_activation
 FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT * INTO v_execution
 FROM airlinerra_game.section9_trusted_execution_release_policy_v1 WHERE world_id=1;
 SELECT * INTO v_engine
 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 IF v_release.release_state IS DISTINCT FROM 'approved'
 OR v_release.approved_at IS NULL
 OR length(coalesce(v_release.approval_reference,''))<20
 OR v_activation.release_state IS DISTINCT FROM 'enabled'
 OR v_activation.enabled_at IS NULL
 OR v_activation.crew_mode IS DISTINCT FROM 'deferred_phase1'
 OR v_execution.release_state IS DISTINCT FROM 'enabled'
 OR v_execution.enabled_at IS NULL
 OR v_engine.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR v_engine.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR v_engine.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 THEN RETURN jsonb_build_object('status','blocked_unreleased_final_finance_job',
  'checked',0,'posted',0,'ledgerPosted',false,'cashChanged',false);
 END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583730,10044)
 THEN RETURN jsonb_build_object('status','final_finance_job_in_progress',
  'checked',0,'posted',0,'ledgerPosted',false,'cashChanged',false);END IF;
 FOR target IN
 SELECT p.physical_flight_id
 FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1 p
 JOIN airlinerra_game.section9_flight_final_cost_approvals_v1 a
  ON a.physical_flight_id=p.physical_flight_id
  AND a.airline_id=p.airline_id
  AND a.arrived_event_id=p.arrival_event_id
  AND a.approval_state='approved'
 WHERE p.preparation_status='UNPOSTED_GAME_ESTIMATE'
 AND NOT EXISTS(
 SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 done
 WHERE done.physical_flight_id=p.physical_flight_id)
 ORDER BY p.created_at,p.physical_flight_id
 LIMIT p_limit
 LOOP
  checked:=checked+1;
  outcome:=airlinerra_game.section9_post_completed_flight_finance_once_v1(
    target.physical_flight_id);
  IF outcome->>'status'='verified_complete_flight_finance_posted_once'
   AND outcome->>'posted'='true'
   AND outcome->>'replayed'='false'
   AND outcome->>'expenseLedgerCreated'='true'
   AND outcome->>'cashChangedNow'='true'
  THEN posted:=posted+1;
  ELSIF outcome->>'status' IN(
     'blocked_game_financial_or_flight_release',
     'blocked_missing_completed_ticket_preparation',
     'blocked_unapproved_final_fuel_or_airport_cost',
     'blocked_fuel_model_not_released_for_money',
     'blocked_unverified_signed_flight_movement',
     'blocked_unverified_game_hour',
     'blocked_real_tickets_not_reconciled',
     'blocked_cash_ledger_reconciliation',
     'blocked_insufficient_flight_settlement_funds',
     'game_flight_finance_posting_busy'
  ) AND outcome->>'ledgerPosted'='false'
     AND outcome->>'cashChanged'='false'
  THEN
   blocked:=blocked+1;reason:=outcome->>'status';
   reasons:=jsonb_set(reasons,ARRAY[reason],
      to_jsonb(coalesce((reasons->>reason)::integer,0)+1),true);
  ELSIF outcome->>'status'='complete_game_flight_finance_already_posted'
   AND outcome->>'replayed'='true'
   AND outcome->>'cashChangedNow'='false'
   AND outcome->>'ledgerPostedNow'='false'
  THEN NULL;
  ELSE RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_UNEXPECTED_GAME_FINANCE_POSTING_RESULT_ROLLBACK';END IF;
 END LOOP;
 RETURN jsonb_build_object(
 'status','game_complete_flight_finance_batch_checked',
 'checked',checked,'posted',posted,'blocked',blocked,
 'blockedReasons',reasons,'releasesVerified',true,
 'noPartialSettlementAllowed',true,
 'alreadyPaidFlightsExcluded',true,
 'crewDeferred',true);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_auto_post_complete_game_flights_v1(integer) FROM PUBLIC,anon,authenticated,service_role;


-- Runs are safe and entirely read-only while ANY independent release is paused.
DO $cron_install$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job
  WHERE jobname='airlinerra-game-approved-final-flight-finance-v1') THEN
  PERFORM cron.schedule(
   'airlinerra-game-approved-final-flight-finance-v1',
   '8,18,28,38,48,58 * * * *',
   'SELECT airlinerra_game.section9_auto_post_complete_game_flights_v1(20);'
  );
 END IF;
END $cron_install$;
