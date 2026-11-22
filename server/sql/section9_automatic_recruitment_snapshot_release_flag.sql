CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_automatic_recruitment_snapshot_v1(p_player uuid,p_airline uuid,p_start timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE pref jsonb;ov jsonb;inp jsonb;salaries jsonb;spent numeric;cash numeric;dt date;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT cash_usd INTO cash FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 ov:=airlinerra_game.section9_owned_shared_crew_hiring_overview_v1(p_player,p_airline);
 inp:=airlinerra_game.section9_owned_weekly_crew_input_v1(p_player,p_airline,p_start);
 IF inp->>'status'<>'weekly_crew_bootstrap_input_preview' THEN RETURN inp;END IF;
 SELECT jsonb_build_object('mode',mode,'reservePercent',reserve_percent,'monthlyBudgetUsd',monthly_budget_usd,'version',version) INTO pref FROM airlinerra_game.section9_crew_recruitment_preferences_v1 WHERE airline_id=p_airline;
 SELECT jsonb_object_agg(role,monthly_salary_usd) INTO salaries FROM airlinerra_game.section9_shared_crew_salary_policy_v1;
 dt:=(airlinerra_game.section9_verified_world_instant_v1() AT TIME ZONE 'Europe/Berlin')::date;
 SELECT coalesce(sum(additional_monthly_salary_usd),0) INTO spent FROM airlinerra_game.section9_automatic_crew_hire_runs_v1 WHERE airline_id=p_airline AND game_date>=date_trunc('month',dt)::date AND game_date<(date_trunc('month',dt)+interval '1 month')::date;
 RETURN jsonb_build_object('status','automatic_crew_recruitment_snapshot','airlineId',p_airline,'automaticHiringEnabled',(SELECT automatic_hiring_enabled FROM airlinerra_game.section9_shared_crew_employment_release_v1 WHERE world_id=1),'gameDate',dt,'input',inp,'overview',ov,'settings',coalesce(pref,'{"mode":"manual","reservePercent":0,"monthlyBudgetUsd":0,"version":0}'::jsonb),'salaryPolicy',salaries,'cabinBaseSalaries',coalesce((SELECT jsonb_object_agg(base_airport_key,monthly_salary_usd) FROM airlinerra_game.section9_cabin_crew_pools_v1 WHERE airline_id=p_airline AND role='flight_attendant'),'{}'::jsonb),'cashUsd',cash,'monthAuthorizedCommitmentsUsd',spent);
END $$;

