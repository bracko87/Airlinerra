-- Group2 SECTION 1 ONLY: five materially wrong timezone approximations.
-- The NSW Government describes the regional standard offsets and DST rules.
-- These are proposed corrections and do not yet mutate game timezone fields.
CREATE TABLE airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1 (
 airport_key text PRIMARY KEY REFERENCES airlinerra_game.airport_group2_game_profiles_v1(airport_key),
 region_code text NOT NULL,
 source_game_timezone_iana text NOT NULL,
 authority_expected_timezone_iana text NOT NULL
 CHECK(authority_expected_timezone_iana IN
 ('Australia/Brisbane','Australia/Darwin','Australia/Adelaide','Australia/Melbourne')),
 source_name text NOT NULL,
 source_url text NOT NULL CHECK(source_url LIKE 'https://%'),
 reason text NOT NULL CHECK(length(reason)>55),
 evidence_checked_on date NOT NULL DEFAULT DATE '2026-11-10',
 source_verification_status text NOT NULL DEFAULT
 'OFFICIAL_STATE_TIME_RULES_CANDIDATE_PENDING_INDEPENDENT_REVIEW'
 CHECK(source_verification_status=
 'OFFICIAL_STATE_TIME_RULES_CANDIDATE_PENDING_INDEPENDENT_REVIEW'),
 applied_to_canonical_game_profile boolean NOT NULL DEFAULT false
 CHECK(applied_to_canonical_game_profile=false),
 authority_verified_for_flight_schedule boolean NOT NULL DEFAULT false
 CHECK(authority_verified_for_flight_schedule=false),
 CHECK(source_game_timezone_iana<>authority_expected_timezone_iana)
);
ALTER TABLE airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1
 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER section1_timezone_candidates_append_only
 BEFORE UPDATE OR DELETE ON airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.group2_evidence_append_only_v1();
COMMENT ON TABLE airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1 IS
 'Five Australia state-timezone mismatches, proposed as sourced corrections. Existing Group2 game timezone profiles unchanged. Check per-airport geographic jurisdiction (incl exceptional regions) before applying.';

INSERT INTO airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1
(airport_key,region_code,source_game_timezone_iana,authority_expected_timezone_iana,
 source_name,source_url,reason)
VALUES
('OURAIRPORTS:27110','AU-NT','Australia/Perth','Australia/Darwin','Australian government time zone rules (NSW DCJ)','https://dcj.nsw.gov.au/about-us/daylight-saving/definitions-of-time-and-how-time-is-regulated.html','Northern Territory uses Australian Central Standard Time (UTC+9:30) year round, not Perth Western Standard Time (UTC+8).'),
('OURAIRPORTS:26990','AU-QLD','Australia/Sydney','Australia/Brisbane','Australian government time zone rules (NSW DCJ)','https://dcj.nsw.gov.au/about-us/daylight-saving/definitions-of-time-and-how-time-is-regulated.html','Queensland observes Australian Eastern Standard Time all year and does not switch to daylight saving; Sydney uses AEDT in November.'),
('OURAIRPORTS:27094','AU-SA','Australia/Brisbane','Australia/Adelaide','Australian government time zone rules (NSW DCJ)','https://dcj.nsw.gov.au/about-us/daylight-saving/definitions-of-time-and-how-time-is-regulated.html','South Australia uses Australian Central Standard Time and daylight saving (ACDT in November); Brisbane is Queensland time.'),
('OURAIRPORTS:27125','AU-SA','Australia/Melbourne','Australia/Adelaide','Australian government time zone rules (NSW DCJ)','https://dcj.nsw.gov.au/about-us/daylight-saving/definitions-of-time-and-how-time-is-regulated.html','Renmark is in South Australia, where ACDT is UTC+10:30 in November, not the Victorian AEDT UTC+11.'),
('OURAIRPORTS:27011','AU-VIC','Australia/Adelaide','Australia/Melbourne','Australian government time zone rules (NSW DCJ)','https://dcj.nsw.gov.au/about-us/daylight-saving/definitions-of-time-and-how-time-is-regulated.html','Horsham is in Victoria, where Australian Eastern Daylight Time applies in November, not South Australian central daylight time.');

CREATE VIEW airlinerra_game.airport_group2_section1_timezone_discrepancy_v1
 WITH (security_invoker=true) AS
SELECT
 c.airport_key,g.game_airport_name,c.region_code,
 g.timezone_iana AS currently_stored_game_timezone,
 c.authority_expected_timezone_iana AS proposed_correct_timezone,
 round(EXTRACT(EPOCH FROM (
 ('2026-11-10 12:00:00+00'::timestamptz AT TIME ZONE g.timezone_iana)
 -
 ('2026-11-10 12:00:00+00'::timestamptz AT TIME ZONE c.authority_expected_timezone_iana)
 ))::numeric/60,0)::integer AS current_vs_expected_offset_minutes_on_nov10,
 round(EXTRACT(EPOCH FROM (
 ('2026-06-10 12:00:00+00'::timestamptz AT TIME ZONE g.timezone_iana)
 -
 ('2026-06-10 12:00:00+00'::timestamptz AT TIME ZONE c.authority_expected_timezone_iana)
 ))::numeric/60,0)::integer AS current_vs_expected_offset_minutes_on_jun10,
 c.source_name,c.source_url,c.source_verification_status,
 false AS timezone_applied, false AS flight_schedule_authorized
FROM airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1 c
JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key);
REVOKE ALL ON airlinerra_game.airport_group2_section1_timezone_discrepancy_v1
 FROM PUBLIC,anon,authenticated;

DO $verify$
BEGIN
 IF (SELECT count(*) FROM airlinerra_game.airport_group2_section1_timezone_discrepancy_v1)<>5
 OR EXISTS(SELECT 1 FROM airlinerra_game.airport_group2_section1_timezone_correction_candidates_v1 c
  JOIN airlinerra_game.airport_group2_game_profiles_v1 g USING(airport_key)
  WHERE c.source_game_timezone_iana IS DISTINCT FROM g.timezone_iana
    OR c.region_code IS DISTINCT FROM g.region_code
    OR c.applied_to_canonical_game_profile OR c.authority_verified_for_flight_schedule)
 OR (SELECT count(*) FROM airlinerra_game.airport_group2_section1_timezone_discrepancy_v1
     WHERE current_vs_expected_offset_minutes_on_nov10=0
       AND current_vs_expected_offset_minutes_on_jun10=0)<>0
 OR (SELECT count(*) FROM airlinerra_game.approved_game_airports WHERE world_id=1)<>3141
 THEN RAISE EXCEPTION 'GROUP2_SECTION1_FIVE_TIMEZONE_RULES_ACCEPTANCE_FAILED';END IF;
END $verify$;
