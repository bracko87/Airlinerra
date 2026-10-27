-- Airlinerra research runway facts schema; deployed 2026-10-27.
-- Supabase migrations:
--   airlinerra_private_versioned_runway_research_facts_20261027
--   airlinerra_private_runway_research_security_invoker_view_20261027
-- Archived for reproducibility. DO NOT rerun blindly: both migrations are installed.
-- Private schema only; no game catalog, original source, or public interface mutation.
CREATE TABLE airlinerra.runway_source_versions (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 runway_pair text NOT NULL CHECK (runway_pair ~ '^[0-9]{2}[LRC]?/[0-9]{2}[LRC]?$'),
 evidence_id bigint NOT NULL REFERENCES airlinerra.airport_evidence(id),
 source_authority text NOT NULL,
 source_url text NOT NULL,
 source_effective_date date,
 observed_on date NOT NULL,
 validation_status text NOT NULL DEFAULT 'PRIMARY_SOURCE_VALIDATED_RESEARCH_ONLY'
  CHECK (validation_status='PRIMARY_SOURCE_VALIDATED_RESEARCH_ONLY'),
 created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(evidence_id,runway_pair)
);
CREATE INDEX runway_source_versions_airport
 ON airlinerra.runway_source_versions(airport_key,runway_pair,source_effective_date DESC);

CREATE TABLE airlinerra.runway_physical_facts (
 source_version_id bigint PRIMARY KEY REFERENCES airlinerra.runway_source_versions(id),
 physical_length_m numeric(8,1) NOT NULL CHECK(physical_length_m>0),
 width_m numeric(7,1) CHECK(width_m>0),
 raw_surface text NOT NULL,
 normalized_surface text NOT NULL CHECK(normalized_surface IN (
  'ASPHALT','CONCRETE','MIXED_VERIFIED','PAVED_UNSPECIFIED',
  'MACADAM_UNRESOLVED','UNKNOWN','NON_PAVED')),
 material_verification text NOT NULL CHECK(material_verification IN('VERIFIED','UNVERIFIED')),
 runway_operational_status text NOT NULL DEFAULT 'UNVERIFIED'
  CHECK(runway_operational_status IN('OPEN','RESTRICTED','CLOSED','UNVERIFIED')),
 original_registry_length_m numeric(8,1),
 caveat text NOT NULL DEFAULT '',
 CHECK(material_verification <> 'VERIFIED'
       OR normalized_surface IN('ASPHALT','CONCRETE','MIXED_VERIFIED'))
);

CREATE TABLE airlinerra.runway_direction_facts (
 source_version_id bigint NOT NULL REFERENCES airlinerra.runway_physical_facts(source_version_id),
 direction_code text NOT NULL CHECK(direction_code ~ '^[0-9]{2}[LRC]?$'),
 tora_m numeric(8,1) CHECK(tora_m>=0),
 toda_m numeric(8,1) CHECK(toda_m>=0),
 asda_m numeric(8,1) CHECK(asda_m>=0),
 lda_m numeric(8,1) CHECK(lda_m>=0),
 clearway_m numeric(8,1) CHECK(clearway_m>=0),
 stopway_m numeric(8,1) CHECK(stopway_m>=0),
 direction_note text NOT NULL DEFAULT '',
 PRIMARY KEY(source_version_id,direction_code),
 CHECK(toda_m IS NULL OR tora_m IS NULL OR toda_m>=tora_m),
 CHECK(asda_m IS NULL OR tora_m IS NULL OR asda_m>=tora_m)
);

CREATE TABLE airlinerra.runway_permission_facts (
 source_version_id bigint NOT NULL REFERENCES airlinerra.runway_source_versions(id),
 operation_type text NOT NULL CHECK(operation_type IN(
  'SCHEDULED_PASSENGER','CHARTER_PASSENGER','CARGO','CIVIL_GENERAL','MILITARY')),
 permission_state text NOT NULL DEFAULT 'UNVERIFIED'
  CHECK(permission_state IN('UNVERIFIED','PROHIBITED','RESTRICTED',
                            'PERMISSION_REQUIRED','CIVIL_PUBLIC_ACCESS')),
 permission_note text NOT NULL DEFAULT '',
 PRIMARY KEY(source_version_id,operation_type)
);

ALTER TABLE airlinerra.runway_source_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra.runway_physical_facts ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra.runway_direction_facts ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra.runway_permission_facts ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.runway_source_versions,
 airlinerra.runway_physical_facts,airlinerra.runway_direction_facts,
 airlinerra.runway_permission_facts FROM PUBLIC,anon,authenticated;
REVOKE ALL ON SEQUENCE airlinerra.runway_source_versions_id_seq
 FROM PUBLIC,anon,authenticated;

-- Applied in second migration to permit independent view-versioning.
CREATE VIEW airlinerra.runway_research_facts WITH(security_invoker=true) AS
SELECT sv.id AS source_version_id,sv.airport_key,
 r.source_gps_code AS icao,sv.runway_pair,
 sv.source_effective_date,sv.observed_on,
 sv.source_authority,sv.source_url,sv.evidence_id,sv.validation_status,
 r.longest_qualifying_runway_m AS original_registry_longest_runway_m,
 p.physical_length_m,p.width_m,p.raw_surface,p.normalized_surface,
 p.material_verification,p.runway_operational_status,
 a.paved_runway_status AS existing_airport_review_material_status,
 a.civilian_access_status,a.commercial_permission_status,a.game_admission_status,
 p.caveat
FROM airlinerra.runway_source_versions sv
JOIN airlinerra.runway_physical_facts p ON p.source_version_id=sv.id
JOIN airlinerra.airport_registry r ON r.airport_key=sv.airport_key
JOIN airlinerra.airport_access_reviews a ON a.airport_key=sv.airport_key;
REVOKE ALL ON airlinerra.runway_research_facts FROM PUBLIC,anon,authenticated;

-- Deliberately no grants or RLS policies for API users.
-- The installed migration also has explanatory PostgreSQL table/view comments.
