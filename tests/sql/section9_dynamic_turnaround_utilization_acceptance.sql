DO $test$
DECLARE a jsonb;b jsonb;c jsonb;u jsonb;x jsonb;y jsonb;
BEGIN
 a:=airlinerra_game.section9_dynamic_turnaround_preview_v1(3,180,4,40);
 b:=airlinerra_game.section9_dynamic_turnaround_preview_v1(3,180,5,40);
 c:=airlinerra_game.section9_dynamic_turnaround_preview_v1(3,180,6,40);
 IF a->>'nominalTurnaroundMinutes'<>'60' OR b->>'nominalTurnaroundMinutes'<>'50' OR c->>'nominalTurnaroundMinutes'<>'40' OR (a->>'turnaroundDelayProbabilityPct')::numeric<=(c->>'turnaroundDelayProbabilityPct')::numeric THEN RAISE EXCEPTION 'staffing interpolation % % %',a,b,c;END IF;
 IF airlinerra_game.section9_dynamic_turnaround_preview_v1(3,180,3,40)->>'status'<>'invalid_turnaround_staffing_or_schedule' THEN RAISE EXCEPTION 'minimum staff';END IF;
 IF airlinerra_game.section9_dynamic_turnaround_preview_v1(3,180,7,40)->>'status'<>'invalid_turnaround_staffing_or_schedule' THEN RAISE EXCEPTION 'maximum staff';END IF;
 IF airlinerra_game.section9_dynamic_turnaround_preview_v1(3,180,4,60)->>'turnaroundDelayProbabilityPct'<>'0.00' THEN RAISE EXCEPTION 'maximum time';END IF;
 IF airlinerra_game.section9_dynamic_turnaround_preview_v1(5,0,0,90)->>'cabinStaffingAffectsTurnaround'<>'false' THEN RAISE EXCEPTION 'cargo';END IF;
 u:=airlinerra_game.section9_aircraft_usage_window_v2('2026-11-23T00:00:00Z','[{"departureUtc":"2026-11-22T22:00:00Z","arrivalUtc":"2026-11-23T01:00:00Z","availableUtc":"2026-11-23T02:00:00Z"},{"departureUtc":"2026-11-23T03:00:00Z","arrivalUtc":"2026-11-23T06:00:00Z","availableUtc":"2026-11-23T07:00:00Z"},{"departureUtc":"2026-11-23T06:30:00Z","arrivalUtc":"2026-11-23T08:00:00Z","availableUtc":"2026-11-23T09:00:00Z"}]');
 IF (u->>'occupiedMinutes')::numeric<>480 OR (u->>'flightMinutes')::numeric<>330 OR (u->>'turnaroundOnlyMinutes')::numeric<>150 OR u->>'overlappingBlocks'<>'1' THEN RAISE EXCEPTION 'clipping or overlap %',u;END IF;
 x:=airlinerra_game.section9_utilization_reliability_v2(90,1080);
 y:=airlinerra_game.section9_utilization_reliability_v2(90,1320);
 IF (x->>'utilizationPct')::numeric<>75 OR (y->>'utilizationPct')::numeric<=90 OR (y->>'technicalDelayProbabilityPct')::numeric<=(x->>'technicalDelayProbabilityPct')::numeric THEN RAISE EXCEPTION 'risk % %',x,y;END IF;
 IF (airlinerra_game.section9_utilization_reliability_v2(60,1320)->>'technicalDelayProbabilityPct')::numeric<=(y->>'technicalDelayProbabilityPct')::numeric THEN RAISE EXCEPTION 'condition';END IF;
 PERFORM set_config('airlinerra.turnaround_regression',jsonb_build_object('fourAttendants',a,'fiveAttendants',b,'sixAttendants',c,'usage',u,'normalRisk',x,'highRisk',y)::text,true);
END $test$;
SELECT current_setting('airlinerra.turnaround_regression',true)::jsonb AS passed_examples,has_function_privilege('authenticated','airlinerra_game.section9_owned_aircraft_utilization_preview_v2(uuid,uuid,uuid,timestamptz)','execute') client_access;