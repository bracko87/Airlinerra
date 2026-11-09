-- Read-only owner-bound last actually observed aircraft movement, distinct
-- from initial delivery. NEVER infer arrivals from planned routes.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_aircraft_movement_preview_v1(
 p_player uuid,p_airline uuid,p_schedule uuid
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE target record;actual_position record;source_anchor record;
 events int;world_state record;
BEGIN
 SELECT s.aircraft_inventory_id,s.configuration_id,
  f.fleet_status,f.registration
 INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a
  ON a.id=s.airline_id AND a.world_id=1 AND a.owner_player_id=p_player
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND s.world_id=1;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATED_MOVEMENT_PREVIEW_NOT_OWNED';END IF;
 SELECT p.airport_key,p.anchored_game_date,
  i.inspection_status,o.delivery_home_airport_key,
  i.reviewer_reference,i.reviewed_at
 INTO source_anchor
 FROM airlinerra_game.section9_aircraft_delivery_position_v1 p
 JOIN airlinerra_game.aircraft_acquisition_orders_v1 o
  ON o.order_id=p.acquisition_order_id
  AND o.airline_id=p.airline_id
  AND o.aircraft_inventory_id=p.aircraft_inventory_id
 JOIN airlinerra_game.aircraft_delivery_inspections_v1 i
  ON i.inspection_id=p.inspection_id AND i.order_id=o.order_id
 WHERE p.aircraft_inventory_id=target.aircraft_inventory_id
  AND p.airline_id=p_airline
  AND o.delivery_home_airport_key=p.airport_key
  AND o.registration=target.registration
  AND o.configuration_id=target.configuration_id
  AND o.order_status='delivered_pending_inspection'
  AND i.inspection_status='approved'
  AND i.reviewed_at=p.inspection_reviewed_at
  AND i.reviewer_reference=p.reviewer_reference;
 SELECT * INTO actual_position
 FROM airlinerra_game.section9_aircraft_current_position_v1 pos
 WHERE pos.aircraft_inventory_id=target.aircraft_inventory_id
  AND pos.airline_id=p_airline;
 SELECT count(*) INTO events
 FROM airlinerra_game.section9_operated_flight_movements_v1 e
 WHERE e.aircraft_inventory_id=target.aircraft_inventory_id
  AND e.airline_id=p_airline;
 SELECT w.state,c.clock_source,c.confirmed_game_date
 INTO world_state
 FROM public.airlinerra_game_worlds w
 LEFT JOIN airlinerra_game.holding_world_clock_v1 c ON c.world_id=w.id
 WHERE w.id=1;
 RETURN jsonb_build_object(
  'status',CASE
    WHEN source_anchor.airport_key IS NULL THEN 'delivery_anchor_missing'
    WHEN actual_position.aircraft_inventory_id IS NULL THEN
       'delivery_anchor_only_no_operated_flights'
    WHEN actual_position.location_status='in_flight' THEN
       'last_verified_operated_departure_in_flight'
    WHEN actual_position.location_status='grounded' THEN
       'last_verified_operated_arrival'
    ELSE 'movement_state_unavailable' END,
  'aircraftInventoryId',target.aircraft_inventory_id,
  'initialDeliveryAirport',source_anchor.airport_key,
  'deliveryAnchorValid',source_anchor.airport_key IS NOT NULL,
  'lastVerifiedGroundAirport',
   CASE WHEN actual_position.location_status='grounded'
       THEN actual_position.airport_key
     WHEN actual_position.aircraft_inventory_id IS NULL THEN
       source_anchor.airport_key ELSE NULL END,
  'locationStatus',CASE WHEN actual_position.aircraft_inventory_id IS NOT NULL
       THEN actual_position.location_status
     WHEN source_anchor.airport_key IS NOT NULL
       THEN 'delivery_only' ELSE 'unknown' END,
  'inFlightOccurrenceId',actual_position.current_flight_occurrence_id,
  'lastMovementEventUtc',actual_position.last_event_utc,
  'lastVerifiedArrivalUtc',actual_position.last_arrival_utc,
  'verifiedOperatedMovementEvents',events,
  'operatedFlightEvidencePresent',events>0,
  'worldClockCurrentlyVerified',
   world_state.state='active'
   AND world_state.clock_source='authoritative_game_engine'
   AND world_state.confirmed_game_date IS NOT NULL,
  'currentRealTimeLocationCertified',false,
  'operationalFlightActivationReleased',false,
  'canActivateNormalFlight',false,
  'readOnly',true);
END $f$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_owned_aircraft_movement_preview_v1(uuid,uuid,uuid)
 FROM PUBLIC,anon,authenticated;
