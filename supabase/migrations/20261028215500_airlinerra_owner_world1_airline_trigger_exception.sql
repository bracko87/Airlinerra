-- World 1 private owner pilot - align the airline INSERT trigger with
-- airlinerra_game.create_airline_once, WITHOUT enabling the public world.
-- Only a verified, currently active owner with a reserved approved email and
-- a separately recorded private-pilot review acknowledgement can use the
-- planned World 1 exception. Every other planned world remains closed.
-- The client role has no INSERT on airlinerra_game.airlines; the protected
-- activation service must still perform the atomic membership/ledger/trial.
CREATE OR REPLACE FUNCTION airlinerra_game.require_open_world_for_airline()
RETURNS trigger
LANGUAGE plpgsql
SET search_path TO ''
AS $function$
BEGIN
  IF EXISTS (
    SELECT 1 FROM public.airlinerra_game_worlds w
    WHERE w.id = NEW.world_id AND w.state IN ('registration_open','active')
  ) THEN
    RETURN NEW;
  END IF;

  IF NEW.world_id = 1 AND EXISTS (
    SELECT 1
    FROM public.airlinerra_game_worlds w
    JOIN auth.users u ON u.id = NEW.owner_player_id
    JOIN airlinerra_game.owner_premium_email_reservations r
      ON r.email = lower(btrim(u.email))
    JOIN airlinerra_game.owner_private_pilot_consents c
      ON c.player_id = u.id
      AND c.version = 'owner_private_pilot_20261028'
    WHERE w.id = 1
      AND w.state = 'planned'
      AND u.email_confirmed_at IS NOT NULL
      AND coalesce(u.is_anonymous,false) = false
      AND u.deleted_at IS NULL
      AND (u.banned_until IS NULL OR u.banned_until <= now())
  ) THEN
    RETURN NEW;
  END IF;

  RAISE EXCEPTION 'Airlinerra world is not open for airline registration'
    USING errcode = 'check_violation';
END;
$function$;
