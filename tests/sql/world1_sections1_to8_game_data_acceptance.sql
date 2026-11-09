-- World 1 Sections 1-8: post-closure NON-MUTATING acceptance.
-- This suite deliberately distinguishes game data from real-world evidence
-- and deliberately keeps the world, licences and flight execution closed.
BEGIN;
DO $test$
DECLARE n integer;exceptions integer;
BEGIN
 SELECT count(*) INTO n FROM airlinerra_game.airport_data_master_categories
 WHERE category_number IN (1,2,3,4,5,6,7)
  AND status='game_complete_estimated' AND updated_on<=CURRENT_DATE;
 IF n<>7 THEN RAISE EXCEPTION 'Wrong game-complete sections: %',n;END IF;
 IF (SELECT status FROM airlinerra_game.airport_data_master_categories
     WHERE category_number=8)<>'partially_populated'
 THEN RAISE EXCEPTION 'Section8 owner pricing review was bypassed';END IF;
 IF (SELECT status FROM airlinerra_game.airport_data_master_categories
     WHERE category_number=9)<>'partially_populated'
 OR (SELECT status FROM airlinerra_game.airport_data_master_categories
     WHERE category_number=10)<>'partially_populated'
 THEN RAISE EXCEPTION 'Unfinished operations or verification wrongly closed';END IF;
 IF (SELECT count(*) FROM airlinerra_game.world1_game_data_section_acceptance_v1
   WHERE world_id=1 AND source_verified_complete=false
   AND live_operations_certified=false)<>8
 THEN RAISE EXCEPTION 'No evidence/operational certification distinction';END IF;
 IF has_table_privilege('anon',
  'airlinerra_game.world1_game_data_section_acceptance_v1','SELECT')
 OR has_table_privilege('authenticated',
  'airlinerra_game.world1_game_data_section_acceptance_v1','INSERT')
 THEN RAISE EXCEPTION 'Game data acceptance audit is publicly editable';END IF;

 IF (SELECT count(*) FROM airlinerra_game.airport_reference_profiles
  WHERE world_id=1 AND game_official_name IS NOT NULL
   AND game_municipality IS NOT NULL AND timezone_iana IS NOT NULL
   AND game_elevation_ft IS NOT NULL AND game_display_code IS NOT NULL)<>3141
 THEN RAISE EXCEPTION 'Section1 data regressed';END IF;
 IF (SELECT assigned_to_six_tiers
   FROM airlinerra_game.airport_classification_completion_progress)<>3141
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_classification_open_review_queue)
 THEN RAISE EXCEPTION 'Section2 category mapping regressed';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_runway_inventory
   WHERE world_id=1 AND length_m>0 AND width_m>0)<>4022
 OR (SELECT count(*) FROM airlinerra_game.airport_fictional_runway_design
   WHERE world_id=1 AND airport_key='FICTIONAL:fictional:RS:LYAL')<>1
 THEN RAISE EXCEPTION 'Section3 physical runway data regressed';END IF;
 IF (SELECT coalesce(sum(game_complete),0)
   FROM airlinerra_game.section4_game_facilities_completion_v1)<>3141
 THEN RAISE EXCEPTION 'Section4 existing game facilities incomplete';END IF;
 IF (SELECT game_defaults_not_source_checked
   FROM airlinerra_game.section5_airport_simplified_game_progress_v1)<>0
 OR (SELECT total_airports
   FROM airlinerra_game.section5_airport_simplified_game_progress_v1)<>3141
 OR (SELECT missing_game_noise_chapter
   FROM airlinerra_game.section5_aircraft_game_noise_chapter_status_v2)<>0
 THEN RAISE EXCEPTION 'Section5 game rules regressed';END IF;
 IF (SELECT count(*) FROM airlinerra_game.section6_airport_slot_capacity_v1
    WHERE world_id=1)<>3141
 THEN RAISE EXCEPTION 'Section6 model missing';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_daily_traffic_pool_baselines
    WHERE world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.airport_seasonal_demand_profiles
    WHERE world_id=1)<>3141
 OR (SELECT count(*) FROM airlinerra_game.section7_origin_priority_allocation_summary
    WHERE world_id=1 AND
      expected_top_destinations=generated_top_destinations)<>3141
 THEN RAISE EXCEPTION 'Section7 baseline/priorities regressed';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_game_fees
    WHERE world_id=1 AND landing_fee_usd>0
     AND parking_per_day_usd>=0 AND departing_passenger_fee_usd>=0)<>3141
 THEN RAISE EXCEPTION 'Section8 preapproval price catalogue regressed';END IF;

 -- These source-uncertainty counts must NOT be rewritten as verified facts.
 IF (SELECT independently_final_approved
   FROM airlinerra_game.airport_classification_completion_progress)<>0
 THEN RAISE EXCEPTION 'Owner final category approval misrepresented';END IF;
 IF (SELECT count(*) FROM airlinerra_game.airport_runway_inventory
   WHERE world_id=1 AND operational_status='unknown')<4000
 THEN RAISE EXCEPTION 'Historical runway source operating status silently promoted';END IF;
 IF (SELECT airline_sim_not_found
   FROM airlinerra_game.section5_airport_simplified_game_progress_v1)<>146
 THEN RAISE EXCEPTION 'Unmatched AirlineSim cases were mislabeled';END IF;
 IF (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 OR EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1
    WHERE world_id=1 AND status='active')
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_game_permission_applications_v1)
 THEN RAISE EXCEPTION 'Unwanted commercial activity';END IF;
 RAISE NOTICE 'PASS: 7 airport sections game-data complete, Section 8 awaits pricing; aviation research and flight engine remain separate';
END $test$;
ROLLBACK;