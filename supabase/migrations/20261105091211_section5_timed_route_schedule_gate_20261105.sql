-- Recorded from the applied 2026-11-05 Airlinerra Supabase migration.
-- Game screening is not real-world dispatch permission.
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
 'requiresSpecialNoiseOrSlotReview',special_review
 );
END;
$function$
;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section5_timed_route_schedule_gate_v1(
 smallint,text,text,bigint,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section5_timed_route_schedule_gate_v1(
 smallint,text,text,bigint,timestamptz,timestamptz)
IS 'Combined two-endpoint game schedule validation. This is not a flight activation/dispatch approval. UNVERIFIED does not mean no restrictions. Used by authenticated server API.';
