-- Airlinerra game-only PA888/PA889 independent launch readiness.
-- NO permission submission, licence fee, airport slot, flight, or ledger write.
-- Preserve the hard stop in the atomic writer until a fully verified booking
-- and execution bridge exists, while surfacing all blockers to the player.
-- Location is checked on the verified CURRENT game day, licence validity on
-- the FUTURE planned first departure local date; these must not be confused.
-- Crew remains deferred Phase 1.

CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_roundtrip_launch_readiness_v1(p_player uuid, p_airline uuid, p_aircraft uuid, p_origin text, p_destination text, p_out_depart timestamp with time zone, p_out_arrive timestamp with time zone, p_back_depart timestamp with time zone, p_back_arrive timestamp with time zone, p_out_weekly jsonb, p_back_weekly jsonb, p_out_depart_stand text, p_out_arrive_stand text, p_back_depart_stand text, p_back_arrive_stand text, p_turnaround integer, p_days integer DEFAULT 28)
 RETURNS jsonb
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE
 base jsonb;
 owner_row record;
 fuel_row record;
 activation record;trusted record;finance record;engine record;
 clock_proof jsonb;
 ground_proof jsonb;
 reference_date date;
 origin_country text;dest_country text;tz_origin text;
 operator_country text;required_code text;
 policy_code text;
 policy_row record;
 initial_ground_verified boolean:=false;
 issuer_open boolean:=false;
 license_valid boolean:=false;
 both_route_rights_valid boolean:=false;
 outbound_right_valid boolean:=false;return_right_valid boolean:=false;
 block_codes text[]:=ARRAY[]::text[];
 cost_total numeric:=0;
BEGIN
 base:=airlinerra_game.section9_owned_roundtrip_candidate_preview_v1(
  p_player,p_airline,p_aircraft,p_origin,p_destination,
  p_out_depart,p_out_arrive,p_back_depart,p_back_arrive,
  p_out_weekly,p_back_weekly,p_out_depart_stand,p_out_arrive_stand,
  p_back_depart_stand,p_back_arrive_stand,p_turnaround,p_days);
 IF base->>'readOnly' IS DISTINCT FROM 'true'
 OR base->>'ledgerPosted' IS DISTINCT FROM 'false'
 OR base->>'flightsCreated' IS DISTINCT FROM '0'
 OR base->>'slotsReserved' IS DISTINCT FROM 'false'
 OR base->>'flightActivated' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_UNTRUSTED_ROUNDTRIP_READINESS_SOURCE';END IF;
 IF base->>'gameRoundtripModelSuitable' IS DISTINCT FROM 'true'
 THEN RETURN base || jsonb_build_object(
   'launchStatus','TIMETABLE_AND_OPERATIONAL_RELEASE_PENDING',
   'launchReadinessVersion','ROUNDTRIP_READONLY_GAME_LAUNCH_GATES_V1',
   'launchBlockers',jsonb_build_array('GAME_TIMETABLE_OR_SLOTS_BLOCKED'),
   'readyForAtomicOperationalCreate',false,
   'gamePermissionApplicationFeeCharged',false,
   'gamePermissionApplicationSubmitted',false,
   'newSchedulesCreated',0,'liveFlightActivated',false,
   'readOnly',true,'ledgerPosted',false);
 END IF;

 SELECT a.owner_player_id,a.home_airport_key,a.world_id,
  h.country_iso AS home_country
 INTO owner_row
 FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships w
  ON w.world_id=a.world_id AND w.player_id=a.owner_player_id
    AND w.state='active'
 LEFT JOIN airlinerra_game.airport_reference_profiles h
  ON h.world_id=1 AND h.airport_key=a.home_airport_key
 WHERE a.id=p_airline AND a.world_id=1 AND a.owner_player_id=p_player;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_ROUNDTRIP_NOT_OWNED';END IF;

 clock_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true'
 THEN block_codes:=array_append(block_codes,'SIGNED_GAME_HOUR_NOT_VERIFIED');
 ELSIF p_out_depart IS NULL
 OR p_out_depart<=(clock_proof->>'gameHourUtc')::timestamptz
 OR p_out_depart>(clock_proof->>'gameHourUtc')::timestamptz+
 interval '42 days'
 THEN block_codes:=array_append(block_codes,'DEPARTURE_NOT_IN_FUTURE_GAME_WINDOW');END IF;
 SELECT a.timezone_iana INTO tz_origin
 FROM airlinerra_game.airport_reference_profiles a
 JOIN pg_catalog.pg_timezone_names zone ON zone.name=a.timezone_iana
 WHERE a.world_id=1 AND a.airport_key=p_origin;
 reference_date:=(p_out_depart AT TIME ZONE coalesce(tz_origin,'Europe/Berlin'))::date;
 SELECT * INTO engine FROM airlinerra_game.section9_flight_engine_readiness_audit_v1
 WHERE world_id=1;
 SELECT * INTO activation FROM airlinerra_game.section9_activation_release_policy_v1
 WHERE world_id=1;
 SELECT * INTO trusted FROM airlinerra_game.section9_trusted_execution_release_policy_v1
 WHERE world_id=1;
 SELECT * INTO finance FROM airlinerra_game.section9_flight_finance_posting_release_v1
 WHERE world_id=1;
 IF engine.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 OR trusted.release_state IS DISTINCT FROM 'enabled'
 OR trusted.enabled_at IS NULL
 THEN block_codes:=array_append(block_codes,'FLIGHT_EXECUTION_AND_FUEL_NOT_RELEASED');END IF;
 IF activation.release_state IS DISTINCT FROM 'enabled'
 OR activation.enabled_at IS NULL
 OR activation.crew_mode IS DISTINCT FROM 'deferred_phase1'
 THEN block_codes:=array_append(block_codes,'INDEPENDENT_GAME_ACTIVATION_NOT_RELEASED');END IF;
 IF finance.release_state IS DISTINCT FROM 'approved'
 OR finance.approved_at IS NULL
 THEN block_codes:=array_append(block_codes,'ONCE_ONLY_FINANCIAL_SETTLEMENT_NOT_RELEASED');END IF;
 SELECT configuration_id INTO fuel_row
 FROM airlinerra_game.airline_aircraft_inventory f
 WHERE f.id=p_aircraft AND f.airline_id=p_airline
  AND f.fleet_status='in_service'
  AND f.ownership_type IN('owned','leased');
 IF NOT FOUND THEN block_codes:=array_append(block_codes,'AIRCRAFT_NOT_IN_SERVICE');
 ELSE
  SELECT configuration_id,operational_dispatch_release,financial_settlement_release,
    game_calculation_ready,model_source_kind
  INTO fuel_row FROM airlinerra_game.section9_game_fuel_model_snapshot_v1
  WHERE configuration_id=fuel_row.configuration_id;
  IF NOT FOUND OR fuel_row.game_calculation_ready IS DISTINCT FROM true
    OR fuel_row.operational_dispatch_release IS DISTINCT FROM 'RELEASED'
    OR fuel_row.financial_settlement_release IS DISTINCT FROM 'RELEASED'
  THEN block_codes:=array_append(block_codes,'AIRCRAFT_GAME_FUEL_DISPATCH_AND_FINANCE_NOT_RELEASED');END IF;
 END IF;

 ground_proof:=airlinerra_game.section9_owned_aircraft_operational_position_v1(
  p_player,p_airline,p_aircraft,(clock_proof->>'gameDate')::date);
 initial_ground_verified:=
   ground_proof->>'verified'='true'
   AND ground_proof->>'atGroundAirport'='true'
   AND ground_proof->>'airportKey'=p_origin;
 IF NOT initial_ground_verified
 THEN block_codes:=array_append(block_codes,'AIRCRAFT_ORIGIN_POSITION_NOT_VERIFIED');END IF;

 SELECT country_iso INTO origin_country
 FROM airlinerra_game.airport_reference_profiles
 WHERE world_id=1 AND airport_key=p_origin;
 SELECT country_iso INTO dest_country
 FROM airlinerra_game.airport_reference_profiles
 WHERE world_id=1 AND airport_key=p_destination;
 operator_country:=owner_row.home_country;
 required_code:=airlinerra_game.section9_required_game_traffic_permission_v1(
  operator_country,origin_country,dest_country,'passenger',reference_date);
 IF required_code IS NULL OR operator_country IS NULL OR origin_country IS NULL
 OR dest_country IS NULL
 THEN block_codes:=array_append(block_codes,'GAME_ROUTE_JURISDICTIONS_UNVERIFIED');
 END IF;
 -- Report game prices but DO NOT submit, approve or charge an application.
 FOREACH policy_code IN ARRAY ARRAY['AIR_OPERATOR_CERTIFICATE',required_code]::text[]
 LOOP
  IF policy_code IS NULL THEN CONTINUE;END IF;
  SELECT c.enabled_in_game,c.game_fee_usd,c.processing_game_days,
    r.release_enabled,r.released_at,r.validity_game_days
  INTO policy_row
  FROM airlinerra_game.business_permission_catalog_v1 c
  JOIN airlinerra_game.section9_game_permission_issuance_policy_v1 r
    ON r.permission_code=c.permission_code
  WHERE c.permission_code=policy_code;
  IF NOT FOUND OR policy_row.enabled_in_game IS DISTINCT FROM true
  OR policy_row.release_enabled IS DISTINCT FROM true
  OR policy_row.released_at IS NULL
  THEN block_codes:=array_append(block_codes,
    'GAME_PERMISSION_APPLICATION_NOT_RELEASED_'||policy_code);
  ELSE
    cost_total:=cost_total+coalesce(policy_row.game_fee_usd,0);
  END IF;
 END LOOP;

 SELECT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_operator_licence_evidence_v1 e
  JOIN airlinerra_game.section9_game_permission_applications_v1 a
   ON a.id=e.issued_application_id AND a.airline_id=e.airline_id
   AND a.status='issued' AND a.permission_code='AIR_OPERATOR_CERTIFICATE'
   AND a.ledger_entry_id IS NOT NULL
  WHERE e.airline_id=p_airline AND e.world_id=1
   AND e.jurisdiction_iso2=operator_country
   AND e.evidence_status='verified'
   AND e.valid_from<=reference_date
   AND e.valid_until>=reference_date+p_days
   AND e.evidence_reference='game-permission-issued-v1-'||a.id::text
 ) INTO license_valid;
 IF NOT license_valid THEN block_codes:=array_append(
   block_codes,'GAME_OPERATOR_LICENCE_NOT_ISSUED');END IF;

 IF required_code IS NOT NULL THEN
 SELECT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_route_operating_permission_evidence_v1 e
  JOIN airlinerra_game.section9_game_permission_applications_v1 a
  ON a.id=e.issued_application_id AND a.airline_id=e.airline_id
   AND a.permission_code=required_code AND a.status='issued'
   AND a.ledger_entry_id IS NOT NULL
  WHERE e.world_id=1 AND e.airline_id=p_airline
    AND e.origin_airport_key=p_origin
    AND e.destination_airport_key=p_destination
    AND e.service_type='passenger' AND e.evidence_status='verified'
    AND e.valid_from<=reference_date
    AND e.valid_until>=reference_date+p_days
    AND e.evidence_reference='game-permission-issued-v1-'||a.id::text
 ) INTO outbound_right_valid;
 SELECT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_route_operating_permission_evidence_v1 e
  JOIN airlinerra_game.section9_game_permission_applications_v1 a
  ON a.id=e.issued_application_id AND a.airline_id=e.airline_id
    AND a.permission_code=required_code AND a.status='issued'
    AND a.ledger_entry_id IS NOT NULL
  WHERE e.world_id=1 AND e.airline_id=p_airline
    AND e.origin_airport_key=p_destination
    AND e.destination_airport_key=p_origin
    AND e.service_type='passenger' AND e.evidence_status='verified'
    AND e.valid_from<=reference_date
    AND e.valid_until>=reference_date+p_days
    AND e.evidence_reference='game-permission-issued-v1-'||a.id::text
 ) INTO return_right_valid;
 END IF;
 both_route_rights_valid:=outbound_right_valid AND return_right_valid;
 IF NOT outbound_right_valid THEN
   block_codes:=array_append(block_codes,'OUTBOUND_GAME_TRAFFIC_RIGHTS_NOT_ISSUED');
 END IF;
 IF NOT return_right_valid THEN
   block_codes:=array_append(block_codes,'RETURN_GAME_TRAFFIC_RIGHTS_NOT_ISSUED');
 END IF;
 IF base->>'airportReviewsPending' IS DISTINCT FROM 'false'
 THEN block_codes:=array_append(block_codes,'AIRPORT_REVIEWS_NOT_COMPLETED');END IF;
 -- Last legacy atomic writer still has an unconditional abort after
 -- certification; do not advertise any live create readiness until its
 -- seven-day ticket & finance commit is safely connected and tested.
 block_codes:=array_append(block_codes,'ATOMIC_BOOKING_AND_FLIGHT_BRIDGE_NOT_COMPLETED');

 RETURN base || jsonb_build_object(
  'launchStatus',CASE WHEN base->>'gameRoundtripModelSuitable'='true'
   THEN 'TIMETABLE_VALID_BUT_OPERATIONAL_RELEASE_PENDING'
   ELSE 'TIMETABLE_AND_OPERATIONAL_RELEASE_PENDING' END,
  'launchReadinessVersion','ROUNDTRIP_READONLY_GAME_LAUNCH_GATES_V1',
  'launchBlockers',to_jsonb(block_codes),
  'launchBlockerCount',cardinality(block_codes),
  'gameOnlyPermissionCode',required_code,
  'operatorLicenceValid',license_valid,
  'outboundGameTrafficRightValid',outbound_right_valid,
  'returnGameTrafficRightValid',return_right_valid,
  'aircraftGamePositionVerified',initial_ground_verified,
  'gamePermissionApplicationFeeCharged',false,
  'gamePermissionApplicationSubmitted',false,
  'newSchedulesCreated',0,
  'liveFlightActivated',false,
  'readyForAtomicOperationalCreate',false,
  'readOnly',true,
  'ledgerPosted',false);
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_roundtrip_launch_readiness_v1(uuid,uuid,uuid,text,text,timestamptz,timestamptz,timestamptz,timestamptz,jsonb,jsonb,text,text,text,text,integer,integer) FROM PUBLIC,anon,authenticated,service_role;


CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_atomic_roundtrip_operational_create_v1(p_player uuid, p_airline uuid, p_aircraft uuid, p_out_flight text, p_back_flight text, p_origin text, p_destination text, p_out_depart timestamp with time zone, p_out_arrive timestamp with time zone, p_back_depart timestamp with time zone, p_back_arrive timestamp with time zone, p_out_weekly jsonb, p_back_weekly jsonb, p_out_depart_stand text, p_out_arrive_stand text, p_back_depart_stand text, p_back_arrive_stand text, p_turnaround integer, p_days integer DEFAULT 28)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'airlinerra', 'pg_catalog'
AS $function$
DECLARE
 owner record; fleet record;engine record; release_policy record; clock_row record;
 preview jsonb;
 out_saved jsonb;back_saved jsonb;out_active jsonb;back_active jsonb;
 out_id uuid;back_id uuid;
 locked_capacity integer:=0; slot_count integer:=0;
 game_day date;
 reason_codes text[]:=ARRAY[]::text[];
 required_code text;origin_country text;destination_country text;required_route_permission text;
 BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_aircraft IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='ROUNDTRIP_OWNER_AND_AIRCRAFT_REQUIRED';END IF;
 SELECT a.id,a.owner_player_id,a.world_id,a.iata_code,w.state AS membership_state
 INTO owner FROM airlinerra_game.airlines a
 JOIN airlinerra_game.world_memberships w
  ON w.world_id=a.world_id AND w.player_id=a.owner_player_id
 WHERE a.id=p_airline AND a.owner_player_id=p_player AND a.world_id=1;
 IF NOT FOUND OR owner.membership_state IS DISTINCT FROM 'active' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='ROUNDTRIP_AIRLINE_NOT_OWNED_OR_ACTIVE';END IF;
 IF p_out_flight IS NULL OR p_back_flight IS NULL
 OR p_out_flight=p_back_flight OR p_out_flight !~ '^[A-Z0-9]{2}[0-9]{1,4}$'
 OR p_back_flight !~ '^[A-Z0-9]{2}[0-9]{1,4}$'
 OR left(p_out_flight,2) IS DISTINCT FROM owner.iata_code
 OR left(p_back_flight,2) IS DISTINCT FROM owner.iata_code
 THEN RAISE EXCEPTION USING ERRCODE='22023',
 MESSAGE='ROUNDTRIP_INVALID_OR_DUPLICATE_FLIGHT_NUMBERS';END IF;
 SELECT fleet_status,ownership_type,configuration_id INTO fleet
 FROM airlinerra_game.airline_aircraft_inventory
 WHERE id=p_aircraft AND airline_id=p_airline;
 IF NOT FOUND OR fleet.fleet_status IS DISTINCT FROM 'in_service'
 OR fleet.ownership_type NOT IN ('owned','leased')
 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='ROUNDTRIP_AIRCRAFT_NOT_OWNED_OR_IN_SERVICE';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 WHERE s.airline_id=p_airline AND s.flight_number IN(p_out_flight,p_back_flight))
 THEN RETURN jsonb_build_object('status','blocked_flight_number_already_used',
 'routeCreated',false,'outboundCreated',false,'returnCreated',false,
 'slotsReserved',false,'flightActivated',false,'bookingEnabled',false,
 'ledgerPosted',false); END IF;

 preview:=airlinerra_game.section9_owned_roundtrip_launch_readiness_v1(
 p_player,p_airline,p_aircraft,p_origin,p_destination,
 p_out_depart,p_out_arrive,p_back_depart,p_back_arrive,
 p_out_weekly,p_back_weekly,p_out_depart_stand,p_out_arrive_stand,
 p_back_depart_stand,p_back_arrive_stand,p_turnaround,p_days);
 IF preview->>'readOnly' IS DISTINCT FROM 'true'
 OR preview->>'flightsCreated' IS DISTINCT FROM '0'
 OR preview->>'slotsReserved' IS DISTINCT FROM 'false'
 OR preview->>'flightActivated' IS DISTINCT FROM 'false'
 OR preview->>'ledgerPosted' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='ROUNDTRIP_UNSAFE_GAME_PREVIEW';END IF;
 IF preview->>'gameRoundtripModelSuitable' IS DISTINCT FROM 'true' THEN
  RETURN jsonb_build_object('status','blocked_roundtrip_game_model',
   'roundtripPreview',preview,
   'routeCreated',false,'outboundCreated',false,'returnCreated',false,
   'slotsReserved',false,'flightActivated',false,'bookingEnabled',false,
   'ledgerPosted',false);
 END IF;

 -- Releases are independently controlled. A game estimate never
 -- issues licences, verifies maintenance, books passengers or enables
 -- flight execution. No write occurs before all release checks.
 SELECT * INTO engine FROM airlinerra_game.section9_flight_engine_readiness_audit_v1 WHERE world_id=1;
 SELECT * INTO release_policy FROM airlinerra_game.section9_activation_release_policy_v1 WHERE world_id=1;
 SELECT confirmed_game_date,clock_source,engine_proof_ref,last_verified_at
 INTO clock_row FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=1;
 game_day:=clock_row.confirmed_game_date;
 IF engine.world_state IS DISTINCT FROM 'active'
 OR engine.authoritative_clock_connected IS DISTINCT FROM true
 OR engine.clock_producer_enabled IS DISTINCT FROM true
 OR clock_row.clock_source IS DISTINCT FROM 'authoritative_game_engine'
 OR game_day IS NULL OR clock_row.last_verified_at IS NULL
 OR length(coalesce(clock_row.engine_proof_ref,''))<12
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1
   WHERE world_id=1 AND game_date=game_day)
 THEN reason_codes:=array_append(reason_codes,'SIGNED_GAME_CLOCK_NOT_VERIFIED');END IF;
 IF engine.automatic_flight_and_fuel_settlement_enabled IS DISTINCT FROM true
 OR engine.trusted_flight_execution_release IS DISTINCT FROM 'ACTIVATED'
 OR engine.fuel_transaction_release IS DISTINCT FROM 'ACTIVATED'
 THEN reason_codes:=array_append(reason_codes,'FLIGHT_EXECUTION_AND_SETTLEMENT_NOT_RELEASED');END IF;
 IF release_policy.release_state IS DISTINCT FROM 'enabled'
 OR release_policy.enabled_at IS NULL OR release_policy.reviewed_at IS NULL
 OR release_policy.crew_mode IS DISTINCT FROM 'deferred_phase1'
 THEN reason_codes:=array_append(reason_codes,'INDEPENDENT_OPERATIONAL_ACTIVATION_NOT_RELEASED');END IF;
 -- Policy selection is route-specific, not a requirement to hold
 -- domestic licences for unrelated international services.
 SELECT country_iso INTO origin_country
 FROM airlinerra_game.airport_reference_profiles
 WHERE world_id=1 AND airport_key=p_origin;
 SELECT country_iso INTO destination_country
 FROM airlinerra_game.airport_reference_profiles
 WHERE world_id=1 AND airport_key=p_destination;
 IF origin_country IS NULL OR destination_country IS NULL THEN
  reason_codes:=array_append(reason_codes,'ROUTE_COUNTRY_NOT_VERIFIED');
 END IF;
 required_route_permission:=CASE WHEN origin_country=destination_country
  THEN 'DOMESTIC_TRAFFIC' ELSE 'THIRD_FOURTH_FREEDOM' END;
 FOREACH required_code IN ARRAY ARRAY[
  'AIR_OPERATOR_CERTIFICATE',required_route_permission]::text[]
 LOOP
  IF NOT EXISTS(
   SELECT 1 FROM airlinerra_game.business_permission_catalog_v1 c
   JOIN airlinerra_game.section9_game_permission_issuance_policy_v1 release
    ON release.permission_code=c.permission_code
   WHERE c.permission_code=required_code AND c.enabled_in_game=true
    AND release.release_enabled=true AND release.released_at IS NOT NULL
    AND c.game_fee_usd>0 AND c.processing_game_days>=1
    AND release.validity_game_days>=35)
  THEN reason_codes:=array_append(reason_codes,'GAME_PERMISSION_RELEASE_MISSING_'||required_code);END IF;
 END LOOP;
 IF cardinality(reason_codes)>0 THEN
  RETURN jsonb_build_object(
   'status','blocked_operational_releases_not_ready','blockers',to_jsonb(reason_codes),
   'roundtripPreview',preview,'routeCreated',false,'outboundCreated',false,
   'returnCreated',false,'slotsReserved',false,'flightActivated',false,
   'bookingEnabled',false,'ledgerPosted',false);
 END IF;

 -- All four movements' airport capacities are locked deterministically,
 -- matching the existing Section 6 single-route writer's lock order.
 PERFORM 1 FROM airlinerra_game.section6_airport_slot_capacity_v1 c
 WHERE c.world_id=1 AND c.airport_key IN(p_origin,p_destination)
 ORDER BY c.airport_key FOR UPDATE;
 GET DIAGNOSTICS locked_capacity=ROW_COUNT;
 IF locked_capacity<>2 THEN
  RETURN jsonb_build_object('status','blocked_airport_capacity_not_configured',
   'routeCreated',false,'outboundCreated',false,'returnCreated',false,
   'slotsReserved',false,'flightActivated',false,'bookingEnabled',false,
   'ledgerPosted',false);
 END IF;
 -- Serialize competing plans for the same aircraft.
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory f
 WHERE f.id=p_aircraft AND f.airline_id=p_airline AND f.fleet_status='in_service'
 ORDER BY f.id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='ROUNDTRIP_AIRCRAFT_CHANGED_DURING_COMMIT';END IF;
 -- Under these locks recalculate rotation and requested slot capacity.
 preview:=airlinerra_game.section9_owned_roundtrip_launch_readiness_v1(
 p_player,p_airline,p_aircraft,p_origin,p_destination,
 p_out_depart,p_out_arrive,p_back_depart,p_back_arrive,
 p_out_weekly,p_back_weekly,p_out_depart_stand,p_out_arrive_stand,
 p_back_depart_stand,p_back_arrive_stand,p_turnaround,p_days);
 IF preview->>'gameRoundtripModelSuitable' IS DISTINCT FROM 'true'
 OR preview->>'readOnly' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','blocked_pair_capacity_or_rotation_changed',
   'roundtripPreview',preview,
   'routeCreated',false,'outboundCreated',false,'returnCreated',false,
   'slotsReserved',false,'flightActivated',false,'bookingEnabled',false,
   'ledgerPosted',false);END IF;

 -- Both Section 6 writers run in the SAME PostgreSQL transaction.
 -- Any downstream clearance failure raises an exception, undoing BOTH
 -- schedules and ALL reservations. No half-created round trip.
 out_saved:=airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
 p_player,p_airline,p_aircraft,p_out_flight,p_origin,p_destination,
 p_out_depart,p_out_arrive,p_out_weekly,NULL::uuid,p_out_depart_stand,p_out_arrive_stand);
 back_saved:=airlinerra_game.section6_save_owned_aircraft_schedule_with_slots_v1(
 p_player,p_airline,p_aircraft,p_back_flight,p_destination,p_origin,
 p_back_depart,p_back_arrive,p_back_weekly,NULL::uuid,p_back_depart_stand,p_back_arrive_stand);
 IF out_saved->>'status' IS DISTINCT FROM 'draft'
 OR back_saved->>'status' IS DISTINCT FROM 'draft'
 OR out_saved->>'slotsReserved' IS DISTINCT FROM 'true'
 OR back_saved->>'slotsReserved' IS DISTINCT FROM 'true'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='ROUNDTRIP_SLOT_WRITE_NOT_CONFIRMED_ROLLBACK';END IF;
 out_id:=(out_saved->>'scheduleId')::uuid;
 back_id:=(back_saved->>'scheduleId')::uuid;
 IF out_id IS NULL OR back_id IS NULL OR out_id=back_id
 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='ROUNDTRIP_INVALID_ATOMIC_SCHEDULE_IDS_ROLLBACK';END IF;
 SELECT count(*)::int INTO slot_count
 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 s
 WHERE s.schedule_id IN(out_id,back_id);
 IF slot_count<4 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='ROUNDTRIP_MISSING_ATOMIC_SLOT_RECORDS_ROLLBACK';END IF;

 -- Individually signed, version-bound operational certifications must
 -- exist for both legs. Failure of either raises and rolls back the pair.
 out_active:=airlinerra_game.section9_commit_certified_schedule_activation_v1(
 p_player,p_airline,out_id,(out_saved->>'version')::int,game_day,p_days);
 IF out_active->>'status' IS DISTINCT FROM 'certified_schedule_activated'
 OR out_active->>'scheduleActivated' IS DISTINCT FROM 'true'
 OR out_active->>'flightActivated' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='ROUNDTRIP_OUTBOUND_NOT_CERTIFIED_ROLLBACK';END IF;
 back_active:=airlinerra_game.section9_commit_certified_schedule_activation_v1(
 p_player,p_airline,back_id,(back_saved->>'version')::int,game_day,p_days);
 IF back_active->>'status' IS DISTINCT FROM 'certified_schedule_activated'
 OR back_active->>'scheduleActivated' IS DISTINCT FROM 'true'
 OR back_active->>'flightActivated' IS DISTINCT FROM 'false'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
 MESSAGE='ROUNDTRIP_RETURN_NOT_CERTIFIED_ROLLBACK';END IF;
 -- A route is NOT successful until saleable bookings and flight execution
 -- are committed too. Their atomic writers are not connected yet, so even
 -- two independently certified schedules must be ROLLED BACK at this point.
 -- Do not create a phantom "operational" route for the player.
 RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='ROUNDTRIP_BOOKING_AND_EXECUTION_NOT_CONNECTED_FULL_ROLLBACK';
END $function$
;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_atomic_roundtrip_operational_create_v1(uuid,uuid,uuid,text,text,text,text,timestamptz,timestamptz,timestamptz,timestamptz,jsonb,jsonb,text,text,text,text,integer,integer) FROM PUBLIC,anon,authenticated,service_role;
