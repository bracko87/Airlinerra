-- Structural compatibility only; not operational flight acceptance.
DO $test$
DECLARE s text;
BEGIN
 IF current_database()<>'airlinerra_disposable' THEN RAISE EXCEPTION 'disposable database required';END IF;
 s:=pg_get_functiondef('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)'::regprocedure);
 IF position('storage_binding_required:=false;' in s)=0
 OR position('STORAGE_HANDOFF_REQUIRES_EXCLUSIVE_ATOMIC_BINDING' in s)=0
 OR position('OR delayed_binding_required OR downstream_required' in s)=0
 OR position('bind_storage_aware_commercial_departure_v1' in s)=0
 OR position('STORAGE_COMMERCIAL_DEPARTURE_BINDING_FAILED' in s)=0
 OR position('section9_bind_approved_delayed_crew_v1' in s)=0
 OR position('section9_auto_recover_delayed_crew_cycle_v1' in s)=0
 OR position('section9_auto_replan_downstream_cycle_v1' in s)=0
 OR position('section9_capture_actual_turnaround_v1' in s)=0
 OR position('section9_complete_bound_crew_arrival_v1' in s)=0
 OR position('storage_commercial_departure_crew_evidence_v1' in s)=0
 OR position('event_committed:=true;' in s)=0
 OR position('atomic_event_rollbacks:=atomic_event_rollbacks+1' in s)=0
 THEN RAISE EXCEPTION 'dispatcher structural integration incomplete';END IF;
 IF EXISTS(SELECT 1 FROM unnest(ARRAY['anon','authenticated','service_role']) AS r(role_name) WHERE has_function_privilege(r.role_name,'airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)','EXECUTE')) THEN RAISE EXCEPTION 'dispatcher grant drift';END IF;
 RAISE NOTICE 'Dispatcher structural patch acceptance passed: legacy recovery, isolation, turnaround and storage binding markers; private grants preserved';
END $test$;
