-- Airlinerra Licence 1: connect original registration to protected AOC bridge.
-- Dormant while AOC issuance_enabled=false. No automatic backfill or release.
-- Existing registration, ICAO/IATA assignment, trial and cash logic preserved.
CREATE OR REPLACE FUNCTION airlinerra_game.create_airline_with_codes(
 p_player_id uuid,p_world_id smallint,p_name text,p_home_airport_key text,
 p_icao_code text,p_iata_code text
) RETURNS TABLE(airline_id uuid,newly_created boolean,starting_balance_usd numeric,trial_ends_at timestamptz)
LANGUAGE plpgsql SECURITY INVOKER SET search_path TO ''
AS $fn$
DECLARE
 v_created record;
 v_icao text := upper(btrim(p_icao_code));
 v_iata text := upper(btrim(p_iata_code));
 v_aoc jsonb;
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
  IF NOT FOUND THEN
   RAISE EXCEPTION 'Airline code assignment failed' USING ERRCODE='check_violation';
  END IF;
 ELSE
  PERFORM 1 FROM airlinerra_game.airlines a
  WHERE a.id=v_created.airline_id AND a.owner_player_id=p_player_id
    AND a.world_id=p_world_id AND a.icao_code=v_icao AND a.iata_code=v_iata;
  IF NOT FOUND THEN
   RAISE EXCEPTION 'Existing airline identity cannot be changed by registration'
    USING ERRCODE='unique_violation';
  END IF;
 END IF;
 -- Call only for a NEW original World 1 airline. The bridge itself checks
 -- release, trusted role, owner/world and unique original classification,
 -- and issues exactly once in the same transaction, otherwise raises.
 -- No certificate or funds are affected while the AOC release is off.
 IF v_created.newly_created AND p_world_id=1 THEN
  v_aoc:=airlinerra_game.section9_aoc_original_registration_bridge_v1(
    p_player_id,p_world_id,v_created.airline_id);
  IF v_aoc->>'status' NOT IN ('aoc_not_released','aoc_original_issued','aoc_already_recorded')
    OR v_aoc->>'charged' IS DISTINCT FROM 'false'
    OR v_aoc->>'flightActivated' IS DISTINCT FROM 'false' THEN
   RAISE EXCEPTION 'AOC original registration returned unsafe outcome'
     USING ERRCODE='check_violation';
  END IF;
 END IF;
 RETURN QUERY SELECT v_created.airline_id::uuid,v_created.newly_created::boolean,
  v_created.starting_balance_usd::numeric,v_created.trial_ends_at::timestamptz;
END;
$fn$;
