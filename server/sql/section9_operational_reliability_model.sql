BEGIN;
-- Game balancing only. No real-world reliability or airworthiness assertion.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_reliability_model_v1(p_condition numeric,p_flight_hours numeric)
RETURNS jsonb LANGUAGE sql IMMUTABLE STRICT SECURITY INVOKER SET search_path TO 'pg_catalog' AS $fn$
 WITH m AS (
 SELECT greatest(0,least(100,p_condition)) c,greatest(0,least(24,p_flight_hours)) h
 ), r AS (
 SELECT c,h,round(least(60::numeric,1+power((100-c)/100,1.5::numeric)*45+power(greatest(0,h-18)/6,1.5::numeric)*25),2) delay_chance FROM m
 )
 SELECT jsonb_build_object('conditionPct',round(c,2),'utilizationPct',least(100,round(h/18*100)),'overloaded',h>18,'operationalReliabilityPct',round(100-delay_chance,2),'technicalDelayProbabilityPct',delay_chance,'model','GAME_OPERATIONAL_RELIABILITY_V1','dispatchEffectsEnabled',false) FROM r
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_reliability_model_v1(numeric,numeric) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_aircraft_reliability_v1(p_player uuid,p_airline uuid,p_aircraft uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog' AS $fn$
DECLARE v_now timestamptz; c jsonb; h numeric; model jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='PRIVATE_RELIABILITY_ONLY';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory f JOIN airlinerra_game.airlines a ON a.id=f.airline_id AND a.owner_player_id=p_player AND a.world_id=1 JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active' WHERE f.id=p_aircraft AND f.airline_id=p_airline AND f.ownership_type IN ('owned','leased')) THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='RELIABILITY_AIRCRAFT_NOT_OWNED';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 c:=airlinerra_game.section9_game_airframe_condition_v1(p_airline,p_aircraft,v_now);
 IF v_now IS NULL OR c->>'conditionPct' IS NULL THEN RETURN jsonb_build_object('status','reliability_baseline_unavailable','aircraftInventoryId',p_aircraft,'readOnly',true,'ledgerPosted',false);END IF;
 -- Merge intervals so duplicate/overlapping evidence cannot inflate utilization.
 -- Includes elapsed airborne time; excludes turnaround and maintenance.
 WITH intervals AS (
 SELECT greatest(d.actual_event_utc,v_now-interval '24 hours') s,least(coalesce(a.actual_event_utc,v_now),v_now) e
 FROM airlinerra_game.section9_operated_flight_movements_v1 d
 LEFT JOIN airlinerra_game.section9_operated_flight_movements_v1 a ON a.flight_occurrence_id=d.flight_occurrence_id AND a.phase='arrived' AND a.airline_id=d.airline_id AND a.aircraft_inventory_id=d.aircraft_inventory_id AND a.source_kind='signed_operated_game_flight_v1'
 WHERE d.world_id=1 AND d.airline_id=p_airline AND d.aircraft_inventory_id=p_aircraft AND d.phase='departed' AND d.source_kind='signed_operated_game_flight_v1'
 AND d.actual_event_utc<v_now AND coalesce(a.actual_event_utc,v_now)>v_now-interval '24 hours'
 -- A missing arrival is not treated as unlimited continuous flight: only a
 -- currently verified in-flight position may contribute elapsed flight time.
 AND (a.engine_event_id IS NOT NULL OR EXISTS(SELECT 1 FROM airlinerra_game.section9_aircraft_current_position_v1 pos WHERE pos.aircraft_inventory_id=p_aircraft AND pos.airline_id=p_airline AND pos.location_status='in_flight' AND pos.current_flight_occurrence_id=d.flight_occurrence_id))
 ), ordered AS (
 SELECT s,e,max(e) OVER(ORDER BY s,e ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) previous_end FROM intervals WHERE e>s
 )
 SELECT coalesce(sum(extract(epoch FROM greatest(interval '0',e-greatest(s,coalesce(previous_end,s)))))/3600,0) INTO h FROM ordered;
 model:=airlinerra_game.section9_reliability_model_v1((c->>'conditionPct')::numeric,h);
 RETURN model||jsonb_build_object('status','aircraft_reliability_preview','aircraftInventoryId',p_aircraft,'asOfUtc',v_now,'readOnly',true,'ledgerPosted',false,'utilizationBasis','rolling_24h_signed_flying_time','reliabilityBasis','game_estimate_not_observed_punctuality');
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_aircraft_reliability_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;
-- Pure scenario model: technical delays + inherited aircraft lateness.
-- No slot, booking, movement or ledger changes. A cancelled flight never
-- moves the aircraft. Any following leg at the wrong airport is cancelled.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_preview_delay_rotation_v1(p_airport text,p_available timestamptz,p_legs jsonb,p_cancellation_minutes integer DEFAULT 180)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO 'pg_catalog' AS $fn$
DECLARE l jsonb; dep timestamptz; arr timestamptz; actual_dep timestamptz; actual_arr timestamptz; available timestamptz:=p_available; airport text:=p_airport; last_scheduled timestamptz; technical int; buffer int; delay_min int; rows jsonb:='[]'::jsonb; why text; ids text[]:=ARRAY[]::text[];
BEGIN
 IF p_airport IS NULL OR p_available IS NULL OR jsonb_typeof(p_legs) IS DISTINCT FROM 'array' OR jsonb_array_length(p_legs)>100 OR p_cancellation_minutes IS NULL OR p_cancellation_minutes NOT BETWEEN 30 AND 720 THEN RAISE EXCEPTION 'INVALID_DELAY_SCENARIO';END IF;
 FOR l IN SELECT value FROM jsonb_array_elements(p_legs) LOOP
  dep:=(l->>'departureUtc')::timestamptz;arr:=(l->>'arrivalUtc')::timestamptz;
  technical:=coalesce((l->>'technicalDelayMinutes')::int,0);buffer:=(l->>'turnaroundMinutes')::int;why:=NULL;
  IF l->>'id' IS NULL OR l->>'id'=ANY(ids) OR l->>'from' IS NULL OR l->>'to' IS NULL OR l->>'from'=l->>'to' OR dep IS NULL OR arr IS NULL OR arr<=dep OR (last_scheduled IS NOT NULL AND dep<last_scheduled) OR technical NOT BETWEEN 0 AND 720 OR buffer IS NULL OR buffer NOT BETWEEN 0 AND 360 THEN RAISE EXCEPTION 'INVALID_DELAY_SCENARIO_LEG';END IF;
  ids:=array_append(ids,l->>'id');last_scheduled:=dep;
  actual_dep:=greatest(dep,available)+make_interval(mins=>technical);delay_min:=ceil(extract(epoch FROM actual_dep-dep)/60)::int;
  IF airport IS DISTINCT FROM l->>'from' THEN why:='aircraft_at_wrong_airport';
  ELSIF delay_min>p_cancellation_minutes THEN why:='maximum_delay_exceeded';END IF;
  IF why IS NOT NULL THEN
   rows:=rows||jsonb_build_array(jsonb_build_object('id',l->>'id','status','would_cancel','reason',why,'delayMinutes',delay_min,'aircraftAirportAfter',airport));
  ELSE
   actual_arr:=actual_dep+(arr-dep);available:=actual_arr+make_interval(mins=>buffer);airport:=l->>'to';
   rows:=rows||jsonb_build_array(jsonb_build_object('id',l->>'id','status',CASE WHEN delay_min>0 THEN 'would_delay' ELSE 'on_time' END,'delayMinutes',delay_min,'technicalDelayMinutes',technical,'inheritedDelayMinutes',delay_min-technical,'estimatedDepartureUtc',actual_dep,'estimatedArrivalUtc',actual_arr,'availableUtc',available,'aircraftAirportAfter',airport));
  END IF;
 END LOOP;
 RETURN jsonb_build_object('status','rotation_delay_scenario','flights',rows,'readOnly',true,'dispatchEffectsEnabled',false,'ledgerPosted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_preview_delay_rotation_v1(text,timestamptz,jsonb,integer) FROM PUBLIC,anon,authenticated,service_role;
COMMIT;
