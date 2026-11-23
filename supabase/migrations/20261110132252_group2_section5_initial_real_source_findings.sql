-- Airlinerra Group 2 Section 5: real-source research ledger (first two reviewed airports).
-- Source page observations are not curfew/noise clearances. Keep Section 5 unresolved.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_fixed_batch_members_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section5_restrictions_review_v1)<>1118
 OR (SELECT source_research_required_airports FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>1118
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 THEN RAISE EXCEPTION 'SECTION5_SOURCE_RESEARCH_PREFLIGHT_FAILED'; END IF;
END $$;

CREATE TABLE airlinerra_game.airport_group2_section5_source_findings_v1 (
 finding_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 airport_key text NOT NULL,
 airport_icao text NOT NULL,
 source_kind text NOT NULL CHECK(source_kind IN ('AIRPORT_OPERATOR','STATE_AIP','AIRLINESIM_GAME')),
 source_url text NOT NULL CHECK(source_url LIKE 'https://%'),
 observed_information text NOT NULL CHECK(length(observed_information)>20),
 status text NOT NULL CHECK(status IN ('SOURCE_REVIEWED_INSUFFICIENT_TO_RESOLVE')),
 verified_nighttime_ban boolean,
 verified_noise_restrictions boolean,
 reviewed_on date NOT NULL DEFAULT DATE '2026-11-10',
 CHECK(verified_nighttime_ban IS NULL AND verified_noise_restrictions IS NULL),
 UNIQUE(airport_key,source_url)
);
ALTER TABLE airlinerra_game.airport_group2_section5_source_findings_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_section5_source_findings_v1 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER group2_section5_source_findings_immutable BEFORE UPDATE OR DELETE
 ON airlinerra_game.airport_group2_section5_source_findings_v1 FOR EACH ROW
 EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();

INSERT INTO airlinerra_game.airport_group2_section5_source_findings_v1
 (airport_key,airport_icao,source_kind,source_url,observed_information,status)
VALUES
 ('OURAIRPORTS:27866','YOLW','AIRPORT_OPERATOR',
 'https://www.ashburton.wa.gov.au/community/shire-facilities/onslow-airport.aspx',
 'Shire of Ashburton airport operator describes a licensed security-controlled airport and regular services but does not explicitly document both nighttime ban and noise chapter status. No restriction conclusion is authorized.',
 'SOURCE_REVIEWED_INSUFFICIENT_TO_RESOLVE'),
 ('OURAIRPORTS:30234','VYPU','STATE_AIP',
 'https://www.ais.gov.mm/eAIP/2022-01-21-AIRAC/html/eAIP/AD-2.VYPU-en-GB.html',
 'Myanmar AIP aerodrome entry records operational hours as HO and states VFR traffic permission in a historical 2022 AIRAC version; this does not prove no nighttime ban or no noise chapter restriction in 2026.',
 'SOURCE_REVIEWED_INSUFFICIENT_TO_RESOLVE');

CREATE VIEW airlinerra_game.airport_group2_section5_source_findings_status_v1
WITH (security_invoker=true) AS
SELECT count(*)::integer AS findings,
 count(DISTINCT airport_key)::integer AS airports_with_any_source_review,
 count(*) FILTER(WHERE verified_nighttime_ban IS NOT NULL AND verified_noise_restrictions IS NOT NULL)::integer AS fully_verified_restriction_findings,
 (SELECT source_research_required_airports FROM airlinerra_game.airport_group2_section5_overall_status_v1) AS airports_still_unresolved,
 false AS flight_clearance_granted
FROM airlinerra_game.airport_group2_section5_source_findings_v1;
REVOKE ALL ON airlinerra_game.airport_group2_section5_source_findings_status_v1 FROM PUBLIC,anon,authenticated;

DO $$
BEGIN
 IF (SELECT airports_with_any_source_review FROM airlinerra_game.airport_group2_section5_source_findings_status_v1)<>2
 OR (SELECT airports_still_unresolved FROM airlinerra_game.airport_group2_section5_source_findings_status_v1)<>1118
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1
 WHERE commercial_playable OR commercial_access_verified)
 THEN RAISE EXCEPTION 'SECTION5_SOURCE_RESEARCH_FAIL_CLOSED_FAILED';END IF;
END $$;