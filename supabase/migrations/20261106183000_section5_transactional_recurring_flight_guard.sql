-- Private guard contract for future scheduling transactions. No live flight activation.
CREATE OR REPLACE FUNCTION airlinerra_game.section5_reject_prohibited_recurrence_v1(
 p_world_id smallint, p_origin_airport_key text, p_destination_airport_key text,
 p_configuration_id bigint, p_occurrences jsonb
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $function$
DECLARE verdict jsonb;
BEGIN
 verdict:=airlinerra_game.section5_batch_route_restriction_screen_v1(
   p_world_id,p_origin_airport_key,p_destination_airport_key,p_configuration_id,p_occurrences);
 IF verdict IS NULL OR (verdict->>'gameHardBlocked')::boolean IS DISTINCT FROM false
 THEN RAISE EXCEPTION USING ERRCODE='P0001',
   MESSAGE='AIRLINERRA_RECURRING_FLIGHT_BLOCKED_BY_AIRPORT_RULE',
   DETAIL=left(coalesce(verdict->>'decision','BLOCKED_INVALID_RESTRICTION_RESPONSE'),96);
 END IF;
 RETURN verdict;
END;
$function$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section5_reject_prohibited_recurrence_v1(smallint,text,text,bigint,jsonb)
FROM PUBLIC,anon,authenticated;
