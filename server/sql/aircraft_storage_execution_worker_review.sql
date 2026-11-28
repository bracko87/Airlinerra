-- ROLLBACK-ONLY REVIEW. Requires funds, movement, billing, arrival and fuel adapter reviews.
-- No cron registration or production enablement.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_dispatch_clearance_v1(
 request_id uuid PRIMARY KEY REFERENCES airlinerra_game.aircraft_storage_relocation_requests_v1(id),
 configuration_id bigint NOT NULL, origin_airport_key text NOT NULL,
 destination_airport_key text NOT NULL, departure_utc timestamptz NOT NULL, arrival_utc timestamptz NOT NULL,
 runway_review_reference text NOT NULL CHECK(btrim(runway_review_reference)<>''),
 airport_restriction_review_reference text NOT NULL CHECK(btrim(airport_restriction_review_reference)<>''),
 ferry_licence_review_reference text NOT NULL CHECK(btrim(ferry_licence_review_reference)<>''),
 crew_review_reference text NOT NULL CHECK(btrim(crew_review_reference)<>''),
 approved_at timestamptz NOT NULL, revoked_at timestamptz,
 CHECK(arrival_utc>departure_utc AND (revoked_at IS NULL OR revoked_at>=approved_at))
);
ALTER TABLE airlinerra_game.aircraft_storage_dispatch_clearance_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_dispatch_clearance_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.execute_aircraft_storage_leg_v1(p_request uuid,p_phase text)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record; i record; l record; pos record; has_position boolean; anchor jsonb; clock_proof jsonb; v_now timestamptz; event_time timestamptz; physical text; event_id text; payload text; signer text; signature text; decision jsonb; q jsonb; fuel jsonb; usage jsonb; settled jsonb; maintenance jsonb; outbound boolean;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_phase IS NULL OR p_phase NOT IN ('departed','arrived') THEN RAISE EXCEPTION 'INVALID_STORAGE_PHASE';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_execution_release_v1 WHERE world_id=1 AND fuel_adapter_enabled AND execution_enabled)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_signed_movement_release_v1 WHERE world_id=1 AND enabled)
 THEN RETURN jsonb_build_object('status','storage_execution_not_released','movementRecorded',false);END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_request_unknown','movementRecorded',false);END IF;
 -- Serialize with holds, cancellation, and arrival accounting.
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=r.airline_id AND world_id=1 FOR UPDATE;
 SELECT * INTO i FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND airline_id=r.airline_id AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_aircraft_unavailable','movementRecorded',false);END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request FOR UPDATE;
 physical:=r.id::text||':'||(r.departure_utc AT TIME ZONE 'UTC')::date::text||':1';
 event_id:='storage-v1:'||physical||':'||p_phase;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE engine_event_id=event_id AND storage_request_id=r.id AND phase=p_phase)
 THEN RETURN jsonb_build_object('status','storage_event_already_recorded','movementRecorded',false,'replayed',true);END IF;
 outbound:=r.purpose='storage_reactivation';
 IF outbound AND p_phase='departed' AND NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_reactivation_release_v1 WHERE world_id=1 AND enabled) THEN RETURN jsonb_build_object('status','reactivation_not_released','movementRecorded',false);END IF;
 IF NOT ((NOT outbound AND r.status='awaiting_slot_and_dispatch_release' AND i.fleet_status='in_service') OR (outbound AND r.status='reactivation_awaiting_review' AND i.fleet_status='stored')) THEN RETURN jsonb_build_object('status','storage_request_not_executable','movementRecorded',false);END IF;
 SELECT * INTO l FROM airlinerra_game.aircraft_storage_any_leg_evidence_v1(physical);
 IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_leg_evidence_missing','movementRecorded',false);END IF;
 clock_proof:=airlinerra_game.section9_verified_berlin_game_hour_v1();
 IF clock_proof->>'authoritativeGameHourAvailable' IS DISTINCT FROM 'true' OR clock_proof->>'gameHourUtc' IS NULL THEN RETURN jsonb_build_object('status','game_clock_unverified','movementRecorded',false);END IF;
 v_now:=(clock_proof->>'gameHourUtc')::timestamptz;
 event_time:=CASE WHEN p_phase='departed' THEN l.departure_utc ELSE l.arrival_utc END;
 IF event_time>v_now OR event_time>clock_timestamp() OR (p_phase='departed' AND event_time<=v_now-interval '10 minutes')
 THEN RETURN jsonb_build_object('status','storage_event_outside_window','movementRecorded',false);END IF;
 SELECT * INTO pos FROM airlinerra_game.section9_aircraft_current_position_v1 WHERE aircraft_inventory_id=r.aircraft_inventory_id AND airline_id=r.airline_id FOR UPDATE;
 has_position:=FOUND;
 IF p_phase='departed' THEN
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_activation_release_policy_v1 a
   JOIN airlinerra_game.section9_trusted_execution_release_policy_v1 e USING(world_id)
   JOIN airlinerra_game.section9_flight_engine_readiness_audit_v1 g USING(world_id)
   WHERE a.world_id=1 AND a.release_state='enabled' AND e.release_state='enabled' AND g.trusted_flight_execution_release='ACTIVATED' AND g.fuel_transaction_release='ACTIVATED' AND g.automatic_flight_and_fuel_settlement_enabled)
  THEN RETURN jsonb_build_object('status','flight_engine_unreleased','movementRecorded',false);END IF;
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_dispatch_clearance_v1 c
   WHERE c.request_id=r.id AND c.configuration_id=i.configuration_id AND c.origin_airport_key=r.origin_airport_key
   AND c.destination_airport_key=r.destination_airport_key AND c.departure_utc=r.departure_utc AND c.arrival_utc=r.arrival_utc
   AND c.approved_at<=event_time AND c.revoked_at IS NULL)
  THEN RETURN jsonb_build_object('status','storage_dispatch_clearance_missing','movementRecorded',false);END IF;
  IF airlinerra_game.section9_canonical_aoc_covers_v1(r.airline_id,airlinerra_game.section9_verified_permission_game_day_v1(),0) IS DISTINCT FROM true
  THEN RETURN jsonb_build_object('status','storage_aoc_blocked','movementRecorded',false);END IF;
  IF outbound THEN
   IF NOT airlinerra_game.reactivation_reservation_evidence_v1(r.id) THEN RETURN jsonb_build_object('status','reactivation_reservation_changed','movementRecorded',false);END IF;
   IF airlinerra_game.aircraft_storage_reactivation_billing_check_v1(r.storage_session_id,event_time)->>'cleared' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','reactivation_storage_arrears','movementRecorded',false);END IF;
   maintenance:=airlinerra_game.storage_reactivation_maintenance_window_v1(r.owner_player_id,r.airline_id,r.aircraft_inventory_id,r.departure_utc,r.arrival_utc);
  ELSE
   maintenance:=airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(r.owner_player_id,r.airline_id,r.aircraft_inventory_id,r.departure_utc,r.arrival_utc);
  END IF;
  IF maintenance->>'gameMaintenanceClear' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','storage_maintenance_blocked','movementRecorded',false);END IF;
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_billing_classes_v1 WHERE configuration_id=i.configuration_id)
  THEN RETURN jsonb_build_object('status','storage_billing_class_missing','movementRecorded',false);END IF;
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_funds_v1 WHERE request_id=r.id AND airline_id=r.airline_id AND amount_usd=r.quoted_cost_usd AND status='held')
  THEN RETURN jsonb_build_object('status','storage_funds_not_held','movementRecorded',false);END IF;
  IF outbound THEN
   IF NOT has_position OR NOT airlinerra_game.reactivation_ground_position_valid_v1(r.id) THEN RETURN jsonb_build_object('status','storage_origin_unverified','movementRecorded',false);END IF;
  ELSE
  anchor:=airlinerra_game.section9_owned_aircraft_operational_position_v1(r.owner_player_id,r.airline_id,r.aircraft_inventory_id,(v_now AT TIME ZONE 'Europe/Berlin')::date);
  IF anchor->>'verified' IS DISTINCT FROM 'true' OR anchor->>'atGroundAirport' IS DISTINCT FROM 'true' OR anchor->>'airportKey' IS DISTINCT FROM r.origin_airport_key
  THEN RETURN jsonb_build_object('status','storage_origin_unverified','movementRecorded',false);END IF;
 END IF;
 ELSE
  IF NOT has_position OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND flight_occurrence_id=physical AND phase='departed')
  THEN RETURN jsonb_build_object('status','storage_arrival_without_departure','movementRecorded',false);END IF;
 END IF;
 decision:=airlinerra_game.section9_aircraft_movement_decision_v1(p_phase,CASE WHEN has_position THEN pos.location_status ELSE 'grounded' END,CASE WHEN has_position THEN pos.airport_key ELSE anchor->>'airportKey' END,CASE WHEN has_position THEN pos.current_flight_occurrence_id ELSE NULL END,CASE WHEN has_position THEN pos.last_event_utc ELSE NULL END,CASE WHEN has_position THEN pos.last_departure_utc ELSE NULL END,r.origin_airport_key,r.destination_airport_key,physical,event_time);
 IF decision->>'allowed' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','storage_movement_blocked','movementRecorded',false,'reason',decision->>'reason');END IF;
 payload:=airlinerra_game.aircraft_storage_event_signing_payload_v1(physical,p_phase);
 SELECT decrypted_secret INTO signer FROM vault.decrypted_secrets WHERE name='airlinerra_operated_flight_auto_signing_v1';
 IF payload IS NULL OR signer IS NULL OR length(signer)<64 THEN RETURN jsonb_build_object('status','storage_signer_unavailable','movementRecorded',false);END IF;
 signature:=encode(extensions.hmac(convert_to(payload,'UTF8'),convert_to(signer,'UTF8'),'sha256'),'hex');
 IF p_phase='departed' THEN
  fuel:=airlinerra_game.section9_auto_supply_game_only_fuel_v1(physical);
  IF fuel->>'status' IS NULL OR fuel->>'status' NOT IN ('game_only_auto_fuel_supply_recorded','game_fuel_already_sufficient') THEN RAISE EXCEPTION 'STORAGE_FUEL_SUPPLY_BLOCKED';END IF;
  q:=airlinerra_game.section9_verify_game_fuel_before_departure_v1(physical);
  IF q->>'fuelVerifiedForGame' IS DISTINCT FROM 'true' OR (q->>'plannedTripBurnKg')::numeric IS DISTINCT FROM (r.quote#>>'{fuel,tripBurnKg}')::numeric THEN RAISE EXCEPTION 'STORAGE_FUEL_QUOTE_CHANGED';END IF;
 END IF;
 INSERT INTO airlinerra_game.section9_operated_flight_movements_v1(world_id,engine_event_id,event_hmac_sha256,airline_id,aircraft_inventory_id,schedule_id,relocation_trip_id,storage_request_id,storage_reactivation,schedule_version,weekly_entry,flight_local_date,flight_occurrence_id,phase,origin_airport_key,destination_airport_key,scheduled_departure_utc,scheduled_arrival_utc,actual_event_utc)
 VALUES(1,event_id,signature,r.airline_id,r.aircraft_inventory_id,NULL,NULL,r.id,outbound,1,1,l.flight_local_date,physical,p_phase,r.origin_airport_key,r.destination_airport_key,r.departure_utc,r.arrival_utc,event_time);
 INSERT INTO airlinerra_game.section9_aircraft_current_position_v1(aircraft_inventory_id,world_id,airline_id,location_status,airport_key,current_flight_occurrence_id,last_event_utc,last_departure_utc,last_arrival_utc,last_engine_event_id,storage_request_id,storage_reactivation)
 VALUES(r.aircraft_inventory_id,1,r.airline_id,decision->>'newState',decision->>'newAirport',CASE WHEN p_phase='departed' THEN physical END,event_time,CASE WHEN p_phase='departed' THEN event_time ELSE pos.last_departure_utc END,CASE WHEN p_phase='arrived' THEN event_time ELSE pos.last_arrival_utc END,event_id,r.id,outbound)
 ON CONFLICT(aircraft_inventory_id) DO UPDATE SET location_status=excluded.location_status,airport_key=excluded.airport_key,current_flight_occurrence_id=excluded.current_flight_occurrence_id,last_event_utc=excluded.last_event_utc,last_departure_utc=excluded.last_departure_utc,last_arrival_utc=excluded.last_arrival_utc,last_engine_event_id=excluded.last_engine_event_id,storage_request_id=excluded.storage_request_id,storage_reactivation=excluded.storage_reactivation,updated_at=clock_timestamp()
 WHERE airlinerra_game.section9_aircraft_current_position_v1.airline_id=excluded.airline_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'STORAGE_POSITION_UPDATE_FAILED';END IF;
 IF p_phase='departed' THEN
  fuel:=airlinerra_game.section9_capture_verified_departure_fuel_v1(physical,event_id);
  IF fuel->>'fuelReceiptCreated' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'STORAGE_DEPARTURE_FUEL_NOT_RECORDED';END IF;
  IF outbound THEN settled:=airlinerra_game.close_storage_at_reactivation_departure_v1(r.id); IF settled->>'billingStopped' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'REACTIVATION_DEPARTURE_NOT_CLOSED';END IF;END IF;
 ELSE
  usage:=airlinerra_game.section9_apply_arrival_airframe_usage_once_v1(physical);
  IF usage->>'usageApplied' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'STORAGE_USAGE_NOT_RECORDED';END IF;
  fuel:=airlinerra_game.section9_apply_verified_arrival_fuel_burn_once_v1(physical,event_id);
  IF fuel->>'fuelBurnRecorded' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'STORAGE_FUEL_BURN_NOT_RECORDED';END IF;
  IF outbound THEN settled:=airlinerra_game.complete_aircraft_reactivation_arrival_v1(r.id); ELSE settled:=airlinerra_game.complete_aircraft_storage_arrival_v1(r.id);END IF;
  IF settled->>'status' IS DISTINCT FROM (CASE WHEN outbound THEN 'aircraft_reactivated' ELSE 'aircraft_stored' END) OR settled->>'ledgerPosted' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'STORAGE_ARRIVAL_SETTLEMENT_FAILED';END IF;
 END IF;
 RETURN jsonb_build_object('status','storage_movement_recorded','movementRecorded',true,'phase',p_phase,'physicalFlightId',physical,'fuel',fuel,'usage',usage,'settlement',settled,'passengers',0,'ticketRevenueUsd',0);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.execute_aircraft_storage_leg_v1(uuid,text) FROM PUBLIC,anon,authenticated,service_role;

-- Bounded worker. Exceptions roll back the failed leg subtransaction; one
-- blocked request does not abort the rest of the batch.
CREATE FUNCTION airlinerra_game.advance_aircraft_storage_relocations_v1(p_limit integer)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE v_now timestamptz; c record; j jsonb; results jsonb:='[]'::jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'INVALID_STORAGE_WORKER_LIMIT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_execution_release_v1 WHERE world_id=1 AND execution_enabled AND fuel_adapter_enabled)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_signed_movement_release_v1 WHERE world_id=1 AND enabled)
 THEN RETURN jsonb_build_object('status','storage_execution_not_released','results',results);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL THEN RETURN jsonb_build_object('status','game_clock_unverified','results',results);END IF;
 FOR c IN SELECT r.id,r.airline_id,CASE WHEN d.engine_event_id IS NULL THEN 'departed' ELSE 'arrived' END AS phase
 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r
 LEFT JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.storage_request_id=r.id AND d.phase='departed'
 LEFT JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.storage_request_id=r.id AND a.phase='arrived'
 WHERE r.status IN ('awaiting_slot_and_dispatch_release','reactivation_awaiting_review') AND a.engine_event_id IS NULL
 AND (r.purpose='storage_inbound' OR d.engine_event_id IS NOT NULL OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_reactivation_release_v1 WHERE world_id=1 AND enabled))
 AND ((d.engine_event_id IS NULL AND r.departure_utc<=v_now AND r.departure_utc>v_now-interval '10 minutes') OR (d.engine_event_id IS NOT NULL AND r.arrival_utc<=v_now))
 ORDER BY r.airline_id,CASE WHEN d.engine_event_id IS NOT NULL THEN 0 ELSE 1 END,r.departure_utc,r.id LIMIT p_limit
 LOOP
  BEGIN j:=airlinerra_game.execute_aircraft_storage_leg_v1(c.id,c.phase);
  EXCEPTION WHEN OTHERS THEN j:=jsonb_build_object('status','storage_leg_rolled_back','sqlstate',SQLSTATE,'movementRecorded',false);END;
  results:=results||jsonb_build_array(j||jsonb_build_object('requestId',c.id,'phase',c.phase));
 END LOOP;
 RETURN jsonb_build_object('status','storage_worker_checked','results',results);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.advance_aircraft_storage_relocations_v1(integer) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
