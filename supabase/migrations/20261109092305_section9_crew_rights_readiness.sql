-- Source-based crew and operator-permission readiness.
-- No approval pathway exposed to a player; all records are privately stored.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_crew_licence_preflight_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,
 p_date date,p_days integer DEFAULT 28
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE s record;crew_required integer;crew_details jsonb;
 insufficient_days integer;qualified_count integer;proposed_count integer;
 stale_count integer;possible_other_routes integer;
 approved_operator record;
 approved_rights integer;required_rights integer;
 permissions jsonb; country_hint text;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_schedule IS NULL
 OR p_date IS NULL OR p_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
 OR p_days NOT BETWEEN 7 AND 42
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_CREW_RIGHTS_READINESS_REQUEST';END IF;
 SELECT d.id,d.airline_id,d.configuration_id,d.weekly_schedule,d.version,
  d.status,d.origin_airport_key,d.destination_airport_key,
  c.crew_required,c.use_type,a.home_airport_key,
  home.country_iso AS home_country
 INTO s
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 JOIN airlinerra_game.airlines a ON a.id=d.airline_id
  AND a.world_id=1 AND a.owner_player_id=p_player
 JOIN airlinerra.aircraft_configurations c ON c.id=d.configuration_id
 LEFT JOIN airlinerra_game.airport_reference_profiles home
  ON home.world_id=1 AND home.airport_key=a.home_airport_key
 WHERE d.id=p_schedule AND d.airline_id=p_airline AND d.world_id=1;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_CREW_RIGHTS_SCHEDULE_NOT_OWNED';END IF;
 crew_required:=CASE WHEN s.crew_required>0 THEN s.crew_required ELSE NULL END;
 country_hint:=s.home_country;

 WITH entries AS (
  SELECT e.ordinality::int AS entry
  FROM jsonb_array_elements(s.weekly_schedule)
  WITH ORDINALITY AS e(item,ordinality)
 ), counts AS (
  SELECT e.entry,
   count(d.crew_id)::int AS proposed_total,
   count(d.crew_id) FILTER(WHERE
    d.schedule_version=s.version
    AND cr.qualified_configuration_id=s.configuration_id
    AND cr.employment_status='verified_employed')::int AS registered_count,
   count(d.crew_id) FILTER(WHERE
    d.schedule_version<>s.version)::int AS stale_total
  FROM entries e
  LEFT JOIN airlinerra_game.section9_weekly_crew_duty_proposals_v1 d
   ON d.schedule_id=s.id AND d.weekly_entry=e.entry
  LEFT JOIN airlinerra_game.section9_airline_crew_roster_v1 cr
   ON cr.crew_id=d.crew_id AND cr.airline_id=p_airline
  GROUP BY e.entry
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'weeklyEntry',entry,'proposed',proposed_total,
   'registeredVerifiedEmployment',registered_count,
   'missingRegisteredCrew',CASE WHEN crew_required IS NULL THEN NULL
     ELSE greatest(0,crew_required-registered_count) END,
   'outdatedAssignments',stale_total)
  ORDER BY entry),'[]'::jsonb),
  count(*) FILTER(WHERE crew_required IS NULL
   OR registered_count<crew_required)::int,
  coalesce(sum(registered_count),0)::int,
  coalesce(sum(proposed_total),0)::int,
  coalesce(sum(stale_total),0)::int
 INTO crew_details,insufficient_days,qualified_count,proposed_count,stale_count
 FROM counts;

 -- Multiple scheduled routes with the same crew are NOT necessarily
 -- overlapping. Report all reuse for duty rest/concurrency validation.
 -- No fake "conflict-free" certification is issued from this count.
 SELECT count(*)::int INTO possible_other_routes
 FROM airlinerra_game.section9_weekly_crew_duty_proposals_v1 d
 WHERE d.airline_id=p_airline AND d.schedule_id<>s.id
 AND EXISTS(
   SELECT 1 FROM airlinerra_game.section9_weekly_crew_duty_proposals_v1 own
   WHERE own.schedule_id=s.id AND own.crew_id=d.crew_id
 );

 SELECT o.* INTO approved_operator
 FROM airlinerra_game.section9_operator_licence_evidence_v1 o
 WHERE o.world_id=1 AND o.airline_id=p_airline
  AND o.jurisdiction_iso2=country_hint
  AND o.evidence_status='verified'
  AND o.reviewed_at IS NOT NULL
  AND o.valid_from<=p_date
  AND (o.valid_until IS NULL OR o.valid_until>=p_date+p_days)
 ORDER BY o.reviewed_at DESC LIMIT 1;

 WITH needed AS (
  SELECT x.role
  FROM unnest(CASE s.use_type
    WHEN 'cargo' THEN ARRAY['cargo']::text[]
    WHEN 'combi' THEN ARRAY['passenger','cargo']::text[]
    ELSE ARRAY['passenger']::text[] END) AS x(role)
 ), checks AS (
  SELECT n.role,
   EXISTS(SELECT 1 FROM
    airlinerra_game.section9_route_operating_permission_evidence_v1 e
    WHERE e.world_id=1 AND e.airline_id=p_airline
      AND e.origin_airport_key=s.origin_airport_key
      AND e.destination_airport_key=s.destination_airport_key
      AND e.service_type=n.role AND e.evidence_status='verified'
      AND e.reviewed_at IS NOT NULL AND e.valid_from<=p_date
      AND (e.valid_until IS NULL OR e.valid_until>=p_date+p_days)
   ) AS evidence_present
  FROM needed n
 )
 SELECT count(*),count(*) FILTER(WHERE evidence_present),
 coalesce(jsonb_agg(jsonb_build_object('serviceType',role,
  'privatelyReviewedRecordPresent',evidence_present)
  ORDER BY role),'[]'::jsonb)
 INTO required_rights,approved_rights,permissions
 FROM checks;

 RETURN jsonb_build_object(
  'status','STAFFING_AND_PERMISSION_NOT_OPERATIONALLY_CERTIFIED',
  'scheduleId',s.id,'scheduleVersion',s.version,
  'crew',jsonb_build_object(
   'catalogCrewRequirement',crew_required,
   'catalogCrewRequirementKnown',crew_required IS NOT NULL,
   'weeklyEntries',crew_details,
   'entriesMissingRegisteredCrew',insufficient_days,
   'registeredEmployeeAssignments',qualified_count,
   'proposedAssignments',proposed_count,
   'staleAssignments',stale_count,
   'otherRouteReuseNeedsConflictAndRestChecks',possible_other_routes,
   'dutyRestAndQualificationsOperationallyCertified',false,
   'flightCrewAuthorized',false),
  'permissions',jsonb_build_object(
   'operatorJurisdictionHint',country_hint,
   'gameOperatorLicenceEvidenceRecorded',approved_operator.licence_id IS NOT NULL,
   'requiredServiceTypes',required_rights,
   'gameRoutePermissionEvidenceRecorded',approved_rights,
   'individualServiceTypes',permissions,
   'legalOperatingLicenceIndependentlyConfirmed',false,
   'trafficRightsOperationallyGranted',false),
  'gameDate',p_date,'previewDays',p_days,
  'readOnly',true,'canActivateNormalFlight',false);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_owned_crew_licence_preflight_v1(
 uuid,uuid,uuid,date,integer) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_crew_roster_preview_v1(
 p_player uuid,p_airline uuid,p_schedule uuid
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE sid uuid;conf bigint;version integer; members jsonb; proposals jsonb;
BEGIN
 SELECT s.id,s.configuration_id,s.version INTO sid,conf,version
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a ON a.id=s.airline_id
  AND a.owner_player_id=p_player AND a.world_id=1
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND s.world_id=1;
 IF sid IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_ROSTER_SCHEDULE_NOT_OWNED';END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
  'crewId',c.crew_id,'crewReference',c.crew_reference,
  'employmentStatus',c.employment_status,
  'aircraftQualificationMatches',c.qualified_configuration_id=conf)
  ORDER BY c.crew_reference),'[]'::jsonb) INTO members
 FROM (
  SELECT crew_id,crew_reference,employment_status,qualified_configuration_id
  FROM airlinerra_game.section9_airline_crew_roster_v1
  WHERE world_id=1 AND airline_id=p_airline
  ORDER BY crew_reference LIMIT 200
 ) c;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
  'crewId',d.crew_id,'weeklyEntry',d.weekly_entry,
  'scheduleVersion',d.schedule_version,
  'stale',d.schedule_version<>version)
 ORDER BY d.weekly_entry,d.crew_id),'[]'::jsonb) INTO proposals
 FROM airlinerra_game.section9_weekly_crew_duty_proposals_v1 d
 WHERE d.airline_id=p_airline AND d.schedule_id=sid;
 RETURN jsonb_build_object(
  'status','crew_roster_planning_only','scheduleId',sid,
  'crewAvailableForPlanning',members,'proposals',proposals,
  'crewEmploymentNotUserVerifiable',true,
  'canActivateNormalFlight',false,'readOnly',true);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_owned_crew_roster_preview_v1(
 uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;

-- Preserve older operations evidence and add separately sourced records.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_operations_with_crew_rights_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,p_date date,p_days integer DEFAULT 28
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE base jsonb;staff jsonb;
BEGIN
 base:=airlinerra_game.section9_owned_operational_preflight_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 staff:=airlinerra_game.section9_owned_crew_licence_preflight_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 IF base->>'readOnly'<>'true' OR base->>'canActivateNormalFlight'<>'false'
 OR staff->>'readOnly'<>'true' OR staff->>'canActivateNormalFlight'<>'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_UNSAFE_OPERATING_EVIDENCE';END IF;
 RETURN base || jsonb_build_object(
  'crewStaffing',staff->'crew',
  'operatingPermissionEvidence',staff->'permissions',
  'canActivateNormalFlight',false,'readOnly',true);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_owned_operations_with_crew_rights_v1(
 uuid,uuid,uuid,date,integer) FROM PUBLIC,anon,authenticated;
