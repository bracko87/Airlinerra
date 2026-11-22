-- Dynamic turnaround and aircraft utilization previews. No dispatch, wear,
-- maintenance counters, or live schedule mutation is connected by this migration.
CREATE FUNCTION airlinerra_game.section9_dynamic_turnaround_preview_v1(p_configuration bigint,p_installed_seats int,p_cabin_count int,p_scheduled_minutes int)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE req jsonb;pol record;minimum int;maximum int;lo int;hi int;staffing numeric;shape numeric;expected numeric;late_probability numeric;threshold numeric;
BEGIN
 req:=airlinerra_game.section9_flight_crew_requirements_v1(p_configuration,p_installed_seats,1);
 IF req->>'status'<>'game_flight_crew_requirements' THEN RETURN req;END IF;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=p_configuration;
 minimum:=(req->>'minimumCabinCrew')::int;maximum:=(req->>'maximumCabinCrew')::int;lo:=pol.minimum_turnaround_minutes;hi:=pol.maximum_turnaround_minutes;
 IF p_cabin_count IS NULL OR p_cabin_count<minimum OR p_cabin_count>maximum OR p_scheduled_minutes IS NULL OR p_scheduled_minutes NOT BETWEEN 0 AND 1440 THEN RETURN jsonb_build_object('status','invalid_turnaround_staffing_or_schedule','minimumCabinCrew',minimum,'maximumCabinCrew',maximum);END IF;
 -- Rounded bounded distribution: at minimum staffing the fast end is very
 -- unlikely; at maximum staffing it is common. Cargo is independent of cabin staff.
 staffing:=CASE WHEN maximum=minimum THEN 0.5 ELSE (p_cabin_count-minimum)::numeric/(maximum-minimum) END;
 shape:=power(4::numeric,1-2*staffing);
 expected:=lo+(hi-lo)*shape/(shape+1);
 IF hi=lo THEN late_probability:=CASE WHEN p_scheduled_minutes<lo THEN 1 ELSE 0 END;
 ELSIF p_scheduled_minutes<lo THEN late_probability:=1;
 ELSIF p_scheduled_minutes>=hi THEN late_probability:=0;
 ELSE
  threshold:=least(1::numeric,greatest(0::numeric,(p_scheduled_minutes::numeric+0.5-lo)/(hi-lo)));
  late_probability:=1-power(threshold,shape);
 END IF;
 RETURN jsonb_build_object('status','dynamic_turnaround_preview','configurationId',p_configuration,'minimumCabinCrew',minimum,'maximumCabinCrew',maximum,'assignedCabinCrew',p_cabin_count,'minimumTurnaroundMinutes',lo,'maximumTurnaroundMinutes',hi,'nominalTurnaroundMinutes',round(hi-(hi-lo)*staffing),'expectedTurnaroundMinutes',round(expected,1),'scheduledTurnaroundMinutes',p_scheduled_minutes,'turnaroundDelayProbabilityPct',round(100*late_probability,2),'cabinStaffingAffectsTurnaround',maximum>minimum AND pol.seat_basis<>'cargo_zero','model','GAME_DYNAMIC_TURNAROUND_V1','dispatchEnforced',false);
END $$;
-- Pure percentage of a physical 24-hour day. The soft stress threshold is 75%,
-- not a maximum operating-hours rule.
CREATE FUNCTION airlinerra_game.section9_utilization_reliability_v2(p_condition numeric,p_occupied_minutes numeric)
RETURNS jsonb LANGUAGE sql IMMUTABLE STRICT SECURITY INVOKER SET search_path TO pg_catalog AS $$
 WITH x AS(SELECT greatest(0,least(100,p_condition)) c,greatest(0,least(1440,p_occupied_minutes))/1440*100 u),
 r AS(SELECT c,u,round(least(60::numeric,1+power((100-c)/100,1.5::numeric)*45+power(greatest(0,u-75)/25,1.5::numeric)*25),2) risk FROM x)
 SELECT jsonb_build_object('conditionPct',round(c,2),'utilizationPct',round(u,2),'highUtilization',u>75,'operationalReliabilityPct',100-risk,'technicalDelayProbabilityPct',risk,'model','GAME_OPERATIONAL_RELIABILITY_V2_PREVIEW','dispatchEffectsEnabled',false) FROM r;
$$;
-- One aircraft's operating blocks, including scheduled ground turnaround.
-- Clip and union intervals across midnight and overlapping records.
CREATE FUNCTION airlinerra_game.section9_aircraft_usage_window_v2(p_start timestamptz,p_blocks jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path TO pg_catalog AS $$
DECLARE b jsonb;s timestamptz;a timestamptz;e timestamptz;flight_minutes numeric;occupied numeric;overlap_count int;valid_count int:=0;
BEGIN
 IF p_start IS NULL OR NOT isfinite(p_start) OR p_blocks IS NULL OR jsonb_typeof(p_blocks)<>'array' THEN RETURN jsonb_build_object('status','invalid_usage_input');END IF;
 IF jsonb_array_length(p_blocks)>10000 THEN RETURN jsonb_build_object('status','usage_input_requires_sharding');END IF;
 FOR b IN SELECT value FROM jsonb_array_elements(p_blocks) LOOP
  IF NOT coalesce(b->>'departureUtc','') ~ '(Z|[+-][0-9]{2}:[0-9]{2})$' OR NOT coalesce(b->>'arrivalUtc','') ~ '(Z|[+-][0-9]{2}:[0-9]{2})$' OR NOT coalesce(b->>'availableUtc','') ~ '(Z|[+-][0-9]{2}:[0-9]{2})$' THEN RETURN jsonb_build_object('status','invalid_usage_block');END IF;
  s:=(b->>'departureUtc')::timestamptz;a:=(b->>'arrivalUtc')::timestamptz;e:=(b->>'availableUtc')::timestamptz;
  IF NOT isfinite(s) OR NOT isfinite(a) OR NOT isfinite(e) OR a<=s OR e<a OR e-a>interval '24 hours' THEN RETURN jsonb_build_object('status','invalid_usage_block');END IF;
 END LOOP;
 WITH raw AS(SELECT (v->>'departureUtc')::timestamptz s,(v->>'arrivalUtc')::timestamptz a,(v->>'availableUtc')::timestamptz e FROM jsonb_array_elements(p_blocks) v),
 kinds AS(SELECT 'flight' AS kind,greatest(s,p_start) b,least(a,p_start+interval '24 hours') e FROM raw UNION ALL SELECT 'occupied',greatest(s,p_start),least(e,p_start+interval '24 hours') FROM raw),
 ordered AS(SELECT *,max(e) OVER(PARTITION BY kind ORDER BY b,e ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING) prior_end FROM kinds WHERE e>b)
 SELECT coalesce(sum(extract(epoch FROM greatest(interval '0',e-greatest(b,coalesce(prior_end,b))))/60) FILTER(WHERE kind='flight'),0),
 coalesce(sum(extract(epoch FROM greatest(interval '0',e-greatest(b,coalesce(prior_end,b))))/60) FILTER(WHERE kind='occupied'),0),
 count(*) FILTER(WHERE kind='occupied' AND prior_end>b)
 INTO flight_minutes,occupied,overlap_count FROM ordered;
 RETURN jsonb_build_object('status','aircraft_usage_preview','flightMinutes',round(flight_minutes,2),'turnaroundOnlyMinutes',round(occupied-flight_minutes,2),'occupiedMinutes',round(occupied,2),'utilizationPct',round(occupied/1440*100,2),'overlappingBlocks',overlap_count,'dispatchEnforced',false);
EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR invalid_text_representation THEN RETURN jsonb_build_object('status','invalid_usage_block');
END $$;
-- Read-only planning preview derived from current-version dated occurrences.
CREATE FUNCTION airlinerra_game.section9_owned_aircraft_utilization_preview_v2(p_player uuid,p_airline uuid,p_aircraft uuid,p_start timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE blocks jsonb;u jsonb;c jsonb;now_utc timestamptz;
BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory f JOIN airlinerra_game.airlines a ON a.id=f.airline_id AND a.world_id=1 AND a.owner_player_id=p_player WHERE f.id=p_aircraft AND f.airline_id=p_airline) THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_start IS NULL OR NOT isfinite(p_start) THEN RETURN jsonb_build_object('status','invalid_usage_window');END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('departureUtc',o.departure_utc,'arrivalUtc',o.arrival_utc,'availableUtc',o.arrival_utc+make_interval(mins=>o.turnaround_minutes)) ORDER BY o.departure_utc,o.id),'[]') INTO blocks
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.aircraft_inventory_id=o.aircraft_inventory_id AND s.version=o.schedule_version AND s.status='active'
 WHERE o.airline_id=p_airline AND o.aircraft_inventory_id=p_aircraft AND o.world_id=1 AND o.booking_status<>'cancelled' AND o.departure_utc<p_start+interval '24 hours' AND o.arrival_utc+make_interval(mins=>o.turnaround_minutes)>p_start;
 u:=airlinerra_game.section9_aircraft_usage_window_v2(p_start,blocks);
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();
 c:=airlinerra_game.section9_game_airframe_condition_v1(p_airline,p_aircraft,now_utc);
 IF u->>'status'='aircraft_usage_preview' AND c->>'conditionPct' IS NOT NULL THEN u:=u||jsonb_build_object('reliability',airlinerra_game.section9_utilization_reliability_v2((c->>'conditionPct')::numeric,(u->>'occupiedMinutes')::numeric));END IF;
 RETURN u||jsonb_build_object('aircraftInventoryId',p_aircraft,'windowStartUtc',p_start,'utilizationBasis','dated_scheduled_flight_plus_turnaround','scheduleCompletenessVerified',false,'actualTurnaroundMeasured',false,'dispatchEnforced',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_dynamic_turnaround_preview_v1(bigint,int,int,int),airlinerra_game.section9_utilization_reliability_v2(numeric,numeric),airlinerra_game.section9_aircraft_usage_window_v2(timestamptz,jsonb),airlinerra_game.section9_owned_aircraft_utilization_preview_v2(uuid,uuid,uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
