-- Section 9 operational readiness: evidence-oriented preflight only.
-- Turnaround times are explicitly PROVISIONAL GAME DESIGN policy, not
-- published airport/airline MCT or certified turnaround requirements.
-- No flight activation, traffic-rights grant, crew authorization or cash entry.

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_game_turnaround_policy_v1(
 role text NOT NULL CHECK(role IN ('passenger','cargo')),
 max_seats integer NOT NULL CHECK(max_seats BETWEEN 0 AND 10000),
 min_ground_minutes smallint NOT NULL CHECK(min_ground_minutes BETWEEN 10 AND 300),
 policy_basis text NOT NULL DEFAULT 'provisional_game_design_v1'
   CHECK(policy_basis='provisional_game_design_v1'),
 PRIMARY KEY(role,max_seats)
);
ALTER TABLE airlinerra_game.section9_game_turnaround_policy_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_game_turnaround_policy_v1 FROM PUBLIC,anon,authenticated;
INSERT INTO airlinerra_game.section9_game_turnaround_policy_v1(role,max_seats,min_ground_minutes)
VALUES ('passenger',19,25),('passenger',79,30),
 ('passenger',199,40),('passenger',349,55),
 ('passenger',10000,70),('cargo',10000,60)
ON CONFLICT(role,max_seats) DO NOTHING;
COMMENT ON TABLE airlinerra_game.section9_game_turnaround_policy_v1 IS
 'Provisional game turnaround safety estimates, NOT passenger minimum connection times or a certified airport/aircraft turnaround release.';

CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_operational_preflight_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,
 p_start_date date,p_days integer DEFAULT 28
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE
 t record; turn record; delivered record;
 rotation jsonb; rights_passenger jsonb; rights_cargo jsonb;
 service_role text;seats integer;
 short_turns integer:=0;first_utc timestamptz;
 first_origin text;minimum_ground numeric;
 reasons text[]:=ARRAY[]::text[];
 country_hint text;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_schedule IS NULL OR
    p_start_date IS NULL OR
    p_start_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01' OR
    p_days NOT BETWEEN 7 AND 42
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_OPERATIONS_PREVIEW_REQUEST';END IF;

 SELECT s.id,s.airline_id,s.aircraft_inventory_id,s.configuration_id,
  s.origin_airport_key,s.destination_airport_key,
  s.version,s.status,s.operationally_verified,
  a.home_airport_key,
  f.fleet_status,f.configuration_id AS fleet_configuration,
  c.use_type,c.crew_required,c.typical_passenger_seats,c.maximum_passenger_seats,
  payload.simultaneous_passenger_seats,
  orig.country_iso AS origin_country,dest.country_iso AS destination_country,
  home.country_iso AS home_country_hint
 INTO t
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a ON a.id=s.airline_id AND a.world_id=1
  AND a.owner_player_id=p_player
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id
 JOIN airlinerra.aircraft_configurations c ON c.id=s.configuration_id
 LEFT JOIN airlinerra.aircraft_service_payload_game_v1 payload
  ON payload.configuration_id=c.id
 LEFT JOIN airlinerra_game.airport_reference_profiles orig
  ON orig.world_id=1 AND orig.airport_key=s.origin_airport_key
 LEFT JOIN airlinerra_game.airport_reference_profiles dest
  ON dest.world_id=1 AND dest.airport_key=s.destination_airport_key
 LEFT JOIN airlinerra_game.airport_reference_profiles home
  ON home.world_id=1 AND home.airport_key=a.home_airport_key
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND s.world_id=1;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OPERATIONS_SCHEDULE_NOT_OWNED';END IF;

 rotation:=airlinerra_game.section9_owned_aircraft_rotation_preview_v1(
  p_player,p_airline,p_schedule,p_start_date,p_days);

 -- The fleet size is a game-planning classification, NOT an airline-specific
 -- turnaround authorization. Unknown passenger seat counts stay UNKNOWN.
 service_role:=CASE WHEN t.use_type='cargo' THEN 'cargo'
   ELSE 'passenger' END;
 seats:=CASE WHEN service_role='cargo' THEN 0
   ELSE coalesce(t.simultaneous_passenger_seats,
     t.typical_passenger_seats,t.maximum_passenger_seats) END;
 IF seats IS NOT NULL THEN
  SELECT p.min_ground_minutes,p.policy_basis INTO turn
  FROM airlinerra_game.section9_game_turnaround_policy_v1 p
  WHERE p.role=service_role AND p.max_seats>=seats
  ORDER BY p.max_seats LIMIT 1;
 END IF;

 -- Calculate aircraft-specific minimum ground gaps across ALL its saved
 -- weekly routes. Include a 7-day lead/tail to expose weekly transitions.
 -- The older overlap/teleport/DST checker remains the independent authority
 -- for those types of schedule conflicts.
 WITH owned AS (
  SELECT s.id,s.origin_airport_key,s.destination_airport_key,
   s.reference_departure_utc,s.reference_arrival_utc,
   tz.timezone_iana,s.weekly_schedule
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
  JOIN airlinerra_game.airport_reference_profiles tz
   ON tz.world_id=1 AND tz.airport_key=s.origin_airport_key
  JOIN pg_catalog.pg_timezone_names names
   ON names.name=tz.timezone_iana
  WHERE s.world_id=1 AND s.airline_id=p_airline
   AND s.aircraft_inventory_id=t.aircraft_inventory_id
 ), weekly AS (
  SELECT o.*,e.ordinality::integer AS weekly_entry,
   e.item->>'day' AS weekday_text,e.item->>'time' AS clock_text
  FROM owned o
  CROSS JOIN LATERAL jsonb_array_elements(o.weekly_schedule)
   WITH ORDINALITY AS e(item,ordinality)
  WHERE jsonb_typeof(e.item)='object'
   AND coalesce(e.item->>'day','')~'^[0-6]$'
   AND coalesce(e.item->>'time','')~
    '^([01][0-9]|2[0-3]):[0-5][0-9]$'
 ), timetable AS (
  SELECT w.id,w.origin_airport_key,w.destination_airport_key,
   (d.local_day::date+(w.clock_text)::time)
      AT TIME ZONE w.timezone_iana AS departure_utc,
   (w.reference_arrival_utc-w.reference_departure_utc) AS duration
  FROM weekly w
  CROSS JOIN LATERAL generate_series(
   (p_start_date-7)::timestamp,(p_start_date+p_days+7)::timestamp,
   interval '1 day') AS d(local_day)
  WHERE (w.weekday_text)::integer=
   extract(isodow from d.local_day)::integer-1
 ), ordered AS (
  SELECT q.*,q.departure_utc+q.duration AS arrival_utc,
   lag(q.departure_utc+q.duration) OVER
    (ORDER BY q.departure_utc,q.id) AS previous_arrival,
   lag(q.destination_airport_key) OVER
    (ORDER BY q.departure_utc,q.id) AS previous_destination
  FROM timetable q
 )
 SELECT count(*) FILTER (
  WHERE previous_arrival IS NOT NULL
   AND previous_destination=origin_airport_key
   AND departure_utc>=previous_arrival
   AND turn.min_ground_minutes IS NOT NULL
   AND departure_utc<
      previous_arrival+make_interval(mins=>turn.min_ground_minutes)
 )::integer,
 min(extract(epoch FROM departure_utc-previous_arrival)/60)
  FILTER(WHERE previous_arrival IS NOT NULL
   AND previous_destination=origin_airport_key
   AND departure_utc>=previous_arrival)::numeric,
 min(departure_utc), (array_agg(origin_airport_key ORDER BY departure_utc))[1]
 INTO short_turns,minimum_ground,first_utc,first_origin
 FROM ordered;

 -- Delivery order is NOT proof of continuous aircraft location. An
 -- independently approved inspection provides a useful positioning ANCHOR,
 -- but there is still no authoritative operated-flight movement history.
 SELECT o.delivery_home_airport_key,o.delivery_due_at,
   inspect.reviewed_at,inspect.reviewer_reference
 INTO delivered
 FROM airlinerra_game.aircraft_acquisition_orders_v1 o
 JOIN airlinerra_game.aircraft_delivery_inspections_v1 inspect
  ON inspect.order_id=o.order_id
   AND inspect.aircraft_inventory_id=o.aircraft_inventory_id
 WHERE o.world_id=1 AND o.airline_id=p_airline
  AND o.aircraft_inventory_id=t.aircraft_inventory_id
  AND o.order_status='delivered_pending_inspection'
  AND inspect.inspection_status='approved'
  AND inspect.reviewed_at IS NOT NULL
  AND inspect.reviewer_reference IS NOT NULL
 ORDER BY inspect.reviewed_at DESC LIMIT 1;

 -- Legal country is a HINT inferred from the home airport, not proof that
 -- the airline holds a licence there. All underlying rights previews
 -- correctly return operationally_authorized=false.
 country_hint:=t.home_country_hint;
 IF country_hint IS NOT NULL AND t.origin_country IS NOT NULL
   AND t.destination_country IS NOT NULL THEN
  IF t.use_type IN ('passenger','combi') THEN
   rights_passenger:=airlinerra_game.aviation_route_rights_preview_v1(
    country_hint,t.origin_country,t.destination_country,'passenger',p_start_date);
  END IF;
  IF t.use_type IN ('cargo','combi') THEN
   rights_cargo:=airlinerra_game.aviation_route_rights_preview_v1(
    country_hint,t.origin_country,t.destination_country,'cargo',p_start_date);
  END IF;
 END IF;

 IF (rotation->>'overlappingFlights')::integer>0 THEN
  reasons:=array_append(reasons,'AIRCRAFT_OVERLAP');END IF;
 IF (rotation->>'wrongAirportDepartures')::integer>0 THEN
  reasons:=array_append(reasons,'AIRCRAFT_WRONG_AIRPORT');END IF;
 IF (rotation->>'daylightSavingTimeIssues')::integer>0 THEN
  reasons:=array_append(reasons,'INVALID_LOCAL_TIME');END IF;
 IF (rotation->>'invalidWeeklyEntries')::integer>0 OR
    (rotation->>'unknownOriginTimezones')::integer>0 THEN
  reasons:=array_append(reasons,'WEEKLY_TIMETABLE_UNVERIFIED');END IF;
 IF turn.min_ground_minutes IS NULL THEN
  reasons:=array_append(reasons,'TURNAROUND_GAME_POLICY_UNAVAILABLE');
 ELSIF short_turns>0 THEN
  reasons:=array_append(reasons,'AIRCRAFT_TURNAROUND_TOO_SHORT');END IF;
 IF delivered.reviewed_at IS NULL THEN
  reasons:=array_append(reasons,'DELIVERY_POSITION_EVIDENCE_MISSING');END IF;
 reasons:=array_append(reasons,'INITIAL_AIRCRAFT_POSITION_NOT_PROVEN');
 IF t.crew_required IS NULL OR t.crew_required<1 THEN
  reasons:=array_append(reasons,'CREW_REQUIREMENT_UNKNOWN');END IF;
 reasons:=array_append(reasons,'CREW_ASSIGNMENTS_NOT_VERIFIED');
 reasons:=array_append(reasons,'OPERATING_LICENCE_NOT_VERIFIED');
 reasons:=array_append(reasons,'TRAFFIC_RIGHTS_NOT_OPERATIONALLY_AUTHORIZED');
 IF (rotation->'slotsRecorded'->>'departure') IS DISTINCT FROM 'true' OR
    (rotation->'slotsRecorded'->>'arrival') IS DISTINCT FROM 'true' THEN
  reasons:=array_append(reasons,'AIRPORT_SLOT_RECORDS_MISSING');END IF;
 reasons:=array_append(reasons,'FLIGHT_ACTIVATION_NOT_RELEASED');

 RETURN jsonb_build_object(
  'status','BLOCKED_OPERATIONAL_EVIDENCE_INCOMPLETE',
  'scheduleId',t.id,'aircraftInventoryId',t.aircraft_inventory_id,
  'gameDate',p_start_date,'previewDays',p_days,
  'aircraftServiceRole',t.use_type,
  'turnaround',jsonb_build_object(
   'provisionalPolicy',true,'policyBasis',turn.policy_basis,
   'minimumMinutes',turn.min_ground_minutes,
   'shortTurnaroundOccurrences',short_turns,
   'minimumObservedGroundMinutes',round(minimum_ground,1),
   'verifiedForOperationalRelease',false),
  'deliveryEvidence',jsonb_build_object(
   'inspectionApproved',delivered.reviewed_at IS NOT NULL,
   'recordedDeliveryAirport',delivered.delivery_home_airport_key,
   'earliestPreviewDepartureAirport',first_origin,
   'earliestPreviewDepartureUtc',first_utc,
   'physicalMovementHistoryVerified',false),
  'crew',jsonb_build_object(
   'catalogRequirementKnown',coalesce(t.crew_required>0,false),
   'catalogCrewRequired',t.crew_required,
   'assignmentsVerified',false),
  'routeRights',jsonb_build_object(
   'countryBasis','airline_home_airport_hint_only',
   'licenceCountryVerified',false,
   'operatorCountryHint',country_hint,
   'originCountry',t.origin_country,
   'destinationCountry',t.destination_country,
   'passengerPrinciple',rights_passenger,
   'cargoPrinciple',rights_cargo,
   'operationallyAuthorized',false),
  'rotation',rotation,
  'blockers',to_jsonb(reasons),
  'initialPositionVerified',false,
  'flightActivationReleased',false,
  'canActivateNormalFlight',false,'readOnly',true);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_owned_operational_preflight_v1(
 uuid,uuid,uuid,date,integer) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section9_owned_operational_preflight_v1(
 uuid,uuid,uuid,date,integer) IS
 'Player-owned read-only operational evidence. Turnaround is provisional GAME DESIGN; licence, crew, aircraft movement and flight activation remain unverified.';
