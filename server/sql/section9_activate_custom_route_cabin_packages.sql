-- Custom route service packages: release after isolated route assignment,
-- frozen package prices, departure capture, finance and satisfaction regression.
DO $release$
DECLARE changed integer;
BEGIN
 PERFORM pg_advisory_xact_lock(583729,10041);
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_onboard_service_release_v1 WHERE world_id=1 AND snapshot_enabled AND settlement_enabled AND satisfaction_enabled)
 THEN RAISE EXCEPTION 'CUSTOM_PACKAGE_ONBOARD_PREREQUISITES_MISSING';END IF;
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-game-operated-flight-dispatch-v1' AND active)
 OR NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-game-passenger-experience-v1' AND active)
 THEN RAISE EXCEPTION 'CUSTOM_PACKAGE_SCHEDULERS_MISSING';END IF;
 IF has_function_privilege('authenticated','airlinerra_game.section9_create_active_route_with_cabin_v1(uuid,uuid,uuid,text,text,text,jsonb,text,text,integer,numeric,text)','EXECUTE')
 OR has_table_privilege('authenticated','airlinerra_game.section9_route_onboard_packages_v1','INSERT')
 OR EXISTS(SELECT 1 FROM airlinerra_game.airlines a WHERE a.cash_usd IS DISTINCT FROM (SELECT coalesce(sum(l.amount_usd),0) FROM airlinerra_game.airline_ledger l WHERE l.airline_id=a.id))
 THEN RAISE EXCEPTION 'CUSTOM_PACKAGE_SECURITY_OR_ACCOUNTING_CHECK_FAILED';END IF;
 UPDATE airlinerra_game.section9_onboard_service_release_v1 SET custom_route_packages_enabled=true WHERE world_id=1 AND snapshot_enabled AND settlement_enabled AND satisfaction_enabled;
 GET DIAGNOSTICS changed=ROW_COUNT;
 IF changed<>1 THEN RAISE EXCEPTION 'CUSTOM_PACKAGE_RELEASE_FAILED';END IF;
END $release$;
