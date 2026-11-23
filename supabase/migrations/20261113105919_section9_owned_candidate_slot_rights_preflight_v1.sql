-- World1 Phase1: read-only candidate operating route slot + traffic rights preflight.
-- This is NOT an operational schedule or any form of reserved capacity/permit.
-- Existing weekly-slot engine and issuance-ledger gate are reused; no writes.
BEGIN;
CREATE FUNCTION airlinerra_game.section9_owned_candidate_slot_rights_preflight_v1(
 p_player uuid,p_airline uuid,p_aircraft uuid,
 p_origin text,p_destination text,
 p_departure timestamptz,p_arrival timestamptz,
 p_weekly jsonb,p_departure_stand text,p_arrival_stand text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $fn$
DECLARE
 v_now timestamptz;
 target record;
 game_day date;
 roles text[];
 role_name text;
 permission_code text;
 permission_ok boolean;
 slot_preview jsonb:=NULL;
 restrict_preview jsonb:=NULL;
 slot_available boolean:=false;
 rights_granted integer:=0;
 blockers text[]:=ARRAY[]::text[];
 details jsonb:='[]'::jsonb;
 owner_world integer:=0;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL
  OR p_origin IS NULL OR p_destination IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='SECTION9_INVALID_CANDIDATE_ROUTE_IDENTITY';END IF;

 SELECT a.owner_player_id,a.world_id,
        home.country_iso AS operator_country,
        o.country_iso AS origin_country,
        d.country_iso AS destination_country,
        f.fleet_status,f.ownership_type,f.configuration_id,c.use_type
 INTO target
 FROM airlinerra_game.airline_aircraft_inventory f
 JOIN airlinerra_game.airlines a ON a.id=f.airline_id
 JOIN airlinerra_game.world_memberships w
  ON w.world_id=a.world_id AND w.player_id=a.owner_player_id AND w.state='active'
 JOIN airlinerra.aircraft_configurations c ON c.id=f.configuration_id
 LEFT JOIN airlinerra_game.airport_reference_profiles home
  ON home.world_id=1 AND home.airport_key=a.home_airport_key
 LEFT JOIN airlinerra_game.airport_reference_profiles o
  ON o.world_id=1 AND o.airport_key=p_origin
 LEFT JOIN airlinerra_game.airport_reference_profiles d
  ON d.world_id=1 AND d.airport_key=p_destination
 WHERE f.id=p_aircraft AND f.airline_id=p_airline
   AND a.owner_player_id=p_player AND a.world_id=1;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='SECTION9_CANDIDATE_ROUTE_NOT_OWNED';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 game_day:=(v_now AT TIME ZONE 'Europe/Berlin')::date;
 IF target.fleet_status IS DISTINCT FROM 'in_service'
 OR target.ownership_type NOT IN ('owned','leased')
 THEN blockers:=array_append(blockers,'AIRCRAFT_NOT_ELIGIBLE_FOR_ROUTE');END IF;
 IF p_origin=p_destination OR
  target.operator_country IS NULL OR
  target.origin_country IS NULL OR
  target.destination_country IS NULL OR
  target.origin_country !~ '^[A-Z]{2}$' OR
  target.destination_country !~ '^[A-Z]{2}$'
 THEN blockers:=array_append(blockers,'ROUTE_COUNTRIES_OR_AIRPORTS_UNVERIFIED');END IF;
 IF (SELECT count(*) FROM airlinerra_game.approved_game_airports airport
     WHERE airport.world_id=1 AND airport.airport_key IN (p_origin,p_destination))<>2
 THEN blockers:=array_append(blockers,'AIRPORT_NOT_ADMITTED_TO_WORLD1');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1 g
    WHERE g.airport_key IN(p_origin,p_destination))
 THEN blockers:=array_append(blockers,'GROUP2_AIRPORT_NOT_OPERATIONALLY_ADMITTED');END IF;

 IF p_departure IS NULL OR p_arrival IS NULL OR
  p_departure<=v_now OR p_departure>v_now+interval '42 days' OR
  p_arrival<=p_departure OR p_arrival>p_departure+interval '72 hours'
 THEN blockers:=array_append(blockers,'REFERENCE_UTC_DEPARTURE_AND_ARRIVAL_REQUIRED');END IF;
 IF p_departure_stand NOT IN ('terminal','remote','cargo') OR
  p_arrival_stand NOT IN ('terminal','remote','cargo') OR
  p_departure_stand IS NULL OR p_arrival_stand IS NULL
 THEN blockers:=array_append(blockers,'AIRPORT_STAND_TYPE_NOT_CONFIRMED');END IF;
 IF p_weekly IS NULL OR jsonb_typeof(p_weekly)<>'array' OR
   jsonb_array_length(p_weekly) NOT BETWEEN 1 AND 7
 THEN blockers:=array_append(blockers,'WEEKLY_FLIGHT_SCHEDULE_UNVERIFIED');END IF;

 IF NOT ('REFERENCE_UTC_DEPARTURE_AND_ARRIVAL_REQUIRED'=ANY(blockers)
   OR 'AIRPORT_STAND_TYPE_NOT_CONFIRMED'=ANY(blockers)
   OR 'WEEKLY_FLIGHT_SCHEDULE_UNVERIFIED'=ANY(blockers)
   OR 'AIRPORT_NOT_ADMITTED_TO_WORLD1'=ANY(blockers)
   OR 'GROUP2_AIRPORT_NOT_OPERATIONALLY_ADMITTED'=ANY(blockers))
 THEN
  slot_preview:=airlinerra_game.section6_weekly_slot_preflight_v1(
   1::smallint,p_origin,p_destination,p_departure,p_arrival,
   p_weekly,p_departure_stand,p_arrival_stand,NULL);
  restrict_preview:=airlinerra_game.section5_weekly_route_restriction_gate_v1(
   1::smallint,p_origin,p_destination,target.configuration_id,
   p_departure,p_arrival,p_weekly);
  slot_available:=
    slot_preview->>'available'='true' AND
    slot_preview->>'departureAvailable'='true' AND
    slot_preview->>'arrivalAvailable'='true' AND
    coalesce((slot_preview->>'windowsChecked')::integer,0)>=2;
  IF NOT slot_available THEN
   blockers:=array_append(blockers,'AIRPORT_WEEKLY_SLOT_CAPACITY_NOT_AVAILABLE');END IF;
  IF restrict_preview->>'weeklyTimetableChecked' IS DISTINCT FROM 'true'
    OR restrict_preview->>'gameHardBlocked' IS DISTINCT FROM 'false'
    OR restrict_preview->>'needsReview' IS DISTINCT FROM 'false'
  THEN blockers:=array_append(blockers,'AIRPORT_GAME_RESTRICTIONS_NOT_CLEARED');END IF;
 END IF;

 roles:=CASE target.use_type
  WHEN 'passenger' THEN ARRAY['passenger']::text[]
  WHEN 'cargo' THEN ARRAY['cargo']::text[]
  WHEN 'combi' THEN ARRAY['passenger','cargo']::text[]
  ELSE ARRAY[]::text[] END;
 IF cardinality(roles)=0 THEN
  blockers:=array_append(blockers,'AIRCRAFT_GAME_SERVICE_TYPE_UNVERIFIED');END IF;
 FOREACH role_name IN ARRAY roles LOOP
  permission_code:=airlinerra_game.section9_required_game_traffic_permission_v1(
   target.operator_country,target.origin_country,target.destination_country,
   role_name,game_day);
  permission_ok:=false;
  IF permission_code IS NOT NULL THEN
   SELECT EXISTS(
    SELECT 1 FROM airlinerra_game.section9_route_operating_permission_evidence_v1 evidence
    JOIN airlinerra_game.section9_game_permission_applications_v1 app
      ON app.id=evidence.issued_application_id AND app.airline_id=evidence.airline_id
    JOIN airlinerra_game.business_permission_catalog_v1 catalog
      ON catalog.permission_code=permission_code
    WHERE evidence.world_id=1 AND evidence.airline_id=p_airline
      AND evidence.origin_airport_key=p_origin
      AND evidence.destination_airport_key=p_destination
      AND evidence.service_type=role_name
      AND evidence.evidence_status='verified'
      AND evidence.reviewed_at IS NOT NULL AND evidence.reviewed_at<=v_now
      AND length(evidence.evidence_reference)>=16
      AND evidence.valid_from<=game_day AND evidence.valid_until>=game_day+28
      AND app.world_id=1 AND app.status='issued'
      AND app.permission_code=permission_code
      AND app.origin_airport_key=p_origin
      AND app.destination_airport_key=p_destination
      AND app.service_type=role_name
      AND app.issued_game_date=evidence.valid_from
      AND app.valid_until_game_date=evidence.valid_until
      AND app.ledger_entry_id IS NOT NULL
      AND evidence.evidence_reference='game-permission-issued-v1-'||app.id::text
      AND catalog.category='traffic_rights' AND catalog.holder_scope='route'
      AND catalog.enabled_in_game=true
   ) INTO permission_ok;
  END IF;
  IF NOT permission_ok THEN
   blockers:=array_append(blockers,
    CASE WHEN permission_code IS NULL
      THEN 'ROUTE_GAME_TRAFFIC_CLASSIFICATION_UNVERIFIED'
      ELSE upper(role_name)||'_GAME_TRAFFIC_RIGHTS_NOT_GRANTED' END);
  ELSE rights_granted:=rights_granted+1; END IF;
  details:=details||jsonb_build_array(jsonb_build_object(
   'serviceType',role_name,'requiredGamePermission',permission_code,
   'issuedGameGrantVerified',permission_ok));
 END LOOP;

 -- Operator licence remains schedule/version scoped; no candidate-only
 -- preview may assert it has been granted. Nothing is committed here.
 blockers:=array_append(blockers,
   'OPERATOR_LICENCE_AND_ATOMIC_SLOT_RESERVATION_NOT_ACTIVATED');
 RETURN jsonb_build_object(
 'status','candidate_operating_route_preflight_only',
 'worldId',1,'gameDate',game_day,
 'readOnly',true,
 'airportSlotCapacityPreviewAvailable',slot_available,
 'airportSlotsReserved',false,
 'airportRestrictionGateChecked',restrict_preview IS NOT NULL,
 'requiredServiceTypes',roles,'verifiedGameTrafficGrants',rights_granted,
 'gameTrafficGrantDetails',details,
 'trafficRightsOperationallyApproved',false,
 'operatorLicenceOperationallyVerified',false,
 'operatingScheduleCreated',false,'flightActivated',false,
 'bookingEnabled',false,'passengerBookingsCreated',false,
 'ledgerPosted',false,'operationallyApproved',false,
 'blockers',to_jsonb(blockers));
END $fn$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_owned_candidate_slot_rights_preflight_v1(
 uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,text,text)
 FROM PUBLIC,anon,authenticated,service_role;
COMMENT ON FUNCTION
 airlinerra_game.section9_owned_candidate_slot_rights_preflight_v1(
 uuid,uuid,uuid,text,text,timestamptz,timestamptz,jsonb,text,text) IS
 'Read-only real owner candidate airport slot capacity, restriction and issued game-rights preflight; never commits slot, permission, ticket or flight.';
COMMIT;