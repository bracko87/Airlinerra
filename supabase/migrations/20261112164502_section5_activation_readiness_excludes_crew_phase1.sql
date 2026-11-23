-- Section 5's read-only player-facing activation preview must not
-- report crew as a blocker in first-release game operations.
-- Does not activate, mutate, or certify any flight.
BEGIN;
CREATE OR REPLACE FUNCTION airlinerra_game.section5_schedule_activation_readiness_v1(p_player_id uuid, p_schedule_id uuid)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 plan record; status jsonb;
BEGIN
 SELECT s.*,a.owner_player_id,f.fleet_status,f.configuration_id AS current_configuration_id
 INTO plan
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a ON a.id=s.airline_id
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id
 WHERE s.id=p_schedule_id AND a.owner_player_id=p_player_id;
 IF NOT FOUND THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='FLIGHT_SCHEDULE_NOT_OWNED_BY_VERIFIED_PLAYER';
 END IF;
 IF plan.fleet_status<>'in_service' OR plan.current_configuration_id<>plan.configuration_id THEN
  RETURN jsonb_build_object('status','BLOCKED_AIRCRAFT_UNAVAILABLE',
   'canActivateNormalFlight',false,'reasons',jsonb_build_array('AIRCRAFT_NOT_IN_SERVICE_OR_CONFIGURATION_CHANGED'));
 END IF;
 status:=airlinerra_game.section5_weekly_route_restriction_gate_v1(
  plan.world_id,plan.origin_airport_key,plan.destination_airport_key,
  plan.configuration_id,plan.reference_departure_utc,
  plan.reference_arrival_utc,plan.weekly_schedule);
 IF status IS NULL OR (status->>'gameHardBlocked')::boolean IS DISTINCT FROM false
   OR status->>'weeklyTimetableChecked'<>'true' THEN
  RETURN jsonb_build_object('status','BLOCKED_AIRPORT_AIRCRAFT_RESTRICTIONS',
   'canActivateNormalFlight',false,
   'decision',coalesce(status->>'decision','UNVERIFIED'),
   'reasons',jsonb_build_array('MANDATORY_RESTRICTION_SCREEN_FAILED'));
 END IF;
 RETURN jsonb_build_object('status','BLOCKED_OPERATIONAL_SYSTEMS_NOT_CONNECTED',
  'scheduleId',plan.id,'canActivateNormalFlight',false,
  'restrictionPreflightPassed',true,
  'restrictionReviewPending',coalesce((status->>'needsReview')::boolean,true),
  'reasons',jsonb_build_array(
    'FLEET_POSITION_AND_ROTATION_NOT_VERIFIED',
    'AIRPORT_SLOTS_AND_TRAFFIC_RIGHTS_NOT_CONNECTED',
    'FLIGHT_DURATION_AND_RECURRENCE_ENGINE_NOT_CONNECTED',
    'OPERATIONAL_FLIGHT_ACTIVATION_NOT_RELEASED'),
  'note','Only a validated schedule draft exists. This function does not activate any flight.');
END;
$function$;
COMMIT;
