-- ROLLBACK-ONLY REVIEW. Revalidate reserved storage crew before signed departure.
-- Requires current authoritative roster/history. Never infer that a booking
-- remains safe simply because its crew IDs were reserved earlier.
BEGIN;
CREATE TABLE airlinerra_game.storage_crew_departure_validation_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.storage_crew_departure_validation_release_v1(world_id) VALUES(1);
ALTER TABLE airlinerra_game.storage_crew_departure_validation_release_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_crew_departure_validation_release_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.storage_crew_departure_check_v1(p_request uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE r record;c record;model record;pol record;inp jsonb;member jsonb;rot jsonb;now_utc timestamptz;ds timestamptz;de timestamptz;expected int;nc int;nf int;na int;matched int;cfg bigint;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request;
 IF NOT FOUND OR r.status NOT IN('awaiting_slot_and_dispatch_release','reactivation_awaiting_review') THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_request_invalid');END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL OR now_utc<r.departure_utc OR now_utc>=r.departure_utc+interval '10 minutes' THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_departure_window_invalid');END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active' WHERE a.id=r.airline_id AND a.owner_player_id=r.owner_player_id AND a.world_id=1) THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_owner_invalid');END IF;
 SELECT configuration_id INTO cfg FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND airline_id=r.airline_id AND ownership_type='owned';
 IF NOT FOUND OR cfg IS DISTINCT FROM (r.quote->>'configurationId')::bigint THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_configuration_changed');END IF;
 SELECT * INTO model FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=cfg;
 IF NOT FOUND OR model.minimum_cabin_crew IS NULL OR model.minimum_cabin_crew<0 OR nullif(btrim(model.qualification_group),'') IS NULL THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_model_invalid');END IF;
 SELECT * INTO pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 IF NOT FOUND OR pol.preflight_minutes IS NULL OR pol.preflight_minutes<0 OR pol.postflight_minutes IS NULL OR pol.postflight_minutes<0 OR pol.minimum_rest_minutes IS DISTINCT FROM 720 THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_policy_invalid');END IF;
 ds:=r.departure_utc-make_interval(mins=>pol.preflight_minutes);de:=r.arrival_utc+make_interval(mins=>pol.postflight_minutes);
 rot:=airlinerra_game.section9_crew_rotation_window_v2(jsonb_build_array(jsonb_build_object('originAirportKey',r.origin_airport_key,'destinationAirportKey',r.destination_airport_key,'departureUtc',to_char(r.departure_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'arrivalUtc',to_char(r.arrival_utc AT TIME ZONE 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'))));
 IF rot->>'status' IS DISTINCT FROM 'rotation_preview' OR (rot->>'dutyStartUtc')::timestamptz IS DISTINCT FROM ds OR (rot->>'dutyEndUtc')::timestamptz IS DISTINCT FROM de THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_rotation_invalid');END IF;
 expected:=CASE WHEN r.arrival_utc-r.departure_utc>interval '6 hours' THEN 2 ELSE 1 END;
 SELECT count(*) FILTER(WHERE seat_role='captain'),count(*) FILTER(WHERE seat_role='first_officer'),count(*) FILTER(WHERE seat_role='cabin') INTO nc,nf,na FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=r.id;
 IF nc<>expected OR nf<>expected OR na<>model.minimum_cabin_crew THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_manifest_incomplete');END IF;
 inp:=airlinerra_game.section9_owned_rolling_crew_input_v1(r.owner_player_id,r.airline_id,now_utc);
 IF inp->>'status' IS DISTINCT FROM 'rolling_crew_input_preview' OR inp->>'unboundDeparturesLast7Days' IS DISTINCT FROM '0' OR inp->>'unresolvedCaptureIssues' IS DISTINCT FROM '0' OR inp->>'invalidOccurrenceCount' IS DISTINCT FROM '0' OR inp->>'alreadyReportedFutureFlights' IS DISTINCT FROM '0' OR inp->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' OR jsonb_typeof(inp->'pilots') IS DISTINCT FROM 'array' OR jsonb_typeof(inp->'cabinMembers') IS DISTINCT FROM 'array' THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_current_history_unverified');END IF;
 FOR c IN SELECT * FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=r.id ORDER BY employee_id LOOP
  IF c.airline_id<>r.airline_id OR c.status<>'reserved' OR c.qualification_group<>model.qualification_group OR c.duty_start_utc<>ds OR c.duty_end_utc<>de OR c.origin_airport_key<>r.origin_airport_key OR c.destination_airport_key<>r.destination_airport_key THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_manifest_changed');END IF;
  -- Until both schedulers consume completed ferry history, do not accept
  -- an employee with any previous non-cancelled storage custody.
  IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 s WHERE s.airline_id=r.airline_id AND s.employee_id=c.employee_id AND s.request_id<>r.id AND s.status<>'cancelled') OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_duties_v1 pd JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pd.plan_id AND b.airline_id=pd.airline_id AND b.status='validated_preview' WHERE pd.airline_id=r.airline_id AND pd.employee_id=c.employee_id AND pd.duty_end_utc>ds) THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_conflicting_custody');END IF;
  SELECT count(*) INTO matched FROM jsonb_array_elements((inp->'pilots')||(inp->'cabinMembers')) a(v) WHERE v->>'id'=c.employee_id::text;
  IF matched<>1 THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_employment_changed');END IF;
  SELECT value INTO member FROM jsonb_array_elements(CASE WHEN c.seat_role='cabin' THEN inp->'cabinMembers' ELSE inp->'pilots' END) WHERE value->>'id'=c.employee_id::text;
  IF NOT FOUND OR airlinerra_game.aircraft_storage_crew_candidate_fit_v1(member,rot,c.qualification_group,c.seat_role) IS DISTINCT FROM true THEN RETURN jsonb_build_object('passed',false,'status','storage_crew_duty_or_qualification_changed');END IF;
 END LOOP;
 RETURN jsonb_build_object('passed',true,'status','storage_crew_departure_revalidated','crewCount',nc+nf+na,'checkedAtUtc',now_utc,'dispatchAuthorized',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_crew_departure_check_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.guard_storage_crew_departure_revalidation_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE j jsonb;
BEGIN
 IF NEW.storage_request_id IS NULL OR NEW.phase<>'departed' THEN RETURN NEW;END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_crew_departure_validation_release_v1 WHERE world_id=1 AND enabled) THEN RETURN NEW;END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=NEW.airline_id FOR UPDATE;
 j:=airlinerra_game.storage_crew_departure_check_v1(NEW.storage_request_id);
 IF j->>'passed' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_CREW_DEPARTURE_REVALIDATION_FAILED',DETAIL=coalesce(j->>'status','unknown');END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_storage_crew_departure_revalidation_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER guard_storage_crew_departure_revalidation_v1 BEFORE INSERT ON airlinerra_game.section9_operated_flight_movements_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_storage_crew_departure_revalidation_v1();
ROLLBACK;
