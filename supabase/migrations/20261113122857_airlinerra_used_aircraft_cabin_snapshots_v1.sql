-- Airlinerra: keep each used airframe's installed cabin through auction transfer.
-- Adds private snapshot metadata only. Does not enable resale, bidding or markets.
ALTER TABLE airlinerra_game.used_aircraft_auction_lots_v1
  ADD COLUMN IF NOT EXISTS source_inventory_id uuid,
  ADD COLUMN IF NOT EXISTS cabin_snapshot jsonb,
  ADD COLUMN IF NOT EXISTS cabin_origin text;

ALTER TABLE airlinerra_game.used_aircraft_auction_lots_v1
  ADD CONSTRAINT used_lot_cabin_origin_v1_check
  CHECK (cabin_origin IS NULL OR cabin_origin IN ('model_default','previous_owner'));

CREATE OR REPLACE FUNCTION airlinerra_game.capture_used_lot_cabin_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'pg_catalog'
AS $fn$
DECLARE installed record; standard record; aircraft record;
BEGIN
  IF NEW.source_inventory_id IS NOT NULL THEN
    SELECT i.configuration_id,i.airline_id INTO aircraft
    FROM airlinerra_game.airline_aircraft_inventory i WHERE i.id=NEW.source_inventory_id;
    IF NOT FOUND OR aircraft.configuration_id<>NEW.configuration_id THEN
      RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='USED_CABIN_SOURCE_AIRCRAFT_MISMATCH';
    END IF;
    SELECT * INTO installed FROM airlinerra_game.aircraft_installed_cabins_v1
    WHERE aircraft_inventory_id=NEW.source_inventory_id
      AND configuration_id=NEW.configuration_id AND airline_id=aircraft.airline_id;
    IF NOT FOUND THEN
      RAISE EXCEPTION USING ERRCODE='23514', MESSAGE='USED_CABIN_SOURCE_NOT_INSTALLED';
    END IF;
    NEW.cabin_snapshot=jsonb_build_object(
      'economy',installed.installed_economy,'premium',installed.installed_premium,
      'business',installed.installed_business,'first',installed.installed_first,
      'economyType',installed.installed_economy_type,
      'premiumType',installed.installed_premium_type,
      'businessType',installed.installed_business_type,
      'firstType',installed.installed_first_type,
      'extraLegroomCm',installed.installed_extra_legroom_cm);
    NEW.cabin_origin=CASE WHEN installed.installed_source='catalog_standard_game_layout'
      THEN 'model_default' ELSE 'previous_owner' END;
  ELSIF NEW.cabin_snapshot IS NULL THEN
    SELECT * INTO standard FROM airlinerra_game.cabin_model_standard_v1
    WHERE configuration_id=NEW.configuration_id;
    IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='23514',
      MESSAGE='USED_CABIN_MODEL_STANDARD_MISSING'; END IF;
    IF standard.use_type<>'cargo' THEN
      NEW.cabin_snapshot=jsonb_build_object('economy',standard.standard_economy_seats,
        'premium',0,'business',0,'first',0,'economyType','eco_standard',
        'premiumType','premium_standard','businessType','business_standard',
        'firstType','first_standard','extraLegroomCm',0);
    END IF;
    NEW.cabin_origin='model_default';
  END IF;
  RETURN NEW;
END
$fn$;

DROP TRIGGER IF EXISTS used_lot_cabin_capture_v1 ON airlinerra_game.used_aircraft_auction_lots_v1;
CREATE TRIGGER used_lot_cabin_capture_v1
BEFORE INSERT ON airlinerra_game.used_aircraft_auction_lots_v1
FOR EACH ROW EXECUTE FUNCTION airlinerra_game.capture_used_lot_cabin_v1();

-- Only final, server-authorized auction awards can install the stored snapshot.
-- The existing inventory INSERT trigger creates its default row first.
CREATE OR REPLACE FUNCTION airlinerra_game.apply_awarded_used_cabin_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'pg_catalog'
AS $fn$
DECLARE plan jsonb;
BEGIN
  IF NEW.awarded_inventory_id IS NULL OR NEW.status<>'awarded'
    OR NEW.awarded_inventory_id IS NOT DISTINCT FROM OLD.awarded_inventory_id
    OR NEW.cabin_snapshot IS NULL THEN RETURN NEW; END IF;
  plan:=NEW.cabin_snapshot;
  UPDATE airlinerra_game.aircraft_installed_cabins_v1 installed
  SET installed_economy=(plan->>'economy')::integer,
      installed_premium=(plan->>'premium')::integer,
      installed_business=(plan->>'business')::integer,
      installed_first=(plan->>'first')::integer,
      installed_economy_type=coalesce(plan->>'economyType','eco_standard'),
      installed_premium_type=coalesce(plan->>'premiumType','premium_standard'),
      installed_business_type=coalesce(plan->>'businessType','business_standard'),
      installed_first_type=coalesce(plan->>'firstType','first_standard'),
      installed_extra_legroom_cm=coalesce((plan->>'extraLegroomCm')::numeric,0),
      installed_source=CASE WHEN NEW.cabin_origin='previous_owner'
        THEN 'used_aircraft_previous_owner_layout' ELSE 'catalog_standard_game_layout' END,
      updated_at=clock_timestamp()
  WHERE installed.aircraft_inventory_id=NEW.awarded_inventory_id
    AND installed.airline_id=NEW.awarded_airline_id
    AND installed.configuration_id=NEW.configuration_id;
  IF NOT FOUND THEN
    RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='AWARDED_USED_CABIN_DESTINATION_NOT_FOUND';
  END IF;
  RETURN NEW;
END
$fn$;
DROP TRIGGER IF EXISTS used_lot_cabin_award_v1 ON airlinerra_game.used_aircraft_auction_lots_v1;
CREATE TRIGGER used_lot_cabin_award_v1
AFTER UPDATE OF awarded_inventory_id ON airlinerra_game.used_aircraft_auction_lots_v1
FOR EACH ROW EXECUTE FUNCTION airlinerra_game.apply_awarded_used_cabin_v1();

-- Existing fictional dealer stock gets a genuine model-standard game layout,
-- not a fabricated previous owner.
UPDATE airlinerra_game.used_aircraft_auction_lots_v1 lot
SET cabin_origin='model_default',
    cabin_snapshot=CASE WHEN s.use_type='cargo' THEN NULL ELSE
      jsonb_build_object('economy',s.standard_economy_seats,'premium',0,
        'business',0,'first',0,'economyType','eco_standard',
        'premiumType','premium_standard','businessType','business_standard',
        'firstType','first_standard','extraLegroomCm',0) END
FROM airlinerra_game.cabin_model_standard_v1 s
WHERE s.configuration_id=lot.configuration_id AND lot.cabin_origin IS NULL;

COMMENT ON COLUMN airlinerra_game.used_aircraft_auction_lots_v1.cabin_snapshot IS
 'Private last-installed seat plan. Copied from source inventory before future resale/decommissioning; transferred to winner on award. Fictional dealer lots use model default.';
COMMENT ON COLUMN airlinerra_game.used_aircraft_auction_lots_v1.source_inventory_id IS
 'Optional previous registered aircraft. Capture its cabin BEFORE removing prior owner inventory; future resale workflow must pass this field.';
