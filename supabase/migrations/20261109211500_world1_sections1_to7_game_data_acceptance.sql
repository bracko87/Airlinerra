-- World 1 airport GAME-DATA completion, distinct from independent
-- aviation source verification and from live flight/settlement release.
-- This migration does not grant licences, approve official airport facts,
-- mutate any airport/aircraft/fee values, or enable live flight operations.

CREATE TABLE IF NOT EXISTS airlinerra_game.world1_game_data_section_acceptance_v1 (
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 category_number smallint NOT NULL REFERENCES
  airlinerra_game.airport_data_master_categories(category_number),
 game_data_result text NOT NULL CHECK(game_data_result IN (
  'game_complete_estimated','awaiting_owner_price_approval')),
 airport_count integer NOT NULL CHECK(airport_count=3141),
 source_verified_complete boolean NOT NULL DEFAULT false
  CHECK(source_verified_complete=false),
 live_operations_certified boolean NOT NULL DEFAULT false
  CHECK(live_operations_certified=false),
 evidence jsonb NOT NULL,
 outstanding_boundary text NOT NULL,
 accepted_on date NOT NULL DEFAULT CURRENT_DATE,
 checked_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 PRIMARY KEY (world_id,category_number)
);
ALTER TABLE airlinerra_game.world1_game_data_section_acceptance_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.world1_game_data_section_acceptance_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.world1_game_data_section_acceptance_v1 IS
 'Readiness of existing World 1 GAME data only; source fact-verification and live flight operations are separate and NOT approved by this table.';

DO $checks$
DECLARE approved integer; observed integer;
BEGIN
 IF (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'WORLD1_DATA_CLOSURE_REQUIRES_PLANNED_WORLD';END IF;
 SELECT count(*) INTO approved FROM airlinerra_game.approved_game_airports
 WHERE world_id=1;
 IF approved<>3141 THEN RAISE EXCEPTION
  'WORLD1_APPROVED_AIRPORT_ROSTER_CHANGED: %',approved;END IF;

 -- 1: Game identity and geography, preserving source/fictional status.
 SELECT count(*) INTO observed
 FROM airlinerra_game.airport_reference_profiles p
 WHERE p.world_id=1 AND p.game_official_name IS NOT NULL
 AND btrim(p.game_official_name)<>'' AND p.game_municipality IS NOT NULL
 AND btrim(p.game_municipality)<>'' AND p.game_display_code IS NOT NULL
 AND p.country_iso ~ '^[A-Z]{2}$'
 AND p.timezone_iana IS NOT NULL AND p.game_elevation_ft IS NOT NULL
 AND (p.airport_kind='fictional'
    OR (p.airport_kind='real' AND p.latitude_deg IS NOT NULL
      AND p.longitude_deg IS NOT NULL));
 IF observed<>approved
  OR (SELECT airports_with_unresolved_research
      FROM airlinerra_game.airport_code_audit_progress)<>0
  OR (SELECT game_names_missing
      FROM airlinerra_game.airport_identity_name_progress)<>0
 THEN RAISE EXCEPTION 'SECTION1_GAME_IDENTITY_INCOMPLETE: %',observed;END IF;

 -- 2: Existing owner-modified six-tier game mapping. Do not write to
 -- approved_category / category_approved_on or claim source sign-off.
 SELECT count(*) INTO observed
 FROM airlinerra_game.airport_reference_profiles p
 WHERE p.world_id=1
 AND p.provisional_category IN
 ('Local','Regional','Medium','Large','Major Hub','Mega Hub');
 IF observed<>approved OR EXISTS(
  SELECT 1 FROM airlinerra_game.airport_classification_open_review_queue
 ) OR EXISTS(
  SELECT 1 FROM airlinerra_game.airport_game_fees f
  JOIN airlinerra_game.airport_reference_profiles p
   USING(world_id,airport_key)
  WHERE f.world_id=1 AND f.category IS DISTINCT FROM p.provisional_category
 ) THEN RAISE EXCEPTION 'SECTION2_GAME_CATEGORY_INCONSISTENT: %',observed;END IF;

 -- 3: All REAL airports have source-reported physical runway geometry.
 -- The one FICTIONAL approved airport has owner-designed GAME runway
 -- separate from official/source-runway inventory.
 SELECT count(DISTINCT p.airport_key) INTO observed
 FROM airlinerra_game.airport_reference_profiles p
 JOIN airlinerra_game.airport_runway_inventory r USING(world_id,airport_key)
 WHERE p.world_id=1 AND p.airport_kind='real'
  AND r.length_m>0 AND r.width_m>0;
 IF observed<>3140 OR
   (SELECT count(*) FROM airlinerra_game.airport_runway_inventory
     WHERE world_id=1 AND (length_m IS NULL OR width_m IS NULL
        OR length_m<=0 OR width_m<=0))<>0 OR
   (SELECT count(*) FROM airlinerra_game.airport_fictional_runway_design
     WHERE world_id=1
      AND airport_key='FICTIONAL:fictional:RS:LYAL'
      AND runway_design_length_m>0
      AND data_status='fictional_game_only')<>1
 THEN RAISE EXCEPTION 'SECTION3_RUNWAY_GAME_GEOMETRY_INCOMPLETE: %',observed;END IF;

 IF (SELECT status FROM airlinerra_game.airport_data_master_categories
     WHERE category_number=4)<>'game_complete_estimated'
 THEN RAISE EXCEPTION 'SECTION4_EXISTING_GAME_COMPLETION_MISSING';END IF;

 -- 5: User-approved simplified game Yes/No fields and all aircraft
 -- game noise chapters. Legal/NOTAM/weather/operating rights stay open.
 SELECT count(*) INTO observed
 FROM airlinerra_game.section5_airport_simplified_game_rules_v1 n
 WHERE n.world_id=1 AND n.nighttime_ban IS NOT NULL
  AND n.noise_restrictions IS NOT NULL
  AND n.source_status IS NOT NULL
  AND (n.noise_restrictions OR
       cardinality(n.permitted_noise_chapters)=0);
 IF observed<>approved OR
  (SELECT game_defaults_not_source_checked
   FROM airlinerra_game.section5_airport_simplified_game_progress_v1)<>0
  OR (SELECT missing_game_noise_chapter
   FROM airlinerra_game.section5_aircraft_game_noise_chapter_status_v2)<>0
  OR (SELECT aircraft_configuration_count
   FROM airlinerra_game.section5_aircraft_game_noise_chapter_status_v2)<>271
  THEN RAISE EXCEPTION 'SECTION5_SIMPLIFIED_GAME_RULES_INCOMPLETE: %',observed;END IF;

 -- 6: Bounded game stand/slot model for every approved airport.
 SELECT count(*) INTO observed
 FROM airlinerra_game.section6_airport_slot_capacity_v1 c
 WHERE c.world_id=1
  AND c.terminal_stands>=0 AND c.remote_stands>=0
  AND c.cargo_stands>=0
  AND c.terminal_per_direction_10m>=0
  AND c.remote_per_direction_10m>=0
  AND c.cargo_per_direction_10m>=0
  AND c.terminal_stands+c.remote_stands+c.cargo_stands>0;
 IF observed<>approved THEN RAISE EXCEPTION
 'SECTION6_GAME_SLOT_CAPACITY_INCOMPLETE: %',observed;END IF;

 -- 7: Distinguish complete simulated market input from actual passengers.
 SELECT count(*) INTO observed
 FROM airlinerra_game.airport_daily_traffic_pool_baselines t
 JOIN airlinerra_game.airport_seasonal_demand_profiles s
  USING(world_id,airport_key)
 JOIN airlinerra_game.section7_origin_priority_allocation_summary d
  ON d.world_id=t.world_id AND d.origin_airport_key=t.airport_key
 WHERE t.world_id=1
  AND t.avg_daily_outbound_passengers>=0
  AND t.avg_daily_outbound_cargo_tonnes>=0
  AND t.outbound_passenger_pool_min<=t.outbound_passenger_pool_max
  AND t.outbound_cargo_pool_min_tonnes<=t.outbound_cargo_pool_max_tonnes
  AND s.jan_pct IS NOT NULL AND s.feb_pct IS NOT NULL
  AND s.mar_pct IS NOT NULL AND s.apr_pct IS NOT NULL
  AND s.may_pct IS NOT NULL AND s.jun_pct IS NOT NULL
  AND s.jul_pct IS NOT NULL AND s.aug_pct IS NOT NULL
  AND s.sep_pct IS NOT NULL AND s.oct_pct IS NOT NULL
  AND s.nov_pct IS NOT NULL AND s.dec_pct IS NOT NULL
  AND d.expected_top_destinations=d.generated_top_destinations
  AND d.current_priority_budget_day>=0
  AND d.current_long_tail_reserve_day>=0;
 IF observed<>approved THEN RAISE EXCEPTION
 'SECTION7_GAME_MARKET_BASELINE_INCOMPLETE: %',observed;END IF;

 -- 8: Price entries ARE complete but remain subject to explicit
 -- owner pricing/balancing approval; do not mark economics fully closed.
 SELECT count(*) INTO observed
 FROM airlinerra_game.airport_game_fees f
 JOIN airlinerra_game.airport_reference_profiles p
  USING(world_id,airport_key)
 WHERE f.world_id=1 AND
 f.category=p.provisional_category
 AND f.landing_fee_usd>0 AND f.parking_per_day_usd>=0
 AND f.departing_passenger_fee_usd>=0
 AND f.base_landing_fee_usd IS NOT NULL
 AND f.base_parking_per_day_usd IS NOT NULL
 AND f.base_departing_passenger_fee_usd IS NOT NULL;
 IF observed<>approved THEN RAISE EXCEPTION
 'SECTION8_PRICE_CATALOG_INCOMPLETE: %',observed;END IF;
END $checks$;

-- Persist what was accepted; distinguish research and operational release.
INSERT INTO airlinerra_game.world1_game_data_section_acceptance_v1
(world_id,category_number,game_data_result,airport_count,evidence,outstanding_boundary,accepted_on)
SELECT 1, entry.section_id, entry.result,3141,entry.metrics,entry.remaining,
 DATE '2026-11-09'
FROM (VALUES
 (1,'game_complete_estimated',
  '{"gameNames":3141,"gameMunicipalities":3141,"codeUnresolved":0,"gameTimezoneRecords":3141,"oneFictionalAirportExcludedFromPhysicalCoordinateRequirement":true}'::jsonb,
  'Official name and municipality verification, authority codes and timezones remain separate source research. No fabricated ICAO/IATA/GPS identities.'),
 (2,'game_complete_estimated',
  '{"sixTierAssignments":3141,"openConsistencyExceptions":0,"ownerCaseDecisionsPreserved":true,"formalIndividualFinalApprovals":0}'::jsonb,
  'Existing owner choices remain the GAME categories; individually final/authority-supported categories are not claimed.'),
 (3,'game_complete_estimated',
  '{"realAirportsWithRunwayGeometry":3140,"physicalRunwayRows":4022,"fictionalAleksandrovoDesignedSeparately":true}'::jsonb,
  'Runway operational status, closures, identifiers, official instrument data and source confirmations remain pending. Physical dimensions are not legal clearance.'),
 (4,'game_complete_estimated',
  '{"gameFacilityProfiles":3141,"existingClosureDate":"2026-11-07"}'::jsonb,
  'Previous Section 4 game completion preserved unchanged; true physical facility source verification remains open.'),
 (5,'game_complete_estimated',
  '{"simplifiedNightNoiseAirports":3141,"aircraftGameNoiseChapters":271,"airlinesimNotFoundFallbackAirports":146}'::jsonb,
  'Simplified game settings only; source-backed airport hard restrictions, legal operations, NOTAM and weather enforcement remain required before flights.'),
 (6,'game_complete_estimated',
  '{"airportStandSlotCapacityModels":3141,"rollbackSlotSchedulingIntegrationTest":"passed","actualOperatingSlotReservations":0}'::jsonb,
  'Game capacity data and transactional draft reservations only; aircraft operation slots require actual launch and flight integration.'),
 (7,'game_complete_estimated',
  '{"airportDailyTrafficBaselines":3141,"seasonalProfiles":3141,"rankedOriginPriorityModels":3141}'::jsonb,
  'Game traffic baselines and priority allocations, not actual booked passengers/cargo; Section 9 handles real demand capture.'),
 (8,'awaiting_owner_price_approval',
  '{"airportGameFeeProfiles":3141,"invalidOrMissingGamePrices":0,"finalPriceBalancingApproved":false}'::jsonb,
  'All prices populated, but landing/parking/passenger fee balance still requires owner review. Actual flight ledger settlement remains Section 9.')
 ) AS entry(section_id,result,metrics,remaining)
ON CONFLICT(world_id,category_number) DO NOTHING;

UPDATE airlinerra_game.airport_data_master_categories AS m
SET status='game_complete_estimated',updated_on=DATE '2026-11-09',
 scope_summary=m.scope_summary||' | WORLD1 GAME-DATA ACCEPTANCE 2026-11-09: All 3,141 airports have complete inputs for this section under the agreed game simulation model; source evidence/authority verification remains independently open in Section 10. LIVE commercial flight operations and settlement NOT approved.'
WHERE m.world_id=1 AND m.category_number IN (1,2,3,5,6,7)
 AND m.status<>'game_complete_estimated';

UPDATE airlinerra_game.airport_data_master_categories AS m
SET status='partially_populated',updated_on=DATE '2026-11-09',
 scope_summary=m.scope_summary||' | 2026-11-09 AUDIT: All 3,141 airport landing/parking/departing-passenger game fee profiles populated with category consistency. Pricing needs final owner balancing approval. No official tariff verification or flight settlement.'
WHERE m.world_id=1 AND m.category_number=8
 AND m.status='research_pending';

DO $final$
DECLARE changed integer;
BEGIN
 SELECT count(*) INTO changed
 FROM airlinerra_game.airport_data_master_categories
 WHERE world_id=1 AND category_number IN(1,2,3,4,5,6,7)
  AND status='game_complete_estimated';
 IF changed<>7 THEN RAISE EXCEPTION
  'SECTION_1_TO_7_GAME_COMPLETION_NOT_PERSISTED: %',changed;END IF;
 IF (SELECT status FROM airlinerra_game.airport_data_master_categories
  WHERE category_number=8)<>'partially_populated'
 THEN RAISE EXCEPTION 'SECTION8_NOT_LEFT_FOR_PRICE_APPROVAL';END IF;
 IF (SELECT count(*) FROM airlinerra_game.world1_game_data_section_acceptance_v1
  WHERE world_id=1)<>8
 THEN RAISE EXCEPTION 'WORLD1_GAME_CLOSURE_AUDIT_MISSING';END IF;
 IF (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 OR EXISTS(SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1
    WHERE world_id=1 AND status='active')
 THEN RAISE EXCEPTION 'WORLD1_COMMERCIAL_RELEASE_CHANGED';END IF;
END $final$;
