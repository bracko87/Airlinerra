-- ROLLBACK-ONLY REVIEW. Signed crew movement evidence, not planner handoff.
-- Keep custody locked after arrival until both commercial and storage history
-- consumers have been adapted. No employee base/initial position is overwritten.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_crew_duty_receipts_v1(
 request_id uuid NOT NULL,employee_id uuid NOT NULL,
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 departure_engine_event_id text NOT NULL REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 arrival_engine_event_id text REFERENCES airlinerra_game.section9_operated_flight_movements_v1(engine_event_id),
 reported_duty_start_utc timestamptz NOT NULL,
 actual_departure_utc timestamptz NOT NULL,actual_arrival_utc timestamptz,
 completed_duty_end_utc timestamptz,rest_complete_utc timestamptz,
 origin_airport_key text NOT NULL,destination_airport_key text NOT NULL,
 PRIMARY KEY(request_id,employee_id),
 FOREIGN KEY(request_id,employee_id) REFERENCES airlinerra_game.aircraft_storage_crew_reservations_v1(request_id,employee_id),
 CHECK(actual_departure_utc>=reported_duty_start_utc),
 CHECK((arrival_engine_event_id IS NULL AND actual_arrival_utc IS NULL AND completed_duty_end_utc IS NULL AND rest_complete_utc IS NULL)
 OR (arrival_engine_event_id IS NOT NULL AND actual_arrival_utc IS NOT NULL AND actual_arrival_utc>actual_departure_utc
 AND completed_duty_end_utc IS NOT NULL AND completed_duty_end_utc>=actual_arrival_utc AND rest_complete_utc IS NOT NULL AND rest_complete_utc>=completed_duty_end_utc+interval '12 hours'))
);
ALTER TABLE airlinerra_game.aircraft_storage_crew_duty_receipts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_crew_duty_receipts_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.capture_storage_crew_departure_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record;model record;pol record;count_c int;count_f int;count_a int;expected int;ds timestamptz;de timestamptz;cfg bigint;
BEGIN
 IF NEW.storage_request_id IS NULL OR NEW.phase<>'departed' THEN RETURN NEW;END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=NEW.storage_request_id) THEN RETURN NEW;END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=NEW.airline_id FOR UPDATE;
 SELECT * INTO STRICT r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=NEW.storage_request_id AND airline_id=NEW.airline_id AND aircraft_inventory_id=NEW.aircraft_inventory_id FOR UPDATE;
 cfg:=(r.quote->>'configurationId')::bigint;
 SELECT * INTO STRICT model FROM airlinerra_game.section9_flight_crew_model_policy_v1 WHERE configuration_id=cfg;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 ds:=r.departure_utc-make_interval(mins=>pol.preflight_minutes);
 de:=r.arrival_utc+make_interval(mins=>pol.postflight_minutes);
 expected:=CASE WHEN r.arrival_utc-r.departure_utc>interval '6 hours' THEN 2 ELSE 1 END;
 SELECT count(*) FILTER(WHERE seat_role='captain'),count(*) FILTER(WHERE seat_role='first_officer'),count(*) FILTER(WHERE seat_role='cabin') INTO count_c,count_f,count_a
 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=r.id;
 IF model.minimum_cabin_crew IS NULL OR count_c<>expected OR count_f<>expected OR count_a<>model.minimum_cabin_crew OR pol.minimum_rest_minutes IS NULL OR pol.minimum_rest_minutes<720 OR de-ds>interval '12 hours'
 OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 c WHERE c.request_id=r.id AND (c.airline_id<>r.airline_id OR c.status<>'reserved' OR c.qualification_group<>model.qualification_group OR c.duty_start_utc<>ds OR c.duty_end_utc<>de OR c.origin_airport_key<>r.origin_airport_key OR c.destination_airport_key<>r.destination_airport_key))
 THEN RAISE EXCEPTION 'STORAGE_CREW_DEPARTURE_MANIFEST_INVALID';END IF;
 INSERT INTO airlinerra_game.aircraft_storage_crew_duty_receipts_v1(request_id,employee_id,airline_id,departure_engine_event_id,reported_duty_start_utc,actual_departure_utc,origin_airport_key,destination_airport_key)
 SELECT r.id,c.employee_id,r.airline_id,NEW.engine_event_id,c.duty_start_utc,NEW.actual_event_utc,r.origin_airport_key,r.destination_airport_key
 FROM airlinerra_game.aircraft_storage_crew_reservations_v1 c WHERE c.request_id=r.id ORDER BY c.employee_id;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.capture_storage_crew_departure_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER capture_storage_crew_departure_v1 AFTER INSERT ON airlinerra_game.section9_operated_flight_movements_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.capture_storage_crew_departure_v1();

CREATE FUNCTION airlinerra_game.capture_storage_crew_completed_duty_v1()
RETURNS trigger LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE d record;a record;pol record;expected int;written int;physical text;finish_at timestamptz;
BEGIN
 IF NEW.status<>'completed' OR OLD.status=NEW.status THEN RETURN NEW;END IF;
 SELECT count(*) INTO expected FROM airlinerra_game.aircraft_storage_crew_reservations_v1 WHERE request_id=NEW.id;
 IF expected=0 THEN RETURN NEW;END IF;
 physical:=NEW.id::text||':'||(NEW.departure_utc AT TIME ZONE 'UTC')::date::text||':1';
 SELECT * INTO STRICT d FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=NEW.id AND phase='departed' AND flight_occurrence_id=physical AND airline_id=NEW.airline_id AND aircraft_inventory_id=NEW.aircraft_inventory_id;
 SELECT * INTO STRICT a FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=NEW.id AND phase='arrived' AND flight_occurrence_id=physical AND airline_id=NEW.airline_id AND aircraft_inventory_id=NEW.aircraft_inventory_id;
 IF d.origin_airport_key<>NEW.origin_airport_key OR d.destination_airport_key<>NEW.destination_airport_key OR a.origin_airport_key<>NEW.origin_airport_key OR a.destination_airport_key<>NEW.destination_airport_key OR d.actual_event_utc<>NEW.departure_utc OR a.actual_event_utc<>NEW.arrival_utc THEN RAISE EXCEPTION 'STORAGE_CREW_MOVEMENT_MISMATCH';END IF;
 SELECT * INTO STRICT pol FROM airlinerra_game.section9_crew_scheduler_policy_v2 WHERE world_id=1;
 IF pol.postflight_minutes IS NULL OR pol.postflight_minutes<0 OR pol.minimum_rest_minutes IS NULL OR pol.minimum_rest_minutes<720 THEN RAISE EXCEPTION 'STORAGE_CREW_POLICY_UNVERIFIED';END IF;
 finish_at:=a.actual_event_utc+make_interval(mins=>pol.postflight_minutes);
 UPDATE airlinerra_game.aircraft_storage_crew_duty_receipts_v1 c
 SET arrival_engine_event_id=a.engine_event_id,actual_arrival_utc=a.actual_event_utc,completed_duty_end_utc=finish_at,rest_complete_utc=finish_at+make_interval(mins=>pol.minimum_rest_minutes)
 WHERE c.request_id=NEW.id AND c.airline_id=NEW.airline_id AND c.departure_engine_event_id=d.engine_event_id AND c.actual_departure_utc=d.actual_event_utc AND c.arrival_engine_event_id IS NULL;
 GET DIAGNOSTICS written=ROW_COUNT;
 IF written<>expected THEN RAISE EXCEPTION 'STORAGE_CREW_DUTY_RECEIPT_MISMATCH';END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.capture_storage_crew_completed_duty_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER capture_storage_crew_completed_duty_v1 AFTER UPDATE OF status ON airlinerra_game.aircraft_storage_relocation_requests_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.capture_storage_crew_completed_duty_v1();

CREATE FUNCTION airlinerra_game.storage_crew_completed_duty_history_v1(p_airline uuid,p_employee uuid,p_at timestamptz)
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path=pg_catalog AS $fn$
DECLARE h jsonb;last_airport text;ready timestamptz;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_at IS NULL OR NOT isfinite(p_at) THEN RETURN jsonb_build_object('status','storage_crew_history_clock_invalid','availableForNewDuty',false);END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object('startUtc',reported_duty_start_utc,'endUtc',completed_duty_end_utc,'origin',origin_airport_key,'destination',destination_airport_key) ORDER BY reported_duty_start_utc,request_id),'[]'::jsonb)
 INTO h FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE airline_id=p_airline AND employee_id=p_employee AND completed_duty_end_utc<=p_at;
 SELECT destination_airport_key,rest_complete_utc INTO last_airport,ready FROM airlinerra_game.aircraft_storage_crew_duty_receipts_v1 WHERE airline_id=p_airline AND employee_id=p_employee AND actual_arrival_utc<=p_at ORDER BY actual_arrival_utc DESC LIMIT 1;
 RETURN jsonb_build_object('status','storage_crew_history_handoff_pending','history',h,'lastAirport',last_airport,'nextReadyUtc',ready,'restComplete',coalesce(ready<=p_at,false),'availableForNewDuty',false,'historyIntegrated',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_crew_completed_duty_history_v1(uuid,uuid,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
