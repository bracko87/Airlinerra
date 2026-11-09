-- Section 9: game-generated crew employment contracts. All values are
-- provisional GAME economics, not real-world salaries or legal credentials.
-- Flight activation is still blocked by the independent operational gate.
ALTER TABLE airlinerra_game.section9_airline_crew_roster_v1
 ADD COLUMN IF NOT EXISTS monthly_salary_usd numeric(12,2)
   CHECK(monthly_salary_usd BETWEEN 0 AND 100000),
 ADD COLUMN IF NOT EXISTS contract_source text
   CHECK(contract_source IN ('game_npc_offer_v1')),
 ADD COLUMN IF NOT EXISTS game_effective_date date,
 ADD COLUMN IF NOT EXISTS contract_signed_at timestamptz;
COMMENT ON COLUMN airlinerra_game.section9_airline_crew_roster_v1.employment_status IS
 'verified_employed for NPC means a game-server-issued employment contract, NOT actual aviation certification or legal flight-deck approval.';

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_crew_salary_policy_v1(
 max_seats int PRIMARY KEY CHECK(max_seats BETWEEN 0 AND 10000),
 monthly_base_salary_usd numeric(12,2) NOT NULL
   CHECK(monthly_base_salary_usd BETWEEN 1000 AND 100000),
 policy_basis text NOT NULL DEFAULT 'provisional_game_salary_v1'
   CHECK(policy_basis='provisional_game_salary_v1')
);
ALTER TABLE airlinerra_game.section9_crew_salary_policy_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_crew_salary_policy_v1 FROM PUBLIC,anon,authenticated;
INSERT INTO airlinerra_game.section9_crew_salary_policy_v1(max_seats,monthly_base_salary_usd)
VALUES (19,4500),(79,5500),(199,6800),(349,8200),(10000,10000)
ON CONFLICT(max_seats) DO NOTHING;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_crew_game_salary_v1(
 p_configuration bigint,p_candidate_slot int
) RETURNS numeric LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE seats int; base_pay numeric;
BEGIN
 IF p_configuration IS NULL OR p_candidate_slot NOT BETWEEN 1 AND 2000
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_GAME_CREW_OFFER';END IF;
 SELECT greatest(0,coalesce(c.typical_passenger_seats,
  c.maximum_passenger_seats,0))
 INTO seats FROM airlinerra.aircraft_configurations c
 WHERE c.id=p_configuration;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_CREW_CONFIGURATION_NOT_FOUND';END IF;
 SELECT monthly_base_salary_usd INTO base_pay
 FROM airlinerra_game.section9_crew_salary_policy_v1
 WHERE max_seats>=seats ORDER BY max_seats LIMIT 1;
 IF base_pay IS NULL THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_CREW_SALARY_POLICY_MISSING';END IF;
 -- Small deterministic NPC-contract variety, never player-entered salary.
 RETURN base_pay+((p_candidate_slot-1)%5)*125;
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_crew_game_salary_v1(bigint,int)
 FROM PUBLIC,anon,authenticated;

-- Read 12 unclaimed virtual candidate slots for a real owned-aircraft draft.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_crew_offers_v1(
 p_player uuid,p_airline uuid,p_schedule uuid
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE conf bigint; result jsonb;
BEGIN
 SELECT d.configuration_id INTO conf
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 JOIN airlinerra_game.airlines a ON a.id=d.airline_id
 AND a.owner_player_id=p_player AND a.world_id=1
 JOIN airlinerra_game.airline_aircraft_inventory f
 ON f.id=d.aircraft_inventory_id AND f.airline_id=d.airline_id
 AND f.configuration_id=d.configuration_id
 WHERE d.id=p_schedule AND d.airline_id=p_airline AND d.world_id=1
 AND d.status='draft';
 IF conf IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_OWNED_CREW_MARKET_NOT_AVAILABLE';END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
  'candidateSlot',x.slot,'crewReference','NPC-FD-'||conf||'-'||x.slot,
  'qualifiedConfigurationId',conf,
  'monthlySalaryUsd',airlinerra_game.section9_crew_game_salary_v1(conf,x.slot),
  'monthlySalaryProvisional',true)
  ORDER BY x.slot),'[]'::jsonb)
 INTO result
 FROM (SELECT s.slot FROM generate_series(1,2000) AS s(slot)
 WHERE NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_airline_crew_roster_v1 cr
  WHERE cr.airline_id=p_airline
   AND cr.crew_reference='NPC-FD-'||conf||'-'||s.slot)
 ORDER BY s.slot LIMIT 12) x;
 RETURN jsonb_build_object('status','game_npc_crew_market',
 'scheduleId',p_schedule,'configurationId',conf,'offers',result,
 'provisionalGameSalary',true,'contractAutomaticallyGameVerified',true,
 'aviationQualifiedForFlight',false,'canActivateNormalFlight',false,
 'noSalaryChargedUntilVerifiedGameClock',true,'readOnly',true);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_owned_crew_offers_v1(
 uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;

-- A game NPC contract is a game employment event, not independent
-- flight-deck certification. No signing cost, no cash or ledger mutation.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_hire_owned_game_crew_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,p_candidate_slot int
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE conf bigint; salary numeric; ref text; existing record;
 game_date date; clock_source text; proof text; inserted int;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_schedule IS NULL
 OR p_candidate_slot NOT BETWEEN 1 AND 2000 THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_CREW_HIRE_REQUEST';END IF;
 SELECT d.configuration_id INTO conf
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 JOIN airlinerra_game.airlines a ON a.id=d.airline_id
  AND a.owner_player_id=p_player AND a.world_id=1
 JOIN airlinerra_game.airline_aircraft_inventory fleet
  ON fleet.id=d.aircraft_inventory_id AND fleet.airline_id=d.airline_id
  AND fleet.configuration_id=d.configuration_id
 WHERE d.id=p_schedule AND d.airline_id=p_airline AND d.world_id=1
 AND d.status='draft' FOR SHARE OF d;
 IF conf IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_CREW_HIRE_REQUIRES_OWNED_DRAFT';END IF;
 -- All concurrent hiring and airline cash updates serialize on the owner.
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=p_airline FOR UPDATE;
 salary:=airlinerra_game.section9_crew_game_salary_v1(conf,p_candidate_slot);
 ref:='NPC-FD-'||conf||'-'||p_candidate_slot;
 SELECT clock.confirmed_game_date,clock.clock_source
 INTO game_date,clock_source FROM airlinerra_game.holding_world_clock_v1 clock
 WHERE clock.world_id=1;
 IF clock_source IS DISTINCT FROM 'authoritative_game_engine' THEN
  game_date:=NULL;END IF;
 proof:='game-npc-contract-v1:'||p_airline||':'||conf||':'||p_candidate_slot;
 INSERT INTO airlinerra_game.section9_airline_crew_roster_v1(
  world_id,airline_id,crew_reference,role,qualified_configuration_id,
  employment_status,employment_proof_ref,employment_reviewed_at,
  monthly_salary_usd,contract_source,game_effective_date,contract_signed_at)
 VALUES(1,p_airline,ref,'flight_deck',conf,
  'verified_employed',proof,clock_timestamp(),salary,
  'game_npc_offer_v1',game_date,clock_timestamp())
 ON CONFLICT(airline_id,crew_reference) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 SELECT * INTO existing
 FROM airlinerra_game.section9_airline_crew_roster_v1
 WHERE airline_id=p_airline AND crew_reference=ref;
 IF NOT FOUND OR existing.qualified_configuration_id<>conf
  OR existing.contract_source IS DISTINCT FROM 'game_npc_offer_v1'
  OR existing.monthly_salary_usd IS DISTINCT FROM salary
 THEN RAISE EXCEPTION USING ERRCODE='23505',
  MESSAGE='SECTION9_CREW_HIRE_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object(
  'status','game_crew_contract_signed','crewId',existing.crew_id,
  'crewReference',ref,'qualifiedConfigurationId',conf,
  'monthlySalaryUsd',salary,'newContract',inserted=1,
  'effectiveGameDate',existing.game_effective_date,
  'salaryPaymentDeferredUntilVerifiedGameClock',true,
  'flightDeckOperationallyCertified',false,
  'canActivateNormalFlight',false,'ledgerPosted',false);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_hire_owned_game_crew_v1(
 uuid,uuid,uuid,int) FROM PUBLIC,anon,authenticated;

COMMENT ON FUNCTION airlinerra_game.section9_hire_owned_game_crew_v1(
 uuid,uuid,uuid,int) IS
 'Idempotent player-owned game-generated NPC crew contract. No real-world aviation credentials, activation or financial posting; game salary starts at verified clock payroll.';
