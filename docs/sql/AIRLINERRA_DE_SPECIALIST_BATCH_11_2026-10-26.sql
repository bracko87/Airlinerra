-- Airlinerra DE expansion specialist Batch11, applied to private Supabase 2026-10-26.
-- Current Airlinerra runway-only collection rule: >=1200m physically operational
-- asphalt or concrete runway; civilian access and usable LDAs are DIFFERENT gates.
-- EDMB fails on current operator-reported 980m runway pending effective AIP.
-- EDXJ physically passes 1450m; civil TORA/LDA 1140m remain barred for landing screening.
-- EDCP physically evidenced 2400m concrete but temporary NOTAM E4380/26
-- and exact runway width remain held; recheck AFTER scheduled Oct31 expiry.
CREATE TABLE IF NOT EXISTS airlinerra.airport_expansion_de_specialist_batch11_decisions(
 batch_key text NOT NULL,
 airport_key text NOT NULL REFERENCES airlinerra.airport_registry(airport_key),
 airport_code text NOT NULL,
 decision text NOT NULL CHECK(decision IN(
 'PROVISIONAL_BELOW_1200_OPERATOR_RUNWAY_AIP_RECONCILIATION',
 'PHYSICAL_PAVED_RUNWAY_PASS_CIVIL_LDA_1140_BOTH_ENDS',
 'PHYSICAL_PAVED_RUNWAY_CORROBORATED_TEMP_NOTAM_HOLD')),
 operator_or_source_physical_m numeric NOT NULL CHECK(operator_or_source_physical_m>0),
 pavement_width_m numeric,runway_pair text NOT NULL,
 surface text NOT NULL CHECK(surface IN('ASPHALT','CONCRETE')),
 historical_registry_length_m numeric NOT NULL,
 direction_a_lda_m numeric,direction_b_lda_m numeric,
 physical_collection_screen_pass boolean NOT NULL,
 temporary_or_civil_operational_hold boolean NOT NULL,
 authority_grade text NOT NULL,primary_url text NOT NULL,independent_url text NOT NULL,
 secondary_url text,evidence_note text NOT NULL,outstanding_aip_action text NOT NULL,
 notam_reference text,revisit_on date,
 latest_effective_aip_verified boolean NOT NULL DEFAULT false CHECK(NOT latest_effective_aip_verified),
 aircraft_flight_approval boolean NOT NULL DEFAULT false CHECK(NOT aircraft_flight_approval),
 game_admission_status text NOT NULL DEFAULT 'NOT_APPROVED' CHECK(game_admission_status='NOT_APPROVED'),
 game_activation_authorized boolean NOT NULL DEFAULT false CHECK(NOT game_activation_authorized),
 reviewed_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(batch_key,airport_key),UNIQUE(batch_key,airport_code),
 CHECK(decision<>'PROVISIONAL_BELOW_1200_OPERATOR_RUNWAY_AIP_RECONCILIATION'
 OR (operator_or_source_physical_m<1200 AND NOT physical_collection_screen_pass)),
 CHECK(decision<>'PHYSICAL_PAVED_RUNWAY_PASS_CIVIL_LDA_1140_BOTH_ENDS'
 OR (operator_or_source_physical_m>=1200 AND physical_collection_screen_pass
 AND direction_a_lda_m=1140 AND direction_b_lda_m=1140 AND temporary_or_civil_operational_hold)),
 CHECK(decision<>'PHYSICAL_PAVED_RUNWAY_CORROBORATED_TEMP_NOTAM_HOLD'
 OR (operator_or_source_physical_m>=1200 AND physical_collection_screen_pass
 AND temporary_or_civil_operational_hold AND notam_reference IS NOT NULL AND revisit_on IS NOT NULL))
);
ALTER TABLE airlinerra.airport_expansion_de_specialist_batch11_decisions ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra.airport_expansion_de_specialist_batch11_decisions FROM PUBLIC,anon,authenticated;
DO $founder$ BEGIN
 IF (SELECT count(*) FROM airlinerra.airport_world_activation WHERE world_number=1 AND active)<>3140
 OR (SELECT count(*) FROM airlinerra.airport_game_world1_registration_source)<>3140
 OR EXISTS(SELECT 1 FROM airlinerra.airport_world_activation WHERE world_number<>1)
 THEN RAISE EXCEPTION 'Protected game-world foundational scope drift'; END IF;
END $founder$;
INSERT INTO airlinerra.airport_expansion_de_specialist_batch11_decisions(batch_key,airport_key,airport_code,decision,operator_or_source_physical_m,pavement_width_m,runway_pair,surface,historical_registry_length_m,direction_a_lda_m,direction_b_lda_m,physical_collection_screen_pass,temporary_or_civil_operational_hold,authority_grade,primary_url,independent_url,secondary_url,evidence_note,outstanding_aip_action,notam_reference,revisit_on) VALUES
('EXPANSION_DE_SPECIALIST_BATCH_11_2026_10_26','OURAIRPORTS:2207','EDCP','PHYSICAL_PAVED_RUNWAY_CORROBORATED_TEMP_NOTAM_HOLD',2400,48,'13/31','CONCRETE',2400,NULL,NULL,true,true,'MULTIPLE_INDEPENDENT_RUNWAY_SOURCES_PLUS_2026_TEMPORARY_NOTAM_UNOFFICIAL_EAD_BRIEFING','https://de.ivao.aero/prozeduren/edww/e/edcp/','https://dulv.de/fmwebphp/Flugplatz/details.php?id=1071','https://www.notaminfo.com/latest?country=Germany','EDCP Peenemuende multiple aviation sources agree that RW13/31 concrete is physically 2400m but conflict on width: IVAO 48m and DULV 60m; the 48m physical width here is a SOURCE OBSERVATION, NOT final certified value. EAD-derived unofficial briefing reproduces NOTAM E4380/26 AD CLSD 2026-10-26 through 2026-10-31 during daily UTC windows 0700-1100 and 1215-1700; separate official DFS Polaris ED-R restricted airspace exists through 2028 but is NOT continuous AD closure. The runway physically passes 1200m paved collection, but time-limited NOTAM prevents treating it as currently unrestricted. Temporary hold and current AIP access checks retained.','Recheck authoritative DFS AIS NOTAM and runway data no earlier than 2026-11-01 for E4380/26 cancellation/extension or replacement, current runway open status, physical width and separate ED-R activity. Maintain the central specific temporary closure hold until verified; do not automatically clear on date.','E4380/26','2026-11-01'),
('EXPANSION_DE_SPECIALIST_BATCH_11_2026_10_26','OURAIRPORTS:2249','EDMB','PROVISIONAL_BELOW_1200_OPERATOR_RUNWAY_AIP_RECONCILIATION',980,23,'04/22','ASPHALT',1314.9,780,980,false,true,'CURRENT_2026_OPERATOR_WITH_DULV_SECONDARY_CORROBORATION_OLD_OURAIRPORTS_CONFLICT','https://www.edmb.de/fur-piloten/an-abflug/','https://dulv.de/fmwebphp/Flugplatz/details.php?id=1366','https://ourairports.com/airports/EDMB/runways.html','Biberach airport operator current 2026 page and airport''s 2025 AERO event page report single operational asphalt runway 04/22 980x23m, with RW04 LDA780m and RW22 LDA980m. DULV independently agrees on 980m. Historic OurAirports runway raw record labels 1315m, likely inherited overlong physical/source dimension and needs proven reconciliation. Operator does NOT currently identify another >=1200m operational paved runway. 980m is below 1200m basic airport-only runway minimum; this is a provisional eligibility failure, not a permanent rejection of the airport identity.','Obtain current effective 2026 German AIP EDMB physical runway 04/22 and investigate any alternate qualifying paved runway or legally counted threshold/strip with dated original source. If no runway of >=1200m is established, recommend formal exclusion of EDMB from expansion candidate releases. Preserve original 1314.9m source record and separate error evidence.',NULL,NULL),
('EXPANSION_DE_SPECIALIST_BATCH_11_2026_10_26','OURAIRPORTS:2294','EDXJ','PHYSICAL_PAVED_RUNWAY_PASS_CIVIL_LDA_1140_BOTH_ENDS',1450,30,'03/21','ASPHALT',1449.9,1140,1140,true,true,'CURRENT_AIRPORT_OPERATOR_PHYSICAL_RUNWAY_1450_PUBLISHED_CIVIL_LDA_1140','https://www.flughafen-husum.de/de/flughafen/daten/startbahn.php','https://www.sfg-husum.de/flugplatz1-sfg.html','https://www.flughafen-husum.de/de/flughafen/daten/zulassung.php','Current airport operator states RW03/21 paved physical 1450x30m asphalt with anti-skid (RW03 end concrete), while only 1140m between civil thresholds and published civil TORA/LDA 1140m. Husum flying group independently repeats 1450 gross and 1140 usable. Airport-only collection under AGENTS.md requires >=1200m paved runway and does not require civilian access/suitability at this stage; the gross runway physical screen therefore passes. BOTH published 1140m civil landing direction constraints stay in the existing specialist hold table, and separate unusable former military runway portion is not available for aircraft operations. Never equate 1450 gross with available flight LDA.','Obtain current effective German AIP EDXJ declared civil distances and runway geometry, keep both landing directions barred from a 1200m landing-distance screen while 1140m data stands, and check permanent markings/fence and PPR. Game and commercial releases remain NOT_APPROVED.',NULL,NULL)
ON CONFLICT(batch_key,airport_key) DO NOTHING;
-- Change ONLY Husum physical RUNWAY evidence status. Its civil operation
-- exception and associated two 1140m end restrictions remain in the specialist table.
WITH eligible AS (
 SELECT s.airport_key,s.primary_url,s.evidence_note,s.outstanding_aip_action
 FROM airlinerra.airport_expansion_de_specialist_batch11_decisions s
 JOIN airlinerra.airport_cohorts c ON c.airport_key=s.airport_key AND c.cohort='EXPANSION_3906'
 JOIN airlinerra.airport_expansion_german_civil_runway_end_holds h
 ON h.airport_key=s.airport_key AND h.icao_code='EDXJ'
 WHERE s.batch_key='EXPANSION_DE_SPECIALIST_BATCH_11_2026_10_26'
 AND s.airport_code='EDXJ'
 AND s.decision='PHYSICAL_PAVED_RUNWAY_PASS_CIVIL_LDA_1140_BOTH_ENDS'
 AND s.physical_collection_screen_pass AND s.operator_or_source_physical_m>=1200
 AND s.direction_a_lda_m=1140 AND s.direction_b_lda_m=1140
 AND s.game_admission_status='NOT_APPROVED' AND NOT s.game_activation_authorized
 AND NOT s.aircraft_flight_approval
 AND h.game_admission_status='NOT_APPROVED' AND NOT h.game_world_activated
)
UPDATE airlinerra.airport_access_reviews a SET
 identity_status='VERIFIED',paved_runway_status='VERIFIED',
 review_status='INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING',
 evidence_url=e.primary_url,
 source_review_note='Batch11: operator confirms EDXJ gross physical runway 1450m >=1200m for airport-only collection. HOWEVER both civil TORA/LDA1140m are below 1200m flight-direction screen. Specialist restriction remains; NOT approved for aircraft/commercial operation or game release. '||e.evidence_note||' Next: '||e.outstanding_aip_action,
 review_date='2026-10-26',last_updated=now()
FROM eligible e WHERE a.airport_key=e.airport_key
AND a.review_status='HOLD_CIVIL_RUNWAY_USABLE_DISTANCE_1140M'
AND a.paved_runway_status='UNVERIFIED'
AND a.game_admission_status='NOT_APPROVED';
-- EDMB remains on provisional below-length hold. EDCP remains on
-- temporary NOTAM hold pending followup, NOT on permanent closure rejection.
-- Acceptance assertions in docs/sql/AIRLINERRA_DE_SPECIALIST_BATCH_11_TESTS_2026-10-26.sql
