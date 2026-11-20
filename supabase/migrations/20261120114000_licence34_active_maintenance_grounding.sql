-- Licence 3/4 long maintenance integration. While any suitable aircraft has an
-- active game maintenance job, exclude that tail from operational counts.
-- Scheduled future checks do not start the outage clock.
DO $patch$
DECLARE fn text;
BEGIN
-- licence3_cargo_readiness_v1
 SELECT pg_get_functiondef(p.oid) INTO fn
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='airlinerra_game' AND p.proname='licence3_cargo_readiness_v1';
 IF fn IS NULL OR strpos(fn,$old0$WHERE f.airline_id=p_airline AND f.fleet_status='in_service'$old0$)=0 THEN
  RAISE EXCEPTION 'EXPECTED_LICENCE_MAINTENANCE_PREDICATE_MISSING: licence3_cargo_readiness_v1';
 END IF;
 fn:=replace(fn,$old0$WHERE f.airline_id=p_airline AND f.fleet_status='in_service'$old0$,$new0$WHERE f.airline_id=p_airline AND f.fleet_status='in_service' AND NOT EXISTS(
      SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 maint
      WHERE maint.airline_id=f.airline_id
       AND maint.aircraft_inventory_id=f.id
       AND maint.status IN ('in_progress','payment_required')
     )$new0$);
 EXECUTE fn;

-- licence4_charter_readiness_v1
 SELECT pg_get_functiondef(p.oid) INTO fn
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='airlinerra_game' AND p.proname='licence4_charter_readiness_v1';
 IF fn IS NULL OR strpos(fn,$old1$WHERE f.airline_id=p_airline AND f.fleet_status='in_service'$old1$)=0 THEN
  RAISE EXCEPTION 'EXPECTED_LICENCE_MAINTENANCE_PREDICATE_MISSING: licence4_charter_readiness_v1';
 END IF;
 fn:=replace(fn,$old1$WHERE f.airline_id=p_airline AND f.fleet_status='in_service'$old1$,$new1$WHERE f.airline_id=p_airline AND f.fleet_status='in_service' AND NOT EXISTS(
      SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 maint
      WHERE maint.airline_id=f.airline_id
       AND maint.aircraft_inventory_id=f.id
       AND maint.status IN ('in_progress','payment_required')
     )$new1$);
 EXECUTE fn;

-- licence3_cargo_flight_scope_v1
 SELECT pg_get_functiondef(p.oid) INTO fn
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='airlinerra_game' AND p.proname='licence3_cargo_flight_scope_v1';
 IF fn IS NULL OR strpos(fn,$old2$WHERE fleet.airline_id=l.airline_id AND fleet.fleet_status='in_service'$old2$)=0 THEN
  RAISE EXCEPTION 'EXPECTED_LICENCE_MAINTENANCE_PREDICATE_MISSING: licence3_cargo_flight_scope_v1';
 END IF;
 fn:=replace(fn,$old2$WHERE fleet.airline_id=l.airline_id AND fleet.fleet_status='in_service'$old2$,$new2$WHERE fleet.airline_id=l.airline_id AND fleet.fleet_status='in_service' AND NOT EXISTS(
      SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 maint
      WHERE maint.airline_id=fleet.airline_id
       AND maint.aircraft_inventory_id=fleet.id
       AND maint.status IN ('in_progress','payment_required')
     )$new2$);
 EXECUTE fn;

-- licence4_charter_flight_scope_v1
 SELECT pg_get_functiondef(p.oid) INTO fn
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='airlinerra_game' AND p.proname='licence4_charter_flight_scope_v1';
 IF fn IS NULL OR strpos(fn,$old3$WHERE fleet.airline_id=l.airline_id AND fleet.fleet_status='in_service'$old3$)=0 THEN
  RAISE EXCEPTION 'EXPECTED_LICENCE_MAINTENANCE_PREDICATE_MISSING: licence4_charter_flight_scope_v1';
 END IF;
 fn:=replace(fn,$old3$WHERE fleet.airline_id=l.airline_id AND fleet.fleet_status='in_service'$old3$,$new3$WHERE fleet.airline_id=l.airline_id AND fleet.fleet_status='in_service' AND NOT EXISTS(
      SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 maint
      WHERE maint.airline_id=fleet.airline_id
       AND maint.aircraft_inventory_id=fleet.id
       AND maint.status IN ('in_progress','payment_required')
     )$new3$);
 EXECUTE fn;

-- licence34_review_aircraft_grace_v1
 SELECT pg_get_functiondef(p.oid) INTO fn
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='airlinerra_game' AND p.proname='licence34_review_aircraft_grace_v1';
 IF fn IS NULL OR strpos(fn,$old4$WHERE f.airline_id=row_data.airline_id AND f.fleet_status='in_service'$old4$)=0 THEN
  RAISE EXCEPTION 'EXPECTED_LICENCE_MAINTENANCE_PREDICATE_MISSING: licence34_review_aircraft_grace_v1';
 END IF;
 fn:=replace(fn,$old4$WHERE f.airline_id=row_data.airline_id AND f.fleet_status='in_service'$old4$,$new4$WHERE f.airline_id=row_data.airline_id AND f.fleet_status='in_service' AND NOT EXISTS(
      SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 maint
      WHERE maint.airline_id=f.airline_id
       AND maint.aircraft_inventory_id=f.id
       AND maint.status IN ('in_progress','payment_required')
     )$new4$);
 EXECUTE fn;

-- licence34_operator_status_v1
 SELECT pg_get_functiondef(p.oid) INTO fn
  FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
  WHERE n.nspname='airlinerra_game' AND p.proname='licence34_operator_status_v1';
 IF fn IS NULL OR strpos(fn,$old5$WHERE i.airline_id=p_airline AND i.fleet_status='in_service'$old5$)=0 THEN
  RAISE EXCEPTION 'EXPECTED_LICENCE_MAINTENANCE_PREDICATE_MISSING: licence34_operator_status_v1';
 END IF;
 fn:=replace(fn,$old5$WHERE i.airline_id=p_airline AND i.fleet_status='in_service'$old5$,$new5$WHERE i.airline_id=p_airline AND i.fleet_status='in_service' AND NOT EXISTS(
      SELECT 1 FROM airlinerra_game.section9_game_maintenance_jobs_v1 maint
      WHERE maint.airline_id=i.airline_id
       AND maint.aircraft_inventory_id=i.id
       AND maint.status IN ('in_progress','payment_required')
     )$new5$);
 EXECUTE fn;

END $patch$;