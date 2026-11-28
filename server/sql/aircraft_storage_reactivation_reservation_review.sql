-- ROLLBACK-ONLY REVIEW. Requires reactivation request and shared slot/funds reviews.
-- The inbound worker cannot consume these outbound reservations.
BEGIN;
CREATE FUNCTION airlinerra_game.reactivation_ground_position_valid_v1(p_request uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path=pg_catalog AS $fn$
 SELECT EXISTS(
 SELECT 1 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r
 JOIN airlinerra_game.aircraft_storage_sessions_v1 s ON s.request_id=r.storage_session_id AND s.airline_id=r.airline_id AND s.aircraft_inventory_id=r.aircraft_inventory_id AND s.storage_ended_utc IS NULL AND s.airport_key=r.origin_airport_key
 JOIN airlinerra_game.airline_aircraft_inventory i ON i.id=r.aircraft_inventory_id AND i.airline_id=r.airline_id AND i.ownership_type='owned' AND i.fleet_status='stored'
 JOIN airlinerra_game.section9_aircraft_current_position_v1 p ON p.aircraft_inventory_id=i.id AND p.airline_id=r.airline_id AND p.location_status='grounded' AND p.airport_key=s.airport_key AND p.storage_request_id=s.request_id AND p.last_engine_event_id=s.arrival_engine_event_id AND p.last_event_utc=s.storage_started_utc
 JOIN airlinerra_game.section9_operated_flight_movements_v1 m ON m.engine_event_id=s.arrival_engine_event_id AND m.storage_request_id=s.request_id AND m.airline_id=r.airline_id AND m.aircraft_inventory_id=i.id AND m.phase='arrived' AND m.destination_airport_key=s.airport_key AND m.actual_event_utc=s.storage_started_utc
 WHERE current_user='postgres' AND r.id=p_request AND r.purpose='storage_reactivation' AND r.status='reactivation_awaiting_review'
 AND (r.quote->>'configurationId')::bigint=i.configuration_id
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 later WHERE later.aircraft_inventory_id=i.id AND later.airline_id=r.airline_id AND (later.actual_event_utc>m.actual_event_utc OR (later.actual_event_utc=m.actual_event_utc AND later.engine_event_id<>m.engine_event_id))));
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.reactivation_ground_position_valid_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.reactivation_reservation_evidence_v1(p_request uuid)
RETURNS boolean LANGUAGE sql STABLE SET search_path=pg_catalog AS $fn$
 SELECT EXISTS(
 SELECT 1 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r
 WHERE current_user='postgres' AND r.id=p_request
 AND airlinerra_game.reactivation_ground_position_valid_v1(r.id)
 AND airlinerra_game.aircraft_storage_airport_admission_v1(r.origin_airport_key,'storage_reactivation')->>'eligible'='true'
 AND EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1 u WHERE u.world_id=1 AND u.airport_key=r.destination_airport_key AND u.operationally_authorized AND u.dispatch_eligible_by_airport_admission)
 AND r.quote->>'status'='storage_relocation_cost_estimate' AND r.quote->>'fuelRangeConfirmed'='true'
 AND r.quote->>'passengers'='0' AND r.quote->>'cargoTonnes'='0' AND r.quote->>'ticketRevenueUsd'='0'
 AND (r.quote->>'directOperatingCostUsd')::numeric=r.quoted_cost_usd
 AND r.arrival_utc=r.departure_utc+make_interval(mins=>(r.quote#>>'{phases,totalMinutes}')::integer)
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_flight_slots_v1 s WHERE s.world_id=1 AND s.request_id=r.id AND s.direction='departure' AND s.airport_key=r.origin_airport_key AND s.movement_utc=r.departure_utc)
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_flight_slots_v1 s WHERE s.world_id=1 AND s.request_id=r.id AND s.direction='arrival' AND s.airport_key=r.destination_airport_key AND s.movement_utc=r.arrival_utc)
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s WHERE s.airline_id=r.airline_id AND s.aircraft_inventory_id=r.aircraft_inventory_id AND s.status='active')
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 j WHERE j.airline_id=r.airline_id AND j.aircraft_inventory_id=r.aircraft_inventory_id AND j.status IN('scheduled','in_progress','payment_required'))
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 t WHERE t.aircraft_inventory_id=r.aircraft_inventory_id AND t.status='reserved'));
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.reactivation_reservation_evidence_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.reserve_aircraft_reactivation_slots_v1(p_player uuid,p_airline uuid,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record; endpoint record; cap record; tz text; local_ts timestamp; day_key date; dow integer; minute_key integer; h integer; m integer; n integer; v_now timestamptz; q jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 -- Same airline -> aircraft -> request lock order as request creation.
 PERFORM 1 FROM airlinerra_game.airlines a JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE a.id=p_airline AND a.owner_player_id=p_player AND a.world_id=1 FOR UPDATE OF a;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT t.* INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 t WHERE t.id=p_request AND t.airline_id=p_airline AND t.owner_player_id=p_player;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND airline_id=p_airline AND fleet_status='stored' AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','aircraft_unavailable','slotsReserved',0);END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request FOR UPDATE;
 IF r.status<>'reactivation_awaiting_review' OR r.purpose<>'storage_reactivation' THEN RETURN jsonb_build_object('status','request_not_pending','slotsReserved',0);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL OR r.departure_utc<v_now+interval '1 minute' THEN RETURN jsonb_build_object('status','request_departure_expired','slotsReserved',0);END IF;
 IF airlinerra_game.aircraft_storage_airport_admission_v1(r.origin_airport_key,'storage_reactivation')->>'eligible' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','storage_admission_blocked','slotsReserved',0);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=r.aircraft_inventory_id AND status='active')
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=r.aircraft_inventory_id AND status IN ('scheduled','in_progress','payment_required'))
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id AND status='reserved')
 THEN RETURN jsonb_build_object('status','aircraft_commitment_conflict','slotsReserved',0);END IF;
 IF NOT airlinerra_game.reactivation_ground_position_valid_v1(r.id)
 THEN RETURN jsonb_build_object('status','aircraft_position_changed','slotsReserved',0);END IF;
 SELECT count(*) INTO n FROM airlinerra_game.aircraft_storage_flight_slots_v1 WHERE request_id=r.id;
 IF n=2 THEN RETURN jsonb_build_object('status','storage_slots_reserved','slotsReserved',2,'replayed',true,'flightScheduled',false);END IF;
 IF n<>0 THEN RAISE EXCEPTION 'STORAGE_PARTIAL_SLOT_RESERVATION';END IF;
 -- All shared commercial rows first, in stable order, then dedicated rows.
 PERFORM 1 FROM airlinerra_game.section6_airport_slot_capacity_v1 WHERE world_id=1 AND airport_key IN(r.origin_airport_key,r.destination_airport_key) ORDER BY airport_key FOR UPDATE;
 PERFORM 1 FROM airlinerra_game.aircraft_storage_only_movement_limits_v1 WHERE world_id=1 AND airport_key=r.origin_airport_key FOR UPDATE;
 BEGIN
 FOR endpoint IN SELECT * FROM (VALUES (r.origin_airport_key,'departure',r.departure_utc),(r.destination_airport_key,'arrival',r.arrival_utc)) e(airport_key,direction,movement_utc) ORDER BY airport_key LOOP
  tz:=NULL; h:=NULL; m:=NULL;
  IF endpoint.direction='departure' AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_facilities_v1 WHERE world_id=1 AND airport_key=endpoint.airport_key AND admission_scope='relocation_only') THEN
   SELECT p.timezone_iana,l.movements_per_direction_hour,l.movements_per_direction_10m INTO tz,h,m
   FROM airlinerra_game.aircraft_storage_airport_operational_profiles_v1 p
   JOIN airlinerra_game.aircraft_storage_only_movement_limits_v1 l USING(world_id,airport_key)
   WHERE p.world_id=1 AND p.airport_key=endpoint.airport_key;
   -- Do not create commercial slot capacity or grant commercial access.
  ELSE
   SELECT p.timezone_iana,c.remote_stands,c.remote_per_direction_10m INTO tz,h,m
   FROM airlinerra_game.section6_airport_slot_capacity_v1 c JOIN airlinerra_game.section5_airport_operating_policy_v1 p USING(world_id,airport_key)
   JOIN airlinerra_game.airport_unified_operations_v1 u USING(world_id,airport_key)
   WHERE c.world_id=1 AND c.airport_key=endpoint.airport_key AND u.operationally_authorized AND u.dispatch_eligible_by_airport_admission;
  END IF;
  IF tz IS NULL OR h IS NULL OR m IS NULL OR h<=0 OR m<=0 OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=tz)
  THEN RAISE EXCEPTION 'STORAGE_MOVEMENT_PROFILE_UNAVAILABLE';END IF;
  local_ts:=endpoint.movement_utc AT TIME ZONE tz;day_key:=local_ts::date;
  dow:=extract(isodow FROM local_ts)::int-1;minute_key:=extract(hour FROM local_ts)::int*60+(extract(minute FROM local_ts)::int/10)*10;
  PERFORM airlinerra_game.assert_storage_remote_slot_v1(endpoint.airport_key,day_key,dow,minute_key,endpoint.direction,h,m,1);
  INSERT INTO airlinerra_game.aircraft_storage_flight_slots_v1 VALUES(r.id,1,endpoint.airport_key,endpoint.direction,endpoint.movement_utc,day_key,dow,minute_key);
 END LOOP;
 EXCEPTION WHEN raise_exception THEN
 IF SQLERRM IN ('STORAGE_FLIGHT_SLOT_UNAVAILABLE','STORAGE_MOVEMENT_PROFILE_UNAVAILABLE') THEN RETURN jsonb_build_object('status',SQLERRM,'slotsReserved',0,'flightScheduled',false);END IF;RAISE;
 END;
 RETURN jsonb_build_object('status','storage_slots_reserved','slotsReserved',2,'replayed',false,'flightScheduled',false,'dispatchAuthorized',false,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.reserve_aircraft_reactivation_slots_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;


CREATE FUNCTION airlinerra_game.hold_aircraft_reactivation_funds_v1(p_player uuid,p_airline uuid,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE a record; r record; h record; now_game timestamptz; total numeric; lid bigint; physical text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT x.* INTO a FROM airlinerra_game.airlines x JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE x.id=p_airline AND x.world_id=1 AND x.owner_player_id=p_player FOR UPDATE OF x;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request AND airline_id=p_airline AND owner_player_id=p_player;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND airline_id=p_airline AND fleet_status='stored' AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','aircraft_unavailable','fundsHeld',false);END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request FOR UPDATE;
 SELECT * INTO h FROM airlinerra_game.aircraft_storage_funds_v1 WHERE request_id=p_request;
 IF FOUND THEN
 IF h.airline_id<>p_airline OR h.amount_usd<>r.quoted_cost_usd OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_ledger WHERE id=h.hold_ledger_id AND airline_id=p_airline AND entry_kind='AIRCRAFT_STORAGE_HOLD' AND amount_usd=-h.amount_usd)
 THEN RAISE EXCEPTION 'STORAGE_HOLD_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status',h.status,'fundsHeld',h.status='held','replayed',true);END IF;
 now_game:=airlinerra_game.section9_verified_world_instant_v1();
 physical:=r.id::text||':'||(r.departure_utc AT TIME ZONE 'UTC')::date::text||':1';
 IF now_game IS NULL OR r.departure_utc<=now_game OR r.status<>'reactivation_awaiting_review' OR r.purpose<>'storage_reactivation' OR r.quoted_cost_usd<=0
 OR NOT airlinerra_game.reactivation_reservation_evidence_v1(r.id)
 THEN RETURN jsonb_build_object('status','storage_hold_not_ready','fundsHeld',false);END IF;
 SELECT coalesce(sum(amount_usd),0) INTO total FROM airlinerra_game.airline_ledger WHERE airline_id=p_airline;
 IF total IS DISTINCT FROM a.cash_usd OR a.cash_usd<r.quoted_cost_usd THEN RETURN jsonb_build_object('status','storage_hold_insufficient_or_unreconciled_cash','fundsHeld',false);END IF;
 UPDATE airlinerra_game.airlines SET cash_usd=cash_usd-r.quoted_cost_usd WHERE id=p_airline;
 INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd,recorded_at) VALUES(p_airline,'AIRCRAFT_STORAGE_HOLD',-r.quoted_cost_usd,now_game) RETURNING id INTO lid;
 INSERT INTO airlinerra_game.aircraft_storage_funds_v1(request_id,airline_id,amount_usd,hold_ledger_id,held_at) VALUES(p_request,p_airline,r.quoted_cost_usd,lid,now_game);
 RETURN jsonb_build_object('status','held','fundsHeld',true,'amountUsd',r.quoted_cost_usd,'replayed',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.hold_aircraft_reactivation_funds_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;


ROLLBACK;
