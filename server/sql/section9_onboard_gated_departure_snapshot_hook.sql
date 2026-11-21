-- Capture at the exact booking-close transition of an operated flight.
-- Release switches remain off. Missing evidence does not prevent flight operations.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_onboard_snapshot_at_booking_close_v1()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE outcome jsonb;
BEGIN
 IF OLD.booking_status='open' AND NEW.booking_status='closed'
 AND EXISTS(SELECT 1 FROM airlinerra_game.section9_onboard_service_release_v1 WHERE world_id=NEW.world_id AND snapshot_enabled)
 THEN
  BEGIN
   outcome:=airlinerra_game.section9_snapshot_onboard_departure_v1(NEW.schedule_id::text||':'||NEW.flight_local_date::text||':'||NEW.weekly_entry::text);
   IF outcome->>'status' NOT IN('onboard_snapshot_captured','onboard_snapshot_already_captured') THEN
    RAISE WARNING 'Onboard service snapshot omitted for occurrence %: %', NEW.id, outcome->>'status';
   END IF;
  EXCEPTION WHEN OTHERS THEN
   RAISE WARNING 'Onboard service snapshot failed for occurrence %, SQLSTATE %',NEW.id,SQLSTATE;
  END;
 END IF;
 RETURN NEW;
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_onboard_snapshot_at_booking_close_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER section9_onboard_snapshot_at_booking_close_v1
AFTER UPDATE OF booking_status ON airlinerra_game.section9_dated_flight_occurrences_v1
FOR EACH ROW WHEN(OLD.booking_status IS DISTINCT FROM NEW.booking_status)
EXECUTE FUNCTION airlinerra_game.section9_onboard_snapshot_at_booking_close_v1();
