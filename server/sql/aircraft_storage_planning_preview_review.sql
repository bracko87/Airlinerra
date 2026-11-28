-- REVIEW ONLY. Owner-scoped airport selection and relocation estimate.
-- No reservation, release, financial mutation, or commercial admission.
BEGIN;
CREATE FUNCTION airlinerra_game.owned_aircraft_storage_planning_context_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE i record; s record; pos jsonb; origin text; v_now timestamptz;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT f.* INTO i FROM airlinerra_game.airline_aircraft_inventory f
 JOIN airlinerra_game.airlines a ON a.id=f.airline_id AND a.world_id=1 AND a.owner_player_id=p_player
 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE f.id=p_aircraft AND f.airline_id=p_airline AND f.ownership_type='owned';
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_purpose IS NULL OR p_purpose NOT IN ('storage_inbound','storage_reactivation') THEN RETURN jsonb_build_object('status','invalid_storage_purpose');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r WHERE r.aircraft_inventory_id=p_aircraft AND r.status IN('awaiting_slot_and_dispatch_release','reactivation_awaiting_review')) THEN RETURN jsonb_build_object('status','storage_request_already_pending');END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL THEN RETURN jsonb_build_object('status','storage_clock_unverified');END IF;
 IF p_purpose='storage_inbound' THEN
  IF i.fleet_status<>'in_service' THEN RETURN jsonb_build_object('status','storage_aircraft_unavailable');END IF;
  pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(p_player,p_airline,p_aircraft,(v_now AT TIME ZONE 'Europe/Berlin')::date);
  IF pos->>'verified' IS DISTINCT FROM 'true' OR pos->>'atGroundAirport' IS DISTINCT FROM 'true' OR pos->>'airportKey' IS NULL THEN RETURN jsonb_build_object('status','storage_position_unverified');END IF;
  origin:=pos->>'airportKey';
 ELSE
  IF i.fleet_status<>'stored' THEN RETURN jsonb_build_object('status','aircraft_not_stored');END IF;
  SELECT * INTO s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft AND storage_ended_utc IS NULL;
  IF NOT FOUND THEN RETURN jsonb_build_object('status','active_storage_session_missing');END IF;
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_aircraft_current_position_v1 p JOIN airlinerra_game.section9_operated_flight_movements_v1 m ON m.engine_event_id=p.last_engine_event_id
   WHERE p.aircraft_inventory_id=p_aircraft AND p.airline_id=p_airline AND p.location_status='grounded' AND p.airport_key=s.airport_key AND p.storage_request_id=s.request_id
   AND m.engine_event_id=s.arrival_engine_event_id AND m.storage_request_id=s.request_id AND m.aircraft_inventory_id=p_aircraft AND m.airline_id=p_airline AND m.phase='arrived' AND m.destination_airport_key=s.airport_key AND m.actual_event_utc=s.storage_started_utc
   AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 later WHERE later.aircraft_inventory_id=p_aircraft AND later.airline_id=p_airline AND (later.actual_event_utc>m.actual_event_utc OR (later.actual_event_utc=m.actual_event_utc AND later.engine_event_id<>m.engine_event_id)))) THEN RETURN jsonb_build_object('status','storage_position_unverified');END IF;
  origin:=s.airport_key;
  IF airlinerra_game.aircraft_storage_airport_admission_v1(origin,p_purpose)->>'eligible' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','storage_reactivation_not_approved');END IF;
 END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft AND status='active') THEN RETURN jsonb_build_object('status','active_routes_require_closure');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft AND status IN('scheduled','in_progress','payment_required'))
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_maintenance_relocation_trips_v1 WHERE aircraft_inventory_id=p_aircraft AND status='reserved') THEN RETURN jsonb_build_object('status','existing_aircraft_commitment');END IF;
 RETURN jsonb_build_object('status','storage_planning_ready','originAirportKey',origin,'configurationId',i.configuration_id,'serverNowUtc',v_now,'storageSessionId',CASE WHEN p_purpose='storage_reactivation' THEN (SELECT request_id FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE airline_id=p_airline AND aircraft_inventory_id=p_aircraft AND storage_ended_utc IS NULL) END);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.owned_aircraft_storage_planning_context_v1(uuid,uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.owned_aircraft_storage_destinations_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_search text)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE ctx jsonb; results jsonb; term text:=lower(btrim(coalesce(p_search,'')));
BEGIN
 ctx:=airlinerra_game.owned_aircraft_storage_planning_context_v1(p_player,p_airline,p_aircraft,p_purpose);
 IF length(term)>80 THEN RAISE EXCEPTION USING ERRCODE='22023';END IF;
 IF ctx->>'status'<>'storage_planning_ready' THEN RETURN ctx||jsonb_build_object('airlineId',p_airline,'aircraftId',p_aircraft,'purpose',p_purpose,'airports','[]'::jsonb,'readOnly',true,'actionsReleased',false);END IF;
 SELECT coalesce(jsonb_agg(to_jsonb(x) ORDER BY x."airportName",x."airportKey"),'[]'::jsonb) INTO results FROM (
 SELECT r.airport_key AS "airportKey",r.airport_name AS "airportName",coalesce(r.source_gps_code,r.source_ident) AS "airportCode",r.country_iso AS "countryIso",
 CASE WHEN p_purpose='storage_inbound' THEN f.admission_scope ELSE 'existing_commercial' END AS "scope"
 FROM airlinerra.airport_registry r
 LEFT JOIN airlinerra_game.aircraft_storage_facilities_v1 f ON f.world_id=1 AND f.airport_key=r.airport_key
 WHERE r.airport_key<>ctx->>'originAirportKey'
 AND ((p_purpose='storage_inbound' AND f.review_state='approved' AND airlinerra_game.aircraft_storage_airport_admission_v1(r.airport_key,p_purpose)->>'eligible'='true')
 OR (p_purpose='storage_reactivation' AND length(term)>=2 AND EXISTS(SELECT 1 FROM airlinerra_game.airport_unified_operations_v1 u WHERE u.world_id=1 AND u.airport_key=r.airport_key AND u.operationally_authorized AND u.dispatch_eligible_by_airport_admission)))
 AND (term='' OR strpos(lower(concat_ws(' ',r.airport_name,r.source_gps_code,r.source_ident,r.country_iso,r.airport_key)),term)>0)
 ORDER BY r.airport_name,r.airport_key LIMIT 50) x;
 RETURN ctx||jsonb_build_object('status','storage_destinations_verified','airlineId',p_airline,'aircraftId',p_aircraft,'purpose',p_purpose,'airports',results,'searchRequired',p_purpose='storage_reactivation' AND length(term)<2,'readOnly',true,'actionsReleased',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.owned_aircraft_storage_destinations_v1(uuid,uuid,uuid,text,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.owned_aircraft_storage_cost_preview_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_purpose text,p_destination text,p_departure timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE ctx jsonb; q jsonb; base jsonb; v_now timestamptz; billing jsonb; monthly numeric;
BEGIN
 ctx:=airlinerra_game.owned_aircraft_storage_planning_context_v1(p_player,p_airline,p_aircraft,p_purpose);
 base:=jsonb_build_object('airlineId',p_airline,'aircraftId',p_aircraft,'purpose',p_purpose,'destinationAirportKey',p_destination,'departureUtc',p_departure,'readOnly',true,'actionsReleased',false,'bookable',false);
 IF ctx->>'status'<>'storage_planning_ready' THEN RETURN base||jsonb_build_object('status',ctx->>'status');END IF;
 v_now:=(ctx->>'serverNowUtc')::timestamptz;
 IF p_departure IS NULL OR p_departure<>date_trunc('second',p_departure) OR p_departure<v_now+interval '1 minute' OR p_departure>v_now+interval '7 days' THEN RETURN base||jsonb_build_object('status','storage_departure_unverified');END IF;
 q:=airlinerra_game.aircraft_storage_relocation_cost_v1((ctx->>'configurationId')::bigint,ctx->>'originAirportKey',p_destination,p_purpose);
 IF q->>'status' IS DISTINCT FROM 'storage_relocation_cost_estimate' OR q->>'fuelRangeConfirmed' IS DISTINCT FROM 'true' OR q->>'directOperatingCostUsd' IS NULL THEN RETURN base||jsonb_build_object('status','storage_quote_blocked','reason',q->>'status');END IF;
 IF p_purpose='storage_inbound' THEN
 SELECT CASE c.billing_class WHEN 'regional' THEN f.monthly_regional_usd WHEN 'narrowbody' THEN f.monthly_narrowbody_usd WHEN 'widebody' THEN f.monthly_widebody_usd END INTO monthly
 FROM airlinerra_game.aircraft_storage_facilities_v1 f CROSS JOIN airlinerra_game.aircraft_storage_billing_classes_v1 c WHERE f.world_id=1 AND f.airport_key=p_destination AND c.configuration_id=(ctx->>'configurationId')::bigint;
 IF monthly IS NULL THEN RETURN base||jsonb_build_object('status','storage_billing_class_missing');END IF;
 ELSE
 billing:=airlinerra_game.aircraft_storage_reactivation_billing_check_v1((ctx->>'storageSessionId')::uuid,p_departure);
 IF billing->>'status' IS NULL OR billing->>'status' NOT IN('storage_billing_current','storage_billing_due') THEN RETURN base||jsonb_build_object('status','storage_billing_unverified');END IF;
 END IF;
 RETURN base||jsonb_build_object('status','storage_cost_preview_verified','originAirportKey',ctx->>'originAirportKey','arrivalUtc',p_departure+make_interval(mins=>(q#>>'{phases,totalMinutes}')::int),'distanceKm',q#>'{phases,distanceKm}','durationMinutes',q#>'{phases,totalMinutes}','fuelUsd',q->'fuelCostUsd','airportFeesUsd',q->'airportFeesUsd','relocationUsd',q->'directOperatingCostUsd','monthlyStorageUsd',monthly,'billingAtDeparture',billing,'excludesCrewAndMonthlyStorage',true,'dispatchAuthorized',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.owned_aircraft_storage_cost_preview_v1(uuid,uuid,uuid,text,text,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
