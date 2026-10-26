-- Airlinerra German runway physical-screen Batch10, APPLIED 2026-10-26 to PRIVATE research only.
-- Source accuracy grade is multi-source only: NO effective 2026 AIP authenticated,
-- NO permission to operate a real commercial airline, NO approval to release game airports.
-- Old research registry lengths remain intact and all 3140 World1 originals remain live.
CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_de_batch10_multisource_runway_screen(
 batch_key text NOT NULL,
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 airport_code text NOT NULL, runway_pair text NOT NULL,
 physical_paved_screen text NOT NULL
 CHECK (physical_paved_screen='CORROBORATED_GEOMETRY_REQUIRES_EFFECTIVE_AIP_REVALIDATION'),
 source_quality text NOT NULL,
 physical_paved_runway_m numeric NOT NULL CHECK(physical_paved_runway_m>=1200),
 physical_width_m numeric NOT NULL CHECK(physical_width_m>0),
 normalized_surface text NOT NULL CHECK(normalized_surface IN('ASPHALT','CONCRETE')),
 historic_registry_runway_m numeric NOT NULL,
 alternative_published_physical_m numeric,
 published_end_a_lda_m numeric,published_end_b_lda_m numeric,
 lda_source_recency text NOT NULL,
 latest_effective_aip_verified boolean NOT NULL DEFAULT false CHECK(NOT latest_effective_aip_verified),
 physical_source_url text NOT NULL,independent_supporting_url text NOT NULL,third_source_url text,
 runway_provenance_note text NOT NULL,unresolved_aip_or_direction_issue text NOT NULL,
 aircraft_specific_operating_permission boolean NOT NULL DEFAULT false CHECK(NOT aircraft_specific_operating_permission),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 game_world_activation_authorized boolean NOT NULL DEFAULT false CHECK(NOT game_world_activation_authorized),
 checked_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(batch_key,airport_key),UNIQUE(batch_key,airport_code)
);
ALTER TABLE airlinerra.airport_expansion_de_batch10_multisource_runway_screen ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_de_batch10_multisource_runway_screen FROM PUBLIC,anon,authenticated;
DO $before$ BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE active AND world_number=1)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 THEN RAISE EXCEPTION 'Original founding 3140 World 1 airport count has drifted'; END IF;
END $before$;
INSERT INTO airlinerra.airport_expansion_de_batch10_multisource_runway_screen
(batch_key,airport_key,airport_code,runway_pair,physical_paved_screen,source_quality,physical_paved_runway_m,physical_width_m,normalized_surface,historic_registry_runway_m,alternative_published_physical_m,published_end_a_lda_m,published_end_b_lda_m,lda_source_recency,physical_source_url,independent_supporting_url,third_source_url,runway_provenance_note,unresolved_aip_or_direction_issue)
VALUES
('EXPANSION_DE_PHYSICAL_SCREEN_BATCH_10_2026_10_26','OURAIRPORTS:2188','EDAK','11/29','CORROBORATED_GEOMETRY_REQUIRES_EFFECTIVE_AIP_REVALIDATION','MULTIPLE_INDEPENDENT_2026_SECONDARY_CONCRETE_RUNWAY_SOURCES',1415,48,'CONCRETE',1414.9,NULL,NULL,NULL,'DIRECTIONAL_LDA_NOT_AVAILABLE','https://dulv.de/fmwebphp/Flugplatz/details.php?id=840','https://tpm-mediashop.com/pages/edak-grossenhain',NULL,'Two independently accessible 2026 aviation sources report concrete RW11/29 1415x48m; former military runway much longer not taken as civilian runway. Source evidence is SECONDARY and not effective official AIP.','Get current effective DFS AIP or original operator civil runway dimensions and opening status; do not grant game airport or airline rights.'),
('EXPANSION_DE_PHYSICAL_SCREEN_BATCH_10_2026_10_26','OURAIRPORTS:2274','EDTF','16/34','CORROBORATED_GEOMETRY_REQUIRES_EFFECTIVE_AIP_REVALIDATION','2023_AIRAC_IVAO_AND_2011_RESIDENT_CLUB_WITH_ACTIVE_2026_OPERATOR_LDA',1240,30,'ASPHALT',1338.1,1400,1190,1040,'CURRENT_2026_OPERATOR_RW16_RW34_LDA','https://de.ivao.aero/prozeduren/edgg/s/edtf/','https://bvm-freiburg.de/flugplatzdaten/','https://freiburg-airport.de/','IVAO technical guide AIRAC2023 1240x30m asphalt, older on-field club 1400x30m, research registry 1338.1m. All gross paved dimensions >=1200m but disagree; CURRENT operator publishes LDA RW16 1190m and RW34 1040m. No LDA qualifies per-end 1200m flight screen. Operator-specific match-day closure remains separate.','Obtain authoritative 2026 gross paved runway length 1240/1338/1400, and retain RW16 LDA1190 and RW34 LDA1040 as below threshold. Aircraft direction planning blocked.'),
('EXPANSION_DE_PHYSICAL_SCREEN_BATCH_10_2026_10_26','OURAIRPORTS:2293','EDXF','11/29','CORROBORATED_GEOMETRY_REQUIRES_EFFECTIVE_AIP_REVALIDATION','2019_OPERATOR_HOSTED_CHART_PLUS_2026_INDEPENDENT_RUNWAY_LISTINGS',1220,30,'ASPHALT',1220.1,NULL,1220,1040,'HISTORIC_OPERATOR_2019_RW11_RW29_LDA','https://www.flensburger-flughafen.de/images/pdf/20190823_EDXF_VFR_AERODROME_CHART.pdf','https://dulv.de/fmwebphp/Flugplatz/details.php?id=805','https://www.ulforum.de/ultraleicht/flugplatz/flensburg-schaeferhaus/EDXF','Operator-hosted 2019 VFR chart states physical paved bitumen RW11/29 1220x30m and 2019 LDA RW11 1220m / RW29 1040m. 2026 accessible directory shows 1220m asphalt physical but another current community page mislabels 1040m as runway length. Operator infrastructure report 1580m INCLUDES 300m+60m overruns; gross runway only 1220m, not 1580m. Only 20m headroom at 1200m cutoff.','Obtain authoritative 2026 runway paved length excluding overruns. If 1220m historically reported is shortened below 1200, immediately reopen runway-only review; RW29 historic LDA1040 separate.')
ON CONFLICT(batch_key,airport_key) DO NOTHING;
-- Only 3 existing expansion airports may advance on the BASIC physical paved runway screen.
-- Landing distance, current AIP and existing technical special holds remain independent.
WITH eligible AS (
 SELECT s.airport_key,s.physical_source_url,s.runway_provenance_note,s.unresolved_aip_or_direction_issue
 FROM airlinerra.airport_expansion_de_batch10_multisource_runway_screen s
 JOIN airlinerra.airport_cohorts c ON c.airport_key=s.airport_key AND c.cohort='EXPANSION_3906'
 WHERE s.batch_key='EXPANSION_DE_PHYSICAL_SCREEN_BATCH_10_2026_10_26'
 AND s.airport_code IN('EDAK','EDTF','EDXF')
 AND s.physical_paved_screen='CORROBORATED_GEOMETRY_REQUIRES_EFFECTIVE_AIP_REVALIDATION'
 AND s.physical_paved_runway_m>=1200 AND s.normalized_surface IN('ASPHALT','CONCRETE')
 AND s.latest_effective_aip_verified=false AND s.game_admission_status='NOT_APPROVED'
 AND NOT s.aircraft_specific_operating_permission
 AND NOT s.game_world_activation_authorized)
UPDATE airlinerra.airport_access_reviews a SET
 identity_status='VERIFIED',paved_runway_status='VERIFIED',
 review_status='INDEPENDENT_MULTISOURCE_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING',
 evidence_url=s.physical_source_url,
 source_review_note='German Batch10 PHYSICAL PAVED RUNWAY multi-source screening ≥1200m ONLY. 2026 effective aeronautical publication NOT obtained; does NOT clear LDA, thresholds, NOTAM, PPR, airline rights, aircraft suitability or game admission. '||s.runway_provenance_note||' REQUIRED: '||s.unresolved_aip_or_direction_issue,
 review_date='2026-10-26',last_updated=now()
FROM eligible s
WHERE a.airport_key=s.airport_key AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
AND a.paved_runway_status='UNVERIFIED' AND a.game_admission_status='NOT_APPROVED';
-- Acceptance: docs/sql/AIRLINERRA_DE_PHYSICAL_RUNWAY_SCREEN_BATCH_10_TESTS_2026-10-26.sql
