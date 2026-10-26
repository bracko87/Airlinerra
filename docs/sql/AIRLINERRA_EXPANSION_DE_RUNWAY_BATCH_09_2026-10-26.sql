-- AIRLINERRA PRIVATE RESEARCH ONLY: German Batch09, applied 2026-10-26.
-- Six further runway evidence cases, TWO multi-source paved screen advances,
-- ONE time-limited EDCP aerodrome closure, THREE unresolved runway source holds.
-- NOTAM source is NOTAMInfo PIB derived from EAD, NOT an official AIS briefing.
-- Official DFS separate ED-R Peenemünde airspace restrictions through 2028.
-- No game releases, no public privileges, no source-identity overwrite.
CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_de_batch09_airport_evidence(
 batch_key text NOT NULL,
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 airport_code text NOT NULL,runway_pair text,
 documented_paved_length_m numeric,documented_paved_width_m numeric,
 pavement_type text CHECK(pavement_type IN('ASPHALT','CONCRETE','BITUMEN')),
 evidence_grade text NOT NULL,
 runway_screen_decision text NOT NULL CHECK(runway_screen_decision IN(
 'MULTISOURCE_PAVED_PHYSICAL_RUNWAY_CONFIRMED',
 'PHYSICAL_RUNWAY_NEEDS_CURRENT_SOURCE',
 'TEMPORARY_CLOSURE_OVERRIDES_COLLECTION_RELEASE')),
 primary_evidence_url text NOT NULL,corroboration_url text,third_source_url text,
 runway_evidence_note text NOT NULL,unresolved_next_action text NOT NULL,
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 world_activation_allowed boolean NOT NULL DEFAULT false CHECK(NOT world_activation_allowed),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(batch_key,airport_key),UNIQUE(batch_key,airport_code));
ALTER TABLE airlinerra.airport_expansion_de_batch09_airport_evidence ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_de_batch09_airport_evidence FROM PUBLIC,anon,authenticated;
CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_de_temp_airfield_closure_watch(
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 notam_reference text NOT NULL,issuer_data_origin text NOT NULL,
 reported_start_utc timestamp without time zone NOT NULL,
 reported_end_utc timestamp without time zone NOT NULL,
 daily_windows_utc text NOT NULL,aerodrome_closed_during_windows boolean NOT NULL CHECK(aerodrome_closed_during_windows),
 airspace_restriction_from date NOT NULL,airspace_restriction_to date NOT NULL,
 reporting_source_url text NOT NULL,airspace_authority_url text NOT NULL,
 followup_utc_date date NOT NULL,detail_note text NOT NULL,
 latest_review_status text NOT NULL DEFAULT 'TEMPORARY_CLOSURE_REVIEW_REQUIRED'
 CHECK(latest_review_status='TEMPORARY_CLOSURE_REVIEW_REQUIRED'),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 world_activation_allowed boolean NOT NULL DEFAULT false CHECK(NOT world_activation_allowed),
 checked_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(airport_key,notam_reference),
 CHECK(reported_start_utc<reported_end_utc),CHECK(airspace_restriction_from<=airspace_restriction_to));
ALTER TABLE airlinerra.airport_expansion_de_temp_airfield_closure_watch ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_de_temp_airfield_closure_watch FROM PUBLIC,anon,authenticated;
DO $before$ BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE active AND world_number=1)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 THEN RAISE EXCEPTION 'Protected founding 3140 game airport pool drifted'; END IF;
END $before$;
INSERT INTO airlinerra.airport_expansion_de_batch09_airport_evidence
 (batch_key,airport_key,airport_code,runway_pair,documented_paved_length_m,documented_paved_width_m,pavement_type,evidence_grade,runway_screen_decision,primary_evidence_url,corroboration_url,third_source_url,runway_evidence_note,unresolved_next_action) VALUES
('EXPANSION_DE_RUNWAY_BATCH_09_2026_10_26','OURAIRPORTS:2188','EDAK','11/29',1415,48,'CONCRETE','2026_SECONDARY_TECHNICAL_PLUS_OLDER_DIRECTORY','PHYSICAL_RUNWAY_NEEDS_CURRENT_SOURCE','https://tpm-mediashop.com/pages/edak-grossenhain','https://dulv.de/fmwebphp/Flugplatz/details.php?id=840','https://www.grossenhain.de/informationsbroschueren.html','TPM publisher dated Aug 2026 and independent UL airfield directory both report concrete 1415x48m; municipal historical account describes much longer former military runway and cannot establish currently permitted length. Current operator official runway declaration not reachable.','Retrieve effective 2026 German AIP or directly dated EDAK operator dimensional publication; do not substitute historic military 2440m runway for present 1415m civil pavement.'),
('EXPANSION_DE_RUNWAY_BATCH_09_2026_10_26','OURAIRPORTS:2743','EDBN','09/27',2293,45,'CONCRETE','ORIGINAL_2018_GERMAN_AIP_PLUS_2026_INDEPENDENT_DIRECTORY_AND_OPERATOR_ACTIVE','MULTISOURCE_PAVED_PHYSICAL_RUNWAY_CONFIRMED','https://www.flughafen-neubrandenburg.de/images/downloads/20211005-edbn-ifr.pdf','https://www.pilotcenter.app/flugplaetze/edbn','https://www.flughafen-neubrandenburg.de/','Original airport-hosted German AIP publication effective 2018 confirms concrete 09/27 2293x45m; currently available 2026 independent airport-pilot directory repeats same physical runway and operator official site remains active. Strong multiyear concordance supports runway-only collection, but effective 2026 AIP/NOTAM and current aircraft flight authorization have NOT been checked. This is not classified as latest-AIP current confirmation.','Obtain effective 2026 DFS AIP to verify runway geometry and current operative status, flight restrictions and landing distances. Never represent 2018 AD2 as current.'),
('EXPANSION_DE_RUNWAY_BATCH_09_2026_10_26','OURAIRPORTS:2207','EDCP','13/31',2400,NULL,'CONCRETE','2021_AVIATION_GUIDE_PLUS_2026_NOTAM_TEMPORARY_AD_CLOSED','TEMPORARY_CLOSURE_OVERRIDES_COLLECTION_RELEASE','https://www.notaminfo.com/latest?country=Germany','https://www.dfs.de/homepage/de/medien/ifr-vfr-informationen/vfr-informationen/gebiet-mit-flugbeschraenkungen-vom-08-januar-2026-bis-31-dezember-2028-forschungsprojekt-polaris/','https://de.ivao.aero/prozeduren/edww/e/edcp/','NOTAM E4380/26 retrieved from unofficial EAD-derived briefing issued 26-Oct-2026: AD CLSD for research flights scheduled DAILY 0700-1100 and 1215-1700 UTC during Oct26-31. Official DFS also documents ED-R Peenemünde airspace restriction Jan2026-Dec2028. Separate physical concrete RW13/31 2400m supported in older IVAO and DULV, but pavement width conflicts 48/60m. Do not classify permanently closed or permanently runway-disqualified; time-limited closure currently blocks admission and flight-level screening.','Recheck official AIS/NOTAM on Nov1 2026 after E4380/26 expiry; independently verify EDCP operator/AIP actual paved width and airspace restriction, track new NOTAM extensions. Keep NOT_APPROVED.'),
('EXPANSION_DE_RUNWAY_BATCH_09_2026_10_26','OURAIRPORTS:2252','EDMO','04/22',2286,45,'ASPHALT','2024_PROFESSIONAL_LIDO_CHART_PLUS_RESIDENT_GROUP_AND_CURRENT_OPERATOR','MULTISOURCE_PAVED_PHYSICAL_RUNWAY_CONFIRMED','https://www.fsg-im-dlr.de/node/49','https://randomflightdatabase.fr/cartes/Lido1/EDMO.pdf','https://www.edmo-airport.de/flugbetrieb/','Current airport operator maintains special-use active airfield PPR and aviation operations. Resident DLR flight group gives asphalt 04/22 2286x45m; professional Lido aviation chart effective May2 2024 independently gives 2286x45m. Physical paved runway is well above 1200m and corroborated by independent aviation chart, but actual latest AIP declaration not obtained. Airport special use does NOT imply public airline/commercial permission.','Retrieve current DFS AIP and operator-published runway pavement technical details; keep special-use PPR aircraft authorization independent of basic game airport collection.'),
('EXPANSION_DE_RUNWAY_BATCH_09_2026_10_26','OURAIRPORTS:2274','EDTF','16/34',NULL,30,'ASPHALT','2025_IVAO_1240_VS_2011_RESIDENT_1400_AND_LEGACY_REGISTRY_1338','PHYSICAL_RUNWAY_NEEDS_CURRENT_SOURCE','https://freiburg-airport.de/','https://de.ivao.aero/prozeduren/edgg/s/edtf/','https://bvm-freiburg.de/flugplatzdaten/','Current 2026 operator confirms RW16 LDA1190 and RW34 LDA1040, both below optional directional landing length threshold, but no gross physical runway figure published on inspected current page. 2023 AIRAC in 2025 updated IVAO page quotes asphalt 1240x30, 2011 resident club quotes 1400x30, legacy registry 1338.1. With minimum figure only 40m above 1200, current authoritative physical measurement needed. Sports match day closures add time-specific restrictions.','Seek 2026 operator/DFS AD runway physical 16/34 asphalt length; retain RW16/34 published short LDAs separately and home football match closures. No game release.'),
('EXPANSION_DE_RUNWAY_BATCH_09_2026_10_26','OURAIRPORTS:2293','EDXF','11/29',1220,30,'BITUMEN','2022_OPERATOR_INFRASTRUCTURE_DOC_AND_2019_AIRFIELD_CHART_VS_2026_ALT_SOURCE_1040','PHYSICAL_RUNWAY_NEEDS_CURRENT_SOURCE','https://www.flensburger-flughafen.de/images/pdf/Entwicklungen-und-Perspektiven-2022.pdf','https://www.flensburger-flughafen.de/images/pdf/20190823_EDXF_VFR_AERODROME_CHART.pdf','https://www.ulforum.de/ultraleicht/flugplatz/flensburg-schaeferhaus/EDXF','Airport operator 2022 says 1580m BITUMEN INCLUDING runway overruns; operator-hosted 2019 airfield chart gives actual 1220x30 bitumen runway. Current community airport source gives 1040m (likely one landing/TORA end) while 2021 aviation guide notes RW29 LDA1040. Historic 1220 physical runway only 20m above 1200, effective runway-only pavement count cannot include 1580m total overrun. Must obtain current source, not claim airport physically fails on 1040m direction field.','Confirm current 2026 DFS AIP physical RW11/29 BITUMEN length excluding overruns and current runway-open status; keep RW29 1040m LDA as separate historic direction limitation.')
ON CONFLICT(batch_key,airport_key) DO NOTHING;
INSERT INTO airlinerra.airport_expansion_de_temp_airfield_closure_watch
 (airport_key,notam_reference,issuer_data_origin,reported_start_utc,reported_end_utc,daily_windows_utc,aerodrome_closed_during_windows,airspace_restriction_from,airspace_restriction_to,reporting_source_url,airspace_authority_url,followup_utc_date,detail_note) VALUES
('OURAIRPORTS:2207','E4380/26','EAD / EUROCONTROL FROM UNOFFICIAL NOTAMINFO PIB 2026-10-26 10:05 UTC','2026-10-26 07:00:00','2026-10-31 17:00:00','DAILY 07:00-11:00 and 12:15-17:00 UTC',true,'2026-01-08','2028-12-31','https://www.notaminfo.com/latest?country=Germany','https://www.dfs.de/homepage/de/medien/ifr-vfr-informationen/vfr-informationen/gebiet-mit-flugbeschraenkungen-vom-08-januar-2026-bis-31-dezember-2028-forschungsprojekt-polaris/','2026-11-01','NOTAM E4380/26 is a time-bounded AD CLOSED during test/research flight windows, NOT a permanent runway closure. Official DFS separate ED-R Peenemünde restriction lasts 2026-01-08 through 2028-12-31, actual activity notified by NOTAM. Requery authoritative NOTAM / official AIP before any reactivation or future simulated airport release. Runway width/pavement still independently disputed.')
ON CONFLICT(airport_key,notam_reference) DO NOTHING;
-- EDBN and EDMO: only independently corroborated paved-runway physical screen;
-- operator-specific permissions, CURRENT AIP and gameplay release are separate.
WITH eligible AS(
 SELECT e.airport_key,e.primary_evidence_url,e.runway_evidence_note,e.unresolved_next_action
 FROM airlinerra.airport_expansion_de_batch09_airport_evidence e
 JOIN airlinerra.airport_cohorts c ON c.airport_key=e.airport_key AND c.cohort='EXPANSION_3906'
 WHERE e.batch_key='EXPANSION_DE_RUNWAY_BATCH_09_2026_10_26'
 AND e.airport_code IN('EDBN','EDMO')
 AND e.runway_screen_decision='MULTISOURCE_PAVED_PHYSICAL_RUNWAY_CONFIRMED'
 AND e.documented_paved_length_m>=1200 AND e.pavement_type IN('ASPHALT','CONCRETE')
 AND e.game_admission_status='NOT_APPROVED' AND NOT e.world_activation_allowed
)
UPDATE airlinerra.airport_access_reviews a SET
 identity_status='VERIFIED',paved_runway_status='VERIFIED',
 review_status='INDEPENDENT_MULTISOURCE_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING',
 evidence_url=e.primary_evidence_url,
 source_review_note='German Batch09 MULTI-SOURCE physical paved runway screening only. Effective 2026 AIP, airline commercial permission and game release NOT approved: '||e.runway_evidence_note||' NEXT: '||e.unresolved_next_action,
 review_date='2026-10-26',last_updated=now()
FROM eligible e WHERE a.airport_key=e.airport_key
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
 AND a.paved_runway_status='UNVERIFIED'
 AND a.game_admission_status='NOT_APPROVED';
-- EDCP: move from general source hold to named temporary NOTAM closure,
-- while retaining UNVERIFIED physical pavement and no permanent rejection.
WITH t AS (
 SELECT h.airport_key,h.reporting_source_url,h.daily_windows_utc
 FROM airlinerra.airport_expansion_de_temp_airfield_closure_watch h
 JOIN airlinerra.airport_expansion_de_batch09_airport_evidence e ON e.airport_key=h.airport_key
 JOIN airlinerra.airport_cohorts c ON c.airport_key=h.airport_key AND c.cohort='EXPANSION_3906'
 WHERE e.batch_key='EXPANSION_DE_RUNWAY_BATCH_09_2026_10_26'
 AND e.airport_code='EDCP' AND h.notam_reference='E4380/26'
 AND e.runway_screen_decision='TEMPORARY_CLOSURE_OVERRIDES_COLLECTION_RELEASE'
 AND h.game_admission_status='NOT_APPROVED')
UPDATE airlinerra.airport_access_reviews a SET
 review_status='HOLD_TEMPORARY_EDCP_AERODROME_CLOSURE_NOTAM_E4380_26',
 evidence_url=t.reporting_source_url,
 source_review_note='German Batch09 EDCP NOTAM E4380/26: aerodrome closed Oct26-Oct31 only during specific daily windows '||t.daily_windows_utc||
 '. Official DFS separate ED-R restrictions extend through Dec31 2028. Recheck official AIS NOTAM after Oct31, do not auto-reject airport or auto-clear restriction. Pavement width source conflict persists.',
 review_date='2026-10-26',last_updated=now()
FROM t WHERE a.airport_key=t.airport_key
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
 AND a.game_admission_status='NOT_APPROVED'
 AND a.paved_runway_status='UNVERIFIED';
-- EDAK / EDTF / EDXF remain on generic source hold.
-- Postcondition check in docs/sql/AIRLINERRA_EXPANSION_DE_RUNWAY_BATCH_09_TESTS_2026-10-26.sql
