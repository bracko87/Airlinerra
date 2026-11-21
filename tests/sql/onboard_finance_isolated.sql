\set ON_ERROR_STOP on
-- Isolated database only. Production evidence validators are represented by
-- explicitly local test doubles; the actual settlement functions are imported.
BEGIN;
CREATE SCHEMA airlinerra_game;
CREATE ROLE anon NOLOGIN;
CREATE ROLE authenticated NOLOGIN;
CREATE ROLE service_role NOLOGIN;
SET search_path TO airlinerra_game,pg_catalog;
CREATE TABLE airlines(id uuid PRIMARY KEY,world_id smallint,cash_usd numeric(16,2));
CREATE TABLE airline_ledger(id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,airline_id uuid,entry_kind text,amount_usd numeric(16,2));
CREATE TABLE section9_dated_flight_occurrences_v1(id uuid PRIMARY KEY,world_id smallint,airline_id uuid,schedule_id uuid,flight_local_date date,weekly_entry int,schedule_version int,booking_status text,booked_seats int);
CREATE TABLE section9_operated_flight_movements_v1(flight_occurrence_id text,engine_event_id text PRIMARY KEY,schedule_id uuid,airline_id uuid,phase text,actual_event_utc timestamptz);
CREATE TABLE airline_flight_schedule_drafts_v1(id uuid PRIMARY KEY,airline_id uuid,version int,configuration_id bigint,status text,operationally_verified bool,flight_number text,aircraft_inventory_id uuid,origin_airport_key text,destination_airport_key text,weekly_schedule jsonb);
CREATE TABLE airline_route_planning_drafts_v1(airline_id uuid,flight_number text,aircraft_inventory_id uuid,origin_airport_key text,destination_airport_key text,weekly_schedule jsonb,planning_options jsonb);
CREATE TABLE section9_flight_finance_posting_release_v1(world_id smallint,release_state text,approved_at timestamptz,approval_reference text);
INSERT INTO section9_flight_finance_posting_release_v1 VALUES(1,'approved',now(),'isolated-finance-approval-only');
CREATE TABLE section9_activation_release_policy_v1(world_id smallint,release_state text,enabled_at timestamptz,crew_mode text);
INSERT INTO section9_activation_release_policy_v1 VALUES(1,'enabled',now(),'deferred_phase1');
CREATE TABLE section9_trusted_execution_release_policy_v1(world_id smallint,release_state text,enabled_at timestamptz);
INSERT INTO section9_trusted_execution_release_policy_v1 VALUES(1,'enabled',now());
CREATE TABLE section9_flight_engine_readiness_audit_v1(world_id smallint,trusted_flight_execution_release text,fuel_transaction_release text,automatic_flight_and_fuel_settlement_enabled bool);
INSERT INTO section9_flight_engine_readiness_audit_v1 VALUES(1,'ACTIVATED','ACTIVATED',true);
CREATE TABLE section9_game_fuel_model_snapshot_v1(configuration_id bigint,financial_settlement_release text,operational_dispatch_release text,game_calculation_ready bool);
INSERT INTO section9_game_fuel_model_snapshot_v1 VALUES(16,'RELEASED','RELEASED',true);
CREATE TABLE section9_actual_ticket_finance_preparations_v1(physical_flight_id text PRIMARY KEY,airline_id uuid,schedule_id uuid,flight_local_date date,arrival_event_id text,passenger_count int,ticket_quote_usd numeric,source_version text,preparation_status text);
CREATE TABLE section9_flight_final_cost_approvals_v1(physical_flight_id text PRIMARY KEY,airline_id uuid,arrived_event_id text,fuel_cost_usd numeric,airport_navigation_cost_usd numeric,airport_fee_lines jsonb,crew_cost_usd numeric,maintenance_cost_usd numeric,ownership_cost_usd numeric,other_cost_usd numeric,fuel_reserve_kg numeric,fuel_reserve_verified bool,fuel_source_reference text,tariff_model_version text,tariff_source_reference text,approval_state text,approved_at timestamptz,approval_reference text);
CREATE TABLE section9_route_posted_flight_financials_v1(physical_flight_id text PRIMARY KEY,schedule_id uuid,airline_id uuid,flown_game_day date,arrived_event_id text,passenger_count int,cargo_tonnes numeric,ticket_income_usd numeric,cargo_income_usd numeric,other_income_usd numeric,airport_navigation_cost_usd numeric,fuel_cost_usd numeric,crew_cost_usd numeric,maintenance_cost_usd numeric,ownership_cost_usd numeric,other_cost_usd numeric,airport_fee_lines jsonb,revenue_ledger_id bigint,expense_ledger_id bigint,tariff_model_version text,settlement_source_reference text,record_status text);
CREATE FUNCTION section9_reject_certificate_audit_mutation_v1() RETURNS trigger LANGUAGE plpgsql AS $$ BEGIN RAISE EXCEPTION 'append only'; END $$;
CREATE FUNCTION section9_airline_reputation_v1(uuid) RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT '{"reputation":70}'::jsonb $$;
CREATE FUNCTION section9_verified_berlin_game_hour_v1() RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT '{"authoritativeGameHourAvailable":true}'::jsonb $$;
-- This fixture does not test HMAC signing; production HMAC validation remains unchanged.
CREATE FUNCTION section9_verify_operated_flight_hmac_pair_v1(text) RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT jsonb_build_object('status','signed_departure_and_arrival_verified','signatureVerified',true,'arrivalEventId',p.arrival_event_id,'scheduleId',p.schedule_id,'airlineId',p.airline_id) FROM section9_actual_ticket_finance_preparations_v1 p WHERE p.physical_flight_id=$1 $$;
CREATE FUNCTION section9_postarrival_ticket_reconciliation_v1(text) RETURNS jsonb LANGUAGE sql STABLE AS $$ SELECT jsonb_build_object('status','postarrival_ticket_totals_reconciled','reconciled',true,'financeAlreadyPosted',false,'ticketPassengers',p.passenger_count,'ticketIncomeUsd',p.ticket_quote_usd) FROM section9_actual_ticket_finance_preparations_v1 p WHERE p.physical_flight_id=$1 $$;
\ir ../../server/sql/section9_onboard_service_foundation.sql
\ir ../../server/sql/section9_onboard_purchase_draw_alias_fix.sql
\ir ../../server/sql/section9_onboard_gated_departure_snapshot_hook.sql
\ir ../../server/sql/section9_simplify_onboard_consumption.sql
\ir ../../server/sql/section9_gated_onboard_flight_financial_settlement.sql
DO $test$
DECLARE a uuid:='00000000-0000-4000-8000-000000000001';
 s uuid; o uuid; physical text; i int; r jsonb; c jsonb; posted record; receipt record; opening numeric; before_count int; expected_revenue numeric;expected_cost numeric; dep timestamptz:='2026-11-21 12:00:00+00'; fees jsonb;
BEGIN
 INSERT INTO airlines VALUES(a,1,100000);
 INSERT INTO airline_ledger(airline_id,entry_kind,amount_usd) VALUES(a,'STARTING_CAPITAL',100000);
 -- A gate-off case, an actual basic-package snapshot case, and a paid-package
 -- synthetic snapshot case (custom route selection is not yet released).
 SELECT jsonb_object_agg(k,CASE WHEN k='departureAirportMovementUsd' THEN 500 ELSE 0 END) INTO fees FROM unnest(ARRAY['departureAirportMovementUsd','arrivalLandingUsd','departureGroundHandlingUsd','arrivalStandParkingUsd','departureTerminalAirTrafficControlUsd','enrouteAirTrafficControlUsd','departingPassengerFacilityUsd','departingPassengerSecurityUsd','internationalPassengerProcessingUsd','originCargoHandlingUsd','destinationCargoHandlingUsd']) k;
 FOR i IN 1..3 LOOP
  s:=gen_random_uuid();o:=gen_random_uuid();physical:=s::text||':2026-11-21:1';
  UPDATE section9_onboard_service_release_v1 SET snapshot_enabled=(i>1),settlement_enabled=(i>1);
  INSERT INTO airline_flight_schedule_drafts_v1 VALUES(s,a,1,16,'active',true,'ZZ'||i,a,'BEG','BUD','[{"day":5,"time":"12:00"}]');
  INSERT INTO airline_route_planning_drafts_v1 VALUES(a,'ZZ'||i,a,'BEG','BUD','[{"day":5,"time":"12:00"}]','{"service":{"cabinPackageId":"basic"}}');
  INSERT INTO section9_dated_flight_occurrences_v1 VALUES(o,1,a,s,'2026-11-21',1,1,'open',100);
  INSERT INTO section9_operated_flight_movements_v1 VALUES(physical,physical||':d',s,a,'departed',dep),(physical,physical||':a',s,a,'arrived',dep+interval '3 hours');
  UPDATE section9_dated_flight_occurrences_v1 SET booking_status='closed' WHERE id=o;
  IF i=1 AND EXISTS(SELECT 1 FROM section9_onboard_departure_snapshots_v1 WHERE physical_flight_id=physical) THEN RAISE EXCEPTION 'gate-off snapshot'; END IF;
  IF i>1 AND NOT EXISTS(SELECT 1 FROM section9_onboard_departure_snapshots_v1 WHERE physical_flight_id=physical AND model_version='GAME_CABIN_SERVICE_V2' AND passengers=100) THEN RAISE EXCEPTION 'snapshot missing'; END IF;
  IF i=3 THEN
   -- Paid service financial arithmetic test, not an active custom route test.
   UPDATE section9_onboard_departure_snapshots_v1 SET package_id='pkg-1',package_items='{"water":{"mode":"included"},"coffee":{"mode":"onboard","onboardCents":500}}' WHERE physical_flight_id=physical;
  END IF;
  INSERT INTO section9_actual_ticket_finance_preparations_v1 VALUES(physical,a,s,'2026-11-21',physical||':a',100,5000,'ACTUAL_TICKET_POSTARRIVAL_PREP_V1','UNPOSTED_GAME_ESTIMATE');
  INSERT INTO section9_flight_final_cost_approvals_v1 VALUES(physical,a,physical||':a',1000,500,fees,0,0,0,0,100,true,'fixture-fuel-reference','fixture-tariff-model','fixture-tariff-reference','approved',now(),'fixture-approval-reference');
  expected_revenue:=0;expected_cost:=0;
  IF i>1 THEN
   c:=section9_prepare_onboard_financials_v1(physical,a,physical||':a',100);
   IF c->>'status' <> 'onboard_finance_ready' THEN RAISE EXCEPTION 'calculation not ready %',c; END IF;
   expected_revenue:=(c->>'revenueUsd')::numeric;expected_cost:=(c->>'costUsd')::numeric;
   IF expected_cost<=0 OR (i=2 AND expected_revenue<>0) OR (i=3 AND expected_revenue<=0) THEN RAISE EXCEPTION 'unexpected amounts %',c;END IF;
   IF section9_prepare_onboard_financials_v1(physical,a,physical||':a',99)->>'status'<>'onboard_snapshot_evidence_mismatch' THEN RAISE EXCEPTION 'passenger mismatch allowed';END IF;
  END IF;
  SELECT cash_usd INTO opening FROM airlines WHERE id=a;
  SELECT count(*) INTO before_count FROM airline_ledger;
  r:=section9_post_completed_flight_finance_once_v1(physical);
  IF r->>'posted'<>'true' OR (r->>'revenueUsd')::numeric<>5000+expected_revenue OR (r->>'expenseUsd')::numeric<>1500+expected_cost THEN RAISE EXCEPTION 'settlement mismatch %',r;END IF;
  SELECT * INTO STRICT posted FROM section9_route_posted_flight_financials_v1 WHERE physical_flight_id=physical;
  IF posted.ticket_income_usd<>5000 OR posted.other_income_usd<>expected_revenue OR posted.other_cost_usd<>expected_cost THEN RAISE EXCEPTION 'incorrect flight line items';END IF;
  IF (SELECT cash_usd FROM airlines WHERE id=a)<>opening+3500+expected_revenue-expected_cost OR (SELECT sum(amount_usd) FROM airline_ledger WHERE airline_id=a)<>(SELECT cash_usd FROM airlines WHERE id=a) THEN RAISE EXCEPTION 'cash reconciliation failed';END IF;
  IF i>1 THEN
   SELECT * INTO STRICT receipt FROM section9_onboard_finance_receipts_v1 WHERE physical_flight_id=physical;
   IF receipt.onboard_revenue_usd<>expected_revenue OR receipt.onboard_cost_usd<>expected_cost THEN RAISE EXCEPTION 'receipt mismatch';END IF;
  END IF;
  r:=section9_post_completed_flight_finance_once_v1(physical);
  IF r->>'replayed'<>'true' OR (SELECT count(*) FROM airline_ledger)<>before_count+2 THEN RAISE EXCEPTION 'duplicate ledger entries';END IF;
 END LOOP;
 IF (SELECT count(*) FROM section9_onboard_finance_receipts_v1)<>2 THEN RAISE EXCEPTION 'receipt count incorrect';END IF;
 RAISE NOTICE 'PASS: gated legacy settlement, departure capture, free and paid consumption, ticket separation, cash/ledger reconciliation, passenger mismatch and replay';
END $test$;
ROLLBACK;
