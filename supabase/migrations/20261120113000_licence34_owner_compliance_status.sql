-- Read-only owner-facing compliance summary for Licences 3 and 4.
CREATE OR REPLACE FUNCTION airlinerra_game.licence34_operator_status_v1(
 p_airline uuid,p_licence text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE d date; threshold integer; rating integer; fleet_count integer;
 recorded boolean:=false;revoked boolean:=false;auth boolean:=false;
 since_day date; revoked_day date; stage text; remaining integer;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE34_OWNER_VERIFIED_STATUS_ONLY';
 END IF;
 IF p_airline IS NULL OR p_licence NOT IN('CARGO_OPERATIONS_SCOPE','CHARTER_VIP_SCOPE') THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='LICENCE34_INVALID_COMPANY_STATUS_REQUEST';
 END IF;
 d:=airlinerra_game.section9_verified_permission_game_day_v1();
 threshold:=CASE WHEN p_licence='CARGO_OPERATIONS_SCOPE' THEN 50 ELSE 70 END;
 SELECT EXISTS(SELECT 1 FROM airlinerra_game.licence3_cargo_approvals_v1
  WHERE airline_id=p_airline AND p_licence='CARGO_OPERATIONS_SCOPE')
 OR EXISTS(SELECT 1 FROM airlinerra_game.licence4_charter_approvals_v1
  WHERE airline_id=p_airline AND p_licence='CHARTER_VIP_SCOPE') INTO recorded;
 SELECT h.no_aircraft_since_game_day,h.revoked_game_day INTO since_day,revoked_day
 FROM airlinerra_game.licence34_company_compliance_v1 h
 WHERE h.airline_id=p_airline AND h.licence_code=p_licence;
 revoked:=revoked_day IS NOT NULL;
 SELECT count(*) INTO fleet_count FROM airlinerra_game.airline_aircraft_inventory i
 JOIN airlinerra_game.section5_aircraft_engine_and_icao_game_library_v1 model
 ON model.configuration_id=i.configuration_id
 WHERE i.airline_id=p_airline AND i.fleet_status='in_service'
 AND ((p_licence='CARGO_OPERATIONS_SCOPE' AND model.use_type IN ('cargo','combi'))
 OR (p_licence='CHARTER_VIP_SCOPE' AND model.use_type IN('passenger','combi')));
 IF d IS NOT NULL THEN
  rating:=(airlinerra_game.section9_aoc_safety_score_v1(p_airline,d)->>'rating')::integer;
  auth:=CASE WHEN p_licence='CARGO_OPERATIONS_SCOPE'
   THEN (airlinerra_game.licence3_cargo_flight_scope_v1(p_airline)->>'authorized')::boolean
   ELSE (airlinerra_game.licence4_charter_flight_scope_v1(p_airline)->>'authorized')::boolean END;
 END IF;
 remaining:=CASE WHEN since_day IS NULL OR d IS NULL OR fleet_count>0 OR revoked
  THEN NULL ELSE greatest(0,90-(d-since_day)) END;
 stage:=CASE
 WHEN NOT recorded THEN 'NOT_ISSUED'
 WHEN revoked THEN 'REVOKED'
 WHEN d IS NULL THEN 'SUSPENDED_UNVERIFIED_GAME_CLOCK'
 WHEN rating<threshold THEN 'SUSPENDED_SAFETY'
 WHEN fleet_count=0 THEN 'SUSPENDED_NO_AIRCRAFT'
 WHEN auth THEN 'ACTIVE'
 ELSE 'SUSPENDED_OTHER_REQUIREMENTS' END;
 RETURN jsonb_build_object(
 'airlineId',p_airline,'licenceCode',p_licence,'status',stage,
 'licenceRecorded',recorded,'revoked',revoked,'revokedGameDay',revoked_day,
 'minimumSafetyRating',threshold,'safetyRating',rating,
 'operationalSuitableAircraftCount',fleet_count,
 'aircraftAbsenceSinceGameDay',since_day,'aircraftGraceDaysRemaining',remaining,
 'operationsAuthorized',auth,'gameDay',d,'flightActivated',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.licence34_operator_status_v1(uuid,text)
 FROM PUBLIC,anon,authenticated,service_role;
