-- Group2 Batch1: rollback-only source review snapshot, not independent approval.
BEGIN;
DO $accept$
DECLARE n integer; oldwidth numeric; tried boolean;
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_desk_cases_v1)<>50
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_desk_worklist_v1)<>50
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_public_source_findings_v1)<>11
 THEN RAISE EXCEPTION 'BATCH1_CASE_OR_SOURCE_COUNT_INVALID';END IF;
 IF (SELECT count(DISTINCT airport_key)
  FROM airlinerra_game.airport_group2_batch1_public_source_findings_v1)<>9
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_public_source_findings_v1
  WHERE claim_kind='runway_width')<>7
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_public_source_findings_v1
  WHERE claim_kind='commercial_aviation_restriction')<>2
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_public_source_findings_v1
  WHERE claim_kind='access_and_stand_conditions')<>2
 THEN RAISE EXCEPTION 'BATCH1_PRIMARY_SOURCE_CLAIMS_INACCURATE';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_desk_cases_v1
  WHERE priority_tier=0)<>2
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_desk_cases_v1
  WHERE priority_tier=1)<>20
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_desk_cases_v1
  WHERE priority_tier=2)<>28
 THEN RAISE EXCEPTION 'BATCH1_PRIORITIES_MISMATCH';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_source_progress_v1
  WHERE cases=50 AND existing_hard_prohibition_cases=2
   AND original_runway_gap_cases=20 AND missing_access_review_cases=28
   AND airports_with_public_source_candidates=9
   AND public_source_findings=11
   AND airports_with_runway_dimension_candidate=7
   AND cases_without_new_public_source=41
   AND independently_verified_cases=0 AND admitted_for_flights=0)<>1
 THEN RAISE EXCEPTION 'BATCH1_PROGRESS_ROLLUP_WRONG';END IF;

 IF EXISTS(SELECT 1
  FROM airlinerra_game.airport_group2_batch1_public_source_findings_v1 s
  LEFT JOIN airlinerra_game.airport_group2_batch1_desk_cases_v1 c USING(airport_key)
  WHERE c.airport_key IS NULL OR independent_review_complete OR
   permitted_for_simulation_flight OR
   source_class<>'PUBLIC_PRIMARY_SOURCE_CANDIDATE_NOT_VALIDATED')
 THEN RAISE EXCEPTION 'BATCH1_SOURCE_FINDING_FALSIFIED_OR_NOT_IN_COHORT';END IF;

 IF (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_desk_worklist_v1
  WHERE source_research_state='HARD_HOLD_EXISTING_PROHIBITION')<>2
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_desk_worklist_v1
  WHERE source_research_state='PUBLIC_SOURCE_FOUND_AWAITING_INDEPENDENT_REVIEW')<>7
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_desk_worklist_v1
  WHERE source_research_state='NEEDS_PRIMARY_SOURCE_RESEARCH')<>41
 THEN RAISE EXCEPTION 'BATCH1_SOURCE_RESEARCH_STATUS_WRONG';END IF;

 -- Source runway widths are NEW documented candidates, not silently
 -- treated as certified runway data nor applied to operational engine.
 SELECT game_runway_width_m INTO oldwidth
 FROM airlinerra_game.airport_group2_game_profiles_v1
 WHERE airport_key='OURAIRPORTS:29801';
 IF oldwidth<>36.3
 OR (SELECT observed_runway_width_m
     FROM airlinerra_game.airport_group2_batch1_public_source_findings_v1
     WHERE airport_key='OURAIRPORTS:29801' AND claim_kind='runway_width')<>30
 OR (SELECT game_runway_width_m
     FROM airlinerra_game.airport_group2_game_profiles_v1
     WHERE airport_key='OURAIRPORTS:27866')<>36.3
 OR (SELECT game_runway_width_m
     FROM airlinerra_game.airport_group2_game_profiles_v1
     WHERE airport_key='OURAIRPORTS:3403')<>36.3
 THEN RAISE EXCEPTION 'BATCH1_SOURCE_CANDIDATE_BYPASSED_CURRENT_GAME_ESTIMATE';END IF;

 IF has_table_privilege('anon',
    'airlinerra_game.airport_group2_batch1_desk_cases_v1','SELECT')
 OR has_table_privilege('authenticated',
    'airlinerra_game.airport_group2_batch1_public_source_findings_v1','INSERT')
 OR has_table_privilege('authenticated',
    'airlinerra_game.airport_group2_batch1_desk_worklist_v1','SELECT')
 THEN RAISE EXCEPTION 'BATCH1_PRIVATE_REVIEW_DATA_EXPOSED';END IF;

 tried:=false;
 BEGIN
  UPDATE airlinerra_game.airport_group2_batch1_public_source_findings_v1
  SET currency_or_freshness_warning='fake overwrite'
  WHERE airport_key='OURAIRPORTS:29801';
 EXCEPTION WHEN SQLSTATE '42501' THEN tried:=true;END;
 IF NOT tried THEN RAISE EXCEPTION 'BATCH1_SOURCE_FINDINGS_NOT_APPEND_ONLY';END IF;
 tried:=false;
 BEGIN
  DELETE FROM airlinerra_game.airport_group2_batch1_desk_cases_v1
  WHERE airport_key='OURAIRPORTS:29801';
 EXCEPTION WHEN SQLSTATE '42501' THEN tried:=true;END;
 IF NOT tried THEN RAISE EXCEPTION 'BATCH1_CASE_SNAPSHOT_MUTABLE';END IF;

 IF (SELECT count(*) FROM airlinerra_game.airport_group2_review_evidence_events_v1)<>0
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_game_profiles_v1)<>1118
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_admission_readiness_v1
   WHERE can_activate_flights OR ready_for_owner_release_review)
 OR (SELECT count(*) FROM airlinerra_game.section9_operated_flight_movements_v1)<>0
 OR (SELECT count(*) FROM airlinerra_game.airline_ledger)<>1
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'BATCH1_DESK_REVIEW_UNEXPECTED_COMMERCIAL_RELEASE';END IF;
 RAISE NOTICE 'PASS Batch1: 50 immutable desk cases, 11 sourced facts covering 9 airports (7 widths, 2 restrictions, 2 access); 41 unsourced; zero verified admission/flight changes';
END $accept$;
ROLLBACK;
