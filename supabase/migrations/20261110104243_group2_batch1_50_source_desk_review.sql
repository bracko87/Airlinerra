-- Group 2 Batch 1 desk research: 50 stable review case snapshots and
-- official-source *candidates*. No independent review / rights granted.
-- Production game and 3,141-airport Group 1 are unchanged.
CREATE TABLE airlinerra_game.airport_group2_batch1_desk_cases_v1 (
 airport_key text PRIMARY KEY REFERENCES airlinerra_game.airport_group2_game_profiles_v1(airport_key),
 batch_number smallint NOT NULL DEFAULT 1 CHECK(batch_number=1),
 case_number smallint NOT NULL UNIQUE CHECK(case_number BETWEEN 1 AND 50),
 priority_tier smallint NOT NULL CHECK(priority_tier BETWEEN 0 AND 4),
 game_airport_name text NOT NULL,
 country_iso text NOT NULL,
 source_game_category text NOT NULL,
 source_service_intention text NOT NULL,
 historical_runway_width_basis text NOT NULL,
 historic_runway_observation_count integer NOT NULL,
 initial_historical_access_review text,
 initial_historical_access_source text,
 prior_commercial_permission_status text,
 prior_commercial_prohibition boolean NOT NULL,
 task_summary text NOT NULL CHECK(length(task_summary)>24),
 desk_state text NOT NULL DEFAULT 'INITIAL_TRIAGE_COMPLETE_INDEPENDENT_REVIEW_PENDING'
 CHECK(desk_state='INITIAL_TRIAGE_COMPLETE_INDEPENDENT_REVIEW_PENDING'),
 independent_source_gates_passed boolean NOT NULL DEFAULT false
 CHECK(independent_source_gates_passed=false),
 commercial_aviation_approval boolean NOT NULL DEFAULT false
 CHECK(commercial_aviation_approval=false),
 live_game_flights_enabled boolean NOT NULL DEFAULT false
 CHECK(live_game_flights_enabled=false),
 snapshot_taken_on date NOT NULL DEFAULT DATE '2026-11-10'
);
ALTER TABLE airlinerra_game.airport_group2_batch1_desk_cases_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_batch1_desk_cases_v1 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER airport_group2_batch1_case_immutable
 BEFORE UPDATE OR DELETE ON airlinerra_game.airport_group2_batch1_desk_cases_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();
COMMENT ON TABLE airlinerra_game.airport_group2_batch1_desk_cases_v1 IS
 'Frozen Batch 1 50-airport research snapshot. Every case triaged for its next verification action, but ZERO new evidence gates completed and no airport admitted.';

INSERT INTO airlinerra_game.airport_group2_batch1_desk_cases_v1 (
 airport_key,case_number,priority_tier,game_airport_name,country_iso,
 source_game_category,source_service_intention,historical_runway_width_basis,
 historic_runway_observation_count,initial_historical_access_review,
 initial_historical_access_source,prior_commercial_permission_status,
 prior_commercial_prohibition,task_summary
)
SELECT airport_key,cohort_review_order::smallint,priority_tier,
 game_airport_name,country_iso,owner_category,game_traffic_type,
 runway_width_game_basis,detailed_runway_observation_count,
 historical_access_review,historical_access_source,
 historical_commercial_access,documented_commercial_prohibition,
 next_research_action
FROM airlinerra_game.airport_group2_source_research_queue_v1
WHERE review_batch_50=1 AND cohort_review_order BETWEEN 1 AND 50;

CREATE TABLE airlinerra_game.airport_group2_batch1_public_source_findings_v1 (
 finding_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 airport_key text NOT NULL REFERENCES airlinerra_game.airport_group2_batch1_desk_cases_v1(airport_key),
 source_url text NOT NULL CHECK(source_url ~ '^https://[^[:space:]]{8,}$'
    AND length(source_url)<=2048),
 issuer_name text NOT NULL CHECK(length(issuer_name)>=7),
 source_kind text NOT NULL CHECK(source_kind IN
 ('national_aip','national_runway_distance_supplement','faa_airport_chart',
  'government_airport_plan','airport_owner_public_webpage','national_aviation_directory')),
 source_published_on date,
 source_reviewed_on date NOT NULL DEFAULT DATE '2026-11-10',
 claim_kind text NOT NULL CHECK(claim_kind IN
   ('commercial_aviation_restriction','runway_width','access_and_stand_conditions')),
 runway_designator text,
 observed_runway_width_m numeric(7,2) CHECK(observed_runway_width_m BETWEEN 5 AND 100),
 evidence_details text NOT NULL CHECK(length(btrim(evidence_details)) BETWEEN 50 AND 2500),
 currency_or_freshness_warning text NOT NULL CHECK(length(btrim(currency_or_freshness_warning))>=20),
 source_class text NOT NULL DEFAULT 'PUBLIC_PRIMARY_SOURCE_CANDIDATE_NOT_VALIDATED'
   CHECK(source_class='PUBLIC_PRIMARY_SOURCE_CANDIDATE_NOT_VALIDATED'),
 independent_review_complete boolean NOT NULL DEFAULT false
   CHECK(independent_review_complete=false),
 permitted_for_simulation_flight boolean NOT NULL DEFAULT false
   CHECK(permitted_for_simulation_flight=false),
 UNIQUE(airport_key,source_url,claim_kind),
 CHECK((claim_kind='runway_width' AND observed_runway_width_m IS NOT NULL)
    OR (claim_kind<>'runway_width' AND observed_runway_width_m IS NULL))
);
ALTER TABLE airlinerra_game.airport_group2_batch1_public_source_findings_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_batch1_public_source_findings_v1
 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER airport_group2_batch1_findings_immutable
 BEFORE UPDATE OR DELETE ON airlinerra_game.airport_group2_batch1_public_source_findings_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();
COMMENT ON TABLE airlinerra_game.airport_group2_batch1_public_source_findings_v1 IS
 'Candidate primary/public source observations from Batch1 desk research; never auto-promote to independent verified evidence, airport source canonical truth or commercial permission.';

-- Source dates and claims refer to the publicly retrievable editions/pages
-- noted below. Old/current validity must be independently rechecked.
INSERT INTO airlinerra_game.airport_group2_batch1_public_source_findings_v1
(airport_key,source_url,issuer_name,source_kind,source_published_on,
 claim_kind,runway_designator,observed_runway_width_m,evidence_details,
 currency_or_freshness_warning)
VALUES
('OURAIRPORTS:29484',
 'https://www.austrocontrol.at/jart/prj3/ac/data/dokumente/LO_Amdt_2024_335_en_2024-12-10_1012477.pdf',
 'Austro Control Austria','national_aip',DATE '2024-12-27',
 'commercial_aviation_restriction',NULL,NULL,
 'AIP Austria AD 1.1-2 identifies Tulln LOXT as a military aerodrome and states military airfields may not be used for commercial aviation. Earlier Group2 access review already marked this airport PROHIBITED_BY_AIP.',
 'AIP amendment is dated December 2024. Recheck effective November 2026 AIP and military authority permission before any use; existing prohibited status stays hard blocked.'),
('OURAIRPORTS:4436',
 'https://www.austrocontrol.at/jart/prj3/ac/data/dokumente/LO_Amdt_2024_335_en_2024-12-10_1012477.pdf',
 'Austro Control Austria','national_aip',DATE '2024-12-27',
 'commercial_aviation_restriction',NULL,NULL,
 'AIP Austria AD 1.1-2 identifies Zeltweg LOXZ as a military aerodrome and states military airfields may not be used for commercial aviation. Earlier Group2 access review already marked this airport PROHIBITED_BY_AIP.',
 'AIP amendment is dated December 2024. Recheck effective November 2026 AIP and military authority permission before any use; existing prohibited status stays hard blocked.'),
('OURAIRPORTS:29801',
 'https://www.airservicesaustralia.com/aip/current/ersa/FAC_YCWA_28NOV2024.pdf',
 'Airservices Australia','national_aip',DATE '2024-11-28',
 'runway_width','08/26',30,
 'Published Australian ERSA Coondewanna YCWA FAC gives runway 08/26 WID 30 metres, whereas Group2 has only a category-based GAME-estimated width. Certified aerodrome operated by BHP Iron Ore. Source also says restricted operation and PPR.',
 'Facility source page bears 2024 date; check current effective ERSA and airport operator before moving to independently verified gate. No changes to airport live width or permission.'),
('OURAIRPORTS:29801',
 'https://www.airservicesaustralia.com/aip/current/ersa/RDS_YCWA_27NOV2025.pdf',
 'Airservices Australia','national_runway_distance_supplement',
 DATE '2025-11-27','access_and_stand_conditions',NULL,NULL,
 'Coondewanna official runway distance supplement lists runway 08 TORA 1950 metres and LDA 1800 metres, runway 26 TORA 1930 metres and LDA 1800 metres; runway width 30 metres.',
 'These are dated 2025 source-declared distances, not current NOTAM/performance clearance or blanket passenger-carrier operating rights.'),
('OURAIRPORTS:27866',
 'https://www.airservicesaustralia.com/aip/current/ersa/FAC_YOLW_04SEP2025.pdf',
 'Airservices Australia','national_aip',DATE '2025-09-04',
 'runway_width','03/21',30,
 'Published Australian ERSA Onslow YOLW FAC reports runway 03/21 WID 30 metres, while Group2 currently uses category median GAME-estimated width. Source names Shire of Ashburton as operator.',
 'Facility record dated September 2025; check currently effective aeronautical supplement and airport operator before any safety or permission claim.'),
('OURAIRPORTS:27866',
 'https://www.airservicesaustralia.com/aip/current/ersa/FAC_YOLW_04SEP2025.pdf',
 'Airservices Australia','national_aip',DATE '2025-09-04',
 'access_and_stand_conditions',NULL,NULL,
 'Onslow ERSA FAC reports security-controlled aerodrome, ground handling by arrangement and parking by prior arrangement for aircraft above 5700 kg. Taxiway B, C, E have aircraft code/gear-width limits. Actual flight restrictions are more detailed than a simple stand estimate.',
 'Not operational clearance for any named airline or aircraft. Revalidate 2026 amendments and NOTAMs before modelling actual stand allocations.'),
('OURAIRPORTS:21335',
 'https://www.cfaspp.com/FASP/AirportPDFs/638615669868993308-VQQ_4_4_2024_.pdf',
 'Florida aviation system planning program','government_airport_plan',
 DATE '2024-04-04','runway_width','18L/36R',60.96,
 'Florida state airport planning fact sheet lists Cecil Airport VQQ main runway 18L/36R as 12503 feet long by 200 feet wide, equivalent to 60.96 metres width. Existing Group2 runway-width game estimate is 36.3m.',
 'Planning factsheet dated 2024; independently cross-check current FAA master record, declared distances, compatible flight types and operational restrictions.'),
('OURAIRPORTS:20581',
 'https://aeronav.faa.gov/afd/19MAR2026/NW_rear_19MAR2026.pdf',
 'US Federal Aviation Administration','faa_airport_chart',
 DATE '2026-03-19','runway_width','14L/32R',60.96,
 'FAA March 2026 Grant County International (MWH) airport diagram marks runway 14L/32R 13503 feet by 200 feet, equivalent to 60.96m runway width. Group2 width is currently only a category median estimate.',
 'FAA chart cycle was 19 March through 14 May 2026 and is out of its chart-validity window; fetch currently effective FAA source and NOTAMs before any operational use.'),
('OURAIRPORTS:3403',
 'https://www.mobileairportauthority.com/aeroplex/infrastructure/',
 'Mobile Airport Authority','airport_owner_public_webpage',NULL,
 'runway_width','14/32',45.72,
 'Airport-operator infrastructure page lists Mobile Downtown (BFM) runway 14/32 as 9618 feet by 150 feet, 45.72 metres wide; separate runway 18/36 also 150 feet wide. Existing Group2 width is category estimated.',
 'Public page does not itself establish a current effective FAA airfield condition or scheduled-carrier service permission. Validate FAA cycle and NOTAM separately.'),
('OURAIRPORTS:21315',
 'https://www.victorvilleca.gov/Government/City-Departments/Airport/For-Pilots',
 'City of Victorville Airport Authority','airport_owner_public_webpage',NULL,
 'runway_width','17/35',45.72,
 'City operator airport for-pilots page lists Southern California Logistics Airport runway 17/35 as 13052 feet by 150 feet, 3978m by approximately 46m, with published declared distances. Group2 current width is estimated 36.3m.',
 'Airport operator webpage is undated. Verify current FAA cycle, actual runway restrictions, aircraft/airline approval and latest NOTAM before setting any dispatch gate.'),
('OURAIRPORTS:3436',
 'https://fly.arkansas.gov/uploads/7/5/7/7/75772239/blytheville-ar_international.pdf',
 'Arkansas Department of Commerce Aviation Division',
 'national_aviation_directory',NULL,
 'runway_width','18/36',45.72,
 'State aviation airport directory lists Arkansas International (BYH) runway 18/36 as 11602 feet long and 150 feet wide concrete, width equivalent to 45.72m. Group2 current width is estimated 36.3m.',
 'Directory publication/current source-cycle not confirmed. Independently check current FAA airport record and runway availability, carrier rights and operation restrictions.'
);

CREATE VIEW airlinerra_game.airport_group2_batch1_source_progress_v1
 WITH (security_invoker=true) AS
SELECT
 count(*)::integer AS cases,
 count(*) FILTER(WHERE c.priority_tier=0)::integer AS existing_hard_prohibition_cases,
 count(*) FILTER(WHERE c.priority_tier=1)::integer AS original_runway_gap_cases,
 count(*) FILTER(WHERE c.priority_tier=2)::integer AS missing_access_review_cases,
 count(*) FILTER(WHERE sources.sources_found>0)::integer AS airports_with_public_source_candidates,
 coalesce(sum(sources.sources_found),0)::integer AS public_source_findings,
 count(*) FILTER(WHERE sources.runway_candidate_count>0)::integer AS airports_with_runway_dimension_candidate,
 count(*) FILTER(WHERE sources.sources_found=0)::integer AS cases_without_new_public_source,
 count(*) FILTER(WHERE c.independent_source_gates_passed)::integer AS independently_verified_cases,
 count(*) FILTER(WHERE c.live_game_flights_enabled)::integer AS admitted_for_flights
FROM airlinerra_game.airport_group2_batch1_desk_cases_v1 c
LEFT JOIN LATERAL(
 SELECT count(*)::integer sources_found,
   count(*) FILTER(WHERE claim_kind='runway_width')::integer runway_candidate_count
 FROM airlinerra_game.airport_group2_batch1_public_source_findings_v1 s
 WHERE s.airport_key=c.airport_key
) sources ON true;
REVOKE ALL ON airlinerra_game.airport_group2_batch1_source_progress_v1
 FROM PUBLIC,anon,authenticated;

CREATE VIEW airlinerra_game.airport_group2_batch1_desk_worklist_v1
 WITH (security_invoker=true) AS
SELECT c.case_number,c.airport_key,c.game_airport_name,c.country_iso,
 c.priority_tier,c.source_service_intention,c.prior_commercial_prohibition,
 c.historic_runway_observation_count,c.historical_runway_width_basis,
 c.task_summary,
 coalesce(count(s.finding_id),0)::integer AS primary_source_finding_count,
 coalesce(count(s.finding_id) FILTER(WHERE s.claim_kind='runway_width'),0)::integer AS source_width_candidate_count,
 CASE WHEN c.prior_commercial_prohibition THEN 'HARD_HOLD_EXISTING_PROHIBITION'
 WHEN count(s.finding_id)>0 THEN 'PUBLIC_SOURCE_FOUND_AWAITING_INDEPENDENT_REVIEW'
 ELSE 'NEEDS_PRIMARY_SOURCE_RESEARCH' END AS source_research_state,
 false AS independent_review_approved,
 false AS can_activate_flights
FROM airlinerra_game.airport_group2_batch1_desk_cases_v1 c
LEFT JOIN airlinerra_game.airport_group2_batch1_public_source_findings_v1 s USING(airport_key)
GROUP BY c.case_number,c.airport_key,c.game_airport_name,c.country_iso,
 c.priority_tier,c.source_service_intention,c.prior_commercial_prohibition,
 c.historic_runway_observation_count,c.historical_runway_width_basis,
 c.task_summary;
REVOKE ALL ON airlinerra_game.airport_group2_batch1_desk_worklist_v1
 FROM PUBLIC,anon,authenticated;

DO $verify$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_desk_cases_v1)<>50
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_public_source_findings_v1)<>11
 OR (SELECT airports_with_public_source_candidates
      FROM airlinerra_game.airport_group2_batch1_source_progress_v1)<>9
 OR (SELECT airports_with_runway_dimension_candidate
      FROM airlinerra_game.airport_group2_batch1_source_progress_v1)<>7
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_batch1_desk_worklist_v1
       WHERE can_activate_flights OR independent_review_approved)<>0
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_review_evidence_events_v1)<>0
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 OR (SELECT state FROM public.airlinerra_game_worlds WHERE id=1)<>'planned'
 THEN RAISE EXCEPTION 'GROUP2_BATCH1_SOURCE_DESK_REVIEW_UNEXPECTED_STATE';END IF;
END $verify$;
