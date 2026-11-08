-- Airlinerra World 1 — launch-phase GAME BALANCE price cards.
-- These are explicitly game-design prices, not certified real aircraft valuations or
-- claims about any real individual used aircraft.
-- Purchase offers may publish; lease prices remain DRAFT until recurring
-- billing and the game clock are connected. Never seed player purchases.
BEGIN;

CREATE OR REPLACE FUNCTION airlinerra_game.aircraft_market_offer_release_guard_v1()
 RETURNS trigger LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'pg_catalog'
 AS $f$
DECLARE model record;
BEGIN
 IF NEW.offer_status='published' THEN
  SELECT c.model_catalog_status,c.civilian_service_status,c.configuration_review_status
    INTO model
  FROM airlinerra.aircraft_catalog_configuration_inventory c
  WHERE c.configuration_id=NEW.configuration_id;
  IF NOT FOUND OR model.model_catalog_status<>'service_verified'
   OR model.civilian_service_status<>'active'
   OR model.configuration_review_status<>'verified'
   OR EXISTS(SELECT 1 FROM airlinerra.aircraft_expansion_group3 g
     WHERE g.configuration_id=NEW.configuration_id)
  THEN RAISE EXCEPTION USING ERRCODE='P0001',
    MESSAGE='AIRCRAFT_NOT_APPROVED_FOR_GAME_MARKET'; END IF;

  -- Unbilled monthly leases cannot become live under this initial pricing release.
  IF NEW.transaction_type='lease' THEN RAISE EXCEPTION USING ERRCODE='P0001',
    MESSAGE='LEASE_BILLING_NOT_READY_FOR_PUBLISHED_OFFERS'; END IF;
  IF NEW.pricing_basis NOT LIKE 'AIRLINERRA_GAME_BALANCE_V1:%' THEN
   RAISE EXCEPTION USING ERRCODE='P0001',
    MESSAGE='AIRCRAFT_GAME_MARKET_PRICING_BASIS_REQUIRED'; END IF;
 END IF;
 RETURN NEW;
END
$f$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_market_offer_release_guard_v1()
 FROM PUBLIC,anon,authenticated;
DROP TRIGGER IF EXISTS aircraft_market_offer_release_guard_v1
 ON airlinerra_game.aircraft_acquisition_offers_v1;
CREATE TRIGGER aircraft_market_offer_release_guard_v1
 BEFORE INSERT OR UPDATE OF offer_status,configuration_id,transaction_type,pricing_basis
 ON airlinerra_game.aircraft_acquisition_offers_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.aircraft_market_offer_release_guard_v1();

WITH prices(configuration_id,purchase_upfront,lease_upfront,monthly_usd,days_to_deliver) AS (
 VALUES
 -- Small starter passenger and cargo aircraft; affordable within $5M cash.
 (93::bigint,2400000::numeric,160000::numeric,40000::numeric,3::smallint), -- Beech 1900D pax
 (123,2100000,150000,38000,3), -- Beech 1900C freighter
 (103,3800000,250000,58000,4), -- Fokker 50 pax
 (111,4500000,280000,70000,5), -- ATR 42-500 pax
 (90,4200000,260000,65000,5), -- Dash 8-300 freighter
 -- A larger airplane requires capital growth or leasing; no automatic loan.
 (78,7200000,450000,118000,6), -- ERJ 145 pax
 (80,7800000,475000,125000,6), -- ATR 72-500 pax
 (133,8500000,600000,140000,8), -- Cessna 408 SkyCourier pax
 (3,19000000,1100000,260000,10) -- A320-200 pax
), offers AS (
 SELECT p.configuration_id,'purchase'::text transaction_type,
 p.purchase_upfront amount,0::numeric monthly,NULL::smallint contract,
 p.days_to_deliver delivery,'published'::text status
 FROM prices p
 UNION ALL
 SELECT p.configuration_id,'lease'::text,
 p.lease_upfront,p.monthly_usd,12::smallint,p.days_to_deliver,'draft'::text
 FROM prices p
)
INSERT INTO airlinerra_game.aircraft_acquisition_offers_v1(
  world_id,configuration_id,transaction_type,upfront_price_usd,
  recurring_monthly_usd,contract_months,delivery_days,offer_status,pricing_basis)
SELECT 1,o.configuration_id,o.transaction_type,o.amount,o.monthly,
 o.contract,o.delivery,o.status,
 'AIRLINERRA_GAME_BALANCE_V1:reference_used_airframe_no_tail_claim'
FROM offers o
JOIN airlinerra.aircraft_catalog_configuration_inventory c
 ON c.configuration_id=o.configuration_id
WHERE c.model_catalog_status='service_verified'
 AND c.civilian_service_status='active'
 AND c.configuration_review_status='verified'
 AND NOT EXISTS(SELECT 1 FROM airlinerra.aircraft_expansion_group3 g
  WHERE g.configuration_id=o.configuration_id)
 AND NOT EXISTS(
  SELECT 1 FROM airlinerra_game.aircraft_acquisition_offers_v1 prior
  WHERE prior.world_id=1 AND prior.configuration_id=o.configuration_id
  AND prior.transaction_type=o.transaction_type
  AND prior.offer_status IN ('draft','published')
 )
ORDER BY o.configuration_id,o.transaction_type;
COMMIT;
