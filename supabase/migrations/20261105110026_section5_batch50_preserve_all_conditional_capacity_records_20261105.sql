-- Preserve all published airport hourly movement-capacity observations,
-- including separate seasons and runway configurations; do not collapse to one value.
CREATE OR REPLACE VIEW airlinerra_game.section5_airport_batch50_capacity_by_conditions_v1
WITH (security_invoker=true) AS
SELECT
 b.world_id,b.airport_key,b.batch_no,b.batch_position,b.airport_code,
 count(c.id)::integer AS capacity_evidence_count,
 COALESCE(
  jsonb_agg(jsonb_build_object(
   'season',c.season_label,
   'observation_kind',c.observation_kind,
   'movement_type',c.movement_type,
   'operating_condition',c.window_description,
   'movements_per_hour',c.movements_per_hour,
   'movements_per_day',c.movements_per_day,
   'coordination_level',c.coordination_level,
   'source_authority',c.source_authority,
   'source_url',c.source_url,
   'verification',c.verification,
   'reviewed_on',c.reviewed_on
  ) ORDER BY c.reviewed_on DESC NULLS LAST,c.id DESC)
  FILTER (WHERE c.id IS NOT NULL),'[]'::jsonb
 ) AS capacity_evidence
FROM airlinerra_game.section5_airport_batch50_screen_v1 b
LEFT JOIN airlinerra_game.airport_capacity_observations c
 USING (world_id,airport_key)
GROUP BY b.world_id,b.airport_key,b.batch_no,b.batch_position,b.airport_code;
REVOKE ALL ON airlinerra_game.section5_airport_batch50_capacity_by_conditions_v1
 FROM PUBLIC, anon, authenticated;
COMMENT ON VIEW airlinerra_game.section5_airport_batch50_capacity_by_conditions_v1 IS
'All capacity evidence records and runway/season operating conditions per 50-airport batch. One conditional runway maximum is not an airport-wide default hourly slot capacity.';
