
-- Airlinerra factory cabins v2. All 181 passenger/combi catalog configurations.
-- Model role/capacity and model-specific 1-2-1 etc row geometry drive the
-- generated GAME defaults, not unverified manufacturer seat maps.
CREATE TABLE IF NOT EXISTS airlinerra_game.cabin_model_factory_layout_v2 (
 configuration_id bigint PRIMARY KEY REFERENCES airlinerra.aircraft_configurations(id),
 use_type text NOT NULL CHECK(use_type IN ('passenger','combi')),
 economy integer NOT NULL CHECK(economy>=0),
 premium integer NOT NULL CHECK(premium>=0),
 business integer NOT NULL CHECK(business>=0),
 first integer NOT NULL CHECK(first>=0),
 economy_type text NOT NULL DEFAULT 'eco_standard' REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 premium_type text NOT NULL DEFAULT 'premium_standard' REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 business_type text NOT NULL DEFAULT 'business_standard' REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 first_type text NOT NULL DEFAULT 'first_standard' REFERENCES airlinerra_game.cabin_seat_types_v1(seat_code),
 extra_legroom_cm numeric(4,1) NOT NULL DEFAULT 0 CHECK(extra_legroom_cm BETWEEN 0 AND 20),
 space_used_pct numeric(7,3) NOT NULL CHECK(space_used_pct BETWEEN 0 AND 100),
 profile_tier text NOT NULL CHECK(profile_tier IN ('economy','eco_premium','eco_business','three_class','four_class')),
 basis text NOT NULL DEFAULT 'AIRLINERRA_FACTORY_GAME_LAYOUT_V2',
 created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE airlinerra_game.cabin_model_factory_layout_v2 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.cabin_model_factory_layout_v2 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.cabin_model_factory_layout_v2 IS
 'Generated model-level Airlinerra factory game defaults; complete seat rows and near-full fictional space units, not aircraft-certified cabin data. Only protected backend reads these.';

WITH model AS (
 SELECT s.configuration_id,s.use_type,s.reference_seat_units::numeric AS capacity,c.model_name,
  (SELECT COALESCE(sum(x),0)::int FROM unnest(g.economy_columns) x) AS ew,
  (SELECT COALESCE(sum(x),0)::int FROM unnest(g.premium_columns) x) AS pw,
  (SELECT COALESCE(sum(x),0)::int FROM unnest(g.business_columns) x) AS bw,
  (SELECT COALESCE(sum(x),0)::int FROM unnest(g.first_columns) x) AS fw
 FROM airlinerra_game.cabin_model_standard_v1 s
 JOIN airlinerra.aircraft_catalog_configuration_inventory c USING(configuration_id)
 JOIN airlinerra_game.cabin_model_row_geometry_v1 g USING(configuration_id)
 WHERE s.use_type IN('passenger','combi')
), p AS (
 SELECT *, CASE
  WHEN capacity>=100 AND capacity<280 AND model_name ~* '(A321|737-|737 |737[ -]|E195)' THEN 'eco_business'
  WHEN capacity<100 THEN 'economy'
  WHEN capacity<170 THEN 'eco_premium'
  WHEN capacity<350 THEN 'three_class'
  ELSE 'four_class' END tier
 FROM model
), counts AS (
 SELECT *,
  CASE WHEN tier IN('eco_premium','three_class','four_class')
   THEN pw*(CASE WHEN capacity>=260 THEN 3 ELSE 2 END) ELSE 0 END prem,
  CASE WHEN tier IN('eco_business','three_class','four_class')
   THEN bw*(CASE WHEN capacity>=350 THEN 3 ELSE 2 END) ELSE 0 END biz,
  CASE WHEN tier='four_class' THEN fw*2 ELSE 0 END fst
 FROM p
), base AS (
 SELECT *, floor((capacity-prem*1.4-biz*1.9-fst*3.0)/ew)::int*ew eco
 FROM counts WHERE ew>0 AND pw>0 AND bw>0 AND fw>0
), used AS (
 SELECT *,eco*1.0+prem*1.4+biz*1.9+fst*3.0 AS base_units,
  (eco/(30.0*2.54)+prem*1.4/(38.0*2.54)+
   biz*1.9/(44.0*2.54)+fst*3.0/(60.0*2.54)) AS per_cm
 FROM base
), final AS (
 SELECT *, least(20,greatest(0,
  floor((capacity-base_units)/nullif(per_cm,0)*10)/10)) AS legroom_cm
 FROM used
)
INSERT INTO airlinerra_game.cabin_model_factory_layout_v2
 (configuration_id,use_type,economy,premium,business,first,
  extra_legroom_cm,space_used_pct,profile_tier)
SELECT configuration_id,use_type,eco,prem,biz,fst,
 legroom_cm,round((base_units+per_cm*legroom_cm)/capacity*100,3),tier
FROM final
WHERE eco>0
  AND eco%ew=0 AND prem%pw=0 AND biz%bw=0 AND fst%fw=0
  AND base_units+per_cm*legroom_cm<=capacity+0.000001
ON CONFLICT(configuration_id) DO NOTHING;

DO $verify$
DECLARE total integer; expected integer;
BEGIN
 SELECT count(*) INTO total FROM airlinerra_game.cabin_model_factory_layout_v2;
 SELECT count(*) INTO expected FROM airlinerra_game.cabin_model_standard_v1
 WHERE use_type IN('passenger','combi');
 IF total<>expected THEN
  RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='FACTORY_CABIN_CATALOG_COVERAGE_INCOMPLETE';
 END IF;
 IF EXISTS(
  SELECT 1 FROM airlinerra_game.cabin_model_factory_layout_v2 f
  JOIN airlinerra_game.cabin_model_row_geometry_v1 g USING(configuration_id)
  WHERE f.economy % (SELECT sum(x) FROM unnest(g.economy_columns) x)<>0
     OR f.premium % (SELECT sum(x) FROM unnest(g.premium_columns) x)<>0
     OR f.business % (SELECT sum(x) FROM unnest(g.business_columns) x)<>0
     OR f.first % (SELECT sum(x) FROM unnest(g.first_columns) x)<>0
     OR f.space_used_pct < 99.0 OR f.space_used_pct>100
 ) THEN
  RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='FACTORY_CABIN_ROW_OR_SPACE_INVALID';
 END IF;
END $verify$;

-- Every newly acquired factory aircraft starts with the new model's COMPLETE
-- factory cabin. Do not mutate existing individual airframes or existing refits.
CREATE OR REPLACE FUNCTION airlinerra_game.initial_installed_cabin_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'pg_catalog'
AS $function$
DECLARE standard record; factory record;
BEGIN
 SELECT * INTO standard FROM airlinerra_game.cabin_model_standard_v1
 WHERE configuration_id=NEW.configuration_id;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='23514',
  MESSAGE='CABIN_STANDARD_CONFIGURATION_MISSING'; END IF;
 SELECT * INTO factory FROM airlinerra_game.cabin_model_factory_layout_v2
 WHERE configuration_id=NEW.configuration_id;
 IF standard.use_type<>'cargo' AND factory.configuration_id IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='FACTORY_CABIN_NOT_PREPARED';
 END IF;
 INSERT INTO airlinerra_game.aircraft_installed_cabins_v1
 (aircraft_inventory_id,airline_id,configuration_id,
  installed_economy,installed_premium,installed_business,installed_first,
  installed_economy_type,installed_premium_type,installed_business_type,installed_first_type,
  installed_extra_legroom_cm,installed_source)
 VALUES(NEW.id,NEW.airline_id,NEW.configuration_id,
  COALESCE(factory.economy,standard.standard_economy_seats),
  COALESCE(factory.premium,0),COALESCE(factory.business,0),COALESCE(factory.first,0),
  COALESCE(factory.economy_type,'eco_standard'),COALESCE(factory.premium_type,'premium_standard'),
  COALESCE(factory.business_type,'business_standard'),COALESCE(factory.first_type,'first_standard'),
  COALESCE(factory.extra_legroom_cm,0),'catalog_standard_game_layout');
 RETURN NEW;
END
$function$;

-- New GAME-generated dealer lots inherit a new factory snapshot. Only a
-- previous-owner listing takes the actual last-installed seat plan.
CREATE OR REPLACE FUNCTION airlinerra_game.capture_used_lot_cabin_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'pg_catalog'
AS $function$
DECLARE installed record; factory record; aircraft record; standard record;
BEGIN
 IF NEW.source_inventory_id IS NOT NULL THEN
  SELECT i.configuration_id,i.airline_id INTO aircraft
  FROM airlinerra_game.airline_aircraft_inventory i WHERE i.id=NEW.source_inventory_id;
  IF NOT FOUND OR aircraft.configuration_id<>NEW.configuration_id THEN
   RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='USED_CABIN_SOURCE_AIRCRAFT_MISMATCH'; END IF;
  SELECT * INTO installed FROM airlinerra_game.aircraft_installed_cabins_v1
  WHERE aircraft_inventory_id=NEW.source_inventory_id
    AND configuration_id=NEW.configuration_id AND airline_id=aircraft.airline_id;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='23514',
   MESSAGE='USED_CABIN_SOURCE_NOT_INSTALLED'; END IF;
  NEW.cabin_snapshot=jsonb_build_object(
   'economy',installed.installed_economy,'premium',installed.installed_premium,
   'business',installed.installed_business,'first',installed.installed_first,
   'economyType',installed.installed_economy_type,'premiumType',installed.installed_premium_type,
   'businessType',installed.installed_business_type,'firstType',installed.installed_first_type,
   'extraLegroomCm',installed.installed_extra_legroom_cm);
  NEW.cabin_origin=CASE WHEN installed.installed_source='catalog_standard_game_layout'
   THEN 'model_default' ELSE 'previous_owner' END;
 ELSIF NEW.cabin_snapshot IS NULL THEN
  SELECT * INTO standard FROM airlinerra_game.cabin_model_standard_v1
  WHERE configuration_id=NEW.configuration_id;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='23514',
   MESSAGE='USED_CABIN_MODEL_STANDARD_MISSING'; END IF;
  SELECT * INTO factory FROM airlinerra_game.cabin_model_factory_layout_v2
  WHERE configuration_id=NEW.configuration_id;
  IF standard.use_type<>'cargo' AND factory.configuration_id IS NULL THEN
   RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='USED_CABIN_FACTORY_PLAN_MISSING'; END IF;
  IF standard.use_type<>'cargo' THEN
   NEW.cabin_snapshot=jsonb_build_object(
    'economy',factory.economy,'premium',factory.premium,
    'business',factory.business,'first',factory.first,
    'economyType',factory.economy_type,'premiumType',factory.premium_type,
    'businessType',factory.business_type,'firstType',factory.first_type,
    'extraLegroomCm',factory.extra_legroom_cm);
  END IF;
  NEW.cabin_origin='model_default';
 END IF;
 RETURN NEW;
END
$function$;

-- Rebase only unsold, computer-generated stock. Never change player-sourced
-- airframes or any cabin installed in a player's live inventory.
UPDATE airlinerra_game.used_aircraft_auction_lots_v1 lot
SET cabin_origin='model_default',
 cabin_snapshot=jsonb_build_object(
  'economy',f.economy,'premium',f.premium,'business',f.business,'first',f.first,
  'economyType',f.economy_type,'premiumType',f.premium_type,
  'businessType',f.business_type,'firstType',f.first_type,
  'extraLegroomCm',f.extra_legroom_cm)
FROM airlinerra_game.cabin_model_factory_layout_v2 f
WHERE lot.configuration_id=f.configuration_id
 AND lot.source_inventory_id IS NULL AND lot.cabin_origin='model_default'
 AND lot.status IN ('available','bidding');

COMMENT ON COLUMN airlinerra_game.used_aircraft_auction_lots_v1.cabin_snapshot IS
 'Installed cabin snapshot: generated dealer stock uses whole-row factory v2; user-source listing copies that individual aircraft last-installed plan, which transfers unchanged on auction award.';
