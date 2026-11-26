-- ROLLBACK-ONLY REVIEW. Requires signed storage movement schema in same transaction.
BEGIN;
ALTER TABLE airlinerra_game.aircraft_storage_relocation_requests_v1
 DROP CONSTRAINT aircraft_storage_relocation_requests_v1_status_check,
 ADD CONSTRAINT aircraft_storage_request_status_v2 CHECK(status IN('awaiting_slot_and_dispatch_release','cancelled','completed'));
CREATE TABLE airlinerra_game.aircraft_storage_sessions_v1(
 request_id uuid PRIMARY KEY REFERENCES airlinerra_game.aircraft_storage_relocation_requests_v1(id),
 world_id smallint NOT NULL CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 airport_key text NOT NULL,
 physical_flight_id text NOT NULL UNIQUE,
 arrival_engine_event_id text NOT NULL UNIQUE REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 storage_started_utc timestamptz NOT NULL,
 storage_ended_utc timestamptz,
 relocation_expense_usd numeric(14,2) NOT NULL CHECK(relocation_expense_usd>0),
 expense_ledger_id bigint NOT NULL UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.aircraft_storage_facilities_v1(world_id,airport_key),
 CHECK(storage_ended_utc IS NULL OR storage_ended_utc>=storage_started_utc)
);
CREATE UNIQUE INDEX aircraft_storage_active_session_v1 ON airlinerra_game.aircraft_storage_sessions_v1(aircraft_inventory_id) WHERE storage_ended_utc IS NULL;
ALTER TABLE airlinerra_game.aircraft_storage_sessions_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_sessions_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.guard_storage_request_lifecycle_v1() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 IF OLD.status='completed' AND NEW IS DISTINCT FROM OLD THEN RAISE EXCEPTION 'STORAGE_COMPLETED_REQUEST_IMMUTABLE';END IF;
 IF NEW.status='cancelled' AND OLD.status IS DISTINCT FROM NEW.status AND EXISTS(
 SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=OLD.id AND phase='departed')
 THEN RAISE EXCEPTION 'STORAGE_FLIGHT_ALREADY_DEPARTED';END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_storage_request_lifecycle_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER storage_request_lifecycle_guard BEFORE UPDATE ON airlinerra_game.aircraft_storage_relocation_requests_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_storage_request_lifecycle_v1();

CREATE FUNCTION airlinerra_game.complete_aircraft_storage_arrival_v1(p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record; a record; i record; s record; m record; dep record; b record; u record; pos record; physical text; burn numeric; fee numeric; fuel_cost numeric; total numeric; ledger_id bigint; proof jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' OR NOT EXISTS(
 SELECT 1 FROM airlinerra_game.aircraft_storage_signed_movement_release_v1 WHERE world_id=1 AND enabled)
 THEN RAISE EXCEPTION 'STORAGE_ARRIVAL_NOT_RELEASED';END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request;
 IF NOT FOUND THEN RAISE EXCEPTION 'STORAGE_REQUEST_UNKNOWN';END IF;
 -- Match the request reservation lock order.
 SELECT * INTO a FROM airlinerra_game.airlines WHERE id=r.airline_id AND world_id=1 AND owner_player_id=r.owner_player_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'STORAGE_AIRLINE_MISMATCH';END IF;
 SELECT * INTO i FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND airline_id=r.airline_id AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'STORAGE_AIRCRAFT_MISMATCH';END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request FOR UPDATE;
 SELECT * INTO s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE request_id=r.id;
 IF FOUND THEN
 IF r.status<>'completed' OR s.airline_id<>r.airline_id OR s.aircraft_inventory_id<>r.aircraft_inventory_id OR s.airport_key<>r.destination_airport_key OR NOT EXISTS(
 SELECT 1 FROM airlinerra_game.airline_ledger WHERE id=s.expense_ledger_id AND airline_id=s.airline_id AND entry_kind='EXPENSE' AND amount_usd=-s.relocation_expense_usd)
 THEN RAISE EXCEPTION 'STORAGE_SETTLEMENT_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status','storage_arrival_already_completed','replayed',true,'ledgerPosted',false,'requestId',r.id);END IF;
 IF r.status<>'awaiting_slot_and_dispatch_release' OR i.fleet_status<>'in_service' THEN RAISE EXCEPTION 'STORAGE_ARRIVAL_STATE_INVALID';END IF;
 physical:=r.id::text||':'||(r.departure_utc AT TIME ZONE 'UTC')::date::text||':1';
 SELECT * INTO m FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND flight_occurrence_id=physical AND phase='arrived' AND airline_id=r.airline_id AND aircraft_inventory_id=r.aircraft_inventory_id;
 IF NOT FOUND OR m.destination_airport_key IS DISTINCT FROM r.destination_airport_key OR m.actual_event_utc IS DISTINCT FROM r.arrival_utc THEN RAISE EXCEPTION 'STORAGE_ARRIVAL_NOT_PROVEN';END IF;
 SELECT * INTO dep FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND flight_occurrence_id=physical AND phase='departed' AND airline_id=r.airline_id AND aircraft_inventory_id=r.aircraft_inventory_id;
 IF NOT FOUND OR dep.actual_event_utc IS DISTINCT FROM r.departure_utc OR dep.origin_airport_key IS DISTINCT FROM r.origin_airport_key THEN RAISE EXCEPTION 'STORAGE_DEPARTURE_NOT_PROVEN';END IF;
 proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true' OR proof->>'gameHourUtc' IS NULL OR m.actual_event_utc>(proof->>'gameHourUtc')::timestamptz OR m.actual_event_utc>clock_timestamp() THEN RAISE EXCEPTION 'STORAGE_ARRIVAL_CLOCK_UNVERIFIED';END IF;
 SELECT * INTO pos FROM airlinerra_game.section9_aircraft_current_position_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id AND airline_id=r.airline_id FOR UPDATE;
 IF NOT FOUND OR pos.location_status<>'grounded' OR pos.airport_key IS DISTINCT FROM r.destination_airport_key OR pos.storage_request_id IS DISTINCT FROM r.id OR pos.last_engine_event_id IS DISTINCT FROM m.engine_event_id THEN RAISE EXCEPTION 'STORAGE_ARRIVAL_POSITION_UNVERIFIED';END IF;
 SELECT * INTO b FROM airlinerra_game.section9_game_flight_fuel_arrival_receipts_v1 WHERE physical_flight_id=physical AND arrival_engine_event_id=m.engine_event_id AND airline_id=r.airline_id AND aircraft_inventory_id=r.aircraft_inventory_id;
 IF NOT FOUND OR b.location_airport_key IS DISTINCT FROM r.destination_airport_key THEN RAISE EXCEPTION 'STORAGE_FUEL_BURN_NOT_PROVEN';END IF;
 SELECT * INTO u FROM airlinerra_game.section9_arrived_aircraft_usage_receipts_v1 WHERE physical_flight_id=physical AND arrived_engine_event_id=m.engine_event_id AND departed_engine_event_id=dep.engine_event_id AND airline_id=r.airline_id AND aircraft_inventory_id=r.aircraft_inventory_id;
 IF NOT FOUND OR u.flight_cycles IS DISTINCT FROM 1 OR u.elapsed_flight_hours<=0 THEN RAISE EXCEPTION 'STORAGE_AIRFRAME_USAGE_NOT_PROVEN';END IF;
 burn:=(r.quote#>>'{fuel,tripBurnKg}')::numeric;
 fuel_cost:=(r.quote->>'fuelCostUsd')::numeric;fee:=(r.quote->>'airportFeesUsd')::numeric;total:=fuel_cost+fee;
 IF burn IS NULL OR burn<=0 OR b.trip_burn_kg IS DISTINCT FROM burn OR fuel_cost IS NULL OR fuel_cost<=0 OR fee IS NULL OR fee<0 OR total IS DISTINCT FROM r.quoted_cost_usd OR (r.quote->>'configurationId')::bigint IS DISTINCT FROM i.configuration_id
 THEN RAISE EXCEPTION 'STORAGE_SETTLEMENT_QUOTE_MISMATCH';END IF;
 -- As with maintenance relocation, do not strand an aircraft already arrived
 -- if another transaction depleted the funds. Post the committed expense once.
 INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd,recorded_at) VALUES(r.airline_id,'EXPENSE',-total,m.actual_event_utc) RETURNING id INTO ledger_id;
 INSERT INTO airlinerra_game.aircraft_storage_sessions_v1(request_id,world_id,airline_id,aircraft_inventory_id,airport_key,physical_flight_id,arrival_engine_event_id,storage_started_utc,relocation_expense_usd,expense_ledger_id)
 VALUES(r.id,1,r.airline_id,r.aircraft_inventory_id,r.destination_airport_key,physical,m.engine_event_id,m.actual_event_utc,total,ledger_id);
 UPDATE airlinerra_game.airline_aircraft_inventory SET fleet_status='stored',updated_at=clock_timestamp() WHERE id=i.id AND airline_id=r.airline_id AND fleet_status='in_service';
 IF NOT FOUND THEN RAISE EXCEPTION 'STORAGE_STATUS_UPDATE_FAILED';END IF;
 UPDATE airlinerra_game.aircraft_storage_relocation_requests_v1 SET status='completed' WHERE id=r.id;
 RETURN jsonb_build_object('status','aircraft_stored','requestId',r.id,'airportKey',r.destination_airport_key,'storedSinceUtc',m.actual_event_utc,'ledgerPosted',true,'expenseUsd',total,'replayed',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.complete_aircraft_storage_arrival_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
