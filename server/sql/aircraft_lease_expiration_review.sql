-- REVIEW ONLY: read-only contract closeout candidates. No refund, fleet
-- mutation, schedule cancellation, or release. Only approved factory orders.
BEGIN;
CREATE FUNCTION airlinerra_game.review_expired_factory_leases_v1(p_limit integer)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE game_day date; result jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION USING ERRCODE='22023';END IF;
 game_day:=(airlinerra_game.section9_verified_world_instant_v1() AT TIME ZONE 'Europe/Berlin')::date;
 IF game_day IS NULL THEN RAISE EXCEPTION 'LEASE_CLOCK_UNVERIFIED';END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY c.expiry,c.order_id),'[]'::jsonb) INTO result
 FROM (
 SELECT o.order_id,o.airline_id,o.aircraft_inventory_id,
 airlinerra_game.aircraft_lease_anniversary_v1(d.anchored_game_date,o.contract_months::integer) AS expiry,
 i.fleet_status,
 CASE WHEN p.location_status='grounded' THEN 'grounded_review_required'
 WHEN p.location_status='in_flight' THEN 'await_arrival'
 ELSE 'position_unverified' END AS return_status,
 coalesce(r.paid_months,0) AS paid_months,o.contract_months,
 false AS refund_authorized,false AS return_authorized
 FROM airlinerra_game.aircraft_acquisition_orders_v1 o
 JOIN airlinerra_game.aircraft_acquisition_offers_v1 offer
 ON offer.offer_id=o.offer_id AND offer.world_id=o.world_id
 AND offer.configuration_id=o.configuration_id AND offer.transaction_type=o.transaction_type
 AND offer.offer_status IN ('published','retired')
 AND offer.pricing_basis='AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2'
 JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=o.aircraft_inventory_id AND i.airline_id=o.airline_id
 JOIN airlinerra_game.section9_aircraft_delivery_position_v1 d ON d.acquisition_order_id=o.order_id AND d.aircraft_inventory_id=i.id AND d.airline_id=o.airline_id AND d.world_id=o.world_id
 LEFT JOIN airlinerra_game.section9_aircraft_current_position_v1 p ON p.aircraft_inventory_id=i.id AND p.airline_id=o.airline_id AND p.world_id=o.world_id
 LEFT JOIN LATERAL (SELECT count(*)::integer AS paid_months FROM airlinerra_game.aircraft_lease_monthly_receipts_v1 x WHERE x.order_id=o.order_id AND x.airline_id=o.airline_id AND x.aircraft_inventory_id=i.id) r ON true
 WHERE o.world_id=1 AND o.transaction_type='lease' AND o.order_status='delivered_pending_inspection'
 AND i.ownership_type='leased' AND i.fleet_status IN ('in_service','maintenance')
 AND o.contract_months BETWEEN 1 AND 240 AND d.anchored_game_date IS NOT NULL
 AND airlinerra_game.aircraft_lease_anniversary_v1(d.anchored_game_date,o.contract_months::integer)<=game_day
 ORDER BY expiry,o.order_id LIMIT p_limit
 ) c;
 RETURN jsonb_build_object('status','expired_factory_lease_review','gameDate',game_day,'candidates',result,'ledgerPosted',false,'aircraftReturned',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.review_expired_factory_leases_v1(integer) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
