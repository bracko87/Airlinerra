-- Read-only source compatibility audit, not a migration.
BEGIN TRANSACTION READ ONLY;
WITH expected(signature,expected_hash) AS (VALUES
 ('airlinerra_game.section9_auto_supply_game_only_fuel_v1(text)','ec884e2b3c7fae76b7fe129067f32e2c'),
 ('airlinerra_game.section9_verify_game_fuel_before_departure_v1(text)','8485598ffa10225b14b17adbc2a45867'),
 ('airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(uuid,uuid,uuid,timestamptz,timestamptz)','55a3903eb1fa311df18a51e90f666676'),
 ('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)','7ef977a05bec5b899d52d1548afbf1d8')
), function_checks AS (
 SELECT signature AS component,coalesce(md5(pg_get_functiondef(to_regprocedure(signature)))=expected_hash,false) AS matched FROM expected
), ledger_check AS (
 SELECT 'airline_ledger.valid_entry_kind'::text AS component, EXISTS(
 SELECT 1 FROM pg_constraint WHERE conrelid=to_regclass('airlinerra_game.airline_ledger') AND conname='valid_entry_kind'
 AND contype='c' AND convalidated AND md5(pg_get_constraintdef(oid))='8acbb97bdb2207e8ceae41f2d6f3f216') AS matched
)
SELECT component,matched,CASE WHEN matched THEN 'SOURCE_MATCHED' ELSE 'BLOCKED_SOURCE_DRIFT' END AS status FROM (
 SELECT * FROM function_checks UNION ALL SELECT * FROM ledger_check
) checks ORDER BY component;
SELECT md5(pg_get_functiondef(to_regprocedure('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)'))) AS dispatcher_hash,
coalesce(position('bind_storage_aware_commercial_departure_v1' in pg_get_functiondef(to_regprocedure('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)')))>0,false) AS storage_binding_hook_present,
'REQUIRES_ISOLATED_SCHEMA_AND_INTEGRATED_RUNTIME_ACCEPTANCE' AS dispatcher_release_status;
ROLLBACK;
