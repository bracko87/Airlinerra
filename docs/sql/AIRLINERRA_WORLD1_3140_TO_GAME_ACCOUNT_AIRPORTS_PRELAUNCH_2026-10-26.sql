-- Airlinerra first 3,140 airports -> PRIVATE game account schema roster.
-- PRELAUNCH / NOT APPLIED as of 2026-10-26.
-- Run ONLY AFTER docs/sql/airlinerra_game_identity_schema_prelaunch.sql
-- has been separately reviewed/installed by the authentication workstream.
-- This bridge does NOT open registration, create users/airlines, start a trial,
-- activate World 2/3, claim airport-owner operating permissions or grant
-- any public Data API SELECT/WRITE privileges.
BEGIN;
DO $preflight$ DECLARE n integer;
BEGIN
 IF to_regclass('airlinerra_game.approved_game_airports') IS NULL
    OR to_regclass('public.airlinerra_game_worlds') IS NULL
 THEN RAISE EXCEPTION 'Game/account schema is not installed: abort airport sync'; END IF;
 IF NOT EXISTS (SELECT 1 FROM public.airlinerra_game_worlds WHERE id=1)
 THEN RAISE EXCEPTION 'World 1 game account directory missing'; END IF;
 SELECT count(*) INTO n FROM airlinerra.airport_game_world1_registration_source;
 IF n<>3140 THEN RAISE EXCEPTION 'Found % authorized home airport identities; expected 3140',n;END IF;
 IF (SELECT count(DISTINCT airport_key) FROM airlinerra.airport_game_world1_registration_source)<>3140
 THEN RAISE EXCEPTION 'Duplicate airport keys';END IF;
 IF EXISTS (SELECT 1 FROM airlinerra.airport_game_world1_registration_source
  WHERE airport_key !~ '^OURAIRPORTS:[1-9][0-9]{0,18}
 IF EXISTS(SELECT 1 FROM airlinerra.airport_game_world1_registration_source
  WHERE world_id<>1 OR admission_basis<>'OWNER_AUTHORIZED_SIMULATION_CATALOG')
 THEN RAISE EXCEPTION 'Unapproved catalog record in source';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.approved_game_airports
  WHERE world_id<>1
    OR approval_reference<>'SIMULATION_ONLY:FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26')
 THEN RAISE EXCEPTION 'Unexpected preexisting game approvals; reconcile manually';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.approved_game_airports a
  LEFT JOIN airlinerra.airport_game_world1_registration_source c
  ON c.world_id=a.world_id AND c.airport_key=a.airport_key
  WHERE c.airport_key IS NULL)
 THEN RAISE EXCEPTION 'Preexisting game approval outside authorized first cohort';END IF;
END $preflight$;

INSERT INTO airlinerra_game.approved_game_airports
  (world_id,airport_key,approval_reference)
SELECT c.world_id,c.airport_key,
  'SIMULATION_ONLY:FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26'
FROM airlinerra.airport_game_world1_registration_source c
ON CONFLICT(world_id,airport_key) DO NOTHING;

DO $verify$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.approved_game_airports
  WHERE world_id=1)<>3140
 THEN RAISE EXCEPTION 'Game approval roster not exactly 3140';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.approved_game_airports a
  LEFT JOIN airlinerra.airport_game_world1_registration_source c
  ON c.world_id=a.world_id AND c.airport_key=a.airport_key
  WHERE c.airport_key IS NULL OR a.world_id<>1)
 THEN RAISE EXCEPTION 'Unauthorized home airport was added';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.approved_game_airports
  WHERE approval_reference<>'SIMULATION_ONLY:FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26')
 THEN RAISE EXCEPTION 'Unscoped game airport approval reference';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_world_activation
     WHERE active AND world_number=1)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation
     WHERE active AND world_number<>1)
 THEN RAISE EXCEPTION 'Research database world activation drifted';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_access_reviews
  WHERE game_admission_status='APPROVED_FOR_GAME')
 THEN RAISE EXCEPTION 'Commercial access verification was unexpectedly changed';END IF;
END $verify$;
COMMIT;

-- Backend account activation uses stable text airport_key values (for example
-- OURAIRPORTS:101), not bigint IDs. Home-airport choices come only from the
-- owner-authorized registration source and are revalidated against
-- airlinerra_game.approved_game_airports in create_airline_once().
-- Keeping public.airlinerra_game_worlds.state='planned' is REQUIRED until the
-- independent authentication/terms/mail/security launch checklist is approved.
)
 THEN RAISE EXCEPTION 'Invalid authorized airport key'; END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_game_world1_registration_source
  WHERE world_id<>1 OR admission_basis<>'OWNER_AUTHORIZED_SIMULATION_CATALOG')
 THEN RAISE EXCEPTION 'Unapproved catalog record in source';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.approved_game_airports
  WHERE world_id<>1
    OR approval_reference<>'SIMULATION_ONLY:FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26')
 THEN RAISE EXCEPTION 'Unexpected preexisting game approvals; reconcile manually';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.approved_game_airports a
  LEFT JOIN airlinerra.airport_game_world1_registration_source c
  ON c.world_id=a.world_id AND c.airport_key=a.airport_key
  WHERE c.airport_key IS NULL)
 THEN RAISE EXCEPTION 'Preexisting game approval outside authorized first cohort';END IF;
END $preflight$;

INSERT INTO airlinerra_game.approved_game_airports
  (world_id,airport_key,approval_reference)
SELECT c.world_id,c.airport_key,
  'SIMULATION_ONLY:FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26'
FROM airlinerra.airport_game_world1_registration_source c
ON CONFLICT(world_id,airport_key) DO NOTHING;

DO $verify$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.approved_game_airports
  WHERE world_id=1)<>3140
 THEN RAISE EXCEPTION 'Game approval roster not exactly 3140';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.approved_game_airports a
  LEFT JOIN airlinerra.airport_game_world1_registration_source c
  ON c.world_id=a.world_id AND c.airport_key=a.airport_key
  WHERE c.airport_key IS NULL OR a.world_id<>1)
 THEN RAISE EXCEPTION 'Unauthorized home airport was added';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.approved_game_airports
  WHERE approval_reference<>'SIMULATION_ONLY:FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26')
 THEN RAISE EXCEPTION 'Unscoped game airport approval reference';END IF;
 IF (SELECT count(*) FROM airlinerra.airport_world_activation
     WHERE active AND world_number=1)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation
     WHERE active AND world_number<>1)
 THEN RAISE EXCEPTION 'Research database world activation drifted';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra.airport_access_reviews
  WHERE game_admission_status='APPROVED_FOR_GAME')
 THEN RAISE EXCEPTION 'Commercial access verification was unexpectedly changed';END IF;
END $verify$;
COMMIT;

-- The backend account activation uses airport_key BIGINT, not the
-- private text key OURAIRPORTS:<id>. Home-airport options must come from
-- airlinerra.airport_game_world1_registration_source and be revalidated
-- against airlinerra_game.approved_game_airports in create_airline_once().
-- Keeping public.airlinerra_game_worlds.state='planned' is REQUIRED until the
-- independent authentication/terms/mail/security launch checklist is approved.
