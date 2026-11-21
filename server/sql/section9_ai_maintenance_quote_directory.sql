BEGIN;
-- Fictional competitive AI providers seeded logically from the verified game
-- airport and type-specific maintenance catalog. No real MRO claims.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_ai_maintenance_quotes_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_check text,p_airport text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE f record; policy record; base numeric; quotes jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_MAINTENANCE_QUOTE_ONLY';END IF;
 SELECT i.configuration_id,a.home_airport_key INTO f
 FROM airlinerra_game.airline_aircraft_inventory i JOIN airlinerra_game.airlines a ON a.id=i.airline_id AND a.world_id=1 AND a.owner_player_id=p_player
 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE i.id=p_aircraft AND i.airline_id=p_airline AND i.ownership_type IN ('owned','leased') AND i.fleet_status='in_service';
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='MAINTENANCE_AIRCRAFT_NOT_OWNED';END IF;
 SELECT * INTO policy FROM airlinerra_game.maintenance_check_policy_v1 WHERE check_code=p_check;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','invalid_maintenance_check','readOnly',true,'quotes','[]'::jsonb);END IF;
 SELECT base_estimate_usd INTO base FROM airlinerra_game.aircraft_maintenance_check_overview_v1 WHERE aircraft_inventory_id=p_aircraft AND airline_id=p_airline AND check_code=p_check AND cost_evidence='provisional_game_tariff_not_vendor_quote';
 IF base IS NULL OR base<=0 THEN RETURN jsonb_build_object('status','maintenance_cost_unavailable','readOnly',true,'quotes','[]'::jsonb);END IF;
 WITH eligible AS (
  SELECT a.airport_key,u.airport_name,u.game_lookup_code,u.country_iso,
    coalesce((SELECT min(m.game_cost_multiplier) FROM airlinerra_game.maintenance_facility_locations_v1 m WHERE m.world_id=1 AND m.airport_key=a.airport_key AND m.game_cost_multiplier>0),1) AS location_factor
  FROM airlinerra_game.approved_game_airports a
  JOIN airlinerra_game.airport_unified_operations_v1 u ON u.world_id=1 AND u.airport_key=a.airport_key
  WHERE a.world_id=1 AND u.dispatch_eligible_by_airport_admission
   AND (p_airport IS NULL OR a.airport_key=p_airport)
   AND ((policy.airport_scope='any_approved_airport' AND a.airport_key=coalesce(p_airport,f.home_airport_key))
   OR (policy.airport_scope='type_approved_mro' AND EXISTS(
     SELECT 1 FROM airlinerra_game.maintenance_airport_capabilities_v1 c WHERE c.world_id=1 AND c.airport_key=a.airport_key AND c.configuration_id=f.configuration_id AND c.check_code=p_check AND c.approval_status='game_approved')))
 ), offers AS (
 SELECT e.*,tier.code,tier.name,tier.price_factor,tier.speed_factor,tier.quality,tier.slots
 FROM eligible e CROSS JOIN (VALUES
 ('economy','Value Aero Services',0.80::numeric,1.25::numeric,85,2),
 ('standard','Aero Technical',1.00::numeric,1.00::numeric,92,3),
 ('express','Express Aircraft Care',1.25::numeric,0.80::numeric,96,2)
 ) tier(code,name,price_factor,speed_factor,quality,slots)
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('providerKey',airport_key||':'||code,'providerName',coalesce(game_lookup_code,airport_key)||' '||name,'airportKey',airport_key,'airportName',airport_name,'airportCode',game_lookup_code,'countryIso',country_iso,'tier',code,'checkCode',p_check,
 'priceUsd',round(base*location_factor*price_factor,2),'durationMinutes',greatest(5,ceil(policy.downtime_hours*60*speed_factor/5)::int*5),'qualityRating',quality,'designCapacity',slots,'availabilityConfirmed',false,'fictionalGameProvider',true)
 ORDER BY airport_name,price_factor),'[]'::jsonb) INTO quotes FROM offers;
 RETURN jsonb_build_object('status','ai_maintenance_quote_directory','readOnly',true,'ledgerPosted',false,'aircraftInventoryId',p_aircraft,'checkCode',p_check,'quotes',quotes,'bookable',false,'note','Indicative provider quotes only; capacity and actual reservations will be connected separately.');
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_ai_maintenance_quotes_v1(uuid,uuid,uuid,text,text) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;