-- ROLLBACK-ONLY REVIEW. Crew custody foundation.
-- A crew member is unavailable to commercial planning until their storage
-- duty is cancelled before report, or a later reviewed history handoff exists.
-- Do not enable live crew allocation: history handoff remains unfinished.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_crew_reservations_v1(
 request_id uuid NOT NULL REFERENCES airlinerra_game.aircraft_storage_relocation_requests_v1(id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 employee_id uuid NOT NULL,
 seat_role text NOT NULL CHECK(seat_role IN('captain','first_officer','cabin')),
 qualification_group text NOT NULL CHECK(btrim(qualification_group)<>''),
 duty_start_utc timestamptz NOT NULL,duty_end_utc timestamptz NOT NULL,
 origin_airport_key text NOT NULL,destination_airport_key text NOT NULL,
 reserved_at timestamptz NOT NULL,
 status text NOT NULL DEFAULT 'reserved' CHECK(status IN('reserved','cancelled','awaiting_history_handoff')),
 PRIMARY KEY(request_id,employee_id),
 CHECK(duty_end_utc>duty_start_utc AND duty_end_utc-duty_start_utc<=interval '12 hours' AND origin_airport_key<>destination_airport_key)
);
CREATE UNIQUE INDEX storage_crew_exclusive_custody_v1 ON airlinerra_game.aircraft_storage_crew_reservations_v1(airline_id,employee_id) WHERE status<>'cancelled';
ALTER TABLE airlinerra_game.aircraft_storage_crew_reservations_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_crew_reservations_v1 FROM PUBLIC,anon,authenticated,service_role;

-- Same airline row lock used by the commercial crew-plan save function.
CREATE FUNCTION airlinerra_game.guard_commercial_duty_against_storage_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=NEW.airline_id FOR UPDATE;
 IF EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 s WHERE s.airline_id=NEW.airline_id AND s.employee_id=NEW.employee_id AND s.status<>'cancelled')
 THEN RAISE EXCEPTION USING ERRCODE='23514',MESSAGE='CREW_RESERVED_FOR_STORAGE_OR_HISTORY_HANDOFF';END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_commercial_duty_against_storage_v1() FROM PUBLIC,anon,authenticated,service_role;
-- AFTER trigger sees the generated employee_id in the real commercial table.
CREATE TRIGGER guard_commercial_duty_against_storage_v1 AFTER INSERT OR UPDATE ON airlinerra_game.section9_planned_crew_duties_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_commercial_duty_against_storage_v1();

CREATE FUNCTION airlinerra_game.guard_storage_crew_reservation_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record;now_utc timestamptz;
BEGIN
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=NEW.airline_id FOR UPDATE;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=NEW.request_id AND airline_id=NEW.airline_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'STORAGE_CREW_REQUEST_MISMATCH';END IF;
 IF TG_OP='INSERT' THEN
  now_utc:=airlinerra_game.section9_verified_world_instant_v1();
  IF now_utc IS NULL OR NEW.status<>'reserved' OR NEW.reserved_at<>now_utc OR NEW.duty_start_utc<now_utc
   OR r.status NOT IN('awaiting_slot_and_dispatch_release','reactivation_awaiting_review') OR NEW.origin_airport_key<>r.origin_airport_key OR NEW.destination_airport_key<>r.destination_airport_key
   OR NEW.duty_start_utc>r.departure_utc OR NEW.duty_end_utc<r.arrival_utc
   OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND phase='departed')
   OR EXISTS(SELECT 1 FROM airlinerra_game.section9_planned_crew_duties_v1 pd JOIN airlinerra_game.section9_crew_plan_batches_v1 b ON b.plan_id=pd.plan_id AND b.airline_id=pd.airline_id AND b.status='validated_preview' WHERE pd.airline_id=NEW.airline_id AND pd.employee_id=NEW.employee_id AND pd.duty_end_utc>now_utc)
  THEN RAISE EXCEPTION 'STORAGE_CREW_RESERVATION_CONFLICT';END IF;
 ELSE
  IF (to_jsonb(NEW)-'status') IS DISTINCT FROM (to_jsonb(OLD)-'status') OR OLD.status<>'reserved' THEN RAISE EXCEPTION 'STORAGE_CREW_RESERVATION_IMMUTABLE';END IF;
  IF NEW.status='cancelled' THEN
   IF r.status<>'cancelled' OR airlinerra_game.section9_verified_world_instant_v1() IS NULL OR airlinerra_game.section9_verified_world_instant_v1()>=OLD.duty_start_utc OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id AND phase='departed') THEN RAISE EXCEPTION 'STORAGE_CREW_CANCELLATION_NOT_VERIFIED';END IF;
  ELSIF NEW.status='awaiting_history_handoff' THEN
   IF r.status<>'completed' AND r.status<>'cancelled' THEN RAISE EXCEPTION 'STORAGE_CREW_HANDOFF_NOT_READY';END IF;
  ELSE RAISE EXCEPTION 'STORAGE_CREW_STATUS_INVALID';END IF;
 END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_storage_crew_reservation_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER guard_storage_crew_reservation_v1 BEFORE INSERT OR UPDATE ON airlinerra_game.aircraft_storage_crew_reservations_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_storage_crew_reservation_v1();

CREATE FUNCTION airlinerra_game.finish_storage_crew_reservation_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 IF NEW.status='cancelled' AND OLD.status IS DISTINCT FROM NEW.status THEN
  UPDATE airlinerra_game.aircraft_storage_crew_reservations_v1 SET status=CASE WHEN airlinerra_game.section9_verified_world_instant_v1()<duty_start_utc THEN 'cancelled' ELSE 'awaiting_history_handoff' END
  WHERE request_id=NEW.id AND status='reserved';
 ELSIF NEW.status='completed' AND OLD.status IS DISTINCT FROM NEW.status THEN
  UPDATE airlinerra_game.aircraft_storage_crew_reservations_v1 SET status='awaiting_history_handoff' WHERE request_id=NEW.id AND status='reserved';
 END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.finish_storage_crew_reservation_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER finish_storage_crew_reservation_v1 AFTER UPDATE OF status ON airlinerra_game.aircraft_storage_relocation_requests_v1
 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.finish_storage_crew_reservation_v1();
ROLLBACK;
