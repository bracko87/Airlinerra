-- German Batch08 SOURCE SNAPSHOT (condensed replay; full evidence notes in report).
-- Recorded against private airlinerra schema on 2026-10-26; no game admission.
-- Six detailed unresolved notes and the two advances are documented in the report.
CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_de_multisource_adjudications(
 batch_key text NOT NULL, airport_key text NOT NULL, airport_code text NOT NULL,
 resolution text NOT NULL CHECK(resolution IN('MULTISOURCE_PAVED_RUNWAY_SCREEN_PASSES_RELEASE_HOLD','CURRENT_OFFICIAL_AIP_OR_OPERATOR_EVIDENCE_STILL_NEEDED')),
 evidence_grade text NOT NULL,runway_pair text,paved_length_m numeric,paved_width_m numeric,
 runway_surface text,primary_evidence_url text NOT NULL,corroboration_url text,
 third_evidence_url text,evidence_summary text NOT NULL,unresolved_question text NOT NULL,
 runways_only_screen_boolean boolean,commercial_permission_verified boolean NOT NULL DEFAULT false CHECK(NOT commercial_permission_verified),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 game_activation_allowed boolean NOT NULL DEFAULT false CHECK(NOT game_activation_allowed),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(batch_key,airport_key),UNIQUE(batch_key,airport_code)
);
ALTER TABLE airlinerra.airport_expansion_de_multisource_adjudications ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_de_multisource_adjudications FROM PUBLIC,anon,authenticated;
INSERT INTO airlinerra.airport_expansion_de_multisource_adjudications
(batch_key,airport_key,airport_code,resolution,evidence_grade,runway_pair,paved_length_m,paved_width_m,runway_surface,primary_evidence_url,corroboration_url,third_evidence_url,runways_only_screen_boolean,evidence_summary,unresolved_question) VALUES
('EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26','OURAIRPORTS:2188','EDAK','CURRENT_OFFICIAL_AIP_OR_OPERATOR_EVIDENCE_STILL_NEEDED','MULTIPLE_SECONDARY_WITHOUT_CURRENT_AUTHORITATIVE_SOURCE','11/29',1415,48,'CONCRETE','https://dulv.de/fmwebphp/Flugplatz/details.php?id=840','https://tpm-mediashop.com/pages/edak-grossenhain',NULL,NULL,'Source-grounded classification; full airport-by-airport evidence and caveats in docs/AIRLINERRA_EXPANSION_DE_MULTISOURCE_BATCH_08_2026-10-26.md','Revalidate current effective German AIP and restrictions before flight-specific or game release.'),
('EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26','OURAIRPORTS:2743','EDBN','CURRENT_OFFICIAL_AIP_OR_OPERATOR_EVIDENCE_STILL_NEEDED','HISTORICAL_2018_GERMAN_AIP_OPERATOR_HOSTED','09/27',2293,45,'CONCRETE','https://www.flughafen-neubrandenburg.de/images/downloads/20211005-edbn-ifr.pdf','https://www.pilotcenter.app/flugplaetze/edbn',NULL,NULL,'Source-grounded classification; full airport-by-airport evidence and caveats in docs/AIRLINERRA_EXPANSION_DE_MULTISOURCE_BATCH_08_2026-10-26.md','Revalidate current effective German AIP and restrictions before flight-specific or game release.'),
('EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26','OURAIRPORTS:2207','EDCP','CURRENT_OFFICIAL_AIP_OR_OPERATOR_EVIDENCE_STILL_NEEDED','MULTIPLE_SECONDARY_WIDTH_AND_RUNWAY_NUMBER_CONFLICT','13/31',2400,NULL,'CONCRETE','https://de.ivao.aero/prozeduren/edww/e/edcp/','https://dulv.de/fmwebphp/Flugplatz/details.php?id=1071','https://www.ulforum.de/ultraleicht/flugplatz/peenemuende/EDCP',NULL,'Source-grounded classification; full airport-by-airport evidence and caveats in docs/AIRLINERRA_EXPANSION_DE_MULTISOURCE_BATCH_08_2026-10-26.md','Revalidate current effective German AIP and restrictions before flight-specific or game release.'),
('EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26','OURAIRPORTS:28553','EDLD','MULTISOURCE_PAVED_RUNWAY_SCREEN_PASSES_RELEASE_HOLD','2026_OPERATOR_LENGTH_PLUS_ON_FIELD_SCHOOL_AND_CLUB_ASPHALT','08/26',1500,30,'ASPHALT','https://schwarze-heide.com/','https://jp-flugschule.de/standorte/','https://gfl-dinslaken.de/angebote/ausbildung',true,'Source-grounded classification; full airport-by-airport evidence and caveats in docs/AIRLINERRA_EXPANSION_DE_MULTISOURCE_BATCH_08_2026-10-26.md','Revalidate current effective German AIP and restrictions before flight-specific or game release.'),
('EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26','OURAIRPORTS:2252','EDMO','CURRENT_OFFICIAL_AIP_OR_OPERATOR_EVIDENCE_STILL_NEEDED','ON_FIELD_FLYING_GROUP_AND_GENERIC_SECONDARY_CURRENT_OPERATOR_NOT_DIMENSIONS','04/22',2286,45,'ASPHALT','https://www.fsg-im-dlr.de/node/49','https://www.edmo-airport.de/flugbetrieb/','https://server.learn-atc.com/de/tools/aerodrome/EDMO',NULL,'Source-grounded classification; full airport-by-airport evidence and caveats in docs/AIRLINERRA_EXPANSION_DE_MULTISOURCE_BATCH_08_2026-10-26.md','Revalidate current effective German AIP and restrictions before flight-specific or game release.'),
('EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26','OURAIRPORTS:2274','EDTF','CURRENT_OFFICIAL_AIP_OR_OPERATOR_EVIDENCE_STILL_NEEDED','OLD_ORGANIZATION_PUBLISHED_1400_VS_SECONDARY_1240_VS_REGISTRY_1338','16/34',NULL,30,'ASPHALT','https://freiburg-airport.de/','https://de.ivao.aero/prozeduren/edgg/s/edtf/','https://bvm-freiburg.de/flugplatzdaten/',NULL,'Source-grounded classification; full airport-by-airport evidence and caveats in docs/AIRLINERRA_EXPANSION_DE_MULTISOURCE_BATCH_08_2026-10-26.md','Revalidate current effective German AIP and restrictions before flight-specific or game release.'),
('EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26','OURAIRPORTS:2293','EDXF','CURRENT_OFFICIAL_AIP_OR_OPERATOR_EVIDENCE_STILL_NEEDED','2022_OPERATOR_BITUMEN_TOTAL_INCLUDES_OVERRUN_2019_CHART_RUNWAY_1220','11/29',1220,30,'ASPHALT','https://www.flensburger-flughafen.de/images/pdf/Entwicklungen-und-Perspektiven-2022.pdf','https://www.flensburger-flughafen.de/images/pdf/20190823_EDXF_VFR_AERODROME_CHART.pdf','https://dulv.de/fmwebphp/Flugplatz/details.php?id=805',NULL,'Source-grounded classification; full airport-by-airport evidence and caveats in docs/AIRLINERRA_EXPANSION_DE_MULTISOURCE_BATCH_08_2026-10-26.md','Revalidate current effective German AIP and restrictions before flight-specific or game release.'),
('EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26','OURAIRPORTS:2726','ETHM','MULTISOURCE_PAVED_RUNWAY_SCREEN_PASSES_RELEASE_HOLD','CURRENT_ON_FIELD_PPR_GROUP_WITH_MUNICIPAL_FORMER_MILITARY_IDENTITY','07/25',1615,35,'ASPHALT','https://sfgmendig.jimdoweb.com/infos-f%C3%BCr-piloten/','https://www.mendig.de/wirtschaft-gewerbe/gewerbe-und-industrie/flugplatz-mendig/','https://www.dulv.de/fmwebphp/Flugplatz/details.php?id=1319',true,'Source-grounded classification; full airport-by-airport evidence and caveats in docs/AIRLINERRA_EXPANSION_DE_MULTISOURCE_BATCH_08_2026-10-26.md','Revalidate current effective German AIP and restrictions before flight-specific or game release.')
ON CONFLICT(batch_key,airport_key) DO NOTHING;
WITH eligible AS(
 SELECT airport_key,primary_evidence_url,evidence_summary,unresolved_question
 FROM airlinerra.airport_expansion_de_multisource_adjudications
 WHERE batch_key='EXPANSION_DE_MULTISOURCE_BATCH_08_2026_10_26'
 AND airport_code IN('EDLD','ETHM')
 AND runways_only_screen_boolean=true
 AND resolution='MULTISOURCE_PAVED_RUNWAY_SCREEN_PASSES_RELEASE_HOLD'
 AND paved_length_m>=1200 AND runway_surface IN('ASPHALT','CONCRETE')
 AND game_admission_status='NOT_APPROVED' AND NOT game_activation_allowed)
UPDATE airlinerra.airport_access_reviews a SET
 identity_status='VERIFIED',paved_runway_status='VERIFIED',
 review_status='INDEPENDENT_MULTISOURCE_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING',
 evidence_url=e.primary_evidence_url,
 source_review_note='German Batch08 independent MULTI-SOURCE paved runway screen, no AIP/airline/game approval. '||e.evidence_summary||' '||e.unresolved_question,
 review_date='2026-10-26',last_updated=now()
FROM eligible e WHERE a.airport_key=e.airport_key
AND a.review_status='HOLD_INDEPENDENT_VERIFICATION'
AND a.paved_runway_status='UNVERIFIED'
AND a.game_admission_status='NOT_APPROVED';
-- This replay intentionally does not overwrite original registry source identifiers,
-- old runway dimensions, production permissions or activation rows.
