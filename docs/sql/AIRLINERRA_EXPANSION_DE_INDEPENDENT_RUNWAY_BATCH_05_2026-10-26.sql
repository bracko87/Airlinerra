-- Airlinerra German expansion runway research Batch 05, 26 October 2026.
-- Research-only record; World1 3140 original airports stay active unchanged.
-- Operator 1200m physical rule is DISTINCT from any 1200m directional LDA.
-- Prerequisite: airport_expansion_independent_paved_runway_reviews from Batch01.
-- Batch05 replays exactly 8 sourced runway records; 2 source discrepancies.
CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_operator_runway_source_issues(
 batch_key text NOT NULL,airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 icao_code text NOT NULL,issue_code text NOT NULL CHECK(issue_code IN(
 'OPERATOR_PHYSICAL_LENGTH_LDA_CONTRADICTION',
 'DIRECTIONAL_LDA_BELOW_1200_AND_PHYSICAL_SOURCE_RECONCILIATION')),
 runway_pair text NOT NULL,operator_reported_physical_m numeric,
 source_landing_a_m numeric,source_landing_b_m numeric,
 historic_registry_runway_m numeric NOT NULL,
 source_url text NOT NULL,supporting_url text,explanation text NOT NULL,next_step text NOT NULL,
 case_status text NOT NULL DEFAULT 'SOURCE_RECONCILIATION_HOLD'
 CHECK(case_status='SOURCE_RECONCILIATION_HOLD'),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED'
 CHECK(game_admission_status='NOT_APPROVED'),
 simulation_world_active boolean NOT NULL DEFAULT false CHECK(NOT simulation_world_active),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(batch_key,airport_key));
ALTER TABLE airlinerra.airport_expansion_operator_runway_source_issues ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_operator_runway_source_issues FROM PUBLIC,anon,authenticated;

DO $preflight$ BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE active AND world_number=1)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 THEN RAISE EXCEPTION 'Owner foundation 3140 inventory not intact';END IF;
END $preflight$;

INSERT INTO airlinerra.airport_expansion_independent_paved_runway_reviews
(batch_key,airport_key,icao_code,research_status,source_authority_grade,paved_runway_pair,documented_physical_length_m,documented_width_m,normalized_surface,published_landing_direction_a_m,published_landing_direction_b_m,historic_registry_length_m,source_url,supporting_url,evidence_notes,next_review_action) VALUES
('EXPANSION_DE_PAVED_BATCH_05_2026_10_26','OURAIRPORTS:2271','EDSN','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','09/27',1248,30,'ASPHALT',NULL,NULL,1247.9,'https://www.take-off-park.de/flugplatz/fluginfos/','https://dulv.de/fmwebphp/Flugplatz/details.php?id=1023','Current operator site revised October 15, 2026 publishes paved asphalt runway 09/27 1248 x30m. PPR beyond listed hours, 5.7t routine and up to 14t prior approval. Displaced touchdown point for aircraft below 2t on RW27, 60m end strips only for takeoff. Old third-party direction 10/28 is superseded by operator designation. Per-end LDA not sourced, so only physical runway research qualifies.','Obtain current effective official aeronautical publication runway declared distances, aircraft-specific suitability and eventual owner-controlled simulation expansion approval; source evidence is not airline permission.'),
('EXPANSION_DE_PAVED_BATCH_05_2026_10_26','OURAIRPORTS:2273','EDTD','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','18/36',1200,30,'ASPHALT',1290,1200,1289.9,'https://donau-airport.de/piloteninformationen/','https://dulv.de/fmwebphp/Flugplatz/details.php?id=766','Current Donau Airport operator webpage gives physical asphalt runway 18/36 only 1200x30m but separately gives RW18 LDG 1290m and TORA1200m, RW36 LDG1200m and TORA1290m; at least one declared landing/takeoff direction exceeds stated physical length, and registry 1289.9m disagrees with operator nominal physical 1200m. Source values transcribed exactly, contradiction MUST be reconciled with current AIP rather than promoted to cleared runway.','Specific operator/runway-source issue, listed in airport_expansion_operator_runway_source_issues. Obtain effective AIP and resolve issue before source hold can be cleared. Landing distance does not automatically follow gross pavement length.'),
('EXPANSION_DE_PAVED_BATCH_05_2026_10_26','OURAIRPORTS:2274','EDTF','SECONDARY_RUNWAY_EVIDENCE_OFFICIAL_SOURCE_REQUIRED','SECONDARY_ONLY_CURRENT','16/34',1338,30,'ASPHALT',1190,1040,1338.1,'https://freiburg-airport.de/','https://de.ivao.aero/prozeduren/edgg/s/edtf/','Current airport operator lists RW16 published LDA1190m and RW34 LDA1040m, both shorter than 1200m. Paved physical length of 1338x30m comes from research register, recent 2023 IVAO and other independent technical listings rather than the current operator page; older aeroclub page lists 1400m. Physical dimensions must be verified in effective aeronautical publications. Runway 16/34 is closed temporarily around SC Freiburg home fixtures: 2h prior to kickoff until 1h after final whistle. Do not use physical length as landing allowance or infer either direction passes 1200m LDA.','Specific operator/runway-source issue, listed in airport_expansion_operator_runway_source_issues. Obtain effective AIP and resolve issue before source hold can be cleared. Landing distance does not automatically follow gross pavement length.'),
('EXPANSION_DE_PAVED_BATCH_05_2026_10_26','OURAIRPORTS:2275','EDTG','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','05/23',1650,45,'ASPHALT',NULL,NULL,1649.9,'https://www.gewerbepark-breisgau.de/unser-flugplatz/kontakt-adesse-lage/','https://www.gewerbepark-breisgau.de/unser-flugplatz/','Gewerbepark Breisgau airfield operator confirms RW05/23 asphalt 1650x45m, separate grass 600x30m is not eligible. Special landing site mainly business/sport flights up to 20t; published operator schedule limited evenings, weekday and weekend hours, no per-end LDA in consulted page. Owner permissions, flight-date restrictions and aircraft suitability unverified.','Obtain current effective official aeronautical publication runway declared distances, aircraft-specific suitability and eventual owner-controlled simulation expansion approval; source evidence is not airline permission.'),
('EXPANSION_DE_PAVED_BATCH_05_2026_10_26','OURAIRPORTS:2277','EDTM','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','07/25',1566,30,'ASPHALT',NULL,NULL,1566.1,'https://www.regio-airport-mengen.de/piloteninfo/flugplatzdaten/','https://wp.regio-airport-mengen.de/piloteninfo/flugplatzdaten/','Current Regio Airport Mengen operator confirms asphalt RW07/25 1566x30m; grass 700x30m not qualifying. Usual 5700kg aircraft, 14t PPR; AFIS service. Current airport rules prohibit circuits on Sundays/holidays except limited recency exception; flight-specific noise, parking, handling and LDA not verified. Real paid charter customs possibility is not game authorization.','Obtain current effective official aeronautical publication runway declared distances, aircraft-specific suitability and eventual owner-controlled simulation expansion approval; source evidence is not airline permission.'),
('EXPANSION_DE_PAVED_BATCH_05_2026_10_26','OURAIRPORTS:2278','EDTY','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','10/28',1540,30,'CONCRETE',1365,1413,1540.2,'https://www.edty.de/de/airport/pilot_information/approach_information/approach_information.php','https://www.edty.de/en/airport/pilot_information/approach_information/approach_information.php','Current Adolf Würth Airport operator confirms RW10/28 concrete 1540x30m, RW10 TORA1540 TODA1600 ASDA1540 LDA1365m, RW28 TORA/TODA/ASDA1540 LDA1413m. RW10 TODA1600m is NOT physical landing runway length. Published flights up to 14t as normal, heavier operations need PPR; seasonal opening and ILS28; flight operations not approved through this study.','Obtain current effective official aeronautical publication runway declared distances, aircraft-specific suitability and eventual owner-controlled simulation expansion approval; source evidence is not airline permission.'),
('EXPANSION_DE_PAVED_BATCH_05_2026_10_26','OURAIRPORTS:2284','EDVE','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','08/26',2300,45,'ASPHALT',NULL,NULL,2300.0,'https://www.fhbwe.de/aviation','https://www.fhbwe.de/','Current Flughafen Braunschweig-Wolfsburg operator confirms asphalt RW08/26 2300x45m PCN52/F/BX/T, IFR/VFR and separate nonqualifying 900m grass area. Winter weekend hours differ, outside hours PPR. Advertised deicing, Jet A1, RFFS cat6/cat8 by prior arrangement are not certified service contracts for Airlinerra. Operator did not publish numeric directional LDA in inspected page.','Obtain current effective official aeronautical publication runway declared distances, aircraft-specific suitability and eventual owner-controlled simulation expansion approval; source evidence is not airline permission.'),
('EXPANSION_DE_PAVED_BATCH_05_2026_10_26','OURAIRPORTS:2286','EDVM','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','07/25',1220,23,'ASPHALT',NULL,NULL,1220.1,'https://www.flugplatz-hildesheim.de/index.php?iCID=1','https://www.flugplatz-hildesheim.de/','Current Flugplatz Hildesheim operator lists RW07/25 asphalt 1220x23m plus a distinct RW07/25 grass 1220x30m. The nearby ''TORA und LDA 1160m'' appears on grass runway line in rendered technical table; do not attribute this 1160m to asphalt without explicit AIP/source clarification. Asphalt physically meets 1200m by just 20m. Aircraft up to 5.7t, seasonal operating hours and out-of-hours PPR. Paved per-end LDA unknown.','Obtain current effective official aeronautical publication runway declared distances, aircraft-specific suitability and eventual owner-controlled simulation expansion approval; source evidence is not airline permission.')
ON CONFLICT(batch_key,airport_key) DO NOTHING;

INSERT INTO airlinerra.airport_expansion_operator_runway_source_issues
(batch_key,airport_key,icao_code,issue_code,runway_pair,operator_reported_physical_m,source_landing_a_m,source_landing_b_m,historic_registry_runway_m,source_url,supporting_url,explanation,next_step) VALUES
('EXPANSION_DE_PAVED_BATCH_05_2026_10_26','OURAIRPORTS:2273','EDTD','OPERATOR_PHYSICAL_LENGTH_LDA_CONTRADICTION','18/36',1200,1290,1200,1289.9,'https://donau-airport.de/piloteninformationen/','https://dulv.de/fmwebphp/Flugplatz/details.php?id=766','October 2026 operator pilot webpage lists physical asphalt runway 1200x30m with RW18 LDG1290m / TORA1200m and RW36 LDG1200m / TORA1290m. Its declared distance for RW18 exceeds physical runway by 90m, and separate historic Airlinerra master shows 1289.9m physical. Dimensions and declared distances are source-contradictory: no authoritative landing direction should be promoted without current AIP/airport corrected table.','Retrieve latest effective DFS AIP ED TD RW18/36 AD2 declared distances and runway physical dimensions or dated written airport operator correction. Distinguish runway pavement, displaced thresholds and takeoff extensions; then reconcile registry original source safely.'),
('EXPANSION_DE_PAVED_BATCH_05_2026_10_26','OURAIRPORTS:2274','EDTF','DIRECTIONAL_LDA_BELOW_1200_AND_PHYSICAL_SOURCE_RECONCILIATION','16/34',NULL,1190,1040,1338.1,'https://freiburg-airport.de/','https://de.ivao.aero/prozeduren/edgg/s/edtf/','Current Freiburg Airport operator lists RW16 LDA1190m and RW34 LDA1040m (TORA1040/1250m), BOTH below 1200m. Historic airport registry physical 1338.1m asphalt while other publications cite 1240m or 1400m and the current operator front page contains no runway gross dimensions. Physical runway >=1200m may qualify for airport collection, but no published landing direction passes the 1200m direction-specific distance screen; these are separate criteria.','Fetch effective German AIP EDTF RW16/34 physical dimensions and LDA, confirm any revised distance/threshold, classify airport collection independently from type-specific landing operation; do not falsely reject the physical runway-only collection by conflating LDA with pavement.')
ON CONFLICT(batch_key,airport_key) DO NOTHING;

-- Only six airports may advance, excluding operator-source issue cases EDTD/EDTF.
WITH eligible AS (SELECT v.airport_key,v.source_url,v.evidence_notes,v.next_review_action
 FROM airlinerra.airport_expansion_independent_paved_runway_reviews v
 JOIN airlinerra.airport_cohorts c ON c.airport_key=v.airport_key AND c.cohort='EXPANSION_3906'
 WHERE v.batch_key='EXPANSION_DE_PAVED_BATCH_05_2026_10_26'
 AND v.source_authority_grade='CURRENT_AIRPORT_OPERATOR'
 AND NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_operator_runway_source_issues e
 WHERE e.batch_key=v.batch_key AND e.airport_key=v.airport_key))
UPDATE airlinerra.airport_access_reviews a SET
 identity_status='VERIFIED',paved_runway_status='VERIFIED',
 review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING',
 evidence_url=eligible.source_url,
 source_review_note='German expansion Batch05 current operator independently verifies asphalt/concrete main runway physical qualifying length, NO commercial/game approval. '||eligible.evidence_notes||' Next: '||eligible.next_review_action,
 review_date='2026-10-26',last_updated=now()
FROM eligible WHERE a.airport_key=eligible.airport_key
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
 AND a.game_admission_status='NOT_APPROVED';

-- No airport world activations; no master airport runway lengths overwritten.
SELECT icao_code,research_status,source_authority_grade
FROM airlinerra.airport_expansion_independent_paved_runway_reviews
WHERE batch_key='EXPANSION_DE_PAVED_BATCH_05_2026_10_26' ORDER BY icao_code;
