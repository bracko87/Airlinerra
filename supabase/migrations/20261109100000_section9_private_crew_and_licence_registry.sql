-- Section 9 crew-and-operating-permission groundwork.
-- Crew rosters originate ONLY from future authenticated airline employment
-- source; game users may propose using registered crew but cannot approve
-- employment or manufacture legal operating permissions.
-- No aircraft activation, financial entries or ticket issuance.

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_airline_crew_roster_v1(
 crew_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 crew_reference text NOT NULL CHECK(
  length(crew_reference) BETWEEN 3 AND 90),
 role text NOT NULL DEFAULT 'flight_deck' CHECK(role='flight_deck'),
 qualified_configuration_id bigint NOT NULL REFERENCES
  airlinerra.aircraft_configurations(id),
 employment_status text NOT NULL DEFAULT 'pending_verification'
  CHECK(employment_status IN
   ('pending_verification','verified_employed','suspended')),
 employment_proof_ref text,
 employment_reviewed_at timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(airline_id,crew_reference),
 UNIQUE(airline_id,crew_id),
 CHECK(employment_status<>'verified_employed'
  OR (employment_reviewed_at IS NOT NULL AND
      length(coalesce(employment_proof_ref,''))>=8))
);
ALTER TABLE airlinerra_game.section9_airline_crew_roster_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_airline_crew_roster_v1
 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_crew_configuration_lookup_idx
 ON airlinerra_game.section9_airline_crew_roster_v1(
  airline_id,qualified_configuration_id,employment_status);

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_weekly_crew_duty_proposals_v1(
 airline_id uuid NOT NULL,
 crew_id uuid NOT NULL,
 schedule_id uuid NOT NULL REFERENCES
  airlinerra_game.airline_flight_schedule_drafts_v1(id)
  ON DELETE CASCADE,
 weekly_entry smallint NOT NULL CHECK(weekly_entry BETWEEN 1 AND 7),
 schedule_version integer NOT NULL CHECK(schedule_version>=1),
 proposal_status text NOT NULL DEFAULT 'planned_not_verified'
  CHECK(proposal_status='planned_not_verified'),
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(schedule_id,weekly_entry,crew_id),
 FOREIGN KEY(airline_id,crew_id) REFERENCES
  airlinerra_game.section9_airline_crew_roster_v1(airline_id,crew_id)
);
ALTER TABLE airlinerra_game.section9_weekly_crew_duty_proposals_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_weekly_crew_duty_proposals_v1
 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_crew_duty_employee_lookup_idx
 ON airlinerra_game.section9_weekly_crew_duty_proposals_v1(
  airline_id,crew_id,weekly_entry,schedule_id);

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_operator_licence_evidence_v1(
 licence_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 jurisdiction_iso2 text NOT NULL CHECK(
  jurisdiction_iso2 ~ '^[A-Z]{2}$'),
 evidence_status text NOT NULL DEFAULT 'unverified'
   CHECK(evidence_status IN ('unverified','verified','revoked')),
 evidence_reference text,
 reviewed_at timestamptz,
 valid_from date,
 valid_until date,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(airline_id,jurisdiction_iso2),
 CHECK(valid_from IS NULL OR valid_until IS NULL OR valid_until>=valid_from),
 CHECK(evidence_status<>'verified' OR (
  reviewed_at IS NOT NULL AND valid_from IS NOT NULL
  AND length(coalesce(evidence_reference,''))>=8))
);
ALTER TABLE airlinerra_game.section9_operator_licence_evidence_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_operator_licence_evidence_v1
 FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_route_operating_permission_evidence_v1(
 permission_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 origin_airport_key text NOT NULL,
 destination_airport_key text NOT NULL,
 service_type text NOT NULL CHECK(service_type IN('passenger','cargo')),
 evidence_status text NOT NULL DEFAULT 'unverified'
   CHECK(evidence_status IN('unverified','verified','revoked')),
 evidence_reference text,
 reviewed_at timestamptz,
 valid_from date,
 valid_until date,
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(airline_id,origin_airport_key,destination_airport_key,service_type),
 CHECK(origin_airport_key<>destination_airport_key),
 CHECK(valid_from IS NULL OR valid_until IS NULL OR valid_until>=valid_from),
 CHECK(evidence_status<>'verified' OR (
  reviewed_at IS NOT NULL AND valid_from IS NOT NULL
  AND length(coalesce(evidence_reference,''))>=8))
);
ALTER TABLE airlinerra_game.section9_route_operating_permission_evidence_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_route_operating_permission_evidence_v1
 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_route_permission_airline_lookup_idx
 ON airlinerra_game.section9_route_operating_permission_evidence_v1(
  airline_id,origin_airport_key,destination_airport_key,evidence_status);

COMMENT ON TABLE airlinerra_game.section9_airline_crew_roster_v1 IS
 'Registered game crew members; ONLY reviewed employment source may mark verified_employed. No user-facing hire/payment source yet.';
COMMENT ON TABLE airlinerra_game.section9_weekly_crew_duty_proposals_v1 IS
 'Owner-planned crew duties for weekly schedule entries; proposals never authorize flying or substitute for certified staffing.';
COMMENT ON TABLE airlinerra_game.section9_operator_licence_evidence_v1 IS
 'Privately reviewed game operator licence evidence; never inferred from airline home-airport country or general country rights table.';
COMMENT ON TABLE airlinerra_game.section9_route_operating_permission_evidence_v1 IS
 'Privately reviewed exact airline/OD/traffic-type authority evidence. General legal right principles do not imply permission.';

-- Browser players can only propose duty on their OWN draft schedule using an
-- ALREADY existing employee roster; no ability to add/hire/verify crew.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_plan_owned_crew_duty_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,p_crew uuid,
 p_weekly_entry integer,p_action text
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE s record;member record;total integer;changed integer;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_schedule IS NULL OR
  p_crew IS NULL OR p_weekly_entry NOT BETWEEN 1 AND 7 OR
  p_action NOT IN ('plan','remove')
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_CREW_DUTY_REQUEST';END IF;
 SELECT d.id,d.airline_id,d.status,d.configuration_id,d.weekly_schedule,
  d.version INTO s
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 JOIN airlinerra_game.airlines a
  ON a.id=d.airline_id AND a.world_id=1
  AND a.owner_player_id=p_player
 WHERE d.id=p_schedule AND d.airline_id=p_airline
 FOR SHARE OF d;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_CREW_SCHEDULE_NOT_OWNED';END IF;
 IF s.status<>'draft' THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_ONLY_DRAFT_CREW_PLANNING_ALLOWED';END IF;
 IF p_weekly_entry>jsonb_array_length(s.weekly_schedule) THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_CREW_WEEKLY_ENTRY_MISSING';END IF;
 SELECT c.crew_id,c.airline_id,c.qualified_configuration_id,c.employment_status
 INTO member
 FROM airlinerra_game.section9_airline_crew_roster_v1 c
 WHERE c.crew_id=p_crew AND c.airline_id=p_airline;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_CREW_NOT_REGISTERED_WITH_AIRLINE';END IF;
 IF p_action='plan' THEN
  IF member.qualified_configuration_id<>s.configuration_id THEN
   RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_CREW_AIRCRAFT_QUALIFICATION_MISMATCH';END IF;
  IF member.employment_status='suspended' THEN
   RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_CREW_SUSPENDED';END IF;
  INSERT INTO airlinerra_game.section9_weekly_crew_duty_proposals_v1(
   airline_id,crew_id,schedule_id,weekly_entry,schedule_version)
  VALUES(p_airline,p_crew,p_schedule,p_weekly_entry,s.version)
  ON CONFLICT(schedule_id,weekly_entry,crew_id) DO UPDATE
   SET schedule_version=excluded.schedule_version;
  changed:=1;
 ELSE
  DELETE FROM airlinerra_game.section9_weekly_crew_duty_proposals_v1
  WHERE airline_id=p_airline AND schedule_id=p_schedule
   AND crew_id=p_crew AND weekly_entry=p_weekly_entry;
  GET DIAGNOSTICS changed=ROW_COUNT;
 END IF;
 SELECT count(*) INTO total
 FROM airlinerra_game.section9_weekly_crew_duty_proposals_v1
 WHERE airline_id=p_airline AND schedule_id=p_schedule
   AND weekly_entry=p_weekly_entry AND schedule_version=s.version;
 RETURN jsonb_build_object(
  'status','planned_not_verified','changed',changed>0,
  'scheduleId',p_schedule,'crewId',p_crew,'weeklyEntry',p_weekly_entry,
  'plannedCrewCount',total,'scheduleVersion',s.version,
  'employmentStatus',member.employment_status,
  'crewOperationallyVerified',false,
  'canActivateNormalFlight',false,'bookingsCreated',false);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_plan_owned_crew_duty_v1(
 uuid,uuid,uuid,uuid,integer,text) FROM PUBLIC,anon,authenticated;
