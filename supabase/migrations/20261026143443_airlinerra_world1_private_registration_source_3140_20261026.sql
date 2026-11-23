-- Owner-authorized World 1 simulation catalog -> registration reference adapter.
-- This is a PRIVATE read-only view. No public Data API grants, account/world
-- activation, profile updates, or real operating permissions are created.
DO $guard$
DECLARE n int;
BEGIN
 SELECT count(*) INTO n
 FROM airlinerra.airport_game_world1_catalog c
 JOIN airlinerra.airport_registry r ON r.airport_key=c.airport_key
 WHERE c.world_number=1
   AND r.source_type='OURAIRPORTS'
   AND r.airport_key='OURAIRPORTS:'||r.source_airport_id
   AND r.source_airport_id ~ '^[1-9][0-9]{0,18}$'
   AND r.source_airport_id::numeric <= 9223372036854775807
   AND c.airport_code IS NOT NULL
   AND c.game_display_category IN('Local','Regional','Medium','Large','Major Hub','Mega Hub');
 IF n<>3140 THEN
  RAISE EXCEPTION 'World1 home airport catalog failed first 3140 source-id/identity check (got %)',n;
 END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_world_activation a
   WHERE a.active AND a.world_number<>1)
 THEN RAISE EXCEPTION 'Unexpected additional world active'; END IF;
END $guard$;
CREATE OR REPLACE VIEW airlinerra.airport_game_world1_registration_source
WITH (security_invoker=true) AS
SELECT c.world_number::smallint AS world_id,
       r.source_airport_id::bigint AS home_airport_source_id,
       c.airport_key,
       c.airport_code,
       c.airport_name,
       c.country_iso,
       c.municipality,
       c.latitude_deg,
       c.longitude_deg,
       c.game_display_category AS provisional_game_category,
       'OWNER_AUTHORIZED_SIMULATION_CATALOG'::text AS admission_basis
FROM airlinerra.airport_game_world1_catalog c
JOIN airlinerra.airport_registry r ON r.airport_key=c.airport_key
WHERE c.world_number=1
  AND r.source_type='OURAIRPORTS'
  AND r.airport_key='OURAIRPORTS:'||r.source_airport_id
  AND r.source_airport_id ~ '^[1-9][0-9]{0,18}$'
  AND r.source_airport_id::numeric <= 9223372036854775807;
REVOKE ALL ON airlinerra.airport_game_world1_registration_source FROM PUBLIC,anon,authenticated;
DO $audit$
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR (SELECT count(distinct home_airport_source_id)
    FROM airlinerra.airport_game_world1_registration_source)<>3140
 THEN RAISE EXCEPTION 'Registration reference has missing/duplicate IDs'; END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_game_world1_registration_source
  WHERE world_id<>1 OR admission_basis<>'OWNER_AUTHORIZED_SIMULATION_CATALOG')
 THEN RAISE EXCEPTION 'Invalid registration airport source scope'; END IF;
 IF (SELECT count(*) FROM airlinerra.airport_cohorts WHERE cohort='EXPANSION_3906')<>3906
 OR (SELECT count(*) FROM airlinerra.airport_world_activation WHERE active)<>3140
 THEN RAISE EXCEPTION 'Unexpected expansion or world activation'; END IF;
END $audit$;
