-- Passenger experience and airline reputation, phase 1. No booking mutation.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_passenger_experience_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 collection_enabled boolean NOT NULL DEFAULT false,
 demand_effect_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.section9_passenger_experience_release_v1(world_id) VALUES(1) ON CONFLICT DO NOTHING;
ALTER TABLE airlinerra_game.section9_passenger_experience_release_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_passenger_experience_release_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_passenger_experience_events_v1(
 event_key text PRIMARY KEY,
 world_id smallint NOT NULL CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 occurrence_id uuid REFERENCES airlinerra_game.section9_dated_flight_occurrences_v1(id),
 event_kind text NOT NULL CHECK(event_kind IN('arrived','cancelled','connection_rebooked','connection_lost')),
 happened_at timestamptz NOT NULL,
 passengers integer NOT NULL CHECK(passengers>0),
 score numeric(5,2) NOT NULL CHECK(score BETWEEN 0 AND 100),
 components jsonb NOT NULL CHECK(jsonb_typeof(components)='object'),
 model_version text NOT NULL DEFAULT 'GAME_PASSENGER_EXPERIENCE_V1',
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE airlinerra_game.section9_passenger_experience_events_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_passenger_experience_events_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE INDEX IF NOT EXISTS section9_passenger_exp_airline_time_idx ON airlinerra_game.section9_passenger_experience_events_v1(airline_id,happened_at DESC);
CREATE OR REPLACE FUNCTION airlinerra_game.section9_passenger_experience_score_v1(
 p_kind text,p_delay_minutes numeric DEFAULT 0,p_comfort numeric DEFAULT NULL,p_condition numeric DEFAULT NULL,p_fare numeric DEFAULT NULL,p_reference numeric DEFAULT NULL)
RETURNS jsonb LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path TO pg_catalog AS $$
 WITH factors AS (
 SELECT CASE WHEN p_kind='arrived' THEN greatest(-50::numeric,10-greatest(0,coalesce(p_delay_minutes,0)-15)*0.25) ELSE 0::numeric END punctuality,
 CASE WHEN p_kind='arrived' AND p_comfort BETWEEN 0 AND 100 THEN (p_comfort-60)*0.20 ELSE 0::numeric END comfort,
 CASE WHEN p_kind='arrived' AND p_condition BETWEEN 0 AND 100 THEN (p_condition-80)*0.10 ELSE 0::numeric END condition,
 CASE WHEN p_kind='arrived' AND p_fare>0 AND p_reference>0 THEN greatest(-10::numeric,least(10::numeric,10*(1-p_fare/p_reference))) ELSE 0::numeric END value_for_money
 )
 SELECT CASE WHEN p_kind IN('arrived','cancelled','connection_rebooked','connection_lost') THEN
 jsonb_build_object('score',round(CASE p_kind WHEN 'arrived' THEN greatest(0,least(100,70+punctuality+comfort+condition+value_for_money)) WHEN 'cancelled' THEN 15 WHEN 'connection_rebooked' THEN 45 WHEN 'connection_lost' THEN 20 END,2),
 'kind',p_kind,'delayMinutes',p_delay_minutes,'punctualityAdjustment',punctuality,'comfortAdjustment',comfort,'conditionAdjustment',condition,'valueAdjustment',value_for_money,
 'cabinRating',p_comfort,'aircraftConditionPct',p_condition,'averageFareUsd',p_fare,'referenceFareUsd',p_reference,'onboardServiceIncluded',false,'modelVersion','GAME_PASSENGER_EXPERIENCE_V1') END FROM factors;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_passenger_experience_score_v1(text,numeric,numeric,numeric,numeric,numeric) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_collect_passenger_experience_v1(p_limit integer DEFAULT 100)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
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
 INSERT INTO airlinerra_game.section9_passenger_experience_events_v1(event_key,world_id,airline_id,occurrence_id,event_kind,happened_at,passengers,score,components)
 VALUES(item.event_key,1,item.airline_id,item.occurrence_id,item.kind,item.happened_at,item.passengers,(evidence->>'score')::numeric,evidence)
 ON CONFLICT(event_key) DO NOTHING;
 GET DIAGNOSTICS affected=ROW_COUNT;n:=n+affected;
 END LOOP;
 RETURN jsonb_build_object('status','passenger_experience_collection_completed','created',n,'ledgerPosted',false,'bookingsChanged',false);
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_collect_passenger_experience_v1(integer) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_airline_reputation_v1(p_airline uuid)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
 WITH clock AS (SELECT airlinerra_game.section9_verified_world_instant_v1() AS now_utc),
 stats AS (
 SELECT coalesce(sum(e.passengers),0) samples,coalesce(sum(e.score*e.passengers),0) weighted,
 count(*) events,coalesce(sum(e.passengers) FILTER(WHERE e.event_kind='arrived'),0) flown,
 coalesce(sum(e.passengers) FILTER(WHERE e.event_kind='cancelled'),0) cancelled,
 coalesce(sum(e.passengers) FILTER(WHERE e.event_kind='connection_rebooked'),0) rebooked,
 coalesce(sum(e.passengers) FILTER(WHERE e.event_kind='connection_lost'),0) lost
 FROM airlinerra_game.section9_passenger_experience_events_v1 e CROSS JOIN clock
 WHERE e.airline_id=p_airline AND e.happened_at>clock.now_utc-interval '90 days' AND e.happened_at<=clock.now_utc
 ), metric AS (SELECT *,round((weighted+70*200)/(samples+200),2) reputation FROM stats)
 SELECT jsonb_build_object('status','airline_reputation_game_estimate','reputation',reputation,'baseline',70,'windowDays',90,'priorPassengerExperiences',200,
 'passengerExperiences',samples,'experienceEvents',events,'arrivedPassengers',flown,'cancelledPassengers',cancelled,'rebookedPassengers',rebooked,'lostConnectionPassengers',lost,
 'averageSatisfaction',CASE WHEN samples>0 THEN round(weighted/samples,2) ELSE NULL END,
 'potentialDemandMultiplier',round(greatest(0.75,least(1.15,1+(reputation-70)/200)),4),
 'demandEffectEnabled',false,'modelVersion','GAME_PASSENGER_EXPERIENCE_V1')
 FROM metric CROSS JOIN clock WHERE clock.now_utc IS NOT NULL AND EXISTS(SELECT 1 FROM airlinerra_game.airlines a WHERE a.id=p_airline AND a.world_id=1);
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_airline_reputation_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;
