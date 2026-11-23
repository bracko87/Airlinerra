-- Group 2 independent evidence/readiness workflow. This is NOT airport admission,
-- operational permission, legal authority, or a World 1 roster modification.
-- Private source review only. All existing game estimates remain clearly estimates.

CREATE VIEW airlinerra_game.airport_group2_required_reviews_v1
 WITH (security_invoker=true) AS
SELECT g.airport_key,
 v.gate_code,
 'general'::text AS service_type
FROM airlinerra_game.airport_group2_game_profiles_v1 g
CROSS JOIN (VALUES
 ('identity_and_location'),
 ('current_paved_runway'),
 ('civilian_access'),
 ('aircraft_and_facilities'),
 ('operating_restrictions')
) v(gate_code)
UNION ALL
SELECT g.airport_key,'commercial_service_permission'::text,'passenger'::text
FROM airlinerra_game.airport_group2_game_profiles_v1 g
WHERE g.game_traffic_type IN('Passenger','Both')
UNION ALL
SELECT g.airport_key,'commercial_service_permission'::text,'cargo'::text
FROM airlinerra_game.airport_group2_game_profiles_v1 g
WHERE g.game_traffic_type IN('Cargo','Both');
REVOKE ALL ON airlinerra_game.airport_group2_required_reviews_v1 FROM PUBLIC,anon,authenticated;

CREATE TABLE airlinerra_game.airport_group2_review_evidence_events_v1 (
 evidence_event_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 airport_key text NOT NULL REFERENCES airlinerra_game.airport_group2_game_profiles_v1(airport_key),
 gate_code text NOT NULL CHECK (gate_code IN (
 'identity_and_location','current_paved_runway','civilian_access',
 'aircraft_and_facilities','operating_restrictions',
 'commercial_service_permission')),
 service_type text NOT NULL CHECK (service_type IN('general','passenger','cargo')),
 decision text NOT NULL CHECK(decision IN('verified','rejected','withdrawn')),
 source_url text NOT NULL CHECK(source_url ~ '^https://[^[:space:]]{8,}$'
    AND length(source_url)<=2048),
 source_effective_on date NOT NULL,
 reviewed_on date NOT NULL,
 reviewer_reference text NOT NULL CHECK(length(btrim(reviewer_reference)) BETWEEN 8 AND 200),
 evidence_note text NOT NULL CHECK(length(btrim(evidence_note)) BETWEEN 35 AND 3000),
 evidence_document_sha256 text CHECK(
   evidence_document_sha256 IS NULL OR evidence_document_sha256 ~ '^[0-9a-f]{64}$'),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK (source_effective_on <= reviewed_on),
 CHECK (reviewed_on <= (now() AT TIME ZONE 'UTC')::date),
 CHECK (source_effective_on >= DATE '2020-01-01')
);
CREATE INDEX airport_group2_evidence_latest_idx
 ON airlinerra_game.airport_group2_review_evidence_events_v1(
 airport_key,gate_code,service_type,evidence_event_id DESC);
ALTER TABLE airlinerra_game.airport_group2_review_evidence_events_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_review_evidence_events_v1
 FROM PUBLIC,anon,authenticated;

CREATE FUNCTION airlinerra_game.group2_evidence_insert_gate_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path=airlinerra_game,pg_catalog
AS $function$
BEGIN
 IF NOT EXISTS (
  SELECT 1 FROM airlinerra_game.airport_group2_required_reviews_v1 q
  WHERE q.airport_key=NEW.airport_key AND q.gate_code=NEW.gate_code
    AND q.service_type=NEW.service_type
 ) THEN RAISE EXCEPTION USING ERRCODE='22023',
    MESSAGE='GROUP2_EVIDENCE_GATE_NOT_APPLICABLE';END IF;
 IF NEW.decision='verified' AND NEW.reviewer_reference ILIKE '%automated%' THEN
  RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='GROUP2_INDEPENDENT_REVIEWER_REQUIRED';END IF;
 RETURN NEW;
END $function$;
CREATE TRIGGER group2_evidence_validate_gate_before_insert
 BEFORE INSERT ON airlinerra_game.airport_group2_review_evidence_events_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.group2_evidence_insert_gate_v1();

CREATE FUNCTION airlinerra_game.group2_evidence_append_only_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER
SET search_path=airlinerra_game,pg_catalog
AS $function$
BEGIN
 RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='GROUP2_EVIDENCE_APPEND_ONLY_USE_NEW_REVIEW_EVENT';
END $function$;
CREATE TRIGGER group2_evidence_append_only
 BEFORE UPDATE OR DELETE ON airlinerra_game.airport_group2_review_evidence_events_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();
REVOKE ALL ON FUNCTION airlinerra_game.group2_evidence_insert_gate_v1()
 FROM PUBLIC,anon,authenticated;
REVOKE ALL ON FUNCTION airlinerra_game.group2_evidence_append_only_v1()
 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.airport_group2_review_evidence_events_v1 IS
 'Private, append-only independent evidence for Group2 airport review. All 6 gates (commercial rights separately for cargo/passenger) must pass; no events are fabricated from owner game pre-approval or historic source flags. No direct player read/write.';

CREATE VIEW airlinerra_game.airport_group2_source_research_queue_v1
 WITH (security_invoker=true) AS
WITH base AS (
 SELECT g.airport_key,g.game_airport_name,g.country_iso,g.owner_category,
  g.game_traffic_type,g.review_sequence,
  g.detailed_runway_observation_count,
  g.runway_width_game_basis,g.source_municipality,
  a.review_status AS historical_access_review,
  a.civilian_access_status AS historical_civilian_access,
  a.commercial_permission_status AS historical_commercial_access,
  a.evidence_url AS historical_access_source,
  cv.faa_match_status,cv.faa_reported_use,
  cv.faa_reported_airport_status,cv.faa_source_url,
  cv.faa_source_date,cv.operator_evidence_url,
  cv.aircraft_compatibility_verification,
  cv.game_admission_status AS old_commercial_game_status,
  ph.phase5_review_status,ph.notam_weather_status,
  (a.commercial_permission_status='PROHIBITED_BY_AIP'
     OR a.review_status='AIP_MILITARY_COMMERCIAL_AVIATION_PROHIBITED'
  ) IS TRUE AS documented_commercial_prohibition,
  CASE
   WHEN a.commercial_permission_status='PROHIBITED_BY_AIP'
     OR a.review_status='AIP_MILITARY_COMMERCIAL_AVIATION_PROHIBITED'
     THEN 0
   WHEN g.detailed_runway_observation_count=0
     OR g.runway_width_game_basis='CATEGORY_MEDIAN_GAME_WIDTH_ESTIMATE'
     THEN 1
   WHEN a.airport_key IS NULL THEN 2
   WHEN cv.airport_key IS NOT NULL THEN 3
   ELSE 4 END AS priority_tier
 FROM airlinerra_game.airport_group2_game_profiles_v1 g
 LEFT JOIN airlinerra.airport_access_reviews a USING(airport_key)
 LEFT JOIN airlinerra.airport_commercial_verification cv USING(airport_key)
 LEFT JOIN airlinerra.airport_expansion_phase5_gate_reviews ph USING(airport_key)
), ranked AS (
 SELECT b.*,row_number() OVER(
  ORDER BY priority_tier, review_sequence,airport_key
 ) AS cohort_review_order
 FROM base b
)
SELECT ranked.*,
 ((cohort_review_order-1)/50+1)::integer AS review_batch_50,
 CASE
 WHEN documented_commercial_prohibition THEN
   'SOURCE_PROHIBITION_HOLD_REVIEW_AIP_AND_DO_NOT_RELEASE'
 WHEN priority_tier=1 THEN
   'RECONCILE_CURRENT_PHYSICAL_RUNWAY_WIDTH_DISTANCE_AND_AIRCRAFT'
 WHEN priority_tier=2 THEN
   'OBTAIN_INDEPENDENT_CIVILIAN_ACCESS_AND_COMMERCIAL_EVIDENCE'
 WHEN priority_tier=3 THEN
   'REUSE_FAA_SOURCE_AND_VERIFY_COMMERCIAL_SERVICE_RESTRICTIONS'
 ELSE
   'VERIFY_OPERATOR_CURRENT_RUNWAY_AND_COMMERCIAL_ACCESS'
 END AS next_research_action
FROM ranked;
REVOKE ALL ON airlinerra_game.airport_group2_source_research_queue_v1
 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_evidence_latest_v1
 WITH (security_invoker=true) AS
SELECT DISTINCT ON(airport_key,gate_code,service_type)
 airport_key,gate_code,service_type,decision,evidence_event_id,
 source_url,reviewer_reference,reviewed_on,source_effective_on,recorded_at
FROM airlinerra_game.airport_group2_review_evidence_events_v1
ORDER BY airport_key,gate_code,service_type,evidence_event_id DESC;
REVOKE ALL ON airlinerra_game.airport_group2_evidence_latest_v1 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_admission_readiness_v1
 WITH (security_invoker=true) AS
WITH checks AS (
 SELECT r.airport_key,count(*)::integer AS required_gate_count,
  count(*) FILTER(WHERE e.decision='verified')::integer AS verified_gate_count,
  count(*) FILTER(WHERE e.decision='rejected')::integer AS rejected_gate_count,
  array_agg(r.gate_code||':'||r.service_type ORDER BY
      r.gate_code,r.service_type)
   FILTER(WHERE e.decision IS DISTINCT FROM 'verified') AS unresolved_gates
 FROM airlinerra_game.airport_group2_required_reviews_v1 r
 LEFT JOIN airlinerra_game.airport_group2_evidence_latest_v1 e
 ON e.airport_key=r.airport_key AND e.gate_code=r.gate_code
  AND e.service_type=r.service_type
 GROUP BY r.airport_key
)
SELECT b.*,c.required_gate_count,c.verified_gate_count,c.rejected_gate_count,
 coalesce(c.unresolved_gates,ARRAY[]::text[]) AS unresolved_gates,
 CASE
 WHEN b.documented_commercial_prohibition THEN 'HARD_HOLD_DOCUMENTED_PROHIBITION'
 WHEN c.rejected_gate_count>0 THEN 'HOLD_REJECTED_EVIDENCE'
 WHEN c.required_gate_count=c.verified_gate_count THEN 'READY_FOR_SEPARATE_OWNER_RELEASE_REVIEW'
 ELSE 'EVIDENCE_INCOMPLETE_NOT_PLAYABLE' END AS readiness_status,
 (c.required_gate_count=c.verified_gate_count
   AND NOT b.documented_commercial_prohibition
   AND c.rejected_gate_count=0) AS ready_for_owner_release_review,
 false AS admitted_to_world1,
 false AS operationally_authorized,
 false AS can_activate_flights
FROM airlinerra_game.airport_group2_source_research_queue_v1 b
JOIN checks c USING(airport_key);
REVOKE ALL ON airlinerra_game.airport_group2_admission_readiness_v1
 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_research_batches_v1
 WITH (security_invoker=true) AS
SELECT review_batch_50,count(*)::integer airports,
 count(*) FILTER(WHERE priority_tier=0)::integer documented_prohibitions,
 count(*) FILTER(WHERE priority_tier=1)::integer runway_reconciliation_priority,
 count(*) FILTER(WHERE priority_tier=2)::integer missing_access_reviews,
 count(*) FILTER(WHERE priority_tier=3)::integer faa_review_available,
 count(*) FILTER(WHERE priority_tier=4)::integer other_reviews,
 count(*) FILTER(WHERE ready_for_owner_release_review)::integer ready_for_release_review,
 count(*) FILTER(WHERE can_activate_flights)::integer operationally_approved,
 count(distinct country_iso)::integer countries
FROM airlinerra_game.airport_group2_admission_readiness_v1
GROUP BY review_batch_50;
REVOKE ALL ON airlinerra_game.airport_group2_research_batches_v1
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION
 airlinerra_game.group2_verify_candidate_admission_v1(p_airport_key text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path=airlinerra_game,pg_catalog
AS $function$
DECLARE s record;
BEGIN
 IF p_airport_key IS NULL OR length(p_airport_key)>100 THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_GROUP2_CANDIDATE';END IF;
 SELECT * INTO s
 FROM airlinerra_game.airport_group2_admission_readiness_v1
 WHERE airport_key=p_airport_key;
 IF NOT FOUND THEN
  RETURN jsonb_build_object('status','not_in_group2',
   'canActivateFlights',false,'canJoinWorld1',false);END IF;
 RETURN jsonb_build_object(
  'status',s.readiness_status,'airportKey',s.airport_key,
  'ownerCategory',s.owner_category,'trafficIntent',s.game_traffic_type,
  'requiredEvidenceGates',s.required_gate_count,
  'verifiedEvidenceGates',s.verified_gate_count,
  'unresolvedEvidenceGates',to_jsonb(s.unresolved_gates),
  'documentedCommercialProhibition',s.documented_commercial_prohibition,
  'readyForSeparateOwnerReleaseReview',s.ready_for_owner_release_review,
  'reviewBatch50',s.review_batch_50,
  'canJoinWorld1',false,'canActivateFlights',false,
  'realCommercialOperatingAuthorityAsserted',false);
END $function$;
REVOKE ALL ON FUNCTION
 airlinerra_game.group2_verify_candidate_admission_v1(text)
 FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.group2_verify_candidate_admission_v1(text) IS
 'Private Group 2 preflight only, always DENIES actual World1 admission and flight activation. Independent gate completion is NOT an airport or airline licence.';

DO $assert$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_admission_readiness_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_required_reviews_v1)<>6830
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_research_batches_v1)<>23
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_admission_readiness_v1
     WHERE ready_for_owner_release_review OR can_activate_flights)<>0
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_admission_readiness_v1
     WHERE documented_commercial_prohibition)<>2
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 THEN RAISE EXCEPTION 'GROUP2_RESEARCH_GATE_OR_GROUP1_UNEXPECTED_STATE'; END IF;
END $assert$;
