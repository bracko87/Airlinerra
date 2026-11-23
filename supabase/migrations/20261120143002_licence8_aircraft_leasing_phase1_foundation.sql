-- Airlinerra Licence 8 Aircraft Leasing — PHASE 1 ONLY, all live features locked.
-- No formation, lease execution, licence issuance, debit, or public marketplace.
ALTER TABLE airlinerra_game.holding_subsidiaries_v1 DROP CONSTRAINT holding_subsidiaries_v1_company_kind_check;
ALTER TABLE airlinerra_game.holding_subsidiaries_v1
 ADD CONSTRAINT holding_subsidiaries_v1_company_kind_check
 CHECK (company_kind IN ('regional_airline','passenger_airline','cargo_airline',
 'charter_airline','maintenance_mro','flight_academy','aircraft_leasing'));

INSERT INTO airlinerra_game.business_permission_catalog_v1(
 permission_code,category,holder_scope,reference_basis,title,purpose,
 requirements,application_guidance,research_status,
 game_fee_usd,processing_game_days,enabled_in_game)
VALUES(
 'AIRCRAFT_LEASING','company','operating_company','game_proposal',
 'Licence 8 — Aircraft Leasing Company Approval',
 'One company licence for dry leasing owned aircraft to holding airlines or external player airlines; ACMI/wet leasing remains an airline-operator activity.',
 'Registered aircraft_leasing subsidiary; zero separate minimum company age. Ownership, independent company finance, aircraft registration/airworthiness, contracts, insurance, operating-control checks and lease exclusivity must be verified before future issuance.',
 'Free application; seven verified game days; exactly one $100,000 fee upon approval only. Annual compliance inspection after 365 game days; optional private-by-default aircraft offers at player-set terms. STRICTLY NOT RELEASED until aircraft ownership/financial/contract systems exist.',
 'reference_only',100000,7,false)
ON CONFLICT(permission_code) DO UPDATE SET
 purpose=excluded.purpose,requirements=excluded.requirements,
 application_guidance=excluded.application_guidance,
 game_fee_usd=100000,processing_game_days=7,enabled_in_game=false,
 updated_at=clock_timestamp();

CREATE TABLE airlinerra_game.licence8_leasing_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 company_registration_enabled boolean NOT NULL DEFAULT false,
 applications_enabled boolean NOT NULL DEFAULT false,
 issuance_enabled boolean NOT NULL DEFAULT false,
 fee_collection_enabled boolean NOT NULL DEFAULT false,
 marketplace_enabled boolean NOT NULL DEFAULT false,
 lease_execution_enabled boolean NOT NULL DEFAULT false,
 aircraft_ownership_verified boolean NOT NULL DEFAULT false,
 company_ledger_verified boolean NOT NULL DEFAULT false,
 lease_exclusivity_verified boolean NOT NULL DEFAULT false,
 insurance_readiness_verified boolean NOT NULL DEFAULT false,
 release_reference text,
 CONSTRAINT licence8_phase1_hard_lock_v1 CHECK(
  NOT company_registration_enabled AND NOT applications_enabled
  AND NOT issuance_enabled AND NOT fee_collection_enabled
  AND NOT marketplace_enabled AND NOT lease_execution_enabled
  AND NOT aircraft_ownership_verified AND NOT company_ledger_verified
  AND NOT lease_exclusivity_verified AND NOT insurance_readiness_verified)
);
INSERT INTO airlinerra_game.licence8_leasing_release_v1(world_id) VALUES(1);

CREATE TABLE airlinerra_game.licence8_leasing_applications_v1(
 application_id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 leasing_subsidiary_id uuid NOT NULL REFERENCES airlinerra_game.holding_subsidiaries_v1(id),
 holding_id uuid NOT NULL,
 owner_player_id uuid NOT NULL,
 request_key uuid NOT NULL,
 application_status text NOT NULL DEFAULT 'submitted'
 CHECK(application_status IN ('submitted','under_review','issued','withdrawn','declined')),
 applied_game_day date NOT NULL,
 due_game_day date NOT NULL,
 application_fee_usd numeric(14,2) NOT NULL DEFAULT 0 CHECK(application_fee_usd=0),
 fee_on_approval_usd numeric(14,2) NOT NULL DEFAULT 100000 CHECK(fee_on_approval_usd=100000),
 issued_game_day date,
 approval_reference text UNIQUE,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(leasing_subsidiary_id,request_key),
 FOREIGN KEY(leasing_subsidiary_id,holding_id,world_id)
 REFERENCES airlinerra_game.holding_subsidiaries_v1(id,holding_id,world_id),
 CHECK(due_game_day=applied_game_day+7),
 CHECK((application_status='issued')=(issued_game_day IS NOT NULL AND approval_reference IS NOT NULL))
);
CREATE UNIQUE INDEX licence8_one_pending_company_application_v1
 ON airlinerra_game.licence8_leasing_applications_v1(leasing_subsidiary_id)
 WHERE application_status IN('submitted','under_review');

CREATE TABLE airlinerra_game.licence8_leasing_approvals_v1(
 leasing_subsidiary_id uuid PRIMARY KEY REFERENCES airlinerra_game.holding_subsidiaries_v1(id),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 application_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.licence8_leasing_applications_v1(application_id),
 status text NOT NULL CHECK(status IN('active','suspended','revoked')),
 issued_game_day date NOT NULL,
 last_inspected_game_day date NOT NULL,
 next_inspection_due_game_day date NOT NULL,
 initial_fee_usd numeric(14,2) NOT NULL CHECK(initial_fee_usd=100000),
 fee_ledger_reference text NOT NULL UNIQUE,
 approval_reference text NOT NULL UNIQUE,
 reviewed_by text NOT NULL,
 status_reason text,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(next_inspection_due_game_day=last_inspected_game_day+365)
);

-- Draft-only leasing offers. No active listings, leases or booking acceptance.
-- Link inventory to lessor ownership later: the existing airline aircraft
-- inventory does NOT establish leasing-company asset title or a safe lease.
CREATE TABLE airlinerra_game.licence8_leasing_offer_drafts_v1(
 offer_id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
 leasing_subsidiary_id uuid NOT NULL REFERENCES airlinerra_game.holding_subsidiaries_v1(id),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 aircraft_reference text NOT NULL CHECK(length(trim(aircraft_reference)) BETWEEN 3 AND 120),
 aircraft_model text NOT NULL CHECK(length(trim(aircraft_model)) BETWEEN 2 AND 120),
 monthly_price_usd numeric(14,2) NOT NULL CHECK(monthly_price_usd>=0),
 minimum_months integer NOT NULL CHECK(minimum_months>0),
 maximum_months integer NOT NULL CHECK(maximum_months>=minimum_months),
 deposit_usd numeric(14,2) NOT NULL DEFAULT 0 CHECK(deposit_usd>=0),
 is_listed boolean NOT NULL DEFAULT false CHECK(is_listed=false),
 can_accept_contracts boolean NOT NULL DEFAULT false CHECK(can_accept_contracts=false),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(leasing_subsidiary_id,aircraft_reference)
);

ALTER TABLE airlinerra_game.licence8_leasing_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.licence8_leasing_applications_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.licence8_leasing_approvals_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.licence8_leasing_offer_drafts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.licence8_leasing_release_v1,
 airlinerra_game.licence8_leasing_applications_v1,
 airlinerra_game.licence8_leasing_approvals_v1,
 airlinerra_game.licence8_leasing_offer_drafts_v1
 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.licence8_leasing_readiness_v1(
 p_owner uuid,p_subsidiary uuid
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE c record; problems text[]:=array[]::text[];
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE8_TRUSTED_PREVIEW_ONLY';
 END IF;
 IF p_owner IS NULL OR p_subsidiary IS NULL THEN
  RETURN jsonb_build_object('status','INVALID_COMPANY','eligible',false,
   'canApply',false,'charged',false,'issued',false);
 END IF;
 SELECT s.id,s.holding_id,s.company_kind,s.formation_state,h.state AS holding_state
 INTO c FROM airlinerra_game.holding_subsidiaries_v1 s
 JOIN airlinerra_game.holding_groups_v1 h ON h.id=s.holding_id AND h.world_id=s.world_id
 WHERE s.id=p_subsidiary AND s.world_id=1 AND h.owner_player_id=p_owner;
 IF NOT FOUND THEN
  RETURN jsonb_build_object('status','COMPANY_NOT_OWNED_OR_UNKNOWN',
   'eligible',false,'canApply',false,'charged',false,'issued',false);
 END IF;
 IF c.company_kind<>'aircraft_leasing' THEN
  problems:=array_append(problems,'REGISTERED_AIRCRAFT_LEASING_COMPANY_REQUIRED');
 END IF;
 IF c.formation_state<>'registered' OR c.holding_state<>'registered' THEN
  problems:=array_append(problems,'COMPANY_REGISTRATION_NOT_COMPLETE');
 END IF;
 problems:=array_append(problems,'AIRCRAFT_OWNERSHIP_AND_EXCLUSIVE_LEASE_CHECK_NOT_IMPLEMENTED');
 problems:=array_append(problems,'LEASING_COMPANY_LEDGER_INSURANCE_AND_CONTRACTS_NOT_VERIFIED');
 problems:=array_append(problems,'LICENCE8_NOT_RELEASED');
 RETURN jsonb_build_object('status','LICENCE8_PHASE1_READ_ONLY',
  'leasingSubsidiaryId',c.id,'holdingId',c.holding_id,
  'eligible',false,'canApply',false,'charged',false,'issued',false,
  'publiclyListed',false,'leaseExecutionEnabled',false,
  'applicationFeeUsd',0,'feeOnApprovalUsd',100000,
  'processingGameDays',7,'minimumCompanyAgeGameDays',0,
  'issues',to_jsonb(problems));
END $fn$;

CREATE OR REPLACE FUNCTION airlinerra_game.licence8_submit_leasing_application_v1(
 p_owner uuid,p_subsidiary uuid,p_request_key uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE8_TRUSTED_SUBMISSION_ONLY';
 END IF;
 IF p_owner IS NULL OR p_subsidiary IS NULL OR p_request_key IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='LICENCE8_INVALID_SUBMISSION';
 END IF;
 RETURN jsonb_build_object('status','NOT_RELEASED','submitted',false,
 'charged',false,'issued',false,'feeOnApprovalUsd',100000,
 'processingGameDays',7);
END $fn$;

CREATE OR REPLACE FUNCTION airlinerra_game.licence8_review_due_leasing_applications_v1(
 p_limit integer DEFAULT 25
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE8_TRUSTED_REVIEW_ONLY';
 END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 25 THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='LICENCE8_INVALID_BATCH_LIMIT';
 END IF;
 RETURN jsonb_build_object('status','NOT_RELEASED','reviewed',0,
 'issued',0,'charged',false,'feeOnApprovalUsd',100000,
 'processingGameDays',7,'inspectionCycleGameDays',365);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.licence8_leasing_readiness_v1(uuid,uuid),
 airlinerra_game.licence8_submit_leasing_application_v1(uuid,uuid,uuid),
 airlinerra_game.licence8_review_due_leasing_applications_v1(integer)
 FROM PUBLIC,anon,authenticated,service_role;
