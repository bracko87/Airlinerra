-- Phase 14D: completed game-day payroll, frozen hiring terms, no automatic release.
ALTER TABLE airlinerra_game.section9_shared_crew_employment_release_v1 ADD COLUMN payroll_start_game_date date;
ALTER TABLE airlinerra_game.section9_shared_crew_employment_release_v1 ADD CHECK(NOT payroll_enabled OR payroll_start_game_date IS NOT NULL);
CREATE TABLE airlinerra_game.section9_shared_crew_salary_terms_v1(
 airline_id uuid NOT NULL,request_id uuid NOT NULL,pilot_id uuid,cabin_member_id uuid,
 employee_id uuid GENERATED ALWAYS AS (coalesce(pilot_id,cabin_member_id)) STORED PRIMARY KEY,
 role text NOT NULL CHECK(role IN('pilot','cabin')),
 effective_game_date date NOT NULL,monthly_salary_usd numeric(12,2) NOT NULL CHECK(monthly_salary_usd BETWEEN 0 AND 100000),
 CHECK((role='pilot' AND pilot_id IS NOT NULL AND cabin_member_id IS NULL) OR (role='cabin' AND cabin_member_id IS NOT NULL AND pilot_id IS NULL)),
 FOREIGN KEY(airline_id,request_id) REFERENCES airlinerra_game.section9_shared_crew_hire_batches_v1(airline_id,request_id),
 FOREIGN KEY(airline_id,pilot_id) REFERENCES airlinerra_game.section9_pilot_profiles_v1(airline_id,crew_id),
 FOREIGN KEY(airline_id,cabin_member_id) REFERENCES airlinerra_game.section9_cabin_crew_members_v1(airline_id,member_id),
 UNIQUE(airline_id,employee_id));
CREATE INDEX section9_shared_salary_terms_airline_idx ON airlinerra_game.section9_shared_crew_salary_terms_v1(airline_id,effective_game_date);
CREATE TABLE airlinerra_game.section9_shared_crew_payroll_lines_v1(
 airline_id uuid NOT NULL,game_date date NOT NULL,employee_id uuid NOT NULL,role text NOT NULL CHECK(role IN('pilot','cabin')),
 monthly_salary_usd numeric(12,2) NOT NULL,amount_usd numeric(12,2) NOT NULL CHECK(amount_usd>=0),
 PRIMARY KEY(airline_id,game_date,employee_id),
 FOREIGN KEY(airline_id,employee_id) REFERENCES airlinerra_game.section9_shared_crew_salary_terms_v1(airline_id,employee_id),
 FOREIGN KEY(airline_id,game_date) REFERENCES airlinerra_game.section9_game_crew_payroll_days_v1(airline_id,game_date));
ALTER TABLE airlinerra_game.section9_shared_crew_salary_terms_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_shared_crew_payroll_lines_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_shared_crew_salary_terms_v1,airlinerra_game.section9_shared_crew_payroll_lines_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE FUNCTION airlinerra_game.section9_capture_shared_hire_salary_v1() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE n int;total numeric;
BEGIN
 INSERT INTO airlinerra_game.section9_shared_crew_salary_terms_v1(airline_id,request_id,pilot_id,role,effective_game_date,monthly_salary_usd)
 SELECT NEW.airline_id,NEW.request_id,r.crew_id,'pilot',NEW.effective_game_date,r.monthly_salary_usd FROM airlinerra_game.section9_airline_crew_roster_v1 r WHERE r.airline_id=NEW.airline_id AND r.crew_id=ANY(NEW.pilot_ids) AND r.game_effective_date=NEW.effective_game_date;
 INSERT INTO airlinerra_game.section9_shared_crew_salary_terms_v1(airline_id,request_id,cabin_member_id,role,effective_game_date,monthly_salary_usd)
 SELECT NEW.airline_id,NEW.request_id,m.member_id,'cabin',NEW.effective_game_date,p.monthly_salary_usd FROM airlinerra_game.section9_cabin_crew_members_v1 m JOIN airlinerra_game.section9_cabin_crew_pools_v1 p ON p.airline_id=m.airline_id AND p.base_airport_key=m.base_airport_key AND p.role=m.role WHERE m.airline_id=NEW.airline_id AND m.member_id=ANY(NEW.cabin_ids) AND m.effective_game_date=NEW.effective_game_date;
 SELECT count(*),coalesce(sum(monthly_salary_usd),0) INTO n,total FROM airlinerra_game.section9_shared_crew_salary_terms_v1 WHERE airline_id=NEW.airline_id AND request_id=NEW.request_id;
 IF n<>NEW.captains+NEW.first_officers+NEW.cabin_staff OR total<>NEW.additional_monthly_salary_usd THEN RAISE EXCEPTION 'SHARED_CREW_SALARY_SNAPSHOT_MISMATCH';END IF;
 RETURN NEW;
END $$;
CREATE TRIGGER section9_capture_shared_hire_salary AFTER INSERT ON airlinerra_game.section9_shared_crew_hire_batches_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_capture_shared_hire_salary_v1();
DO $$ BEGIN IF EXISTS(SELECT 1 FROM airlinerra_game.section9_shared_crew_hire_batches_v1) THEN RAISE EXCEPTION 'EXISTING_HIRE_BATCHES_REQUIRE_SALARY_BACKFILL';END IF;END $$;
CREATE FUNCTION airlinerra_game.section9_daily_salary_share_v1(p_salary numeric,p_day date)
RETURNS numeric LANGUAGE sql IMMUTABLE STRICT SECURITY INVOKER SET search_path TO pg_catalog AS $$
 SELECT round(p_salary*extract(day FROM p_day)/extract(day FROM (date_trunc('month',p_day::timestamp)+interval '1 month'-interval '1 day')),2)
 -round(p_salary*(extract(day FROM p_day)-1)/extract(day FROM (date_trunc('month',p_day::timestamp)+interval '1 month'-interval '1 day')),2);
$$;
CREATE FUNCTION airlinerra_game.section9_post_shared_crew_payroll_v1(p_airline uuid,p_day date)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE rel record;company record;prior record;today_date date;first_date date;last_date date;due_date date;total numeric;pilot_total numeric;cabin_total numeric;n int;lid bigint;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_airline IS NULL OR p_day IS NULL OR p_day NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-31' THEN RAISE EXCEPTION USING ERRCODE='22023';END IF;
 SELECT * INTO STRICT rel FROM airlinerra_game.section9_shared_crew_employment_release_v1 WHERE world_id=1;
 IF NOT rel.payroll_enabled THEN RETURN jsonb_build_object('status','shared_payroll_disabled','ledgerPosted',false);END IF;
 today_date:=(airlinerra_game.section9_verified_world_instant_v1() AT TIME ZONE 'Europe/Berlin')::date;
 SELECT * INTO company FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO prior FROM airlinerra_game.section9_game_crew_payroll_days_v1 WHERE airline_id=p_airline AND game_date=p_day;
 IF FOUND THEN RETURN jsonb_build_object('status','already_posted','amountUsd',prior.amount_usd,'crewCount',prior.crew_count,'ledgerPosted',prior.ledger_id IS NOT NULL,'replayed',true);END IF;
 IF p_day>=today_date THEN RETURN jsonb_build_object('status','payroll_day_not_completed','ledgerPosted',false);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_airline_crew_roster_v1 r WHERE r.airline_id=p_airline AND r.employment_status='verified_employed' AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_shared_crew_salary_terms_v1 t WHERE t.airline_id=r.airline_id AND t.pilot_id=r.crew_id))
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_cabin_crew_members_v1 m WHERE m.airline_id=p_airline AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_shared_crew_salary_terms_v1 t WHERE t.airline_id=m.airline_id AND t.cabin_member_id=m.member_id))
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_cabin_crew_pools_v1 p WHERE p.airline_id=p_airline AND p.employed_count<>(SELECT count(*) FROM airlinerra_game.section9_cabin_crew_members_v1 m WHERE m.airline_id=p.airline_id AND m.base_airport_key=p.base_airport_key AND m.role=p.role))
 THEN RETURN jsonb_build_object('status','shared_salary_terms_unreconciled','ledgerPosted',false);END IF;
 -- Salary or employment changes require effective-dated history before release.
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_shared_crew_salary_terms_v1 t JOIN airlinerra_game.section9_airline_crew_roster_v1 r ON r.airline_id=t.airline_id AND r.crew_id=t.pilot_id WHERE t.airline_id=p_airline AND (r.monthly_salary_usd<>t.monthly_salary_usd OR r.employment_status<>'verified_employed' OR r.game_effective_date IS DISTINCT FROM t.effective_game_date))
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_shared_crew_salary_terms_v1 t JOIN airlinerra_game.section9_cabin_crew_members_v1 m ON m.airline_id=t.airline_id AND m.member_id=t.cabin_member_id JOIN airlinerra_game.section9_cabin_crew_pools_v1 p ON p.airline_id=m.airline_id AND p.base_airport_key=m.base_airport_key AND p.role=m.role WHERE t.airline_id=p_airline AND (p.monthly_salary_usd<>t.monthly_salary_usd OR m.employment_status<>'employed' OR m.effective_game_date<>t.effective_game_date))
 THEN RETURN jsonb_build_object('status','salary_term_change_requires_history','ledgerPosted',false);END IF;
 SELECT min(effective_game_date) INTO first_date FROM airlinerra_game.section9_shared_crew_salary_terms_v1 WHERE airline_id=p_airline;
 IF first_date IS NULL THEN RETURN jsonb_build_object('status','no_salary_obligations','ledgerPosted',false);END IF;
 SELECT max(game_date) INTO last_date FROM airlinerra_game.section9_game_crew_payroll_days_v1 WHERE airline_id=p_airline;
 due_date:=greatest(first_date,rel.payroll_start_game_date,coalesce(last_date+1,first_date));
 IF p_day<>due_date THEN RETURN jsonb_build_object('status','payroll_requires_next_due_day','nextDueGameDate',due_date,'ledgerPosted',false);END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1 WHERE world_id=1 AND game_date=p_day AND length(event_hmac_sha256)=64) THEN RETURN jsonb_build_object('status','payroll_day_not_verified','ledgerPosted',false);END IF;
 SELECT count(*),coalesce(sum(airlinerra_game.section9_daily_salary_share_v1(monthly_salary_usd,p_day)) FILTER(WHERE role='pilot'),0),coalesce(sum(airlinerra_game.section9_daily_salary_share_v1(monthly_salary_usd,p_day)) FILTER(WHERE role='cabin'),0)
 INTO n,pilot_total,cabin_total FROM airlinerra_game.section9_shared_crew_salary_terms_v1 WHERE airline_id=p_airline AND effective_game_date<=p_day;
 total:=pilot_total+cabin_total;
 IF total>company.cash_usd THEN RETURN jsonb_build_object('status','payroll_insufficient_cash','amountDueUsd',total,'ledgerPosted',false);END IF;
 IF total>0 THEN UPDATE airlinerra_game.airlines SET cash_usd=cash_usd-total WHERE id=p_airline;
 INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd) VALUES(p_airline,'EXPENSE',-total) RETURNING id INTO lid;END IF;
 INSERT INTO airlinerra_game.section9_game_crew_payroll_days_v1(airline_id,game_date,crew_count,amount_usd,ledger_id) VALUES(p_airline,p_day,n,total,lid);
 INSERT INTO airlinerra_game.section9_shared_crew_payroll_lines_v1(airline_id,game_date,employee_id,role,monthly_salary_usd,amount_usd)
 SELECT airline_id,p_day,employee_id,role,monthly_salary_usd,airlinerra_game.section9_daily_salary_share_v1(monthly_salary_usd,p_day) FROM airlinerra_game.section9_shared_crew_salary_terms_v1 WHERE airline_id=p_airline AND effective_game_date<=p_day;
 RETURN jsonb_build_object('status','shared_crew_payroll_posted','gameDate',p_day,'amountUsd',total,'pilotAmountUsd',pilot_total,'cabinAmountUsd',cabin_total,'crewCount',n,'ledgerPosted',lid IS NOT NULL,'replayed',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_capture_shared_hire_salary_v1(),airlinerra_game.section9_daily_salary_share_v1(numeric,date),airlinerra_game.section9_post_shared_crew_payroll_v1(uuid,date) FROM PUBLIC,anon,authenticated,service_role;
