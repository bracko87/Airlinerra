-- Disposable-only posted-flight ledger attribution acceptance.
-- Isolated representative fixture, never production rows or migrations.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.airline_ledger') IS NOT NULL
 OR to_regclass('airlinerra_game.section9_route_posted_flight_financials_v1') IS NOT NULL
 THEN RAISE EXCEPTION 'POSTED_LEDGER_ATTRIBUTION_DISPOSABLE_ONLY';END IF;
END $guard$;
CREATE TABLE airlinerra_game.airline_ledger(
 id bigint PRIMARY KEY,airline_id uuid NOT NULL,entry_kind text NOT NULL,
 amount_usd numeric NOT NULL);
CREATE TABLE airlinerra_game.section9_route_posted_flight_financials_v1(
 physical_flight_id text PRIMARY KEY,schedule_id uuid NOT NULL,
 airline_id uuid NOT NULL,record_status text NOT NULL,
 ticket_income_usd numeric NOT NULL,cargo_income_usd numeric NOT NULL,
 other_income_usd numeric NOT NULL,airport_navigation_cost_usd numeric NOT NULL,
 fuel_cost_usd numeric NOT NULL,crew_cost_usd numeric NOT NULL,
 maintenance_cost_usd numeric NOT NULL,ownership_cost_usd numeric NOT NULL,
 other_cost_usd numeric NOT NULL,
 revenue_ledger_id bigint UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 expense_ledger_id bigint UNIQUE NOT NULL REFERENCES airlinerra_game.airline_ledger(id));
INSERT INTO airlinerra_game.airline_ledger VALUES
 (1001,'11111111-1111-4111-8111-111111111111','REVENUE',200),
 (1002,'11111111-1111-4111-8111-111111111111','EXPENSE',-80),
 (1003,'11111111-1111-4111-8111-111111111111','REVENUE',199),
 (1004,'11111111-1111-4111-8111-111111111111','EXPENSE',-80),
 (1005,'22222222-2222-4222-8222-222222222222','EXPENSE',-80);
INSERT INTO airlinerra_game.section9_route_posted_flight_financials_v1 VALUES
 ('88888888-8888-4888-8888-888888888888:2026-11-21:1',
  '88888888-8888-4888-8888-888888888888',
  '11111111-1111-4111-8111-111111111111','posted_complete',
  180,0,20,30,40,10,0,0,0,1001,1002),
 ('99999999-9999-4999-8999-999999999999:2026-11-21:1',
  '99999999-9999-4999-8999-999999999999',
  '11111111-1111-4111-8111-111111111111','posted_complete',
  180,0,20,30,40,10,0,0,0,1003,1004);
-- Use the same ledger attribution predicate as the server read-only SQL.
CREATE VIEW airlinerra_game.fixture_posted_flight_attribution AS
 SELECT p.schedule_id,p.airline_id,p.ticket_income_usd,
 CASE WHEN
      p.record_status IS DISTINCT FROM 'posted_complete'
      OR (p.revenue_ledger_id IS NULL
          AND (p.ticket_income_usd+p.cargo_income_usd+p.other_income_usd)<>0)
      OR (p.revenue_ledger_id IS NOT NULL
          AND (lr.id IS NULL OR lr.airline_id IS DISTINCT FROM p.airline_id
           OR lr.entry_kind IS DISTINCT FROM 'REVENUE'
           OR lr.amount_usd IS DISTINCT FROM
             p.ticket_income_usd+p.cargo_income_usd+p.other_income_usd))
      OR le.id IS NULL OR le.airline_id IS DISTINCT FROM p.airline_id
      OR le.entry_kind IS DISTINCT FROM 'EXPENSE'
      OR le.amount_usd IS DISTINCT FROM -(
        p.airport_navigation_cost_usd+p.fuel_cost_usd+p.crew_cost_usd+
        p.maintenance_cost_usd+p.ownership_cost_usd+p.other_cost_usd)
  THEN 1 ELSE 0 END AS mismatched
 FROM airlinerra_game.section9_route_posted_flight_financials_v1 p
 LEFT JOIN airlinerra_game.airline_ledger lr ON lr.id=p.revenue_ledger_id
 LEFT JOIN airlinerra_game.airline_ledger le ON le.id=p.expense_ledger_id;
DO $test$
DECLARE valid_mismatch int;incorrect_mismatch int;
BEGIN
 SELECT mismatched INTO valid_mismatch
 FROM airlinerra_game.fixture_posted_flight_attribution WHERE schedule_id=
 '88888888-8888-4888-8888-888888888888'::uuid;
 SELECT mismatched INTO incorrect_mismatch
 FROM airlinerra_game.fixture_posted_flight_attribution WHERE schedule_id=
 '99999999-9999-4999-8999-999999999999'::uuid;
 IF valid_mismatch<>0 OR incorrect_mismatch<>1 THEN
  RAISE EXCEPTION 'Posted ledger mismatch detection failed: %, %',valid_mismatch,incorrect_mismatch;END IF;
 UPDATE airlinerra_game.section9_route_posted_flight_financials_v1
 SET expense_ledger_id=1005 WHERE schedule_id='88888888-8888-4888-8888-888888888888'::uuid;
 SELECT mismatched INTO valid_mismatch
 FROM airlinerra_game.fixture_posted_flight_attribution WHERE schedule_id=
 '88888888-8888-4888-8888-888888888888'::uuid;
 IF valid_mismatch<>1 THEN RAISE EXCEPTION 'Cross-airline expense ledger not detected';END IF;
 RAISE NOTICE 'PASS posted flight accounting attribution: valid, wrong amount and cross-airline reference';
END $test$;
