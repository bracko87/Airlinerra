-- Game pilot permissions. Existing employment roster remains authoritative.
-- No pilot is grandfathered into a captain permission from an old configuration reference.
CREATE TABLE airlinerra_game.section9_pilot_qualification_groups_v1(
 qualification_group text PRIMARY KEY CHECK(qualification_group ~ '^(family:[0-9]+|atr:42-72)$')
);
INSERT INTO airlinerra_game.section9_pilot_qualification_groups_v1
 SELECT DISTINCT qualification_group FROM airlinerra_game.section9_flight_crew_model_policy_v1;
ALTER TABLE airlinerra_game.section9_flight_crew_model_policy_v1
 ADD CONSTRAINT section9_crew_policy_qualification_group_fk FOREIGN KEY(qualification_group)
 REFERENCES airlinerra_game.section9_pilot_qualification_groups_v1(qualification_group);
CREATE TABLE airlinerra_game.section9_pilot_profiles_v1(
 crew_id uuid PRIMARY KEY,
 airline_id uuid NOT NULL,
 career_rank text NOT NULL CHECK(career_rank IN('captain','first_officer','senior_first_officer','second_officer','training_captain','flight_instructor','examiner')),
 total_flight_minutes bigint NOT NULL DEFAULT 0 CHECK(total_flight_minutes>=0),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(airline_id,crew_id),
 FOREIGN KEY(airline_id,crew_id) REFERENCES airlinerra_game.section9_airline_crew_roster_v1(airline_id,crew_id)
);
CREATE TABLE airlinerra_game.section9_pilot_family_permissions_v1(
 airline_id uuid NOT NULL,
 crew_id uuid NOT NULL,
 qualification_group text NOT NULL REFERENCES airlinerra_game.section9_pilot_qualification_groups_v1(qualification_group),
 captain_permission boolean NOT NULL DEFAULT false,
 first_officer_permission boolean NOT NULL DEFAULT false,
 qualification_status text NOT NULL CHECK(qualification_status IN('active','suspended','expired')),
 family_flight_minutes bigint NOT NULL DEFAULT 0 CHECK(family_flight_minutes>=0),
 issued_game_date date NOT NULL,
 expires_game_date date NOT NULL CHECK(expires_game_date>issued_game_date),
 PRIMARY KEY(crew_id,qualification_group),
 FOREIGN KEY(airline_id,crew_id) REFERENCES airlinerra_game.section9_pilot_profiles_v1(airline_id,crew_id),
 CHECK(captain_permission OR first_officer_permission)
);
CREATE INDEX section9_pilot_permissions_airline_group_idx ON airlinerra_game.section9_pilot_family_permissions_v1(airline_id,qualification_group,qualification_status);
ALTER TABLE airlinerra_game.section9_pilot_qualification_groups_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_pilot_profiles_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_pilot_family_permissions_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_pilot_qualification_groups_v1,airlinerra_game.section9_pilot_profiles_v1,airlinerra_game.section9_pilot_family_permissions_v1 FROM PUBLIC,anon,authenticated,service_role;

-- Evaluate rank and permission separately. Career title alone never grants a licence.
CREATE FUNCTION airlinerra_game.section9_pilot_can_fill_rank_v1(p_rank text,p_captain boolean,p_first_officer boolean,p_requested text)
RETURNS boolean LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path TO pg_catalog AS $$
 SELECT coalesce(CASE WHEN p_requested='captain' THEN p_captain AND p_rank IN('captain','training_captain','flight_instructor','examiner')
 WHEN p_requested='first_officer' THEN p_first_officer AND p_rank IN('captain','training_captain','flight_instructor','examiner','first_officer','senior_first_officer')
 ELSE false END,false)
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_pilot_can_fill_rank_v1(text,boolean,boolean,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.section9_owned_pilot_coverage_preview_v1(p_player uuid,p_airline uuid,p_configuration bigint,p_flight_minutes integer,p_game_date date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE grp text; needed integer; captains integer; officers integer; eligible integer; covered boolean;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_PILOT_COVERAGE_ONLY';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RETURN jsonb_build_object('status','blocked_airline_not_owned');END IF;
 SELECT qualification_group INTO grp FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=p_configuration;
 IF grp IS NULL OR p_flight_minutes IS NULL OR p_flight_minutes NOT BETWEEN 1 AND 1440 OR p_game_date IS NULL THEN RETURN jsonb_build_object('status','pilot_requirements_unverified');END IF;
 needed:=CASE WHEN p_flight_minutes>360 THEN 2 ELSE 1 END;
 WITH candidates AS (
 SELECT p.crew_id,
 airlinerra_game.section9_pilot_can_fill_rank_v1(p.career_rank,q.captain_permission,q.first_officer_permission,'captain') can_captain,
 airlinerra_game.section9_pilot_can_fill_rank_v1(p.career_rank,q.captain_permission,q.first_officer_permission,'first_officer') can_officer
 FROM airlinerra_game.section9_pilot_profiles_v1 p
 JOIN airlinerra_game.section9_pilot_family_permissions_v1 q ON q.crew_id=p.crew_id AND q.airline_id=p.airline_id
 JOIN airlinerra_game.section9_airline_crew_roster_v1 e ON e.crew_id=p.crew_id AND e.airline_id=p.airline_id
 WHERE p.airline_id=p_airline AND e.employment_status='verified_employed' AND e.role='flight_deck'
 AND e.game_effective_date IS NOT NULL AND e.game_effective_date<=p_game_date
 AND q.qualification_group=grp AND q.qualification_status='active'
 AND q.issued_game_date<=p_game_date AND q.expires_game_date>p_game_date)
 SELECT count(*) FILTER(WHERE can_captain),count(*) FILTER(WHERE can_officer),count(*) FILTER(WHERE can_captain OR can_officer)
 INTO captains,officers,eligible FROM candidates;
 covered:=captains>=needed AND officers>=needed AND eligible>=needed*2;
 RETURN jsonb_build_object('status','pilot_coverage_preview','qualificationGroup',grp,'asOfGameDate',p_game_date,'requiredCaptains',needed,'requiredFirstOfficers',needed,'requiredTotalPilots',needed*2,'eligibleCaptains',captains,'eligibleFirstOfficers',officers,'distinctEligiblePilots',eligible,'rankAndQualificationCoverage',covered,'availabilityCalculated',false,'dispatchEnforced',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_pilot_coverage_preview_v1(uuid,uuid,bigint,integer,date) FROM PUBLIC,anon,authenticated,service_role;
