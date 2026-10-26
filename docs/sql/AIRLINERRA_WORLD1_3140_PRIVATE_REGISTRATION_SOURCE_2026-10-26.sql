-- World 1 owner-authorized first 3,140 simulation airports.
-- Applied in Supabase migration airlinerra_world1_private_registration_source_3140_20261026.
-- Exact PostgreSQL read-back of registration-source view, anchored to original release.
-- Run in the PRIVATE airlinerra schema; no browser keys or direct public grants.
DO $check$ DECLARE found integer; BEGIN
 SELECT COUNT(*) INTO found FROM airlinerra.airport_game_world1_catalog
 WHERE world_number=1;
 IF found<>3140 THEN RAISE EXCEPTION 'World 1 founding cohort is incomplete: %',found; END IF;
END $check$;
CREATE OR REPLACE VIEW airlinerra.airport_game_world1_registration_source
WITH (security_invoker=true) AS
SELECT c.world_number AS world_id,
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
     JOIN airlinerra.airport_registry r ON r.airport_key = c.airport_key
  WHERE c.world_number = 1 AND r.source_type = 'OURAIRPORTS'::text AND r.airport_key = ('OURAIRPORTS:'::text || r.source_airport_id) AND r.source_airport_id ~ '^[1-9][0-9]{0,18}$'::text AND r.source_airport_id::numeric <= '9223372036854775807'::bigint::numeric;
REVOKE ALL ON airlinerra.airport_game_world1_registration_source FROM PUBLIC,anon,authenticated;
DO $audit$ BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR (SELECT count(DISTINCT home_airport_source_id) FROM airlinerra.airport_game_world1_registration_source)<>3140
 THEN RAISE EXCEPTION 'Missing or duplicated onboarding airport IDs'; END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_game_world1_registration_source
 WHERE world_id<>1 OR admission_basis<>'OWNER_AUTHORIZED_SIMULATION_CATALOG')
 THEN RAISE EXCEPTION 'Non-foundation airport leaked into registration'; END IF;
END $audit$;
