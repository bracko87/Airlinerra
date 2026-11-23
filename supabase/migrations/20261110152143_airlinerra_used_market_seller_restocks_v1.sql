-- Keep the fictional supplier stable for replenished lots.
-- PostgreSQL executes defaults before BEFORE INSERT triggers: remove default
-- so each new replacement lot is mapped by its configuration ID.
ALTER TABLE airlinerra_game.used_aircraft_auction_lots_v1
 ALTER COLUMN seller_id DROP DEFAULT;
