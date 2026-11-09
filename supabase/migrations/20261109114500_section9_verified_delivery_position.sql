-- Section 9: evidence-backed INITIAL aircraft location only.
-- Does not assert any later movement or activate commercial flights.
-- No browser can manufacture aircraft position, reviewer approvals,
-- game dates, or completed flight events.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_aircraft_delivery_position_v1(
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 aircraft_inventory_id uuid PRIMARY KEY REFERENCES
  airlinerra_game.airline_aircraft_inventory(id) ON DELETE RESTRICT,
 airline_id uuid NOT NULL REFERENCES
  airlinerra_game.airlines(id) ON DELETE RESTRICT,
 acquisition_order_id uuid NOT NULL UNIQUE REFERENCES
  airlinerra_game.aircraft_acquisition_orders_v1(order_id) ON DELETE RESTRICT,
 inspection_id uuid NOT NULL UNIQUE REFERENCES
  airlinerra_game.aircraft_delivery_inspections_v1(inspection_id) ON DELETE RESTRICT,
 airport_key text NOT NULL,
 anchored_game_date date NOT NULL CHECK (
  anchored_game_date BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'),
 reviewer_reference text NOT NULL CHECK(length(reviewer_reference)>=8),
 inspection_reviewed_at timestamptz NOT NULL,
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 source_kind text NOT NULL DEFAULT 'approved_delivery_inspection'
  CHECK(source_kind='approved_delivery_inspection'),
 FOREIGN KEY(world_id,airport_key) REFERENCES
  airlinerra_game.approved_game_airports(world_id,airport_key)
);
ALTER TABLE airlinerra_game.section9_aircraft_delivery_position_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aircraft_delivery_position_v1
 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_delivery_position_airline_idx
 ON airlinerra_game.section9_aircraft_delivery_position_v1(
  airline_id,airport_key);

CREATE OR REPLACE FUNCTION airlinerra_game.section9_reject_delivery_position_mutation_v1()
 RETURNS trigger LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
BEGIN
 RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_DELIVERY_POSITION_IS_IMMUTABLE';
END $f$;
DROP TRIGGER IF EXISTS section9_delivery_position_immutable
 ON airlinerra_game.section9_aircraft_delivery_position_v1;
CREATE TRIGGER section9_delivery_position_immutable
 BEFORE UPDATE OR DELETE ON airlinerra_game.section9_aircraft_delivery_position_v1
 FOR EACH ROW EXECUTE FUNCTION
  airlinerra_game.section9_reject_delivery_position_mutation_v1();
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_reject_delivery_position_mutation_v1()
 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.section9_aircraft_delivery_position_v1 IS
 'Immutable original delivery-location event from approved order+inspection and VERIFIED game clock. NOT the aircraft current location; later operated-flight movements need their own authoritative event source.';

CREATE OR REPLACE FUNCTION airlinerra_game.section9_capture_approved_delivery_position_v1(
 p_airline uuid,p_aircraft uuid
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE w record;c record; aircraft record;source record;existing record;
 inserted integer;
BEGIN
 IF p_airline IS NULL OR p_aircraft IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_DELIVERY_POSITION_SOURCE';END IF;
 SELECT state,opens_at INTO w FROM public.airlinerra_game_worlds
 WHERE id=1 FOR SHARE;
 SELECT * INTO c FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=1 FOR SHARE;
 IF w.state IS DISTINCT FROM 'active' OR
   w.opens_at IS NULL OR w.opens_at>clock_timestamp() OR
   c.clock_source IS DISTINCT FROM 'authoritative_game_engine' OR
   c.confirmed_game_date IS NULL OR c.last_verified_at IS NULL OR
   length(coalesce(c.engine_proof_ref,''))<12
 THEN RETURN jsonb_build_object(
   'status','blocked_unverified_world_clock',
   'deliveryPositionRecorded',false,
   'currentLocationVerified',false,
   'flightActivationReleased',false);END IF;
 SELECT id,airline_id,configuration_id,registration,fleet_status
 INTO aircraft
 FROM airlinerra_game.airline_aircraft_inventory
 WHERE id=p_aircraft AND airline_id=p_airline FOR SHARE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_AIRCRAFT_NOT_OWNED_BY_AIRLINE';END IF;
 IF aircraft.fleet_status<>'in_service' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_DELIVERY_AIRCRAFT_NOT_IN_SERVICE';END IF;
 SELECT o.order_id,o.aircraft_inventory_id,o.airline_id,
  o.delivery_home_airport_key,o.delivery_due_at,
  o.configuration_id,o.registration,
  i.inspection_id,i.reviewed_at,i.reviewer_reference
 INTO source
 FROM airlinerra_game.aircraft_acquisition_orders_v1 o
 JOIN airlinerra_game.aircraft_delivery_inspections_v1 i
  ON i.order_id=o.order_id
   AND i.aircraft_inventory_id=o.aircraft_inventory_id
 WHERE o.world_id=1 AND o.airline_id=p_airline
  AND o.aircraft_inventory_id=p_aircraft
  AND o.order_status='delivered_pending_inspection'
  AND o.delivery_due_at<=clock_timestamp()
  AND i.inspection_status='approved'
  AND i.reviewed_at IS NOT NULL AND i.reviewed_at<=clock_timestamp()
  AND length(coalesce(i.reviewer_reference,''))>=8
 FOR SHARE OF o,i;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_APPROVED_DELIVERY_INSPECTION_REQUIRED';END IF;
 IF source.configuration_id IS DISTINCT FROM aircraft.configuration_id OR
  source.registration IS DISTINCT FROM aircraft.registration THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_DELIVERY_AIRCRAFT_IDENTITY_CHANGED';END IF;
 INSERT INTO airlinerra_game.section9_aircraft_delivery_position_v1(
  world_id,aircraft_inventory_id,airline_id,acquisition_order_id,
  inspection_id,airport_key,anchored_game_date,reviewer_reference,
  inspection_reviewed_at)
 VALUES(1,p_aircraft,p_airline,source.order_id,source.inspection_id,
  source.delivery_home_airport_key,c.confirmed_game_date,
  source.reviewer_reference,source.reviewed_at)
 ON CONFLICT(aircraft_inventory_id) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 SELECT * INTO existing
 FROM airlinerra_game.section9_aircraft_delivery_position_v1
 WHERE aircraft_inventory_id=p_aircraft;
 IF NOT FOUND OR existing.airline_id IS DISTINCT FROM p_airline OR
   existing.acquisition_order_id IS DISTINCT FROM source.order_id OR
   existing.inspection_id IS DISTINCT FROM source.inspection_id OR
   existing.airport_key IS DISTINCT FROM source.delivery_home_airport_key OR
   existing.reviewer_reference IS DISTINCT FROM source.reviewer_reference OR
   existing.inspection_reviewed_at IS DISTINCT FROM source.reviewed_at
 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_DELIVERY_POSITION_SOURCE_CONFLICT';END IF;
 RETURN jsonb_build_object(
  'status',CASE WHEN inserted=1 THEN 'approved_delivery_position_recorded'
    ELSE 'approved_delivery_position_replayed' END,
  'aircraftInventoryId',p_aircraft,
  'airportKey',existing.airport_key,
  'anchoredGameDate',existing.anchored_game_date,
  'deliveryPositionRecorded',true,
  'currentLocationVerified',false,
  'flightActivationReleased',false,'bookingsCreated',false,
  'ledgerPosted',false);
END $f$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_capture_approved_delivery_position_v1(uuid,uuid)
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_sync_approved_delivery_positions_v1(
 p_limit integer DEFAULT 25
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE s record; outcome jsonb;done integer:=0;
BEGIN
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_DELIVERY_SYNC_BATCH';END IF;
 IF NOT EXISTS(
  SELECT 1 FROM public.airlinerra_game_worlds
  WHERE id=1 AND state='active' AND opens_at<=clock_timestamp()
 ) OR NOT EXISTS(
  SELECT 1 FROM airlinerra_game.holding_world_clock_v1
  WHERE world_id=1 AND clock_source='authoritative_game_engine'
   AND confirmed_game_date IS NOT NULL
   AND length(coalesce(engine_proof_ref,''))>=12
   AND last_verified_at IS NOT NULL
 ) THEN
  RETURN jsonb_build_object('status','blocked_unverified_world_clock',
   'recorded',0,'readOnlyCommercialFlights',true,
   'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 FOR s IN SELECT o.airline_id,o.aircraft_inventory_id
  FROM airlinerra_game.aircraft_acquisition_orders_v1 o
  JOIN airlinerra_game.aircraft_delivery_inspections_v1 i
   ON i.order_id=o.order_id
    AND i.aircraft_inventory_id=o.aircraft_inventory_id
  WHERE o.world_id=1 AND o.order_status='delivered_pending_inspection'
   AND o.delivery_due_at<=clock_timestamp()
   AND i.inspection_status='approved'
   AND i.reviewed_at<=clock_timestamp()
   AND length(coalesce(i.reviewer_reference,''))>=8
   AND NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section9_aircraft_delivery_position_v1 p
    WHERE p.aircraft_inventory_id=o.aircraft_inventory_id)
  ORDER BY o.created_at,o.order_id LIMIT p_limit
  FOR SHARE OF o,i
 LOOP
  outcome:=airlinerra_game.section9_capture_approved_delivery_position_v1(
   s.airline_id,s.aircraft_inventory_id);
  IF outcome->>'status'='approved_delivery_position_recorded'
  THEN done:=done+1;END IF;
 END LOOP;
 RETURN jsonb_build_object('status','delivery_position_batch_processed',
  'recorded',done,'maxBatch',p_limit,
  'readOnlyCommercialFlights',true,'bookingsCreated',false,
  'ledgerPosted',false);
END $f$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_sync_approved_delivery_positions_v1(integer)
 FROM PUBLIC,anon,authenticated;
