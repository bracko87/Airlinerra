-- A lease contract needs recurring billing, so keep lease bidding locked until
-- the separate recurring-payment engine has been proven.
ALTER TABLE airlinerra_game.aircraft_market_control_v1
 ADD COLUMN lease_enabled boolean NOT NULL DEFAULT false;
-- Airlinerra market state machine v1. No auctions or factory payments until
-- a separately authorised world/game release changes market gate to live.
-- All bid/settlement transfers execute in one PostgreSQL transaction.
CREATE OR REPLACE FUNCTION airlinerra_game.place_used_aircraft_bid_v1(
 p_player_id uuid,p_airline_id uuid,p_listing_id uuid,
 p_bid_usd numeric,p_registration text,p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $fn$
DECLARE lot record; bid record; prior record; actor record;
 normalized text; required_hold numeric(14,2);
 new_deadline timestamptz; market_allowed boolean;
BEGIN
 IF p_player_id IS NULL OR p_airline_id IS NULL OR p_listing_id IS NULL
  OR p_request_id IS NULL OR p_bid_usd IS NULL
  OR p_bid_usd<100 OR p_bid_usd>1000000000000
  OR p_bid_usd<>round(p_bid_usd,2) THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_USED_AIRCRAFT_BID';
 END IF;
 normalized:=upper(btrim(coalesce(p_registration,'')));
 IF normalized !~ '^[A-Z0-9][A-Z0-9-]{2,18}[A-Z0-9]$' THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_AIRCRAFT_REGISTRATION';
 END IF;
 -- Disallow auction money movement before world is officially open.
 SELECT (market.release_state='live' AND world.state='active'
   AND world.opens_at IS NOT NULL AND world.opens_at<=clock_timestamp())
 INTO market_allowed
 FROM airlinerra_game.aircraft_market_control_v1 market
 JOIN public.airlinerra_game_worlds world ON world.id=market.world_id
 WHERE market.world_id=1;
 IF market_allowed IS DISTINCT FROM true THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AIRCRAFT_MARKET_NOT_OPEN';
 END IF;
 SELECT * INTO lot FROM airlinerra_game.used_aircraft_auction_lots_v1
 WHERE listing_id=p_listing_id AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='USED_AIRCRAFT_OFFER_NOT_AVAILABLE';
 END IF;
 -- Safe client retries return the prior accepted bid without a second hold.
 SELECT * INTO bid FROM airlinerra_game.used_aircraft_auction_bids_v1
 WHERE airline_id=p_airline_id AND request_id=p_request_id;
 IF FOUND THEN
  IF bid.listing_id<>p_listing_id OR bid.bid_usd<>p_bid_usd
   OR bid.registration<>normalized OR bid.player_id<>p_player_id THEN
   RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AUCTION_IDEMPOTENCY_KEY_REUSED';
  END IF;
  RETURN jsonb_build_object('status','accepted_replay','bidId',bid.bid_id,
   'listingId',lot.listing_id,'bidUsd',bid.bid_usd::text,
   'holdStatus',bid.hold_status,'deadlineUtc',lot.close_after_utc,
   'cashReservedAgain',false);
 END IF;
 IF lot.offering_type='lease' AND NOT (
   SELECT lease_enabled FROM airlinerra_game.aircraft_market_control_v1
   WHERE world_id=1) THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AIRCRAFT_LEASE_BILLING_NOT_ACTIVE';
 END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_acquisition_orders_v1
   WHERE airline_id=p_airline_id AND request_id=p_request_id) THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AUCTION_REQUEST_ID_ALREADY_USED';
 END IF;
 IF lot.status NOT IN ('available','bidding') THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='USED_AIRCRAFT_OFFER_NOT_AVAILABLE';
 END IF;
 IF lot.status='bidding' AND lot.close_after_utc<=clock_timestamp() THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AUCTION_CLOSED_PENDING_SETTLEMENT';
 END IF;
 IF lot.highest_bid_airline_id=p_airline_id THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='ALREADY_HIGHEST_BIDDER';
 END IF;
 IF p_bid_usd < CASE WHEN lot.highest_bid_usd IS NULL THEN lot.opening_bid_usd
                     ELSE lot.highest_bid_usd+lot.min_bid_increment_usd END THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AUCTION_BID_BELOW_REQUIRED_AMOUNT';
 END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory i
   WHERE upper(i.registration)=normalized) OR EXISTS(
   SELECT 1 FROM airlinerra_game.used_aircraft_auction_lots_v1 x
   WHERE x.listing_id<>p_listing_id AND x.status='bidding'
    AND upper(x.highest_registration)=normalized) THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AIRCRAFT_REGISTRATION_ALREADY_TAKEN';
 END IF;
 IF lot.status='bidding' THEN
  SELECT * INTO prior FROM airlinerra_game.used_aircraft_auction_bids_v1
  WHERE bid_id=lot.winning_bid_id AND listing_id=p_listing_id
  AND hold_status='held';
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0001',
   MESSAGE='AUCTION_ESCROW_INCONSISTENT'; END IF;
 END IF;
 -- Lock both affected airlines in deterministic order to avoid deadlocks.
 PERFORM 1 FROM airlinerra_game.airlines a WHERE a.id=p_airline_id
  OR (lot.highest_bid_airline_id IS NOT NULL AND a.id=lot.highest_bid_airline_id)
 ORDER BY a.id FOR UPDATE;
 SELECT a.id,a.owner_player_id,a.world_id,a.cash_usd,w.state
 INTO actor FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships w
 ON w.world_id=a.world_id AND w.player_id=a.owner_player_id
 WHERE a.id=p_airline_id;
 IF NOT FOUND OR actor.owner_player_id IS DISTINCT FROM p_player_id
   OR actor.world_id<>1 OR actor.state<>'active' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='AIRLINE_NOT_OWNED_BY_VERIFIED_PLAYER';
 END IF;
 -- Purchase: hold the entire bid. Lease: hold a fixed deposit + first month.
 -- All amounts are spent in this transaction; no late overdrawn winner.
 required_hold:=CASE WHEN lot.offering_type='purchase' THEN p_bid_usd
  ELSE p_bid_usd+lot.fixed_lease_deposit_usd END;
 IF actor.cash_usd < required_hold THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='INSUFFICIENT_AIRLINE_CASH';
 END IF;
 UPDATE airlinerra_game.airlines SET cash_usd=cash_usd-required_hold
  WHERE id=p_airline_id AND cash_usd>=required_hold;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0001',
  MESSAGE='INSUFFICIENT_AIRLINE_CASH'; END IF;
 INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
 VALUES(p_airline_id,'AIRCRAFT_AUCTION_HOLD',-required_hold);
 -- Refund the former leader exactly once, in the SAME transaction.
 IF lot.status='bidding' THEN
  UPDATE airlinerra_game.airlines SET cash_usd=cash_usd+prior.held_usd
   WHERE id=prior.airline_id;
  INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
  VALUES(prior.airline_id,'AIRCRAFT_AUCTION_REFUND',prior.held_usd);
  UPDATE airlinerra_game.used_aircraft_auction_bids_v1
  SET hold_status='refunded' WHERE bid_id=prior.bid_id AND hold_status='held';
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0001',
   MESSAGE='AUCTION_ESCROW_INCONSISTENT'; END IF;
 END IF;
 INSERT INTO airlinerra_game.used_aircraft_auction_bids_v1
 (listing_id,airline_id,player_id,request_id,registration,bid_usd,held_usd)
 VALUES(p_listing_id,p_airline_id,p_player_id,p_request_id,
 normalized,p_bid_usd,required_hold) RETURNING * INTO bid;
 new_deadline:=clock_timestamp()+interval '15 minutes';
 UPDATE airlinerra_game.used_aircraft_auction_lots_v1
 SET status='bidding',highest_bid_usd=p_bid_usd,
 highest_bid_airline_id=p_airline_id,highest_bid_player_id=p_player_id,
 highest_registration=normalized,winning_bid_id=bid.bid_id,
 last_bid_utc=clock_timestamp(),close_after_utc=new_deadline,
 bid_count=bid_count+1
 WHERE listing_id=p_listing_id;
 RETURN jsonb_build_object(
  'status','bid_accepted','listingId',p_listing_id,
  'bidId',bid.bid_id,'bidUsd',p_bid_usd::text,
  'heldUsd',required_hold::text,'deadlineUtc',new_deadline,
  'bidCount',lot.bid_count+1,'cashReservedAgain',true,
  'aircraftAssigned',false);
END;
$fn$;

-- New factory order must use production-approved models and a still-open
-- World 1 + explicit market switch. The legacy acquisition procedure handles
-- owner funds, ledger and acquisition idempotency under row locks.
CREATE OR REPLACE FUNCTION airlinerra_game.order_new_factory_aircraft_v2(
 p_player_id uuid,p_airline_id uuid,p_offer_id uuid,
 p_registration text,p_request_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $fn$
DECLARE model record; open_market boolean;
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
 SELECT o.offer_status,o.pricing_basis,o.transaction_type,
 m.production_status,m.production_start_year,m.production_end_year,
 m.model_catalog_status,m.civilian_service_status
 INTO model FROM airlinerra_game.aircraft_acquisition_offers_v1 o
 JOIN airlinerra.aircraft_catalog_configuration_inventory m
 ON m.configuration_id=o.configuration_id
 WHERE o.offer_id=p_offer_id AND o.world_id=1 FOR SHARE OF o;
 IF NOT FOUND OR model.offer_status<>'published'
  OR model.pricing_basis<>'AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2'
  OR model.production_status<>'in_production'
  OR model.model_catalog_status<>'service_verified'
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
 RETURN airlinerra_game.acquire_offered_aircraft_v1(
  p_player_id,p_airline_id,p_offer_id,p_registration,p_request_id);
END;
$fn$;

-- Batch close by trusted Postgres cron only. Cash is already held from the
-- winning bid. Settlement DOES NOT debit a second time.
CREATE OR REPLACE FUNCTION airlinerra_game.settle_used_aircraft_auctions_v1(
 p_limit integer DEFAULT 30)
RETURNS integer LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $fn$
DECLARE lot record; bid record; company record;
 market_allowed boolean; completed integer:=0;
 fleet_id uuid; offer_id uuid;
 paid_upfront numeric(14,2);recurring numeric(14,2);
 now_utc timestamptz:=clock_timestamp();
BEGIN
 IF p_limit IS NULL OR p_limit<1 OR p_limit>100 THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_AUCTION_SETTLEMENT_BATCH';
 END IF;
 SELECT (market.release_state='live' AND world.state='active'
  AND world.opens_at IS NOT NULL AND world.opens_at<=clock_timestamp())
 INTO market_allowed
 FROM airlinerra_game.aircraft_market_control_v1 market
 JOIN public.airlinerra_game_worlds world ON world.id=market.world_id
 WHERE market.world_id=1;
 IF market_allowed IS DISTINCT FROM true THEN RETURN 0; END IF;
 FOR lot IN SELECT * FROM airlinerra_game.used_aircraft_auction_lots_v1
  WHERE world_id=1 AND status='bidding' AND close_after_utc<=now_utc
  ORDER BY close_after_utc,listing_id LIMIT p_limit FOR UPDATE SKIP LOCKED
 LOOP
  SELECT * INTO bid FROM airlinerra_game.used_aircraft_auction_bids_v1
  WHERE bid_id=lot.winning_bid_id AND listing_id=lot.listing_id
   AND hold_status='held' FOR UPDATE;
  IF NOT FOUND OR bid.airline_id IS DISTINCT FROM lot.highest_bid_airline_id
   OR bid.registration IS DISTINCT FROM lot.highest_registration THEN
   RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AUCTION_ESCROW_INCONSISTENT';
  END IF;
  SELECT id,home_airport_key,world_id INTO company
  FROM airlinerra_game.airlines WHERE id=bid.airline_id AND world_id=1
  FOR SHARE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='P0001',
   MESSAGE='AUCTION_WINNER_AIRLINE_NOT_AVAILABLE';END IF;
  IF EXISTS (SELECT 1 FROM airlinerra_game.airline_aircraft_inventory i
   WHERE upper(i.registration)=bid.registration) THEN
   RAISE EXCEPTION USING ERRCODE='P0001',
    MESSAGE='AIRCRAFT_REGISTRATION_ALREADY_TAKEN';END IF;
  paid_upfront:=bid.held_usd;
  recurring:=CASE WHEN lot.offering_type='lease' THEN bid.bid_usd ELSE 0 END;
  INSERT INTO airlinerra_game.aircraft_acquisition_offers_v1(
   world_id,configuration_id,transaction_type,upfront_price_usd,
   recurring_monthly_usd,contract_months,delivery_days,
   offer_status,pricing_basis)
  VALUES(1,lot.configuration_id,lot.offering_type,paid_upfront,recurring,
   CASE WHEN lot.offering_type='lease' THEN lot.lease_months ELSE NULL END,
   5,'retired','USED_AUCTION_SETTLED_GAME_PRICE_V1')
  RETURNING aircraft_acquisition_offers_v1.offer_id INTO offer_id;
  INSERT INTO airlinerra_game.airline_aircraft_inventory(
   airline_id,configuration_id,registration,ownership_type,fleet_status)
  VALUES(bid.airline_id,lot.configuration_id,bid.registration,
   CASE WHEN lot.offering_type='purchase' THEN 'owned' ELSE 'leased' END,'stored')
  RETURNING id INTO fleet_id;
  INSERT INTO airlinerra_game.aircraft_maintenance_state_v1(
   aircraft_inventory_id,airline_id,manufacture_year,
   manufacture_year_basis,condition_pct,condition_basis)
  VALUES(fleet_id,bid.airline_id,lot.manufacture_year,
   'game_generated_used_market_airframe',
   lot.condition_pct,'game_generated_used_market_airframe')
  ON CONFLICT(aircraft_inventory_id) DO NOTHING;
  INSERT INTO airlinerra_game.aircraft_acquisition_orders_v1(
   world_id,airline_id,player_id,request_id,offer_id,
   aircraft_inventory_id,registration,configuration_id,transaction_type,
   paid_upfront_usd,recurring_monthly_usd,contract_months,
   delivery_home_airport_key,delivery_due_at)
  VALUES(1,bid.airline_id,bid.player_id,bid.request_id,offer_id,
   fleet_id,bid.registration,lot.configuration_id,lot.offering_type,
   paid_upfront,recurring,
   CASE WHEN lot.offering_type='lease' THEN lot.lease_months ELSE NULL END,
   company.home_airport_key,clock_timestamp()+interval '5 days');
  UPDATE airlinerra_game.used_aircraft_auction_bids_v1
   SET hold_status='settled' WHERE bid_id=bid.bid_id AND hold_status='held';
  UPDATE airlinerra_game.used_aircraft_auction_lots_v1
   SET status='awarded',awarded_at_utc=clock_timestamp(),
    awarded_airline_id=bid.airline_id,awarded_inventory_id=fleet_id
   WHERE listing_id=lot.listing_id AND status='bidding';
  -- Permanent supply by aircraft model and purchase/lease form:
  -- replace a sold fictional stock with a DISTINCT fictional stock listing.
  INSERT INTO airlinerra_game.used_aircraft_auction_lots_v1(
   world_id,configuration_id,offering_type,manufacture_year,
   condition_pct,next_c_check_in_hours,provisional_new_value_usd,
   opening_bid_usd,min_bid_increment_usd,fixed_lease_deposit_usd,
   lease_months,price_basis,source_kind)
  VALUES(1,lot.configuration_id,lot.offering_type,lot.manufacture_year,
   greatest(35,least(98,lot.condition_pct+2)),
   greatest(100,least(5400,lot.next_c_check_in_hours+107)),
   lot.provisional_new_value_usd,lot.opening_bid_usd,
   lot.min_bid_increment_usd,lot.fixed_lease_deposit_usd,
   lot.lease_months,lot.price_basis,lot.source_kind);
  completed:=completed+1;
 END LOOP;
 RETURN completed;
END;
$fn$;

REVOKE EXECUTE ON FUNCTION
 airlinerra_game.place_used_aircraft_bid_v1(uuid,uuid,uuid,numeric,text,uuid),
 airlinerra_game.order_new_factory_aircraft_v2(uuid,uuid,uuid,text,uuid),
 airlinerra_game.settle_used_aircraft_auctions_v1(integer)
 FROM PUBLIC,anon,authenticated;

-- Checks every minute, but transaction gate DISABLED means the job cannot
-- award, charge or transfer assets before World 1's actual release.
SELECT cron.schedule('airlinerra-used-market-settle-v1','* * * * *',
 'SELECT airlinerra_game.settle_used_aircraft_auctions_v1(30);');

-- Factory offers remain DRAFT until the Edge entrypoint is updated to use
-- the new guarded order function. Publication is a separate deployment step.
