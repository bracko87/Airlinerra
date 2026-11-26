-- REVIEW ONLY: run on an isolated schema clone, never as a live release.
-- Preserve current function definitions, ownership and privileges; fail if
-- the expected legacy predicate is absent or appears more than once.
BEGIN;
DO $review$
DECLARE sig text; fn regprocedure; original text; revised text;
 old_pred constant text := 'approved_offer.pricing_basis LIKE ''AIRLINERRA_GAME_BALANCE_V1:%''';
 new_pred constant text := '(approved_offer.pricing_basis LIKE ''AIRLINERRA_GAME_BALANCE_V1:%'' OR approved_offer.pricing_basis = ''AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2'')';
BEGIN
 FOREACH sig IN ARRAY ARRAY[
 'airlinerra_game.section9_capture_approved_delivery_position_v1(uuid,uuid)',
 'airlinerra_game.section9_sync_approved_delivery_positions_v1(integer)'
 ] LOOP
  fn := to_regprocedure(sig);
  IF fn IS NULL THEN RAISE EXCEPTION 'Missing delivery function: %',sig; END IF;
  original := pg_get_functiondef(fn);
  IF (length(original)-length(replace(original,old_pred,''))) <> length(old_pred)
   THEN RAISE EXCEPTION 'Unexpected delivery predicate: %',sig; END IF;
  revised := replace(original,old_pred,new_pred);
  EXECUTE revised;
 END LOOP;
END $review$;
-- The owner preview also checks the legacy basis. Discover its exact
-- signature before applying the identical guarded transformation.
DO $review$
DECLARE fn regprocedure; n integer; original text;
 old_pred constant text := 'approved_offer.pricing_basis LIKE ''AIRLINERRA_GAME_BALANCE_V1:%''';
 new_pred constant text := '(approved_offer.pricing_basis LIKE ''AIRLINERRA_GAME_BALANCE_V1:%'' OR approved_offer.pricing_basis = ''AIRLINERRA_NEW_FACTORY_GAME_ESTIMATE_V2'')';
BEGIN
 SELECT count(*) INTO n FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace
 WHERE s.nspname='airlinerra_game' AND p.proname='section9_owned_aircraft_delivery_position_preview_v1';
 IF n<>1 THEN RAISE EXCEPTION 'Unexpected delivery preview overload count: %',n; END IF;
 SELECT p.oid::regprocedure INTO fn FROM pg_proc p JOIN pg_namespace s ON s.oid=p.pronamespace
 WHERE s.nspname='airlinerra_game' AND p.proname='section9_owned_aircraft_delivery_position_preview_v1';
 original:=pg_get_functiondef(fn);
 IF (length(original)-length(replace(original,old_pred,'')))<>length(old_pred)
 THEN RAISE EXCEPTION 'Unexpected delivery preview predicate'; END IF;
 EXECUTE replace(original,old_pred,new_pred);
END $review$;
-- No offer publication, lease enablement, inspection approval or data changes.
-- Roll back by design until actual current schema and negative tests pass.
-- Isolated fixture hook: test the transformed functions before rollback.
\if :{?factory_delivery_fixture}
\i tests/sql/aircraft_factory_delivery_compatibility_acceptance.sql
\endif
ROLLBACK;
