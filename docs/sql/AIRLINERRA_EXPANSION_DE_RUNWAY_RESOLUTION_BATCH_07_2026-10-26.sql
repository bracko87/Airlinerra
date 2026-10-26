-- Airlinerra German expansion Batch07, 26 October 2026. REPRODUCIBLE RESEARCH ONLY.
-- Exactly 10 previously generic source-held cases; 2 paved-only source advances
-- and 2 independently held declared-landing-distance source exceptions.
-- Preconditions: airport_expansion_independent_paved_runway_reviews and
-- airport_expansion_german_civil_runway_end_holds created in previous batches.
-- Original registry/runway source, 3140 active foundation and six categories unchanged.
CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_de_runway_resolution_cases(
batch_key text NOT NULL,airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
airport_code text NOT NULL,source_grade text NOT NULL CHECK(source_grade IN(
'OPERATOR_2025_CURRENT_PUBLICATION_WITH_OLDER_TECHNICAL_TABLE',
'CURRENT_AIRPORT_OPERATOR_DOCUMENTED_PHYSICAL','HISTORICAL_OFFICIAL_AIP_CURRENT_RECHECK',
'CURRENT_OR_LOCAL_SECONDARY_WITH_UNRESOLVED_CONFLICT','SECONDARY_WITHOUT_CURRENT_OFFICIAL_RUNWAY',
'ON_FIELD_FLYING_GROUP_OPERATOR_NOT_VERIFIED','DIRECTIONAL_LDA_CONFIRMED_PHYSICAL_SOURCE_UNRESOLVED')),
disposition text NOT NULL CHECK(disposition IN(
'PAVED_RUNWAY_CONFIRMED_LANDING_DIRECTION_EXCEPTION',
'PAVED_RUNWAY_CONFIRMED_DECLARED_DISTANCE_CONFLICT',
'AWAIT_CURRENT_OFFICIAL_PAVED_RUNWAY_EVIDENCE','AWAIT_CURRENT_OFFICIAL_AIP_REVALIDATION',
'AWAIT_PAVEMENT_SUBTYPE_AUTHORITY','AWAIT_OPERATOR_RUNWAY_DIMENSIONS',
'AWAIT_AIRPORT_IDENTITY_CROSSWALK')),
source_url text NOT NULL,supporting_url text,physical_runway_length_m numeric,
physical_runway_width_m numeric,landing_end_a_m numeric,landing_end_b_m numeric,
evidence_summary text NOT NULL,next_source_action text NOT NULL,
game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED'
CHECK(game_admission_status='NOT_APPROVED'),
world_activation_allowed boolean NOT NULL DEFAULT false CHECK(NOT world_activation_allowed),
reviewed_at timestamptz NOT NULL DEFAULT now(),
PRIMARY KEY(batch_key,airport_key),UNIQUE(batch_key,airport_code));
ALTER TABLE airlinerra.airport_expansion_de_runway_resolution_cases ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_de_runway_resolution_cases FROM PUBLIC,anon,authenticated;

DO $guard$ BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE active AND world_number=1)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 THEN RAISE EXCEPTION 'World 1 foundation airport count changed; abort replay'; END IF;
END $guard$;

INSERT INTO airlinerra.airport_expansion_de_runway_resolution_cases
(batch_key,airport_key,airport_code,source_grade,disposition,source_url,supporting_url,physical_runway_length_m,physical_runway_width_m,landing_end_a_m,landing_end_b_m,evidence_summary,next_source_action) VALUES
('EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26','OURAIRPORTS:2188','EDAK','SECONDARY_WITHOUT_CURRENT_OFFICIAL_RUNWAY','AWAIT_CURRENT_OFFICIAL_PAVED_RUNWAY_EVIDENCE','https://dulv.de/fmwebphp/Flugplatz/details.php?id=840','https://tpm-mediashop.com/pages/edak-grossenhain',1415,48,NULL,NULL,'Two aviation directories report RW11/29 concrete 1415x48m, but neither is currently effective airport-operator or DFS AIP source. The runway collection candidate is plausible; review is not authenticated as current.','Obtain directly current Großenhain operator or DFS AIP VFR runway physical specification; preserve secondary grade until sourced.'),
('EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26','OURAIRPORTS:2743','EDBN','HISTORICAL_OFFICIAL_AIP_CURRENT_RECHECK','AWAIT_CURRENT_OFFICIAL_AIP_REVALIDATION','https://www.flughafen-neubrandenburg.de/images/downloads/20211005-edbn-ifr.pdf','https://www.flughafen-neubrandenburg.de/index.php?Itemid=104&catid=2&id=7%3Apiloteninformationen&option=com_content&view=article',2293,45,2293,2293,'Operator-hosted genuine German AIP AD2 runway characteristics effective 6 Dec 2018 records concrete RW09/27 2293x45m and 2293m LDA each way. Current operator explicitly directs pilots to effective AIP and NOTAM, so this historical material is not independently certified as October 2026.','Obtain currently effective DFS AIP AD2 EDBN 2.12/2.13 and reconcile any runway or LDA changes; do not falsely cite 2018 as 2026.'),
('EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26','OURAIRPORTS:2207','EDCP','CURRENT_OR_LOCAL_SECONDARY_WITH_UNRESOLVED_CONFLICT','AWAIT_CURRENT_OFFICIAL_PAVED_RUNWAY_EVIDENCE','https://de.ivao.aero/prozeduren/edww/e/edcp/','https://dulv.de/fmwebphp/Flugplatz/details.php?id=1071',2400,NULL,NULL,NULL,'Secondary sources report concrete RW13/31 length2400m, but source width conflicts 48m vs 60m; no current direct airport operator or national AIP authenticated. Width cannot be silently chosen.','Obtain airport operator or effective DFS AIP runway width and open status, then reconcile 48/60m evidence.'),
('EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26','OURAIRPORTS:2226','EDFE','OPERATOR_2025_CURRENT_PUBLICATION_WITH_OLDER_TECHNICAL_TABLE','PAVED_RUNWAY_CONFIRMED_LANDING_DIRECTION_EXCEPTION','https://egelsbach-airport.com/wp-content/uploads/2025/12/EDFE-Benutzungsordnung-25-11-2025-FinalohneUnterschrift-DE-v1-2.pdf','https://egelsbach-airport.com/wp-content/uploads/2023/08/AIP-VFR-Flugplatzkarte.pdf',1400,25,1400,1166,'Directly verified operator regulation effective 25 Nov 2025, physical runway table labelled state 2014: asphalt RW08/26 1400x25m, RW08 LDA1400m/TORA1166m, RW26 LDA1166m/TORA1400m. Airport-hosted official 24 Aug 2023 DFS chart corroborates 1400x25m physical paved length. Airport-only runway collection eligible; RW26 LDA1166m below 1200m direction-only screening. Retain current effective AIP requirement and operator/aircraft requirements.','Source effective 2026 AIP for EDFE direction-specific published LDA; retain RW26 direction hold. Release game airport only under separate owner approval.'),
('EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26','OURAIRPORTS:28553','EDLD','CURRENT_OR_LOCAL_SECONDARY_WITH_UNRESOLVED_CONFLICT','AWAIT_PAVEMENT_SUBTYPE_AUTHORITY','https://jp-flugschule.de/standorte/','https://tpm-mediashop.com/pages/edld-dinslaken-schwarze-heide',1500,30,NULL,NULL,'Current on-airport certified flying school says runway08/26 asphalt 1500x30m, whereas separate aviation technical publisher and historic database say concrete 1500x30m. BOTH are qualifying material types under the airport-only rule, but exact pavement subtype not established as authoritative by airport operator/AIP. Operator confirms active field/approach including 400m displaced touchdown instruction RW26 for aircraft under 2t; not a published LDA.','Obtain operator-published or effective DFS AIP specific runway pavement material/type. Do not overwrite conflicting source and do not confuse 400m touchdown instruction with LDA.'),
('EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26','OURAIRPORTS:2252','EDMO','ON_FIELD_FLYING_GROUP_OPERATOR_NOT_VERIFIED','AWAIT_OPERATOR_RUNWAY_DIMENSIONS','https://www.fsg-im-dlr.de/node/49','https://www.edmo-airport.de/flugbetrieb/',2286,45,NULL,NULL,'Resident DLR flying group publishes ASPH RW04/22 2286x45m; current airport operator confirms special-use airport and PPR but inspected operator page does not independently publish matching runway measurements. Special-use restriction is separate from physical runway screening.','Confirm dimensions with current EDMO operator technical publication or effective DFS AIP; leave airline access permissions unverified.'),
('EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26','OURAIRPORTS:2273','EDTD','CURRENT_AIRPORT_OPERATOR_DOCUMENTED_PHYSICAL','PAVED_RUNWAY_CONFIRMED_DECLARED_DISTANCE_CONFLICT','https://donau-airport.de/piloteninformationen/','https://dulv.de/fmwebphp/Flugplatz/details.php?id=766',1200,30,1290,1200,'Current owner operator explicitly lists RW18/36 ASPH gross physical 1200x30m (exactly runway-only minimum), but published RW18 LDG1290m and RW36 LDG1200m contradict the listed gross length and existing registry length1289.9m. Verify *physical airport-collection threshold only*; do NOT claim a valid 1290m landing length until current AIP reconciles contradictions.','Get current effective DFS AIP EDTD 18/36 runway dimensions and LDA, reconcile operator text/registry. Keep declared distance inconsistency documented; no flight-specific approval.'),
('EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26','OURAIRPORTS:2274','EDTF','DIRECTIONAL_LDA_CONFIRMED_PHYSICAL_SOURCE_UNRESOLVED','AWAIT_CURRENT_OFFICIAL_PAVED_RUNWAY_EVIDENCE','https://freiburg-airport.de/','https://de.ivao.aero/prozeduren/edgg/s/edtf/',NULL,NULL,1190,1040,'Current airport operator explicitly gives RW16 LDA1190m and RW34 LDA1040m (both below 1200m direction-only screen), while last airport physical length reported variously 1240m/1338.1m/1400m by secondary and older sources. Exact current physical source remains unverified; airport-only eligibility cannot be rejected merely on shorter LDA.','Obtain current official operator or DFS AIP physical RW16/34 length/surface/width; preserve separate direction-only failure.'),
('EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26','OURAIRPORTS:2293','EDXF','HISTORICAL_OFFICIAL_AIP_CURRENT_RECHECK','AWAIT_CURRENT_OFFICIAL_AIP_REVALIDATION','https://www.flensburger-flughafen.de/images/pdf/20190823_EDXF_VFR_AERODROME_CHART.pdf','https://de.ivao.aero/prozeduren/edww/w/edxf/',1220,30,1220,1040,'Operator-hosted aerodrome chart dated 2019 identifies RW11/29 bitumen 1220x30m, landing distances 1220m /1040m; secondary 2021 IVAO corroborates. Current effective AIP needed. Physical length only 20m above requirement; RW29 1040m LDA failed historical direction screen. Displaced threshold/overruns not eligible physical runway additions.','Confirm 2026 DFS VFR AIP current physical runway 1220m asphalt/bitumen and RW29 LDA; do not auto-promote from 2019.'),
('EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26','OURAIRPORTS:2726','ETHM','ON_FIELD_FLYING_GROUP_OPERATOR_NOT_VERIFIED','AWAIT_AIRPORT_IDENTITY_CROSSWALK','https://sfgmendig.jimdoweb.com/infos-f%C3%BCr-piloten/','https://dulv.de/fmwebphp/Flugplatz/details.php?id=1319',1615,35,NULL,NULL,'Resident group handling flight PPR confirms current ASPH runway07/25 1615x35m and ICAO code EDRE. Legacy source_ident ETHM is old historical military identity while source_gps_code EDRE, registry size1628.2m. This is an airport-identity crosswalk to resolve without changing stable master key. PPR and aircraft class are separate from runway-only eligibility.','Create source-specific historical ETHM->EDRE identity alias after current AIP/airport operator validation; preserve stable airport key, do not falsely match a different airport.')
ON CONFLICT(batch_key,airport_key) DO NOTHING;

INSERT INTO airlinerra.airport_expansion_independent_paved_runway_reviews
(batch_key,airport_key,icao_code,research_status,source_authority_grade,paved_runway_pair,documented_physical_length_m,documented_width_m,normalized_surface,published_landing_direction_a_m,published_landing_direction_b_m,historic_registry_length_m,source_url,supporting_url,evidence_notes,next_review_action) VALUES
('EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26','OURAIRPORTS:2226','EDFE','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','08/26',1400,25,'ASPHALT',1400,1166,1399.9,'https://egelsbach-airport.com/wp-content/uploads/2025/12/EDFE-Benutzungsordnung-25-11-2025-FinalohneUnterschrift-DE-v1-2.pdf','https://egelsbach-airport.com/wp-content/uploads/2023/08/AIP-VFR-Flugplatzkarte.pdf','Direct operator regulation effective Nov 25 2025 (runway technical table labelled May 1 2014) plus airport-hosted 2023 DFS chart confirms asphalt RW08/26 physical 1400x25m, with LDA RW08 1400m and LDA RW26 1166m. Runway qualifies airport-only paved physical collection; RW26 fails 1200m direction-specific landing requirement. Source updates and flight-date permissions separate.','Verified physical asphalt runway only. Keep separately recorded directional landing limitations/conflicts and owner-controlled future game release. Check latest AIP before aircraft-level operation.'),
('EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26','OURAIRPORTS:2273','EDTD','OPERATOR_RUNWAY_INDEPENDENTLY_CONFIRMED_RELEASE_HOLD','CURRENT_AIRPORT_OPERATOR','18/36',1200,30,'ASPHALT',1290,1200,1289.9,'https://donau-airport.de/piloteninformationen/','https://dulv.de/fmwebphp/Flugplatz/details.php?id=766','Current Donau operator primary page physical runway 18/36 asphalt 1200x30m meets physical airport-only minimum exactly, but LDA RW18 listed 1290m exceeds that runway length, while registry lists 1289.9m. Preserve direction declared-distance contradiction and request corrected AIP before aircraft flight operations.','Verified physical asphalt runway only. Keep separately recorded directional landing limitations/conflicts and owner-controlled future game release. Check latest AIP before aircraft-level operation.')
ON CONFLICT(batch_key,airport_key) DO NOTHING;

INSERT INTO airlinerra.airport_expansion_german_civil_runway_end_holds
(batch_key,airport_key,icao_code,runway_pair,source_physical_length_m,source_width_m,source_landing_end_a_m,source_landing_end_b_m,current_source_check,issue,source_url,evidence_note,resolution) VALUES
('EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26','OURAIRPORTS:2226','EDFE','08/26',1400,25,1400,1166,'CURRENT_AIRPORT_OPERATOR','Airport operator regulation effective Nov25 2025, technical table dated May2014, explicitly publishes RW08 LDA1400m and RW26 LDA1166m. RW26 is below Airlinerra 1200m direction-only landing screen despite gross physical asphalt runway 1400m. Airport technical runway collection passes independently of this landing direction.','https://egelsbach-airport.com/wp-content/uploads/2025/12/EDFE-Benutzungsordnung-25-11-2025-FinalohneUnterschrift-DE-v1-2.pdf','Specific direction-only landing evidence issue retained alongside verified physical runway-length data.','Obtain currently effective DFS AIP/NOTAM to confirm RW26 usable landing 1166m; keep RW26 blocked from 1200m-aircraft landing screen unless new source changes; runway-only airport collection remains physically qualified.'),
('EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26','OURAIRPORTS:2273','EDTD','18/36',1200,30,1290,1200,'CURRENT_AIRPORT_OPERATOR','Operator currently publishes runway asphalt 1200m but also RW18 landing1290m, which exceeds stated physical runway. Old registry has 1289.9m; these cannot be treated as reconciled declared distances. Physical 1200m threshold only has independent operator confirmation, while directional landing distances require manual AIP reconciliation.','https://donau-airport.de/piloteninformationen/','Specific direction-only landing evidence issue retained alongside verified physical runway-length data.','Obtain effective German AIP EDTD AD2 declared distances and physical geometry or written airport correction to resolve length discrepancy; do not publish 1290m as officially reconciled landing allowance.')
ON CONFLICT(batch_key,airport_key) DO NOTHING;

-- Only confirm runway PHYSICAL paved evidence for EDFE and EDTD. Their
-- restricted/unreconciled usable landing distances remain in the held table.
WITH eligible AS (SELECT v.airport_key,v.source_url,v.evidence_notes,v.next_review_action
 FROM airlinerra.airport_expansion_independent_paved_runway_reviews v
 JOIN airlinerra.airport_expansion_de_runway_resolution_cases rs
 ON rs.batch_key=v.batch_key AND rs.airport_key=v.airport_key
 JOIN airlinerra.airport_expansion_german_civil_runway_end_holds h
 ON h.batch_key=v.batch_key AND h.airport_key=v.airport_key
 JOIN airlinerra.airport_cohorts cohort ON cohort.airport_key=v.airport_key
 AND cohort.cohort='EXPANSION_3906'
 WHERE v.batch_key='EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26'
 AND v.icao_code IN ('EDFE','EDTD')
 AND v.documented_physical_length_m>=1200
 AND v.normalized_surface='ASPHALT'
 AND v.source_authority_grade='CURRENT_AIRPORT_OPERATOR'
 AND h.game_admission_status='NOT_APPROVED'
 AND rs.game_admission_status='NOT_APPROVED')
UPDATE airlinerra.airport_access_reviews a SET
 identity_status='VERIFIED',paved_runway_status='VERIFIED',
 review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING',
 evidence_url=e.source_url,
 source_review_note='German resolution Batch07: OPERATOR CONFIRMS GROSS PAVED RUNWAY ONLY. DIRECTION-SPECIFIC LDA EXCEPTION REMAINS ACTIVE AND MUST NOT BE INTERPRETED AS A LANDING APPROVAL. '||e.evidence_notes||' Next: '||e.next_review_action,
 review_date='2026-10-26',last_updated=now()
FROM eligible e WHERE a.airport_key=e.airport_key
 AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
 AND a.game_admission_status='NOT_APPROVED'
 AND a.paved_runway_status='UNVERIFIED';

-- Final states are research-only; no activation rows or public table grants.
SELECT airport_code,disposition FROM airlinerra.airport_expansion_de_runway_resolution_cases
WHERE batch_key='EXPANSION_DE_RESOLUTION_BATCH_07_2026_10_26' ORDER BY airport_code;
