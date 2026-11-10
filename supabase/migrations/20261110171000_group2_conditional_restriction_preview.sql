-- Group 2 conditional restriction evaluation. Read-only, never a dispatch authorization.
-- Airlinerra game-only defaults and sourced rules are NOT operational/legal permits.
CREATE OR REPLACE FUNCTION airlinerra_game.group2_airport_conditional_restriction_preview_v1(
 p_airport_key text,p_configuration_id bigint,p_operation text,p_time_utc timestamptz
) RETURNS jsonb
LANGUAGE plpgsql STABLE
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $$
DECLARE v record; n record; aircraft record; local_time timestamp; local_clock time;
 chapter text; decision text; reason text; is_lfpb boolean; is_lerl boolean;
BEGIN
 IF nullif(btrim(coalesce(p_airport_key,'')),'') IS NULL OR p_configuration_id IS NULL
 OR p_operation NOT IN ('departure','arrival') OR p_time_utc IS NULL
 THEN RETURN jsonb_build_object('decision','BLOCKED_INVALID_INPUT','previewOnly',true,
 'canBook',false,'canDispatch',false);END IF;
 SELECT * INTO v FROM airlinerra_game.airport_group2_engine_input_preview_v1
 WHERE airport_key=p_airport_key AND world_id=1;
 SELECT configuration_id,model_name INTO aircraft
 FROM airlinerra.aircraft_catalog_configuration_inventory
 WHERE configuration_id=p_configuration_id;
 IF v.airport_key IS NULL OR aircraft.configuration_id IS NULL
 THEN RETURN jsonb_build_object('decision','BLOCKED_UNKNOWN_AIRPORT_OR_AIRCRAFT',
 'previewOnly',true,'canBook',false,'canDispatch',false);END IF;
 SELECT icao_annex16_chapter,classification_basis INTO n
 FROM airlinerra_game.section5_aircraft_noise_profiles_v1
 WHERE configuration_id=p_configuration_id;
 chapter:=nullif(btrim(coalesce(n.icao_annex16_chapter,'')),'');
 local_time:=p_time_utc AT TIME ZONE v.timezone_iana;
 local_clock:=local_time::time;
 is_lfpb:=p_airport_key='OURAIRPORTS:4183';
 is_lerl:=p_airport_key='OURAIRPORTS:46583';
 IF is_lerl AND chapter IS NOT NULL AND chapter NOT IN ('3','4') THEN
   decision:='BLOCKED_DOCUMENTED_GAME_CHAPTER_RULE';
   reason:='Ciudad Real game rule: only ICAO Chapters 3 and 4 accepted';
 ELSIF is_lerl AND chapter IS NULL THEN
   decision:='REVIEW_REQUIRED_UNSOURCED_AIRCRAFT_CHAPTER';
   reason:='Ciudad Real chapter restriction cannot be decided from unsourced aircraft chapter';
 ELSIF is_lfpb AND p_operation='departure' AND
   (local_clock>=time '22:15' OR local_clock<time '06:00') THEN
   decision:='REVIEW_REQUIRED_CONDITIONAL_NIGHT_RESTRICTION';
   reason:='Paris-Le Bourget jet stand departure restriction 22:15-06:00; aircraft type and exceptions not yet machine-evaluated';
 ELSIF is_lfpb THEN
   decision:='REVIEW_REQUIRED_AIRCRAFT_TYPE_AND_NOISE';
   reason:='Paris-Le Bourget has aircraft-dependent arrival/prop and Chapter noise rules not fully machine-evaluated';
 ELSIF v.game_nighttime_ban OR v.game_noise_restrictions THEN
   decision:='REVIEW_REQUIRED_UNSTRUCTURED_RESTRICTION';
   reason:='Recorded airport restriction not yet converted to an enforceable rule';
 ELSE
   decision:='NO_KNOWN_GROUP2_GAME_RESTRICTION_CONFLICT';
   reason:='No recorded Group 2 game restriction conflict; airport remains unapproved for flight operation';
 END IF;
 RETURN jsonb_build_object(
  'modelVersion','GROUP2_CONDITIONAL_RESTRICTION_PREVIEW_V1',
  'airportKey',p_airport_key,'airportName',v.airport_name,'aircraftModel',aircraft.model_name,
  'configurationId',p_configuration_id,'aircraftSourcedIcaoChapter',chapter,
  'chapterSourceBasis',n.classification_basis,
  'operation',p_operation,'localAirportTime',to_char(local_time,'YYYY-MM-DD HH24:MI:SS'),
  'timezone',v.timezone_iana,
  'gameNighttimeRestriction',v.game_nighttime_ban,
  'gameNoiseRestriction',v.game_noise_restrictions,
  'sourceRuleOrigin',v.rule_origin,
  'decision',decision,'reason',reason,
  'conditionalRulesFullyEnforced',false,
  'fullWeightRunwayChecked',false,'liveSlotAvailabilityChecked',false,
  'canBook',false,'canDispatch',false,'canActivateOffice',false,
  'realWorldClearance',false,'previewOnly',true
 );
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.group2_airport_conditional_restriction_preview_v1(text,bigint,text,timestamptz)
FROM PUBLIC,anon,authenticated;
DO $$
DECLARE a jsonb; b jsonb; c jsonb; d jsonb;
BEGIN
 a:=airlinerra_game.group2_airport_conditional_restriction_preview_v1(
 'OURAIRPORTS:4183',194,'departure','2026-11-10T22:00:00Z');
 b:=airlinerra_game.group2_airport_conditional_restriction_preview_v1(
 'OURAIRPORTS:4183',194,'departure','2026-11-10T12:00:00Z');
 c:=airlinerra_game.group2_airport_conditional_restriction_preview_v1(
 'OURAIRPORTS:46583',239,'arrival','2026-11-10T12:00:00Z');
 d:=airlinerra_game.group2_airport_conditional_restriction_preview_v1(
 'OURAIRPORTS:46583',194,'arrival','2026-11-10T12:00:00Z');
 IF a->>'decision'<>'REVIEW_REQUIRED_CONDITIONAL_NIGHT_RESTRICTION'
 OR b->>'decision'<>'REVIEW_REQUIRED_AIRCRAFT_TYPE_AND_NOISE'
 OR c->>'decision'<>'BLOCKED_DOCUMENTED_GAME_CHAPTER_RULE'
 OR d->>'decision'='BLOCKED_DOCUMENTED_GAME_CHAPTER_RULE'
 OR a->>'canDispatch'<>'false' OR d->>'canBook'<>'false'
 THEN RAISE EXCEPTION 'GROUP2_CONDITIONAL_RULE_PREVIEW_POSTCHECK_FAILED';END IF;
END $$;