-- Phase 1 commercial preflight: position uses authoritative starter allocation
-- before the first flight, then the last verified movement. Crew is deferred
-- without bypassing slots, rights, fuel, release or trusted execution.
-- Remains READ ONLY and cannot activate any schedule or book passengers.
BEGIN;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_commercial_activation_preflight_v1(p_player uuid, p_airline uuid, p_schedule uuid, p_date date, p_days integer DEFAULT 28)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 schedule_row record;
 operations jsonb; rest_report jsonb; delivery jsonb;
 verified_position jsonb; crew_deferred boolean;
 movements jsonb; world_clock jsonb; restrictions jsonb;
 staffing jsonb; rights jsonb; rotation jsonb;
 blockers text[]:=ARRAY[]::text[];
 slots_recorded boolean; rotation_clear boolean; crew_proposed boolean;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_schedule IS NULL OR
    p_date IS NULL OR p_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
    OR p_days NOT BETWEEN 7 AND 42
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_ACTIVATION_PREFLIGHT_REQUEST';END IF;

 -- Verify ownership BEFORE consulting private evidence, even when the
 -- caller supplies a different airline's schedule ID.
 SELECT s.id,s.aircraft_inventory_id,s.status,s.operationally_verified,s.version,
        s.origin_airport_key
 INTO schedule_row
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a ON a.id=s.airline_id
  AND a.owner_player_id=p_player AND a.world_id=1
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND s.world_id=1;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_ACTIVATION_PREFLIGHT_SCHEDULE_NOT_OWNED';END IF;

 operations:=airlinerra_game.section9_owned_operations_with_crew_rights_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 rest_report:=airlinerra_game.section9_owned_crew_rest_preview_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 delivery:=airlinerra_game.section9_owned_aircraft_delivery_position_preview_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 movements:=airlinerra_game.section9_owned_aircraft_movement_preview_v1(
  p_player,p_airline,p_schedule);
 verified_position:=airlinerra_game.section9_owned_aircraft_operational_position_v1(
  p_player,p_airline,schedule_row.aircraft_inventory_id,p_date);
 SELECT coalesce(
  (SELECT pol.crew_mode='deferred_phase1'
   FROM airlinerra_game.section9_activation_release_policy_v1 pol
   WHERE pol.world_id=1),true)
 INTO crew_deferred;
 world_clock:=airlinerra_game.section9_world_clock_dispatch_readiness_v1(1::smallint);
 restrictions:=airlinerra_game.section5_schedule_activation_readiness_v1(
  p_player,p_schedule);

 -- Fail closed if any existing evidence source changes its contract.
 IF operations->>'readOnly' IS DISTINCT FROM 'true'
 OR operations->>'canActivateNormalFlight' IS DISTINCT FROM 'false'
 OR rest_report->>'readOnly' IS DISTINCT FROM 'true'
 OR rest_report->>'canActivateNormalFlight' IS DISTINCT FROM 'false'
 OR delivery->>'readOnly' IS DISTINCT FROM 'true'
 OR delivery->>'canActivateNormalFlight' IS DISTINCT FROM 'false'
 OR movements->>'readOnly' IS DISTINCT FROM 'true'
 OR movements->>'canActivateNormalFlight' IS DISTINCT FROM 'false'
 OR verified_position->>'readOnly' IS DISTINCT FROM 'true'
 OR verified_position->>'flightActivated' IS DISTINCT FROM 'false'
 OR world_clock->>'readOnly' IS DISTINCT FROM 'true'
 OR restrictions->>'canActivateNormalFlight' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_ACTIVATION_PREFLIGHT_UNSAFE_EVIDENCE';END IF;

 staffing:=operations->'crewStaffing';
 rights:=operations->'operatingPermissionEvidence';
 rotation:=operations->'rotation';
 slots_recorded:=(rotation->'slotsRecorded'->>'departure') IS NOT DISTINCT FROM 'true'
   AND (rotation->'slotsRecorded'->>'arrival') IS NOT DISTINCT FROM 'true';
 rotation_clear:=coalesce((rotation->>'overlappingFlights')::integer,-1)=0
  AND coalesce((rotation->>'wrongAirportDepartures')::integer,-1)=0
  AND coalesce((rotation->>'daylightSavingTimeIssues')::integer,-1)=0
  AND coalesce((rotation->>'invalidWeeklyEntries')::integer,-1)=0
  AND coalesce((rotation->>'unknownOriginTimezones')::integer,-1)=0
  AND coalesce((rotation->>'targetOccurrences')::integer,0)>0;
 -- Crew-rights composite exposes crewStaffing as the inner crew object.
 crew_proposed:=coalesce((staffing->>'entriesMissingRegisteredCrew')::integer,-1)=0
  AND coalesce((staffing->>'registeredEmployeeAssignments')::integer,0)>0
  AND coalesce((rest_report->>'unverifiedOrStaleAssignments')::integer,-1)=0;

 IF schedule_row.status<>'active' OR schedule_row.operationally_verified IS DISTINCT FROM true
 THEN blockers:=array_append(blockers,'SCHEDULE_IS_DRAFT_NOT_CERTIFIED');END IF;
 IF world_clock->>'clockConnected' IS DISTINCT FROM 'true'
 THEN blockers:=array_append(blockers,'WORLD_CLOCK_NOT_OPERATIONAL');END IF;
 IF restrictions->>'restrictionPreflightPassed' IS DISTINCT FROM 'true'
 THEN blockers:=array_append(blockers,'AIRPORT_RESTRICTION_GATE_NOT_CLEARED');END IF;
 IF NOT rotation_clear
 THEN blockers:=array_append(blockers,'AIRCRAFT_ROTATION_HAS_CONFLICTS_OR_UNKNOWN_DATA');END IF;
 IF (operations->'turnaround'->>'shortTurnaroundOccurrences')::integer IS DISTINCT FROM 0
  OR operations->'turnaround'->>'minimumMinutes' IS NULL
 THEN blockers:=array_append(blockers,'TURNAROUND_NOT_VERIFIED');END IF;
 IF slots_recorded IS DISTINCT FROM true
 THEN blockers:=array_append(blockers,'DEPARTURE_AND_ARRIVAL_SLOTS_NOT_RECORDED');END IF;
 IF movements->>'deliveryAnchorValid' IS DISTINCT FROM 'true'
  OR verified_position->>'verified' IS DISTINCT FROM 'true'
 THEN blockers:=array_append(blockers,'VERIFIED_INITIAL_AIRCRAFT_LOCATION_MISSING');END IF;
 IF movements->>'locationStatus'='in_flight'
 THEN blockers:=array_append(blockers,'AIRCRAFT_CURRENTLY_IN_FLIGHT');END IF;
 IF NOT crew_deferred AND NOT crew_proposed
 THEN blockers:=array_append(blockers,'CREW_ASSIGNMENTS_INCOMPLETE_OR_STALE');END IF;
 IF NOT crew_deferred AND (coalesce((rest_report->>'overlapConflicts')::integer,-1)<>0
  OR coalesce((rest_report->>'insufficientRest')::integer,-1)<>0
  OR coalesce((rest_report->>'crewWrongAirport')::integer,-1)<>0
  OR coalesce((rest_report->>'overlongDuty')::integer,-1)<>0
  OR coalesce((rest_report->>'invalidLocalDeparture')::integer,-1)<>0)
 THEN blockers:=array_append(blockers,'CREW_REST_AND_DUTY_PREVIEW_HAS_CONFLICTS');END IF;
 IF rights->>'gameOperatorLicenceEvidenceRecorded' IS DISTINCT FROM 'true'
 THEN blockers:=array_append(blockers,'OPERATOR_LICENCE_EVIDENCE_MISSING');END IF;
 IF coalesce((rights->>'requiredServiceTypes')::integer,-1)<>
    coalesce((rights->>'gameRoutePermissionEvidenceRecorded')::integer,-2)
 THEN blockers:=array_append(blockers,'ROUTE_TRAFFIC_PERMISSION_EVIDENCE_MISSING');END IF;
 -- Recorded evidence and provisional policies are NOT operational releases.
 IF NOT crew_deferred THEN
  blockers:=array_append(blockers,'CREW_DUTY_NOT_OPERATIONALLY_CERTIFIED');
 END IF;
 blockers:=array_append(blockers,'AIRPORT_SLOT_CAPACITY_NOT_CERTIFIED_FOR_ACTIVATION');
 blockers:=array_append(blockers,'OPERATOR_LICENCE_AND_TRAFFIC_RIGHTS_NOT_GRANTED');
 blockers:=array_append(blockers,'TRUSTED_FLIGHT_EXECUTION_PRODUCER_NOT_CONNECTED');
 blockers:=array_append(blockers,'COMMERCIAL_FLIGHT_ACTIVATION_NOT_RELEASED');

 RETURN operations || jsonb_build_object(
  'status','BLOCKED_COMMERCIAL_ACTIVATION_NOT_RELEASED',
  'scheduleId',schedule_row.id,
  'scheduleVersion',schedule_row.version,
  'startDate',p_date,'previewDays',p_days,
  'readOnly',true,'canActivateNormalFlight',false,
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false,
  'activationChecklist',jsonb_build_object(
   'draftOnly',schedule_row.status='draft',
   'airportRestrictionPreviewPassed',restrictions->>'restrictionPreflightPassed'='true',
   'aircraftRotationPreviewConflictFree',rotation_clear,
   'departureArrivalSlotRecordsPresent',slots_recorded,
   'aircraftDeliveryAnchorVerified',
      movements->>'deliveryAnchorValid'='true'
      AND verified_position->>'verified'='true',
   'initialGamePositionVerified',
      verified_position->>'verified'='true'
      AND verified_position->>'initialOnly'='true',
   'lastVerifiedGroundAirport',CASE
      WHEN verified_position->>'verified'='true'
       AND verified_position->>'atGroundAirport'='true'
      THEN verified_position->>'airportKey'
      ELSE NULL END,
   'aircraftInFlight',movements->>'locationStatus'='in_flight',
   'proposedCrewAssignmentsComplete',crew_proposed,
   'crewRequired',NOT crew_deferred,
   'crewDeferredPhase1',crew_deferred,
   'crewRestPreviewConflictFree',
       coalesce((rest_report->>'overlapConflicts')::integer,-1)=0
       AND coalesce((rest_report->>'insufficientRest')::integer,-1)=0
       AND coalesce((rest_report->>'crewWrongAirport')::integer,-1)=0
       AND coalesce((rest_report->>'overlongDuty')::integer,-1)=0
       AND coalesce((rest_report->>'invalidLocalDeparture')::integer,-1)=0,
   'operatorLicenceEvidenceRecorded',
       rights->>'gameOperatorLicenceEvidenceRecorded'='true',
   'routePermissionEvidenceComplete',
       coalesce((rights->>'requiredServiceTypes')::integer,-1)=
       coalesce((rights->>'gameRoutePermissionEvidenceRecorded')::integer,-2),
   'worldClockConnected',world_clock->>'clockConnected'='true',
   'crewLegallyAuthorized',false,
   'trafficRightsOperationallyGranted',false,
   'slotCapacityCertifiedForFlightRelease',false,
   'trustedFlightExecutionProducerConnected',false,
   'operationalActivationReleased',false),
  'activationBlockers',to_jsonb(blockers),
  'crewRest',rest_report,
  'aircraftDeliveryPosition',delivery,
  'aircraftMovement',movements,
  'verifiedAircraftPosition',verified_position,
  'worldClock',world_clock,
  'currentAirportRestrictionCheck',restrictions);
END $function$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_commercial_activation_preflight_v1(uuid,uuid,uuid,date,integer)
 FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
