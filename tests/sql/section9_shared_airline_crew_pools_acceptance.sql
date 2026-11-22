-- Isolated shared crew pool regression: fixture writes are rolled back.
DO $test$
DECLARE a record; cid uuid; other_id uuid; r jsonb; output jsonb; i int; same_family bigint;
BEGIN
 BEGIN
 SELECT id,owner_player_id,home_airport_key INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 SELECT configuration_id INTO STRICT same_family FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE qualification_group='family:12' AND configuration_id<>16 ORDER BY configuration_id LIMIT 1;
 INSERT INTO airlinerra_game.section9_airline_crew_roster_v1(world_id,airline_id,crew_reference,role,qualified_configuration_id,employment_status,employment_proof_ref,employment_reviewed_at,monthly_salary_usd,contract_source,game_effective_date,contract_signed_at)
 VALUES(1,a.id,'TEST-SHARED-'||gen_random_uuid()::text,'flight_deck',16,'verified_employed','isolated-game-fixture',clock_timestamp(),5000,'game_npc_offer_v1','2026-01-01',clock_timestamp()) RETURNING crew_id INTO cid;
 INSERT INTO airlinerra_game.section9_pilot_profiles_v1(crew_id,airline_id,career_rank) VALUES(cid,a.id,'captain');
 INSERT INTO airlinerra_game.section9_pilot_base_assignments_v1(crew_id,airline_id,base_airport_key,initial_airport_key,location_effective_utc) VALUES(cid,a.id,a.home_airport_key,a.home_airport_key,'2026-11-22T00:00:00Z');
 INSERT INTO airlinerra_game.section9_pilot_family_permissions_v1(airline_id,crew_id,qualification_group,captain_permission,first_officer_permission,qualification_status,issued_game_date,expires_game_date)
 VALUES(a.id,cid,'family:12',true,true,'active','2026-01-01','2027-01-01'),(a.id,cid,'family:1',true,true,'active','2026-01-01','2027-01-01');
 INSERT INTO airlinerra_game.section9_cabin_crew_pools_v1(airline_id,base_airport_key,role,employed_count,monthly_salary_usd) VALUES(a.id,a.home_airport_key,'flight_attendant',4,2200);
 FOR i IN 1..4 LOOP
 INSERT INTO airlinerra_game.section9_cabin_crew_members_v1(airline_id,base_airport_key,role,initial_airport_key,location_effective_utc,employment_status,effective_game_date)
 VALUES(a.id,a.home_airport_key,'flight_attendant',a.home_airport_key,'2026-11-22T00:00:00Z','employed','2026-01-01');
 END LOOP;
 r:=airlinerra_game.section9_owned_shared_crew_pool_preview_v1(a.owner_player_id,a.id,a.home_airport_key,ARRAY[16::bigint,16::bigint,same_family,16::bigint],'2026-11-22');
 IF r->>'status'<>'shared_crew_pool_preview' OR r->>'proposedAircraftCount'<>'4' OR jsonb_array_length(r->'qualificationGroups')<>1 OR r->'qualificationGroups'->0->>'aircraftCount'<>'4' OR r->>'distinctPilotCount'<>'1' OR r->>'distinctCabinMemberCount'<>'4' THEN RAISE EXCEPTION 'same family case %',r;END IF;
 output:=jsonb_build_object('fourAircraftOneFamily',r);
 r:=airlinerra_game.section9_owned_shared_crew_pool_preview_v1(a.owner_player_id,a.id,a.home_airport_key,ARRAY[16::bigint,54::bigint],'2026-11-22');
 IF r->>'distinctPilotCount'<>'1' OR jsonb_array_length(r->'pilots'->0->'permissions')<>2 OR jsonb_array_length(r->'qualificationGroups')<>2 THEN RAISE EXCEPTION 'multiple qualifications counted twice %',r;END IF;
 output:=output||jsonb_build_object('twoFamiliesOnePilot',r);
 IF airlinerra_game.section9_owned_shared_crew_pool_preview_v1(gen_random_uuid(),a.id,a.home_airport_key,ARRAY[16::bigint],'2026-11-22')->>'status'<>'blocked_airline_not_owned' THEN RAISE EXCEPTION 'owner isolation';END IF;
 IF airlinerra_game.section9_owned_shared_crew_pool_preview_v1(a.owner_player_id,a.id,'NO-BASE',ARRAY[16::bigint],'2026-11-22')->>'status'<>'blocked_unregistered_crew_base' THEN RAISE EXCEPTION 'base isolation';END IF;
 r:=airlinerra_game.section9_owned_shared_crew_pool_preview_v1(a.owner_player_id,a.id,a.home_airport_key,ARRAY[16::bigint],'2027-01-01');
 IF r->>'distinctPilotCount'<>'0' THEN RAISE EXCEPTION 'expired qualification';END IF;
 UPDATE airlinerra_game.section9_cabin_crew_pools_v1 SET employed_count=5 WHERE airline_id=a.id AND base_airport_key=a.home_airport_key AND role='flight_attendant';
 r:=airlinerra_game.section9_owned_shared_crew_pool_preview_v1(a.owner_player_id,a.id,a.home_airport_key,ARRAY[16::bigint],'2026-11-22');
 IF r->>'cabinHeadcountReconciled'<>'false' OR r->>'distinctCabinMemberCount'<>'0' THEN RAISE EXCEPTION 'inconsistent cabin headcount';END IF;
 RAISE SQLSTATE 'ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;
 END;
 PERFORM set_config('airlinerra.shared_pool_test',output::text,true);
END $test$;
SELECT current_setting('airlinerra.shared_pool_test',true)::jsonb test,
 (SELECT count(*) FROM airlinerra_game.section9_pilot_base_assignments_v1) persisted_pilot_assignments,
 (SELECT count(*) FROM airlinerra_game.section9_cabin_crew_members_v1) persisted_cabin_members,
 has_function_privilege('authenticated','airlinerra_game.section9_owned_shared_crew_pool_preview_v1(uuid,uuid,text,bigint[],date)','execute') client_access;