-- Airlinerra AOC foundation v1 (17 Nov 2026).
-- INSTALL ONLY. Policy gates remain FALSE. No airline classification, AOC,
-- incident, payment, worker, route release or safety penalty is seeded.
-- This is game-only; never claims a real civil aviation authorization.
--
-- Existing paid game-permission issuer remains untouched. Its verifier needs
-- a future explicit free-original source path; never fake a paid application.

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_aoc_release_policy_v1 (
 world_id smallint PRIMARY KEY DEFAULT 1 CHECK(world_id=1),
 issuance_enabled boolean NOT NULL DEFAULT false,
 safety_events_enabled boolean NOT NULL DEFAULT false,
 renewal_enabled boolean NOT NULL DEFAULT false,
 flight_enforcement_enabled boolean NOT NULL DEFAULT false,
 reviewed_by text,
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(NOT flight_enforcement_enabled OR
  (issuance_enabled AND safety_events_enabled AND renewal_enabled))
);
INSERT INTO airlinerra_game.section9_aoc_release_policy_v1
 (world_id,issuance_enabled,safety_events_enabled,renewal_enabled,
  flight_enforcement_enabled,reviewed_by)
VALUES (1,false,false,false,false,'INITIAL_DORMANT_AOC_FOUNDATION')
ON CONFLICT (world_id) DO NOTHING;
ALTER TABLE airlinerra_game.section9_aoc_release_policy_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aoc_release_policy_v1
 FROM PUBLIC,anon,authenticated,service_role;

-- Operating airline identity only: no holding or academy AOC.
-- Subsidiaries cannot be registered without an explicit holding subsidiary.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_aoc_operating_companies_v1 (
 airline_id uuid PRIMARY KEY REFERENCES airlinerra_game.airlines(id)
  ON DELETE RESTRICT,
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 company_source text NOT NULL CHECK(company_source IN('original','subsidiary')),
 business_kind text NOT NULL CHECK(business_kind IN
  ('passenger','regional','low_cost','cargo','charter','vip')),
 holding_id uuid REFERENCES airlinerra_game.holding_groups_v1(id),
 subsidiary_id uuid UNIQUE REFERENCES airlinerra_game.holding_subsidiaries_v1(id),
 identity_evidence_reference text NOT NULL
  CHECK(length(identity_evidence_reference)>=12),
 verified_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(airline_id,world_id),
 CHECK((company_source='original' AND subsidiary_id IS NULL)
    OR (company_source='subsidiary' AND holding_id IS NOT NULL
        AND subsidiary_id IS NOT NULL))
);
ALTER TABLE airlinerra_game.section9_aoc_operating_companies_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aoc_operating_companies_v1
 FROM PUBLIC,anon,authenticated,service_role;

-- Real issue/renewal and initial paid subsidiary provenance are separate.
-- An original airline uses no fee ledger; a subsidiary must have one.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_aoc_certificates_v1 (
 certificate_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 airline_id uuid NOT NULL UNIQUE REFERENCES
  airlinerra_game.section9_aoc_operating_companies_v1(airline_id),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 initial_issue_source text NOT NULL CHECK(initial_issue_source IN
  ('original_free_registration','subsidiary_paid_application')),
 initial_issue_application_id uuid UNIQUE REFERENCES
  airlinerra_game.section9_game_permission_applications_v1(id),
 initial_issue_ledger_id bigint UNIQUE REFERENCES
  airlinerra_game.airline_ledger(id),
 initial_issue_verified_reference text NOT NULL
  CHECK(length(initial_issue_verified_reference)>=16),
 status text NOT NULL CHECK(status IN('active','expired')),
 issued_game_day date NOT NULL,
 expires_game_day date NOT NULL,
 reminded_for_expiry_game_day date,
 last_decision_game_day date NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(expires_game_day=issued_game_day+365),
 CHECK((initial_issue_source='original_free_registration'
    AND initial_issue_ledger_id IS NULL
    AND initial_issue_application_id IS NULL)
  OR (initial_issue_source='subsidiary_paid_application'
    AND initial_issue_ledger_id IS NOT NULL
    AND initial_issue_application_id IS NOT NULL)),
 FOREIGN KEY (airline_id,world_id) REFERENCES
  airlinerra_game.section9_aoc_operating_companies_v1(airline_id,world_id)
);
ALTER TABLE airlinerra_game.section9_aoc_certificates_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aoc_certificates_v1
 FROM PUBLIC,anon,authenticated,service_role;

-- Signed/verified game-event provenance must be confirmed by a trusted producer
-- before incident insertion is ever wired. No client-write API exists.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_aoc_safety_incidents_v1 (
 event_id text PRIMARY KEY CHECK(length(event_id) BETWEEN 12 AND 160),
 airline_id uuid NOT NULL REFERENCES
  airlinerra_game.section9_aoc_operating_companies_v1(airline_id),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 severity text NOT NULL CHECK(severity IN('minor','serious','major')),
 penalty_points smallint GENERATED ALWAYS AS
  (CASE severity WHEN 'minor' THEN 5
    WHEN 'serious' THEN 20 ELSE 30 END) STORED,
 occurred_game_day date NOT NULL,
 description_code text NOT NULL CHECK(description_code ~ '^[A-Z][A-Z0-9_]{3,95}$'),
 verified_event_reference text NOT NULL CHECK(length(verified_event_reference)>=16),
 required_action_count smallint NOT NULL DEFAULT 1
  CHECK(required_action_count BETWEEN 1 AND 8),
 resolved_game_day date,
 resolution_reference text,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(event_id,airline_id),
 CHECK(resolved_game_day IS NULL OR resolved_game_day>=occurred_game_day),
 CHECK((resolved_game_day IS NULL AND resolution_reference IS NULL)
  OR (resolved_game_day IS NOT NULL AND
    length(resolution_reference)>=12)),
 FOREIGN KEY (airline_id,world_id) REFERENCES
  airlinerra_game.section9_aoc_operating_companies_v1(airline_id,world_id)
);
CREATE INDEX IF NOT EXISTS section9_aoc_incidents_airline_day_v1
 ON airlinerra_game.section9_aoc_safety_incidents_v1
 (airline_id,occurred_game_day);
ALTER TABLE airlinerra_game.section9_aoc_safety_incidents_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aoc_safety_incidents_v1
 FROM PUBLIC,anon,authenticated,service_role;

-- A resolved incident counts ONLY after mandatory tasks have non-zero
-- verified, COMPANY-PAID financial and completion evidence.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_aoc_corrective_tasks_v1 (
 task_id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 event_id text NOT NULL,
 airline_id uuid NOT NULL,
 task_key text NOT NULL CHECK(length(task_key)>=8),
 work_kind text NOT NULL CHECK(work_kind IN
  ('aircraft_repair','safety_inspection','compliance_audit')),
 quote_usd numeric(14,2) NOT NULL CHECK(quote_usd>0),
 quote_source_reference text NOT NULL CHECK(length(quote_source_reference)>=12),
 status text NOT NULL DEFAULT 'quoted'
  CHECK(status IN('quoted','booked','paid','completed')),
 paid_ledger_entry_id bigint UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 completion_receipt_reference text,
 completed_game_day date,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(event_id,task_key),
 FOREIGN KEY(event_id,airline_id) REFERENCES
  airlinerra_game.section9_aoc_safety_incidents_v1(event_id,airline_id),
 CHECK((status IN('quoted','booked') AND paid_ledger_entry_id IS NULL
      AND completed_game_day IS NULL AND completion_receipt_reference IS NULL)
   OR (status='paid' AND paid_ledger_entry_id IS NOT NULL
      AND completed_game_day IS NULL AND completion_receipt_reference IS NULL)
   OR (status='completed' AND paid_ledger_entry_id IS NOT NULL
      AND completed_game_day IS NOT NULL AND
      length(completion_receipt_reference)>=12))
);
CREATE INDEX IF NOT EXISTS section9_aoc_tasks_event_v1
 ON airlinerra_game.section9_aoc_corrective_tasks_v1(event_id,airline_id);
ALTER TABLE airlinerra_game.section9_aoc_corrective_tasks_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aoc_corrective_tasks_v1
 FROM PUBLIC,anon,authenticated,service_role;

-- Immutable decision and reminder audit; no timer or engine connected yet.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_aoc_review_audit_v1 (
 event_id text PRIMARY KEY CHECK(length(event_id) BETWEEN 16 AND 160),
 airline_id uuid NOT NULL REFERENCES
  airlinerra_game.section9_aoc_operating_companies_v1(airline_id),
 game_day date NOT NULL,
 action text NOT NULL CHECK(action IN
  ('original_issue','subsidiary_issue','renew','expire','reinstate','reminder')),
 effective_safety_rating smallint CHECK(effective_safety_rating BETWEEN 0 AND 100),
 expiry_game_day date NOT NULL,
 verified_event_reference text NOT NULL CHECK(length(verified_event_reference)>=16),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(airline_id,action,game_day,expiry_game_day)
);
ALTER TABLE airlinerra_game.section9_aoc_review_audit_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_aoc_review_audit_v1
 FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER section9_aoc_review_append_only_v1
 BEFORE UPDATE OR DELETE ON airlinerra_game.section9_aoc_review_audit_v1
 FOR EACH ROW EXECUTE FUNCTION
 airlinerra_game.section9_reject_certificate_audit_mutation_v1();

-- Strictly private score computation; a "resolved" incident without fully
-- PAID and actually COMPLETED tasks still subtracts points. No manual score.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_safety_score_v1(
 p_airline uuid,p_game_day date
) RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
 WITH incident_status AS (
  SELECT i.event_id,i.airline_id,i.penalty_points,i.occurred_game_day,
   (i.resolved_game_day IS NOT NULL AND i.resolved_game_day<=p_game_day
    AND (SELECT count(*) FROM airlinerra_game.section9_aoc_corrective_tasks_v1 t
         JOIN airlinerra_game.airline_ledger l ON l.id=t.paid_ledger_entry_id
           AND l.airline_id=i.airline_id
           AND l.amount_usd<=-t.quote_usd
         WHERE t.event_id=i.event_id AND t.airline_id=i.airline_id
          AND t.status='completed'
          AND t.completed_game_day<=p_game_day
          AND length(t.completion_receipt_reference)>=12
        )=i.required_action_count
    AND (SELECT count(*) FROM airlinerra_game.section9_aoc_corrective_tasks_v1 t
         WHERE t.event_id=i.event_id AND t.airline_id=i.airline_id
        )=i.required_action_count
   ) AS fully_corrected
  FROM airlinerra_game.section9_aoc_safety_incidents_v1 i
  WHERE i.airline_id=p_airline AND i.occurred_game_day<=p_game_day
 ), tally AS (
  SELECT count(*)::integer AS lifetime,
   count(*) FILTER(WHERE occurred_game_day>p_game_day-365)::integer
     AS last365,
   count(*) FILTER(WHERE NOT fully_corrected)::integer AS open_count,
   coalesce(sum(penalty_points) FILTER(WHERE NOT fully_corrected),0)::integer
     AS penalty_total
  FROM incident_status
 )
 SELECT jsonb_build_object(
   'airlineId',p_airline,'gameDay',p_game_day,
   'rating',greatest(0,100-penalty_total),
   'unresolved',open_count,'last365GameDays',last365,'lifetime',lifetime,
   'initialBaseline',lifetime=0,'readOnly',true)
 FROM tally
$fn$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_aoc_safety_score_v1(uuid,date)
 FROM PUBLIC,anon,authenticated,service_role;

-- Owner-scoped read, to be attached behind a future authenticated server
-- handler. No AOC is invented for airlines not in the verified registry.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_aoc_owned_status_v1(
 p_player uuid,p_airline uuid,p_game_day date
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE company_row record;cert record;release_row record;score jsonb;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines a
    WHERE a.id=p_airline AND a.owner_player_id=p_player AND a.world_id=1)
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='AOC_STATUS_NOT_OWNED'; END IF;
 SELECT * INTO release_row
 FROM airlinerra_game.section9_aoc_release_policy_v1 WHERE world_id=1;
 SELECT * INTO company_row
 FROM airlinerra_game.section9_aoc_operating_companies_v1
 WHERE airline_id=p_airline AND world_id=1;
 IF NOT FOUND THEN
  RETURN jsonb_build_object('airlineId',p_airline,'worldId',1,
   'status','planned_not_released','verifiedCompanyRegistry',false,
   'issued',false,'safetyRating',null,'readOnly',true);
 END IF;
 SELECT * INTO cert FROM airlinerra_game.section9_aoc_certificates_v1
 WHERE airline_id=p_airline AND world_id=1;
 score:=airlinerra_game.section9_aoc_safety_score_v1(p_airline,p_game_day);
 RETURN jsonb_build_object('airlineId',p_airline,'worldId',1,
  'companyKind',company_row.business_kind,
  'companySource',company_row.company_source,
  'status',CASE WHEN release_row.issuance_enabled IS DISTINCT FROM true
    THEN 'planned_not_released'
    ELSE coalesce(cert.status,'not_issued') END,
  'issued',(release_row.issuance_enabled=true AND cert.certificate_id IS NOT NULL),
  'issuedGameDay',CASE WHEN release_row.issuance_enabled
     THEN cert.issued_game_day ELSE NULL END,
  'expiresGameDay',CASE WHEN release_row.issuance_enabled
     THEN cert.expires_game_day ELSE NULL END,
  'safetyRating',CASE WHEN release_row.safety_events_enabled
     THEN score ELSE NULL END,
  'readOnly',true);
END $fn$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_aoc_owned_status_v1(uuid,uuid,date)
 FROM PUBLIC,anon,authenticated,service_role;

COMMENT ON TABLE airlinerra_game.section9_aoc_release_policy_v1 IS
 'AOC future release switches intentionally disabled. Separate from legacy paid permits.';
