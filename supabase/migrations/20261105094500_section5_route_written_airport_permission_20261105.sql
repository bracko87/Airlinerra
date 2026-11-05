-- Follow-up to installed Section 5 route gate: FAA-documented written airport permission checks.
CREATE OR REPLACE FUNCTION airlinerra_game.section5_timed_route_schedule_gate_v1(p_world_id smallint, p_origin_airport_key text, p_destination_airport_key text, p_configuration_id bigint, p_departure_utc timestamp with time zone, p_arrival_utc timestamp with time zone)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 d jsonb;
 a jsonb;
 r jsonb;
 origin_curfew text;
 destination_curfew text;
 runway_ok boolean;
 hard_block boolean;
 special_review boolean;
 written_permission_review boolean;
 research_pending boolean;
 source_estimated boolean;
 decision text;
BEGIN
 IF p_world_id IS NULL OR p_origin_airport_key IS NULL OR p_destination_airport_key IS NULL
  OR p_configuration_id IS NULL OR p_departure_utc IS NULL OR p_arrival_utc IS NULL
  OR p_origin_airport_key = p_destination_airport_key
  OR p_arrival_utc <= p_departure_utc OR p_arrival_utc > p_departure_utc + interval '72 hours'
 THEN
  RETURN jsonb_build_object('decision','BLOCKED_INVALID_ROUTE_OR_TIME','canActivateNormalFlight',false,'legalRealWorldClearance',false);
 END IF;

 SELECT to_jsonb(x) INTO d
 FROM airlinerra_game.section5_game_airport_noise_curfew_check_v3(
 p_world_id,p_origin_airport_key,p_configuration_id,'departure',p_departure_utc) x;
 SELECT to_jsonb(x) INTO a
 FROM airlinerra_game.section5_game_airport_noise_curfew_check_v3(
 p_world_id,p_destination_airport_key,p_configuration_id,'arrival',p_arrival_utc) x;
 SELECT to_jsonb(x) INTO r
 FROM airlinerra_game.section5_full_weight_route_runway_check_v2(
 p_world_id,p_origin_airport_key,p_destination_airport_key,p_configuration_id) x;
 IF d IS NULL OR a IS NULL OR r IS NULL THEN
  RETURN jsonb_build_object('decision','BLOCKED_UNRESOLVED_AIRPORT_AIRCRAFT_OR_RUNWAY',
  'canActivateNormalFlight',false,'legalRealWorldClearance',false);
 END IF;

 runway_ok:=COALESCE((r->>'full_weight_one_way_length_screen_pass')::boolean,false);
 hard_block:=COALESCE((d->>'denied_by_documented_curfew')::boolean,false)
  OR COALESCE((a->>'denied_by_documented_curfew')::boolean,false)
  OR COALESCE((d->>'denied_by_game_chapter_rule')::boolean,false)
  OR COALESCE((a->>'denied_by_game_chapter_rule')::boolean,false);
 written_permission_review:=EXISTS (
  SELECT 1 FROM airlinerra_game.section5_airport_operational_rule_evidence_v1 permission
  JOIN airlinerra.aircraft_catalog_configuration_inventory aircraft
    ON aircraft.configuration_id=p_configuration_id
  WHERE permission.world_id=p_world_id
    AND permission.airport_key IN (p_origin_airport_key,p_destination_airport_key)
    AND permission.applies_to='commercial_air_carrier'
    AND permission.permission_kind='PRIOR_WRITTEN_PERMISSION'
    AND permission.operational_effect='REQUIRES_PERMISSION_NOT_AUTOMATICALLY_APPROVED'
    AND aircraft.maximum_passenger_seats>permission.passenger_seats_threshold
 );
 special_review:=COALESCE((d->>'requires_special_noise_or_slot_review')::boolean,false)
  OR COALESCE((a->>'requires_special_noise_or_slot_review')::boolean,false);
 SELECT evidence_status INTO origin_curfew
 FROM airlinerra_game.section5_airport_curfew_research_audit_v2
 WHERE world_id=p_world_id AND airport_key=p_origin_airport_key;
 SELECT evidence_status INTO destination_curfew
 FROM airlinerra_game.section5_airport_curfew_research_audit_v2
 WHERE world_id=p_world_id AND airport_key=p_destination_airport_key;
 research_pending:=
  COALESCE(origin_curfew,'NOT_INDIVIDUALLY_VERIFIED')='NOT_INDIVIDUALLY_VERIFIED'
  OR COALESCE(destination_curfew,'NOT_INDIVIDUALLY_VERIFIED')='NOT_INDIVIDUALLY_VERIFIED'
  OR COALESCE(d->>'airport_chapter_evidence_status','NOT_INDIVIDUALLY_VERIFIED')='NOT_INDIVIDUALLY_VERIFIED'
  OR COALESCE(a->>'airport_chapter_evidence_status','NOT_INDIVIDUALLY_VERIFIED')='NOT_INDIVIDUALLY_VERIFIED';
 source_estimated:= d->>'official_icao_chapter' IS NULL OR a->>'official_icao_chapter' IS NULL;

 decision:=CASE
  WHEN NOT runway_ok THEN 'BLOCKED_FULL_WEIGHT_RUNWAY_SCREEN'
  WHEN hard_block THEN 'BLOCKED_NOISE_CHAPTER_OR_DOCUMENTED_CURFEW'
  WHEN special_review THEN 'SPECIAL_PERMISSION_OR_SLOT_REVIEW_REQUIRED'
  WHEN written_permission_review THEN 'SPECIAL_WRITTEN_AIRPORT_PERMISSION_REVIEW_REQUIRED'
  WHEN research_pending OR source_estimated THEN 'PRELIMINARY_ALLOW_WITH_UNVERIFIED_NOISE_OR_AIRPORT_RULES'
  ELSE 'PRELIMINARY_ALLOW_SOURCE_REVIEWED'
 END;
 RETURN jsonb_build_object(
 'modelVersion','SECTION5_TIMED_ROUTE_SCHEDULE_GATE_V1',
 'decision',decision,
 'canActivateNormalFlight',false,
 'normalFlightNeedsOtherDispatchChecks',true,
 'legalRealWorldClearance',false,
 'runwayFullWeightScreenPass',runway_ok,
 'runwayGameResult',r->>'game_screening_result',
 'originCode',d->>'airport_code',
 'destinationCode',a->>'airport_code',
 'aircraftModel',d->>'aircraft_model',
 'selectedEngine',d->>'selected_engine',
 'gameIcaoChapter',(d->>'game_icao_chapter')::smallint,
 'aircraftChapterSourceEstimated',source_estimated,
 'originLocalTime',d->>'local_airport_time',
 'destinationLocalTime',a->>'local_airport_time',
 'originNoiseOutcome',d->>'game_schedule_outcome',
 'destinationNoiseOutcome',a->>'game_schedule_outcome',
 'originCurfewResearch',COALESCE(origin_curfew,'NOT_INDIVIDUALLY_VERIFIED'),
 'destinationCurfewResearch',COALESCE(destination_curfew,'NOT_INDIVIDUALLY_VERIFIED'),
 'originChapterResearch',d->>'airport_chapter_evidence_status',
 'destinationChapterResearch',a->>'airport_chapter_evidence_status',
 'airportResearchPending',research_pending,
 'documentedCurfewOrGameChapterBlocked',hard_block,
 'requiresSpecialNoiseOrSlotReview',special_review,
 'requiresSpecialWrittenAirportPermissionReview',written_permission_review
 );
END;
$function$
;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section5_timed_route_schedule_gate_v1(smallint,text,text,bigint,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section5_timed_route_schedule_gate_v1(smallint,text,text,bigint,timestamptz,timestamptz) IS 'Combined game-only screening of curfews, noise chapters, runway length and larger-air-carrier written airport permission. Never releases or activates an actual flight.';