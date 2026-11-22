-- Approved simplified Airlinerra crew policy. The legacy per-flight proposal preview
-- remains separate; neither this policy nor this preview is used to block dispatch.
CREATE TABLE airlinerra_game.section9_crew_scheduler_policy_v2(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 preflight_minutes integer NOT NULL CHECK(preflight_minutes=120),
 postflight_minutes integer NOT NULL CHECK(postflight_minutes=30),
 maximum_duty_minutes integer NOT NULL CHECK(maximum_duty_minutes=720),
 minimum_rest_minutes integer NOT NULL CHECK(minimum_rest_minutes=720),
 maximum_working_days integer NOT NULL CHECK(maximum_working_days=5),
 working_day_window integer NOT NULL CHECK(working_day_window=7),
 enforce_weekly_duty_hours boolean NOT NULL CHECK(NOT enforce_weekly_duty_hours),
 enforce_rolling_flight_hours boolean NOT NULL CHECK(NOT enforce_rolling_flight_hours),
 automatic_allocation_enabled boolean NOT NULL DEFAULT false,
 dispatch_enforced boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.section9_crew_scheduler_policy_v2 VALUES(1,120,30,720,720,5,7,false,false,false,false);
ALTER TABLE airlinerra_game.section9_crew_scheduler_policy_v2 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_crew_scheduler_policy_v2 FROM PUBLIC,anon,authenticated,service_role;

-- One proposed continuous duty for one employee. Every ground gap is counted.
-- Input legs are in chronological UTC order, not separate duties.
CREATE FUNCTION airlinerra_game.section9_crew_rotation_window_v2(p_legs jsonb)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE pol record; leg jsonb; dep timestamptz; arr timestamptz; first_dep timestamptz;
 last_arr timestamptz; first_origin text; last_destination text; orig text; dest text;
 duty_start timestamptz; duty_end timestamptz; flight_minutes numeric:=0;
BEGIN
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 IF p_legs IS NULL OR jsonb_typeof(p_legs)<>'array' THEN RETURN jsonb_build_object('status','invalid_legs');END IF;
 IF jsonb_array_length(p_legs) NOT BETWEEN 1 AND 32 THEN RETURN jsonb_build_object('status','invalid_legs');END IF;
 FOR leg IN SELECT value FROM jsonb_array_elements(p_legs) LOOP
  IF NOT coalesce(leg->>'departureUtc','') ~ '(Z|[+-][0-9]{2}:[0-9]{2})$' OR NOT coalesce(leg->>'arrivalUtc','') ~ '(Z|[+-][0-9]{2}:[0-9]{2})$' THEN
   RETURN jsonb_build_object('status','invalid_leg_time');END IF;
  dep:=(leg->>'departureUtc')::timestamptz;arr:=(leg->>'arrivalUtc')::timestamptz;
  orig:=nullif(btrim(leg->>'originAirportKey'),'');dest:=nullif(btrim(leg->>'destinationAirportKey'),'');
  IF dep IS NULL OR arr IS NULL OR NOT isfinite(dep) OR NOT isfinite(arr) OR arr<=dep OR orig IS NULL OR dest IS NULL OR orig=dest THEN RETURN jsonb_build_object('status','invalid_leg');END IF;
  IF last_arr IS NOT NULL AND dep<last_arr THEN RETURN jsonb_build_object('status','overlapping_flights');END IF;
  IF last_destination IS NOT NULL AND last_destination<>orig THEN RETURN jsonb_build_object('status','crew_wrong_airport');END IF;
  IF first_dep IS NULL THEN first_dep:=dep;first_origin:=orig;END IF;
  last_arr:=arr;last_destination:=dest;flight_minutes:=flight_minutes+extract(epoch FROM arr-dep)/60;
 END LOOP;
 duty_start:=first_dep-make_interval(mins=>pol.preflight_minutes);
 duty_end:=last_arr+make_interval(mins=>pol.postflight_minutes);
 RETURN jsonb_build_object('status',CASE WHEN duty_end-duty_start>make_interval(mins=>pol.maximum_duty_minutes) THEN 'duty_too_long' ELSE 'rotation_preview' END,
 'dutyStartUtc',duty_start,'dutyEndUtc',duty_end,'startingAirport',first_origin,'endingAirport',last_destination,
 'dutyMinutes',extract(epoch FROM duty_end-duty_start)/60,'flightMinutes',flight_minutes,
 'legCount',jsonb_array_length(p_legs),'nextReadyUtc',duty_end+make_interval(mins=>pol.minimum_rest_minutes),
 'dispatchEnforced',false);
EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR invalid_text_representation THEN RETURN jsonb_build_object('status','invalid_leg_time');
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_crew_rotation_window_v2(jsonb) FROM PUBLIC,anon,authenticated,service_role;

-- Compare the proposed duty with a complete, authoritative employee duty history
-- (including future commitments). First known location is at the start of history.
-- A working day is the reporting date in the employee's home-base timezone.
-- Check all rolling seven-day windows containing the proposed reporting date.
CREATE FUNCTION airlinerra_game.section9_crew_duty_fit_v2(p_rotation jsonb,p_existing jsonb,p_home_timezone text,p_initial_airport text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE pol record; s timestamptz;e timestamptz; d record; prev_end timestamptz; prev_dest text;
 report_date date;work_dates date[]:='{}'; day_start date; working_count integer; peak int:=0;
BEGIN
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 IF p_rotation->>'status' IS DISTINCT FROM 'rotation_preview' THEN RETURN jsonb_build_object('status','invalid_rotation','eligible',false);END IF;
 IF p_existing IS NULL OR jsonb_typeof(p_existing)<>'array' OR p_initial_airport IS NULL OR btrim(p_initial_airport)='' OR NOT EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=p_home_timezone) THEN RETURN jsonb_build_object('status','invalid_duty_history','eligible',false);END IF;
 IF jsonb_array_length(p_existing)>366 THEN RETURN jsonb_build_object('status','history_requires_sharding','eligible',false);END IF;
 s:=(p_rotation->>'dutyStartUtc')::timestamptz;e:=(p_rotation->>'dutyEndUtc')::timestamptz;
 IF s IS NULL OR e IS NULL OR NOT isfinite(s) OR NOT isfinite(e) OR e<=s OR e-s>make_interval(mins=>pol.maximum_duty_minutes) THEN RETURN jsonb_build_object('status','invalid_rotation','eligible',false);END IF;
 report_date:=(s AT TIME ZONE p_home_timezone)::date;
 prev_dest:=p_initial_airport;
 FOR d IN SELECT (v->>'dutyStartUtc')::timestamptz ds,(v->>'dutyEndUtc')::timestamptz de,
 v->>'startingAirport' AS origin,v->>'endingAirport' AS destination
 FROM jsonb_array_elements(p_existing||jsonb_build_array(p_rotation)) x(v)
 ORDER BY ds,de LOOP
  IF d.ds IS NULL OR d.de IS NULL OR NOT isfinite(d.ds) OR NOT isfinite(d.de) OR d.de<=d.ds OR d.de-d.ds>make_interval(mins=>pol.maximum_duty_minutes) OR nullif(btrim(d.origin),'') IS NULL OR nullif(btrim(d.destination),'') IS NULL THEN RETURN jsonb_build_object('status','invalid_duty_history','eligible',false);END IF;
  IF prev_end IS NOT NULL AND d.ds<prev_end THEN RETURN jsonb_build_object('status','duty_overlap','eligible',false);END IF;
  IF prev_end IS NOT NULL AND d.ds<prev_end+make_interval(mins=>pol.minimum_rest_minutes) THEN RETURN jsonb_build_object('status','insufficient_rest','eligible',false);END IF;
  IF prev_dest IS DISTINCT FROM d.origin THEN RETURN jsonb_build_object('status','crew_wrong_airport','eligible',false);END IF;
  work_dates:=array_append(work_dates,(d.ds AT TIME ZONE p_home_timezone)::date);
  prev_end:=d.de;prev_dest:=d.destination;
 END LOOP;
 FOR day_start IN SELECT report_date-i FROM generate_series(0,pol.working_day_window-1) i LOOP
  SELECT count(DISTINCT dt) INTO working_count FROM unnest(work_dates) dt WHERE dt BETWEEN day_start AND day_start+pol.working_day_window-1;
  peak:=greatest(peak,working_count);
 END LOOP;
 RETURN jsonb_build_object('status',CASE WHEN peak>pol.maximum_working_days THEN 'working_days_exceeded' ELSE 'duty_fit_preview' END,
 'eligible',peak<=pol.maximum_working_days,'maxWorkingDaysInWindow',peak,'workingDayBasis','home_base_reporting_date','reportDate',report_date,'dispatchEnforced',false);
EXCEPTION WHEN invalid_datetime_format OR datetime_field_overflow OR invalid_text_representation THEN RETURN jsonb_build_object('status','invalid_duty_history','eligible',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_crew_duty_fit_v2(jsonb,jsonb,text,text) FROM PUBLIC,anon,authenticated,service_role;
