-- Compose immutable operated-flight movement history with the existing owner-scoped operational readiness.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_operations_with_crew_rights_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,p_date date,
 p_days integer DEFAULT 28
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE base jsonb; staff jsonb; rest jsonb; position jsonb; movement jsonb;
 reasons jsonb;
BEGIN
 base:=airlinerra_game.section9_owned_operational_preflight_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 staff:=airlinerra_game.section9_owned_crew_licence_preflight_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 rest:=airlinerra_game.section9_owned_crew_rest_preview_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 position:=airlinerra_game.section9_owned_aircraft_delivery_position_preview_v1(
  p_player,p_airline,p_schedule,p_date,p_days);
 movement:=airlinerra_game.section9_owned_aircraft_movement_preview_v1(
  p_player,p_airline,p_schedule);
 IF base->>'readOnly'<>'true' OR base->>'canActivateNormalFlight'<>'false'
 OR staff->>'readOnly'<>'true' OR staff->>'canActivateNormalFlight'<>'false'
 OR rest->>'readOnly'<>'true' OR rest->>'canActivateNormalFlight'<>'false'
 OR position->>'readOnly'<>'true' OR
    position->>'canActivateNormalFlight'<>'false'
 OR movement->>'readOnly'<>'true' OR
    movement->>'canActivateNormalFlight'<>'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_UNSAFE_OPERATING_EVIDENCE';END IF;

 reasons:=coalesce(base->'blockers','[]'::jsonb)
  || to_jsonb(ARRAY[
    CASE WHEN position->>'deliveryAnchorRecorded'<>'true' THEN
      'DELIVERY_POSITION_ANCHOR_NOT_RECORDED'
     WHEN position->>'status'='first_departure_airport_mismatch' THEN
      'FIRST_PLANNED_DEPARTURE_AT_WRONG_AIRPORT'
     WHEN position->>'status'='timetable_evidence_incomplete' OR
          position->>'status'='invalid_initial_departure_time' THEN
      'AIRCRAFT_DEPARTURE_TIME_UNVERIFIED'
     ELSE 'INITIAL_POSITION_NOT_OPERATIONALLY_CERTIFIED' END,
    CASE WHEN movement->>'operatedFlightEvidencePresent'='true'
      THEN 'LIVE_FLIGHT_OPERATIONS_NOT_RELEASED'
      ELSE 'OPERATED_AIRCRAFT_MOVEMENT_HISTORY_MISSING' END
   ]);
 RETURN base || jsonb_build_object(
  'crewStaffing',staff->'crew',
  'operatingPermissionEvidence',staff->'permissions',
  'crewRest',rest,
  'aircraftPosition',position,
  'aircraftMovement',movement,
  'blockers',reasons,
  'canActivateNormalFlight',false,'readOnly',true);
END $f$;
REVOKE EXECUTE ON FUNCTION
 airlinerra_game.section9_owned_operations_with_crew_rights_v1(
 uuid,uuid,uuid,date,integer)
 FROM PUBLIC,anon,authenticated;
