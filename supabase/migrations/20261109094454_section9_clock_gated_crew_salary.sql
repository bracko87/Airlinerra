-- Crew salary commitment + uniquely accounted daily expenses, only when
-- the already-existing authoritative game clock is confirmed.
-- NO independent cron or clock fake, no passenger revenue or flight activation.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_game_crew_payroll_days_v1(
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 game_date date NOT NULL CHECK(game_date BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'),
 crew_count int NOT NULL CHECK(crew_count BETWEEN 0 AND 100000),
 amount_usd numeric(16,2) NOT NULL CHECK(amount_usd>=0),
 ledger_id bigint UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 posted_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(airline_id,game_date),
 CHECK((amount_usd=0 AND ledger_id IS NULL) OR (amount_usd>0 AND ledger_id IS NOT NULL))
);
ALTER TABLE airlinerra_game.section9_game_crew_payroll_days_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_game_crew_payroll_days_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.section9_game_crew_payroll_days_v1 IS
 'Exactly-once NPC crew salary expense by airline and authoritative in-game date. Never settle without verified existing world clock.';

CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_game_crew_salary_preview_v1(
 p_player uuid,p_airline uuid
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE salary numeric; crew_count integer; clock_date date; clock_kind text;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines a
   WHERE a.id=p_airline AND a.owner_player_id=p_player AND a.world_id=1)
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_CREW_PAYROLL_AIRLINE_NOT_OWNED';END IF;
 SELECT count(*)::int,coalesce(sum(c.monthly_salary_usd),0)
 INTO crew_count,salary
 FROM airlinerra_game.section9_airline_crew_roster_v1 c
 WHERE c.airline_id=p_airline AND c.contract_source='game_npc_offer_v1'
  AND c.employment_status='verified_employed';
 SELECT confirmed_game_date,clock_source INTO clock_date,clock_kind
 FROM airlinerra_game.holding_world_clock_v1 WHERE world_id=1;
 RETURN jsonb_build_object('status','game_crew_salary_forecast',
  'crewCount',crew_count,'monthlySalaryCommitmentUsd',salary,
  'salaryBasis','provisional_game_design',
  'clockVerified',clock_kind='authoritative_game_engine' AND clock_date IS NOT NULL,
  'confirmedGameDate',clock_date,
  'automaticPayrollEnabled',false,
  'manualPlayerSalaryPostingAllowed',false,'readOnly',true);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_owned_game_crew_salary_preview_v1(
 uuid,uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_post_verified_game_crew_payroll_v1(
 p_airline uuid,p_day date
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE clk record; company record; last_date date; prior record;
 total numeric(16,2);n int; inserted_ledger_id bigint;
 days_in_month integer; charged numeric; new_rows int;
BEGIN
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
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_post_verified_game_crew_payroll_v1(
 uuid,date) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section9_post_verified_game_crew_payroll_v1(
 uuid,date) IS
 'Internal trusted game-clock daily salary cost, once per airline and game day with serialized cash+ledger transaction. No player-callable payroll endpoint.';
