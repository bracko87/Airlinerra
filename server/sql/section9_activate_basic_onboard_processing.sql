-- Release basic onboard processing after finance and satisfaction regression.
-- No retroactive fees, no custom package release in this migration.
DO $release$
DECLARE r jsonb; changed int;
BEGIN
 PERFORM pg_advisory_xact_lock(583729,10041);
 PERFORM pg_advisory_xact_lock(583729,10062);
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_dated_flight_occurrences_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_onboard_departure_snapshots_v1)
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_onboard_finance_receipts_v1)
 THEN RAISE EXCEPTION 'ONBOARD_INITIAL_RELEASE_REQUIRES_EMPTY_FLIGHT_QUEUE';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_flight_finance_posting_release_v1 WHERE world_id=1 AND release_state='approved')
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_passenger_experience_release_v1 WHERE world_id=1 AND collection_enabled)
 OR NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-game-operated-flight-dispatch-v1' AND active)
 OR NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-game-passenger-experience-v1' AND active)
 OR NOT EXISTS(SELECT 1 FROM pg_trigger WHERE tgname='section9_onboard_snapshot_at_booking_close_v1' AND tgenabled='O')
 THEN RAISE EXCEPTION 'ONBOARD_RELEASE_PREREQUISITES_MISSING';END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.airlines a WHERE a.cash_usd IS DISTINCT FROM (SELECT coalesce(sum(l.amount_usd),0) FROM airlinerra_game.airline_ledger l WHERE l.airline_id=a.id)) THEN RAISE EXCEPTION 'ONBOARD_CASH_LEDGER_MISMATCH';END IF;
 r:=airlinerra_game.section9_onboard_service_calculate_v1('release-smoke-100','{"water":{"mode":"included"}}',100,60,70);
 IF r->>'status' IS DISTINCT FROM 'onboard_service_game_calculated' OR r->>'modelVersion' IS DISTINCT FROM 'GAME_CABIN_SERVICE_V2' OR (r->>'revenueCents')::int<>0 OR (r->>'costCents')::int NOT BETWEEN 3900 AND 5200 THEN RAISE EXCEPTION 'ONBOARD_CALCULATION_SMOKE_FAILED';END IF;
 UPDATE airlinerra_game.section9_onboard_service_release_v1 SET snapshot_enabled=true,settlement_enabled=true,satisfaction_enabled=true,custom_route_packages_enabled=false WHERE world_id=1;
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'ONBOARD_RELEASE_SWITCH_FAILED';END IF;
 r:=airlinerra_game.section9_collect_passenger_experience_v1(100);
 IF r->>'status' IS DISTINCT FROM 'passenger_experience_collection_completed' OR r->>'ledgerPosted' IS DISTINCT FROM 'false' OR (r->>'created')::int IS DISTINCT FROM 0 THEN RAISE EXCEPTION 'ONBOARD_EXPERIENCE_SMOKE_FAILED';END IF;
END $release$;
