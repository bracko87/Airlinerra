-- World 1 integration acceptance tests for date-bound restrictions and future flight guard.
-- No fixture data remains; tests are read-only and transaction-rolled back.
BEGIN;
DO $tests$
DECLARE v jsonb; blocked boolean; a jsonb;
BEGIN
 blocked:=false;
 BEGIN
  PERFORM airlinerra_game.section5_reject_prohibited_flight_v1(
    1::smallint,'OURAIRPORTS:5564','OURAIRPORTS:2218',3::bigint,
    '2026-11-05T14:30:00Z'::timestamptz,'2026-11-05T19:00:00Z'::timestamptz);
 EXCEPTION WHEN SQLSTATE 'P0001' THEN blocked:=true; END;
 IF NOT blocked THEN RAISE EXCEPTION 'Fukuoka night restriction not rejected at server guard'; END IF;
 v:=airlinerra_game.section5_reject_prohibited_flight_v1(
   1::smallint,'OURAIRPORTS:4185','OURAIRPORTS:2218',3::bigint,
   '2026-11-05T11:00:00Z'::timestamptz,'2026-11-05T13:00:00Z'::timestamptz);
 IF (v->>'gameHardBlocked')::boolean OR (v->>'canActivateNormalFlight')::boolean
 THEN RAISE EXCEPTION 'Review-only result falsely banned or activated a flight'; END IF;

 v:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
    1::smallint,'OURAIRPORTS:4070',3::bigint,'departure',
    '2026-12-30T22:15:00Z'::timestamptz);
 IF (v->>'blockedByAirportTimeRule')::boolean THEN RAISE EXCEPTION 'TLS 2027 future law applied in 2026'; END IF;

 v:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
    1::smallint,'OURAIRPORTS:4070',3::bigint,'departure',
    '2027-01-02T22:15:00Z'::timestamptz);
 IF NOT (v->>'blockedByAirportTimeRule')::boolean THEN RAISE EXCEPTION 'TLS 2027 departures not blocked'; END IF;

 v:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
    1::smallint,'OURAIRPORTS:4070',3::bigint,'arrival',
    '2027-01-02T23:30:00Z'::timestamptz);
 IF (v->>'blockedByAirportTimeRule')::boolean OR NOT (v->>'quotaOrSlotReview')::boolean
 THEN RAISE EXCEPTION 'TLS 2027-28 conditional early arrivals should require quota review'; END IF;

 v:=airlinerra_game.section5_universal_airport_leg_restriction_v1(
    1::smallint,'OURAIRPORTS:4070',3::bigint,'arrival',
    '2029-01-02T23:30:00Z'::timestamptz);
 IF NOT (v->>'blockedByAirportTimeRule')::boolean THEN RAISE EXCEPTION 'TLS 2029 arrival ban missing'; END IF;

 IF (SELECT count(*) FROM airlinerra_game.section5_airport_game_restriction_catalog_v1)<>3141
 THEN RAISE EXCEPTION 'World1 airport restriction catalogue not complete'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_airport_restriction_normalization_queue_v1)<>1312
 THEN RAISE EXCEPTION 'Positive-research queue coverage changed unexpectedly'; END IF;
 IF (SELECT count(*) FROM airlinerra_game.section5_runway_specific_restrictions_v1
   WHERE rule_code LIKE '%TEST_ONLY%')<>0 THEN RAISE EXCEPTION 'Test runway bans leaked into permanent rules'; END IF;
 RAISE NOTICE 'PASS: mandatory schedule rejection, review without activation, future law windows and all-airport catalogue';
END $tests$;
ROLLBACK;
