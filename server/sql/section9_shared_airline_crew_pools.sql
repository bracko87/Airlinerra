-- Shared crew identity and home-base foundation, not yet an allocator.
-- Existing pilot employment and aggregate cabin headcount remain authoritative.
CREATE TABLE airlinerra_game.section9_crew_bases_v1(
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airport_key text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(airline_id,airport_key),
 FOREIGN KEY(world_id,airport_key) REFERENCES airlinerra_game.airport_reference_profiles(world_id,airport_key)
);
INSERT INTO airlinerra_game.section9_crew_bases_v1(airline_id,world_id,airport_key)
SELECT a.id,a.world_id,a.home_airport_key FROM airlinerra_game.airlines a
JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=a.world_id AND ap.airport_key=a.home_airport_key
WHERE a.world_id=1;

CREATE TABLE airlinerra_game.section9_pilot_base_assignments_v1(
 crew_id uuid PRIMARY KEY,
 airline_id uuid NOT NULL,
 base_airport_key text NOT NULL,
 initial_airport_key text NOT NULL,
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 location_effective_utc timestamptz NOT NULL CHECK(isfinite(location_effective_utc)),
 FOREIGN KEY(airline_id,crew_id) REFERENCES airlinerra_game.section9_pilot_profiles_v1(airline_id,crew_id),
 FOREIGN KEY(airline_id,base_airport_key) REFERENCES airlinerra_game.section9_crew_bases_v1(airline_id,airport_key),
 FOREIGN KEY(world_id,initial_airport_key) REFERENCES airlinerra_game.airport_reference_profiles(world_id,airport_key)
);
CREATE INDEX section9_pilot_base_airline_idx ON airlinerra_game.section9_pilot_base_assignments_v1(airline_id,base_airport_key);

-- Internal identities permit individual rest and allocation checks without
-- requiring players to manage flight attendants one by one.
ALTER TABLE airlinerra_game.section9_cabin_crew_pools_v1 ADD CONSTRAINT section9_cabin_pool_registered_base_fk
 FOREIGN KEY(airline_id,base_airport_key) REFERENCES airlinerra_game.section9_crew_bases_v1(airline_id,airport_key);
CREATE TABLE airlinerra_game.section9_cabin_crew_members_v1(
 member_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 airline_id uuid NOT NULL,
 base_airport_key text NOT NULL,
 role text NOT NULL,
 initial_airport_key text NOT NULL,
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 location_effective_utc timestamptz NOT NULL CHECK(isfinite(location_effective_utc)),
 employment_status text NOT NULL CHECK(employment_status IN('employed','suspended')),
 effective_game_date date NOT NULL,
 UNIQUE(airline_id,member_id),
 FOREIGN KEY(airline_id,base_airport_key,role) REFERENCES airlinerra_game.section9_cabin_crew_pools_v1(airline_id,base_airport_key,role),
 FOREIGN KEY(world_id,initial_airport_key) REFERENCES airlinerra_game.airport_reference_profiles(world_id,airport_key)
);
CREATE INDEX section9_cabin_members_base_idx ON airlinerra_game.section9_cabin_crew_members_v1(airline_id,base_airport_key,role);
ALTER TABLE airlinerra_game.section9_crew_bases_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_pilot_base_assignments_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_cabin_crew_members_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_crew_bases_v1,airlinerra_game.section9_pilot_base_assignments_v1,airlinerra_game.section9_cabin_crew_members_v1 FROM PUBLIC,anon,authenticated,service_role;

-- The proposed fleet may repeat configuration IDs (four distinct A319s, etc.).
-- Aggregate by qualification group, but keep a single identity for each employee.
-- Candidate counts do NOT represent concurrent coverage or availability.
CREATE FUNCTION airlinerra_game.section9_owned_shared_crew_pool_preview_v1(
 p_player uuid,p_airline uuid,p_base text,p_configurations bigint[],p_game_date date)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE groups jsonb; pilots jsonb; cabin jsonb; pool_consistent boolean; home_tz text;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_SHARED_CREW_PREVIEW_ONLY';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RETURN jsonb_build_object('status','blocked_airline_not_owned');END IF;
 SELECT ap.timezone_iana INTO home_tz FROM airlinerra_game.section9_crew_bases_v1 b JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=b.world_id AND ap.airport_key=b.airport_key
 WHERE b.airline_id=p_airline AND b.airport_key=p_base;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','blocked_unregistered_crew_base');END IF;
 IF home_tz IS NULL OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=home_tz) THEN RETURN jsonb_build_object('status','base_timezone_unverified');END IF;
 IF p_game_date IS NULL OR p_configurations IS NULL OR cardinality(p_configurations)>5000 OR EXISTS(SELECT 1 FROM unnest(p_configurations) i LEFT JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=i WHERE p.configuration_id IS NULL) THEN RETURN jsonb_build_object('status','configuration_requirements_unverified');END IF;
 WITH fleet AS (
 SELECT p.qualification_group,count(*) aircraft_count,
 array_agg(DISTINCT p.configuration_id ORDER BY p.configuration_id) configurations
 FROM unnest(p_configurations) id JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=id GROUP BY p.qualification_group
 ), candidates AS (
 SELECT pr.crew_id,pr.career_rank,b.initial_airport_key,b.location_effective_utc,
 q.qualification_group,
 airlinerra_game.section9_pilot_can_fill_rank_v1(pr.career_rank,q.captain_permission,q.first_officer_permission,'captain') can_captain,
 airlinerra_game.section9_pilot_can_fill_rank_v1(pr.career_rank,q.captain_permission,q.first_officer_permission,'first_officer') can_officer
 FROM airlinerra_game.section9_pilot_profiles_v1 pr
 JOIN airlinerra_game.section9_pilot_base_assignments_v1 b ON b.crew_id=pr.crew_id AND b.airline_id=pr.airline_id
 JOIN airlinerra_game.section9_airline_crew_roster_v1 r ON r.crew_id=pr.crew_id AND r.airline_id=pr.airline_id
 JOIN airlinerra_game.section9_pilot_family_permissions_v1 q ON q.crew_id=pr.crew_id AND q.airline_id=pr.airline_id
 JOIN fleet f ON f.qualification_group=q.qualification_group
 WHERE pr.airline_id=p_airline AND b.base_airport_key=p_base AND r.employment_status='verified_employed'
 AND r.game_effective_date<=p_game_date AND q.qualification_status='active' AND q.issued_game_date<=p_game_date AND q.expires_game_date>p_game_date
 ), eligible AS (SELECT * FROM candidates WHERE can_captain OR can_officer),
 members AS (
 SELECT crew_id,career_rank,initial_airport_key,location_effective_utc,
 jsonb_agg(jsonb_build_object('qualificationGroup',qualification_group,'captain',can_captain,'firstOfficer',can_officer) ORDER BY qualification_group) permissions
 FROM eligible GROUP BY crew_id,career_rank,initial_airport_key,location_effective_utc
 )
 SELECT
 (SELECT coalesce(jsonb_agg(jsonb_build_object('qualificationGroup',f.qualification_group,'aircraftCount',f.aircraft_count,'configurationIds',f.configurations,
 'eligibleCaptains',(SELECT count(*) FROM eligible e WHERE e.qualification_group=f.qualification_group AND e.can_captain),
 'eligibleFirstOfficers',(SELECT count(*) FROM eligible e WHERE e.qualification_group=f.qualification_group AND e.can_officer),
 'distinctPilots',(SELECT count(DISTINCT e.crew_id) FROM eligible e WHERE e.qualification_group=f.qualification_group)) ORDER BY f.qualification_group),'[]') FROM fleet f),
 (SELECT coalesce(jsonb_agg(jsonb_build_object('crewId',crew_id,'careerRank',career_rank,'initialAirport',initial_airport_key,'locationEffectiveUtc',location_effective_utc,'permissions',permissions) ORDER BY crew_id),'[]') FROM members)
 INTO groups,pilots;
 WITH counts AS (
 SELECT p.role,p.employed_count,
 (SELECT count(*) FROM airlinerra_game.section9_cabin_crew_members_v1 m WHERE m.airline_id=p.airline_id AND m.base_airport_key=p.base_airport_key AND m.role=p.role) member_count
 FROM airlinerra_game.section9_cabin_crew_pools_v1 p WHERE p.airline_id=p_airline AND p.base_airport_key=p_base
 )
 SELECT coalesce(bool_and(employed_count=member_count),true) INTO pool_consistent FROM counts;
 SELECT coalesce(jsonb_agg(jsonb_build_object('memberId',m.member_id,'role',m.role,'initialAirport',m.initial_airport_key,'locationEffectiveUtc',m.location_effective_utc) ORDER BY m.member_id),'[]') INTO cabin
 FROM airlinerra_game.section9_cabin_crew_members_v1 m
 WHERE m.airline_id=p_airline AND m.base_airport_key=p_base AND m.employment_status='employed' AND m.effective_game_date<=p_game_date AND m.role IN('flight_attendant','cabin_supervisor','purser') AND pool_consistent;
 RETURN jsonb_build_object('status','shared_crew_pool_preview','baseAirportKey',p_base,'baseTimezone',home_tz,'asOfGameDate',p_game_date,
 'proposedAircraftCount',cardinality(p_configurations),'qualificationGroups',groups,'pilots',pilots,'distinctPilotCount',jsonb_array_length(pilots),
 'cabinMembers',cabin,'distinctCabinMemberCount',jsonb_array_length(cabin),'cabinHeadcountReconciled',pool_consistent,
 'availabilityCalculated',false,'crossGroupCountsAreNonAdditive',true,'dispatchEnforced',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_shared_crew_pool_preview_v1(uuid,uuid,text,bigint[],date) FROM PUBLIC,anon,authenticated,service_role;
