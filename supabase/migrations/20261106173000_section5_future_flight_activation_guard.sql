
CREATE OR REPLACE FUNCTION airlinerra_game.section5_reject_prohibited_flight_v1(
 p_world_id smallint,p_origin_airport_key text,p_destination_airport_key text,
 p_configuration_id bigint,p_departure_utc timestamptz,p_arrival_utc timestamptz,
 p_origin_runway_id text DEFAULT NULL,p_destination_runway_id text DEFAULT NULL
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $function$
DECLARE verdict jsonb; decision text;
BEGIN
 verdict:=airlinerra_game.section5_universal_route_restriction_gate_v1(
  p_world_id,p_origin_airport_key,p_destination_airport_key,
  p_configuration_id,p_departure_utc,p_arrival_utc,
  p_origin_runway_id,p_destination_runway_id);
 IF verdict IS NULL OR (verdict->>'gameHardBlocked')::boolean IS DISTINCT FROM false THEN
  decision:=left(coalesce(verdict->>'decision','BLOCKED_INVALID_RESTRICTION_RESPONSE'),96);
  RAISE EXCEPTION USING ERRCODE='P0001',
   MESSAGE='AIRLINERRA_FLIGHT_BLOCKED_BY_AIRPORT_RULE',
   DETAIL=decision,
   HINT='Inspect airport rule checker; do not activate the flight.';
 END IF;
 RETURN verdict;
END;
$function$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section5_reject_prohibited_flight_v1(
 smallint,text,text,bigint,timestamptz,timestamptz,text,text) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section5_reject_prohibited_flight_v1(smallint,text,text,bigint,timestamptz,timestamptz,text,text) IS
'Guard for a future authenticated flight create/change transaction. Must be called within the same transaction; rejects confirmed airport/aircraft/runway/time game-rule violations. Review-only findings do not invent bans. No flight write paths currently call this guard.';
