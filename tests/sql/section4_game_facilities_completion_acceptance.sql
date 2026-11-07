-- Section 4 GAME completion acceptance, non-mutating.
-- Field-level official aviation verification is explicitly NOT asserted.
DO $checks$
DECLARE
 total_airports integer;
 completed integer;
 gaps integer;
 split_errors integer;
 original_gate_gaps integer;
 original_cargo_flags integer;
 preserved_sources integer;
 original_source_count integer;
BEGIN
 SELECT coalesce(sum(airports),0),coalesce(sum(game_complete),0),
  coalesce(sum(missing_required_game_fields),0),coalesce(sum(stand_split_errors),0)
 INTO total_airports,completed,gaps,split_errors
 FROM airlinerra_game.section4_game_facilities_completion_v1;
 IF total_airports<>3141 OR completed<>3141 OR gaps<>0 OR split_errors<>0
 THEN RAISE EXCEPTION 'Section4 game completion incomplete: total %,complete %,gaps %,stand conflicts %',
  total_airports,completed,gaps,split_errors; END IF;

 SELECT count(*) FILTER (WHERE (missing_before->>'passenger_gate_count')::boolean),
        count(*) FILTER (WHERE (missing_before->>'cargo_priority')::boolean),
        count(*) FILTER (WHERE baseline_before->>'source_url' IS NOT NULL)
 INTO original_gate_gaps,original_cargo_flags,original_source_count
 FROM airlinerra_game.section4_facility_game_completion_audit_v1
 WHERE world_id=1;
 IF original_gate_gaps<>89 OR original_cargo_flags<>16 OR original_source_count<>10
 THEN RAISE EXCEPTION 'Original facility gap snapshot mismatch'; END IF;

 SELECT count(*) INTO preserved_sources
 FROM airlinerra_game.section4_facility_game_completion_audit_v1 a
 JOIN airlinerra_game.airport_facilities f USING(world_id,airport_key)
 WHERE a.world_id=1
 AND (
   f.source_url IS DISTINCT FROM a.baseline_before->>'source_url'
   OR f.terminal_count IS DISTINCT FROM (a.baseline_before->>'terminal_count')::integer
   OR f.game_capacity_basis IS DISTINCT FROM a.baseline_before->>'game_capacity_basis'
   OR (a.baseline_before->>'cargo_priority') IS NOT NULL AND
     f.cargo_priority IS DISTINCT FROM (a.baseline_before->>'cargo_priority')::boolean
 );
 IF preserved_sources<>0
 THEN RAISE EXCEPTION 'Pre-existing sourced/user-approved facility values were changed'; END IF;

 IF EXISTS (SELECT 1 FROM airlinerra_game.airport_facilities f WHERE f.world_id=1
   AND (f.passenger_gate_count>f.contact_stand_count OR
   f.jet_bridge_count>f.contact_stand_count OR f.apron_area_m2<0
   OR f.terminal_count<0 OR f.aircraft_stand_count<0))
 THEN RAISE EXCEPTION 'Inconsistent facility geometry'; END IF;
 IF (SELECT status FROM airlinerra_game.airport_data_master_categories
  WHERE category_number=4 AND world_id=1)<>'game_complete_estimated'
 THEN RAISE EXCEPTION 'Section 4 status is not game complete'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_data_work_queue
  WHERE world_id=1 AND data_area='facilities_gates'
   AND research_status='game_complete_estimated')<>3141
 THEN RAISE EXCEPTION 'Section 4 airport completion queue inconsistent'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.section4_tier_facility_game_defaults_v1
  WHERE world_id=1)<>6
 THEN RAISE EXCEPTION 'Six category defaults are not present'; END IF;
 RAISE NOTICE 'SECTION 4 GAME COMPLETE: 3141/3141 airports; zero mandatory game-field gaps; 89 same-tier gate/stand averages; 16 cargo flags; original facts preserved; NOT source verified.';
END $checks$;