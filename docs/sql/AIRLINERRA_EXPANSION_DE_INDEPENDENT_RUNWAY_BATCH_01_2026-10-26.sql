-- Airlinerra owner-protected expansion DE independent runway evidence, Batch 01.
-- Applied to private Supabase research schema 2026-10-26. All airports NOT_APPROVED.
-- Source authority is airport operator for six, secondary for EDAK, historic AIP for EDBN.
-- Does not create game admissions, world2/3 rows or modify original 3140.
CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_independent_paved_runway_reviews(
batch_key text NOT NULL,airport_key text NOT NULL,icao_code text NOT NULL,
country_iso text NOT NULL DEFAULT 'DE' CHECK(country_iso='DE'),
research_status text NOT NULL CHECK(research_status IN
('OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD',
 'SECONDARY_RUNWAY_EVIDENCE_OFFICIAL_SOURCE_REQUIRED',
 'HISTORICAL_AIP_CURRENT_VERIFICATION_REQUIRED')),
source_authority_grade text NOT NULL CHECK(source_authority_grade IN
('CURRENT_AIRPORT_OPERATOR','SECONDARY_ONLY_CURRENT',
 'HISTORICAL_OFFICIAL_AIP_CURRENT_RECHECK')),
paved_runway_pair text NOT NULL,
documented_physical_length_m numeric NOT NULL CHECK(documented_physical_length_m>=1200),
documented_width_m numeric NOT NULL CHECK(documented_width_m>0),
normalized_surface text NOT NULL CHECK(normalized_surface IN('CONCRETE','ASPHALT')),
published_landing_direction_a_m numeric,published_landing_direction_b_m numeric,
historic_registry_length_m numeric NOT NULL,
physical_length_difference_m numeric GENERATED ALWAYS AS
 (documented_physical_length_m-historic_registry_length_m) STORED,
source_url text NOT NULL,supporting_url text,evidence_notes text NOT NULL,
next_review_action text NOT NULL,
game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
simulation_world_active boolean NOT NULL DEFAULT false CHECK(simulation_world_active=false),
researched_at timestamptz NOT NULL DEFAULT now(),
PRIMARY KEY(batch_key,airport_key),
FOREIGN KEY(airport_key) REFERENCES airlinerra.airport_registry(airport_key));
ALTER TABLE airlinerra.airport_expansion_independent_paved_runway_reviews ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_independent_paved_runway_reviews FROM PUBLIC,anon,authenticated;

INSERT INTO airlinerra.airport_expansion_independent_paved_runway_reviews
(batch_key,airport_key,icao_code,research_status,source_authority_grade,paved_runway_pair,documented_physical_length_m,documented_width_m,normalized_surface,published_landing_direction_a_m,published_landing_direction_b_m,historic_registry_length_m,source_url,supporting_url,evidence_notes,next_review_action) VALUES
('EXPANSION_DE_PAVED_BATCH_01_2026_10_26','OURAIRPORTS:2183','EDAB','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','07/25',2200,50,'CONCRETE',NULL,NULL,2200.0,'https://www.flugplatz-bautzen.com/informationen-fuer-piloten/',NULL,'Operator reports concrete RW07/25 2200x50m, PCN 44 R/B/W/T. Secondary grass 07/25 is 1000m and ineligible. Winter weekends require PPR; no operator-specific permission or aircraft compatibility approval.','Check current AIP runway direction declarations, dimensions, operating restrictions and any registry discrepancy; invite for separate owner-authorized simulation expansion release, without certifying commercial airline rights.'),
('EXPANSION_DE_PAVED_BATCH_01_2026_10_26','OURAIRPORTS:2188','EDAK','SECONDARY_RUNWAY_EVIDENCE_OFFICIAL_SOURCE_REQUIRED','SECONDARY_ONLY_CURRENT','11/29',1415,48,'CONCRETE',NULL,NULL,1414.9,'https://dulv.de/fmwebphp/Flugplatz/details.php?id=840','https://tpm-mediashop.com/pages/edak-grossenhain','Two independent secondary guides report concrete 11/29 1415x48m, with separate 950m grass. No current airport-operator source or German AIP effective runway declaration authenticated; keep independent verification hold.','Obtain current operator or effective German AIP runway declarations; maintain evidence hold and do not activate before owner release.'),
('EXPANSION_DE_PAVED_BATCH_01_2026_10_26','OURAIRPORTS:2192','EDAV','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','10/28',1560,50,'CONCRETE',NULL,NULL,1538.0,'https://edav.eu/','https://de.ivao.aero/prozeduren/edww/e/edav/','Current operator says 1560x50m concrete 10/28, compared to 1538m in registry and 1480m on older secondary source. 22m registry difference requires reconciliation with effective AIP. Jet-A1 advertised, but no flight permissions or LDA verified.','Check current AIP runway direction declarations, dimensions, operating restrictions and any registry discrepancy; invite for separate owner-authorized simulation expansion release, without certifying commercial airline rights.'),
('EXPANSION_DE_PAVED_BATCH_01_2026_10_26','OURAIRPORTS:2193','EDAX','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','07/25',2380,50,'CONCRETE',1301,1341,2379.9,'https://www.mueritz-airpark.de/flugplatz/daten/','https://www.mueritz-airpark.de/flugplatz/geschichte','Operator reports 2380x50m concrete but declares RW07 LDA1301m / TORA1341m and RW25 LDA1341m / TORA1301m. Flight-data page lists MTOW 5700kg while history mentions past 14t approval; current license requires verification. PPR applies; do not use full gross length as landing distance.','Check current AIP runway direction declarations, dimensions, operating restrictions and any registry discrepancy; invite for separate owner-authorized simulation expansion release, without certifying commercial airline rights.'),
('EXPANSION_DE_PAVED_BATCH_01_2026_10_26','OURAIRPORTS:2195','EDAZ','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','07/25',1510,23,'ASPHALT',1340,1270,1510.0,'https://www.flugplatz-schoenhagen.aero/piloten/verkehrslandeplatz/flugplatzdaten','https://www.flugplatz-schoenhagen.aero/piloten/verkehrslandeplatz','Operator lists asphalt 07/25 1510x23m, LDA07 1340m, LDA25 1270m, TORA07 1270m TORA25 1340m and PCN25 F/A/X/T. Published nighttime commercial operation limits; no individual operator right established.','Check current AIP runway direction declarations, dimensions, operating restrictions and any registry discrepancy; invite for separate owner-authorized simulation expansion release, without certifying commercial airline rights.'),
('EXPANSION_DE_PAVED_BATCH_01_2026_10_26','OURAIRPORTS:28546','EDBC','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','07/25',2500,45,'ASPHALT',NULL,NULL,2500.0,'https://www.dlr.de/de/ux/forschung-betrieb/flughafenbetrieb','https://cochstedt-airport.de/allgemeine_luftfahrt/','DLR confirms airport reopened 2022 and asphalt RW07/25 2500x45m; grass secondary 800m. Aircraft up to 14t per DLR VFR statement; DLR says outside-hours PPR 48h, aerodrome site says 72h, so current notice must be verified. Jet A-1 available in principle only.','Check current AIP runway direction declarations, dimensions, operating restrictions and any registry discrepancy; invite for separate owner-authorized simulation expansion release, without certifying commercial airline rights.'),
('EXPANSION_DE_PAVED_BATCH_01_2026_10_26','OURAIRPORTS:2196','EDBH','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','09/27',1685,30,'ASPHALT',1385,1450,1684.9,'https://www.edbh.de/fuer-piloten/flughafen-daten',NULL,'Operator reports paved 09/27 with 1685m and direction-specific other physical listing 1658m, LDA09 1385m, LDA27 1450m; currently no IFR, aircraft >5.7t previous-working-day PPR, seasonal hours. Both LDAs meet minimum, not airline permission.','Check current AIP runway direction declarations, dimensions, operating restrictions and any registry discrepancy; invite for separate owner-authorized simulation expansion release, without certifying commercial airline rights.'),
('EXPANSION_DE_PAVED_BATCH_01_2026_10_26','OURAIRPORTS:2743','EDBN','HISTORICAL_AIP_CURRENT_VERIFICATION_REQUIRED','HISTORICAL_OFFICIAL_AIP_CURRENT_RECHECK','09/27',2293,45,'CONCRETE',NULL,NULL,2292.7,'https://www.flughafen-neubrandenburg.de/images/downloads/20211005-edbn-ifr.pdf','https://www.pilotcenter.app/flugplaetze/edbn','Operator-hosted German AIP aerodrome obstacle chart effective June 2018 documents 2293x45m concrete 09/27; independent aviation directory corroborates size, but chart is too old for current 2026 operability conclusion. Current AIP/operator confirmation required.','Obtain current operator or effective German AIP runway declarations; maintain evidence hold and do not activate before owner release.')
ON CONFLICT(batch_key,airport_key) DO NOTHING;

-- Advance only six with independently sourced current operator runway information.
-- The other two remain at HOLD_INDEPENDENT_VERIFICATION.
UPDATE airlinerra.airport_access_reviews a SET
identity_status='VERIFIED',paved_runway_status='VERIFIED',
review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING',
evidence_url=v.source_url,
source_review_note='Independent airport operator physical paved runway verified in expansion DE batch 01; game admission and airline permissions NOT APPROVED. ' || v.evidence_notes || ' Next: ' || v.next_review_action,
review_date='2026-10-26',last_updated=now()
FROM airlinerra.airport_expansion_independent_paved_runway_reviews v
JOIN airlinerra.airport_cohorts cohort ON cohort.airport_key=v.airport_key AND cohort.cohort='EXPANSION_3906'
WHERE a.airport_key=v.airport_key
AND v.batch_key='EXPANSION_DE_PAVED_BATCH_01_2026_10_26'
AND v.source_authority_grade='CURRENT_AIRPORT_OPERATOR'
AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
AND a.game_admission_status='NOT_APPROVED';

-- Never activate these airports here. A later owner-authorized game release is separate.
SELECT icao_code,research_status,published_landing_direction_a_m,published_landing_direction_b_m
FROM airlinerra.airport_expansion_independent_paved_runway_reviews
WHERE batch_key='EXPANSION_DE_PAVED_BATCH_01_2026_10_26' ORDER BY icao_code;