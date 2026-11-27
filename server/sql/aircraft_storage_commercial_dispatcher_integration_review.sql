-- ROLLBACK-ONLY REVIEW. Patch the exact current dispatcher, preserving
-- delayed approval, downstream recovery, event isolation and turnaround.
BEGIN;
DO $patch$
DECLARE original text; updated text; old_fragment text; new_fragment text; p record;
BEGIN
 original:=pg_get_functiondef(to_regprocedure('airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)'));
 IF original IS NULL OR md5(original)<>'7ef977a05bec5b899d52d1548afbf1d8' THEN RAISE EXCEPTION 'STORAGE_DISPATCHER_SOURCE_DRIFT';END IF;
 updated:=original;
 FOR p IN SELECT * FROM (VALUES
 ($old$event_error_code text;event_error_message text;event_block_key text;atomic_event_rollbacks integer:=0;$old$,
 $new$event_error_code text;event_error_message text;event_block_key text;atomic_event_rollbacks integer:=0;
 storage_binding_required boolean;storage_handoff_check jsonb;$new$),
 ($old$  IF reason IS NOT NULL THEN
    IF event_isolation_enabled THEN RAISE EXCEPTION USING ERRCODE='ZXV01',MESSAGE=reason;END IF;$old$,
 $new$  storage_binding_required:=false;
  IF reason IS NULL AND evt.phase='departed' THEN
   storage_handoff_check:=airlinerra_game.storage_commercial_handoff_dispatch_check_v1(evt.airline_id,evt.physical_id);
   IF storage_handoff_check->>'status'='storage_handoff_dispatch_integration_required' THEN
    IF NOT event_isolation_enabled OR delayed_binding_required OR downstream_required
     OR NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_commercial_binding_release_v1 WHERE world_id=1 AND enabled)
     THEN reason:='STORAGE_HANDOFF_REQUIRES_EXCLUSIVE_ATOMIC_BINDING';
    ELSE storage_binding_required:=true;
    END IF;
   ELSIF storage_handoff_check->>'allowed' IS DISTINCT FROM 'true' THEN reason:='STORAGE_COMMERCIAL_CREW_CUSTODY_CONFLICT';
   END IF;
  END IF;
  IF reason IS NOT NULL THEN
    IF event_isolation_enabled THEN RAISE EXCEPTION USING ERRCODE='ZXV01',MESSAGE=reason;END IF;$new$),
 ($old$    IF delayed_binding_required THEN
     crew_capture:=airlinerra_game.section9_bind_approved_delayed_crew_v1(evt.airline_id,evt.occurrence_id,movement_event_id);$old$,
 $new$    IF storage_binding_required THEN
     crew_capture:=airlinerra_game.bind_storage_aware_commercial_departure_v1(evt.airline_id,evt.physical_id,movement_event_id);
     IF crew_capture->>'status' IS DISTINCT FROM 'crew_departure_bound' THEN
      RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='STORAGE_COMMERCIAL_DEPARTURE_BINDING_FAILED';
     END IF;
    ELSIF delayed_binding_required THEN
     crew_capture:=airlinerra_game.section9_bind_approved_delayed_crew_v1(evt.airline_id,evt.occurrence_id,movement_event_id);$new$),
 ($old$    IF normal_crew_enforcement_enabled THEN
     crew_capture:=airlinerra_game.section9_complete_bound_crew_arrival_v1(evt.airline_id,evt.physical_id,movement_event_id);$old$,
 $new$    IF normal_crew_enforcement_enabled OR EXISTS(
      SELECT 1 FROM airlinerra_game.storage_commercial_departure_crew_evidence_v1 e
      WHERE e.airline_id=evt.airline_id AND e.physical_flight_id=evt.physical_id
    ) THEN
     crew_capture:=airlinerra_game.section9_complete_bound_crew_arrival_v1(evt.airline_id,evt.physical_id,movement_event_id);$new$)
 ) v(old_text,new_text)
 LOOP
  IF (length(updated)-length(replace(updated,p.old_text,'')))/length(p.old_text)<>1 THEN RAISE EXCEPTION 'STORAGE_DISPATCHER_PATCH_ANCHOR_DRIFT';END IF;
  updated:=replace(updated,p.old_text,p.new_text);
 END LOOP;
 EXECUTE updated;
 IF EXISTS(SELECT 1 FROM unnest(ARRAY['anon','authenticated','service_role']) r(role_name)
 WHERE has_function_privilege(r.role_name,'airlinerra_game.section9_auto_dispatch_due_flight_events_v1(integer)','EXECUTE'))
 THEN RAISE EXCEPTION 'STORAGE_DISPATCHER_PRIVILEGE_DRIFT';END IF;
 RAISE NOTICE 'Current dispatcher patched in isolated review; legacy branches preserved, storage binding requires exclusive atomic event';
END $patch$;
ROLLBACK;
