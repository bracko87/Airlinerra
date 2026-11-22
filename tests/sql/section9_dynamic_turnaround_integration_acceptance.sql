DO $test$
DECLARE a record;u jsonb;r1 jsonb;r2 jsonb;lo int;mid int;hi int;i int;
BEGIN
 FOR i IN 0..999 LOOP
 lo:=airlinerra_game.section9_sample_turnaround_minutes_v1(3,180,4,45,i::numeric/1000);
 mid:=airlinerra_game.section9_sample_turnaround_minutes_v1(3,180,5,45,i::numeric/1000);
 hi:=airlinerra_game.section9_sample_turnaround_minutes_v1(3,180,6,45,i::numeric/1000);
 IF lo NOT BETWEEN 40 AND 60 OR mid NOT BETWEEN 40 AND 60 OR hi NOT BETWEEN 40 AND 60 OR lo<mid OR mid<hi OR lo IS NULL OR mid IS NULL OR hi IS NULL THEN RAISE EXCEPTION 'sample bounds or staffing %',i;END IF;
 END LOOP;
 IF airlinerra_game.section9_sample_turnaround_minutes_v1(3,180,3,45,0.5) IS NOT NULL THEN RAISE EXCEPTION 'invalid minimum';END IF;
 u:=airlinerra_game.section9_aircraft_usage_window_v2('2026-11-24T00:00:00Z','[{"departureUtc":"2026-11-24T00:00:00Z","arrivalUtc":"2026-11-24T08:00:00Z","availableUtc":"2026-11-24T10:00:00Z"},{"departureUtc":"2026-11-24T10:00:00Z","arrivalUtc":"2026-11-24T18:00:00Z","availableUtc":"2026-11-24T20:00:00Z"}]');
 IF (u->>'occupiedMinutes')::numeric<>1200 OR (u->>'flightMinutes')::numeric<>960 OR (u->>'utilizationPct')::numeric<>83.33 THEN RAISE EXCEPTION 'occupancy %',u;END IF;
 r1:=airlinerra_game.section9_utilization_reliability_v2(90,1080);r2:=airlinerra_game.section9_utilization_reliability_v2(90,1200);
 IF (r1->>'technicalDelayProbabilityPct')::numeric>=(r2->>'technicalDelayProbabilityPct')::numeric THEN RAISE EXCEPTION 'risk';END IF;
 SELECT id,owner_player_id INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 IF airlinerra_game.section9_capture_actual_turnaround_v1(a.id,'test-no-flight','test-no-event')->>'status'<>'dynamic_turnaround_disabled' THEN RAISE EXCEPTION 'release gate';END IF;
END $test$;
SELECT 'passed' status,3000 turnaround_samples,(SELECT capture_enabled FROM airlinerra_game.section9_dynamic_turnaround_release_v1) capture_enabled,(SELECT dispatch_effects_enabled FROM airlinerra_game.section9_dynamic_turnaround_release_v1) dispatch_enabled,(SELECT count(*) FROM airlinerra_game.section9_actual_turnaround_receipts_v1) live_receipts,has_function_privilege('authenticated','airlinerra_game.section9_capture_actual_turnaround_v1(uuid,text,text)','execute') client_access;