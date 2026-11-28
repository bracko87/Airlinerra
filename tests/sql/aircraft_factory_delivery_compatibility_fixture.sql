-- Synthetic predicate fixture; not a substitute for full delivery integration.
DO $$ BEGIN IF current_database()<>'airlinerra_disposable' THEN RAISE EXCEPTION 'DISPOSABLE_DATABASE_REQUIRED'; END IF; END $$;
CREATE TABLE airlinerra_game.factory_delivery_review_fixture(id integer PRIMARY KEY, pricing_basis text, offer_status text, approved boolean);
INSERT INTO airlinerra_game.factory_delivery_review_fixture VALUES
(1,'AIRLINERRA_GAME_BALANCE_V1:test','published',true),
(2,'AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2','published',true),
(3,'AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2','draft',true),
(4,'AIRLINERRA_UNKNOWN','published',true),
(5,'AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2','published',false),
(6,'AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2','retired',true);
CREATE FUNCTION airlinerra_game.section9_capture_approved_delivery_position_v1(uuid,uuid) RETURNS integer[] LANGUAGE plpgsql AS $f$
BEGIN RETURN ARRAY(SELECT id FROM airlinerra_game.factory_delivery_review_fixture approved_offer WHERE approved_offer.pricing_basis LIKE 'AIRLINERRA_GAME_BALANCE_V1:%' AND offer_status IN ('published','retired') AND approved ORDER BY id); END $f$;
CREATE FUNCTION airlinerra_game.section9_sync_approved_delivery_positions_v1(integer) RETURNS integer[] LANGUAGE plpgsql AS $f$
BEGIN RETURN ARRAY(SELECT id FROM airlinerra_game.factory_delivery_review_fixture approved_offer WHERE approved_offer.pricing_basis LIKE 'AIRLINERRA_GAME_BALANCE_V1:%' AND offer_status IN ('published','retired') AND approved ORDER BY id); END $f$;
CREATE FUNCTION airlinerra_game.section9_owned_aircraft_delivery_position_preview_v1(uuid,uuid) RETURNS integer[] LANGUAGE plpgsql AS $f$
BEGIN RETURN ARRAY(SELECT id FROM airlinerra_game.factory_delivery_review_fixture approved_offer WHERE approved_offer.pricing_basis LIKE 'AIRLINERRA_GAME_BALANCE_V1:%' AND offer_status IN ('published','retired') AND approved ORDER BY id); END $f$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_capture_approved_delivery_position_v1(uuid,uuid),airlinerra_game.section9_sync_approved_delivery_positions_v1(integer),airlinerra_game.section9_owned_aircraft_delivery_position_preview_v1(uuid,uuid) FROM PUBLIC,anon,authenticated;
