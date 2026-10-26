-- Airlinerra German Expansion Batch 03, October 26 2026. Research only.
-- Prerequisite: Batch 01 airlinerra.airport_expansion_independent_paved_runway_reviews;
-- and this batch's companion technical-exception schema below.
-- Batch consists of seven >1200m runway observations and one below-rule EDMB exception.
-- Preserve founding 3140 game locations and do not mark any commercial license/airline approval.
CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_runway_technical_exceptions(
 batch_key text NOT NULL,airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 icao_code text NOT NULL,
 exception_type text NOT NULL CHECK(exception_type='OPERATOR_PAVED_RUNWAY_BELOW_1200M_REGISTRY_CONFLICT'),
 source_paved_length_m numeric NOT NULL CHECK(source_paved_length_m>0 AND source_paved_length_m<1200),
 source_paved_width_m numeric NOT NULL CHECK(source_paved_width_m>0),
 runway_pair text NOT NULL,runway_surface text NOT NULL CHECK(runway_surface IN('ASPHALT','CONCRETE')),
 source_landing_direction_a_m numeric,source_landing_direction_b_m numeric,
 registry_qualifying_length_m numeric NOT NULL CHECK(registry_qualifying_length_m>=1200),
 source_authority_grade text NOT NULL CHECK(source_authority_grade='CURRENT_AIRPORT_OPERATOR'),
 source_url text NOT NULL,evidence_notes text NOT NULL,required_reconciliation text NOT NULL,
 review_status text NOT NULL DEFAULT 'SOURCE_CONFLICT_EXCLUSION_REVIEW' CHECK(review_status='SOURCE_CONFLICT_EXCLUSION_REVIEW'),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 simulation_world_active boolean NOT NULL DEFAULT false CHECK(NOT simulation_world_active),
 last_verified_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(batch_key,airport_key));
ALTER TABLE airlinerra.airport_expansion_runway_technical_exceptions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_runway_technical_exceptions FROM PUBLIC,anon,authenticated;

DO $guard$ BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE active AND world_number=1)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 THEN RAISE EXCEPTION 'Original game world has drifted'; END IF;
END $guard$;

INSERT INTO airlinerra.airport_expansion_independent_paved_runway_reviews
(batch_key,airport_key,icao_code,research_status,source_authority_grade,paved_runway_pair,documented_physical_length_m,documented_width_m,normalized_surface,published_landing_direction_a_m,published_landing_direction_b_m,historic_registry_length_m,source_url,supporting_url,evidence_notes,next_review_action) VALUES
('EXPANSION_DE_PAVED_BATCH_03_2026_10_26','OURAIRPORTS:2233','EDGS','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','13/31',1620,30,'ASPHALT',NULL,NULL,1620.0,'https://www.siegerland-airport.de/fuer-piloten/infos-fuer-piloten/','https://de.ivao.aero/prozeduren/edgg/n/edgs/','2026 airport operator runway 13/31 asphalt 1620m PCN53 F/D/X/T, IFR approaches. 30m width from older independent aviation guide, not from this operator page; obtain current effective AIP. Separate grass runways shorter than 1200m. Seasonal hours effective 1 Oct 2026 and Christmas/New Year closures; PPR outside hours. Published per-end LDA not verified.','Reconcile authoritative effective aeronautical publication, direction-specific landing/takeoff allowances, runway width and local aircraft class; later independent owner simulation-airport release needed; do not mark actual commercial operating rights verified.'),
('EXPANSION_DE_PAVED_BATCH_03_2026_10_26','OURAIRPORTS:2235','EDHK','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','08/26',1320,30,'ASPHALT',NULL,NULL,1260.0,'https://www.airport-kiel.de/files/Airport/Downloads/Airport%20Kiel%20-%20web%20DE%202025.pdf','https://www.airport-kiel.de/','Airport Kiel GmbH own 2025 brochure lists asphalt 08/26 1320x30m and parallel grass 450x35m; older original registry and DULV show 1260m. +60m conflict; official brochure PDF indexed but screenshot retrieval from remote site failed, use operator document with effective AIP recheck; no numeric published per-direction LDA confirmed. Training and general aviation only not proof of scheduled carrier permission.','Reconcile authoritative effective aeronautical publication, direction-specific landing/takeoff allowances, runway width and local aircraft class; later independent owner simulation-airport release needed; do not mark actual commercial operating rights verified.'),
('EXPANSION_DE_PAVED_BATCH_03_2026_10_26','OURAIRPORTS:28553','EDLD','SECONDARY_RUNWAY_EVIDENCE_OFFICIAL_SOURCE_REQUIRED','SECONDARY_ONLY_CURRENT','08/26',1500,30,'ASPHALT',NULL,NULL,1499.9,'https://jp-flugschule.de/standorte/','https://schwarze-heide.com/edld/neuigkeiten/','Airport operator historical news confirms extension to 1500m, but pavement type in registry is CONCRETE and on-site school and DULV describe ASPHALT 1500x30m; exact current operator/AIP pavement field not obtained, so keep central source-verification hold pending reconciliation. Operator current page requires 400m displaced touchdown point RW26 for airplanes under 2t, a procedural issue not a published LDA; individual performance constraints unresolved.','Reconcile official airport/AIP paving type and directional declared distances against conflicting registry; preserve source evidence hold.'),
('EXPANSION_DE_PAVED_BATCH_03_2026_10_26','OURAIRPORTS:2241','EDLE','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','06/24',1553,45,'ASPHALT',1553,1200,1553.0,'https://www.flughafen-essen-muelheim.de/piloten/allgemein','https://www.flughafen-essen-muelheim.de/assets/media/flugplatzbenutzungsordnung-stand-01.01.26.pdf','Current airport operator official airport data gives asphalt runway 1553x45m, labeled 06/24 (some older secondary lists 07/25): RW06 TORA1200 LDA1553; RW24 TORA1553 LDA1200m exactly Airlinerra minimum. Jets prohibited except ambulance flights; no all-purpose jet airline eligibility despite usable paved runway. Scheduled/night services require separate airline and airport approval. 2026 FBO restricts 14t, 25t PPR and ARFF category on demand.','Reconcile authoritative effective aeronautical publication, direction-specific landing/takeoff allowances, runway width and local aircraft class; later independent owner simulation-airport release needed; do not mark actual commercial operating rights verified.'),
('EXPANSION_DE_PAVED_BATCH_03_2026_10_26','OURAIRPORTS:2242','EDLI','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','11/29',1256,20,'ASPHALT',NULL,NULL,1256.1,'https://flugplatz-bielefeld.de/flugplatzdaten/','https://flugplatz-bielefeld.de/en/aerodrome-data/','Operator lists 11/29 asphalt 1256x20m, 3000kg standard aircraft limit, up to 5700kg PPR. Aircraft runway width only 20m; runway merely 56m longer than min physical length, published per-end LDA not yet verified. PAPI 4 degrees, flight-date and aircraft/performance/owner rules unresolved.','Reconcile authoritative effective aeronautical publication, direction-specific landing/takeoff allowances, runway width and local aircraft class; later independent owner simulation-airport release needed; do not mark actual commercial operating rights verified.'),
('EXPANSION_DE_PAVED_BATCH_03_2026_10_26','OURAIRPORTS:2245','EDLS','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','11/29',1240,30,'ASPHALT',1200,1240,1239.9,'https://www.flugplatz-stadtlohn.de/index.php?L=1&id=79','https://www.flugplatz-stadtlohn.de/index.php?L=786%2C1709401784&id=79','Airport operator publishes runway 11/29 asphalt 1240x30m, RW11 TORA1240 LDA1200, RW29 TORA1200 LDA1240. RW11 landing distance is exactly minimum, no surplus. Aircraft >5700kg require PPR; daily opening to sunset or 21:00, earlier/late PPR; day-specific commercial and airframe limitations unverified.','Reconcile authoritative effective aeronautical publication, direction-specific landing/takeoff allowances, runway width and local aircraft class; later independent owner simulation-airport release needed; do not mark actual commercial operating rights verified.'),
('EXPANSION_DE_PAVED_BATCH_03_2026_10_26','OURAIRPORTS:2248','EDMA','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','07/25',1594,30,'ASPHALT',1355,1331,1594.1,'https://www.augsburg-airport.de/flughafen/flughafendaten/','https://www.euroga.org/system/1/user_files/files/000/042/014/42014/802240a5f/original/ED_AD_2_EDMA_en_2019-07-18.pdf','Operator current official data RW07/25 1594m asphalt, RW07 TORA1406m TODA1551m ASDA1406m LDA1355m; RW25 TORA1406 TODA1605 ASDA1406 LDA1331. 30m width corroborated by older original German AIP 2019 (not authenticated as current); effective 2026 AIP recheck outstanding. Asphalt clearway is not landing pavement; operator documents extra takeoff option on preceding paved areas, separate aircraft approval needed.','Reconcile authoritative effective aeronautical publication, direction-specific landing/takeoff allowances, runway width and local aircraft class; later independent owner simulation-airport release needed; do not mark actual commercial operating rights verified.')
ON CONFLICT(batch_key,airport_key) DO NOTHING;

INSERT INTO airlinerra.airport_expansion_runway_technical_exceptions
(batch_key,airport_key,icao_code,exception_type,source_paved_length_m,source_paved_width_m,runway_pair,runway_surface,source_landing_direction_a_m,source_landing_direction_b_m,registry_qualifying_length_m,source_authority_grade,source_url,evidence_notes,required_reconciliation) VALUES
('EXPANSION_DE_PAVED_BATCH_03_2026_10_26','OURAIRPORTS:2249','EDMB','OPERATOR_PAVED_RUNWAY_BELOW_1200M_REGISTRY_CONFLICT',980,23,'04/22','ASPHALT',780,980,1314.9,'CURRENT_AIRPORT_OPERATOR','https://www.edmb.de/fur-piloten/an-abflug/','Airport operator 2026 pilots technical page identifies EDMB runway 04/22 asphalt 980x23m, 04 landing distance 780m and 22 landing distance 980m. Registry incorrectly labels a qualifying 1314.9m asphalt runway, >334m above measured operator fact. Both actual landing directions and gross runway length fail >=1200m requirement. This is an independently grounded technical hold, not a permanently rejected airport pending effective AIP/source correction.','Confirm whether any OTHER currently operational paved runway at EDMB >=1200m exists using effective 2026 Germany AIP/airport operator. Correct underlying stale runway master only through separately reviewed source-specific correction process; do not include in airport simulation world absent proof.')
ON CONFLICT(batch_key,airport_key) DO NOTHING;

-- Operator-confirmed qualifying runway candidates: 6 of 7 main-runway observations.
UPDATE airlinerra.airport_access_reviews a SET
 identity_status='VERIFIED',paved_runway_status='VERIFIED',
 review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING',
 evidence_url=v.source_url,
 source_review_note='German independent Batch 03 operator-supported paved runway source: '||v.evidence_notes||' Next: '||v.next_review_action||' No actual airline permission or simulation world admission approved.',
 review_date='2026-10-26',last_updated=now()
FROM airlinerra.airport_expansion_independent_paved_runway_reviews v
JOIN airlinerra.airport_cohorts c ON c.airport_key=v.airport_key AND c.cohort='EXPANSION_3906'
WHERE a.airport_key=v.airport_key AND v.batch_key='EXPANSION_DE_PAVED_BATCH_03_2026_10_26'
AND v.source_authority_grade='CURRENT_AIRPORT_OPERATOR'
AND a.review_status='HOLD_INDEPENDENT_VERIFICATION' AND a.game_admission_status='NOT_APPROVED';

-- EDMB airport operator reports only 980m asphalt while registry says 1314.9m.
UPDATE airlinerra.airport_access_reviews a SET
 identity_status='VERIFIED',review_status='HOLD_OPERATOR_RUNWAY_BELOW_1200M_REGISTRY_CONFLICT',
 evidence_url=e.source_url,
 source_review_note='German independent runway Batch 03: '||e.evidence_notes||' Required next step: '||e.required_reconciliation,
 review_date='2026-10-26',last_updated=now()
FROM airlinerra.airport_expansion_runway_technical_exceptions e
WHERE a.airport_key=e.airport_key
AND e.batch_key='EXPANSION_DE_PAVED_BATCH_03_2026_10_26'
AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
AND a.game_admission_status='NOT_APPROVED' AND a.paved_runway_status='UNVERIFIED';

-- No source override or game activation performed. EDLD remains in generic hold.
SELECT icao_code,research_status FROM airlinerra.airport_expansion_independent_paved_runway_reviews
WHERE batch_key='EXPANSION_DE_PAVED_BATCH_03_2026_10_26' ORDER BY icao_code;
