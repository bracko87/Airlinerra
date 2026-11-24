-- Final money is still unreleased on production. This CI explicitly
-- enables release on a disposable local fixture ONLY; it fabricates a
-- *clearly labelled* final tariff/cost-approval and preparation row while
-- verifying the real private signed event pair and real ticket reconciliation.
\set ON_ERROR_STOP on
DO $test$
DECLARE
 fid text:='11111111-1111-4111-8111-111111111111:2026-11-23:4';
 airline uuid:='22222222-2222-4222-8222-222222222222';
 receipt jsonb; quoted numeric; arrived text; old_sig text;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'SIGNED_FLIGHT_FINANCE_PREP_DISPOSABLE_ONLY';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1
     WHERE flight_occurrence_id=fid AND phase IN('departed','arrived'))<>2
 OR (SELECT count(*) FROM airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1
     WHERE physical_flight_id=fid)<>1
 OR (SELECT onboard_kg FROM airlinerra_game.section9_aircraft_game_fuel_custody_v1)<>380
 OR (SELECT booked_seats FROM airlinerra_game.section9_dated_flight_occurrences_v1
     WHERE id='00000000-0000-4000-8000-000000000004')<>5
 THEN RAISE EXCEPTION 'Actual signed arrived flight missing original 5 passengers or 120kg burn';END IF;

 receipt:=airlinerra_game.section9_verify_operated_flight_hmac_pair_v1(fid);
 IF receipt->>'status'<>'signed_departure_and_arrival_verified'
 OR receipt->>'signatureVerified'<>'true'
 OR receipt->>'checkedEvents'<>'2'
 THEN RAISE EXCEPTION 'Actual HMAC pair verifier blocked signed flight: %',receipt;END IF;
 receipt:=airlinerra_game.section9_postarrival_ticket_reconciliation_v1(fid);
 IF receipt->>'status'<>'postarrival_ticket_totals_reconciled'
 OR receipt->>'ticketPassengers'<>'5'
 OR (receipt->>'ticketIncomeUsd')::numeric<>250
 OR receipt->>'financeAlreadyPosted'<>'false'
 THEN RAISE EXCEPTION 'Actual post-arrival reconciliation rejected original bookings: %',receipt;END IF;
 quoted:=(receipt->>'ticketIncomeUsd')::numeric;

 -- Zero money recognition until final posting: no hidden prepayment.
 IF (SELECT count(*) FROM airlinerra_game.airline_ledger)<>1
 OR (SELECT sum(amount_usd) FROM airlinerra_game.airline_ledger)<>5000000
 THEN RAISE EXCEPTION 'Payment/ledger changed before final financial approval';END IF;
 receipt:=airlinerra_game.section9_post_completed_flight_finance_once_v1(fid);
 IF receipt->>'status'<>'blocked_game_financial_or_flight_release'
 THEN RAISE EXCEPTION 'Paused finance release was bypassed: %',receipt;END IF;

 SELECT engine_event_id INTO arrived
 FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=fid AND phase='arrived';
 INSERT INTO airlinerra_game.section9_actual_ticket_finance_preparations_v1(
  physical_flight_id,airline_id,schedule_id,flight_local_date,arrival_event_id,
  passenger_count,ticket_quote_usd,preparation_status,source_version)
 VALUES(fid,airline,'11111111-1111-4111-8111-111111111111',
  DATE '2026-11-23',arrived,5,quoted,
  'UNPOSTED_GAME_ESTIMATE','ACTUAL_TICKET_POSTARRIVAL_PREP_V1');

 INSERT INTO airlinerra_game.section9_flight_final_cost_approvals_v1(
  physical_flight_id,airline_id,arrived_event_id,approval_state,approved_at,
  approval_reference,fuel_reserve_verified,fuel_reserve_kg,
  fuel_source_reference,tariff_source_reference,
  fuel_cost_usd,airport_navigation_cost_usd,
  crew_cost_usd,maintenance_cost_usd,ownership_cost_usd,other_cost_usd,
  airport_fee_lines,tariff_model_version)
 VALUES(fid,airline,arrived,'approved',now(),
  'SYNTHETIC_CI_FINAL_APPROVAL_NOT_LIVE_20261124',
  true,180,'SYNTHETIC_CI_120KG_FUEL_INVOICE',
  'SYNTHETIC_CI_AIRPORT_FEE_RATE',
  144,75,0,0,0,0,
  jsonb_build_object(
   'departureAirportMovementUsd',15,'arrivalLandingUsd',40,
   'departureGroundHandlingUsd',10,'arrivalStandParkingUsd',10,
   'departureTerminalAirTrafficControlUsd',0,'enrouteAirTrafficControlUsd',0,
   'departingPassengerFacilityUsd',0,'departingPassengerSecurityUsd',0,
   'internationalPassengerProcessingUsd',0,'originCargoHandlingUsd',0,
   'destinationCargoHandlingUsd',0),
  'DISPOSABLE_SYNTHETIC_FINAL_COST_V1');

 UPDATE airlinerra_game.section9_flight_finance_posting_release_v1
 SET release_state='approved',approved_at=now(),
 approval_reference='SYNTHETIC_CI_FINANCE_RELEASE_NOT_LIVE'
 WHERE world_id=1;

 -- No posting before proofs, even when isolated cost approval looks valid.
 UPDATE airlinerra_game.section9_flight_final_cost_approvals_v1
 SET approval_state='unapproved' WHERE physical_flight_id=fid;
 receipt:=airlinerra_game.section9_post_completed_flight_finance_once_v1(fid);
 IF receipt->>'status'<>'blocked_unapproved_final_fuel_or_airport_cost'
 THEN RAISE EXCEPTION 'Unapproved tariff incorrectly allowed money: %',receipt;END IF;
 UPDATE airlinerra_game.section9_flight_final_cost_approvals_v1
 SET approval_state='approved' WHERE physical_flight_id=fid;

 -- Signature tamper MUST fail against the original actual HMAC verifier.
 SELECT event_hmac_sha256 INTO old_sig
 FROM airlinerra_game.section9_operated_flight_movements_v1
 WHERE flight_occurrence_id=fid AND phase='arrived';
 UPDATE airlinerra_game.section9_operated_flight_movements_v1
 SET event_hmac_sha256=repeat('f',64)
 WHERE flight_occurrence_id=fid AND phase='arrived';
 receipt:=airlinerra_game.section9_post_completed_flight_finance_once_v1(fid);
 IF receipt->>'status'<>'blocked_unverified_signed_flight_movement'
 THEN RAISE EXCEPTION 'Tampered arrival was allowed financial settlement: %',receipt;END IF;
 UPDATE airlinerra_game.section9_operated_flight_movements_v1
 SET event_hmac_sha256=old_sig
 WHERE flight_occurrence_id=fid AND phase='arrived';

 UPDATE airlinerra_game.section9_actual_ticket_finance_preparations_v1
 SET passenger_count=4 WHERE physical_flight_id=fid;
 receipt:=airlinerra_game.section9_post_completed_flight_finance_once_v1(fid);
 IF receipt->>'status'<>'blocked_real_tickets_not_reconciled'
 THEN RAISE EXCEPTION 'Mismatched prepared passenger count allowed financial posting: %',receipt;END IF;
 UPDATE airlinerra_game.section9_actual_ticket_finance_preparations_v1
 SET passenger_count=5 WHERE physical_flight_id=fid;

 UPDATE airlinerra_game.airlines SET cash_usd=4999999 WHERE id=airline;
 receipt:=airlinerra_game.section9_post_completed_flight_finance_once_v1(fid);
 IF receipt->>'status'<>'blocked_cash_ledger_reconciliation'
 THEN RAISE EXCEPTION 'Cash/ledger drift allowed settlement: %',receipt;END IF;
 UPDATE airlinerra_game.airlines SET cash_usd=5000000 WHERE id=airline;

 IF (SELECT count(*) FROM airlinerra_game.airline_ledger)<>1
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1)
 THEN RAISE EXCEPTION 'Rejected final financial attempts leaked ledger/flight settlement';END IF;
 RAISE NOTICE 'PASS SAME real signed flight finance preflights: HMAC, 5 booked seats/$250, paused, cost review, HMAC tamper, ticket count and ledger drift. Final approval is SYNTHETIC CI ONLY.';
END $test$;
