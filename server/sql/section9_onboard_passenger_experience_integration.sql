-- Only completed, financially posted onboard receipts may affect experience.
-- Prior scores remain immutable; the release gate is initially unchanged.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_apply_onboard_experience_v1(p_physical text,p_airline uuid,p_passengers integer,p_evidence jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE r record; adjustment numeric; base_score numeric;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_onboard_service_release_v1 WHERE world_id=1 AND snapshot_enabled AND settlement_enabled AND satisfaction_enabled) THEN RETURN p_evidence;END IF;
 IF p_evidence->>'kind' IS DISTINCT FROM 'arrived' OR jsonb_typeof(p_evidence->'score') IS DISTINCT FROM 'number' OR p_passengers IS NULL OR p_passengers<=0 THEN RETURN p_evidence;END IF;
 SELECT rec.calculation,s.package_id INTO r
 FROM airlinerra_game.section9_onboard_finance_receipts_v1 rec
 JOIN airlinerra_game.section9_route_posted_flight_financials_v1 f ON f.physical_flight_id=rec.physical_flight_id AND f.airline_id=rec.airline_id AND f.passenger_count=rec.passengers AND f.other_income_usd=rec.onboard_revenue_usd AND f.other_cost_usd=rec.onboard_cost_usd
 JOIN airlinerra_game.section9_onboard_departure_snapshots_v1 s ON s.physical_flight_id=rec.physical_flight_id AND s.airline_id=rec.airline_id AND s.passengers=rec.passengers
 WHERE rec.physical_flight_id=p_physical AND rec.airline_id=p_airline AND rec.passengers=p_passengers AND rec.calculation->>'modelVersion'='GAME_CABIN_SERVICE_V2';
 IF NOT FOUND OR jsonb_typeof(r.calculation->'satisfactionAdjustment') IS DISTINCT FROM 'number' THEN RETURN p_evidence;END IF;
 adjustment:=(r.calculation->>'satisfactionAdjustment')::numeric;
 base_score:=(p_evidence->>'score')::numeric;
 IF adjustment NOT BETWEEN 0 AND 10 OR base_score NOT BETWEEN 0 AND 100 THEN RETURN p_evidence;END IF;
 RETURN p_evidence||jsonb_build_object('score',round(least(100,base_score+adjustment),2),'onboardServiceIncluded',true,'onboardServiceAdjustment',adjustment,'onboardPackageId',r.package_id,'onboardModelVersion','GAME_CABIN_SERVICE_V2','scoreBeforeOnboardServices',base_score);
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_apply_onboard_experience_v1(text,uuid,integer,jsonb) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_collect_passenger_experience_v1(p_limit integer DEFAULT 100)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE item record; evidence jsonb; comfort numeric; condition numeric; fare numeric; ref_fare numeric; delay_m numeric; n integer:=0; affected integer; now_utc timestamptz;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_PASSENGER_EXPERIENCE_WORKER';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 250 THEN RAISE EXCEPTION 'INVALID_PASSENGER_EXPERIENCE_LIMIT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_passenger_experience_release_v1 WHERE world_id=1 AND collection_enabled) THEN RETURN jsonb_build_object('status','passenger_experience_not_released','created',0);END IF;
 IF NOT pg_try_advisory_xact_lock(583729,10062) THEN RETURN jsonb_build_object('status','passenger_experience_worker_busy','created',0);END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_utc IS NULL THEN RETURN jsonb_build_object('status','passenger_experience_clock_unverified','created',0);END IF;
 -- Only settled passenger counts, not forecasts, are counted as flown experiences.
 FOR item IN
 SELECT 'arrival:'||f.physical_flight_id AS event_key,'arrived'::text AS kind,f.airline_id,o.id AS occurrence_id,
 f.passenger_count AS passengers,m.actual_event_utc AS happened_at,o.arrival_utc AS scheduled_arrival,
 d.actual_event_utc AS actual_departure,o.aircraft_inventory_id,f.ticket_income_usd AS fare_total,
 extract(epoch FROM(o.arrival_utc-o.departure_utc))/60 AS flight_minutes
 FROM airlinerra_game.section9_route_posted_flight_financials_v1 f
 JOIN airlinerra_game.section9_operated_flight_movements_v1 m ON m.engine_event_id=f.arrived_event_id AND m.flight_occurrence_id=f.physical_flight_id AND m.phase='arrived' AND m.airline_id=f.airline_id
 JOIN airlinerra_game.section9_operated_flight_movements_v1 d ON d.flight_occurrence_id=f.physical_flight_id AND d.phase='departed' AND d.airline_id=f.airline_id
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.schedule_id=f.schedule_id AND o.airline_id=f.airline_id AND o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text=f.physical_flight_id
 WHERE o.world_id=1 AND o.booking_status='closed' AND f.passenger_count>0 AND m.actual_event_utc<=now_utc
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_passenger_experience_events_v1 e WHERE e.event_key='arrival:'||f.physical_flight_id)
 UNION ALL
 SELECT 'cancel:'||c.physical_flight_id,'cancelled',c.airline_id,o.id,c.cancelled_seats,c.cancelled_at,NULL,NULL,o.aircraft_inventory_id,NULL,NULL
 FROM airlinerra_game.section9_flight_cancellation_receipts_v1 c JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.id=c.occurrence_id AND o.airline_id=c.airline_id
 WHERE o.world_id=1 AND o.booking_status='cancelled' AND c.cancelled_seats>0 AND c.cancelled_at<=now_utc
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_passenger_experience_events_v1 e WHERE e.event_key='cancel:'||c.physical_flight_id)
 UNION ALL
 SELECT 'connection:'||r.source_allocation_key,CASE WHEN r.result->>'status'='connection_rebooked' THEN 'connection_rebooked' ELSE 'connection_lost' END,o.airline_id,o.id,h.passengers,r.recorded_at,NULL,NULL,o.aircraft_inventory_id,NULL,NULL
 FROM airlinerra_game.section9_connection_recovery_receipts_v1 r
 JOIN airlinerra_game.section9_atomic_itinerary_holds_v1 h ON h.source_allocation_key=r.source_allocation_key AND h.passengers>0 AND h.cargo_tonnes=0
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text=h.physical_flight_ids[CASE WHEN r.result->>'reason'='second_leg_cancelled' THEN 2 ELSE 1 END]
 WHERE o.world_id=1 AND r.recorded_at<=now_utc AND r.result->>'recovered'='true'
 AND EXISTS(SELECT 1 FROM airlinerra_game.section9_passenger_reservation_batches_v1 b WHERE b.reservation_key='demand.'||r.source_allocation_key AND b.occurrence_id IN(SELECT d.id FROM airlinerra_game.section9_dated_flight_occurrences_v1 d WHERE d.schedule_id::text||':'||d.flight_local_date::text||':'||d.weekly_entry::text=h.physical_flight_ids[2]))
 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_passenger_experience_events_v1 e WHERE e.event_key='connection:'||r.source_allocation_key)
 ORDER BY happened_at,event_key LIMIT p_limit
 LOOP
 comfort:=NULL;condition:=NULL;fare:=NULL;ref_fare:=NULL;delay_m:=0;
 IF item.kind='arrived' THEN
  delay_m:=greatest(0,extract(epoch FROM(item.happened_at-item.scheduled_arrival))/60);
  -- If cabin has changed after departure, the current rating is not historical proof.
  SELECT c.comfort_rating INTO comfort FROM airlinerra_game.section9_installed_cabin_comfort_v1 c
  JOIN airlinerra_game.aircraft_installed_cabins_v1 i USING(aircraft_inventory_id,airline_id,configuration_id)
  WHERE c.aircraft_inventory_id=item.aircraft_inventory_id AND c.airline_id=item.airline_id AND i.updated_at<=item.actual_departure;
  condition:=(airlinerra_game.section9_game_airframe_condition_v1(item.airline_id,item.aircraft_inventory_id,item.actual_departure)->>'conditionPct')::numeric;
  fare:=item.fare_total/item.passengers;ref_fare:=greatest(45,least(650,45+item.flight_minutes*0.65));
 END IF;
 evidence:=airlinerra_game.section9_passenger_experience_score_v1(item.kind,delay_m,comfort,condition,fare,ref_fare);
 IF item.kind='arrived' THEN
  evidence:=airlinerra_game.section9_apply_onboard_experience_v1(substring(item.event_key from 9),item.airline_id,item.passengers,evidence);
 END IF;
 INSERT INTO airlinerra_game.section9_passenger_experience_events_v1(event_key,world_id,airline_id,occurrence_id,event_kind,happened_at,passengers,score,components)
 VALUES(item.event_key,1,item.airline_id,item.occurrence_id,item.kind,item.happened_at,item.passengers,(evidence->>'score')::numeric,evidence)
 ON CONFLICT(event_key) DO NOTHING;
 GET DIAGNOSTICS affected=ROW_COUNT;n:=n+affected;
 END LOOP;
 RETURN jsonb_build_object('status','passenger_experience_collection_completed','created',n,'ledgerPosted',false,'bookingsChanged',false);
END;
$function$;
