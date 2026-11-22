-- Individual flight experience accounting. Only an authoritative departure
-- manifest may be credited, and only against a matching signed arrival.
-- No automatic writer/arrival hook is installed until operational release.
CREATE TABLE airlinerra_game.section9_pilot_departure_manifests_v1(
 physical_flight_id text PRIMARY KEY REFERENCES airlinerra_game.section9_game_flight_fuel_departure_receipts_v1(physical_flight_id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 departure_event_id text NOT NULL UNIQUE REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 configuration_id bigint NOT NULL REFERENCES airlinerra.aircraft_configurations(id),
 qualification_group text NOT NULL REFERENCES airlinerra_game.section9_pilot_qualification_groups_v1(qualification_group),
 captain_ids uuid[] NOT NULL,
 first_officer_ids uuid[] NOT NULL,
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(cardinality(captain_ids) BETWEEN 1 AND 2 AND cardinality(captain_ids)=cardinality(first_officer_ids))
);
CREATE TABLE airlinerra_game.section9_pilot_flight_experience_v1(
 physical_flight_id text NOT NULL REFERENCES airlinerra_game.section9_pilot_departure_manifests_v1(physical_flight_id),
 airline_id uuid NOT NULL,
 crew_id uuid NOT NULL,
 qualification_group text NOT NULL REFERENCES airlinerra_game.section9_pilot_qualification_groups_v1(qualification_group),
 seat_role text NOT NULL CHECK(seat_role IN('captain','first_officer')),
 departure_event_id text NOT NULL REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 arrival_event_id text NOT NULL REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 actual_departure_utc timestamptz NOT NULL,
 actual_arrival_utc timestamptz NOT NULL,
 flight_minutes integer NOT NULL CHECK(flight_minutes BETWEEN 1 AND 4320),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(physical_flight_id,crew_id),
 FOREIGN KEY(airline_id,crew_id) REFERENCES airlinerra_game.section9_pilot_profiles_v1(airline_id,crew_id),
 CHECK(actual_arrival_utc>actual_departure_utc)
);
CREATE INDEX section9_pilot_experience_history_idx ON airlinerra_game.section9_pilot_flight_experience_v1(airline_id,crew_id,actual_arrival_utc DESC);
ALTER TABLE airlinerra_game.section9_pilot_departure_manifests_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_pilot_flight_experience_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_pilot_departure_manifests_v1,airlinerra_game.section9_pilot_flight_experience_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.section9_record_pilot_departure_manifest_v1(p_airline uuid,p_physical text,p_captains uuid[],p_officers uuid[])
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE f record; manifest record; required int; member record; eligible int;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_airline IS NULL OR p_physical IS NULL THEN RAISE EXCEPTION USING ERRCODE='22023';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO manifest FROM airlinerra_game.section9_pilot_departure_manifests_v1 WHERE physical_flight_id=p_physical;
 IF FOUND THEN
  IF manifest.airline_id=p_airline AND manifest.captain_ids=p_captains AND manifest.first_officer_ids=p_officers THEN RETURN jsonb_build_object('status','manifest_already_recorded','created',false);END IF;
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='PILOT_MANIFEST_CONFLICT';
 END IF;
 SELECT d.*,r.configuration_id,p.qualification_group INTO f
 FROM airlinerra_game.section9_game_flight_fuel_departure_receipts_v1 r
 JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.engine_event_id=r.departure_engine_event_id AND d.flight_occurrence_id=r.physical_flight_id AND d.airline_id=r.airline_id AND d.aircraft_inventory_id=r.aircraft_inventory_id
 JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=r.configuration_id
 WHERE r.physical_flight_id=p_physical AND r.airline_id=p_airline AND d.world_id=1 AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1' AND d.schedule_id IS NOT NULL;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','departure_not_verified');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id=p_physical AND phase='arrived') THEN RETURN jsonb_build_object('status','manifest_too_late');END IF;
 required:=CASE WHEN f.scheduled_arrival_utc-f.scheduled_departure_utc>interval '6 hours' THEN 2 ELSE 1 END;
 IF p_captains IS NULL OR p_officers IS NULL OR array_ndims(p_captains)<>1 OR array_ndims(p_officers)<>1 OR cardinality(p_captains)<>required OR cardinality(p_officers)<>required OR (SELECT count(DISTINCT id) FROM unnest(p_captains||p_officers) id)<>required*2 THEN RETURN jsonb_build_object('status','invalid_pilot_manifest');END IF;
 FOR member IN SELECT id,'captain' AS seat_role FROM unnest(p_captains) id UNION ALL SELECT id,'first_officer' FROM unnest(p_officers) id LOOP
 SELECT count(*) INTO eligible FROM airlinerra_game.section9_pilot_profiles_v1 pr
 JOIN airlinerra_game.section9_airline_crew_roster_v1 r ON r.airline_id=pr.airline_id AND r.crew_id=pr.crew_id
 JOIN airlinerra_game.section9_pilot_family_permissions_v1 q ON q.airline_id=pr.airline_id AND q.crew_id=pr.crew_id AND q.qualification_group=f.qualification_group
 WHERE pr.airline_id=p_airline AND pr.crew_id=member.id AND r.employment_status='verified_employed' AND r.game_effective_date<=f.flight_local_date
 AND q.qualification_status='active' AND q.issued_game_date<=f.flight_local_date AND q.expires_game_date>f.flight_local_date
 AND airlinerra_game.section9_pilot_can_fill_rank_v1(pr.career_rank,q.captain_permission,q.first_officer_permission,member.seat_role);
 IF eligible<>1 THEN RETURN jsonb_build_object('status','pilot_manifest_qualification_failed');END IF;
 END LOOP;
 INSERT INTO airlinerra_game.section9_pilot_departure_manifests_v1(physical_flight_id,airline_id,departure_event_id,configuration_id,qualification_group,captain_ids,first_officer_ids)
 VALUES(p_physical,p_airline,f.engine_event_id,f.configuration_id,f.qualification_group,p_captains,p_officers);
 RETURN jsonb_build_object('status','pilot_manifest_recorded','created',true,'pilotCount',required*2,'dispatchEnforced',false);
END $$;

CREATE FUNCTION airlinerra_game.section9_credit_completed_pilot_flight_v1(p_airline uuid,p_physical text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE m record; d record; a record; member record; mins integer; inserted int; credited int:=0;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO m FROM airlinerra_game.section9_pilot_departure_manifests_v1 WHERE physical_flight_id=p_physical AND airline_id=p_airline;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','pilot_manifest_missing');END IF;
 SELECT * INTO STRICT d FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=m.departure_event_id AND phase='departed' AND airline_id=p_airline AND flight_occurrence_id=p_physical;
 SELECT * INTO a FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE flight_occurrence_id=p_physical AND phase='arrived' AND airline_id=p_airline AND world_id=d.world_id AND aircraft_inventory_id=d.aircraft_inventory_id AND schedule_id=d.schedule_id AND schedule_version=d.schedule_version AND weekly_entry=d.weekly_entry AND flight_local_date=d.flight_local_date AND origin_airport_key=d.origin_airport_key AND destination_airport_key=d.destination_airport_key;
 IF NOT FOUND OR a.actual_event_utc<=d.actual_event_utc OR a.actual_event_utc-d.actual_event_utc>interval '72 hours' THEN RETURN jsonb_build_object('status','completed_flight_not_verified');END IF;
 mins:=greatest(1,round(extract(epoch FROM a.actual_event_utc-d.actual_event_utc)/60)::integer);
 FOR member IN SELECT id,'captain' AS seat_role FROM unnest(m.captain_ids) id UNION ALL SELECT id,'first_officer' FROM unnest(m.first_officer_ids) id LOOP
 INSERT INTO airlinerra_game.section9_pilot_flight_experience_v1(physical_flight_id,airline_id,crew_id,qualification_group,seat_role,departure_event_id,arrival_event_id,actual_departure_utc,actual_arrival_utc,flight_minutes)
 VALUES(p_physical,p_airline,member.id,m.qualification_group,member.seat_role,d.engine_event_id,a.engine_event_id,d.actual_event_utc,a.actual_event_utc,mins)
 ON CONFLICT(physical_flight_id,crew_id) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 IF inserted=1 THEN
 UPDATE airlinerra_game.section9_pilot_profiles_v1 SET total_flight_minutes=total_flight_minutes+mins WHERE airline_id=p_airline AND crew_id=member.id;
 IF NOT FOUND THEN RAISE EXCEPTION 'PILOT_PROFILE_MISSING';END IF;
 UPDATE airlinerra_game.section9_pilot_family_permissions_v1 SET family_flight_minutes=family_flight_minutes+mins WHERE airline_id=p_airline AND crew_id=member.id AND qualification_group=m.qualification_group;
 IF NOT FOUND THEN RAISE EXCEPTION 'PILOT_FAMILY_HISTORY_MISSING';END IF;
 credited:=credited+1;
 END IF;
 END LOOP;
 RETURN jsonb_build_object('status',CASE WHEN credited>0 THEN 'pilot_experience_credited' ELSE 'pilot_experience_already_credited' END,'flightMinutes',mins,'pilotsCredited',credited,'monthlyLimitEnforced',false);
END $$;

CREATE FUNCTION airlinerra_game.section9_owned_pilot_career_v1(p_player uuid,p_airline uuid,p_crew uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE pr record; families jsonb; history jsonb; flights bigint;
BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO pr FROM airlinerra_game.section9_pilot_profiles_v1 WHERE airline_id=p_airline AND crew_id=p_crew;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','pilot_not_found');END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('qualificationGroup',qualification_group,'familyFlightMinutes',family_flight_minutes,'status',qualification_status,'issuedGameDate',issued_game_date,'expiresGameDate',expires_game_date) ORDER BY qualification_group),'[]') INTO families FROM airlinerra_game.section9_pilot_family_permissions_v1 WHERE airline_id=p_airline AND crew_id=p_crew;
 SELECT count(*) INTO flights FROM airlinerra_game.section9_pilot_flight_experience_v1 WHERE airline_id=p_airline AND crew_id=p_crew;
 SELECT coalesce(jsonb_agg(to_jsonb(x)),'[]') INTO history FROM (SELECT physical_flight_id AS "physicalFlightId",qualification_group AS "qualificationGroup",seat_role AS "seatRole",actual_departure_utc AS "departureUtc",actual_arrival_utc AS "arrivalUtc",flight_minutes AS "flightMinutes" FROM airlinerra_game.section9_pilot_flight_experience_v1 WHERE airline_id=p_airline AND crew_id=p_crew ORDER BY actual_arrival_utc DESC,physical_flight_id LIMIT 50)x;
 RETURN jsonb_build_object('status','pilot_career_history','crewId',p_crew,'careerRank',pr.career_rank,'totalFlightMinutes',pr.total_flight_minutes,'recordedCompletedFlights',flights,'families',families,'recentFlights',history,'monthlyLimitEnforced',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_record_pilot_departure_manifest_v1(uuid,text,uuid[],uuid[]),airlinerra_game.section9_credit_completed_pilot_flight_v1(uuid,text),airlinerra_game.section9_owned_pilot_career_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
