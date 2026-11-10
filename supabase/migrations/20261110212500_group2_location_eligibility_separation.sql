-- World 1 location selection independent from commercial airport admission.
-- Group 2 can be chosen as HQ or office DRAFT, never automatically book flights.
DO $pre$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
  OR (SELECT count(*) FROM airlinerra_game.airport_sections1_8_combined_catalog_v1)<>4259
  OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1)<>1118
  OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
    WHERE commercial_playable OR commercial_access_verified)
 THEN RAISE EXCEPTION 'GROUP2_LOCATION_SEPARATION_PREFLIGHT_FAILED';END IF;
END $pre$;

CREATE TABLE airlinerra_game.airport_location_eligibility_v1(
 world_id smallint NOT NULL,
 airport_key text NOT NULL,
 airport_name text NOT NULL,
 airport_code text,
 country_iso text NOT NULL,
 municipality text,
 source_group text NOT NULL CHECK(source_group IN('GROUP_1','GROUP_2')),
 hq_selectable boolean NOT NULL DEFAULT true,
 office_selectable boolean NOT NULL DEFAULT true,
 commercial_airport_admitted boolean NOT NULL DEFAULT false,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(world_id,airport_key),
 CHECK(world_id=1),
 CHECK(country_iso ~ '^[A-Z]{2}$'),
 CHECK(airport_key ~ '^OURAIRPORTS:[1-9][0-9]{0,18}$' OR
       airport_key ~ '^FICTIONAL:fictional:[A-Z]{2}:[A-Z0-9]{2,8}$'),
 CHECK(source_group='GROUP_1' OR commercial_airport_admitted=false),
 FOREIGN KEY(world_id) REFERENCES public.airlinerra_game_worlds(id)
);
INSERT INTO airlinerra_game.airport_location_eligibility_v1(
 world_id,airport_key,airport_name,airport_code,country_iso,municipality,
 source_group,hq_selectable,office_selectable,commercial_airport_admitted)
SELECT a.world_id,a.airport_key,coalesce(a.airport_name,a.airport_key),
 a.airport_code,coalesce(a.country_iso,'XX'),a.municipality,
 'GROUP_1',true,true,true
FROM airlinerra_game.approved_game_airports a WHERE a.world_id=1
UNION ALL
SELECT c.world_id,c.airport_key,c.airport_name,c.game_lookup_code,
 c.country_iso,g.game_locality_display,'GROUP_2',true,true,false
FROM airlinerra_game.airport_sections1_8_combined_catalog_v1 c
JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key)
WHERE c.world_id=1 AND c.source_group='GROUP_2'
 AND c.commercial_access_scope='GROUP2_PREPARED_NOT_ADMITTED'
 AND c.game_data_status='game_complete_estimated';
ALTER TABLE airlinerra_game.airport_location_eligibility_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_location_eligibility_v1 FROM PUBLIC,anon,authenticated;
CREATE INDEX airport_location_source_v1 ON airlinerra_game.airport_location_eligibility_v1(source_group,world_id);

-- HQ and offices can use the selection registry. Flight/route/delivery movement
-- foreign keys remain tied to approved_game_airports.
ALTER TABLE airlinerra_game.airlines
 DROP CONSTRAINT airlines_world_id_home_airport_key_fkey,
 ADD CONSTRAINT airlines_location_eligible_fk
 FOREIGN KEY(world_id,home_airport_key)
 REFERENCES airlinerra_game.airport_location_eligibility_v1(world_id,airport_key);
ALTER TABLE airlinerra_game.airport_offices
 DROP CONSTRAINT airport_offices_approved_world_fk,
 ADD CONSTRAINT airport_offices_location_eligible_fk
 FOREIGN KEY(world_id,airport_key)
 REFERENCES airlinerra_game.airport_location_eligibility_v1(world_id,airport_key);
ALTER TABLE airlinerra_game.initial_aircraft_allocations_v1
 DROP CONSTRAINT starter_home_fk,
 ADD CONSTRAINT starter_location_eligible_fk
 FOREIGN KEY(world_id,initial_home_airport_key)
 REFERENCES airlinerra_game.airport_location_eligibility_v1(world_id,airport_key)
 DEFERRABLE INITIALLY DEFERRED;

CREATE OR REPLACE FUNCTION airlinerra_game.enforce_location_selection_eligibility_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path='' AS $trg$
DECLARE permitted boolean;
BEGIN
 SELECT CASE TG_TABLE_NAME WHEN 'airlines' THEN hq_selectable
 ELSE office_selectable END INTO permitted
 FROM airlinerra_game.airport_location_eligibility_v1
 WHERE world_id=NEW.world_id AND airport_key=
  CASE WHEN TG_TABLE_NAME='airlines' THEN NEW.home_airport_key ELSE NEW.airport_key END;
 IF permitted IS DISTINCT FROM true THEN
  RAISE EXCEPTION 'Location is not eligible for selection'
    USING ERRCODE='23514';
 END IF;
 RETURN NEW;
END $trg$;
REVOKE ALL ON FUNCTION airlinerra_game.enforce_location_selection_eligibility_v1()
FROM PUBLIC,anon,authenticated;
CREATE TRIGGER airlines_eligibility_v1 BEFORE INSERT OR UPDATE OF home_airport_key,world_id
 ON airlinerra_game.airlines FOR EACH ROW
 EXECUTE FUNCTION airlinerra_game.enforce_location_selection_eligibility_v1();
CREATE TRIGGER airport_offices_eligibility_v1 BEFORE INSERT OR UPDATE OF airport_key,world_id
 ON airlinerra_game.airport_offices FOR EACH ROW
 EXECUTE FUNCTION airlinerra_game.enforce_location_selection_eligibility_v1();

DO $post$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_location_eligibility_v1)<>4259
 OR (SELECT count(*) FROM airlinerra_game.airport_location_eligibility_v1 WHERE source_group='GROUP_2' AND hq_selectable AND office_selectable AND NOT commercial_airport_admitted)<>1118
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1
 WHERE commercial_playable OR commercial_access_verified)<>0
 THEN RAISE EXCEPTION 'GROUP2_LOCATION_SEPARATION_POSTCHECK_FAILED';END IF;
END $post$;