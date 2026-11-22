CREATE OR REPLACE FUNCTION airlinerra_game.section9_execute_automatic_crew_hire_v1(p_player uuid, p_airline uuid, p_run uuid, p_start timestamp with time zone, p_snapshot jsonb, p_groups jsonb)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE old_run record;snap jsonb;settings jsonb;g jsonb;q jsonb;outcome jsonb;total numeric:=0;budget numeric;result jsonb;batch_results jsonb:='[]'::jsonb;headcount int:=0;group_key text;seen text[]:='{}';
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_run IS NULL OR p_snapshot IS NULL OR p_groups IS NULL OR jsonb_typeof(p_groups)<>'array' THEN RAISE EXCEPTION USING ERRCODE='22023';END IF;
 SELECT * INTO old_run FROM airlinerra_game.section9_automatic_crew_hire_runs_v1 WHERE airline_id=p_airline AND run_id=p_run;
 IF FOUND THEN
 IF old_run.snapshot<>p_snapshot OR old_run.hire_groups<>p_groups THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='AUTO_CREW_RUN_CONFLICT';END IF;
 RETURN old_run.result||jsonb_build_object('replayed',true);
 END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_shared_crew_employment_release_v1 WHERE world_id=1 AND automatic_hiring_enabled AND manual_hiring_enabled) THEN RETURN jsonb_build_object('status','automatic_hiring_disabled');END IF;
 snap:=airlinerra_game.section9_owned_automatic_recruitment_snapshot_v1(p_player,p_airline,p_start);
 IF snap IS DISTINCT FROM p_snapshot THEN RETURN jsonb_build_object('status','recruitment_snapshot_changed');END IF;
 -- Automatic recruitment requires verified subordinate delegation in addition to
 -- the existing salary limit. An appointed manager is never inferred from UI.
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_management_appointments_v1 WHERE airline_id=p_airline AND manager_role='crew_staffing_manager' AND active) THEN RETURN jsonb_build_object('status','staffing_manager_appointment_required');END IF;
 IF EXISTS(SELECT 1 FROM jsonb_array_elements(p_groups) x WHERE
 ((coalesce((x->>'captains')::int,0)+coalesce((x->>'firstOfficers')::int,0)>0) AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_management_responsibilities_v1 WHERE airline_id=p_airline AND policies->>'pilots'='auto'))
 OR (coalesce((x->>'cabinCrew')::int,0)>0 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_management_responsibilities_v1 WHERE airline_id=p_airline AND policies->>'cabin'='auto')))
 THEN RETURN jsonb_build_object('status','staffing_delegation_required');END IF;
 settings:=snap->'settings';
 IF settings->>'mode' NOT IN('automatic_minimum','automatic_reserves') THEN RETURN jsonb_build_object('status','manual_recruitment_selected');END IF;
 IF snap->'input'->>'scheduleCompletenessVerified' IS DISTINCT FROM 'true' OR snap->'input'->>'dutyHistoryIntegrated' IS DISTINCT FROM 'true' OR snap->'input'->>'invalidOccurrenceCount' IS DISTINCT FROM '0' OR snap->'input'->>'cabinHeadcountReconciled' IS DISTINCT FROM 'true' THEN RETURN jsonb_build_object('status','authoritative_schedule_or_duty_history_required');END IF;
 IF p_start<airlinerra_game.section9_verified_world_instant_v1() OR p_start>airlinerra_game.section9_verified_world_instant_v1()+interval '7 days' THEN RETURN jsonb_build_object('status','recruitment_window_stale');END IF;
 IF jsonb_array_length(p_groups) NOT BETWEEN 1 AND 100 OR jsonb_array_length(snap->'input'->'flights')=0 THEN RETURN jsonb_build_object('status','no_valid_recruitment_plan');END IF;
 budget:=greatest(0,(settings->>'monthlyBudgetUsd')::numeric-(snap->>'monthAuthorizedCommitmentsUsd')::numeric);
 FOR g IN SELECT value FROM jsonb_array_elements(p_groups) LOOP
 IF jsonb_typeof(g)<>'object' OR jsonb_typeof(g->'captains') IS DISTINCT FROM 'number' OR jsonb_typeof(g->'firstOfficers') IS DISTINCT FROM 'number' OR jsonb_typeof(g->'cabinCrew') IS DISTINCT FROM 'number' THEN RETURN jsonb_build_object('status','invalid_recruitment_group');END IF;
 group_key:=jsonb_build_array(g->>'baseAirportKey',g->>'qualificationGroup')::text;
 IF group_key=ANY(seen) THEN RETURN jsonb_build_object('status','duplicate_recruitment_group');END IF;
 seen:=array_append(seen,group_key);
 q:=airlinerra_game.section9_owned_shared_crew_hire_quote_v1(p_player,p_airline,g->>'baseAirportKey',g->>'qualificationGroup',(g->>'captains')::int,(g->>'firstOfficers')::int,(g->>'cabinCrew')::int);
 IF q->>'status'<>'shared_crew_hire_quote' OR q->>'oneMonthAffordability'<>'true' THEN RETURN jsonb_build_object('status','automatic_hire_quote_rejected','quote',q);END IF;
 total:=total+(q->>'additionalMonthlySalaryUsd')::numeric;
 headcount:=headcount+(g->>'captains')::int+(g->>'firstOfficers')::int+(g->>'cabinCrew')::int;
 END LOOP;
 IF total>budget OR total+(snap->'overview'->'forecast'->>'totalMonthlySalaryUsd')::numeric>(snap->>'cashUsd')::numeric OR headcount>200 THEN RETURN jsonb_build_object('status','automatic_hire_budget_exceeded','requiredMonthlyUsd',total,'remainingMonthlyBudgetUsd',budget);END IF;
 FOR g IN SELECT value FROM jsonb_array_elements(p_groups) LOOP
 q:=airlinerra_game.section9_owned_shared_crew_hire_quote_v1(p_player,p_airline,g->>'baseAirportKey',g->>'qualificationGroup',(g->>'captains')::int,(g->>'firstOfficers')::int,(g->>'cabinCrew')::int);
 outcome:=airlinerra_game.section9_confirm_owned_shared_crew_hire_v1(p_player,p_airline,gen_random_uuid(),g->>'baseAirportKey',g->>'qualificationGroup',(g->>'captains')::int,(g->>'firstOfficers')::int,(g->>'cabinCrew')::int,(q->>'additionalMonthlySalaryUsd')::numeric);
 IF outcome->>'status'<>'shared_crew_hired' THEN RAISE EXCEPTION 'AUTOMATIC_CREW_BATCH_ABORTED';END IF;
 batch_results:=batch_results||jsonb_build_array(outcome);
 END LOOP;
 result:=jsonb_build_object('status','automatic_crew_hired','runId',p_run,'additionalMonthlySalaryUsd',total,'staffHired',headcount,'batches',batch_results,'replayed',false,'ledgerPosted',false);
 INSERT INTO airlinerra_game.section9_automatic_crew_hire_runs_v1(airline_id,run_id,game_date,settings_version,snapshot,hire_groups,additional_monthly_salary_usd,result)
 VALUES(p_airline,p_run,(snap->>'gameDate')::date,(settings->>'version')::int,p_snapshot,p_groups,total,result);
 RETURN result;
END $function$
;
