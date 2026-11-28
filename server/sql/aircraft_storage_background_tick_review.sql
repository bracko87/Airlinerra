-- ROLLBACK-ONLY REVIEW. Private minute tick; no cron registration here.
-- Independent gates for billing and flight processing. No browser dependency.
BEGIN;
CREATE TABLE airlinerra_game.storage_background_worker_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 movement_enabled boolean NOT NULL DEFAULT false,
 billing_enabled boolean NOT NULL DEFAULT false,
 expiry_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.storage_background_worker_release_v1(world_id) VALUES(1);
CREATE TABLE airlinerra_game.storage_background_attempts_v1(
 request_id uuid NOT NULL REFERENCES airlinerra_game.aircraft_storage_relocation_requests_v1(id),
 phase text NOT NULL CHECK(phase IN('departed','arrived','expiry','billing')),
 last_attempt_utc timestamptz NOT NULL, status text NOT NULL,
 PRIMARY KEY(request_id,phase)
);
ALTER TABLE airlinerra_game.storage_background_worker_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.storage_background_attempts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.storage_background_worker_release_v1,airlinerra_game.storage_background_attempts_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.expire_missed_storage_departure_v1(p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE r record;v_now timestamptz;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.storage_background_worker_release_v1 WHERE world_id=1 AND expiry_enabled) THEN RETURN jsonb_build_object('status','storage_expiry_not_released','cancelled',false);END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_request_unknown','cancelled',false);END IF;
 PERFORM 1 FROM airlinerra_game.airlines WHERE id=r.airline_id AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_airline_unknown','cancelled',false);END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND airline_id=r.airline_id FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','storage_aircraft_unknown','cancelled',false);END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request FOR UPDATE;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL OR NOT isfinite(v_now) OR r.status NOT IN('awaiting_slot_and_dispatch_release','reactivation_awaiting_review') OR r.departure_utc>v_now-interval '10 minutes' OR r.departure_utc>clock_timestamp()
 OR EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=r.id)
 THEN RETURN jsonb_build_object('status','storage_expiry_not_applicable','cancelled',false);END IF;
 -- Existing cancellation triggers refund holds, remove slots, and retain
 -- custody for already-reported crews. No artificial movement or crew release.
 UPDATE airlinerra_game.aircraft_storage_relocation_requests_v1 SET status='cancelled',cancelled_at=clock_timestamp() WHERE id=r.id;
 RETURN jsonb_build_object('status','storage_missed_departure_cancelled','cancelled',true,'movementRecorded',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.expire_missed_storage_departure_v1(uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.run_storage_background_tick_v1(p_limit integer)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE gate record;c record;j jsonb;v_now timestamptz;day_key date;phase_key text;results jsonb:='[]'::jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'INVALID_STORAGE_BACKGROUND_LIMIT';END IF;
 IF NOT pg_try_advisory_xact_lock(190927,1) THEN RETURN jsonb_build_object('status','storage_background_busy','results',results);END IF;
 SELECT * INTO gate FROM airlinerra_game.storage_background_worker_release_v1 WHERE world_id=1;
 IF NOT FOUND OR NOT(gate.movement_enabled OR gate.billing_enabled OR gate.expiry_enabled) THEN RETURN jsonb_build_object('status','storage_background_not_released','results',results);END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL OR NOT isfinite(v_now) THEN RETURN jsonb_build_object('status','game_clock_unverified','results',results);END IF;
 day_key:=(v_now AT TIME ZONE 'Europe/Berlin')::date;
 -- Separate bounded queues. Arrivals first; no failed airline can monopolize
 -- a queue indefinitely: least recently attempted records come first.
 FOREACH phase_key IN ARRAY ARRAY['arrived','billing','departed','expiry'] LOOP
  IF (phase_key IN('arrived','departed') AND NOT gate.movement_enabled) OR (phase_key='billing' AND NOT gate.billing_enabled) OR (phase_key='expiry' AND NOT gate.expiry_enabled) THEN CONTINUE;END IF;
  FOR c IN
   WITH due AS (
    SELECT r.id AS request_id,r.airline_id,0 AS next_month,CASE WHEN phase_key='arrived' THEN r.arrival_utc ELSE r.departure_utc END AS due_at
    FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r
    WHERE phase_key IN('arrived','departed','expiry') AND r.status IN('awaiting_slot_and_dispatch_release','reactivation_awaiting_review')
    AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.storage_request_id=r.id AND m.phase='arrived')
    AND (
     (phase_key='arrived' AND r.arrival_utc<=v_now AND EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.storage_request_id=r.id AND m.phase='departed'))
     OR (phase_key IN('departed','expiry') AND NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m WHERE m.storage_request_id=r.id AND m.phase='departed') AND
      ((phase_key='departed' AND r.departure_utc<=v_now AND r.departure_utc>v_now-interval '10 minutes') OR (phase_key='expiry' AND r.departure_utc<=v_now-interval '10 minutes'))))
    UNION ALL
    SELECT s.request_id,s.airline_id,n.paid+1,(airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,n.paid)::timestamp AT TIME ZONE 'Europe/Berlin')
    FROM airlinerra_game.aircraft_storage_sessions_v1 s JOIN airlinerra_game.aircraft_storage_billing_terms_v1 t USING(request_id)
    CROSS JOIN LATERAL(SELECT count(*)::int AS paid FROM airlinerra_game.aircraft_storage_monthly_receipts_v1 x WHERE x.request_id=s.request_id) n
    WHERE phase_key='billing' AND airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,n.paid)<=day_key
    AND (s.storage_ended_utc IS NULL OR n.paid=0 OR airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,n.paid)<(s.storage_ended_utc AT TIME ZONE 'Europe/Berlin')::date)
   )
   SELECT d.* FROM due d LEFT JOIN airlinerra_game.storage_background_attempts_v1 x ON x.request_id=d.request_id AND x.phase=phase_key
   WHERE x.last_attempt_utc IS NULL OR x.last_attempt_utc<v_now
   ORDER BY x.last_attempt_utc NULLS FIRST,d.due_at,d.request_id LIMIT p_limit
  LOOP
   BEGIN
    IF phase_key='billing' THEN j:=airlinerra_game.post_aircraft_storage_month_v1(c.airline_id,c.request_id,c.next_month);
    ELSIF phase_key='expiry' THEN j:=airlinerra_game.expire_missed_storage_departure_v1(c.request_id);
    ELSE j:=airlinerra_game.execute_aircraft_storage_leg_v1(c.request_id,phase_key);END IF;
   EXCEPTION WHEN OTHERS THEN j:=jsonb_build_object('status','storage_background_item_rolled_back','sqlstate',SQLSTATE);END;
   INSERT INTO airlinerra_game.storage_background_attempts_v1 VALUES(c.request_id,phase_key,v_now,coalesce(j->>'status','unknown'))
   ON CONFLICT(request_id,phase) DO UPDATE SET last_attempt_utc=excluded.last_attempt_utc,status=excluded.status;
   results:=results||jsonb_build_array(j||jsonb_build_object('requestId',c.request_id,'phase',phase_key));
  END LOOP;
 END LOOP;
 RETURN jsonb_build_object('status','storage_background_checked','checkedAtUtc',v_now,'results',results);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.run_storage_background_tick_v1(integer) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
