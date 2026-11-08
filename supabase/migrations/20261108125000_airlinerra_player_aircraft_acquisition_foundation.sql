-- Airlinerra World 1: real individual aircraft acquisition (purchase/lease order foundation).
-- Financial offers require an explicit approved game price. No prices, fleets or orders are seeded.
-- No aircraft is dispatched, delivered or set in_service by this migration.
BEGIN;

CREATE TABLE IF NOT EXISTS airlinerra_game.aircraft_acquisition_offers_v1(
 offer_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 configuration_id bigint NOT NULL REFERENCES airlinerra.aircraft_configurations(id),
 transaction_type text NOT NULL CHECK(transaction_type IN ('purchase','lease')),
 upfront_price_usd numeric(14,2) NOT NULL CHECK(upfront_price_usd>=100),
 recurring_monthly_usd numeric(14,2) NOT NULL DEFAULT 0 CHECK(recurring_monthly_usd>=0),
 contract_months smallint,
 delivery_days smallint NOT NULL DEFAULT 0 CHECK(delivery_days BETWEEN 0 AND 365),
 offer_status text NOT NULL DEFAULT 'draft' CHECK(offer_status IN ('draft','published','retired')),
 pricing_basis text NOT NULL DEFAULT 'GAME_ECONOMY_REVIEW_REQUIRED',
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT acquisition_lease_economics_check CHECK(
 (transaction_type='purchase' AND recurring_monthly_usd=0 AND contract_months IS NULL)
 OR (transaction_type='lease' AND recurring_monthly_usd>0 AND contract_months BETWEEN 1 AND 120))
);
CREATE UNIQUE INDEX IF NOT EXISTS aircraft_one_published_offer_per_type_v1
 ON airlinerra_game.aircraft_acquisition_offers_v1(world_id,configuration_id,transaction_type)
 WHERE offer_status='published';
ALTER TABLE airlinerra_game.aircraft_acquisition_offers_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_acquisition_offers_v1 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.aircraft_acquisition_offers_v1 IS
 'Game economy administrator-curated aircraft acquisition offers. No fabricated default prices or automatically published offers.';

CREATE TABLE IF NOT EXISTS airlinerra_game.aircraft_acquisition_orders_v1(
 order_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id) ON DELETE RESTRICT,
 player_id uuid NOT NULL,
 request_id uuid NOT NULL,
 offer_id uuid NOT NULL REFERENCES airlinerra_game.aircraft_acquisition_offers_v1(offer_id) ON DELETE RESTRICT,
 aircraft_inventory_id uuid NOT NULL UNIQUE
  REFERENCES airlinerra_game.airline_aircraft_inventory(id) ON DELETE RESTRICT,
 registration text NOT NULL,
 configuration_id bigint NOT NULL REFERENCES airlinerra.aircraft_configurations(id),
 transaction_type text NOT NULL CHECK(transaction_type IN ('purchase','lease')),
 paid_upfront_usd numeric(14,2) NOT NULL CHECK(paid_upfront_usd>=100),
 recurring_monthly_usd numeric(14,2) NOT NULL DEFAULT 0 CHECK(recurring_monthly_usd>=0),
 contract_months smallint,
 delivery_home_airport_key text NOT NULL,
 delivery_due_at timestamptz NOT NULL,
 order_status text NOT NULL DEFAULT 'awaiting_delivery' CHECK(order_status IN(
  'awaiting_delivery','delivered_pending_inspection','cancelled_with_refund')),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(airline_id,request_id),
 FOREIGN KEY(world_id,delivery_home_airport_key)
  REFERENCES airlinerra_game.approved_game_airports(world_id,airport_key)
);
CREATE INDEX IF NOT EXISTS aircraft_acquisition_orders_by_airline_v1
 ON airlinerra_game.aircraft_acquisition_orders_v1(airline_id,created_at DESC);
ALTER TABLE airlinerra_game.aircraft_acquisition_orders_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_acquisition_orders_v1 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.aircraft_acquisition_orders_v1 IS
 'Immutable player-initiated order receipts; stored individual fleet aircraft await verified delivery, inspection and operational positioning. No automatic live flight activation.';

CREATE UNIQUE INDEX IF NOT EXISTS airline_aircraft_registration_worldwide_casefold_v1
 ON airlinerra_game.airline_aircraft_inventory(upper(registration));

CREATE OR REPLACE FUNCTION airlinerra_game.acquire_offered_aircraft_v1(
 p_player_id uuid,p_airline_id uuid,p_offer_id uuid,p_registration text,p_request_id uuid
) RETURNS jsonb
LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $fn$
DECLARE
 company record; offer record; previous record; model record;
 fleet_id uuid; order_id uuid; balance numeric(14,2);
 normalized_registration text;
BEGIN
 IF p_player_id IS NULL OR p_airline_id IS NULL OR p_offer_id IS NULL
   OR p_request_id IS NULL OR p_registration IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_AIRCRAFT_ACQUISITION_INPUT';
 END IF;
 normalized_registration:=upper(btrim(p_registration));
 IF normalized_registration !~ '^[A-Z0-9][A-Z0-9-]{2,18}[A-Z0-9]$' THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_AIRCRAFT_REGISTRATION';
 END IF;
 -- Serialize the airline's funds, order idempotency and fleet creation.
 SELECT a.id,a.owner_player_id,a.world_id,a.home_airport_key,a.cash_usd,w.state
 INTO company FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships w
  ON w.world_id=a.world_id AND w.player_id=a.owner_player_id
 WHERE a.id=p_airline_id FOR UPDATE OF a;
 IF NOT FOUND OR company.owner_player_id IS DISTINCT FROM p_player_id THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='AIRLINE_NOT_OWNED_BY_VERIFIED_PLAYER';
 END IF;
 IF company.world_id<>1 OR company.state<>'active' THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AIRLINE_WORLD_NOT_ACTIVE_FOR_ACQUISITION';
 END IF;

 SELECT o.* INTO previous FROM airlinerra_game.aircraft_acquisition_orders_v1 o
 WHERE o.airline_id=p_airline_id AND o.request_id=p_request_id;
 IF FOUND THEN
  IF previous.offer_id<>p_offer_id OR previous.registration<>normalized_registration THEN
   RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='ACQUISITION_IDEMPOTENCY_KEY_REUSED';
  END IF;
  RETURN jsonb_build_object(
   'orderId',previous.order_id,'aircraftInventoryId',previous.aircraft_inventory_id,
   'registration',previous.registration,'transactionType',previous.transaction_type,
   'paidUpfrontUsd',previous.paid_upfront_usd::text,
   'recurringMonthlyUsd',previous.recurring_monthly_usd::text,
   'deliveryDueAt',previous.delivery_due_at,'deliveryStatus',previous.order_status,
   'fleetStatus','stored','replayed',true,'canScheduleFlight',false,
   'canActivateFlight',false);
 END IF;

 SELECT * INTO offer FROM airlinerra_game.aircraft_acquisition_offers_v1 o
 WHERE o.offer_id=p_offer_id AND o.world_id=company.world_id
 AND o.offer_status='published'
 FOR SHARE;
 IF NOT FOUND THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AIRCRAFT_OFFER_NOT_AVAILABLE';
 END IF;
 SELECT m.configuration_id,m.model_catalog_status,m.civilian_service_status
 INTO model FROM airlinerra.aircraft_catalog_configuration_inventory m
 WHERE m.configuration_id=offer.configuration_id;
 IF NOT FOUND OR model.model_catalog_status<>'service_verified'
  OR model.civilian_service_status<>'active' THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AIRCRAFT_CONFIGURATION_NOT_RELEASED_FOR_PLAYER_MARKET';
 END IF;
 -- Existing group 3 trigger independently rejects research-only models.
 IF EXISTS(SELECT 1 FROM airlinerra.aircraft_expansion_group3 g
  WHERE g.configuration_id=offer.configuration_id) THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='GROUP3_AIRCRAFT_NOT_RELEASED_FOR_FLEET';
 END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory i
   WHERE upper(i.registration)=normalized_registration) THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='AIRCRAFT_REGISTRATION_ALREADY_TAKEN';
 END IF;

 -- One debit and one ledger event, in the same transaction as the fleet order.
 UPDATE airlinerra_game.airlines a
 SET cash_usd=a.cash_usd-offer.upfront_price_usd
 WHERE a.id=p_airline_id AND a.cash_usd>=offer.upfront_price_usd
 RETURNING a.cash_usd INTO balance;
 IF balance IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='INSUFFICIENT_AIRLINE_CASH';
 END IF;
 INSERT INTO airlinerra_game.airline_aircraft_inventory(
  airline_id,configuration_id,registration,ownership_type,fleet_status)
 VALUES(p_airline_id,offer.configuration_id,normalized_registration,
  CASE WHEN offer.transaction_type='purchase' THEN 'owned' ELSE 'leased' END,
  'stored')
 RETURNING id INTO fleet_id;

 INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
 VALUES(p_airline_id,
  CASE WHEN offer.transaction_type='purchase' THEN 'AIRCRAFT_PURCHASE' ELSE 'AIRCRAFT_LEASE' END,
  -offer.upfront_price_usd);
 INSERT INTO airlinerra_game.aircraft_acquisition_orders_v1(
  world_id,airline_id,player_id,request_id,offer_id,
  aircraft_inventory_id,registration,configuration_id,transaction_type,
  paid_upfront_usd,recurring_monthly_usd,contract_months,
  delivery_home_airport_key,delivery_due_at)
 VALUES(company.world_id,p_airline_id,p_player_id,p_request_id,p_offer_id,
  fleet_id,normalized_registration,offer.configuration_id,offer.transaction_type,
  offer.upfront_price_usd,offer.recurring_monthly_usd,offer.contract_months,
  company.home_airport_key,now()+make_interval(days=>offer.delivery_days))
 RETURNING aircraft_acquisition_orders_v1.order_id INTO order_id;
 RETURN jsonb_build_object(
  'orderId',order_id,'aircraftInventoryId',fleet_id,
  'registration',normalized_registration,
  'transactionType',offer.transaction_type,
  'paidUpfrontUsd',offer.upfront_price_usd::text,
  'recurringMonthlyUsd',offer.recurring_monthly_usd::text,
  'remainingCashUsd',balance::text,
  'deliveryStatus','awaiting_delivery',
  'fleetStatus','stored','replayed',false,
  'canScheduleFlight',false,'canActivateFlight',false,
  'message','Aircraft acquired and paid for in game. Delivery, airworthiness and flight activation remain separate.');
END;
$fn$;

REVOKE ALL ON FUNCTION airlinerra_game.acquire_offered_aircraft_v1(
 uuid,uuid,uuid,text,uuid) FROM PUBLIC,anon,authenticated;
COMMIT;
