-- Airlinerra expansion Germany Batch 06, independently executed 2026-10-26.
-- EIGHT research source records including re-reviews, TWO directional civil-use cases.
-- First original 3140 game airports are never changed; expansion activation 0.
-- PRE-REQUISITE: initial table airport_expansion_independent_paved_runway_reviews (Batch01).
-- Do not conflate physical runway length >=1200m with usable published per-end LDA >=1200m.
CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_german_civil_runway_end_holds (
 batch_key text NOT NULL,airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 icao_code text NOT NULL,runway_pair text NOT NULL,
 source_physical_length_m numeric NOT NULL CHECK(source_physical_length_m>=1200),
 source_width_m numeric NOT NULL CHECK(source_width_m>0),
 source_landing_end_a_m numeric NOT NULL CHECK(source_landing_end_a_m>0),
 source_landing_end_b_m numeric NOT NULL CHECK(source_landing_end_b_m>0),
 current_source_check text NOT NULL CHECK(current_source_check IN
 ('CURRENT_AIRPORT_OPERATOR','HISTORICAL_OPERATOR_HOSTED_AIRFIELD_CHART')),
 issue text NOT NULL,source_url text NOT NULL,evidence_note text NOT NULL,resolution text NOT NULL,
 review_status text NOT NULL DEFAULT 'DIRECTIONAL_USABLE_DISTANCE_MANUAL_REVIEW'
 CHECK(review_status='DIRECTIONAL_USABLE_DISTANCE_MANUAL_REVIEW'),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 game_world_activated boolean NOT NULL DEFAULT false CHECK(NOT game_world_activated),
 reviewed_at timestamptz NOT NULL DEFAULT now(),PRIMARY KEY(batch_key,airport_key));
ALTER TABLE airlinerra.airport_expansion_german_civil_runway_end_holds ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_german_civil_runway_end_holds FROM PUBLIC,anon,authenticated;

DO $foundation$ BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE world_number=1 AND active)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 THEN RAISE EXCEPTION 'Initial foundation world not protected';END IF;
END $foundation$;

INSERT INTO airlinerra.airport_expansion_independent_paved_runway_reviews
(batch_key,airport_key,icao_code,research_status,source_authority_grade,paved_runway_pair,documented_physical_length_m,documented_width_m,normalized_surface,published_landing_direction_a_m,published_landing_direction_b_m,historic_registry_length_m,source_url,supporting_url,evidence_notes,next_review_action) VALUES
('EXPANSION_DE_PAVED_BATCH_06_2026_10_26','OURAIRPORTS:2188','EDAK','SECONDARY_RUNWAY_EVIDENCE_OFFICIAL_SOURCE_REQUIRED','SECONDARY_ONLY_CURRENT','11/29',1415,48,'CONCRETE',NULL,NULL,1414.9,'https://dulv.de/fmwebphp/Flugplatz/details.php?id=840','https://tpm-mediashop.com/pages/edak-grossenhain','DULV runway directory and separate 2026 aviation technical publisher both list concrete RW11/29 1415x48m and separate grass 950x40m; original airport operator current documentation and effective 2026 German AIP not obtained. This RECHECK reconfirms secondary but does NOT strengthen evidence to current airport operator; runway TORA/LDA unknown; maintain hold.','Previous hold rechecked. Still needs current effective operator or German AIP physical runway dimensions/operability. Do not classify historic/secondary publication as current approved.'),
('EXPANSION_DE_PAVED_BATCH_06_2026_10_26','OURAIRPORTS:2743','EDBN','HISTORICAL_AIP_CURRENT_VERIFICATION_REQUIRED','HISTORICAL_OFFICIAL_AIP_CURRENT_RECHECK','09/27',2293,45,'CONCRETE',2293,2293,2292.7,'https://www.flughafen-neubrandenburg.de/images/downloads/20211005-edbn-ifr.pdf','https://www.flughafen-neubrandenburg.de/index.php?Itemid=299&id=58&option=com_content&view=article','Operator-hosted genuine German AIP AD2 page effective 06 Dec 2018 lists concrete RW09/27 2293x45m PCN75, TORA/TODA/ASDA/LDA 2293m each end. Operator current page lists operational contacts but does not authenticate that 2018 runway geometry and declared distances remain current in 2026. Therefore keep historical AIP source grade and general independent hold.','Previous hold rechecked. Still needs current effective operator or German AIP physical runway dimensions/operability. Do not classify historic/secondary publication as current approved.'),
('EXPANSION_DE_PAVED_BATCH_06_2026_10_26','OURAIRPORTS:2207','EDCP','SECONDARY_RUNWAY_EVIDENCE_OFFICIAL_SOURCE_REQUIRED','SECONDARY_ONLY_CURRENT','13/31',2400,48,'CONCRETE',NULL,NULL,2400.0,'https://de.ivao.aero/prozeduren/edww/e/edcp/','https://dulv.de/fmwebphp/Flugplatz/details.php?id=1071','2021 IVAO procedure quotes concrete RW13/31 2400x48m, while independent DULV directory gives 2400x60m; width conflicting. No current operator/AIP direct verification available at source check. Retain hold; no fabricated direction-specific LDA or paved-runway width certification.','Previous hold rechecked. Still needs current effective operator or German AIP physical runway dimensions/operability. Do not classify historic/secondary publication as current approved.'),
('EXPANSION_DE_PAVED_BATCH_06_2026_10_26','OURAIRPORTS:2252','EDMO','SECONDARY_RUNWAY_EVIDENCE_OFFICIAL_SOURCE_REQUIRED','SECONDARY_ONLY_CURRENT','04/22',2286,45,'ASPHALT',NULL,NULL,2286.0,'https://www.fsg-im-dlr.de/node/49','https://www.edmo-airport.de/flugbetrieb/','DLR-based resident flying group cites ASPH RW04/22 2286x45m. Airport operator confirms Sonderflughafen use/PPR but current inspected operator page lacks published geometry. Without current AIP/airport operator dimensions retain source hold; operator authorization is not available to all paid airlines.','Previous hold rechecked. Still needs current effective operator or German AIP physical runway dimensions/operability. Do not classify historic/secondary publication as current approved.'),
('EXPANSION_DE_PAVED_BATCH_06_2026_10_26','OURAIRPORTS:2290','EDWI','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','02/20',1459,30,'ASPHALT',1233,1207,1459.1,'https://www.edwi.info/piloten.html','https://www.edwi.info/piloten/flugplatzinfo.html','Current JadeWeser Airport operator runway technical table RW02/20 ASPH 1459x30m PCN40. RW02 TORA1267m LDA1233m; RW20 TORA1293m LDA1207m, both published LDAs >=1200m (RW20 only 7m margin), not 1459m. Separate RW16/34 615x15m asphalt below threshold, excluded. Aircraft normal max14t and special PPR/IFR/weather/aircraft constraints not game operating approval.','Current operator physical runway evidence and published both-end LDA confirmed. Retain independent game release and real-world aircraft/airline/date suitability gates.'),
('EXPANSION_DE_PAVED_BATCH_06_2026_10_26','OURAIRPORTS:2293','EDXF','HISTORICAL_AIP_CURRENT_VERIFICATION_REQUIRED','HISTORICAL_OFFICIAL_AIP_CURRENT_RECHECK','11/29',1220,30,'ASPHALT',1220,1040,1220.1,'https://www.flensburger-flughafen.de/images/pdf/20190823_EDXF_VFR_AERODROME_CHART.pdf','https://de.ivao.aero/prozeduren/edww/w/edxf/','Airport-operator hosted VFR aerodrome chart dated 23 Aug 2019 shows bitumen/ASPH 11/29 RW 1220x30m, RW11 TORA1040 LDA1220, RW29 TORA1220 LDA1040. Older/2021 IVAO guide repeats values; 300m west and 60m east overrun MUST NOT be added to landing pavement. RW29 historic LDA1040m below 1200m; needs effective 2026 source validation. Hold as historical AIP, physical length may qualify collection.','2019 operator-hosted VFR chart shows 1220m gross paved runway but LDA RW29 1040m, only RW11 1220m. Validate 2026 AIP before release.'),
('EXPANSION_DE_PAVED_BATCH_06_2026_10_26','OURAIRPORTS:2294','EDXJ','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','03/21',1450,30,'ASPHALT',1140,1140,1449.9,'https://www.flughafen-husum.de/de/flughafen/daten/startbahn.php','https://www.flughafen-husum.de/de/flughafen/daten/zulassung.php','Current Husum airport operator confirms ASPH/anti-skid main 03/21 gross pavement1450x30m, BUT length between thresholds1140m, TORA1140m and LDA1140m. Only southwestern part of former NATO runway civil usable; northeast closed with diagonal markings and approximately 1500m fence. Gross runway-only collection requires adjudication of permanently restricted portion. Both published LDA <1200m. Explicit civil-use exception, NOT independently advanced.','CRITICAL: reconcile 1450m gross paved runway and 1140m civil usable length published by airport operator; keep runway-length and 1200m LDA screen held, and check 2026 AIP before approval.'),
('EXPANSION_DE_PAVED_BATCH_06_2026_10_26','OURAIRPORTS:2726','ETHM','SECONDARY_RUNWAY_EVIDENCE_OFFICIAL_SOURCE_REQUIRED','SECONDARY_ONLY_CURRENT','07/25',1615,35,'ASPHALT',NULL,NULL,1628.2,'https://sfgmendig.jimdoweb.com/infos-f%C3%BCr-piloten/','https://www.roland-aircraft.com/index.php/info-fuer-piloten','Resident sport-flying group responsible for PPR publishes EDRE RW07/25 asphalt 1615x35m, matching DULV directory and differing from Airlinerra historic 1628.2m by -13.2m; resident manufacturer suggests 1628x36m. Official ICAO identifier EDRE differs from preserved OURAIRPORTS historical source_ident ETHM and source_gps_code EDRE. Do not alter legacy identity without source-specific crosswalk. Sonderlandeplatz strictly prior written PPR, 5.7t aircraft limit, explicitly NO aviation fuel nor customs. Actual airport operator/current DFS AIP needs confirmation before advancing.','Retrieve effective 2026 aeronautical source and confirm ICAO identity EDRE versus master historical ETHM; protect independent operator/flight access gates.')
ON CONFLICT(batch_key,airport_key) DO NOTHING;

INSERT INTO airlinerra.airport_expansion_german_civil_runway_end_holds
(batch_key,airport_key,icao_code,runway_pair,source_physical_length_m,source_width_m,source_landing_end_a_m,source_landing_end_b_m,current_source_check,issue,source_url,evidence_note,resolution) VALUES
('EXPANSION_DE_PAVED_BATCH_06_2026_10_26','OURAIRPORTS:2293','EDXF','11/29',1220,30,1220,1040,'HISTORICAL_OPERATOR_HOSTED_AIRFIELD_CHART','Airport-operator hosted Jeppesen chart dated 23 Aug 2019 lists 1220x30m bitumen pavement but historic RW11 LDA1220m, RW29 LDA1040m. The gross runway-only physical screen potentially passes, yet RW29 directional landing screen fails 1200m; 2019 chart must not be represented as authenticated 2026 runway data.','https://www.flensburger-flughafen.de/images/pdf/20190823_EDXF_VFR_AERODROME_CHART.pdf','Operator-source usable-runway evidence; physical pavement and each published landing direction are independent airport fields; hold until effective 2026 AIP checked.','Locate current effective DFS/AIP EDXF runway 11/29 physical/published declared distances; confirm that 1040m RW29 LDA is still valid and if runway physically open. Preserve chart provenance; do not include stopway overruns in runway LDA.'),
('EXPANSION_DE_PAVED_BATCH_06_2026_10_26','OURAIRPORTS:2294','EDXJ','03/21',1450,30,1140,1140,'CURRENT_AIRPORT_OPERATOR','Current airport operator publishes 1450m gross asphalt/concrete-threshold pavement but restricts civil usable takeoff and landing distances to 1140m in BOTH runway directions; only southwest part of former NATO runway in service. Do not use 1450m as a 1450m playable operational runway or assert either end meets direction-specific 1200m landing rule.','https://www.flughafen-husum.de/de/flughafen/daten/startbahn.php','Operator-source usable-runway evidence; physical pavement and each published landing direction are independent airport fields; hold until effective 2026 AIP checked.','Obtain effective 2026 Germany AIP EDXJ declared RW03/21 distances and current civil closure markings; separately adjudicate gross runway-only 1200m collection and civil usability. If both usable ends remain 1140m, mark direction-specific 1200m flight screen failed; no automatic permanent collection rejection.')
ON CONFLICT(batch_key,airport_key) DO NOTHING;

-- Advance only EDWI: current operator confirmed 1459m asphalt, LDA1233m / 1207m.
WITH target AS (
 SELECT r.airport_key,r.source_url,r.evidence_notes,r.next_review_action
 FROM airlinerra.airport_expansion_independent_paved_runway_reviews r
 JOIN airlinerra.airport_cohorts c ON c.airport_key=r.airport_key AND c.cohort='EXPANSION_3906'
 WHERE r.batch_key='EXPANSION_DE_PAVED_BATCH_06_2026_10_26'
 AND r.icao_code='EDWI' AND r.source_authority_grade='CURRENT_AIRPORT_OPERATOR'
 AND r.published_landing_direction_a_m>=1200
 AND r.published_landing_direction_b_m>=1200
 AND NOT EXISTS(SELECT 1 FROM airlinerra.airport_expansion_german_civil_runway_end_holds h
 WHERE h.airport_key=r.airport_key AND h.batch_key=r.batch_key))
UPDATE airlinerra.airport_access_reviews a SET
 identity_status='VERIFIED',paved_runway_status='VERIFIED',
 review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING',
 evidence_url=t.source_url,
 source_review_note='DE Batch06 independent operator physical runway + BOTH directional LDAs verified as published: '||t.evidence_notes||' Next: '||t.next_review_action||' This is not commercial-operation permission or game activation.',
 review_date='2026-10-26',last_updated=now()
FROM target t WHERE a.airport_key=t.airport_key
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
 AND a.game_admission_status='NOT_APPROVED';

-- Move EDXJ to explicit 1140m CIVIL usable-distance hold, not game rejection.
WITH special AS (
 SELECT h.airport_key,h.source_url,h.issue,h.resolution
 FROM airlinerra.airport_expansion_german_civil_runway_end_holds h
 JOIN airlinerra.airport_cohorts c ON c.airport_key=h.airport_key AND c.cohort='EXPANSION_3906'
 WHERE h.batch_key='EXPANSION_DE_PAVED_BATCH_06_2026_10_26'
 AND h.icao_code='EDXJ' AND h.current_source_check='CURRENT_AIRPORT_OPERATOR'
 AND h.source_landing_end_a_m=1140 AND h.source_landing_end_b_m=1140)
UPDATE airlinerra.airport_access_reviews a SET
 identity_status='VERIFIED',review_status='HOLD_CIVIL_RUNWAY_USABLE_DISTANCE_1140M',
 evidence_url=h.source_url,
 source_review_note='German Batch06 operator source: 1450m gross paved vs both civil TORA/LDA1140m. '||h.issue||' Required: '||h.resolution,
 review_date='2026-10-26',last_updated=now()
FROM special h WHERE a.airport_key=h.airport_key
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
 AND a.paved_runway_status='UNVERIFIED' AND a.game_admission_status='NOT_APPROVED';

-- EDXF historical chart + five other unverified sources must remain on generic hold.
-- No original runway registry overwrite, game admission or world activation.
SELECT icao_code,source_authority_grade,research_status
FROM airlinerra.airport_expansion_independent_paved_runway_reviews
WHERE batch_key='EXPANSION_DE_PAVED_BATCH_06_2026_10_26' ORDER BY icao_code;
