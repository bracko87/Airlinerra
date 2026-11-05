-- Separate non-authoritative second-source screening, by stable 50-airport batches.
-- Distinguish published "not recorded" from an actual "no restriction" rule.
-- Never use reference-only sources to authorize real/normal flight activation.
CREATE TABLE IF NOT EXISTS airlinerra_game.section5_airport_batch50_reference_screen_v1 (
  world_id smallint NOT NULL,
  airport_key text NOT NULL,
  batch_no integer NOT NULL,
  airport_code text NOT NULL,
  source_name text NOT NULL,
  source_url text,
  reported_curfew text NOT NULL CHECK (reported_curfew IN (
    'NO_GENERAL_CURFEW_REPORTED',
    'RESTRICTION_REPORTED',
    'NOT_RECORDED',
    'CONFLICT',
    'SOURCE_UNAVAILABLE'
  )),
  reported_min_icao_chapter smallint,
  chapter_information_status text NOT NULL CHECK (chapter_information_status IN (
    'SECONDARY_CLAIM',
    'NOT_RECORDED',
    'SOURCE_UNAVAILABLE'
  )),
  source_notes text,
  evidence_quality text NOT NULL CHECK (evidence_quality IN (
    'SECONDARY_ONLY',
    'CONFLICT_WITH_OFFICIAL',
    'SOURCE_UNAVAILABLE'
  )),
  reviewed_on date NOT NULL DEFAULT CURRENT_DATE,
  game_enforcement_eligible boolean NOT NULL DEFAULT false,
  PRIMARY KEY (world_id, airport_key),
  FOREIGN KEY (world_id, airport_key) REFERENCES
    airlinerra_game.section5_airport_batch50_screen_v1(world_id, airport_key)
);
ALTER TABLE airlinerra_game.section5_airport_batch50_reference_screen_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section5_airport_batch50_reference_screen_v1
  FROM PUBLIC, anon, authenticated;
COMMENT ON TABLE airlinerra_game.section5_airport_batch50_reference_screen_v1 IS
'Individual public third-party airport-reference screening by 50-airport batch. Source is community-maintained and cannot authorize live operations. Not recorded is NOT NO. Conflicts require primary source review. AirlineSim bulk access not used.';

CREATE OR REPLACE VIEW airlinerra_game.section5_airport_batch50_pass_progress_v1
  WITH (security_invoker=true) AS
SELECT
  b.batch_no,
  count(*)::integer AS airport_count,
  count(ref.airport_key)::integer AS external_reference_reviewed,
  count(*) FILTER (WHERE ref.reported_curfew='SOURCE_UNAVAILABLE')::integer AS reference_access_failures,
  count(*) FILTER (WHERE ref.reported_curfew='NOT_RECORDED')::integer AS reference_curfew_not_recorded,
  count(*) FILTER (WHERE ref.chapter_information_status='NOT_RECORDED')::integer AS reference_chapter_not_recorded,
  count(*) FILTER (WHERE ref.reported_curfew='CONFLICT')::integer AS reference_conflicts,
  count(*) FILTER (WHERE b.curfew_result='UNCONFIRMED')::integer AS curfews_unconfirmed,
  count(*) FILTER (WHERE b.chapter_result='UNCONFIRMED')::integer AS chapters_unconfirmed,
  CASE WHEN count(*)=count(ref.airport_key)
    THEN 'SCREENING_PASS_COMPLETE'
    ELSE 'SCREENING_PASS_IN_PROGRESS'
  END AS screening_pass_state,
  CASE WHEN count(*) FILTER (WHERE b.curfew_result='UNCONFIRMED' OR b.chapter_result='UNCONFIRMED')=0
    THEN 'ALL_RESEARCH_FIELDS_RESOLVED'
    ELSE 'OFFICIAL_FOLLOWUP_STILL_NEEDED'
  END AS verified_research_state
FROM airlinerra_game.section5_airport_batch50_screen_v1 b
LEFT JOIN airlinerra_game.section5_airport_batch50_reference_screen_v1 ref
  USING (world_id, airport_key)
GROUP BY b.batch_no;

REVOKE ALL ON airlinerra_game.section5_airport_batch50_pass_progress_v1
  FROM PUBLIC, anon, authenticated;
