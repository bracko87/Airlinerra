-- Disposable-only acceptance of the UNCHANGED production recovery writer.
-- Exercise fail-closed gates, existing receipt replay, identity validation.
-- No real cancellation, inventory mutation or financial postings.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 OR to_regclass('airlinerra_game.section9_connection_recovery_receipts_v1') IS NOT NULL
 OR to_regclass('airlinerra_game.section9_disruption_release_v1') IS NOT NULL
 THEN RAISE EXCEPTION 'RECOVERY_WRITER_DISPOSABLE_ONLY';END IF;
END $guard$;
CREATE TABLE airlinerra_game.section9_disruption_release_v1(
 world_id smallint PRIMARY KEY,connecting_recovery_enabled boolean NOT NULL);
INSERT INTO airlinerra_game.section9_disruption_release_v1 VALUES(1,false);
CREATE TABLE airlinerra_game.section9_connection_recovery_receipts_v1(
 source_allocation_key text PRIMARY KEY,
 replacement_allocation_key text UNIQUE,
 first_ticket_key text NOT NULL,
 recorded_at timestamptz NOT NULL DEFAULT now(),
 result jsonb NOT NULL CHECK(jsonb_typeof(result)='object'));
\i tests/sql/section9_disposable_original_connection_recovery_writer.sql

DO $fail_closed$
DECLARE result jsonb; key text:='s9g1:'||repeat('e',64); caught boolean:=false;
BEGIN
 result:=airlinerra_game.section9_recover_connecting_passengers_v1(key,NULL,1440);
 IF result->>'status'<>'connection_recovery_not_released'
 OR result->>'recovered'<>'false'
 THEN RAISE EXCEPTION 'Release-disabled function did not fail closed: %',result;END IF;
 BEGIN
  PERFORM airlinerra_game.section9_recover_connecting_passengers_v1(key,NULL,59);
 EXCEPTION WHEN OTHERS THEN
  IF SQLERRM='INVALID_CONNECTION_RECOVERY_INPUT' THEN caught:=true; ELSE RAISE;END IF;
 END;
 IF NOT caught THEN RAISE EXCEPTION 'Recovery accepted invalid waiting window';END IF;
 UPDATE airlinerra_game.section9_disruption_release_v1
 SET connecting_recovery_enabled=true WHERE world_id=1;
 result:=airlinerra_game.section9_recover_connecting_passengers_v1(key,NULL,1440);
 IF result->>'status'<>'passenger_connection_unavailable_or_mixed_cargo'
 OR result->>'recovered'<>'false' THEN
 RAISE EXCEPTION 'Unknown allocation did not fail closed: %',result;END IF;
END $fail_closed$;

INSERT INTO airlinerra_game.section9_connection_recovery_receipts_v1(
 source_allocation_key,replacement_allocation_key,first_ticket_key,result)
 VALUES('s9g1:'||repeat('e',64),NULL,'demand.s9g1:'||repeat('e',64),
 '{"status":"connection_unflown_seats_released","recovered":true,"refundUsd":0,"ledgerPosted":false}'::jsonb);
DO $replay$
DECLARE result jsonb;key text:='s9g1:'||repeat('e',64);
BEGIN
 result:=airlinerra_game.section9_recover_connecting_passengers_v1(key,NULL,1440);
 IF result->>'status'<>'connection_unflown_seats_released'
 OR result->>'recovered'<>'true'
 OR result->>'replayed'<>'true'
 OR result->>'refundUsd'<>'0'
 OR result->>'ledgerPosted'<>'false'
 OR (SELECT count(*) FROM airlinerra_game.section9_connection_recovery_receipts_v1
    WHERE source_allocation_key=key)<>1
 THEN RAISE EXCEPTION 'Original recovery receipt replay failed: %',result;END IF;
 IF has_function_privilege('anon',
   'airlinerra_game.section9_recover_connecting_passengers_v1(text,text,integer)','EXECUTE')
 OR has_function_privilege('authenticated',
   'airlinerra_game.section9_recover_connecting_passengers_v1(text,text,integer)','EXECUTE')
 OR has_function_privilege('service_role',
   'airlinerra_game.section9_recover_connecting_passengers_v1(text,text,integer)','EXECUTE')
 THEN RAISE EXCEPTION 'Recovery writer client execution privilege exposed';END IF;
 RAISE NOTICE 'PASS unchanged private connecting recovery writer: release, input, missing claim, replay and grants';
END $replay$;
