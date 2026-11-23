
CREATE TABLE airlinerra.airport_game_foundation_release_authorizations(
 release_key text PRIMARY KEY,
 cohort text NOT NULL CHECK(cohort='ORIGINAL_3140'),
 world_number smallint NOT NULL CHECK(world_number=1),
 authorized_airport_count integer NOT NULL CHECK(authorized_airport_count=3140),
 permission_basis text NOT NULL,
 release_purpose text NOT NULL DEFAULT 'SIMULATION_GAME_CATALOG' CHECK(release_purpose='SIMULATION_GAME_CATALOG'),
 commercial_operator_authority_verified boolean NOT NULL DEFAULT false CHECK(commercial_operator_authority_verified=false),
 production_site_release_authorized boolean NOT NULL DEFAULT false CHECK(production_site_release_authorized=false),
 recorded_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE airlinerra.airport_game_foundation_release_members(
 release_key text NOT NULL REFERENCES airlinerra.airport_game_foundation_release_authorizations(release_key),
 airport_key text NOT NULL,
 cohort text NOT NULL DEFAULT 'ORIGINAL_3140' CHECK(cohort='ORIGINAL_3140'),
 world_number smallint NOT NULL DEFAULT 1 CHECK(world_number=1),
 release_scope text NOT NULL DEFAULT 'SIMULATION_GAMEPLAY_ONLY' CHECK(release_scope='SIMULATION_GAMEPLAY_ONLY'),
 operating_permissions_asserted boolean NOT NULL DEFAULT false CHECK(operating_permissions_asserted=false),
 included_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(release_key,airport_key),UNIQUE(world_number,airport_key),
 FOREIGN KEY(airport_key,cohort) REFERENCES airlinerra.airport_cohorts(airport_key,cohort)
);
ALTER TABLE airlinerra.airport_game_foundation_release_authorizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra.airport_game_foundation_release_members ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_game_foundation_release_authorizations FROM anon,authenticated;
REVOKE ALL ON airlinerra.airport_game_foundation_release_members FROM anon,authenticated;
INSERT INTO airlinerra.airport_game_foundation_release_authorizations
(release_key,cohort,world_number,authorized_airport_count,permission_basis)
VALUES('FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26','ORIGINAL_3140',1,3140,
'Owner explicitly authorized making original 3140 airport cohort available to the simulated game database on 2026-10-26, before later airport expansion. This does not grant real-world commercial operating permission or production website deployment.');
DO $guard$ DECLARE n integer;
BEGIN
 SELECT count(*) INTO n FROM airlinerra.airport_cohorts c
 JOIN airlinerra.airport_registry r ON r.airport_key=c.airport_key
 JOIN airlinerra.airport_game_profiles p ON p.airport_key=c.airport_key
 WHERE c.cohort='ORIGINAL_3140' AND r.runway_screen_status='RUNWAY_QUALIFIED'
 AND r.longest_qualifying_runway_m>=1200
 AND r.latitude_deg IS NOT NULL AND r.longitude_deg IS NOT NULL
 AND r.country_iso IS NOT NULL AND r.airport_name IS NOT NULL
 AND p.proposed_category IN('Local','Regional','Medium','Large','Major Hub','Mega Hub');
 IF n<>3140 THEN RAISE EXCEPTION 'Original airport cohort validation failed: %',n; END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_world_activation) THEN
  RAISE EXCEPTION 'World activation should be empty at initial owner release'; END IF;
END $guard$;
INSERT INTO airlinerra.airport_game_foundation_release_members(release_key,airport_key)
SELECT 'FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26',c.airport_key
FROM airlinerra.airport_cohorts c
JOIN airlinerra.airport_registry r ON r.airport_key=c.airport_key
JOIN airlinerra.airport_game_profiles p ON p.airport_key=c.airport_key
WHERE c.cohort='ORIGINAL_3140' AND r.runway_screen_status='RUNWAY_QUALIFIED'
AND r.longest_qualifying_runway_m>=1200
AND p.proposed_category IN('Local','Regional','Medium','Large','Major Hub','Mega Hub');

CREATE OR REPLACE FUNCTION airlinerra.enforce_game_airport_activation()
RETURNS trigger LANGUAGE plpgsql SET search_path TO 'airlinerra','pg_temp' AS $function$
BEGIN
 IF NEW.active AND NEW.world_number=1 AND EXISTS(
   SELECT 1 FROM airlinerra.airport_game_foundation_release_members m
   JOIN airlinerra.airport_game_foundation_release_authorizations a ON a.release_key=m.release_key
   JOIN airlinerra.airport_cohorts c ON c.airport_key=m.airport_key AND c.cohort='ORIGINAL_3140'
   JOIN airlinerra.airport_registry r ON r.airport_key=m.airport_key
   JOIN airlinerra.airport_game_profiles p ON p.airport_key=m.airport_key
   WHERE m.airport_key=NEW.airport_key AND m.world_number=1
   AND a.world_number=1 AND a.cohort='ORIGINAL_3140'
   AND a.release_purpose='SIMULATION_GAME_CATALOG' AND a.authorized_airport_count=3140
   AND r.runway_screen_status='RUNWAY_QUALIFIED'
   AND r.longest_qualifying_runway_m>=1200
   AND p.proposed_category IN('Local','Regional','Medium','Large','Major Hub','Mega Hub')
 ) THEN RETURN NEW; END IF;
 IF NEW.active AND NOT EXISTS(
  SELECT 1 FROM airlinerra.airport_access_reviews a
  JOIN airlinerra.airport_game_profiles p ON p.airport_key=a.airport_key
  WHERE a.airport_key=NEW.airport_key
  AND a.game_admission_status='APPROVED_FOR_GAME'
  AND a.owner_approved_at IS NOT NULL AND a.approved_by IS NOT NULL
  AND a.identity_status='VERIFIED' AND a.paved_runway_status='VERIFIED'
  AND a.civilian_access_status='VERIFIED' AND a.commercial_permission_status='VERIFIED'
  AND p.final_category IS NOT NULL AND p.category_approved_at IS NOT NULL
 ) THEN
  RAISE EXCEPTION 'Airlinerra airport is not approved for gameplay activation: %',NEW.airport_key;
 END IF;
 RETURN NEW;
END $function$;

INSERT INTO airlinerra.airport_world_activation(world_number,airport_key,active,activated_at)
SELECT 1,m.airport_key,true,now()
FROM airlinerra.airport_game_foundation_release_members m
WHERE m.release_key='FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26';

CREATE VIEW airlinerra.airport_game_world1_catalog WITH(security_invoker=true) AS
SELECT w.world_number,r.airport_key,r.airport_name,r.country_iso,r.region_code,
r.municipality,r.source_ident AS airport_code,r.source_gps_code,
r.latitude_deg,r.longitude_deg,r.longest_qualifying_runway_m,
r.longest_qualifying_surface,r.minimum_eligible_level,
p.proposed_category AS game_display_category,p.final_category,
(p.final_category IS NOT NULL) AS category_finalized,
'OWNER_AUTHORIZED_SIMULATION_CATALOG'::text AS game_catalog_basis,
a.game_admission_status AS commercial_access_admission,w.activated_at
FROM airlinerra.airport_world_activation w
JOIN airlinerra.airport_game_foundation_release_members m
 ON m.world_number=w.world_number AND m.airport_key=w.airport_key
JOIN airlinerra.airport_registry r ON r.airport_key=w.airport_key
JOIN airlinerra.airport_game_profiles p ON p.airport_key=w.airport_key
JOIN airlinerra.airport_access_reviews a ON a.airport_key=w.airport_key
WHERE w.world_number=1 AND w.active
AND m.release_key='FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26'
AND r.runway_screen_status='RUNWAY_QUALIFIED';
REVOKE ALL ON airlinerra.airport_game_world1_catalog FROM anon,authenticated;

DO $audit$ BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE world_number=1 AND active)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_catalog)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_foundation_release_members)<>3140
 THEN RAISE EXCEPTION 'Initial release missing or duplicated airports'; END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_world_activation w
 LEFT JOIN airlinerra.airport_cohorts c
 ON c.airport_key=w.airport_key AND c.cohort='ORIGINAL_3140'
 WHERE w.active AND c.airport_key IS NULL)
 THEN RAISE EXCEPTION 'Unauthorized non-original world activation'; END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 THEN RAISE EXCEPTION 'Unauthorized additional world activation'; END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_access_reviews WHERE game_admission_status<>'NOT_APPROVED')
 THEN RAISE EXCEPTION 'Commercial access status improperly changed'; END IF;
END $audit$;
