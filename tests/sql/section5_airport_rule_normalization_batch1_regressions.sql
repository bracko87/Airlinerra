-- Airlinerra Section5 research normalization regression suite.
-- All temporary changes are inside a transaction that is ROLLED BACK.
BEGIN;
DO $tests$
DECLARE
 passenger jsonb; cargo jsonb; midnight jsonb; daylight jsonb; boundary jsonb;
 goa jsonb; permission_review jsonb; current_newest bigint;
BEGIN
 SELECT max(configuration_id) INTO current_newest
 FROM airlinerra.aircraft_catalog_configuration_inventory;
 IF current_newest IS NULL THEN RAISE EXCEPTION 'No canonical aircraft configurations'; END IF;
 midnight:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:2218',current_newest,'departure',
 '2026-11-06T10:00:00Z'::timestamptz);
 IF midnight->>'decision'='BLOCKED_UNKNOWN_AIRPORT_OR_AIRCRAFT' THEN
  RAISE EXCEPTION 'New catalog aircraft did not auto-register in universal gate'; END IF;

 passenger:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:2220',3::bigint,'departure',
 '2026-11-05T23:30:00Z'::timestamptz);
 cargo:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:2220',4::bigint,'departure',
 '2026-11-05T23:30:00Z'::timestamptz);
 IF passenger->>'decision'<>'BLOCKED_AIRPORT_TIME_CURFEW'
  OR (cargo->>'blockedByAirportTimeRule')::boolean
 THEN RAISE EXCEPTION 'Leipzig passenger-only/24h cargo mismatch'; END IF;

 midnight:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:6402',3::bigint,'arrival',
 '2026-11-06T03:00:00Z'::timestamptz);
 daylight:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:6402',3::bigint,'arrival',
 '2026-11-06T16:00:00Z'::timestamptz);
 IF NOT (midnight->>'blockedByAirportTimeRule')::boolean
 OR (daylight->>'blockedByAirportTimeRule')::boolean
 THEN RAISE EXCEPTION 'Aruba ordinary scheduled service window mismatch'; END IF;

 midnight:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:2157',3::bigint,'arrival',
 '2026-11-06T05:29:00Z'::timestamptz);
 boundary:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:2157',3::bigint,'arrival',
 '2026-11-06T05:30:00Z'::timestamptz);
 IF NOT (midnight->>'blockedByAirportTimeRule')::boolean
 OR (boundary->>'blockedByAirportTimeRule')::boolean
 THEN RAISE EXCEPTION 'Charleroi 06:30 local boundary mismatch'; END IF;

 goa:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:26444',3::bigint,'departure',
 '2026-11-05T04:00:00Z'::timestamptz);
 IF goa->>'decision'<>'BLOCKED_AIRPORT_TIME_CURFEW' THEN
 RAISE EXCEPTION 'Goa weekday military slot mismatch'; END IF;
 goa:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:26444',3::bigint,'departure',
 '2026-11-07T03:00:00Z'::timestamptz,'236704');
 IF goa->>'decision'<>'BLOCKED_SPECIFIC_RUNWAY_RULE'
 THEN RAISE EXCEPTION 'Goa runway-specific Saturday closure mismatch'; END IF;

 permission_review:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:4001',3::bigint,'departure',
 '2026-11-06T23:00:00Z'::timestamptz);
 IF (permission_review->>'blockedByAirportTimeRule')::boolean
 OR NOT (permission_review->>'quotaOrSlotReview')::boolean
 THEN RAISE EXCEPTION 'Bilbao PPR should flag review but not hard-block'; END IF;

 IF (SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1)<>1312
 THEN RAISE EXCEPTION 'Incomplete normalization backlog coverage'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_airport_time_restrictions_v1
 WHERE evidence_authority='SOURCE_SCREENED_OPERATING_HOURS_REVIEW_ONLY'
  AND (game_auto_enforcement OR prohibit_normal_scheduled))<>0
 THEN RAISE EXCEPTION 'Research-only operating hours accidentally activated'; END IF;
END $tests$;

INSERT INTO airlinerra_game.section5_airport_time_restrictions_v1(
 world_id,airport_key,airport_code,rule_code,rule_kind,affected_operations,
 local_start,local_end,weekday_iso,prohibit_normal_scheduled,game_auto_enforcement,
 exceptions_expected,source_url,evidence_authority,evidence_note,evidence_checked_on,
 applies_aircraft_use_types,active_from,active_until)
VALUES (
 1,'OURAIRPORTS:4001','BIO','ROLLBACK_TEST_ONLY_SEASONAL_PASSENGER',
 'CURFEW_SCHEDULED','both','12:00','13:00',ARRAY[6]::smallint[],true,true,true,
 'https://example.invalid/test-only','ROLLBACK_TEST_ONLY',
 'Synthetic dated/weekday/aircraft scope regression, must not persist','2026-11-06',
 ARRAY['passenger']::text[],'2026-11-07','2026-11-07');

DO $tests$
DECLARE date_match jsonb; cargo jsonb; date_miss jsonb;
BEGIN
 date_match:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:4001',3::bigint,'departure',
 '2026-11-07T11:30:00Z'::timestamptz);
 cargo:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:4001',4::bigint,'departure',
 '2026-11-07T11:30:00Z'::timestamptz);
 date_miss:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
 1::smallint,'OURAIRPORTS:4001',3::bigint,'departure',
 '2026-11-14T11:30:00Z'::timestamptz);
 IF date_match->>'decision'<>'BLOCKED_AIRPORT_TIME_CURFEW'
 OR (cargo->>'blockedByAirportTimeRule')::boolean
 OR (date_miss->>'blockedByAirportTimeRule')::boolean
 THEN RAISE EXCEPTION 'Synthetic scoped restriction mismatch: date=% cargo=% next=%',date_match,cargo,date_miss; END IF;
 RAISE NOTICE 'PASS: operating-hours normalization, runway-specific, aircraft-use, dated, weekday, and exception-review rules';
END $tests$;
ROLLBACK;
