-- Airlinerra World 1: owner-verified aircraft delivery lifecycle.
-- One real day equals one game day in current World 1. Delivery due date
-- is a server-owned timestamp from the already committed acquisition order.
-- The owner can acknowledge due delivery but cannot self-approve maintenance,
-- mark an airframe in_service or activate any flight.
BEGIN;
CREATE TABLE IF NOT EXISTS airlinerra_game.aircraft_delivery_inspections_v1 (
 inspection_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 order_id uuid NOT NULL UNIQUE
  REFERENCES airlinerra_game.aircraft_acquisition_orders_v1(order_id) ON DELETE RESTRICT,
 aircraft_inventory_id uuid NOT NULL UNIQUE
  REFERENCES airlinerra_game.airline_aircraft_inventory(id) ON DELETE RESTRICT,
 inspection_status text NOT NULL DEFAULT 'pending_inspection'
  CHECK(inspection_status IN ('pending_inspection','approved','rejected')),
 requested_at timestamptz NOT NULL DEFAULT now(),
 reviewed_at timestamptz,
 reviewer_reference text,
 internal_note text,
 CONSTRAINT inspection_approval_review_required CHECK(
  inspection_status='pending_inspection' OR
  (reviewed_at IS NOT NULL AND reviewer_reference IS NOT NULL))
);
ALTER TABLE airlinerra_game.aircraft_delivery_inspections_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_delivery_inspections_v1 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.aircraft_delivery_inspections_v1 IS
 'Protected per-airframe delivery inspection. Pending is not flight-ready. No customer-facing approval or automatic airworthiness claims.';

CREATE OR REPLACE FUNCTION airlinerra_game.check_owned_aircraft_delivery_v1(
 p_player_id uuid,p_airline_id uuid,p_order_id uuid
) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE company record; requested record; inspection_state text;
BEGIN
 IF p_player_id IS NULL OR p_airline_id IS NULL OR p_order_id IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_DELIVERY_CHECK_INPUT'; END IF;
 SELECT a.id,a.owner_player_id,a.world_id,w.state
 INTO company
 FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships w
 ON w.world_id=a.world_id AND w.player_id=a.owner_player_id
 WHERE a.id=p_airline_id FOR SHARE OF a,w;
 IF NOT FOUND OR company.owner_player_id IS DISTINCT FROM p_player_id
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='AIRLINE_NOT_OWNED_BY_VERIFIED_PLAYER'; END IF;
 IF company.world_id<>1 OR company.state<>'active'
 THEN RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AIRLINE_WORLD_NOT_ACTIVE_FOR_DELIVERY'; END IF;

 SELECT o.* INTO requested
 FROM airlinerra_game.aircraft_acquisition_orders_v1 o
 WHERE o.order_id=p_order_id AND o.airline_id=p_airline_id
 AND o.player_id=p_player_id
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='AIRCRAFT_ORDER_NOT_OWNED'; END IF;

 IF requested.order_status='awaiting_delivery' AND now()>=requested.delivery_due_at THEN
  UPDATE airlinerra_game.aircraft_acquisition_orders_v1
  SET order_status='delivered_pending_inspection'
  WHERE order_id=p_order_id AND order_status='awaiting_delivery';
  INSERT INTO airlinerra_game.aircraft_delivery_inspections_v1(
   order_id,aircraft_inventory_id)
  VALUES(requested.order_id,requested.aircraft_inventory_id)
  ON CONFLICT (order_id) DO NOTHING;
  requested.order_status:='delivered_pending_inspection';
 END IF;
 SELECT inspection_status INTO inspection_state
 FROM airlinerra_game.aircraft_delivery_inspections_v1
 WHERE order_id=requested.order_id;
 RETURN jsonb_build_object(
  'orderId',requested.order_id,
  'aircraftInventoryId',requested.aircraft_inventory_id,
  'registration',requested.registration,
  'deliveryDueAt',requested.delivery_due_at,
  'deliveryStatus',requested.order_status,
  'inspectionStatus',coalesce(inspection_state,'not_requested'),
  'readyForDelivery',now()>=requested.delivery_due_at,
  'fleetStatus',(
    SELECT i.fleet_status FROM airlinerra_game.airline_aircraft_inventory i
    WHERE i.id=requested.aircraft_inventory_id),
  'canScheduleFlight',false,
  'canActivateFlight',false
 );
END $f$;

REVOKE ALL ON FUNCTION airlinerra_game.check_owned_aircraft_delivery_v1(
 uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;

COMMENT ON FUNCTION airlinerra_game.check_owned_aircraft_delivery_v1(uuid,uuid,uuid)
 IS 'Owner-authenticated server delivery acknowledgement. Cannot approve inspection or move stored airframe into service.';

COMMIT;
