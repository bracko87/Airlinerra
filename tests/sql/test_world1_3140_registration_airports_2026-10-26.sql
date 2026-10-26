-- Airlinerra World1 first-cohort airport registration adapter regression.
-- Executed PASS against private Supabase on 2026-10-26.
-- This is a read-only test; no app accounts, game rosters or worlds mutated.
DO $verify$
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR (SELECT count(distinct home_airport_source_id)
     FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR (SELECT count(distinct airport_key)
     FROM airlinerra.airport_game_world1_registration_source)<>3140
 THEN RAISE EXCEPTION 'World1 registration source not exactly 3140 distinct airports';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_game_world1_registration_source v
  WHERE v.world_id<>1 OR v.home_airport_source_id<=0
  OR v.airport_key<>'OURAIRPORTS:'||v.home_airport_source_id::text
  OR v.admission_basis<>'OWNER_AUTHORIZED_SIMULATION_CATALOG'
  OR v.airport_code IS NULL OR trim(v.airport_code)=''
  OR v.provisional_game_category NOT IN
    ('Local','Regional','Medium','Large','Major Hub','Mega Hub'))
 THEN RAISE EXCEPTION 'Invalid airport ID or six-category/display coverage';END IF;
 IF (SELECT count(distinct country_iso)
    FROM airlinerra.airport_game_world1_registration_source)<>229
 THEN RAISE EXCEPTION 'Missing foundation geographical codes';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_game_world1_registration_source v
  LEFT JOIN airlinerra.airport_cohorts c ON c.airport_key=v.airport_key
   AND c.cohort='ORIGINAL_3140'
  WHERE c.airport_key IS NULL)
 THEN RAISE EXCEPTION 'Expansion/other source airport leaked into picker';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_world_activation
  WHERE active AND world_number<>1)
 THEN RAISE EXCEPTION 'An unapproved game world was activated';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_access_reviews
  WHERE game_admission_status='APPROVED_FOR_GAME')
 THEN RAISE EXCEPTION 'Research permission incorrectly marked approved';END IF;
 IF EXISTS(SELECT 1 FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='airlinerra'
    AND c.relname='airport_game_world1_registration_source'
    AND (c.reloptions IS NULL
    OR NOT ('security_invoker=true'=ANY(c.reloptions))
    OR has_table_privilege('anon',c.oid,'SELECT')
    OR has_table_privilege('authenticated',c.oid,'SELECT')))
 THEN RAISE EXCEPTION 'Source view no longer private or security-invoker';END IF;
END $verify$;
SELECT 'PASS' AS private_registration_airport_catalog;
