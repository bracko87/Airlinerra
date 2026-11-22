-- Read-only regression of approved game duty rules. No crew, payments or flights created.
DO $test$
DECLARE r jsonb; h jsonb; test_result jsonb; d int;
BEGIN
 r:=airlinerra_game.section9_crew_rotation_window_v2('[{"departureUtc":"2026-11-23T06:00:00Z","arrivalUtc":"2026-11-23T09:00:00Z","originAirportKey":"BEG","destinationAirportKey":"LHR"},{"departureUtc":"2026-11-23T10:00:00Z","arrivalUtc":"2026-11-23T13:00:00Z","originAirportKey":"LHR","destinationAirportKey":"BEG"}]');
 IF r->>'status' <> 'rotation_preview' OR (r->>'dutyMinutes')::numeric<>570 OR (r->>'flightMinutes')::numeric<>360 THEN RAISE EXCEPTION 'round trip %',r;END IF;
 test_result:=jsonb_build_object('roundTrip',r);
 r:=airlinerra_game.section9_crew_rotation_window_v2('[{"departureUtc":"2026-11-23T06:00:00Z","arrivalUtc":"2026-11-23T15:30:00Z","originAirportKey":"BEG","destinationAirportKey":"LPA"}]');
 IF r->>'status'<>'rotation_preview' OR (r->>'dutyMinutes')::numeric<>720 THEN RAISE EXCEPTION '12h boundary %',r;END IF;
 test_result:=test_result||jsonb_build_object('maximumDuty',r);
 r:=airlinerra_game.section9_crew_rotation_window_v2('[{"departureUtc":"2026-11-23T06:00:00Z","arrivalUtc":"2026-11-23T15:31:00Z","originAirportKey":"BEG","destinationAirportKey":"LPA"}]');
 IF r->>'status'<>'duty_too_long' THEN RAISE EXCEPTION 'overlong duty %',r;END IF;
 r:=airlinerra_game.section9_crew_rotation_window_v2('[{"departureUtc":"2026-11-23T17:00:00Z","arrivalUtc":"2026-11-23T20:00:00Z","originAirportKey":"BEG","destinationAirportKey":"CAI"},{"departureUtc":"2026-11-23T21:00:00Z","arrivalUtc":"2026-11-24T00:00:00Z","originAirportKey":"CAI","destinationAirportKey":"BEG"}]');
 IF r->>'status'<>'rotation_preview' OR (r->>'dutyMinutes')::numeric<>570 THEN RAISE EXCEPTION 'overnight %',r;END IF;
 test_result:=test_result||jsonb_build_object('overnight',r);
 r:='{"status":"rotation_preview","dutyStartUtc":"2026-11-24T04:00:00Z","dutyEndUtc":"2026-11-24T16:00:00Z","startingAirport":"BEG","endingAirport":"BEG"}';
 h:='[{"dutyStartUtc":"2026-11-23T04:00:00Z","dutyEndUtc":"2026-11-23T16:00:00Z","startingAirport":"BEG","endingAirport":"BEG"}]';
 IF (airlinerra_game.section9_crew_duty_fit_v2(r,h,'Europe/Belgrade','BEG')->>'eligible')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION '12h rest';END IF;
 IF airlinerra_game.section9_crew_duty_fit_v2(jsonb_set(r,'{dutyStartUtc}','"2026-11-24T03:59:00Z"'),h,'Europe/Belgrade','BEG')->>'status' NOT IN ('invalid_rotation','insufficient_rest') THEN RAISE EXCEPTION 'rest boundary';END IF;
 IF airlinerra_game.section9_crew_duty_fit_v2(jsonb_set(r,'{dutyStartUtc}','"2026-11-24T03:59:00Z"')||'{"dutyEndUtc":"2026-11-24T12:00:00Z"}',h,'Europe/Belgrade','BEG')->>'status'<>'insufficient_rest' THEN RAISE EXCEPTION '11h59 rest';END IF;
 IF airlinerra_game.section9_crew_duty_fit_v2(r,h,'Europe/Belgrade','CAI')->>'status'<>'crew_wrong_airport' THEN RAISE EXCEPTION 'wrong airport';END IF;
 SELECT jsonb_agg(jsonb_build_object('dutyStartUtc',t,'dutyEndUtc',t+interval '8 hours','startingAirport','BEG','endingAirport','BEG')) INTO h FROM generate_series('2026-11-23T04:00:00Z'::timestamptz,'2026-11-27T04:00:00Z'::timestamptz,interval '1 day') t;
 r:='{"status":"rotation_preview","dutyStartUtc":"2026-11-28T04:00:00Z","dutyEndUtc":"2026-11-28T12:00:00Z","startingAirport":"BEG","endingAirport":"BEG"}';
 IF airlinerra_game.section9_crew_duty_fit_v2(r,h,'Europe/Belgrade','BEG')->>'status'<>'working_days_exceeded' THEN RAISE EXCEPTION 'sixth day';END IF;
 r:=r||'{"dutyStartUtc":"2026-11-30T04:00:00Z","dutyEndUtc":"2026-11-30T12:00:00Z"}';
 IF (airlinerra_game.section9_crew_duty_fit_v2(r,h,'Europe/Belgrade','BEG')->>'eligible')::boolean IS DISTINCT FROM true THEN RAISE EXCEPTION 'after days off';END IF;
 PERFORM set_config('airlinerra.test_crew_duty',test_result::text,true);
END $test$;
SELECT current_setting('airlinerra.test_crew_duty',true)::jsonb as passed_examples,
 (SELECT to_jsonb(p) FROM airlinerra_game.section9_crew_scheduler_policy_v2 p WHERE world_id=1) policy,
 has_function_privilege('authenticated','airlinerra_game.section9_crew_duty_fit_v2(jsonb,jsonb,text,text)','execute') client_access;
