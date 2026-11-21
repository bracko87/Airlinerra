BEGIN;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_relocation_status_v1(p_player uuid,p_airline uuid,p_aircraft uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE results jsonb; enabled boolean;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_RELOCATION_STATUS_ONLY';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory f JOIN airlinerra_game.airlines a ON a.id=f.airline_id AND a.owner_player_id=p_player AND a.world_id=1 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active' WHERE f.id=p_aircraft AND f.airline_id=p_airline AND f.ownership_type IN ('owned','leased')) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='RELOCATION_AIRCRAFT_NOT_OWNED';END IF;
 SELECT reservation_enabled AND execution_enabled INTO enabled FROM airlinerra_game.section9_relocation_release_v1 WHERE world_id=1;
 SELECT coalesce(jsonb_agg(to_jsonb(q) ORDER BY q."departureUtc" DESC),'[]'::jsonb) INTO results FROM (
 SELECT t.id AS "tripId",t.status,t.check_code AS "checkCode",t.quote#>>'{provider,providerName}' AS "providerName",t.departure_utc AS "departureUtc",t.available_utc AS "availableUtc",t.quoted_total_usd AS "quotedTotalUsd",t.last_result AS "lastResult",t.origin_airport_key AS "originAirportKey",t.provider_airport_key AS "providerAirportKey",
 (t.status='reserved' AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.relocation_trip_id=t.id AND phase='departed') ) AS "canCancelBeforeDeparture",
 (t.status='reserved' AND t.last_result='return_recovery_required' AND EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 j JOIN airlinerra_game.section9_game_maintenance_service_receipts_v1 m ON m.job_id=j.job_id WHERE j.job_id=t.maintenance_job_id AND j.status='completed' AND m.paid_ledger_entry_id IS NOT NULL) AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.relocation_trip_id=t.id AND weekly_entry=2 AND phase='departed')) AS "canCancelReturn",
 (SELECT coalesce(sum(fuel_cost_usd+airport_fees_usd),0) FROM airlinerra_game.section9_relocation_leg_expense_receipts_v1 e WHERE e.trip_id=t.id)+(SELECT coalesce(sum(settled_cost_usd),0) FROM airlinerra_game.section9_game_maintenance_service_receipts_v1 s WHERE s.job_id=t.maintenance_job_id) AS "paidUsd"
 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 t WHERE t.airline_id=p_airline AND t.aircraft_inventory_id=p_aircraft ORDER BY (t.status='reserved') DESC,t.departure_utc DESC LIMIT 12
 ) q;
 RETURN jsonb_build_object('status','owned_relocation_status','aircraftInventoryId',p_aircraft,'bookingEnabled',coalesce(enabled,false),'trips',results,'readOnly',true,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_relocation_status_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;