-- Additional defense: do not allow bypassing certified transition via
-- INSERT(status='active',operationally_verified=true).
-- Uncertified draft inserts are unchanged. No existing game rows modified.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_guard_schedule_activation_update_v1()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'airlinerra_game', 'pg_catalog'
AS $function$
DECLARE proof record; release_record record; clock_record record;
BEGIN
 -- Prevent direct INSERT of an active/verified schedule: every schedule
 -- must enter as a draft and only the guarded transition may activate it.
 IF TG_OP='INSERT' THEN
  IF NEW.status='draft' AND NEW.operationally_verified=false
  THEN RETURN NEW;END IF;
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_ACTIVE_SCHEDULE_INSERT_NOT_AUTHORIZED';
 END IF;
 IF OLD.status='active' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_ACTIVE_SCHEDULE_IMMUTABLE';
 END IF;
 IF NEW.status IS NOT DISTINCT FROM OLD.status
    AND NEW.operationally_verified IS NOT DISTINCT FROM OLD.operationally_verified
 THEN RETURN NEW; END IF;
 IF OLD.status IS DISTINCT FROM 'draft'
    OR OLD.operationally_verified IS DISTINCT FROM false
    OR NEW.status IS DISTINCT FROM 'active'
    OR NEW.operationally_verified IS DISTINCT FROM true
    OR (to_jsonb(NEW)-'status'-'operationally_verified'-'updated_at')
       IS DISTINCT FROM
       (to_jsonb(OLD)-'status'-'operationally_verified'-'updated_at')
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_UNAUTHORIZED_SCHEDULE_STATE_CHANGE';
 END IF;
 SELECT * INTO proof
 FROM airlinerra_game.section9_schedule_activation_preparations_v1
 WHERE schedule_id=OLD.id AND schedule_version=OLD.version
    AND airline_id=OLD.airline_id AND aircraft_inventory_id=OLD.aircraft_inventory_id
 FOR SHARE;
 SELECT * INTO release_record
 FROM airlinerra_game.section9_activation_release_policy_v1
 WHERE world_id=1 FOR SHARE;
 SELECT confirmed_game_date,clock_source,last_verified_at
 INTO clock_record FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=1 FOR SHARE;
 IF proof.fingerprint_md5 IS DISTINCT FROM
     airlinerra_game.section9_activation_evidence_fingerprint_v1(OLD.id)
 OR proof.verified_game_date IS DISTINCT FROM clock_record.confirmed_game_date
 OR proof.release_reference IS DISTINCT FROM release_record.release_reference
 OR release_record.release_state IS DISTINCT FROM 'enabled'
 OR release_record.enabled_at IS NULL OR release_record.reviewed_at IS NULL
 OR clock_record.clock_source IS DISTINCT FROM 'authoritative_game_engine'
 OR clock_record.last_verified_at IS NULL
 OR NOT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1 r
   WHERE r.world_id=1 AND r.game_date=proof.verified_game_date
 )
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_SCHEDULE_ACTIVATION_NOT_PREPARED_OR_RELEASED';
 END IF;
 RETURN NEW;
END $function$;
DROP TRIGGER IF EXISTS section9_schedule_activation_guard_v1
 ON airlinerra_game.airline_flight_schedule_drafts_v1;
CREATE TRIGGER section9_schedule_activation_guard_v1
BEFORE INSERT OR UPDATE ON airlinerra_game.airline_flight_schedule_drafts_v1
FOR EACH ROW EXECUTE FUNCTION
 airlinerra_game.section9_guard_schedule_activation_update_v1();
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_guard_schedule_activation_update_v1()
 FROM PUBLIC,anon,authenticated,service_role;
