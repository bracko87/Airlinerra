-- Rollback-only verification of shared hiring, quote authorization and payroll forecast.
DO $test$
DECLARE a record; grp text; request uuid:=gen_random_uuid(); r jsonb; beforecash numeric; beforeledger bigint;
BEGIN
 BEGIN
 SELECT id,owner_player_id,home_airport_key,cash_usd INTO STRICT a FROM airlinerra_game.airlines WHERE world_id=1 LIMIT 1;
 SELECT p.qualification_group INTO STRICT grp FROM airlinerra_game.airline_aircraft_inventory f JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=f.configuration_id WHERE f.airline_id=a.id AND f.fleet_status='in_service' AND p.seat_basis<>'cargo_zero' LIMIT 1;
 beforecash:=a.cash_usd; SELECT count(*) INTO beforeledger FROM airlinerra_game.airline_ledger WHERE airline_id=a.id;
 r:=airlinerra_game.section9_owned_shared_crew_hire_quote_v1(a.owner_player_id,a.id,a.home_airport_key,grp,1,1,4);
 IF r->>'status'<>'shared_crew_hire_quote' OR (r->>'additionalMonthlySalaryUsd')::numeric<>22800 THEN RAISE EXCEPTION 'quote %',r;END IF;
 r:=airlinerra_game.section9_confirm_owned_shared_crew_hire_v1(a.owner_player_id,a.id,request,a.home_airport_key,grp,1,1,4,22800);
 IF r->>'status'<>'shared_crew_hiring_disabled' THEN RAISE EXCEPTION 'release gate %',r;END IF;
 UPDATE airlinerra_game.section9_shared_crew_employment_release_v1 SET manual_hiring_enabled=true WHERE world_id=1;
 r:=airlinerra_game.section9_confirm_owned_shared_crew_hire_v1(a.owner_player_id,a.id,request,a.home_airport_key,grp,1,1,4,22799);
 IF r->>'status'<>'crew_quote_exceeds_authorization' THEN RAISE EXCEPTION 'quote cap %',r;END IF;
 r:=airlinerra_game.section9_confirm_owned_shared_crew_hire_v1(a.owner_player_id,a.id,request,a.home_airport_key,grp,1,1,4,22800);
 IF r->>'status'<>'shared_crew_hired' OR jsonb_array_length(r->'pilotIds')<>2 OR jsonb_array_length(r->'cabinIds')<>4 THEN RAISE EXCEPTION 'hire %',r;END IF;
 r:=airlinerra_game.section9_confirm_owned_shared_crew_hire_v1(a.owner_player_id,a.id,request,a.home_airport_key,grp,1,1,4,22800);
 IF r->>'replayed'<>'true' THEN RAISE EXCEPTION 'replay %',r;END IF;
 BEGIN PERFORM airlinerra_game.section9_confirm_owned_shared_crew_hire_v1(a.owner_player_id,a.id,request,a.home_airport_key,grp,2,1,4,22800);RAISE EXCEPTION 'conflict not rejected';EXCEPTION WHEN invalid_parameter_value THEN NULL;END;
 r:=airlinerra_game.section9_owned_shared_crew_payroll_forecast_v1(a.owner_player_id,a.id);
 IF r->>'pilotCount'<>'2' OR r->>'cabinCrewCount'<>'4' OR (r->>'totalMonthlySalaryUsd')::numeric<>22800 OR r->>'cabinHeadcountReconciled'<>'true' THEN RAISE EXCEPTION 'forecast %',r;END IF;
 IF (SELECT cash_usd FROM airlinerra_game.airlines WHERE id=a.id)<>beforecash OR (SELECT count(*) FROM airlinerra_game.airline_ledger WHERE airline_id=a.id)<>beforeledger THEN RAISE EXCEPTION 'premature charge';END IF;
 BEGIN PERFORM airlinerra_game.section9_owned_shared_crew_hire_quote_v1(gen_random_uuid(),a.id,a.home_airport_key,grp,1,1,4);RAISE EXCEPTION 'owner bypass';EXCEPTION WHEN insufficient_privilege THEN NULL;END;
 RAISE SQLSTATE 'ZX001';
 EXCEPTION WHEN SQLSTATE 'ZX001' THEN NULL;END;
END $test$;
SELECT 'passed' test,(SELECT count(*) FROM airlinerra_game.section9_shared_crew_hire_batches_v1) persisted_batches,(SELECT count(*) FROM airlinerra_game.section9_pilot_profiles_v1) persisted_pilots,(SELECT count(*) FROM airlinerra_game.section9_cabin_crew_members_v1) persisted_cabin_members,(SELECT to_jsonb(r) FROM airlinerra_game.section9_shared_crew_employment_release_v1 r) release,has_function_privilege('authenticated','airlinerra_game.section9_confirm_owned_shared_crew_hire_v1(uuid,uuid,uuid,text,text,int,int,int,numeric)','execute') client_access;