-- ROLLBACK-ONLY REVIEW. Crew candidate evaluation only, not reservations.
-- Reuse the existing rolling input, actual history, and duty-fit policy.
BEGIN;
CREATE FUNCTION airlinerra_game.aircraft_storage_crew_candidate_fit_v1(p_member jsonb,p_rotation jsonb,p_group text,p_role text)
RETURNS boolean LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE hist jsonb; fit jsonb; s timestamptz;e timestamptz;zone text; day1 date;day2 date;peak numeric;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_role NOT IN('captain','first_officer','cabin') OR p_rotation->>'status' IS DISTINCT FROM 'rotation_preview' OR jsonb_typeof(p_member->'history') IS DISTINCT FROM 'array' OR jsonb_typeof(p_member->'absences') IS DISTINCT FROM 'array' THEN RETURN false;END IF;
 s:=(p_rotation->>'dutyStartUtc')::timestamptz;e:=(p_rotation->>'dutyEndUtc')::timestamptz;zone:=p_member->>'baseTimezone';
 IF s IS NULL OR e IS NULL OR NOT isfinite(s) OR NOT isfinite(e) OR e<=s OR e-s>interval '12 hours' OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=zone) THEN RETURN false;END IF;
 day1:=(s AT TIME ZONE zone)::date;day2:=(e AT TIME ZONE zone)::date;
 IF (p_member->>'employmentFrom')::date IS NULL OR (p_member->>'employmentFrom')::date>day1 OR (p_member->>'locationEffectiveUtc')::timestamptz IS NULL OR (p_member->>'locationEffectiveUtc')::timestamptz>s OR nullif(btrim(p_member->>'initialAirport'),'') IS NULL THEN RETURN false;END IF;
 IF p_role='cabin' THEN
  IF p_member->>'role' IS NULL OR p_member->>'role' NOT IN('flight_attendant','cabin_supervisor','purser') THEN RETURN false;END IF;
 ELSE
  IF jsonb_typeof(p_member->'permissions') IS DISTINCT FROM 'array' OR NOT EXISTS(SELECT 1 FROM jsonb_array_elements(p_member->'permissions') a(v) WHERE v->>'group'=p_group AND v->>'active'='true' AND v->>(CASE WHEN p_role='captain' THEN 'captain' ELSE 'firstOfficer' END)='true' AND (v->>'issued')::date<=day1 AND (v->>'expires')::date>day2) THEN RETURN false;END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_member->'absences') a(v) WHERE (v->>'startUtc')::timestamptz IS NULL OR (v->>'endUtc')::timestamptz IS NULL OR (v->>'endUtc')::timestamptz<=(v->>'startUtc')::timestamptz OR ((v->>'startUtc')::timestamptz<e AND (v->>'endUtc')::timestamptz>s)) THEN RETURN false;END IF;
 -- Actual history uses startUtc/endUtc/origin/destination, not rotation keys.
 SELECT coalesce(jsonb_agg(jsonb_build_object('dutyStartUtc',v->'startUtc','dutyEndUtc',v->'endUtc','startingAirport',v->'origin','endingAirport',v->'destination') ORDER BY (v->>'startUtc')::timestamptz),'[]'::jsonb) INTO hist FROM jsonb_array_elements(p_member->'history') a(v);
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(hist) a(v) WHERE (v->>'dutyStartUtc')::timestamptz IS NULL OR (v->>'dutyEndUtc')::timestamptz IS NULL OR (v->>'dutyStartUtc')::timestamptz<(p_member->>'locationEffectiveUtc')::timestamptz OR (v->>'dutyEndUtc')::timestamptz>s) THEN RETURN false;END IF;
 fit:=airlinerra_game.section9_crew_duty_fit_v2(p_rotation,hist,zone,p_member->>'initialAirport');
 IF fit->>'eligible' IS DISTINCT FROM 'true' THEN RETURN false;END IF;
 -- Enforce 60 hours in every rolling 168-hour window intersecting new duty.
 -- The overlap sum is piecewise linear; extrema occur at duty start or end
 -- shifted by the window length, or at the intersecting-window boundaries.
 WITH duties AS (
 SELECT (v->>'dutyStartUtc')::timestamptz ds,(v->>'dutyEndUtc')::timestamptz de FROM jsonb_array_elements(hist||jsonb_build_array(p_rotation)) a(v)
 ), starts AS (
 SELECT ds AS w FROM duties UNION SELECT de-interval '168 hours' FROM duties UNION SELECT s-interval '168 hours' UNION SELECT e
 ), totals AS (
 SELECT w,sum(greatest(0,extract(epoch FROM least(d.de,w+interval '168 hours')-greatest(d.ds,w))))/3600 hours
 FROM starts CROSS JOIN duties d WHERE w<=e AND w+interval '168 hours'>=s GROUP BY w
 )
 SELECT coalesce(max(hours),0) INTO peak FROM totals;
 RETURN peak<=60;
EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR invalid_text_representation OR invalid_parameter_value THEN RETURN false;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.aircraft_storage_crew_candidate_fit_v1(jsonb,jsonb,text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.owned_aircraft_storage_crew_candidates_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE ctx jsonb;q jsonb;req jsonb;inp jsonb;rot jsonb;group_key text;ds timestamptz;now_utc timestamptz;captains uuid[];officers uuid[];cabin uuid[];need_c int;need_f int;need_a int;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 ctx:=airlinerra_game.owned_aircraft_storage_planning_context_v1(p_player,p_airline,p_aircraft,p_purpose);
 IF ctx->>'status' IS DISTINCT FROM 'storage_planning_ready' THEN RETURN jsonb_build_object('status',ctx->>'status','crewReserved',false);END IF;
 q:=airlinerra_game.owned_aircraft_storage_cost_preview_v1(p_player,p_airline,p_aircraft,p_purpose,p_destination,p_departure);
 IF q->>'status' IS DISTINCT FROM 'storage_cost_preview_verified' THEN RETURN jsonb_build_object('status',q->>'status','crewReserved',false);END IF;
 req:=airlinerra_game.aircraft_storage_crew_requirements_v1((ctx->>'configurationId')::bigint,q->>'originAirportKey',p_destination,p_departure,(q->>'arrivalUtc')::timestamptz);
 IF req->>'requirementsVerified' IS DISTINCT FROM 'true' THEN RETURN req||jsonb_build_object('status','storage_crew_requirements_blocked','crewReserved',false);END IF;
 rot:=req->'rotation';group_key:=req->>'qualificationGroup';ds:=(rot->>'dutyStartUtc')::timestamptz;now_utc:=(ctx->>'serverNowUtc')::timestamptz;
 need_c:=(req->>'captainsRequired')::int;need_f:=(req->>'firstOfficersRequired')::int;need_a:=(req->>'minimumCabinCrew')::int;
 inp:=airlinerra_game.section9_owned_rolling_crew_input_v1(p_player,p_airline,now_utc);
 IF inp->>'status' IS DISTINCT FROM 'rolling_crew_input_preview' OR inp->>'unboundDeparturesLast7Days' IS DISTINCT FROM '0' OR inp->>'unresolvedCaptureIssues' IS DISTINCT FROM '0' OR inp->>'invalidOccurrenceCount' IS DISTINCT FROM '0' OR inp->>'alreadyReportedFutureFlights' IS DISTINCT FROM '0' OR jsonb_typeof(inp->'pilots') IS DISTINCT FROM 'array' OR jsonb_typeof(inp->'cabinMembers') IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('status','storage_crew_history_unverified','crewReserved',false);END IF;
 -- Conservative exclusion: do not move a crew member away from ANY existing
 -- future validated commercial duty. Full multi-flight replanning is separate.
 WITH eligible AS (
 SELECT (v->>'id')::uuid id,
 airlinerra_game.aircraft_storage_crew_candidate_fit_v1(v,rot,group_key,'captain') c,
 airlinerra_game.aircraft_storage_crew_candidate_fit_v1(v,rot,group_key,'first_officer') f
 FROM jsonb_array_elements(inp->'pilots') a(v)
 WHERE NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_duties_v1 pd JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pd.plan_id AND b.airline_id=pd.airline_id AND b.status='validated_preview' WHERE pd.airline_id=p_airline AND pd.employee_id=(v->>'id')::uuid AND pd.duty_end_utc>now_utc)
 ), f AS (
 SELECT DISTINCT id,c FROM eligible WHERE f ORDER BY c,id LIMIT need_f
 ), c AS (
 SELECT DISTINCT id FROM eligible WHERE c AND id NOT IN(SELECT id FROM f) ORDER BY id LIMIT need_c
 )
 SELECT ARRAY(SELECT id FROM c ORDER BY id),ARRAY(SELECT id FROM f ORDER BY id) INTO captains,officers;
 SELECT ARRAY(SELECT DISTINCT (v->>'id')::uuid FROM jsonb_array_elements(inp->'cabinMembers') a(v)
 WHERE (v->>'id')::uuid<>ALL(captains||officers) AND airlinerra_game.aircraft_storage_crew_candidate_fit_v1(v,rot,group_key,'cabin')
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_duties_v1 pd JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pd.plan_id AND b.airline_id=pd.airline_id AND b.status='validated_preview' WHERE pd.airline_id=p_airline AND pd.employee_id=(v->>'id')::uuid AND pd.duty_end_utc>now_utc)
 ORDER BY 1 LIMIT need_a) INTO cabin;
 RETURN req||jsonb_build_object('status',CASE WHEN cardinality(captains)=need_c AND cardinality(officers)=need_f AND cardinality(cabin)=need_a THEN 'storage_crew_candidates_found' ELSE 'storage_crew_candidates_insufficient' END,
 'candidateCaptains',to_jsonb(captains),'candidateFirstOfficers',to_jsonb(officers),'candidateCabinCrew',to_jsonb(cabin),'crewReserved',false,'dispatchAuthorized',false,'allowed',false,'scheduleCompletenessVerified',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.owned_aircraft_storage_crew_candidates_v1(uuid,uuid,uuid,text,text,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
