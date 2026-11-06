CREATE OR REPLACE FUNCTION airlinerra_game.section5_batch_route_restriction_screen_v1(
 p_world_id smallint,p_origin_airport_key text,p_destination_airport_key text,
 p_configuration_id bigint,p_occurrences jsonb
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $function$
DECLARE
 item jsonb; gate jsonb; legs jsonb:='[]'::jsonb;
 hard boolean:=false; review boolean:=false; prior_departure timestamptz:=NULL;
 current_departure timestamptz; current_arrival timestamptz;
 idx integer:=0; n integer; denial text;
BEGIN
 IF p_occurrences IS NULL OR jsonb_typeof(p_occurrences)<>'array'
 THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_OCCURRENCES','gameHardBlocked',true,
 'needsReview',false,'canActivateNormalFlight',false);
 END IF;
 n:=jsonb_array_length(p_occurrences);
 IF n<1 OR n>32
 THEN RETURN jsonb_build_object('decision','BLOCKED_OCCURRENCE_BATCH_SIZE','gameHardBlocked',true,
  'needsReview',false,'canActivateNormalFlight',false,'limit',32);
 END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p_occurrences)
 LOOP
  idx:=idx+1;
  IF jsonb_typeof(item)<>'object'
    OR jsonb_typeof(item->'departureUtc')<>'string'
    OR jsonb_typeof(item->'arrivalUtc')<>'string'
    OR (item ? 'originRunwaySourceId' AND jsonb_typeof(item->'originRunwaySourceId') NOT IN('string','null'))
    OR (item ? 'destinationRunwaySourceId' AND jsonb_typeof(item->'destinationRunwaySourceId') NOT IN('string','null'))
  THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_OCCURRENCE_INPUT','gameHardBlocked',true,
   'needsReview',false,'canActivateNormalFlight',false,'invalidIndex',idx); END IF;
  BEGIN
   current_departure:=(item->>'departureUtc')::timestamptz;
   current_arrival:=(item->>'arrivalUtc')::timestamptz;
  EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR invalid_parameter_value THEN
   RETURN jsonb_build_object('decision','BLOCKED_INVALID_OCCURRENCE_TIME','gameHardBlocked',true,
   'needsReview',false,'canActivateNormalFlight',false,'invalidIndex',idx);
  END;
  IF current_departure IS NULL OR current_arrival IS NULL
     OR (prior_departure IS NOT NULL AND current_departure<=prior_departure)
     OR current_arrival<=current_departure
  THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_OCCURRENCE_ORDER','gameHardBlocked',true,
   'needsReview',false,'canActivateNormalFlight',false,'invalidIndex',idx); END IF;
  gate:=airlinerra_game.section5_universal_route_restriction_gate_v1(
    p_world_id,p_origin_airport_key,p_destination_airport_key,p_configuration_id,
    current_departure,current_arrival,
    NULLIF(item->>'originRunwaySourceId',''),NULLIF(item->>'destinationRunwaySourceId',''));
  hard:=hard OR coalesce((gate->>'gameHardBlocked')::boolean,true);
  review:=review OR coalesce((gate->>'needsReview')::boolean,true);
  legs:=legs || jsonb_build_array(jsonb_build_object(
    'index',idx,'departureUtc',current_departure,'arrivalUtc',current_arrival,
    'decision',gate->>'decision',
    'gameHardBlocked',coalesce((gate->>'gameHardBlocked')::boolean,true),
    'needsReview',coalesce((gate->>'needsReview')::boolean,true),
    'origin',gate->'origin','destination',gate->'destination'
   ));
  prior_departure:=current_departure;
 END LOOP;
 RETURN jsonb_build_object(
  'modelVersion','SECTION5_BATCH_ROUTE_RESTRICTION_V1',
  'decision',CASE WHEN hard THEN 'BLOCKED_RECURRING_ROUTE_OCCURRENCE'
   WHEN review THEN 'REVIEW_REQUIRED_RECURRING_ROUTE_OCCURRENCE'
   ELSE 'PRELIMINARY_ALLOW_RECURRING_ROUTE_OCCURRENCES' END,
  'aircraftConfigurationId',p_configuration_id,
  'occurrenceCount',n,'occurrences',legs,
  'gameHardBlocked',hard,'needsReview',review,
  'gamePreliminaryAllow',NOT hard,
  'canActivateNormalFlight',false,
  'requiresReevaluationForFutureOccurrences',true,
  'realWorldDispatchApproved',false
 );
END;
$function$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section5_batch_route_restriction_screen_v1(
smallint,text,text,bigint,jsonb) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section5_batch_route_restriction_screen_v1(smallint,text,text,bigint,jsonb)
IS 'Server-only game restriction screen for up to 32 explicitly UTC scheduled occurrences, all checked independently against local airport curfews and noise/runway rules. Never authorizes flight activation.';
