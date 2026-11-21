-- Candidate private game-cost approval function for isolated integration.
-- Not a migration or production release. Uses actual signed fuel burn and
-- existing canonical completed-flight game tariffs, not arbitrary caller costs.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_approve_completed_game_flight_cost_v1(p_id text)
 RETURNS jsonb LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $function$
DECLARE
 p record; d record; a record; model record; s record; movement record;
 policy record; engine record; hour_proof jsonb; signed_proof jsonb; ticket jsonb; quote jsonb;
 fee_lines jsonb; fee numeric; usd_per_kg numeric; fuel_cost numeric;
 reserve numeric; fee_key text; price_count integer; price_max numeric;
 approval_ref text; fuel_ref text; tariff_ref text;
 inserted integer;
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
 approval_ref:='game-completed-cost-v1-'||md5(concat_ws('|',p_id,policy.approval_reference,fuel_ref,tariff_ref));
 INSERT INTO airlinerra_game.section9_flight_final_cost_approvals_v1(
 physical_flight_id,airline_id,arrived_event_id,approval_state,approved_at,approval_reference,
 fuel_reserve_verified,fuel_reserve_kg,fuel_source_reference,tariff_source_reference,
 fuel_cost_usd,airport_navigation_cost_usd,crew_cost_usd,maintenance_cost_usd,ownership_cost_usd,other_cost_usd,
 airport_fee_lines,tariff_model_version)
 VALUES(p_id,p.airline_id,p.arrival_event_id,'approved',clock_timestamp(),approval_ref,
 true,reserve,fuel_ref,tariff_ref,fuel_cost,fee,0,0,0,0,fee_lines,quote->>'airportFeeQuoteModelVersion')
 ON CONFLICT(physical_flight_id) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_final_cost_approvals_v1 c
  WHERE c.physical_flight_id=p_id AND c.airline_id=p.airline_id AND c.arrived_event_id=p.arrival_event_id
  AND c.approval_state='approved' AND c.approval_reference=approval_ref
  AND c.fuel_cost_usd=fuel_cost AND c.airport_navigation_cost_usd=fee
  AND c.fuel_reserve_kg=reserve AND c.fuel_reserve_verified=true AND c.airport_fee_lines=fee_lines
  AND c.fuel_source_reference=fuel_ref AND c.tariff_source_reference=tariff_ref
  AND c.tariff_model_version=quote->>'airportFeeQuoteModelVersion'
  AND c.crew_cost_usd=0 AND c.maintenance_cost_usd=0 AND c.ownership_cost_usd=0 AND c.other_cost_usd=0)
 THEN RAISE EXCEPTION 'SECTION9_GAME_COST_APPROVAL_REPLAY_CONFLICT' USING ERRCODE='23505';END IF;
 RETURN jsonb_build_object('status',CASE WHEN inserted=1 THEN 'game_flight_cost_approved' ELSE 'game_flight_cost_approval_replayed' END,
 'approved',true,'fuelCostUsd',fuel_cost,'airportCostUsd',fee,'ledgerPosted',false);
END $function$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_approve_completed_game_flight_cost_v1(text) FROM PUBLIC,anon,authenticated,service_role;

-- Bounded stage between the existing post-arrival preparation scheduler
-- and the existing final posting scheduler. No release switches changed.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_auto_approve_completed_game_flight_costs_v1(p_limit integer DEFAULT 20)
 RETURNS jsonb LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $function$
DECLARE item record; r jsonb; checked int:=0; approved int:=0; waiting int:=0;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION 'SECTION9_PRIVATE_GAME_COST_BATCH_ONLY' USING ERRCODE='42501';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION 'SECTION9_GAME_COST_BATCH_LIMIT' USING ERRCODE='22023';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_engine_readiness_audit_v1
  WHERE world_id=1 AND trusted_flight_execution_release='ACTIVATED'
  AND fuel_transaction_release='ACTIVATED' AND automatic_flight_and_fuel_settlement_enabled=true)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_finance_posting_release_v1
  WHERE world_id=1 AND release_state='approved' AND approved_at IS NOT NULL AND length(approval_reference)>=20)
 THEN RETURN jsonb_build_object('status','blocked_game_cost_release','checked',0,'approved',0,'waiting',0);END IF;
 IF NOT pg_try_advisory_xact_lock(583731,10053) THEN
  RETURN jsonb_build_object('status','game_cost_batch_busy','checked',0,'approved',0,'waiting',0);END IF;
 FOR item IN SELECT p.physical_flight_id
  FROM airlinerra_game.section9_actual_ticket_finance_preparations_v1 p
  WHERE p.preparation_status='UNPOSTED_GAME_ESTIMATE'
  AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_final_cost_approvals_v1 a
   WHERE a.physical_flight_id=p.physical_flight_id AND a.approval_state='approved')
  AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_route_posted_flight_financials_v1 done
   WHERE done.physical_flight_id=p.physical_flight_id)
  ORDER BY p.flight_local_date,p.physical_flight_id LIMIT p_limit
 LOOP
  checked:=checked+1;
  r:=airlinerra_game.section9_approve_completed_game_flight_cost_v1(item.physical_flight_id);
  IF r->>'status' IN('game_flight_cost_approved','game_flight_cost_approval_replayed') AND r->>'approved'='true'
   AND r->>'ledgerPosted'='false' THEN approved:=approved+1;
  ELSIF r->>'approved'='false' THEN waiting:=waiting+1;
  ELSE RAISE EXCEPTION 'SECTION9_GAME_COST_BATCH_UNEXPECTED_RESULT' USING ERRCODE='42501';END IF;
 END LOOP;
 RETURN jsonb_build_object('status','game_cost_batch_completed','checked',checked,'approved',approved,'waiting',waiting);
END $function$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_auto_approve_completed_game_flight_costs_v1(integer) FROM PUBLIC,anon,authenticated,service_role;
