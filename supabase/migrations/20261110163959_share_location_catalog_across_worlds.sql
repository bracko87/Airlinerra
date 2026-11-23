-- Same airport *location* choices in every Airlinerra world.
-- Does not admit Group 2 into flight reservations or dispatch.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_location_eligibility_v1 WHERE world_id=1)<>4259
 OR (SELECT count(*) FROM airlinerra_game.airport_location_eligibility_v1 WHERE world_id=1 AND source_group='GROUP_2')<>1118
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_location_eligibility_v1 WHERE world_id<>1)
 OR (SELECT count(*) FROM public.airlinerra_game_worlds WHERE id IN(1,2,3))<>3
 THEN RAISE EXCEPTION 'GLOBAL_AIRPORT_LOCATION_PREFLIGHT_FAILED';END IF;
END $$;
ALTER TABLE airlinerra_game.airport_location_eligibility_v1
 DROP CONSTRAINT airport_location_eligibility_v1_world_id_check,
 ADD CONSTRAINT airport_location_eligibility_v1_world_id_check CHECK(world_id BETWEEN 1 AND 3);
INSERT INTO airlinerra_game.airport_location_eligibility_v1(
 world_id,airport_key,airport_name,airport_code,country_iso,municipality,
 source_group,hq_selectable,office_selectable,commercial_airport_admitted)
SELECT w.id,a.airport_key,a.airport_name,a.airport_code,a.country_iso,a.municipality,
 a.source_group,a.hq_selectable,a.office_selectable,false
FROM public.airlinerra_game_worlds w
CROSS JOIN airlinerra_game.airport_location_eligibility_v1 a
WHERE w.id IN (2,3) AND a.world_id=1;
DO $$
BEGIN
 IF EXISTS(SELECT 1 FROM (
  SELECT world_id,count(*) n,
   count(*) FILTER(WHERE source_group='GROUP_2') group2
  FROM airlinerra_game.airport_location_eligibility_v1
  GROUP BY world_id) x WHERE n<>4259 OR group2<>1118)
 OR (SELECT count(DISTINCT world_id) FROM airlinerra_game.airport_location_eligibility_v1)<>3
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports)<>3141
 THEN RAISE EXCEPTION 'GLOBAL_AIRPORT_LOCATION_POSTCHECK_FAILED';END IF;
END $$;