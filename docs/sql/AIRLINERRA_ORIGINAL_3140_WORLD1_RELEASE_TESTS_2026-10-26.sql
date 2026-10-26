-- Airlinerra original 3,140 airport founder release World 1 — smoke/negative tests.
-- Run in private Supabase admin role only. No public permissions are granted.
DO $tests$ DECLARE blocked_expansion boolean:=false;blocked_other_world boolean:=false;ex_key text;orig_key text;
BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE world_number=1 AND active)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_catalog)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_foundation_release_members)<>3140
 THEN RAISE EXCEPTION 'World1 founder 3140 total mismatch';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 THEN RAISE EXCEPTION 'World2/3 unexpectedly enabled';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_world_activation w
 JOIN airlinerra.airport_cohorts c ON c.airport_key=w.airport_key
 WHERE w.active AND c.cohort<>'ORIGINAL_3140')
 THEN RAISE EXCEPTION 'Expansion or other airport active';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_game_world1_catalog
 WHERE game_display_category NOT IN('Local','Regional','Medium','Large','Major Hub','Mega Hub')
 OR NOT (commercial_access_admission='NOT_APPROVED') OR category_finalized)
 THEN RAISE EXCEPTION 'Unexpected operational clearance or non-six-tier category';END IF;
 IF (SELECT count(distinct country_iso) FROM airlinerra.airport_game_world1_catalog)<>229
 THEN RAISE EXCEPTION 'Countries unexpectedly missing';END IF;
 SELECT airport_key INTO ex_key FROM airlinerra.airport_cohorts WHERE cohort='EXPANSION_3906' ORDER BY airport_key LIMIT 1;
 SELECT airport_key INTO orig_key FROM airlinerra.airport_cohorts WHERE cohort='ORIGINAL_3140' ORDER BY airport_key LIMIT 1;
 BEGIN
 INSERT INTO airlinerra.airport_world_activation(world_number,airport_key,active,activated_at)
 VALUES(1,ex_key,true,now());
 EXCEPTION WHEN raise_exception THEN blocked_expansion:=true;END;
 BEGIN
 INSERT INTO airlinerra.airport_world_activation(world_number,airport_key,active,activated_at)
 VALUES(2,orig_key,true,now());
 EXCEPTION WHEN raise_exception THEN blocked_other_world:=true;END;
 IF NOT blocked_expansion OR NOT blocked_other_world
 THEN RAISE EXCEPTION 'Owner authorization boundaries were bypassed';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE active)<>3140
 THEN RAISE EXCEPTION 'Failed activation test changed data';END IF;
END $tests$;
SELECT 'PASS' AS world1_foundation_release;
