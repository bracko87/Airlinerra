-- SAFETY CORRECTION: this earlier 2026-11-23 full dispatcher replacement
-- was built against the obsolete permission-application source. On current
-- World 1 the issue is ALREADY fixed by newer canonical AOC/L1/L2 logic,
-- while the dispatcher contains modern delayed flights, crew enforcement,
-- disruption recovery and atomic event isolation. Replacing it with that
-- full old SQL would silently DELETE those working features.
--
-- Consequently this historical migration is a DRIFT-GUARDED NO-OP on the
-- current deployed source, NOT a function replacement. Fail-closed if it
-- sees any earlier deployment needing manual source-based reconciliation.
-- NO release flags, player rows, game money or triggers are changed.
DO $verify_current_dispatch$
DECLARE
 fn_oid oid;
 src text;
BEGIN
 SELECT to_regprocedure(
  'airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)'
 )::oid INTO fn_oid;
 IF fn_oid IS NULL THEN
  RAISE EXCEPTION 'SECTION9_DISPATCH_NOT_INSTALLED_NO_SAFE_MIGRATION';
 END IF;
 SELECT pg_get_functiondef(fn_oid) INTO src;
 IF src IS NULL
  OR position('required_permission_code text;' IN src)=0
  OR position('section9_canonical_aoc_covers_v1' IN src)=0
  OR position('section9_game_route_licence_scope_v1' IN src)=0
  OR position('section9_effective_dispatch_window_v1' IN src)=0
  OR position('section9_delayed_turnaround_clear_v1' IN src)=0
  OR position('section9_capture_dispatched_crew_v1' IN src)=0
  OR position('event_isolation_enabled' IN src)=0
  OR position('normal_crew_enforcement_enabled' IN src)=0
  OR position('section9_record_signed_operated_flight_movement_v1' IN src)=0
  OR position('a.permission_code=required_permission_code' IN src)>0
 THEN
  RAISE EXCEPTION 'SECTION9_DISPATCH_SOURCE_DRIFT_REQUIRES_MANUAL_RECONCILIATION';
 END IF;
 RAISE NOTICE 'Section9 current canonical AOC/rights and delayed-crew dispatcher already supersedes historical 20261123210000; NO SQL rewrite applied';
END $verify_current_dispatch$;
