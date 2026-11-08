-- Section 5: apply simplified AirlineSim game rules in the existing server-side
-- route and weekly schedule-draft preflight. Preserve mandatory official rules.
-- This migration does not activate flights or weaken existing RLS/ownership checks.

CREATE OR REPLACE FUNCTION airlinerra_game.section5_simplified_airport_leg_screen_v1(
 p_world_id smallint, p_airport_key text, p_configuration_id bigint,
 p_operation text, p_time_utc timestamptz
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path = 'pg_catalog'
AS $body$
DECLARE
 r record; parts text[]; lower_time time; upper_time time;
 local_dt timestamp; block_night boolean:=false; block_noise boolean:=false;
 night_review boolean:=false; certificate_review boolean:=false;
 certified_chapter smallint; certification_matched boolean:=false;
 permitted boolean:=false;
BEGIN
 IF p_world_id IS NULL OR p_airport_key IS NULL OR p_configuration_id IS NULL
  OR p_time_utc IS NULL OR p_operation NOT IN ('departure','arrival') THEN
  RETURN jsonb_build_object('gameHardBlocked',true,'needsReview',false,
    'reason','INVALID_SIMPLIFIED_SCREEN_INPUT');
 END IF;

 SELECT g.nighttime_ban,g.noise_restrictions,g.permitted_noise_chapters,
        g.simplified_nighttime_window,g.source_status,p.timezone_iana
 INTO r FROM airlinerra_game.section5_airport_simplified_game_rules_v1 g
 JOIN airlinerra_game.section5_airport_operating_policy_v1 p
   ON p.world_id=g.world_id AND p.airport_key=g.airport_key
 WHERE g.world_id=p_world_id AND g.airport_key=p_airport_key;
 IF NOT FOUND OR r.timezone_iana IS NULL THEN
  RETURN jsonb_build_object('gameHardBlocked',false,'needsReview',true,
    'reason','SIMPLIFIED_AIRPORT_RULES_OR_TIMEZONE_UNAVAILABLE');
 END IF;

 local_dt := p_time_utc AT TIME ZONE r.timezone_iana;

 IF r.nighttime_ban THEN
  -- AirlineSim standard "0:01 and 5:59", plus exact 24-hour-window notations.
  IF r.simplified_nighttime_window ~ '^[0-9]{1,2}:[0-9]{2} and [0-9]{1,2}:[0-9]{2}$' THEN
   parts:=regexp_match(r.simplified_nighttime_window,
     '^([0-9]{1,2}:[0-9]{2}) and ([0-9]{1,2}:[0-9]{2})$');
  ELSIF r.simplified_nighttime_window ~ '^[0-9]{1,2}:[0-9]{2}-[0-9]{1,2}:[0-9]{2}$' THEN
   parts:=regexp_match(r.simplified_nighttime_window,
     '^([0-9]{1,2}:[0-9]{2})-([0-9]{1,2}:[0-9]{2})$');
  ELSIF r.simplified_nighttime_window =
    'Scheduled departures 23:00-06:00; arrivals 00:00-05:00 (local)' THEN
   parts:=CASE WHEN p_operation='departure'
       THEN ARRAY['23:00','06:00']::text[]
       ELSE ARRAY['00:00','05:00']::text[] END;
  END IF;

  IF parts IS NOT NULL AND cardinality(parts)=2 THEN
   lower_time:=parts[1]::time;
   upper_time:=parts[2]::time;
   block_night:=CASE WHEN lower_time<=upper_time
    THEN local_dt::time BETWEEN lower_time AND upper_time
    ELSE local_dt::time>=lower_time OR local_dt::time<=upper_time END;
  ELSE
   -- Variable daylight windows cannot be turned into an invented fixed curfew.
   night_review:=true;
  END IF;
 END IF;

 IF r.noise_restrictions THEN
  SELECT c.official_icao_chapter,
         c.noise_certificate_status='CERTIFICATE_CONFIGURATION_MATCHED'
  INTO certified_chapter,certification_matched
  FROM airlinerra_game.section5_icao_aircraft_certification_v2 c
  WHERE c.configuration_id=p_configuration_id;
  certification_matched:=coalesce(certification_matched,false);
  IF NOT certification_matched OR certified_chapter IS NULL THEN
   certificate_review:=true;
  ELSE
   -- Chapter 14 is quieter than Chapter 4 and is not rejected by a 3/4 floor.
   permitted := certified_chapter=ANY(r.permitted_noise_chapters)
     OR (certified_chapter=14 AND 4=ANY(r.permitted_noise_chapters));
   block_noise:=NOT permitted;
  END IF;
 END IF;

 RETURN jsonb_build_object(
   'modelVersion','SECTION5_SIMPLIFIED_GAME_LEG_V1',
   'nighttimeBan',r.nighttime_ban,
   'noiseRestrictions',r.noise_restrictions,
   'permittedNoiseChapters',r.permitted_noise_chapters,
   'sourceStatus',r.source_status,
   'nighttimeWindow',r.simplified_nighttime_window,
   'localAirportTime',local_dt,
   'configurationMatchedIcaoChapter',
       CASE WHEN certification_matched THEN certified_chapter ELSE NULL END,
   'blockedBySimplifiedNighttimeBan',block_night,
   'blockedBySimplifiedNoiseChapter',block_noise,
   'nighttimeWindowNeedsReview',night_review,
   'noiseCertificateNeedsReview',certificate_review,
   'gameHardBlocked',block_night OR block_noise,
   'needsReview',night_review OR certificate_review,
   'realWorldDispatchApproved',false
 );
END;
$body$;

REVOKE ALL ON FUNCTION airlinerra_game.section5_simplified_airport_leg_screen_v1(
 smallint,text,bigint,text,timestamptz) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section5_universal_route_restriction_gate_v1(
 p_world_id smallint, p_origin_airport_key text, p_destination_airport_key text,
 p_configuration_id bigint, p_departure_utc timestamptz, p_arrival_utc timestamptz,
 p_origin_source_runway_id text DEFAULT NULL::text,
 p_destination_source_runway_id text DEFAULT NULL::text
) RETURNS jsonb
LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $body$
DECLARE
 dep jsonb; arr jsonb; dep_simple jsonb; arr_simple jsonb;
 blocked boolean; review boolean; code text;
 dep_base_blocked boolean; arr_base_blocked boolean;
BEGIN
 IF p_world_id IS NULL OR p_origin_airport_key IS NULL OR p_destination_airport_key IS NULL
    OR p_origin_airport_key=p_destination_airport_key OR p_configuration_id IS NULL
    OR p_departure_utc IS NULL OR p_arrival_utc IS NULL
    OR p_arrival_utc<=p_departure_utc
    OR p_arrival_utc>p_departure_utc+interval '72 hours'
 THEN RETURN jsonb_build_object('modelVersion','SECTION5_UNIVERSAL_ROUTE_GATE_V1',
   'decision','BLOCKED_INVALID_ROUTE_OR_TIME','gameHardBlocked',true,
   'canActivateNormalFlight',false,'realWorldDispatchApproved',false);
 END IF;

 dep:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
    p_world_id,p_origin_airport_key,p_configuration_id,'departure',
    p_departure_utc,p_origin_source_runway_id);
 arr:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
    p_world_id,p_destination_airport_key,p_configuration_id,'arrival',
    p_arrival_utc,p_destination_source_runway_id);
 dep_simple:=airlinerra_game.section5_simplified_airport_leg_screen_v1(
    p_world_id,p_origin_airport_key,p_configuration_id,'departure',p_departure_utc);
 arr_simple:=airlinerra_game.section5_simplified_airport_leg_screen_v1(
    p_world_id,p_destination_airport_key,p_configuration_id,'arrival',p_arrival_utc);

 dep_base_blocked:=coalesce((dep->>'gameHardBlocked')::boolean,true);
 arr_base_blocked:=coalesce((arr->>'gameHardBlocked')::boolean,true);

 dep:=dep||jsonb_build_object(
   'simpleNightNoise',dep_simple,
   'blockedBySimplifiedNighttimeBan',coalesce((dep_simple->>'blockedBySimplifiedNighttimeBan')::boolean,false),
   'blockedBySimplifiedNoiseChapter',coalesce((dep_simple->>'blockedBySimplifiedNoiseChapter')::boolean,false),
   'blockedByAirportTimeRule',coalesce((dep->>'blockedByAirportTimeRule')::boolean,false)
     OR coalesce((dep_simple->>'blockedBySimplifiedNighttimeBan')::boolean,false),
   'blockedByVerifiedNoiseRule',coalesce((dep->>'blockedByVerifiedNoiseRule')::boolean,false)
     OR coalesce((dep_simple->>'blockedBySimplifiedNoiseChapter')::boolean,false),
   'gameHardBlocked',dep_base_blocked OR coalesce((dep_simple->>'gameHardBlocked')::boolean,false),
   'needsReview',coalesce((dep->>'needsReview')::boolean,true)
     OR coalesce((dep_simple->>'needsReview')::boolean,true),
   'decision',CASE
     WHEN dep_base_blocked THEN dep->>'decision'
     WHEN coalesce((dep_simple->>'blockedBySimplifiedNighttimeBan')::boolean,false)
       THEN 'BLOCKED_GAME_SIMPLIFIED_NIGHTTIME_BAN'
     WHEN coalesce((dep_simple->>'blockedBySimplifiedNoiseChapter')::boolean,false)
       THEN 'BLOCKED_GAME_SIMPLIFIED_CERTIFIED_NOISE_CHAPTER'
     WHEN coalesce((dep_simple->>'needsReview')::boolean,false)
       THEN 'REVIEW_REQUIRED_SIMPLIFIED_AIRPORT_RULE'
     ELSE dep->>'decision' END
 );

 arr:=arr||jsonb_build_object(
   'simpleNightNoise',arr_simple,
   'blockedBySimplifiedNighttimeBan',coalesce((arr_simple->>'blockedBySimplifiedNighttimeBan')::boolean,false),
   'blockedBySimplifiedNoiseChapter',coalesce((arr_simple->>'blockedBySimplifiedNoiseChapter')::boolean,false),
   'blockedByAirportTimeRule',coalesce((arr->>'blockedByAirportTimeRule')::boolean,false)
     OR coalesce((arr_simple->>'blockedBySimplifiedNighttimeBan')::boolean,false),
   'blockedByVerifiedNoiseRule',coalesce((arr->>'blockedByVerifiedNoiseRule')::boolean,false)
     OR coalesce((arr_simple->>'blockedBySimplifiedNoiseChapter')::boolean,false),
   'gameHardBlocked',arr_base_blocked OR coalesce((arr_simple->>'gameHardBlocked')::boolean,false),
   'needsReview',coalesce((arr->>'needsReview')::boolean,true)
     OR coalesce((arr_simple->>'needsReview')::boolean,true),
   'decision',CASE
     WHEN arr_base_blocked THEN arr->>'decision'
     WHEN coalesce((arr_simple->>'blockedBySimplifiedNighttimeBan')::boolean,false)
       THEN 'BLOCKED_GAME_SIMPLIFIED_NIGHTTIME_BAN'
     WHEN coalesce((arr_simple->>'blockedBySimplifiedNoiseChapter')::boolean,false)
       THEN 'BLOCKED_GAME_SIMPLIFIED_CERTIFIED_NOISE_CHAPTER'
     WHEN coalesce((arr_simple->>'needsReview')::boolean,false)
       THEN 'REVIEW_REQUIRED_SIMPLIFIED_AIRPORT_RULE'
     ELSE arr->>'decision' END
 );

 blocked:=coalesce((dep->>'gameHardBlocked')::boolean,true)
       OR coalesce((arr->>'gameHardBlocked')::boolean,true);
 review:=coalesce((dep->>'needsReview')::boolean,true)
       OR coalesce((arr->>'needsReview')::boolean,true);
 code:=CASE WHEN blocked THEN 'BLOCKED_BY_GAME_AIRPORT_RUNWAY_OR_NOISE_RESTRICTION'
       WHEN review THEN 'REVIEW_REQUIRED_GAME_RESTRICTION_SCREEN'
       ELSE 'PRELIMINARY_ALLOW_GAME_RESTRICTION_SCREEN' END;
 RETURN jsonb_build_object(
    'modelVersion','SECTION5_UNIVERSAL_ROUTE_GATE_V1','decision',code,
    'origin',dep,'destination',arr,
    'aircraftConfigurationId',p_configuration_id,
    'gameHardBlocked',blocked,'needsReview',review,
    'gamePreliminaryAllow',NOT blocked,
    'canActivateNormalFlight',false,
    'realWorldDispatchApproved',false,
    'activationBlockedUntilOtherFlightSystemsExist',true
 );
END;
$body$;
