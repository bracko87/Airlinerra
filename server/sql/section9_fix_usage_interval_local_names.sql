CREATE OR REPLACE FUNCTION airlinerra_game.section9_aircraft_usage_window_v2(p_start timestamptz,p_blocks jsonb)
RETURNS jsonb LANGUAGE plpgsql IMMUTABLE SECURITY INVOKER SET search_path TO pg_catalog AS $$
DECLARE v_block jsonb;v_departure timestamptz;v_arrival timestamptz;v_available timestamptz;flight_minutes numeric;occupied numeric;overlap_count int;valid_count int:=0;
BEGIN
 IF p_start IS NULL OR NOT isfinite(p_start) OR p_blocks IS NULL OR jsonb_typeof(p_blocks)<>'array' THEN RETURN jsonb_build_object('status','invalid_usage_input');END IF;
 IF jsonb_array_length(p_blocks)>10000 THEN RETURN jsonb_build_object('status','usage_input_requires_sharding');END IF;
 FOR v_block IN SELECT value FROM jsonb_array_elements(p_blocks) LOOP
  IF NOT coalesce(v_block->>'departureUtc','') ~ '(Z|[+-][0-9]{2}:[0-9]{2})$' OR NOT coalesce(v_block->>'arrivalUtc','') ~ '(Z|[+-][0-9]{2}:[0-9]{2})$' OR NOT coalesce(v_block->>'availableUtc','') ~ '(Z|[+-][0-9]{2}:[0-9]{2})$' THEN RETURN jsonb_build_object('status','invalid_usage_block');END IF;
  v_departure:=(v_block->>'departureUtc')::timestamptz;v_arrival:=(v_block->>'arrivalUtc')::timestamptz;v_available:=(v_block->>'availableUtc')::timestamptz;
  IF NOT isfinite(v_departure) OR NOT isfinite(v_arrival) OR NOT isfinite(v_available) OR v_arrival<=v_departure OR v_available<v_arrival OR v_available-v_arrival>interval '24 hours' THEN RETURN jsonb_build_object('status','invalid_usage_block');END IF;
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
