-- ROLLBACK-ONLY REVIEW. Persist independently validated storage-aware plans
-- in an isolated table. Never supersede live commercial plans or release custody.
BEGIN;
CREATE TABLE airlinerra_game.storage_aware_crew_plan_reviews_v1(
 plan_id uuid PRIMARY KEY,airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 window_start_utc timestamptz NOT NULL,validated_at timestamptz NOT NULL,
 source_snapshot jsonb NOT NULL,assignments jsonb NOT NULL,verified_duties jsonb NOT NULL,
 CHECK(jsonb_typeof(assignments)='array' AND jsonb_typeof(verified_duties)='array')
);
ALTER TABLE airlinerra_game.storage_aware_crew_plan_reviews_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_aware_crew_plan_reviews_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.save_storage_aware_crew_plan_review_v1(p_player uuid,p_airline uuid,p_plan uuid,p_start timestamptz,p_snapshot jsonb,p_assignments jsonb)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE snap jsonb;old record;item jsonb;f jsonb;seat jsonb;emp jsonb;ids jsonb;required int;v_now timestamptz;emp_id text;report_at timestamptz;legs jsonb;rot jsonb;history jsonb;verified jsonb:='[]';role_name text;group_key text;all_seats jsonb:='[]';expected int;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active' WHERE a.id=p_airline AND a.owner_player_id=p_player AND a.world_id=1 FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_plan IS NULL OR p_start IS NULL OR NOT isfinite(p_start) OR jsonb_typeof(p_assignments) IS DISTINCT FROM 'array' OR jsonb_typeof(p_snapshot) IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('status','storage_crew_review_invalid','saved',false);END IF;
 SELECT * INTO old FROM airlinerra_game.storage_aware_crew_plan_reviews_v1 WHERE plan_id=p_plan;
 IF FOUND THEN
  IF old.airline_id IS DISTINCT FROM p_airline OR old.window_start_utc IS DISTINCT FROM p_start OR old.source_snapshot IS DISTINCT FROM p_snapshot OR old.assignments IS DISTINCT FROM p_assignments THEN RETURN jsonb_build_object('status','storage_crew_review_replay_conflict','saved',false);END IF;
  RETURN jsonb_build_object('status','storage_crew_review_validated','planId',p_plan,'saved',true,'replayed',true,'crewReleased',false,'dispatchEnforced',false);
 END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 snap:=airlinerra_game.owned_storage_aware_crew_input_preview_v1(p_player,p_airline,p_start);
 IF v_now IS NULL OR snap->>'status' IS DISTINCT FROM 'storage_aware_crew_input_preview' OR snap IS DISTINCT FROM p_snapshot THEN RETURN jsonb_build_object('status','storage_crew_review_snapshot_changed','saved',false);END IF;
 IF jsonb_array_length(p_assignments) NOT BETWEEN 1 AND 2000 OR jsonb_array_length(p_assignments)<>jsonb_array_length(snap->'flights') OR jsonb_array_length(p_assignments)<>(SELECT count(DISTINCT v->>'flightId') FROM jsonb_array_elements(p_assignments) a(v)) THEN RETURN jsonb_build_object('status','storage_crew_review_incomplete','saved',false);END IF;
 FOR item IN SELECT value FROM jsonb_array_elements(p_assignments) LOOP
  SELECT value INTO f FROM jsonb_array_elements(snap->'flights') WHERE value->>'id'=item->>'flightId';
  IF NOT FOUND OR item->>'aircraftId' IS DISTINCT FROM f->>'aircraftId' OR (item->>'departureUtc')::timestamptz IS DISTINCT FROM (f->>'departureUtc')::timestamptz OR (item->>'arrivalUtc')::timestamptz IS DISTINCT FROM (f->>'arrivalUtc')::timestamptz THEN RETURN jsonb_build_object('status','storage_crew_review_flight_mismatch','saved',false);END IF;
  IF jsonb_typeof(item->'captains') IS DISTINCT FROM 'array' OR jsonb_typeof(item->'firstOfficers') IS DISTINCT FROM 'array' OR jsonb_typeof(item->'cabinCrew') IS DISTINCT FROM 'array' OR jsonb_typeof(item->'duties') IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('status','storage_crew_review_manifest_invalid','saved',false);END IF;
  required:=CASE WHEN (f->>'arrivalUtc')::timestamptz-(f->>'departureUtc')::timestamptz>interval '6 hours' THEN 2 ELSE 1 END;
  IF jsonb_array_length(item->'captains')<>required OR jsonb_array_length(item->'firstOfficers')<>required OR jsonb_array_length(item->'cabinCrew') IS DISTINCT FROM (f->>'cabinRequired')::int THEN RETURN jsonb_build_object('status','storage_crew_review_wrong_staff_count','saved',false);END IF;
  ids:=(item->'captains')||(item->'firstOfficers')||(item->'cabinCrew');
  IF jsonb_array_length(ids)<>(SELECT count(DISTINCT value) FROM jsonb_array_elements(ids)) OR jsonb_array_length(ids)<>jsonb_array_length(item->'duties') OR jsonb_array_length(ids)<>(SELECT count(DISTINCT v->>'employeeId') FROM jsonb_array_elements(item->'duties') a(v)) THEN RETURN jsonb_build_object('status','storage_crew_review_duplicate_employee','saved',false);END IF;
  FOR seat IN SELECT value FROM jsonb_array_elements(item->'duties') LOOP
   emp_id:=seat->>'employeeId';role_name:=seat->>'role';
   ids:=CASE role_name WHEN 'captain' THEN item->'captains' WHEN 'firstOfficer' THEN item->'firstOfficers' WHEN 'cabin' THEN item->'cabinCrew' END;
   IF ids IS NULL OR emp_id IS NULL OR NOT (ids?emp_id) OR (seat->>'dutyStartUtc')::timestamptz IS NULL THEN RETURN jsonb_build_object('status','storage_crew_review_manifest_mismatch','saved',false);END IF;
   all_seats:=all_seats||jsonb_build_array(jsonb_build_object('employeeId',emp_id,'role',role_name,'reportAt',seat->>'dutyStartUtc','flight',f));
  END LOOP;
 END LOOP;
 FOR emp_id IN SELECT DISTINCT v->>'employeeId' FROM jsonb_array_elements(all_seats) a(v) ORDER BY 1 LOOP
  SELECT value INTO emp FROM jsonb_array_elements((snap->'pilots')||(snap->'cabinMembers')) WHERE value->>'id'=emp_id;
  IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_crew_review_employee_unavailable','saved',false);END IF;
  history:=emp->'history';
  FOR report_at IN SELECT DISTINCT (v->>'reportAt')::timestamptz FROM jsonb_array_elements(all_seats) a(v) WHERE v->>'employeeId'=emp_id ORDER BY 1 LOOP
   SELECT jsonb_agg(jsonb_build_object('originAirportKey',v#>>'{flight,origin}','destinationAirportKey',v#>>'{flight,destination}','departureUtc',to_char((v#>>'{flight,departureUtc}')::timestamptz AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'arrivalUtc',to_char((v#>>'{flight,arrivalUtc}')::timestamptz AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"')) ORDER BY (v#>>'{flight,departureUtc}')::timestamptz) INTO legs
   FROM jsonb_array_elements(all_seats) a(v) WHERE v->>'employeeId'=emp_id AND (v->>'reportAt')::timestamptz=report_at;
   rot:=airlinerra_game.section9_crew_rotation_window_v2(legs);
   IF rot->>'status' IS DISTINCT FROM 'rotation_preview' OR (rot->>'dutyStartUtc')::timestamptz IS DISTINCT FROM report_at OR report_at<v_now THEN RETURN jsonb_build_object('status','storage_crew_review_invalid_rotation','saved',false);END IF;
   FOR seat IN SELECT DISTINCT jsonb_build_object('role',v->>'role','group',v#>>'{flight,group}') FROM jsonb_array_elements(all_seats) a(v) WHERE v->>'employeeId'=emp_id AND (v->>'reportAt')::timestamptz=report_at LOOP
    role_name:=CASE seat->>'role' WHEN 'firstOfficer' THEN 'first_officer' ELSE seat->>'role' END;
    group_key:=seat->>'group';
    IF airlinerra_game.aircraft_storage_crew_candidate_fit_v1(jsonb_set(emp,'{history}',history),rot,group_key,role_name) IS DISTINCT FROM true THEN RETURN jsonb_build_object('status','storage_crew_review_duty_fit_failed','saved',false);END IF;
   END LOOP;
   history:=history||jsonb_build_array(jsonb_build_object('startUtc',rot->'dutyStartUtc','endUtc',rot->'dutyEndUtc','origin',rot->'startingAirport','destination',rot->'endingAirport'));
   verified:=verified||jsonb_build_array(rot||jsonb_build_object('employeeId',emp_id));
  END LOOP;
 END LOOP;
 INSERT INTO airlinerra_game.storage_aware_crew_plan_reviews_v1 VALUES(p_plan,p_airline,p_start,v_now,snap,p_assignments,verified);
 RETURN jsonb_build_object('status','storage_crew_review_validated','planId',p_plan,'saved',true,'replayed',false,'flightCount',jsonb_array_length(p_assignments),'dutyCount',jsonb_array_length(verified),'crewReleased',false,'dispatchEnforced',false);
EXCEPTION WHEN unique_violation OR invalid_text_representation OR invalid_datetime_format OR datetime_field_overflow OR invalid_parameter_value THEN RETURN jsonb_build_object('status','storage_crew_review_invalid','saved',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.save_storage_aware_crew_plan_review_v1(uuid,uuid,uuid,timestamptz,jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
