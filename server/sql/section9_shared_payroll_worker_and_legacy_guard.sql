CREATE OR REPLACE FUNCTION airlinerra_game.section9_post_verified_game_crew_payroll_v1(p_airline uuid, p_day date)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE clk record; company record; last_date date; prior record;
 total numeric(16,2);n int; inserted_ledger_id bigint;
 days_in_month integer; charged numeric; new_rows int;
BEGIN
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_shared_crew_salary_terms_v1 WHERE airline_id=p_airline) OR EXISTS(SELECT 1 FROM airlinerra_game.section9_shared_crew_employment_release_v1 WHERE world_id=1 AND payroll_enabled) THEN
  RETURN jsonb_build_object('status','shared_payroll_processor_required','ledgerPosted',false,'salaryPaid',false);
 END IF;
 IF p_airline IS NULL OR p_day IS NULL OR
 p_day NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_CREW_PAYROLL_DAY';END IF;
 SELECT * INTO clk FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=1 FOR SHARE;
 IF NOT FOUND OR clk.clock_source<>'authoritative_game_engine' OR
  clk.confirmed_game_date IS NULL OR
  length(coalesce(clk.engine_proof_ref,''))<12 OR clk.last_verified_at IS NULL
 THEN RETURN jsonb_build_object('status','blocked_unverified_game_clock',
  'ledgerPosted',false,'salaryPaid',false);END IF;
 IF p_day>clk.confirmed_game_date THEN
  RETURN jsonb_build_object('status','blocked_future_game_date',
   'ledgerPosted',false,'salaryPaid',false);END IF;
 SELECT * INTO company FROM airlinerra_game.airlines
 WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_PAYROLL_AIRLINE_NOT_FOUND';END IF;
 SELECT * INTO prior FROM airlinerra_game.section9_game_crew_payroll_days_v1
 WHERE airline_id=p_airline AND game_date=p_day;
 IF FOUND THEN
  RETURN jsonb_build_object('status','already_posted','airlineId',p_airline,
   'gameDate',p_day,'amountUsd',prior.amount_usd,'crewCount',prior.crew_count,
   'ledgerPosted',prior.ledger_id IS NOT NULL,'replayed',true);
 END IF;
 SELECT max(game_date) INTO last_date
 FROM airlinerra_game.section9_game_crew_payroll_days_v1
 WHERE airline_id=p_airline;
 IF last_date IS NOT NULL AND p_day<>last_date+1 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_CREW_PAYROLL_REQUIRES_CONSECUTIVE_DAY';END IF;
 IF last_date IS NULL AND p_day<>clk.confirmed_game_date THEN
  RETURN jsonb_build_object('status','blocked_initial_payroll_not_current_day',
  'ledgerPosted',false,'salaryPaid',false);
 END IF;
 -- Contracts signed before game-clock readiness start on the first
 -- verified paid day; never invent a past salary obligation.
 UPDATE airlinerra_game.section9_airline_crew_roster_v1
 SET game_effective_date=p_day
 WHERE airline_id=p_airline AND contract_source='game_npc_offer_v1'
 AND employment_status='verified_employed'
 AND game_effective_date IS NULL;
 days_in_month:=extract(day FROM
  ((date_trunc('month',p_day)::date+interval '1 month')-interval '1 day'))::int;
 SELECT count(*)::int,coalesce(sum(
  round(c.monthly_salary_usd/days_in_month,2)),0)::numeric(16,2)
 INTO n,total FROM airlinerra_game.section9_airline_crew_roster_v1 c
 WHERE c.airline_id=p_airline AND c.contract_source='game_npc_offer_v1'
  AND c.employment_status='verified_employed'
  AND c.game_effective_date<=p_day;
 IF total>company.cash_usd THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_CREW_PAYROLL_INSUFFICIENT_AIRLINE_CASH';END IF;
 IF total>0 THEN
  UPDATE airlinerra_game.airlines SET cash_usd=cash_usd-total
   WHERE id=p_airline AND cash_usd>=total;
  GET DIAGNOSTICS new_rows=ROW_COUNT;
  IF new_rows<>1 THEN RAISE EXCEPTION USING ERRCODE='40001',
   MESSAGE='SECTION9_CREW_PAYROLL_CASH_CONFLICT';END IF;
  INSERT INTO airlinerra_game.airline_ledger(
   airline_id,entry_kind,amount_usd)
  VALUES(p_airline,'EXPENSE',-total)
  RETURNING id INTO inserted_ledger_id;
 END IF;
 INSERT INTO airlinerra_game.section9_game_crew_payroll_days_v1(
  airline_id,game_date,crew_count,amount_usd,ledger_id)
 VALUES(p_airline,p_day,n,total,inserted_ledger_id);
 RETURN jsonb_build_object('status','game_crew_payroll_accounted',
  'airlineId',p_airline,'gameDate',p_day,'crewCount',n,
  'amountUsd',total,'ledgerPosted',inserted_ledger_id IS NOT NULL,
  'replayed',false,'commercialFlightActivated',false);
END $function$
;
-- Bounded trusted worker, intentionally not scheduled until release.
CREATE FUNCTION airlinerra_game.section9_run_shared_crew_payroll_v1(p_limit integer DEFAULT 50)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE rel record;today_date date;item record;r jsonb;results jsonb:='[]'::jsonb;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 500 THEN RAISE EXCEPTION USING ERRCODE='22023';END IF;
 SELECT * INTO STRICT rel FROM airlinerra_game.section9_shared_crew_employment_release_v1 WHERE world_id=1;
 IF NOT rel.payroll_enabled THEN RETURN jsonb_build_object('status','shared_payroll_disabled','processed',0);END IF;
 today_date:=(airlinerra_game.section9_verified_world_instant_v1() AT TIME ZONE 'Europe/Berlin')::date;
 FOR item IN WITH firsts AS(SELECT airline_id,min(effective_game_date) first_day FROM airlinerra_game.section9_shared_crew_salary_terms_v1 GROUP BY airline_id),
 due AS(SELECT f.airline_id,greatest(f.first_day,rel.payroll_start_game_date,coalesce((SELECT max(game_date)+1 FROM airlinerra_game.section9_game_crew_payroll_days_v1 d WHERE d.airline_id=f.airline_id),f.first_day)) due_day FROM firsts f)
 SELECT * FROM due WHERE due_day<today_date ORDER BY due_day,airline_id LIMIT p_limit LOOP
 BEGIN
 r:=airlinerra_game.section9_post_shared_crew_payroll_v1(item.airline_id,item.due_day);
 EXCEPTION WHEN OTHERS THEN r:=jsonb_build_object('status','payroll_processing_error','sqlstate',SQLSTATE);END;
 results:=results||jsonb_build_array(jsonb_build_object('airlineId',item.airline_id,'gameDate',item.due_day,'result',r));
 END LOOP;
 RETURN jsonb_build_object('status','shared_payroll_run','processed',jsonb_array_length(results),'results',results);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_run_shared_crew_payroll_v1(integer) FROM PUBLIC,anon,authenticated,service_role;