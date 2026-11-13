-- Shared two-leg, *fully atomic* activation/booking boundary.
-- Authorization is owner-scoped and uses invoker security only.
-- No planning-only fallback, no "partial operating route".
-- Current commercial/permissions releases remain independently disabled.
-- Until a trusted booking+execution writer is connected, even certified
-- schedules are rolled back at the final gate. This is INTENTIONAL.
-- Game-only capacity and right classifications must not be misrepresented
-- as official operating clearances.
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

 preview:=airlinerra_game.section9_owned_roundtrip_candidate_preview_v1(
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
 preview:=airlinerra_game.section9_owned_roundtrip_candidate_preview_v1(
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
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_atomic_roundtrip_operational_create_v1(
 uuid,uuid,uuid,text,text,text,text,timestamptz,timestamptz,timestamptz,timestamptz,
 jsonb,jsonb,text,text,text,text,integer,integer) FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION airlinerra_game.section9_owned_atomic_roundtrip_operational_create_v1(
 uuid,uuid,uuid,text,text,text,text,timestamptz,timestamptz,timestamptz,timestamptz,
 jsonb,jsonb,text,text,text,text,integer,integer) TO service_role;
