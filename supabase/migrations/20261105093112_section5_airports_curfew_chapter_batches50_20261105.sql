-- World 1: dual screening queue, stable batches of 50; research-only
CREATE TABLE IF NOT EXISTS airlinerra_game.section5_airport_batch50_screen_v1 (
 world_id smallint NOT NULL,
 airport_key text NOT NULL,
 airport_code text NOT NULL,
 airport_name text NOT NULL,
 country_iso text NOT NULL,
 batch_no integer NOT NULL CHECK (batch_no >= 1),
 batch_position smallint NOT NULL CHECK (batch_position BETWEEN 1 AND 50),
 curfew_result text NOT NULL DEFAULT 'UNCONFIRMED' CHECK (curfew_result IN ('YES','NO','UNCONFIRMED')),
 curfew_rule_summary text,
 curfew_source_url text,
 curfew_checked_on date,
 chapter_result text NOT NULL DEFAULT 'UNCONFIRMED' CHECK (chapter_result IN ('YES','NO','UNCONFIRMED')),
 chapter_rule_summary text,
 chapter_source_url text,
 chapter_checked_on date,
 survey_note text NOT NULL DEFAULT 'No negative conclusion from absence of search results; further evidence required.',
 recorded_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY (world_id, airport_key),
 UNIQUE (world_id, batch_no, batch_position),
 FOREIGN KEY (world_id, airport_key) REFERENCES airlinerra_game.approved_game_airports(world_id, airport_key)
);
ALTER TABLE airlinerra_game.section5_airport_batch50_screen_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section5_airport_batch50_screen_v1 FROM PUBLIC, anon, authenticated;
WITH pending AS (
 SELECT c.world_id,c.airport_key,n.airport_code,p.display_name,p.country_iso,
 c.evidence_status,c.rule_kind_summary,c.source_url,c.source_checked_on,
 row_number() OVER (ORDER BY CASE p.provisional_category WHEN 'Mega Hub' THEN 1 WHEN 'Major Hub' THEN 2 WHEN 'Large' THEN 3 WHEN 'Medium' THEN 4 WHEN 'Regional' THEN 5 ELSE 6 END,n.airport_code,c.airport_key) rn
 FROM airlinerra_game.section5_airport_curfew_research_audit_v2 c
 JOIN airlinerra_game.section5_airport_icao_chapter_policy_v2 n USING(world_id,airport_key)
 JOIN airlinerra_game.airport_reference_profiles p USING(world_id,airport_key)
 WHERE c.evidence_status='NOT_INDIVIDUALLY_VERIFIED' OR n.research_status='NOT_INDIVIDUALLY_VERIFIED'
)
INSERT INTO airlinerra_game.section5_airport_batch50_screen_v1
(world_id,airport_key,airport_code,airport_name,country_iso,batch_no,batch_position,curfew_result,curfew_rule_summary,curfew_source_url,curfew_checked_on)
SELECT world_id,airport_key,airport_code,display_name,country_iso,
 ((rn-1)/50+1)::integer,((rn-1)%50+1)::smallint,
 CASE WHEN evidence_status='DOCUMENTED_RESTRICTION' THEN 'YES'
 WHEN evidence_status='SOURCE_REVIEW_NO_RESTRICTION_FOUND' THEN 'NO'
 ELSE 'UNCONFIRMED' END,
 CASE WHEN evidence_status='NOT_INDIVIDUALLY_VERIFIED' THEN NULL ELSE rule_kind_summary END,
 source_url,source_checked_on
FROM pending ON CONFLICT (world_id,airport_key) DO NOTHING;
CREATE OR REPLACE VIEW airlinerra_game.section5_airport_batch50_progress_v1 WITH (security_invoker=true) AS
SELECT batch_no,count(*)::integer airports,
count(*) FILTER(WHERE curfew_result='YES')::integer curfew_yes,
count(*) FILTER(WHERE curfew_result='NO')::integer curfew_no,
count(*) FILTER(WHERE curfew_result='UNCONFIRMED')::integer curfew_unconfirmed,
count(*) FILTER(WHERE chapter_result='YES')::integer chapter_yes,
count(*) FILTER(WHERE chapter_result='NO')::integer chapter_no,
count(*) FILTER(WHERE chapter_result='UNCONFIRMED')::integer chapter_unconfirmed,
count(*) FILTER(WHERE curfew_result<>'UNCONFIRMED' AND chapter_result<>'UNCONFIRMED')::integer both_screened,
CASE WHEN count(*) FILTER(WHERE curfew_result='UNCONFIRMED' OR chapter_result='UNCONFIRMED')=0
THEN 'COMPLETE' ELSE 'IN_PROGRESS' END batch_status
FROM airlinerra_game.section5_airport_batch50_screen_v1 GROUP BY batch_no;
REVOKE ALL ON airlinerra_game.section5_airport_batch50_progress_v1 FROM PUBLIC,anon,authenticated;
