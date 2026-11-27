-- REVIEW ONLY; install in disposable database, not production.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_facilities_v1 (
 world_id smallint NOT NULL CHECK(world_id=1),
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 admission_scope text NOT NULL CHECK(admission_scope IN ('existing_commercial','relocation_only')),
 review_state text NOT NULL DEFAULT 'candidate' CHECK(review_state IN ('candidate','approved','suspended')),
 -- Unlimited storage: no capacity quota or occupancy admission gate.
 monthly_regional_usd numeric(14,2) CHECK(monthly_regional_usd>0),
 monthly_narrowbody_usd numeric(14,2) CHECK(monthly_narrowbody_usd>0),
 monthly_widebody_usd numeric(14,2) CHECK(monthly_widebody_usd>0),
 dismantling_allowed boolean NOT NULL DEFAULT false,
 reactivation_allowed boolean NOT NULL DEFAULT false,
 evidence_reference text,
 relocation_release_reference text,
 reviewed_at timestamptz,
 PRIMARY KEY(world_id,airport_key),
 CHECK(review_state<>'approved' OR (
 monthly_regional_usd IS NOT NULL
 AND monthly_narrowbody_usd IS NOT NULL AND monthly_widebody_usd IS NOT NULL
 AND nullif(btrim(evidence_reference),'') IS NOT NULL
 AND nullif(btrim(relocation_release_reference),'') IS NOT NULL AND reviewed_at IS NOT NULL)),
 CHECK(review_state<>'candidate' OR (NOT dismantling_allowed AND NOT reactivation_allowed))
);
ALTER TABLE airlinerra_game.aircraft_storage_facilities_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_facilities_v1 FROM PUBLIC,anon,authenticated,service_role;
INSERT INTO airlinerra_game.aircraft_storage_facilities_v1(world_id,airport_key,admission_scope)
VALUES
(1,'OURAIRPORTS:26900','existing_commercial'),
(1,'OURAIRPORTS:4073','existing_commercial'),
(1,'OURAIRPORTS:3856','existing_commercial'),
(1,'OURAIRPORTS:316427','relocation_only'),
(1,'OURAIRPORTS:2409','relocation_only'),
(1,'OURAIRPORTS:2395','relocation_only'),
(1,'OURAIRPORTS:21315','relocation_only'),
(1,'OURAIRPORTS:20507','relocation_only'),
(1,'OURAIRPORTS:20594','relocation_only');
-- Candidate records confer NO operational rights. Admission and signed
-- relocation integration must be separately reviewed and released.
COMMIT;
