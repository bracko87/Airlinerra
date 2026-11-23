-- 54-week Group 2 route safety preflight. Strictly READ ONLY.
-- Uses the Group 2 full-weight, slot snapshot, and conditional restriction functions
-- for BOTH origin and destination on EVERY occurrence. Not an admission gate.
CREATE OR REPLACE FUNCTION airlinerra_game.group2_combined_route_safety_preview_v1(
 p_origin_key text,p_destination_key text,p_configuration_id bigint,
 p_reference_departure_utc timestamptz,p_reference_arrival_utc timestamptz,
 p_weekly_schedule jsonb,p_departure_stand text,p_arrival_stand text
) RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $$
DECLARE ori record; dest record; monday date; duration interval;
 item record; w integer; day_idx integer; departure_local timestamp;
 departure_utc timestamptz; arrival_utc timestamptz;
 dep jsonb; arr jsonb; weekly jsonb;
 checked_count integer:=0; blocked_count integer:=0;
 review_count integer:=0; first_issue jsonb:=NULL; outcome text;
BEGIN
 IF p_origin_key IS NULL OR p_destination_key IS NULL
 OR p_origin_key=p_destination_key OR p_configuration_id IS NULL
 OR p_reference_departure_utc IS NULL OR p_reference_arrival_utc IS NULL
 OR p_reference_arrival_utc<=p_reference_departure_utc
 OR p_reference_arrival_utc-p_reference_departure_utc>interval '72 hours'
 OR p_departure_stand NOT IN ('terminal','remote','cargo')
 OR p_arrival_stand NOT IN ('terminal','remote','cargo')
 OR p_weekly_schedule IS NULL OR jsonb_typeof(p_weekly_schedule)<>'array'
 OR jsonb_array_length(p_weekly_schedule) NOT BETWEEN 1 AND 7
 THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_ROUTE_OR_TIMETABLE',
  'previewOnly',true,'canBook',false,'canDispatch',false);END IF;
 IF EXISTS(
  SELECT 1 FROM jsonb_array_elements(p_weekly_schedule) elem
  WHERE jsonb_typeof(elem)<>'object'
  OR (SELECT count(*) FROM jsonb_object_keys(elem))<>2
  OR NOT(elem ? 'day' AND elem ? 'time')
  OR elem->>'day' !~ '^[0-6]$'
  OR elem->>'time' !~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
 ) OR (SELECT count(*) FROM (SELECT DISTINCT (elem->>'day'),(elem->>'time')
  FROM jsonb_array_elements(p_weekly_schedule) elem) d)
 <>jsonb_array_length(p_weekly_schedule)
 THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_WEEKLY_ITEMS',
  'previewOnly',true,'canBook',false,'canDispatch',false);END IF;
 SELECT * INTO ori FROM airlinerra_game.section6_group2_slot_capacity_bridge_v1
 WHERE airport_key=p_origin_key AND world_id=1;
 SELECT * INTO dest FROM airlinerra_game.section6_group2_slot_capacity_bridge_v1
 WHERE airport_key=p_destination_key AND world_id=1;
 IF ori.airport_key IS NULL OR dest.airport_key IS NULL
 THEN RETURN jsonb_build_object('decision','BLOCKED_AIRPORT_NOT_IN_GROUP2_BRIDGE',
 'previewOnly',true,'canBook',false,'canDispatch',false);END IF;
 weekly:=airlinerra_game.group2_weekly_slot_route_preview_v1(
  p_origin_key,p_destination_key,p_reference_departure_utc,
  p_reference_arrival_utc,p_weekly_schedule,p_departure_stand,p_arrival_stand);
 IF coalesce(weekly->>'decision','') IN (
  'BLOCKED_INVALID_REQUEST','BLOCKED_INVALID_WEEKLY_TIMETABLE',
  'BLOCKED_NOT_TWO_GROUP2_PREPARED_AIRPORTS') THEN
  RETURN jsonb_build_object('decision','BLOCKED_WEEKLY_SLOT_INPUT',
    'weeklyCapacityPreview',weekly,'previewOnly',true,'canBook',false,'canDispatch',false);
 END IF;
 monday:=(p_reference_departure_utc AT TIME ZONE ori.timezone_iana)::date-
  (extract(isodow FROM p_reference_departure_utc AT TIME ZONE ori.timezone_iana)::int-1);
 duration:=p_reference_arrival_utc-p_reference_departure_utc;
 FOR item IN SELECT (e->>'day')::integer AS day_of_week,(e->>'time')::time AS local_time
             FROM jsonb_array_elements(p_weekly_schedule) e LOOP
  FOR w IN 0..53 LOOP
   departure_local:=(monday + item.day_of_week + 7*w)::timestamp+item.local_time;
   departure_utc:=departure_local AT TIME ZONE ori.timezone_iana;
   arrival_utc:=departure_utc+duration;
   dep:=airlinerra_game.group2_full_weight_slot_leg_preview_v1(
    p_origin_key,p_configuration_id,'departure',departure_utc,p_departure_stand);
   arr:=airlinerra_game.group2_full_weight_slot_leg_preview_v1(
    p_destination_key,p_configuration_id,'arrival',arrival_utc,p_arrival_stand);
   checked_count:=checked_count+1;
   IF (dep->>'decision') LIKE 'BLOCKED_%'
    OR (arr->>'decision') LIKE 'BLOCKED_%' THEN
    blocked_count:=blocked_count+1;
    IF first_issue IS NULL THEN first_issue:=jsonb_build_object(
      'departureUtc',departure_utc,'originDecision',dep->>'decision',
      'destinationDecision',arr->>'decision');END IF;
   ELSIF (dep->>'decision') LIKE 'REVIEW_%'
      OR (arr->>'decision') LIKE 'REVIEW_%' THEN
    review_count:=review_count+1;
    IF first_issue IS NULL THEN first_issue:=jsonb_build_object(
      'departureUtc',departure_utc,'originDecision',dep->>'decision',
      'destinationDecision',arr->>'decision');END IF;
   END IF;
  END LOOP;
 END LOOP;
 outcome:=CASE
  WHEN blocked_count>0 THEN 'BLOCKED_OCCURRENCE_RUNWAY_SLOT_OR_RESTRICTION'
  WHEN review_count>0 THEN 'REVIEW_REQUIRED_OCCURRENCE_RESTRICTION'
  WHEN weekly->>'decision'<>'PRELIMINARY_WEEKLY_GAME_CAPACITY_PASS_NOT_ADMITTED'
    THEN 'BLOCKED_WEEKLY_SLOT_CAPACITY'
  ELSE 'PRELIMINARY_ALL_OCCURRENCES_PASS_NOT_ADMITTED' END;
 RETURN jsonb_build_object(
   'modelVersion','GROUP2_COMBINED_ROUTE_SAFETY_PREVIEW_V1',
   'decision',outcome,'occurrencesChecked',checked_count,
   'blockedOccurrences',blocked_count,'reviewRequiredOccurrences',review_count,
   'firstIssue',first_issue,
   'weeklyCapacityPreview',weekly,'originAirportKey',p_origin_key,
   'destinationAirportKey',p_destination_key,'configurationId',p_configuration_id,
   'checksEveryOccurrence',true,'gameFullWeightModel',true,
   'conditionalRestrictionsChecked',true,
   'modeledSlotSnapshotChecked',true,'slotsWritten',false,
   'realFlightSchedulingEngineConnected',false,'movementGateConnected',false,
   'commercialAdmission',false,'canBook',false,'canDispatch',false,
   'canActivateHqOrOffice',false,'previewOnly',true
 );
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.group2_combined_route_safety_preview_v1(
 text,text,bigint,timestamptz,timestamptz,jsonb,text,text)
 FROM PUBLIC,anon,authenticated;
