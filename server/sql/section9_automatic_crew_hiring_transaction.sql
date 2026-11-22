CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_weekly_crew_input_v1(p_player uuid,p_airline uuid,p_start timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE flights jsonb; pilots jsonb; cabin jsonb; invalid_count integer; pool_ok boolean; active_count integer;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_WEEKLY_CREW_INPUT_ONLY';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RETURN jsonb_build_object('status','blocked_airline_not_owned');END IF;
 IF p_start IS NULL OR NOT isfinite(p_start) OR p_start<'2000-01-01'::timestamptz OR p_start>'2199-12-01'::timestamptz THEN RETURN jsonb_build_object('status','invalid_preview_window');END IF;
 SELECT count(*) INTO active_count FROM airlinerra_game.airline_flight_schedule_drafts_v1 s WHERE s.airline_id=p_airline AND s.world_id=1 AND s.status='active';
 WITH raw AS (
 SELECT o.*,s.configuration_id,s.version current_version,s.status schedule_status,p.qualification_group,p.maximum_cabin_crew,p.seat_basis,
 CASE WHEN p.seat_basis='cargo_zero' THEN 0 ELSE o.verified_passenger_seats END seats
 FROM airlinerra_game.section9_dated_flight_occurrences_v1 o
 LEFT JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.aircraft_inventory_id=o.aircraft_inventory_id
 LEFT JOIN airlinerra_game.section9_flight_crew_model_policy_v1 p ON p.configuration_id=s.configuration_id
 WHERE o.airline_id=p_airline AND o.world_id=1 AND o.booking_status<>'cancelled' AND o.departure_utc>=p_start AND o.departure_utc<p_start+interval '168 hours'
 ), checked AS (
 SELECT *,CASE WHEN seats<=19 THEN 0 ELSE (seats+49)/50 END cabin_required,
 (qualification_group IS NOT NULL AND current_version=schedule_version AND schedule_status='active' AND seats IS NOT NULL AND
 ((seat_basis='cargo_zero' AND seats=0) OR (seat_basis<>'cargo_zero' AND seats>0))) valid
 FROM raw
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',id,'aircraftId',aircraft_inventory_id,'group',qualification_group,'origin',origin_airport_key,'destination',destination_airport_key,'departureUtc',departure_utc,'arrivalUtc',arrival_utc,'cabinRequired',cabin_required) ORDER BY departure_utc,id) FILTER(WHERE valid AND cabin_required<=maximum_cabin_crew),'[]'),
 count(*) FILTER(WHERE valid IS DISTINCT FROM true OR cabin_required IS NULL OR cabin_required>maximum_cabin_crew)
 INTO flights,invalid_count FROM checked;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',pr.crew_id,'baseAirportKey',b.base_airport_key,'initialAirport',b.initial_airport_key,'locationEffectiveUtc',b.location_effective_utc,'baseTimezone',ap.timezone_iana,'employmentFrom',r.game_effective_date,'history','[]'::jsonb,'absences',airlinerra_game.section9_crew_unavailability_windows_v1(pr.airline_id,pr.crew_id,NULL,p_start),'permissions',q.permissions) ORDER BY pr.crew_id),'[]') INTO pilots
 FROM airlinerra_game.section9_pilot_profiles_v1 pr JOIN airlinerra_game.section9_pilot_base_assignments_v1 b ON b.crew_id=pr.crew_id AND b.airline_id=pr.airline_id
 JOIN airlinerra_game.section9_airline_crew_roster_v1 r ON r.crew_id=pr.crew_id AND r.airline_id=pr.airline_id
 JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=b.world_id AND ap.airport_key=b.base_airport_key
 CROSS JOIN LATERAL (
 SELECT coalesce(jsonb_agg(jsonb_build_object('group',q.qualification_group,'issued',q.issued_game_date,'expires',q.expires_game_date,'active',q.qualification_status='active','captain',airlinerra_game.section9_pilot_can_fill_rank_v1(pr.career_rank,q.captain_permission,q.first_officer_permission,'captain'),'firstOfficer',airlinerra_game.section9_pilot_can_fill_rank_v1(pr.career_rank,q.captain_permission,q.first_officer_permission,'first_officer')) ORDER BY q.qualification_group),'[]') permissions
 FROM airlinerra_game.section9_pilot_family_permissions_v1 q WHERE q.crew_id=pr.crew_id AND q.airline_id=pr.airline_id
 ) q
 WHERE pr.airline_id=p_airline AND r.employment_status='verified_employed' AND r.game_effective_date IS NOT NULL
 AND ap.timezone_iana IS NOT NULL AND EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=ap.timezone_iana);
 SELECT NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_cabin_crew_pools_v1 p WHERE p.airline_id=p_airline AND p.employed_count<>(SELECT count(*) FROM airlinerra_game.section9_cabin_crew_members_v1 m WHERE m.airline_id=p.airline_id AND m.base_airport_key=p.base_airport_key AND m.role=p.role)) INTO pool_ok;
 SELECT coalesce(jsonb_agg(jsonb_build_object('id',m.member_id,'role',m.role,'baseAirportKey',m.base_airport_key,'initialAirport',m.initial_airport_key,'locationEffectiveUtc',m.location_effective_utc,'baseTimezone',ap.timezone_iana,'employmentFrom',m.effective_game_date,'history','[]'::jsonb,'absences',airlinerra_game.section9_crew_unavailability_windows_v1(m.airline_id,NULL,m.member_id,p_start)) ORDER BY m.member_id),'[]') INTO cabin
 FROM airlinerra_game.section9_cabin_crew_members_v1 m JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=m.world_id AND ap.airport_key=m.base_airport_key
 WHERE m.airline_id=p_airline AND m.employment_status='employed' AND m.role IN('flight_attendant','cabin_supervisor','purser') AND pool_ok
 AND ap.timezone_iana IS NOT NULL AND EXISTS(SELECT 1 FROM pg_timezone_names WHERE name=ap.timezone_iana);
 RETURN jsonb_build_object('status','weekly_crew_bootstrap_input_preview','windowStartUtc',p_start,'flights',flights,'pilots',pilots,'cabinMembers',cabin,'invalidOccurrenceCount',invalid_count,'activeScheduleCount',active_count,'cabinHeadcountReconciled',pool_ok,'unavailabilityIntegrated',true,'dutyHistoryIntegrated',false,'scheduleCompletenessVerified',false,'dispatchEnforced',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_weekly_crew_input_v1(uuid,uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;

-- Trusted-worker snapshot and atomic automatic procurement. A live execution
-- is forbidden until verified schedules AND actual duty histories are available.
CREATE TABLE airlinerra_game.section9_automatic_crew_hire_runs_v1(
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 run_id uuid NOT NULL,game_date date NOT NULL,settings_version integer NOT NULL,
 snapshot jsonb NOT NULL,hire_groups jsonb NOT NULL,
 additional_monthly_salary_usd numeric(16,2) NOT NULL CHECK(additional_monthly_salary_usd>=0),
 result jsonb NOT NULL,created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(airline_id,run_id)
);
CREATE INDEX section9_auto_hire_month_idx ON airlinerra_game.section9_automatic_crew_hire_runs_v1(airline_id,game_date);
ALTER TABLE airlinerra_game.section9_automatic_crew_hire_runs_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_automatic_crew_hire_runs_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.section9_owned_automatic_recruitment_snapshot_v1(p_player uuid,p_airline uuid,p_start timestamptz)
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
 RETURN jsonb_build_object('status','automatic_crew_recruitment_snapshot','airlineId',p_airline,'gameDate',dt,'input',inp,'overview',ov,'settings',coalesce(pref,'{"mode":"manual","reservePercent":0,"monthlyBudgetUsd":0,"version":0}'::jsonb),'salaryPolicy',salaries,'cabinBaseSalaries',coalesce((SELECT jsonb_object_agg(base_airport_key,monthly_salary_usd) FROM airlinerra_game.section9_cabin_crew_pools_v1 WHERE airline_id=p_airline AND role='flight_attendant'),'{}'::jsonb),'cashUsd',cash,'monthAuthorizedCommitmentsUsd',spent);
END $$;

-- All quotes are recomputed inside the airline lock. The worker's request is
-- never accepted from a player API. A failure in any batch rolls back all hires.
CREATE FUNCTION airlinerra_game.section9_execute_automatic_crew_hire_v1(p_player uuid,p_airline uuid,p_run uuid,p_start timestamptz,p_snapshot jsonb,p_groups jsonb)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
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
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_automatic_recruitment_snapshot_v1(uuid,uuid,timestamptz),airlinerra_game.section9_execute_automatic_crew_hire_v1(uuid,uuid,uuid,timestamptz,jsonb,jsonb) FROM PUBLIC,anon,authenticated,service_role;
