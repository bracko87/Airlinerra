-- Phase 14A: private shared-pool contracts and payroll commitment preview.
-- No public mutation, no automatic recruitment, no live payroll or dispatch.
CREATE TABLE airlinerra_game.section9_shared_crew_employment_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 manual_hiring_enabled boolean NOT NULL DEFAULT false,
 automatic_hiring_enabled boolean NOT NULL DEFAULT false,
 payroll_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.section9_shared_crew_employment_release_v1 VALUES(1,false,false,false);
CREATE TABLE airlinerra_game.section9_shared_crew_salary_policy_v1(
 role text PRIMARY KEY CHECK(role IN('captain','first_officer','flight_attendant')),
 monthly_salary_usd numeric(12,2) NOT NULL CHECK(monthly_salary_usd BETWEEN 0 AND 100000)
);
INSERT INTO airlinerra_game.section9_shared_crew_salary_policy_v1 VALUES('captain',8500),('first_officer',5500),('flight_attendant',2200);
CREATE TABLE airlinerra_game.section9_shared_crew_hire_batches_v1(
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 request_id uuid NOT NULL, base_airport_key text NOT NULL,
 qualification_group text REFERENCES airlinerra_game.section9_pilot_qualification_groups_v1(qualification_group),
 captains integer NOT NULL CHECK(captains BETWEEN 0 AND 200),
 first_officers integer NOT NULL CHECK(first_officers BETWEEN 0 AND 200),
 cabin_staff integer NOT NULL CHECK(cabin_staff BETWEEN 0 AND 200),
 confirmed_monthly_limit_usd numeric(16,2) NOT NULL CHECK(confirmed_monthly_limit_usd>=0),
 additional_monthly_salary_usd numeric(16,2) NOT NULL CHECK(additional_monthly_salary_usd>=0),
 effective_game_date date NOT NULL,
 pilot_ids uuid[] NOT NULL,cabin_ids uuid[] NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY(airline_id,request_id),
 CHECK(cardinality(pilot_ids)=captains+first_officers AND cardinality(cabin_ids)=cabin_staff),
 FOREIGN KEY(airline_id,base_airport_key) REFERENCES airlinerra_game.section9_crew_bases_v1(airline_id,airport_key)
);
ALTER TABLE airlinerra_game.section9_shared_crew_employment_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_shared_crew_salary_policy_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_shared_crew_hire_batches_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_shared_crew_employment_release_v1,airlinerra_game.section9_shared_crew_salary_policy_v1,airlinerra_game.section9_shared_crew_hire_batches_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.section9_owned_shared_crew_payroll_forecast_v1(p_player uuid,p_airline uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE pilots int;cabin int;pilot_salary numeric;cabin_salary numeric;consistent boolean;
BEGIN
 IF current_user<>'postgres' OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 AND owner_player_id=p_player) THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT count(*),coalesce(sum(monthly_salary_usd),0) INTO pilots,pilot_salary FROM airlinerra_game.section9_airline_crew_roster_v1 WHERE airline_id=p_airline AND employment_status='verified_employed';
 SELECT NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_cabin_crew_pools_v1 p WHERE p.airline_id=p_airline AND p.employed_count<>(SELECT count(*) FROM airlinerra_game.section9_cabin_crew_members_v1 m WHERE m.airline_id=p.airline_id AND m.base_airport_key=p.base_airport_key AND m.role=p.role)) INTO consistent;
 SELECT count(*),coalesce(sum(p.monthly_salary_usd),0) INTO cabin,cabin_salary FROM airlinerra_game.section9_cabin_crew_members_v1 m JOIN airlinerra_game.section9_cabin_crew_pools_v1 p ON p.airline_id=m.airline_id AND p.base_airport_key=m.base_airport_key AND p.role=m.role WHERE m.airline_id=p_airline AND m.employment_status='employed';
 RETURN jsonb_build_object('status','shared_crew_payroll_forecast','pilotCount',pilots,'cabinCrewCount',cabin,'pilotMonthlySalaryUsd',pilot_salary,'cabinMonthlySalaryUsd',cabin_salary,'totalMonthlySalaryUsd',CASE WHEN consistent THEN pilot_salary+cabin_salary ELSE NULL END,'cabinHeadcountReconciled',consistent,'payrollPosted',false,'payrollEnabled',false);
END $$;
-- A manual quote is derived from server pricing, a registered base and owned fleet.
CREATE FUNCTION airlinerra_game.section9_owned_shared_crew_hire_quote_v1(p_player uuid,p_airline uuid,p_base text,p_group text,p_captains int,p_officers int,p_cabin int)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE conf bigint;cap_pay numeric;fo_pay numeric;cabin_pay numeric;total numeric;forecast jsonb;company_cash numeric;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT cash_usd INTO company_cash FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_captains IS NULL OR p_officers IS NULL OR p_cabin IS NULL OR p_captains NOT BETWEEN 0 AND 200 OR p_officers NOT BETWEEN 0 AND 200 OR p_cabin NOT BETWEEN 0 AND 200 OR p_captains+p_officers+p_cabin NOT BETWEEN 1 AND 200 OR ((p_captains+p_officers>0)<>(p_group IS NOT NULL)) THEN RETURN jsonb_build_object('status','invalid_hire_counts');END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_crew_bases_v1 b JOIN airlinerra_game.airport_reference_profiles ap ON ap.world_id=b.world_id AND ap.airport_key=b.airport_key WHERE b.airline_id=p_airline AND b.airport_key=p_base AND EXISTS(SELECT 1 FROM pg_timezone_names n WHERE n.name=ap.timezone_iana)) THEN RETURN jsonb_build_object('status','crew_base_unverified');END IF;
 IF p_captains+p_officers>0 THEN
 SELECT min(f.configuration_id) INTO conf FROM airlinerra_game.airline_aircraft_inventory f JOIN airlinerra_game.section9_flight_crew_model_policy_v1 pol ON pol.configuration_id=f.configuration_id WHERE f.airline_id=p_airline AND f.fleet_status<>'retired' AND pol.qualification_group=p_group;
 IF conf IS NULL THEN RETURN jsonb_build_object('status','no_owned_aircraft_for_qualification');END IF;
 END IF;
 IF p_cabin>0 AND NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory f JOIN airlinerra_game.section9_flight_crew_model_policy_v1 pol ON pol.configuration_id=f.configuration_id WHERE f.airline_id=p_airline AND f.fleet_status<>'retired' AND pol.seat_basis<>'cargo_zero') THEN RETURN jsonb_build_object('status','no_passenger_aircraft');END IF;
 SELECT monthly_salary_usd INTO STRICT cap_pay FROM airlinerra_game.section9_shared_crew_salary_policy_v1 WHERE role='captain';
 SELECT monthly_salary_usd INTO STRICT fo_pay FROM airlinerra_game.section9_shared_crew_salary_policy_v1 WHERE role='first_officer';
 SELECT monthly_salary_usd INTO cabin_pay FROM airlinerra_game.section9_cabin_crew_pools_v1 WHERE airline_id=p_airline AND base_airport_key=p_base AND role='flight_attendant';
 IF NOT FOUND THEN SELECT monthly_salary_usd INTO STRICT cabin_pay FROM airlinerra_game.section9_shared_crew_salary_policy_v1 WHERE role='flight_attendant';END IF;
 total:=p_captains*cap_pay+p_officers*fo_pay+p_cabin*cabin_pay;
 forecast:=airlinerra_game.section9_owned_shared_crew_payroll_forecast_v1(p_player,p_airline);
 RETURN jsonb_build_object('status','shared_crew_hire_quote','configurationId',conf,'baseAirportKey',p_base,'qualificationGroup',p_group,'captains',p_captains,'firstOfficers',p_officers,'cabinCrew',p_cabin,'captainSalaryUsd',cap_pay,'firstOfficerSalaryUsd',fo_pay,'cabinSalaryUsd',cabin_pay,'additionalMonthlySalaryUsd',total,'currentMonthlySalaryUsd',forecast->'totalMonthlySalaryUsd','oneMonthAffordability',coalesce(company_cash>=total+(forecast->>'totalMonthlySalaryUsd')::numeric,false),'cabinHeadcountReconciled',forecast->'cabinHeadcountReconciled','contractsCreated',false,'ledgerPosted',false);
END $$;

CREATE FUNCTION airlinerra_game.section9_confirm_owned_shared_crew_hire_v1(p_player uuid,p_airline uuid,p_request uuid,p_base text,p_group text,p_captains int,p_officers int,p_cabin int,p_monthly_limit numeric)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE prev record;q jsonb;now_utc timestamptz;dt date;conf bigint;total numeric;pay numeric;kind text;n int;num int;pid uuid;ref text;pilot_ids uuid[]:='{}';cabin_ids uuid[]:='{}';
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 AND owner_player_id=p_player FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_request IS NULL OR p_monthly_limit IS NULL OR p_monthly_limit<0 OR p_monthly_limit>1000000000 OR p_monthly_limit<>round(p_monthly_limit,2) THEN RAISE EXCEPTION USING ERRCODE='22023';END IF;
 SELECT * INTO prev FROM airlinerra_game.section9_shared_crew_hire_batches_v1 WHERE airline_id=p_airline AND request_id=p_request;
 IF FOUND THEN
 IF (prev.base_airport_key,prev.qualification_group,prev.captains,prev.first_officers,prev.cabin_staff,prev.confirmed_monthly_limit_usd) IS DISTINCT FROM (p_base,p_group,p_captains,p_officers,p_cabin,p_monthly_limit) THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='CREW_HIRE_REQUEST_CONFLICT';END IF;
 RETURN jsonb_build_object('status','shared_crew_hired','replayed',true,'pilotIds',prev.pilot_ids,'cabinIds',prev.cabin_ids,'additionalMonthlySalaryUsd',prev.additional_monthly_salary_usd,'ledgerPosted',false);
 END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_shared_crew_employment_release_v1 WHERE world_id=1 AND manual_hiring_enabled) THEN RETURN jsonb_build_object('status','shared_crew_hiring_disabled');END IF;
 q:=airlinerra_game.section9_owned_shared_crew_hire_quote_v1(p_player,p_airline,p_base,p_group,p_captains,p_officers,p_cabin);
 IF q->>'status'<>'shared_crew_hire_quote' THEN RETURN q;END IF;
 total:=(q->>'additionalMonthlySalaryUsd')::numeric;conf:=(q->>'configurationId')::bigint;
 IF total>p_monthly_limit THEN RETURN jsonb_build_object('status','crew_quote_exceeds_authorization');END IF;
 IF q->>'oneMonthAffordability'<>'true' OR q->>'cabinHeadcountReconciled'<>'true' THEN RETURN jsonb_build_object('status','crew_hiring_budget_or_reconciliation_failed');END IF;
 now_utc:=airlinerra_game.section9_verified_world_instant_v1();dt:=(now_utc AT TIME ZONE 'Europe/Berlin')::date;
 FOREACH kind IN ARRAY ARRAY['captain','first_officer'] LOOP
 num:=CASE WHEN kind='captain' THEN p_captains ELSE p_officers END;
 pay:=(q->>CASE WHEN kind='captain' THEN 'captainSalaryUsd' ELSE 'firstOfficerSalaryUsd' END)::numeric;
 FOR n IN 1..num LOOP
 ref:='NPC-SHARED-'||p_request||'-'||kind||'-'||n;
 INSERT INTO airlinerra_game.section9_airline_crew_roster_v1(world_id,airline_id,crew_reference,role,qualified_configuration_id,employment_status,employment_proof_ref,employment_reviewed_at,monthly_salary_usd,contract_source,game_effective_date,contract_signed_at)
 VALUES(1,p_airline,ref,'flight_deck',conf,'verified_employed','shared-contract:'||ref,now_utc,pay,'game_npc_offer_v1',dt,now_utc) RETURNING crew_id INTO pid;
 INSERT INTO airlinerra_game.section9_pilot_profiles_v1(crew_id,airline_id,career_rank) VALUES(pid,p_airline,kind);
 INSERT INTO airlinerra_game.section9_pilot_family_permissions_v1(airline_id,crew_id,qualification_group,captain_permission,first_officer_permission,qualification_status,issued_game_date,expires_game_date) VALUES(p_airline,pid,p_group,kind='captain',kind='first_officer','active',dt,dt+365);
 INSERT INTO airlinerra_game.section9_pilot_base_assignments_v1(crew_id,airline_id,base_airport_key,initial_airport_key,location_effective_utc) VALUES(pid,p_airline,p_base,p_base,now_utc);
 pilot_ids:=array_append(pilot_ids,pid);
 END LOOP;
 END LOOP;
 IF p_cabin>0 THEN
 INSERT INTO airlinerra_game.section9_cabin_crew_pools_v1 AS pool(airline_id,base_airport_key,role,employed_count,monthly_salary_usd) VALUES(p_airline,p_base,'flight_attendant',p_cabin,(q->>'cabinSalaryUsd')::numeric)
 ON CONFLICT(airline_id,base_airport_key,role) DO UPDATE SET employed_count=pool.employed_count+excluded.employed_count,version=pool.version+1,updated_at=clock_timestamp();
 FOR n IN 1..p_cabin LOOP
 INSERT INTO airlinerra_game.section9_cabin_crew_members_v1(airline_id,base_airport_key,role,initial_airport_key,location_effective_utc,employment_status,effective_game_date) VALUES(p_airline,p_base,'flight_attendant',p_base,now_utc,'employed',dt) RETURNING member_id INTO pid;
 cabin_ids:=array_append(cabin_ids,pid);
 END LOOP;
 END IF;
 INSERT INTO airlinerra_game.section9_shared_crew_hire_batches_v1(airline_id,request_id,base_airport_key,qualification_group,captains,first_officers,cabin_staff,confirmed_monthly_limit_usd,additional_monthly_salary_usd,effective_game_date,pilot_ids,cabin_ids)
 VALUES(p_airline,p_request,p_base,p_group,p_captains,p_officers,p_cabin,p_monthly_limit,total,dt,pilot_ids,cabin_ids);
 RETURN jsonb_build_object('status','shared_crew_hired','replayed',false,'pilotIds',pilot_ids,'cabinIds',cabin_ids,'additionalMonthlySalaryUsd',total,'ledgerPosted',false,'dispatchEnforced',false);
END $$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_owned_shared_crew_payroll_forecast_v1(uuid,uuid),airlinerra_game.section9_owned_shared_crew_hire_quote_v1(uuid,uuid,text,text,int,int,int),airlinerra_game.section9_confirm_owned_shared_crew_hire_v1(uuid,uuid,uuid,text,text,int,int,int,numeric) FROM PUBLIC,anon,authenticated,service_role;
