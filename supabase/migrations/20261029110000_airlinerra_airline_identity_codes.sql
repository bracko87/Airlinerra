-- Non-destructive airline identity code support.
-- Existing airlines remain unchanged until their owner chooses codes later.
ALTER TABLE airlinerra_game.airlines
 ADD COLUMN IF NOT EXISTS icao_code text,
 ADD COLUMN IF NOT EXISTS iata_code text;
DO $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='airlinerra_airline_icao_format' AND conrelid='airlinerra_game.airlines'::regclass) THEN
  ALTER TABLE airlinerra_game.airlines ADD CONSTRAINT airlinerra_airline_icao_format CHECK (icao_code IS NULL OR icao_code ~ '^[A-Z]{3}$');
 END IF;
 IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname='airlinerra_airline_iata_format' AND conrelid='airlinerra_game.airlines'::regclass) THEN
  ALTER TABLE airlinerra_game.airlines ADD CONSTRAINT airlinerra_airline_iata_format CHECK (iata_code IS NULL OR (iata_code ~ '^[A-Z0-9]{2}$' AND iata_code ~ '[A-Z]'));
 END IF;
END $$;
CREATE UNIQUE INDEX IF NOT EXISTS airlinerra_icao_by_world
 ON airlinerra_game.airlines(world_id,icao_code) WHERE icao_code IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS airlinerra_iata_by_world
 ON airlinerra_game.airlines(world_id,iata_code) WHERE iata_code IS NOT NULL;

-- New code-aware atomic wrapper. Existing 4-argument function is kept for
-- compatibility but is not called by the new airline creation endpoint.
-- A failed unique index check rolls the entire airline, membership and
-- starting-cash transaction back.
CREATE OR REPLACE FUNCTION airlinerra_game.create_airline_with_codes(
 p_player_id uuid,p_world_id smallint,p_name text,p_home_airport_key text,
 p_icao_code text,p_iata_code text)
RETURNS TABLE(airline_id uuid,newly_created boolean,starting_balance_usd numeric,trial_ends_at timestamptz)
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
DECLARE
 v_created record;
 v_icao text := upper(btrim(p_icao_code));
 v_iata text := upper(btrim(p_iata_code));
BEGIN
 IF v_icao IS NULL OR v_icao !~ '^[A-Z]{3}$'
    OR v_iata IS NULL OR v_iata !~ '^[A-Z0-9]{2}$'
    OR v_iata !~ '[A-Z]' THEN
  RAISE EXCEPTION 'Invalid airline ICAO/IATA code'
    USING ERRCODE='check_violation';
 END IF;
 SELECT * INTO STRICT v_created
 FROM airlinerra_game.create_airline_once(p_player_id,p_world_id,p_name,p_home_airport_key);
 IF v_created.newly_created THEN
  UPDATE airlinerra_game.airlines a
  SET icao_code=v_icao,iata_code=v_iata
  WHERE a.id=v_created.airline_id AND a.owner_player_id=p_player_id
        AND a.world_id=p_world_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'Airline code assignment failed' USING ERRCODE='check_violation'; END IF;
 ELSE
  PERFORM 1 FROM airlinerra_game.airlines a
  WHERE a.id=v_created.airline_id AND a.owner_player_id=p_player_id
    AND a.world_id=p_world_id AND a.icao_code=v_icao AND a.iata_code=v_iata;
  IF NOT FOUND THEN
   RAISE EXCEPTION 'Existing airline identity cannot be changed by registration'
    USING ERRCODE='unique_violation';
  END IF;
 END IF;
 RETURN QUERY SELECT v_created.airline_id::uuid,v_created.newly_created::boolean,
   v_created.starting_balance_usd::numeric,v_created.trial_ends_at::timestamptz;
END;
$function$;
REVOKE ALL ON FUNCTION airlinerra_game.create_airline_with_codes(uuid,smallint,text,text,text,text) FROM PUBLIC,anon,authenticated;
