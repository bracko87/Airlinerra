-- Group 2 Section 5: append source-grounded partial findings; no fabricated curfew/noise verification.
DO $$
BEGIN
 IF (SELECT findings FROM airlinerra_game.airport_group2_section5_source_findings_status_v1)<>4
 OR (SELECT airports_with_any_source_review FROM airlinerra_game.airport_group2_section5_source_findings_status_v1)<>3
 OR (SELECT source_research_required_airports FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>1118
 THEN RAISE EXCEPTION 'SECTION5_RESEARCH_PREFLIGHT_MISMATCH';END IF;
END $$;
INSERT INTO airlinerra_game.airport_group2_section5_source_findings_v1
(airport_key,airport_icao,source_kind,source_url,observed_information,status)
VALUES
('OURAIRPORTS:4436','LOXZ','AIRPORT_OPERATOR','https://www.loxz.at/?page_id=68',
'Zeltweg local airport information publishes normal military flight operations Monday to Thursday 08:00-16:00 local and Friday 08:00-12:00 local, with extensions such as night flying and readiness by NOTAM. Civil club flights outside military hours are permitted under Day-VFR conditions between BCMT and ECET. The page disclaims authority and directs pilots to the official AIP and NOTAMs. Not proof of an unconditional night ban and no complete ICAO noise Chapter restrictions.',
'SOURCE_REVIEWED_INSUFFICIENT_TO_RESOLVE'),
('OURAIRPORTS:5227','OMAD','AIRPORT_OPERATOR','https://www.albateenairport.ae/en/aviation',
'Al Bateen Executive Airport operator advertises 24/7 operations, no slot restrictions, runway 13/31 and GCAA certification. These statements refer to executive aviation services; they are not a verified assertion of no formal nighttime curfew or no ICAO aircraft noise Chapter bans. Official AIP/NOTAM review is required before dispatch and no rule flag is changed.',
'SOURCE_REVIEWED_INSUFFICIENT_TO_RESOLVE');
DO $$
BEGIN
 IF (SELECT findings FROM airlinerra_game.airport_group2_section5_source_findings_status_v1)<>6
 OR (SELECT airports_with_any_source_review FROM airlinerra_game.airport_group2_section5_source_findings_status_v1)<>5
 OR (SELECT fully_verified_restriction_findings FROM airlinerra_game.airport_group2_section5_source_findings_status_v1)<>0
 OR (SELECT airports_still_unresolved FROM airlinerra_game.airport_group2_section5_source_findings_status_v1)<>1118
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1 WHERE commercial_playable OR commercial_access_verified)
 THEN RAISE EXCEPTION 'SECTION5_RESEARCH_SAFE_POSTCHECK_FAILED';END IF;
END $$;