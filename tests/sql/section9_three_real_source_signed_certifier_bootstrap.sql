-- Standalone private issuer + atomic sink acceptance on the EXISTING
-- disposable BEG-ZAG AOC/L1/slot source test fixture. All keys are NEW
-- synthetic 72-character local values. No live Vault data is exported.
\set ON_ERROR_STOP on
DO $guard$ BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.fixture_source_route_game_evidence') IS NULL
 OR to_regclass('airlinerra_game.section9_aoc_certificates_v1') IS NULL
 OR to_regclass('airlinerra_game.section6_weekly_airport_slot_reservations_v1') IS NULL
 THEN RAISE EXCEPTION 'SIGNED_CERTIFIER_REQUIRES_DISPOSABLE_SOURCE_FIXTURE';END IF;
END $guard$;

-- PostgreSQL pgcrypto is the real cryptographic implementation used by
-- the deployed issuer. The key store here is a synthetic throwaway table.
CREATE SCHEMA extensions;
CREATE EXTENSION pgcrypto WITH SCHEMA extensions;
CREATE SCHEMA vault;
CREATE TABLE vault.decrypted_secrets(
 name text PRIMARY KEY,decrypted_secret text NOT NULL
 CHECK(length(decrypted_secret)>=64));
INSERT INTO vault.decrypted_secrets(name,decrypted_secret) VALUES
('airlinerra_game_clearance_operator_licence_v1',repeat('O',72)),
('airlinerra_game_clearance_route_traffic_rights_v1',repeat('R',72)),
('airlinerra_game_clearance_airport_slot_capacity_v1',repeat('S',72));
REVOKE ALL ON SCHEMA vault FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON vault.decrypted_secrets FROM PUBLIC,anon,authenticated,service_role;

-- The older generic roundtrip fixture pre-seeded 10 fake certificates and
-- events with a different schema. Replace only those fixture tables with
-- the real schema contract and start with ZERO operational approvals.
DROP TABLE airlinerra_game.section9_schedule_operational_certifications_v1;
DROP TABLE airlinerra_game.section9_operational_certification_events_v1;

CREATE TABLE airlinerra_game.section9_operational_certification_events_v1(
 event_id text PRIMARY KEY CHECK(event_id~'^[A-Za-z0-9._:-]{16,128}$'),
 schedule_id uuid NOT NULL REFERENCES airlinerra_game.airline_flight_schedule_drafts_v1(id) ON DELETE RESTRICT,
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id) ON DELETE RESTRICT,
 schedule_version integer NOT NULL CHECK(schedule_version>0),
 clearance_type text NOT NULL CHECK(clearance_type IN('crew_duty','operator_licence','route_traffic_rights','airport_slot_capacity','trusted_flight_execution','commercial_finance')),
 action text NOT NULL CHECK(action IN('certify','revoke')),
 source_kind text NOT NULL,
 source_reference text NOT NULL CHECK(length(source_reference) BETWEEN 16 AND 160),
 reviewer_reference text NOT NULL CHECK(length(reviewer_reference) BETWEEN 12 AND 160),
 valid_from_game_date date NOT NULL,valid_to_game_date date NOT NULL,
 verified_hmac_sha256 text NOT NULL CHECK(verified_hmac_sha256~'^[a-f0-9]{64}$'),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(valid_to_game_date>=valid_from_game_date AND valid_to_game_date<=valid_from_game_date+365)
);
ALTER TABLE airlinerra_game.section9_operational_certification_events_v1 ENABLE ROW LEVEL SECURITY;
CREATE INDEX section9_signed_disposable_events_schedule_ix
 ON airlinerra_game.section9_operational_certification_events_v1(schedule_id,schedule_version,clearance_type,recorded_at DESC);

CREATE OR REPLACE FUNCTION airlinerra_game.section9_reject_certificate_audit_mutation_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER AS $fn$
BEGIN
 RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_CERTIFICATION_EVENT_LOG_IS_APPEND_ONLY';
END $fn$;
CREATE TRIGGER section9_certification_event_immutable
 BEFORE UPDATE OR DELETE ON airlinerra_game.section9_operational_certification_events_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.section9_reject_certificate_audit_mutation_v1();

CREATE TABLE airlinerra_game.section9_schedule_operational_certifications_v1(
 schedule_id uuid NOT NULL REFERENCES airlinerra_game.airline_flight_schedule_drafts_v1(id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 schedule_version integer NOT NULL,clearance_type text NOT NULL,
 review_status text NOT NULL,source_kind text NOT NULL,
 source_reference text NOT NULL,reviewer_reference text NOT NULL,
 reviewed_at timestamptz NOT NULL,valid_from_game_date date NOT NULL,
 valid_to_game_date date NOT NULL,last_verified_event_id text NOT NULL
 REFERENCES airlinerra_game.section9_operational_certification_events_v1(event_id),
 PRIMARY KEY(schedule_id,schedule_version,clearance_type)
);
CREATE TABLE airlinerra_game.section9_schedule_activation_preparations_v1(
 schedule_id uuid NOT NULL,schedule_version integer NOT NULL,
 payload jsonb,PRIMARY KEY(schedule_id,schedule_version));

-- Extra source check inside the REAL sink has its own crew/permissions
-- preflight function. This is a SYNTHETIC evidence adapter only.
-- Critical: sink ALSO recalculates actual canonical AOC, L1 rights and
-- exact slot reservations with the existing production verifiers.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_crew_licence_preflight_v1(
 p_player uuid,p_airline uuid,p_schedule uuid,p_date date,p_days integer)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER AS $fn$
 SELECT jsonb_build_object('permissions',jsonb_build_object(
 'gameOperatorLicenceEvidenceRecorded',true,'requiredServiceTypes',1,
 'gameRoutePermissionEvidenceRecorded',1),'syntheticCrewEvidence',true)
 WHERE EXISTS(SELECT 1 FROM airlinerra_game.world_memberships w
 WHERE w.world_id=1 AND w.player_id=p_player AND w.state='active')
$fn$;

-- Keep not-yet-released execution/finance outside this issuer acceptance:
-- a read-only synthetic source rejects them, no signing or certificates.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_execution_finance_source_snapshot_v1(
 p_airline uuid,p_schedule uuid,p_version integer,p_game_date date,p_type text)
RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER AS $fn$
 SELECT jsonb_build_object(
 'status','unreleased_execution_finance_source','candidateReady',false,
 'sourceAuthorityReleased',false,'clearanceType',p_type,
 'worldId',1,'airlineId',p_airline,'scheduleId',p_schedule,
 'scheduleVersion',p_version,'gameDate',p_game_date,
 'readOnly',true,'flightActivated',false,'movementRecorded',false,
 'bookingsCreated',false,'ledgerPosted',false)
$fn$;

-- The actual source-specific source-reader + publisher are loaded
-- UNMODIFIED in the next workflow step.
REVOKE ALL ON airlinerra_game.section9_operational_certification_events_v1
 FROM PUBLIC,anon,authenticated,service_role;
REVOKE ALL ON airlinerra_game.section9_schedule_operational_certifications_v1
 FROM PUBLIC,anon,authenticated,service_role;
