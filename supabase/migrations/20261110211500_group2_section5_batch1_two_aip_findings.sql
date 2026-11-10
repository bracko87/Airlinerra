-- Group 2 Section 5 Batch 1: append two authoritative AIP observations, no clearance.
DO $$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section5_source_findings_v1)<>2
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_fixed_batch_members_v1 WHERE batch_number=1)<>50
 OR (SELECT source_research_required_airports FROM airlinerra_game.airport_group2_section5_overall_status_v1)<>1118
 THEN RAISE EXCEPTION 'GROUP2_SECTION5_BATCH1_SOURCE_PREFLIGHT_FAILED'; END IF;
END $$;
INSERT INTO airlinerra_game.airport_group2_section5_source_findings_v1
(airport_key,airport_icao,source_kind,source_url,observed_information,status)
VALUES
('OURAIRPORTS:29484','LOXT','STATE_AIP',
'https://eaip.austrocontrol.at/lo/260319/PART_3/AD_2/MIL/AD_2_LOXT/LO_AD_2_LOXT_en.pdf',
'Austro Control AIP Austria LOXT AD 2, effective 19 MAR 2026, states military flight administration hours Monday to Thursday 0700-1500 (0600-1400 in summer notation) and Friday 0700-1230 (0600-1130), excluding holidays, with possible exceptions. AD 2.20 requires Ministry of Defence permission for takeoffs and landings. AD 2.21 requires avoiding low-altitude overflight of populated areas for noise abatement. This is not a source-confirmed ICAO Chapter ban or a complete time-of-day restriction encoding; civil commercial operation is NOT authorized.',
'SOURCE_REVIEWED_INSUFFICIENT_TO_RESOLVE'),
('OURAIRPORTS:27866','YOLW','STATE_AIP',
'https://www.airservicesaustralia.com/aip/current/ersa/FAC_YOLW_04SEP2025.pdf',
'Airservices Australia AIP FAC YOLW dated 04 SEP 2025 identifies Onslow as security-controlled, records runway/taxiway lighting and restrictions including unlit taxiways B C E restricted to day operations, and parking for aircraft over 5700 kg by prior airport-operator arrangement. H24 availability mentioned for fuel pumps is NOT evidence of unrestricted H24 airport operations. Airport-specific nighttime ban/noise Chapter rules remain unresolved.',
'SOURCE_REVIEWED_INSUFFICIENT_TO_RESOLVE');
DO $$
BEGIN
 IF (SELECT findings FROM airlinerra_game.airport_group2_section5_source_findings_status_v1)<>4
 OR (SELECT airports_with_any_source_review FROM airlinerra_game.airport_group2_section5_source_findings_status_v1)<>3
 OR (SELECT fully_verified_restriction_findings FROM airlinerra_game.airport_group2_section5_source_findings_status_v1)<>0
 OR (SELECT airports_still_unresolved FROM airlinerra_game.airport_group2_section5_source_findings_status_v1)<>1118
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_game_profiles_v1 WHERE commercial_playable OR commercial_access_verified)
 THEN RAISE EXCEPTION 'GROUP2_SECTION5_BATCH1_SOURCE_POSTCHECK_FAILED'; END IF;
END $$;