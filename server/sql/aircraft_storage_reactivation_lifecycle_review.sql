-- ROLLBACK-ONLY REVIEW. Requires outbound movement adapter.
-- The automatic worker must call these in the same transaction as the
-- corresponding signed movement and fuel receipt; no standalone release.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_reactivation_receipts_v1(
 request_id uuid PRIMARY KEY REFERENCES airlinerra_game.aircraft_storage_relocation_requests_v1(id),
 storage_session_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.aircraft_storage_sessions_v1(request_id),
 departure_engine_event_id text NOT NULL UNIQUE REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 departure_utc timestamptz NOT NULL,
 arrival_engine_event_id text UNIQUE REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 arrival_utc timestamptz,
 expense_ledger_id bigint UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 CHECK((arrival_engine_event_id IS NULL AND arrival_utc IS NULL AND expense_ledger_id IS NULL)
 OR (arrival_engine_event_id IS NOT NULL AND arrival_utc>departure_utc AND expense_ledger_id IS NOT NULL))
);
ALTER TABLE airlinerra_game.aircraft_storage_reactivation_receipts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_reactivation_receipts_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.close_storage_at_reactivation_departure_v1(p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record; s record; d record; p record; receipt record; physical text; billing jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request AND purpose='storage_reactivation';
 IF NOT FOUND THEN RAISE EXCEPTION 'REACTIVATION_REQUEST_UNKNOWN';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=r.airline_id FOR UPDATE;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND airline_id=r.airline_id AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'REACTIVATION_AIRCRAFT_UNKNOWN';END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request FOR UPDATE;
 SELECT * INTO receipt FROM airlinerra_game.aircraft_storage_reactivation_receipts_v1 WHERE request_id=p_request;
 IF FOUND THEN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE request_id=receipt.storage_session_id AND storage_ended_utc=receipt.departure_utc) THEN RAISE EXCEPTION 'REACTIVATION_DEPARTURE_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status','storage_already_closed','replayed',true,'billingStopped',true);END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_reactivation_release_v1 WHERE world_id=1 AND enabled)
 OR r.status<>'reactivation_awaiting_review' THEN RAISE EXCEPTION 'REACTIVATION_DEPARTURE_NOT_RELEASED';END IF;
 SELECT * INTO s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE request_id=r.storage_session_id AND airline_id=r.airline_id AND aircraft_inventory_id=r.aircraft_inventory_id AND airport_key=r.origin_airport_key AND storage_ended_utc IS NULL FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'REACTIVATION_STORAGE_SESSION_MISSING';END IF;
 physical:=r.id::text||':'||(r.departure_utc AT TIME ZONE 'UTC')::date::text||':1';
 SELECT * INTO d FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND storage_reactivation AND phase='departed' AND flight_occurrence_id=physical AND airline_id=r.airline_id AND aircraft_inventory_id=r.aircraft_inventory_id;
 IF NOT FOUND OR d.actual_event_utc IS DISTINCT FROM r.departure_utc OR d.origin_airport_key IS DISTINCT FROM s.airport_key THEN RAISE EXCEPTION 'REACTIVATION_SIGNED_DEPARTURE_MISSING';END IF;
 SELECT * INTO p FROM airlinerra_game.section9_aircraft_current_position_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id AND airline_id=r.airline_id FOR UPDATE;
 IF NOT FOUND OR p.location_status<>'in_flight' OR p.current_flight_occurrence_id IS DISTINCT FROM physical OR p.last_engine_event_id IS DISTINCT FROM d.engine_event_id OR p.storage_request_id IS DISTINCT FROM r.id OR NOT p.storage_reactivation THEN RAISE EXCEPTION 'REACTIVATION_DEPARTURE_POSITION_MISSING';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 f WHERE f.physical_flight_id=physical AND f.departure_engine_event_id=d.engine_event_id AND f.airline_id=r.airline_id AND f.aircraft_inventory_id=r.aircraft_inventory_id AND f.planned_trip_burn_kg=(r.quote#>>'{fuel,tripBurnKg}')::numeric)
 THEN RAISE EXCEPTION 'REACTIVATION_DEPARTURE_FUEL_MISSING';END IF;
 billing:=airlinerra_game.aircraft_storage_reactivation_billing_check_v1(s.request_id,d.actual_event_utc);
 IF billing->>'cleared' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'REACTIVATION_STORAGE_ARREARS';END IF;
 UPDATE airlinerra_game.aircraft_storage_sessions_v1 SET storage_ended_utc=d.actual_event_utc WHERE request_id=s.request_id AND storage_ended_utc IS NULL;
 IF NOT FOUND THEN RAISE EXCEPTION 'REACTIVATION_STORAGE_CLOSE_FAILED';END IF;
 INSERT INTO airlinerra_game.aircraft_storage_reactivation_receipts_v1(request_id,storage_session_id,departure_engine_event_id,departure_utc) VALUES(r.id,s.request_id,d.engine_event_id,d.actual_event_utc);
 -- Stored remains the fleet status during the ferry, preventing route use.
 RETURN jsonb_build_object('status','storage_closed_at_departure','billingStopped',true,'aircraftAvailable',false,'departureUtc',d.actual_event_utc,'replayed',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.close_storage_at_reactivation_departure_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.complete_aircraft_reactivation_arrival_v1(p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record; receipt record; m record; p record; i record; burn numeric; total numeric; lid bigint; physical text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request AND purpose='storage_reactivation';
 IF NOT FOUND THEN RAISE EXCEPTION 'REACTIVATION_REQUEST_UNKNOWN';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=r.airline_id FOR UPDATE;
 SELECT * INTO i FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND airline_id=r.airline_id AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'REACTIVATION_AIRCRAFT_UNKNOWN';END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request FOR UPDATE;
 SELECT * INTO receipt FROM airlinerra_game.aircraft_storage_reactivation_receipts_v1 WHERE request_id=r.id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'REACTIVATION_DEPARTURE_RECEIPT_MISSING';END IF;
 IF receipt.arrival_engine_event_id IS NOT NULL THEN
 IF r.status<>'completed' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_ledger WHERE id=receipt.expense_ledger_id AND airline_id=r.airline_id AND entry_kind='EXPENSE' AND amount_usd=-r.quoted_cost_usd) THEN RAISE EXCEPTION 'REACTIVATION_ARRIVAL_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status','reactivation_already_completed','replayed',true,'ledgerPosted',false);END IF;
 IF r.status<>'reactivation_awaiting_review' OR i.fleet_status<>'stored' OR receipt.storage_session_id IS DISTINCT FROM r.storage_session_id THEN RAISE EXCEPTION 'REACTIVATION_STATE_INVALID';END IF;
 physical:=r.id::text||':'||(r.departure_utc AT TIME ZONE 'UTC')::date::text||':1';
 SELECT * INTO m FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND storage_reactivation AND phase='arrived' AND flight_occurrence_id=physical AND airline_id=r.airline_id AND aircraft_inventory_id=r.aircraft_inventory_id;
 IF NOT FOUND OR m.actual_event_utc IS DISTINCT FROM r.arrival_utc OR m.destination_airport_key IS DISTINCT FROM r.destination_airport_key THEN RAISE EXCEPTION 'REACTIVATION_SIGNED_ARRIVAL_MISSING';END IF;
 SELECT * INTO p FROM airlinerra_game.section9_aircraft_current_position_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id AND airline_id=r.airline_id FOR UPDATE;
 IF NOT FOUND OR p.location_status<>'grounded' OR p.airport_key IS DISTINCT FROM r.destination_airport_key OR p.storage_request_id IS DISTINCT FROM r.id OR p.last_engine_event_id IS DISTINCT FROM m.engine_event_id OR NOT p.storage_reactivation THEN RAISE EXCEPTION 'REACTIVATION_ARRIVAL_POSITION_MISSING';END IF;
 burn:=(r.quote#>>'{fuel,tripBurnKg}')::numeric;
 total:=(r.quote->>'fuelCostUsd')::numeric+(r.quote->>'airportFeesUsd')::numeric;
 IF burn IS NULL OR burn<=0 OR total IS DISTINCT FROM r.quoted_cost_usd OR (r.quote->>'configurationId')::bigint IS DISTINCT FROM i.configuration_id THEN RAISE EXCEPTION 'REACTIVATION_QUOTE_MISMATCH';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 f WHERE f.physical_flight_id=physical AND f.arrival_engine_event_id=m.engine_event_id AND f.airline_id=r.airline_id AND f.aircraft_inventory_id=r.aircraft_inventory_id AND f.trip_burn_kg=burn AND f.location_airport_key=r.destination_airport_key) THEN RAISE EXCEPTION 'REACTIVATION_ARRIVAL_FUEL_MISSING';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 u WHERE u.physical_flight_id=physical AND u.arrived_engine_event_id=m.engine_event_id AND u.departed_engine_event_id=receipt.departure_engine_event_id AND u.airline_id=r.airline_id AND u.aircraft_inventory_id=r.aircraft_inventory_id AND u.flight_cycles=1 AND u.elapsed_flight_hours>0) THEN RAISE EXCEPTION 'REACTIVATION_AIRFRAME_USAGE_MISSING';END IF;
 lid:=airlinerra_game.settle_held_storage_funds_v1(r.id,r.airline_id,total,m.actual_event_utc);
 UPDATE airlinerra_game.aircraft_storage_reactivation_receipts_v1 SET arrival_engine_event_id=m.engine_event_id,arrival_utc=m.actual_event_utc,expense_ledger_id=lid WHERE request_id=r.id;
 UPDATE airlinerra_game.airline_aircraft_inventory SET fleet_status='in_service',updated_at=clock_timestamp() WHERE id=r.aircraft_inventory_id AND airline_id=r.airline_id AND fleet_status='stored';
 IF NOT FOUND THEN RAISE EXCEPTION 'REACTIVATION_FLEET_UPDATE_FAILED';END IF;
 UPDATE airlinerra_game.aircraft_storage_relocation_requests_v1 SET status='completed' WHERE id=r.id;
 RETURN jsonb_build_object('status','aircraft_reactivated','requestId',r.id,'airportKey',r.destination_airport_key,'ledgerPosted',true,'expenseUsd',total,'aircraftAvailable',true,'replayed',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.complete_aircraft_reactivation_arrival_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
