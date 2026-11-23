-- Licence 7 Flight Academy phase 1 foundation, strictly NOT a live release.
-- Creates future company-kind schema, status, applications, approvals and
-- private course-offer drafts. No public formation, payment or issuance is enabled.
-- 2026-11-20: $40k / 7 verified game days, approved by user.
ALTER TABLE airlinerra_game.holding_subsidiaries_v1
 DROP CONSTRAINT holding_subsidiaries_v1_company_kind_check;
ALTER TABLE airlinerra_game.holding_subsidiaries_v1
 ADD CONSTRAINT holding_subsidiaries_v1_company_kind_check
 CHECK (company_kind IN ('regional_airline','passenger_airline','cargo_airline',
                        'charter_airline','maintenance_mro','flight_academy'));

INSERT INTO airlinerra_game.business_permission_catalog_v1(
 permission_code,category,holder_scope,reference_basis,title,purpose,
 requirements,application_guidance,research_status,
 game_fee_usd,processing_game_days,enabled_in_game)
VALUES(
 'FLIGHT_ACADEMY','company','operating_company','game_proposal',
 'Licence 7 — Flight Academy / Training Organization Approval',
 'Single academy company approval for training its holding employees and external airlines. Optional paid external courses under the same licence.',
 'Registered flight_academy subsidiary, no subsidiary age waiting, at least one purchased/delivered/operational eligible small training aircraft assigned to the academy, with future instructors, facilities, training programmes, aircraft/simulator and finance checks.',
 'Design and phase-1 foundation only: free submission once released; seven verified game days review and $40,000 charge exactly once upon approval. Public directory off by default with custom per-course prices; live issuance and billing forbidden until verified academy infrastructure is implemented.',
 'reference_only',40000,7,false
)
ON CONFLICT (permission_code) DO UPDATE SET
  purpose=excluded.purpose,requirements=excluded.requirements,
  application_guidance=excluded.application_guidance,
  game_fee_usd=40000,processing_game_days=7,
  enabled_in_game=false,updated_at=clock_timestamp();

CREATE TABLE airlinerra_game.licence7_academy_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 company_registration_enabled boolean NOT NULL DEFAULT false,
 applications_enabled boolean NOT NULL DEFAULT false,
 issuance_enabled boolean NOT NULL DEFAULT false,
 fee_collection_enabled boolean NOT NULL DEFAULT false,
 marketplace_enabled boolean NOT NULL DEFAULT false,
 training_asset_validation_verified boolean NOT NULL DEFAULT false,
 instructor_infrastructure_verified boolean NOT NULL DEFAULT false,
 company_ledger_verified boolean NOT NULL DEFAULT false,
 calendar_booking_verified boolean NOT NULL DEFAULT false,
 release_reference text,
 CONSTRAINT licence7_phase1_hard_lock_v1 CHECK (
  NOT company_registration_enabled AND NOT applications_enabled
  AND NOT issuance_enabled AND NOT fee_collection_enabled
  AND NOT marketplace_enabled AND NOT training_asset_validation_verified
  AND NOT instructor_infrastructure_verified AND NOT company_ledger_verified
  AND NOT calendar_booking_verified
 )
);
INSERT INTO airlinerra_game.licence7_academy_release_v1(world_id) VALUES (1);

CREATE TABLE airlinerra_game.licence7_academy_applications_v1(
 application_id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 academy_subsidiary_id uuid NOT NULL REFERENCES airlinerra_game.holding_subsidiaries_v1(id),
 holding_id uuid NOT NULL,
 owner_player_id uuid NOT NULL,
 request_key uuid NOT NULL,
 application_status text NOT NULL DEFAULT 'submitted'
   CHECK (application_status IN ('submitted','under_review','issued','withdrawn','declined')),
 applied_game_day date NOT NULL,
 due_game_day date NOT NULL,
 fee_on_approval_usd numeric(14,2) NOT NULL DEFAULT 40000 CHECK(fee_on_approval_usd=40000),
 application_fee_usd numeric(14,2) NOT NULL DEFAULT 0 CHECK(application_fee_usd=0),
 issued_game_day date,
 approval_reference text UNIQUE,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE (academy_subsidiary_id,request_key),
 FOREIGN KEY (academy_subsidiary_id,holding_id,world_id)
 REFERENCES airlinerra_game.holding_subsidiaries_v1(id,holding_id,world_id),
 CHECK (due_game_day=applied_game_day+7),
 CHECK ((application_status='issued')=(issued_game_day IS NOT NULL AND approval_reference IS NOT NULL))
);
CREATE UNIQUE INDEX licence7_one_pending_company_application_v1
 ON airlinerra_game.licence7_academy_applications_v1(academy_subsidiary_id)
 WHERE application_status IN ('submitted','under_review');

CREATE TABLE airlinerra_game.licence7_academy_approvals_v1(
 academy_subsidiary_id uuid PRIMARY KEY REFERENCES airlinerra_game.holding_subsidiaries_v1(id),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 application_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.licence7_academy_applications_v1(application_id),
 status text NOT NULL CHECK(status IN ('active','suspended','revoked')),
 issued_game_day date NOT NULL,
 last_inspected_game_day date NOT NULL,
 next_inspection_due_game_day date NOT NULL,
 initial_fee_usd numeric(14,2) NOT NULL CHECK(initial_fee_usd=40000),
 fee_ledger_reference text NOT NULL UNIQUE,
 approval_reference text NOT NULL UNIQUE,
 status_reason text,
 reviewed_by text NOT NULL,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK (next_inspection_due_game_day=last_inspected_game_day+365)
);

-- Future course-offer records: no unsupported public sales, and no draft prices
-- silently turned into contracts. Published must always remain false until cutover.
CREATE TABLE airlinerra_game.licence7_academy_course_offers_v1(
 offer_id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
 academy_subsidiary_id uuid NOT NULL REFERENCES airlinerra_game.holding_subsidiaries_v1(id),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 course_key text NOT NULL CHECK(course_key ~ '^[A-Z0-9_]{3,70}$'),
 display_name text NOT NULL CHECK (length(trim(display_name)) BETWEEN 3 AND 120),
 location_airport_key text,
 aircraft_family text,
 price_usd numeric(14,2) NOT NULL CHECK(price_usd>=0),
 is_listed boolean NOT NULL DEFAULT false CHECK(is_listed=false),
 accepts_external_bookings boolean NOT NULL DEFAULT false CHECK(accepts_external_bookings=false),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(academy_subsidiary_id,course_key,location_airport_key)
);

ALTER TABLE airlinerra_game.licence7_academy_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.licence7_academy_applications_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.licence7_academy_approvals_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.licence7_academy_course_offers_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.licence7_academy_release_v1,
 airlinerra_game.licence7_academy_applications_v1,
 airlinerra_game.licence7_academy_approvals_v1,
 airlinerra_game.licence7_academy_course_offers_v1
 FROM PUBLIC,anon,authenticated,service_role;

-- Trusted read-only ownership-scoped preview. Never reports readiness as
-- complete while mandatory operational training assets cannot be verified.
CREATE OR REPLACE FUNCTION airlinerra_game.licence7_academy_readiness_v1(
 p_owner uuid,p_subsidiary uuid
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE c record; d date; problems text[]:=array[]::text[];
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE7_TRUSTED_PREVIEW_ONLY';
 END IF;
 IF p_owner IS NULL OR p_subsidiary IS NULL THEN
  RETURN jsonb_build_object('status','INVALID_COMPANY','canApply',false,
    'eligible',false,'feeUsd',40000,'applicationFeeUsd',0,
    'processingGameDays',7,'issued',false,'charged',false);
 END IF;
 SELECT s.id,s.holding_id,s.world_id,s.company_kind,s.formation_state,h.owner_player_id,h.state AS holding_state
 INTO c
 FROM airlinerra_game.holding_subsidiaries_v1 s
 JOIN airlinerra_game.holding_groups_v1 h
 ON h.id=s.holding_id AND h.world_id=s.world_id
 WHERE s.id=p_subsidiary AND s.world_id=1 AND h.owner_player_id=p_owner;
 IF NOT FOUND THEN
  RETURN jsonb_build_object('status','ACADEMY_NOT_OWNED_OR_UNKNOWN',
   'canApply',false,'eligible',false,'feeUsd',40000,
   'applicationFeeUsd',0,'processingGameDays',7,'charged',false);
 END IF;
 IF c.company_kind<>'flight_academy' THEN
  problems:=array_append(problems,'REGISTERED_FLIGHT_ACADEMY_REQUIRED');
 END IF;
 IF c.formation_state<>'registered' OR c.holding_state<>'registered' THEN
  problems:=array_append(problems,'COMPANY_REGISTRATION_NOT_COMPLETE');
 END IF;
 d:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF d IS NULL THEN problems:=array_append(problems,'VERIFIED_GAME_DAY_REQUIRED');END IF;
 problems:=array_append(problems,'ONE_PURCHASED_OPERATIONAL_SMALL_TRAINING_AIRCRAFT_NOT_VERIFIED');
 problems:=array_append(problems,'ACADEMY_FACILITIES_INSTRUCTORS_PROGRAMMES_NOT_IMPLEMENTED');
 problems:=array_append(problems,'COMPANY_FINANCE_LEDGER_AND_REVIEW_NOT_VERIFIED');
 problems:=array_append(problems,'LICENCE7_NOT_RELEASED');
 RETURN jsonb_build_object('status','LICENCE7_PHASE1_READ_ONLY',
 'academySubsidiaryId',c.id,'holdingId',c.holding_id,
 'gameDay',d,'eligible',false,'canApply',false,'issued',false,
 'charged',false,'isListed',false,'courseBookingsEnabled',false,
 'applicationFeeUsd',0,'feeUsd',40000,'processingGameDays',7,
 'minimumCompanyAgeGameDays',0,'minimumOperationalSmallTrainingAircraft',1,
 'issues',to_jsonb(problems));
END $fn$;

-- Exposed to the future trusted application service only. An app cannot be
-- submitted, approved, or charged during Phase 1 even via direct SQL execution.
CREATE OR REPLACE FUNCTION airlinerra_game.licence7_submit_academy_application_v1(
 p_owner uuid,p_subsidiary uuid,p_request_key uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE7_TRUSTED_SUBMISSION_ONLY';
 END IF;
 IF p_owner IS NULL OR p_subsidiary IS NULL OR p_request_key IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='LICENCE7_INVALID_SUBMISSION';
 END IF;
 RETURN jsonb_build_object('status','NOT_RELEASED',
 'applicationSubmitted',false,'charged',false,'issued',false,
 'feeOnApprovalUsd',40000,'processingGameDays',7);
END $fn$;

CREATE OR REPLACE FUNCTION airlinerra_game.licence7_review_due_academy_applications_v1(
 p_limit integer DEFAULT 25
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE7_TRUSTED_REVIEW_ONLY';
 END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 25 THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='LICENCE7_INVALID_BATCH_LIMIT';
 END IF;
 RETURN jsonb_build_object('status','NOT_RELEASED','reviewed',0,
 'issued',0,'charged',false,'feeOnApprovalUsd',40000,
 'processingGameDays',7,'nextInspectionIntervalGameDays',365);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.licence7_academy_readiness_v1(uuid,uuid),
 airlinerra_game.licence7_submit_academy_application_v1(uuid,uuid,uuid),
 airlinerra_game.licence7_review_due_academy_applications_v1(integer)
 FROM PUBLIC,anon,authenticated,service_role;
