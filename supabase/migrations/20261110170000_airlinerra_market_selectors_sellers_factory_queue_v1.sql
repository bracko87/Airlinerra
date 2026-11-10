-- AIRLINERRA aircraft markets: manufacturer/model selectors, fictional
-- companies, indicative original model values and factory capacity foundation.
-- No live order, bid, credit or lease activation. World 1 remains closed.
CREATE TABLE airlinerra_game.aircraft_market_sellers_v1 (
 seller_id smallint PRIMARY KEY CHECK(seller_id BETWEEN 1 AND 20),
 display_name text NOT NULL UNIQUE,
 is_fictional boolean NOT NULL DEFAULT true CHECK(is_fictional),
 seller_kind text NOT NULL DEFAULT 'system_dealer' CHECK(seller_kind='system_dealer'),
 supported_offers text NOT NULL DEFAULT 'purchase_and_lease',
 provenance_note text NOT NULL DEFAULT 'Fictional Airlinerra marketplace counterparty, not a real business'
);
INSERT INTO airlinerra_game.aircraft_market_sellers_v1(seller_id,display_name)
VALUES (1,'Northstar Airframe Exchange'),
 (2,'Meridian Fleet Trading'),
 (3,'Horizon Aviation Assets'),
 (4,'Pacific Aircraft Brokerage'),
 (5,'Continental Fleet Partners'),
 (6,'Skybridge Aviation Leasing');

ALTER TABLE airlinerra_game.used_aircraft_auction_lots_v1
 ADD COLUMN seller_id smallint
 REFERENCES airlinerra_game.aircraft_market_sellers_v1(seller_id);
UPDATE airlinerra_game.used_aircraft_auction_lots_v1 l
SET seller_id=(1+mod(l.configuration_id::int,6))::smallint
WHERE seller_id IS NULL;
ALTER TABLE airlinerra_game.used_aircraft_auction_lots_v1
 ALTER COLUMN seller_id SET NOT NULL,
 ALTER COLUMN seller_id SET DEFAULT 1;

-- Replacement stock created by cron after an award keeps the same fictional
-- seller as the original lot. The existing settled lot keeps its seller.
CREATE OR REPLACE FUNCTION airlinerra_game.market_used_lot_default_seller_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'pg_catalog'
AS $f$
BEGIN
 IF NEW.seller_id IS NULL THEN
  NEW.seller_id:=(1+mod(NEW.configuration_id::int,6))::smallint;
 END IF;
 RETURN NEW;
END;$f$;
DROP TRIGGER IF EXISTS market_used_lot_seller_default_v1
 ON airlinerra_game.used_aircraft_auction_lots_v1;
CREATE TRIGGER market_used_lot_seller_default_v1
 BEFORE INSERT ON airlinerra_game.used_aircraft_auction_lots_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.market_used_lot_default_seller_v1();

CREATE TABLE airlinerra_game.factory_manufacturer_capacity_v1 (
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 manufacturer_name text NOT NULL,
 aircraft_per_day smallint NOT NULL CHECK(aircraft_per_day BETWEEN 1 AND 10),
 next_factory_day date,
 scheduled_on_next_day smallint NOT NULL DEFAULT 0 CHECK(scheduled_on_next_day BETWEEN 0 AND 10),
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(world_id,manufacturer_name)
);
INSERT INTO airlinerra_game.factory_manufacturer_capacity_v1
 (world_id,manufacturer_name,aircraft_per_day)
SELECT 1,manufacturer_name,
 CASE WHEN mod(length(manufacturer_name),2)=0 THEN 2 ELSE 3 END
FROM airlinerra.aircraft_catalog_configuration_inventory c
WHERE c.production_status='in_production'
 AND c.model_catalog_status='service_verified'
 AND c.civilian_service_status='active'
 AND c.production_start_year<=extract(year from now())
 AND (c.production_end_year IS NULL OR c.production_end_year>=extract(year from now()))
GROUP BY manufacturer_name
ON CONFLICT DO NOTHING;

CREATE TABLE airlinerra_game.factory_model_stock_v1 (
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 configuration_id bigint NOT NULL REFERENCES airlinerra.aircraft_configurations(id),
 stocked_units smallint NOT NULL DEFAULT 0 CHECK(stocked_units BETWEEN 0 AND 20),
 stock_delivery_days smallint NOT NULL DEFAULT 7 CHECK(stock_delivery_days BETWEEN 7 AND 14),
 updated_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(world_id,configuration_id)
);
-- Initial fictional stock: some variants immediately in stock and others
-- factory-order only. Future replenishment must come from server-owned supply.
INSERT INTO airlinerra_game.factory_model_stock_v1
 (world_id,configuration_id,stocked_units,stock_delivery_days)
SELECT 1,c.configuration_id,
 CASE WHEN mod(c.configuration_id,4)=0 THEN 0
      WHEN mod(c.configuration_id,4)=1 THEN 1 ELSE 2 END,
 CASE WHEN mod(c.configuration_id,2)=0 THEN 7 ELSE 14 END
FROM airlinerra.aircraft_catalog_configuration_inventory c
WHERE c.production_status='in_production'
 AND c.model_catalog_status='service_verified'
 AND c.civilian_service_status='active'
 AND c.production_start_year<=extract(year from now())
 AND (c.production_end_year IS NULL OR c.production_end_year>=extract(year from now()))
ON CONFLICT DO NOTHING;

CREATE TABLE airlinerra_game.factory_delivery_reservations_v1 (
 order_id uuid PRIMARY KEY
  REFERENCES airlinerra_game.aircraft_acquisition_orders_v1(order_id),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 configuration_id bigint NOT NULL REFERENCES airlinerra.aircraft_configurations(id),
 manufacturer_name text NOT NULL,
 source_kind text NOT NULL CHECK(source_kind IN ('stock','factory_queue')),
 booked_factory_day date,
 delivery_due_at timestamptz NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now(),
 FOREIGN KEY(world_id,manufacturer_name)
  REFERENCES airlinerra_game.factory_manufacturer_capacity_v1(world_id,manufacturer_name),
 CHECK ((source_kind='stock' AND booked_factory_day IS NULL)
    OR (source_kind='factory_queue' AND booked_factory_day IS NOT NULL))
);
CREATE INDEX factory_delivery_reservations_maker_day_v1
 ON airlinerra_game.factory_delivery_reservations_v1(manufacturer_name,booked_factory_day);

-- Reference pricing: where an official historical price exists, keep its
-- historical year and publication. Other original values remain explicitly
-- marked as game estimates; NOT verified historical sale prices.
CREATE TABLE airlinerra_game.aircraft_model_reference_prices_v1 (
 configuration_id bigint PRIMARY KEY REFERENCES airlinerra.aircraft_configurations(id),
 reference_price_usd numeric(14,2) NOT NULL CHECK(reference_price_usd>=100000),
 reference_year integer NOT NULL CHECK(reference_year BETWEEN 1930 AND 2100),
 evidence_kind text NOT NULL CHECK(evidence_kind IN
  ('manufacturer_list_2018','game_estimate_mtow_2026')),
 source_url text,
 source_notes text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO airlinerra_game.aircraft_model_reference_prices_v1
 (configuration_id,reference_price_usd,reference_year,evidence_kind,source_url,source_notes)
SELECT c.configuration_id,
 CASE
  WHEN c.manufacturer_name='Airbus' AND c.model_name='A319neo' THEN 101500000
  WHEN c.manufacturer_name='Airbus' AND c.model_name='A320neo' THEN 110600000
  WHEN c.manufacturer_name='Airbus' AND c.model_name='A321neo' THEN 129500000
  WHEN c.manufacturer_name='Airbus' AND c.model_name='A330-900neo' THEN 296400000
  WHEN c.manufacturer_name='Airbus' AND c.model_name='A350-900' THEN 317400000
  WHEN c.manufacturer_name='Airbus' AND c.model_name='A350-1000' THEN 366500000
  WHEN c.manufacturer_name='Boeing' AND c.model_name='737 MAX 8' THEN 117100000
  WHEN c.manufacturer_name='Boeing' AND c.model_name='737 MAX 9' THEN 124100000
  WHEN c.manufacturer_name='Boeing' AND c.model_name='737 MAX 10' THEN 129900000
  WHEN c.manufacturer_name='Boeing' AND c.model_name='787-8' THEN 239000000
  WHEN c.manufacturer_name='Boeing' AND c.model_name='787-9' THEN 281600000
  WHEN c.manufacturer_name='Boeing' AND c.model_name='787-10' THEN 325800000
  ELSE greatest(100000::numeric,
   round((4200000+55000000*power(c.mtow_kg::numeric/78000,.85))/10000)*10000)
 END,
 CASE WHEN (c.manufacturer_name='Airbus' AND c.model_name IN
     ('A319neo','A320neo','A321neo','A330-900neo','A350-900','A350-1000'))
    OR (c.manufacturer_name='Boeing' AND c.model_name IN
     ('737 MAX 8','737 MAX 9','737 MAX 10','787-8','787-9','787-10'))
   THEN 2018 ELSE 2026 END,
 CASE WHEN (c.manufacturer_name='Airbus' AND c.model_name IN
     ('A319neo','A320neo','A321neo','A330-900neo','A350-900','A350-1000'))
    OR (c.manufacturer_name='Boeing' AND c.model_name IN
     ('737 MAX 8','737 MAX 9','737 MAX 10','787-8','787-9','787-10'))
   THEN 'manufacturer_list_2018' ELSE 'game_estimate_mtow_2026' END,
 CASE WHEN c.manufacturer_name='Airbus' AND c.model_name IN
     ('A319neo','A320neo','A321neo','A330-900neo','A350-900','A350-1000')
   THEN 'https://www.marketscreener.com/quote/stock/AIRBUS-SE-4637/news/Airbus-2018-Price-List-Press--25807080/'
  WHEN c.manufacturer_name='Boeing' AND c.model_name IN
   ('737 MAX 8','737 MAX 9','737 MAX 10','787-8','787-9','787-10')
   THEN 'https://finance.yahoo.com/news/boeing-raises-2018-commercial-jet-132016203.html'
  ELSE NULL END,
 CASE WHEN (c.manufacturer_name='Airbus' AND c.model_name IN
     ('A319neo','A320neo','A321neo','A330-900neo','A350-900','A350-1000'))
    OR (c.manufacturer_name='Boeing' AND c.model_name IN
     ('737 MAX 8','737 MAX 9','737 MAX 10','787-8','787-9','787-10'))
  THEN '2018 manufacturer historical public list-price reference; not actual sale price'
  ELSE '2026 game value estimated from reference max takeoff mass; not original historic factory price'
 END
FROM airlinerra.aircraft_catalog_configuration_inventory c
WHERE c.mtow_kg>0
ON CONFLICT(configuration_id) DO NOTHING;

ALTER TABLE airlinerra_game.aircraft_market_sellers_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.factory_manufacturer_capacity_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.factory_model_stock_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.factory_delivery_reservations_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.aircraft_model_reference_prices_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_market_sellers_v1,
 airlinerra_game.factory_manufacturer_capacity_v1,
 airlinerra_game.factory_model_stock_v1,
 airlinerra_game.factory_delivery_reservations_v1,
 airlinerra_game.aircraft_model_reference_prices_v1
 FROM PUBLIC,anon,authenticated;
REVOKE EXECUTE ON FUNCTION airlinerra_game.market_used_lot_default_seller_v1()
 FROM PUBLIC,anon,authenticated;
