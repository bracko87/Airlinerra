-- ROLLBACK-ONLY REVIEW. Clone the existing maintenance gate, without changing
-- commercial dispatch or allowing stored aircraft into regular operations.
BEGIN;
DO $patch$
DECLARE original text; updated text;
 old_scope text:='AND f.fleet_status=''in_service'' AND f.ownership_type IN(''owned'',''leased'');';
 new_scope text:='AND f.fleet_status=''stored'' AND f.ownership_type=''owned''
 AND EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r
 WHERE r.airline_id=p_airline AND r.aircraft_inventory_id=p_aircraft AND r.owner_player_id=p_owner
 AND r.purpose=''storage_reactivation'' AND r.status=''reactivation_awaiting_review''
 AND r.departure_utc=p_depart_utc AND r.arrival_utc=p_arrive_utc
 AND airlinerra_game.reactivation_reservation_evidence_v1(r.id));';
BEGIN
 original:=pg_get_functiondef(to_regprocedure('airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(uuid,uuid,uuid,timestamptz,timestamptz)'));
 IF original IS NULL OR md5(original)<>'55a3903eb1fa311df18a51e90f666676' THEN RAISE EXCEPTION 'STORAGE_MAINTENANCE_SOURCE_DRIFT';END IF;
 IF (length(original)-length(replace(original,old_scope,'')))/length(old_scope)<>1 THEN RAISE EXCEPTION 'STORAGE_MAINTENANCE_SCOPE_DRIFT';END IF;
 updated:=replace(original,'FUNCTION airlinerra_game.section9_verified_game_maintenance_dispatch_window_v1(','FUNCTION airlinerra_game.storage_reactivation_maintenance_window_v1(');
 IF updated=original THEN RAISE EXCEPTION 'STORAGE_MAINTENANCE_NAME_DRIFT';END IF;
 EXECUTE replace(updated,old_scope,new_scope);
END $patch$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_reactivation_maintenance_window_v1(uuid,uuid,uuid,timestamptz,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
