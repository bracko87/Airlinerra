-- Retire misleading 120–300 day static delivery values on the new-factory
-- offers. The protected order procedure owns the actual queue reservation.
-- This is an indicative fallback only, not an allocated slot.
UPDATE airlinerra_game.aircraft_acquisition_offers_v1 o
 SET delivery_days=CASE WHEN stock.stocked_units>0
  THEN stock.stock_delivery_days ELSE 14 END,
 updated_at=now()
 FROM airlinerra_game.factory_model_stock_v1 stock
 WHERE o.configuration_id=stock.configuration_id
 AND o.world_id=stock.world_id
 AND o.pricing_basis='AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2'
 AND o.offer_status IN ('draft','published')
 AND o.delivery_days IS DISTINCT FROM CASE WHEN stock.stocked_units>0
  THEN stock.stock_delivery_days ELSE 14 END;
