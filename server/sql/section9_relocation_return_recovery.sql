BEGIN;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_reschedule_relocation_return_v1(p_player uuid,p_airline uuid,p_trip uuid,p_departure timestamptz)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE t record; svc record; pos jsonb; q jsonb; flight jsonb; restriction jsonb; proof jsonb; v_now timestamptz; arr timestamptz; available timestamptz; duration int; turnaround int; config bigint;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_RELOCATION_RECOVERY_ONLY';END IF;
 SELECT r.* INTO t FROM airlinerra_game.section9_maintenance_relocation_trips_v1 r JOIN airlinerra_game.airlines a ON a.id=r.airline_id AND a.owner_player_id=p_player AND a.world_id=1 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active' WHERE r.id=p_trip AND r.airline_id=p_airline AND r.owner_player_id=p_player FOR UPDATE OF r;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='RELOCATION_NOT_OWNED';END IF;
 IF t.status<>'reserved' OR t.last_result IS DISTINCT FROM 'return_recovery_required' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_relocation_release_v1 WHERE world_id=1 AND reservation_enabled AND execution_enabled) THEN RETURN jsonb_build_object('status','return_recovery_not_available','rescheduled',false,'ledgerPosted',false);END IF;
 SELECT f.configuration_id INTO config FROM airlinerra_game.airline_aircraft_inventory f WHERE f.id=t.aircraft_inventory_id AND f.airline_id=t.airline_id AND f.fleet_status='in_service' FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','aircraft_unavailable','rescheduled',false,'ledgerPosted',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE relocation_trip_id=p_trip AND weekly_entry=2 AND phase='departed') THEN RETURN jsonb_build_object('status','return_already_departed','rescheduled',false,'ledgerPosted',false);END IF;
 SELECT m.game_completed_at_utc,j.engine_completion_observed_at INTO svc FROM airlinerra_game.section9_game_maintenance_jobs_v1 j JOIN airlinerra_game.section9_game_maintenance_service_receipts_v1 m ON m.job_id=j.job_id JOIN airlinerra_game.airline_ledger b ON b.id=m.paid_ledger_entry_id AND b.airline_id=t.airline_id AND b.entry_kind='EXPENSE' AND b.amount_usd=-m.settled_cost_usd WHERE j.job_id=t.maintenance_job_id AND j.status='completed' AND j.airline_id=t.airline_id AND j.aircraft_inventory_id=t.aircraft_inventory_id;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','relocation_service_not_completed','rescheduled',false,'ledgerPosted',false);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 turnaround:=(t.quote->>'turnaroundMinutes')::int;duration:=(t.quote#>>'{return,flightMinutes}')::int;
 IF p_departure IS NULL OR p_departure<>date_trunc('second',p_departure) OR p_departure<v_now+interval '1 minute' OR p_departure>v_now+interval '7 days' OR p_departure<greatest(svc.game_completed_at_utc,svc.engine_completion_observed_at)+make_interval(mins=>turnaround) THEN RETURN jsonb_build_object('status','invalid_recovery_departure','rescheduled',false,'ledgerPosted',false);END IF;
 arr:=p_departure+make_interval(mins=>duration);available:=arr+make_interval(mins=>turnaround);
 pos:=airlinerra_game.section9_owned_aircraft_operational_position_v1(p_player,p_airline,t.aircraft_inventory_id,(v_now AT TIME ZONE 'Europe/Berlin')::date);
 IF pos->>'verified' IS DISTINCT FROM 'true' OR pos->>'atGroundAirport' IS DISTINCT FROM 'true' OR pos->>'airportKey' IS DISTINCT FROM t.provider_airport_key THEN RETURN jsonb_build_object('status','relocation_position_unverified','rescheduled',false,'ledgerPosted',false);END IF;
 IF airlinerra_game.section9_game_route_licence_scope_v1(p_airline,t.provider_airport_key,t.origin_airport_key,(v_now AT TIME ZONE 'Europe/Berlin')::date,((arr AT TIME ZONE 'Europe/Berlin')::date-(v_now AT TIME ZONE 'Europe/Berlin')::date))->>'allowed' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','relocation_licence_blocked','rescheduled',false,'ledgerPosted',false);END IF;
 proof:=airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(p_player,p_airline,t.aircraft_inventory_id,p_departure,arr);
 IF proof->>'gameMaintenanceClear' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','recovery_maintenance_not_ready','rescheduled',false,'blockers',proof->'blockers','ledgerPosted',false);END IF;
 restriction:=airlinerra_game.section5_universal_route_restriction_gate_v1(1::smallint,t.provider_airport_key,t.origin_airport_key,config,p_departure,arr,NULL,NULL);
 IF NOT airlinerra_game.section9_game_route_restrictions_valid_v1(t.provider_airport_key,t.origin_airport_key,jsonb_build_object('weeklyTimetableChecked',true,'gameHardBlocked',(restriction->>'gameHardBlocked')::boolean,'occurrences',jsonb_build_array(restriction))) THEN RETURN jsonb_build_object('status','relocation_airport_restrictions_blocked','rescheduled',false,'ledgerPosted',false);END IF;
 proof:=airlinerra_game.section9_owned_hourly_maintenance_slot_preflight_v1(p_player,p_airline,t.aircraft_inventory_id,v_now,available);
 IF proof->>'slotClear' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','recovery_aircraft_schedule_conflict','rescheduled',false,'ledgerPosted',false);END IF;
 flight:=airlinerra_game.section9_owned_route_commercial_forecast_v1(p_player,p_airline,t.aircraft_inventory_id,t.provider_airport_key,t.origin_airport_key,'remote','remote',turnaround,0,0);
 IF flight->>'status' IS DISTINCT FROM 'route_phase1_forecast' OR (flight#>>'{phases,totalMinutes}')::int IS DISTINCT FROM duration OR (flight#>>'{fuel,tripBurnKg}')::numeric IS DISTINCT FROM (t.quote#>>'{return,fuelBurnKg}')::numeric OR (flight->>'directOperatingCostUsd')::numeric IS DISTINCT FROM (t.quote#>>'{return,totalUsd}')::numeric THEN RETURN jsonb_build_object('status','return_quote_changed','rescheduled',false,'ledgerPosted',false);END IF;
 PERFORM 1 FROM airlinerra_game.section6_airport_slot_capacity_v1 WHERE world_id=1 AND airport_key IN(t.provider_airport_key,t.origin_airport_key) ORDER BY airport_key FOR UPDATE;
 BEGIN
  DELETE FROM airlinerra_game.section6_dated_relocation_slots_v1 WHERE trip_id=p_trip AND leg='return';
  INSERT INTO airlinerra_game.section6_dated_relocation_slots_v1(trip_id,leg,airport_key,direction,movement_utc,local_date,weekday,minute_of_day)
  VALUES(p_trip,'return',t.provider_airport_key,'departure',p_departure,current_date,0,0),(p_trip,'return',t.origin_airport_key,'arrival',arr,current_date,0,0);
  q:=jsonb_set(t.quote,'{return}',t.quote->'return'||jsonb_build_object('departureUtc',p_departure,'arrivalUtc',arr,'availableUtc',available));
  q:=jsonb_set(q,'{totalDowntimeMinutes}',to_jsonb(round(extract(epoch FROM available-t.departure_utc)/60)::int));
  UPDATE airlinerra_game.section9_maintenance_relocation_trips_v1 SET quote=q,available_utc=available,last_attempt_at=v_now,last_result='return_rescheduled' WHERE id=p_trip;
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM LIKE 'RELOCATION_%' THEN RETURN jsonb_build_object('status','recovery_airport_slot_unavailable','rescheduled',false,'ledgerPosted',false);END IF;RAISE;
 END;
 RETURN jsonb_build_object('status','return_rescheduled','rescheduled',true,'tripId',p_trip,'departureUtc',p_departure,'arrivalUtc',arr,'availableUtc',available,'returnCostUsd',t.quote#>'{return,totalUsd}','slotsReserved',2,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_reschedule_relocation_return_v1(uuid,uuid,uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;