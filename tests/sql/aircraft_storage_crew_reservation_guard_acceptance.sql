DO $crew_guard$
DECLARE s record; owner_id uuid; j jsonb; r record; dep timestamptz; v_now timestamptz; rid uuid; plan uuid:=gen_random_uuid(); emp uuid:=gen_random_uuid(); blocked boolean:=false;
BEGIN
 SELECT * INTO STRICT s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE storage_ended_utc IS NULL;
 SELECT owner_player_id INTO STRICT owner_id FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=s.request_id;
 v_now:=s.storage_started_utc;
 PERFORM set_config('test.storage_hour',v_now::text,true);
 dep:=date_trunc('second',v_now+interval '3 hours');
 j:=airlinerra_game.request_aircraft_storage_reactivation_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'OURAIRPORTS:999',dep,2688.13,gen_random_uuid());
 IF j->>'created' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'crew request fixture failed: %',j;END IF;
 rid:=(j->>'requestId')::uuid;
 SELECT * INTO STRICT r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=rid;
 INSERT INTO airlinerra_game.section9_crew_plan_batches_v1 VALUES(plan,s.airline_id,'validated_preview');
 INSERT INTO airlinerra_game.section9_planned_crew_duties_v1(plan_id,airline_id,pilot_id,duty_end_utc) VALUES(plan,s.airline_id,emp,dep);
 BEGIN
  INSERT INTO airlinerra_game.aircraft_storage_crew_reservations_v1(request_id,airline_id,employee_id,seat_role,qualification_group,duty_start_utc,duty_end_utc,origin_airport_key,destination_airport_key,reserved_at)
  VALUES(rid,s.airline_id,emp,'captain','fixture',dep-interval '2 hours',r.arrival_utc+interval '30 minutes',r.origin_airport_key,r.destination_airport_key,v_now);
 EXCEPTION WHEN raise_exception THEN
  IF SQLERRM<>'STORAGE_CREW_RESERVATION_CONFLICT' THEN RAISE;END IF;
  blocked:=true;
 END;
 IF NOT blocked THEN RAISE EXCEPTION 'commercial duty conflict accepted';END IF;
 DELETE FROM airlinerra_game.section9_planned_crew_duties_v1 WHERE pilot_id=emp;
 INSERT INTO airlinerra_game.aircraft_storage_crew_reservations_v1(request_id,airline_id,employee_id,seat_role,qualification_group,duty_start_utc,duty_end_utc,origin_airport_key,destination_airport_key,reserved_at)
 VALUES(rid,s.airline_id,emp,'captain','fixture',dep-interval '2 hours',r.arrival_utc+interval '30 minutes',r.origin_airport_key,r.destination_airport_key,v_now);
 blocked:=false;
 BEGIN
  INSERT INTO airlinerra_game.section9_planned_crew_duties_v1(plan_id,airline_id,pilot_id,duty_end_utc) VALUES(plan,s.airline_id,emp,dep+interval '2 days');
 EXCEPTION WHEN check_violation THEN
  IF SQLERRM<>'CREW_RESERVED_FOR_STORAGE_OR_HISTORY_HANDOFF' THEN RAISE;END IF;
  blocked:=true;
 END;
 IF NOT blocked THEN RAISE EXCEPTION 'commercial planner reused reserved crew';END IF;
 j:=airlinerra_game.cancel_owned_aircraft_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,rid);
 IF j->>'cancelled' IS DISTINCT FROM 'true' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=rid AND status='cancelled') THEN RAISE EXCEPTION 'pre-report cancellation did not release crew: %',j;END IF;
 INSERT INTO airlinerra_game.section9_planned_crew_duties_v1(plan_id,airline_id,pilot_id,duty_end_utc) VALUES(plan,s.airline_id,emp,dep);
 DELETE FROM airlinerra_game.section9_planned_crew_duties_v1 WHERE pilot_id=emp;
 j:=airlinerra_game.request_aircraft_storage_reactivation_v1(owner_id,s.airline_id,s.aircraft_inventory_id,'OURAIRPORTS:999',dep,2688.13,gen_random_uuid());
 IF j->>'created' IS DISTINCT FROM 'true' THEN RAISE EXCEPTION 'second crew request fixture failed: %',j;END IF;
 rid:=(j->>'requestId')::uuid;
 SELECT * INTO STRICT r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=rid;
 INSERT INTO airlinerra_game.aircraft_storage_crew_reservations_v1(request_id,airline_id,employee_id,seat_role,qualification_group,duty_start_utc,duty_end_utc,origin_airport_key,destination_airport_key,reserved_at)
 VALUES(rid,s.airline_id,emp,'captain','fixture',dep-interval '2 hours',r.arrival_utc+interval '30 minutes',r.origin_airport_key,r.destination_airport_key,v_now);
 PERFORM set_config('test.storage_hour',(dep-interval '2 hours')::text,true);
 j:=airlinerra_game.cancel_owned_aircraft_storage_booking_v1(owner_id,s.airline_id,s.aircraft_inventory_id,rid);
 IF j->>'cancelled' IS DISTINCT FROM 'true' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=rid AND status='awaiting_history_handoff') THEN RAISE EXCEPTION 'post-report cancellation lost crew custody: %',j;END IF;
 blocked:=false;
 BEGIN
  INSERT INTO airlinerra_game.section9_planned_crew_duties_v1(plan_id,airline_id,pilot_id,duty_end_utc) VALUES(plan,s.airline_id,emp,dep+interval '2 days');
 EXCEPTION WHEN check_violation THEN blocked:=true;
 END;
 IF NOT blocked THEN RAISE EXCEPTION 'unreconciled crew reused';END IF;
 RAISE NOTICE 'Storage crew reservation guard acceptance passed (synthetic commercial duty records)';
END $crew_guard$;
ROLLBACK TO SAVEPOINT storage_crew_guard;
