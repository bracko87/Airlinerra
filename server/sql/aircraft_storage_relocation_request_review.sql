-- REVIEW ONLY: player-confirmed one-way storage relocation request.
-- A request is NOT a scheduled flight, financial hold, or dispatch clearance.
-- The signed one-way scheduler must consume it in a separate release.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_relocation_requests_v1 (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 owner_player_id uuid NOT NULL,
 request_key uuid NOT NULL,
 origin_airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 destination_airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 departure_utc timestamptz NOT NULL, arrival_utc timestamptz NOT NULL,
 quoted_cost_usd numeric(14,2) NOT NULL CHECK(quoted_cost_usd>=0),
 quote jsonb NOT NULL,
 status text NOT NULL DEFAULT 'awaiting_slot_and_dispatch_release'
 CHECK(status IN ('awaiting_slot_and_dispatch_release','cancelled')),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(), cancelled_at timestamptz,
 UNIQUE(airline_id,request_key),
 CHECK(origin_airport_key<>destination_airport_key AND arrival_utc>departure_utc),
 CHECK((status='cancelled')=(cancelled_at IS NOT NULL))
);
CREATE UNIQUE INDEX aircraft_storage_one_pending_request_v1
 ON airlinerra_game.aircraft_storage_relocation_requests_v1(aircraft_inventory_id)
 WHERE status='awaiting_slot_and_dispatch_release';
ALTER TABLE airlinerra_game.aircraft_storage_relocation_requests_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_relocation_requests_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.request_aircraft_storage_relocation_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,p_destination text,p_departure timestamptz,
 p_expected_cost numeric,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE cfg bigint; prior record; v_now timestamptz; pos jsonb; origin text;
 q jsonb; arrival timestamptz; balance numeric; ledger numeric; commitments numeric; new_id uuid;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_request IS NULL OR p_destination IS NULL OR p_expected_cost IS NULL OR p_expected_cost<0
 OR p_departure IS NULL OR p_departure<>date_trunc('second',p_departure) THEN RETURN jsonb_build_object('status','invalid_storage_request','created',false);END IF;
 -- Serialize the airline financial snapshot and this aircraft. No financial mutation.
 SELECT a.cash_usd INTO balance FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE a.id=p_airline AND a.world_id=1 AND a.owner_player_id=p_player FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='STORAGE_AIRLINE_NOT_OWNED';END IF;
 SELECT configuration_id INTO cfg FROM airlinerra_game.airline_aircraft_inventory
 WHERE id=p_aircraft AND airline_id=p_airline AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='STORAGE_AIRCRAFT_NOT_OWNED';END IF;
 SELECT * INTO prior FROM airlinerra_game.aircraft_storage_relocation_requests_v1
 WHERE airline_id=p_airline AND request_key=p_request;
 IF FOUND THEN
 IF prior.aircraft_inventory_id<>p_aircraft OR prior.destination_airport_key<>p_destination OR prior.departure_utc<>p_departure OR prior.quoted_cost_usd<>p_expected_cost
 THEN RETURN jsonb_build_object('status','storage_request_key_conflict','created',false);END IF;
 RETURN jsonb_build_object('status',prior.status,'requestId',prior.id,'created',false,'replayed',true,'flightScheduled',false);
 END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE aircraft_inventory_id=p_aircraft AND status='awaiting_slot_and_dispatch_release')
 THEN RETURN jsonb_build_object('status','storage_request_already_pending','created',false);END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=p_aircraft AND fleet_status='in_service')
 THEN RETURN jsonb_build_object('status','storage_aircraft_unavailable','created',false);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL OR p_departure<v_now+interval '1 minute' OR p_departure>v_now+interval '7 days'
 THEN RETURN jsonb_build_object('status','storage_departure_unverified','created',false);END IF;
 pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(p_player,p_airline,p_aircraft,(v_now AT TIME ZONE 'Europe/Berlin')::date);
 origin:=pos->>'airportKey';
 IF pos->>'verified' IS DISTINCT FROM 'true' OR pos->>'atGroundAirport' IS DISTINCT FROM 'true' OR origin IS NULL
 THEN RETURN jsonb_build_object('status','storage_position_unverified','created',false);END IF;
 IF origin=p_destination THEN RETURN jsonb_build_object('status','already_at_storage_airport','created',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft AND status='active')
 THEN RETURN jsonb_build_object('status','active_routes_require_closure','created',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft AND status IN ('scheduled','in_progress','payment_required'))
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE aircraft_inventory_id=p_aircraft AND status='reserved')
 THEN RETURN jsonb_build_object('status','existing_aircraft_commitment','created',false);END IF;
 q:=airlinerra_game.aircraft_storage_relocation_cost_v1(cfg,origin,p_destination,'storage_inbound');
 IF q->>'status' IS DISTINCT FROM 'storage_relocation_cost_estimate' OR q->>'fuelRangeConfirmed' IS DISTINCT FROM 'true'
 OR q->>'directOperatingCostUsd' IS NULL OR q#>>'{phases,totalMinutes}' IS NULL
 THEN RETURN jsonb_build_object('status','storage_quote_blocked','created',false,'quote',q);END IF;
 IF (q->>'directOperatingCostUsd')::numeric<>p_expected_cost THEN RETURN jsonb_build_object('status','storage_price_changed','created',false,'quote',q);END IF;
 arrival:=p_departure+make_interval(mins=>(q#>>'{phases,totalMinutes}')::integer);
 SELECT coalesce(sum(amount_usd),0) INTO ledger FROM airlinerra_game.airline_ledger WHERE airline_id=p_airline;
 SELECT coalesce(sum(quoted_cost_usd),0) INTO commitments FROM airlinerra_game.section9_game_maintenance_jobs_v1 WHERE airline_id=p_airline AND status IN ('scheduled','in_progress','payment_required');
 commitments:=commitments+(SELECT coalesce(sum(quoted_total_usd),0) FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE airline_id=p_airline AND status='reserved');
 IF balance IS DISTINCT FROM ledger OR ledger-commitments<p_expected_cost
 THEN RETURN jsonb_build_object('status','storage_funds_unverified_or_insufficient','created',false);END IF;
 INSERT INTO airlinerra_game.aircraft_storage_relocation_requests_v1(airline_id,aircraft_inventory_id,owner_player_id,request_key,origin_airport_key,destination_airport_key,departure_utc,arrival_utc,quoted_cost_usd,quote)
 VALUES(p_airline,p_aircraft,p_player,p_request,origin,p_destination,p_departure,arrival,p_expected_cost,q) RETURNING id INTO new_id;
 RETURN jsonb_build_object('status','awaiting_slot_and_dispatch_release','created',true,'requestId',new_id,'departureUtc',p_departure,'arrivalUtc',arrival,
 'flightScheduled',false,'slotsReserved',false,'fundsHeld',false,'ledgerPosted',false,'aircraftStored',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.request_aircraft_storage_relocation_v1(uuid,uuid,uuid,text,timestamptz,numeric,uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.cancel_aircraft_storage_relocation_request_v1(p_player uuid,p_airline uuid,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT t.* INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 t
 JOIN airlinerra_game.airlines a ON a.id=t.airline_id AND a.owner_player_id=p_player AND a.world_id=1
 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE t.id=p_request AND t.airline_id=p_airline AND t.owner_player_id=p_player FOR UPDATE OF t;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF r.status='cancelled' THEN RETURN jsonb_build_object('status','cancelled','replayed',true,'ledgerPosted',false);END IF;
 UPDATE airlinerra_game.aircraft_storage_relocation_requests_v1 SET status='cancelled',cancelled_at=clock_timestamp() WHERE id=r.id;
 RETURN jsonb_build_object('status','cancelled','replayed',false,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.cancel_aircraft_storage_relocation_request_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
