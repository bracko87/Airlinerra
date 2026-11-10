-- Owner-confirmed cash factory orders only. No credit or leases.
-- Serial capacity & stock allocation, with no duplicate reservations on retries.
CREATE OR REPLACE FUNCTION airlinerra_game.order_new_factory_aircraft_v2(p_player_id uuid, p_airline_id uuid, p_offer_id uuid, p_registration text, p_request_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE model record; open_market boolean;
 maker record; stock record; receipt jsonb;
 chosen_due timestamptz; factory_day date; slots_used int; using_stock boolean;
BEGIN
 SELECT (market.release_state='live' AND world.state='active'
  AND world.opens_at IS NOT NULL AND world.opens_at<=clock_timestamp())
 INTO open_market
 FROM airlinerra_game.aircraft_market_control_v1 market
 JOIN public.airlinerra_game_worlds world ON world.id=market.world_id
 WHERE market.world_id=1;
 IF open_market IS DISTINCT FROM true THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AIRCRAFT_MARKET_NOT_OPEN';
 END IF;
 SELECT o.configuration_id,o.offer_status,o.pricing_basis,o.transaction_type,
 m.manufacturer_name,m.configuration_review_status,m.production_status,m.production_start_year,m.production_end_year,
 m.model_catalog_status,m.civilian_service_status
 INTO model FROM airlinerra_game.aircraft_acquisition_offers_v1 o
 JOIN airlinerra.aircraft_catalog_configuration_inventory m
 ON m.configuration_id=o.configuration_id
 WHERE o.offer_id=p_offer_id AND o.world_id=1 FOR SHARE OF o;
 IF NOT FOUND OR model.offer_status<>'published'
  OR model.pricing_basis<>'AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2'
  OR model.production_status<>'in_production'
  OR model.model_catalog_status<>'service_verified'
  OR model.configuration_review_status<>'verified'
  OR model.civilian_service_status<>'active'
  OR model.production_start_year>extract(year from now())::int
  OR (model.production_end_year IS NOT NULL
  AND model.production_end_year<extract(year from now())::int) THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='NEW_AIRCRAFT_MODEL_NOT_ELIGIBLE';
 END IF;
 IF model.transaction_type='lease' AND NOT (
   SELECT lease_enabled FROM airlinerra_game.aircraft_market_control_v1
   WHERE world_id=1) THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AIRCRAFT_LEASE_BILLING_NOT_ACTIVE';
 END IF;
 IF EXISTS (SELECT 1 FROM airlinerra_game.used_aircraft_auction_lots_v1 l
  WHERE l.status='bidding' AND upper(l.highest_registration)=upper(btrim(p_registration))) THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AIRCRAFT_REGISTRATION_ALREADY_TAKEN';
 END IF;
 -- Serialise the manufacturer-wide production queue, and then the
 -- configuration's limited stocked aircraft. The existing owner-verified
 -- acquisition procedure handles all cash, invoice and registration writes.
 -- Both actions stay inside a SINGLE PostgreSQL transaction.
 SELECT * INTO maker FROM airlinerra_game.factory_manufacturer_capacity_v1
 WHERE world_id=1 AND manufacturer_name=model.manufacturer_name FOR UPDATE;
 IF NOT FOUND THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='FACTORY_CAPACITY_UNAVAILABLE';
 END IF;
 SELECT * INTO stock FROM airlinerra_game.factory_model_stock_v1
 WHERE world_id=1 AND configuration_id=model.configuration_id FOR UPDATE;
 IF NOT FOUND THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='FACTORY_STOCK_UNAVAILABLE';
 END IF;
 receipt:=airlinerra_game.acquire_offered_aircraft_v1(
  p_player_id,p_airline_id,p_offer_id,p_registration,p_request_id);
 IF coalesce((receipt->>'replayed')::boolean,false) THEN
  -- A previously committed idempotency key must NEVER reserve stock twice.
  RETURN receipt;
 END IF;
 using_stock:=stock.stocked_units>0;
 IF using_stock THEN
  UPDATE airlinerra_game.factory_model_stock_v1
  SET stocked_units=stocked_units-1,updated_at=now()
  WHERE world_id=1 AND configuration_id=model.configuration_id
   AND stocked_units>0;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0001',
   MESSAGE='FACTORY_STOCK_CHANGED'; END IF;
  chosen_due:=clock_timestamp()+make_interval(days=>stock.stock_delivery_days);
  factory_day:=NULL;
 ELSE
  factory_day:=greatest(coalesce(maker.next_factory_day,current_date+14),
   current_date+14);
  slots_used:=CASE WHEN maker.next_factory_day=factory_day
   THEN maker.scheduled_on_next_day ELSE 0 END;
  IF slots_used>=maker.aircraft_per_day THEN
   factory_day:=factory_day+1;
   slots_used:=0;
  END IF;
  UPDATE airlinerra_game.factory_manufacturer_capacity_v1
  SET next_factory_day=factory_day,
   scheduled_on_next_day=slots_used+1,updated_at=now()
  WHERE world_id=1 AND manufacturer_name=model.manufacturer_name;
  chosen_due:=(factory_day::timestamp AT TIME ZONE 'UTC')+interval '1 day';
 END IF;
 UPDATE airlinerra_game.aircraft_acquisition_orders_v1
 SET delivery_due_at=chosen_due
 WHERE order_id=(receipt->>'orderId')::uuid
  AND airline_id=p_airline_id AND request_id=p_request_id;
 IF NOT FOUND THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='FACTORY_ORDER_NOT_RECORDED';
 END IF;
 INSERT INTO airlinerra_game.factory_delivery_reservations_v1
  (order_id,world_id,configuration_id,manufacturer_name,source_kind,
   booked_factory_day,delivery_due_at)
 VALUES((receipt->>'orderId')::uuid,1,model.configuration_id,
   model.manufacturer_name,CASE WHEN using_stock THEN 'stock'
   ELSE 'factory_queue' END,factory_day,chosen_due);
 RETURN receipt||jsonb_build_object(
  'deliveryDueAt',chosen_due,'deliverySource',
   CASE WHEN using_stock THEN 'stock' ELSE 'factory_queue' END,
  'manufacturerDailyCapacity',maker.aircraft_per_day);
END;
$function$

REVOKE EXECUTE ON FUNCTION
 airlinerra_game.order_new_factory_aircraft_v2(uuid,uuid,uuid,text,uuid)
 FROM PUBLIC,anon,authenticated;
