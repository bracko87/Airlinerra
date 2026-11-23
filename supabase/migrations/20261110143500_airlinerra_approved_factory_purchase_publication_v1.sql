-- Extend the existing market release guard for the NEW factory offer pricing
-- while preserving the research, Group-3 and unbilled-lease exclusions.
CREATE OR REPLACE FUNCTION airlinerra_game.aircraft_market_offer_release_guard_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'pg_catalog'
AS $fn$
DECLARE model record;
BEGIN
 IF NEW.offer_status='published' THEN
  SELECT c.model_catalog_status,c.civilian_service_status,
   c.configuration_review_status,c.production_status,
   c.production_start_year,c.production_end_year
  INTO model
  FROM airlinerra.aircraft_catalog_configuration_inventory c
  WHERE c.configuration_id=NEW.configuration_id;
  IF NOT FOUND OR model.model_catalog_status<>'service_verified'
   OR model.civilian_service_status<>'active'
   OR model.configuration_review_status<>'verified'
   OR EXISTS(
    SELECT 1 FROM airlinerra.aircraft_expansion_group3 g
     WHERE g.configuration_id=NEW.configuration_id) THEN
   RAISE EXCEPTION USING ERRCODE='P0001',
    MESSAGE='AIRCRAFT_NOT_APPROVED_FOR_GAME_MARKET';
  END IF;
  -- No lease payments without a proven recurring-finance engine.
  IF NEW.transaction_type='lease' THEN
   RAISE EXCEPTION USING ERRCODE='P0001',
    MESSAGE='LEASE_BILLING_NOT_READY_FOR_PUBLISHED_OFFERS';
  END IF;
  -- New factory pricing is explicitly estimated and only in-production.
  IF NEW.pricing_basis='AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2' THEN
   IF model.production_status<>'in_production'
    OR model.production_start_year>extract(year from now())::integer
    OR (model.production_end_year IS NOT NULL AND
     model.production_end_year<extract(year from now())::integer) THEN
    RAISE EXCEPTION USING ERRCODE='P0001',
      MESSAGE='NEW_AIRCRAFT_MODEL_NOT_ELIGIBLE';
   END IF;
  ELSIF NEW.pricing_basis NOT LIKE 'AIRLINERRA_GAME_BALANCE_V1:%' THEN
   RAISE EXCEPTION USING ERRCODE='P0001',
    MESSAGE='AIRCRAFT_GAME_MARKET_PRICING_BASIS_REQUIRED';
  END IF;
 END IF;
 RETURN NEW;
END;
$fn$;

-- Publish ONLY currently verified production aircraft purchase offers.
-- Draft research configurations and ALL lease offers remain visible
-- through the *read-only* factory catalog and cannot be ordered.
UPDATE airlinerra_game.aircraft_acquisition_offers_v1 o
SET offer_status='published',updated_at=now()
FROM airlinerra.aircraft_catalog_configuration_inventory c
WHERE c.configuration_id=o.configuration_id
 AND o.pricing_basis='AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2'
 AND o.offer_status='draft' AND o.transaction_type='purchase'
 AND c.configuration_review_status='verified'
 AND c.production_status='in_production'
 AND c.model_catalog_status='service_verified'
 AND c.civilian_service_status='active'
 AND c.production_start_year<=extract(year from now())
 AND (c.production_end_year IS NULL OR c.production_end_year>=extract(year from now()))
 AND NOT EXISTS(SELECT 1 FROM airlinerra.aircraft_expansion_group3 g
  WHERE g.configuration_id=c.configuration_id);
REVOKE EXECUTE ON FUNCTION airlinerra_game.aircraft_market_offer_release_guard_v1()
 FROM PUBLIC,anon,authenticated;
