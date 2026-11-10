-- Publish pre-approved factory catalog for authenticated *read* and future
-- owner-verified orders. World 1 is planned; money gate remains disabled.
-- The deployed Fleet Edge service must call order_new_factory_aircraft_v2.
UPDATE airlinerra_game.aircraft_acquisition_offers_v1 o
SET offer_status='published',updated_at=now()
WHERE o.pricing_basis='AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2'
 AND o.offer_status='draft'
 AND EXISTS(
  SELECT 1 FROM airlinerra.aircraft_catalog_configuration_inventory c
  WHERE c.configuration_id=o.configuration_id
   AND c.production_status='in_production'
   AND c.model_catalog_status='service_verified'
   AND c.civilian_service_status='active'
   AND c.production_start_year<=extract(year from now())
   AND (c.production_end_year IS NULL OR c.production_end_year>=extract(year from now()))
   AND NOT EXISTS(
     SELECT 1 FROM airlinerra.aircraft_expansion_group3 g
     WHERE g.configuration_id=c.configuration_id)
 );
