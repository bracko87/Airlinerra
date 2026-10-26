-- Synthetic fixture for GitHub Actions disposable PostgreSQL only.
-- It represents 3,140 fake airport IDs, NOT the live research registry.
-- Must run only after tests/sql/disposable_database_preflight.sql and the
-- local-only account foundation/activation draft schema.
DO $guard$
BEGIN
  IF current_database() <> 'airlinerra_disposable' THEN
    RAISE EXCEPTION 'Refuse synthetic airport fixture outside disposable CI database';
  END IF;
  IF (SELECT count(*) FROM airlinerra_game.approved_game_airports) <> 0 THEN
    RAISE EXCEPTION 'Airport fixture needs an empty game-approval table';
  END IF;
END $guard$;

CREATE SCHEMA airlinerra;
REVOKE ALL ON SCHEMA airlinerra FROM PUBLIC, anon, authenticated;

CREATE TABLE airlinerra.airport_game_world1_registration_source (
  world_id smallint NOT NULL,
  airport_key text NOT NULL,
  admission_basis text NOT NULL
);
CREATE TABLE airlinerra.airport_world_activation (
  world_number smallint NOT NULL,
  active boolean NOT NULL
);
CREATE TABLE airlinerra.airport_access_reviews (
  game_admission_status text NOT NULL
);

INSERT INTO airlinerra.airport_game_world1_registration_source
  (world_id,airport_key,admission_basis)
SELECT 1::smallint,'OURAIRPORTS:' || n::text,
       'OWNER_AUTHORIZED_SIMULATION_CATALOG'
FROM generate_series(1,3140) AS n;

INSERT INTO airlinerra.airport_world_activation (world_number,active)
SELECT 1::smallint,true FROM generate_series(1,3140);

DO $audit$
BEGIN
  IF (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source) <> 3140 THEN
    RAISE EXCEPTION 'Synthetic World 01 fixture has wrong count';
  END IF;
  IF EXISTS (SELECT 1 FROM airlinerra.airport_game_world1_registration_source
             WHERE world_id <> 1 OR admission_basis <> 'OWNER_AUTHORIZED_SIMULATION_CATALOG') THEN
    RAISE EXCEPTION 'Synthetic World 01 source scope incorrect';
  END IF;
END $audit$;
