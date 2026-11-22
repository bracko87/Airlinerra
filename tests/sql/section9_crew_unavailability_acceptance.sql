DO $test$
DECLARE a record; member uuid; w jsonb; r jsonb;
BEGIN
 BEGIN
 SELECT id,owner_player_id,home_airport_key INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 INSERT INTO airlinerra_game.section9_cabin_crew_pools_v1(airline_id,base_airport_key,role,employed_count,monthly_salary_usd) VALUES(a.id,a.home_airport_key,'flight_attendant',1,2200);
 INSERT INTO airlinerra_game.section9_cabin_crew_members_v1(airline_id,base_airport_key,role,initial_airport_key,location_effective_utc,employment_status,effective_game_date) VALUES(a.id,a.home_airport_key,'flight_attendant',a.home_airport_key,'2026-11-22T00:00:00Z','employed','2026-01-01') RETURNING member_id INTO member;
 INSERT INTO airlinerra_game.section9_crew_unavailability_v1(airline_id,cabin_member_id,reason,start_utc,end_utc,status) VALUES
 (a.id,member,'sickness','2026-11-23T03:00:00Z','2026-11-24T03:00:00Z','active'),
 (a.id,member,'holiday','2026-11-25T03:00:00Z','2026-11-26T03:00:00Z','cancelled'),
 (a.id,member,'training','2026-12-05T03:00:00Z','2026-12-06T03:00:00Z','active');
 w:=airlinerra_game.section9_crew_unavailability_windows_v1(a.id,NULL,member,'2026-11-23T00:00:00Z');
 IF jsonb_array_length(w)<>1 OR w->0->>'reason'<>'sickness' THEN RAISE EXCEPTION 'invalid windows';END IF;
 r:=airlinerra_game.section9_owned_weekly_crew_input_v1(a.owner_player_id,a.id,'2026-11-23T00:00:00Z');
 IF r->>'unavailabilityIntegrated'<>'true' OR r->'cabinMembers'->0->'absences' IS DISTINCT FROM w THEN RAISE EXCEPTION 'bootstrap absent';END IF;
 IF airlinerra_game.section9_crew_unavailability_windows_v1(gen_random_uuid(),NULL,member,'2026-11-23T00:00:00Z')<>'[]'::jsonb THEN RAISE EXCEPTION 'cross airline';END IF;
 RAISE SQLSTATE 'ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;END;
END $test$;
SELECT 'passed' AS test,(SELECT count(*) FROM airlinerra_game.section9_crew_unavailability_v1) persisted_absences,has_table_privilege('authenticated','airlinerra_game.section9_crew_unavailability_v1','INSERT') client_write,has_function_privilege('authenticated','airlinerra_game.section9_crew_unavailability_windows_v1(uuid,uuid,uuid,timestamptz)','execute') client_execute;