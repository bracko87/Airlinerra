-- REVIEW ONLY. Owner-scoped read model for the fleet storage panel.
-- No public RPC grant or mutation, no commercial airport access changes.
BEGIN;
CREATE FUNCTION airlinerra_game.owned_aircraft_storage_overview_v1(p_player uuid,p_airline uuid,p_aircraft uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE i record; s record; r record; t record; h record; b jsonb; v_now timestamptz; history jsonb; current_request jsonb; session_info jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT f.* INTO i FROM airlinerra_game.airline_aircraft_inventory f
 JOIN airlinerra_game.airlines a ON a.id=f.airline_id AND a.world_id=1 AND a.owner_player_id=p_player
 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE f.id=p_aircraft AND f.airline_id=p_airline;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='STORAGE_OVERVIEW_NOT_OWNED';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft AND owner_player_id=p_player
 AND status IN ('awaiting_slot_and_dispatch_release','reactivation_awaiting_review');
 IF FOUND THEN
 SELECT * INTO h FROM airlinerra_game.aircraft_storage_funds_v1 WHERE request_id=r.id AND airline_id=p_airline;
 current_request:=jsonb_build_object('requestId',r.id,'purpose',r.purpose,'status',r.status,'originAirportKey',r.origin_airport_key,
 'destinationAirportKey',r.destination_airport_key,'departureUtc',r.departure_utc,'arrivalUtc',r.arrival_utc,
 'quotedCostUsd',r.quoted_cost_usd,'fundsHeld',coalesce(h.status='held',false),'slotsReserved',(SELECT count(*) FROM airlinerra_game.aircraft_storage_flight_slots_v1 WHERE request_id=r.id),
 'departed',EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND phase='departed'));
 END IF;
 SELECT * INTO s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft AND storage_ended_utc IS NULL;
 IF FOUND THEN
 SELECT * INTO t FROM airlinerra_game.aircraft_storage_billing_terms_v1 WHERE request_id=s.request_id;
 IF v_now IS NOT NULL THEN b:=airlinerra_game.aircraft_storage_reactivation_billing_check_v1(s.request_id,v_now);END IF;
 session_info:=jsonb_build_object('sessionId',s.request_id,'airportKey',s.airport_key,'startedUtc',s.storage_started_utc,'monthlyUsd',t.monthly_usd,'billingClass',t.billing_class,'billing',b,
 'daysStored',CASE WHEN v_now>=s.storage_started_utc THEN floor(extract(epoch FROM(v_now-s.storage_started_utc))/86400)::int ELSE NULL END);
 END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x."startedUtc" DESC),'[]'::jsonb) INTO history FROM
 (SELECT q.request_id AS "sessionId",q.airport_key AS "airportKey",q.storage_started_utc AS "startedUtc",q.storage_ended_utc AS "endedUtc",q.relocation_expense_usd AS "inboundExpenseUsd",y.monthly_usd AS "monthlyUsd"
 FROM airlinerra_game.aircraft_storage_sessions_v1 q LEFT JOIN airlinerra_game.aircraft_storage_billing_terms_v1 y USING(request_id)
 WHERE q.airline_id=p_airline AND q.aircraft_inventory_id=p_aircraft AND q.storage_ended_utc IS NOT NULL ORDER BY q.storage_started_utc DESC LIMIT 10) x;
 RETURN jsonb_build_object('status','storage_overview_verified','airlineId',p_airline,'aircraftId',p_aircraft,'ownershipType',i.ownership_type,'fleetStatus',i.fleet_status,
 'session',session_info,'pendingRequest',current_request,'history',history,'storageCapacityUnlimited',true,'readOnly',true,'actionsReleased',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.owned_aircraft_storage_overview_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
