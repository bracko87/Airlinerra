-- ROLLBACK-ONLY REVIEW. Install after signed movement schema, before arrival completion.
BEGIN;
-- Keep existing allowed ledger kinds and add explicit storage hold/refund.
ALTER TABLE airlinerra_game.airline_ledger DROP CONSTRAINT IF EXISTS valid_entry_kind,
 ADD CONSTRAINT valid_entry_kind CHECK(entry_kind IN ('STARTING_CAPITAL','AIRCRAFT_PURCHASE','AIRCRAFT_LEASE','REVENUE','EXPENSE','ADJUSTMENT','AIRCRAFT_AUCTION_HOLD','AIRCRAFT_AUCTION_REFUND','AIRCRAFT_STORAGE_HOLD','AIRCRAFT_STORAGE_REFUND'));
CREATE TABLE airlinerra_game.aircraft_storage_funds_v1(
 request_id uuid PRIMARY KEY REFERENCES airlinerra_game.aircraft_storage_relocation_requests_v1(id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 amount_usd numeric(14,2) NOT NULL CHECK(amount_usd>0),
 hold_ledger_id bigint NOT NULL UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 held_at timestamptz NOT NULL,
 status text NOT NULL DEFAULT 'held' CHECK(status IN('held','refunded','settled')),
 refund_ledger_id bigint UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 expense_ledger_id bigint UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 CHECK((status='held' AND refund_ledger_id IS NULL AND expense_ledger_id IS NULL)
 OR (status='refunded' AND refund_ledger_id IS NOT NULL AND expense_ledger_id IS NULL)
 OR (status='settled' AND refund_ledger_id IS NOT NULL AND expense_ledger_id IS NOT NULL))
);
ALTER TABLE airlinerra_game.aircraft_storage_funds_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_funds_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.hold_aircraft_storage_funds_v1(p_player uuid,p_airline uuid,p_request uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE a record; r record; h record; now_game timestamptz; total numeric; lid bigint; physical text;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT x.* INTO a FROM airlinerra_game.airlines x JOIN airlinerra_game.world_memberships w ON w.world_id=1 AND w.player_id=p_player AND w.state='active'
 WHERE x.id=p_airline AND x.world_id=1 AND x.owner_player_id=p_player FOR UPDATE OF x;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request AND airline_id=p_airline AND owner_player_id=p_player;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 PERFORM 1 FROM airlinerra_game.airline_aircraft_inventory WHERE id=r.aircraft_inventory_id AND airline_id=p_airline AND fleet_status='in_service' AND ownership_type='owned' FOR UPDATE;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','aircraft_unavailable','fundsHeld',false);END IF;
 SELECT * INTO r FROM airlinerra_game.aircraft_storage_relocation_requests_v1 WHERE id=p_request FOR UPDATE;
 SELECT * INTO h FROM airlinerra_game.aircraft_storage_funds_v1 WHERE request_id=p_request;
 IF FOUND THEN
 IF h.airline_id<>p_airline OR h.amount_usd<>r.quoted_cost_usd OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_ledger WHERE id=h.hold_ledger_id AND airline_id=p_airline AND entry_kind='AIRCRAFT_STORAGE_HOLD' AND amount_usd=-h.amount_usd)
 THEN RAISE EXCEPTION 'STORAGE_HOLD_REPLAY_CONFLICT';END IF;
 RETURN jsonb_build_object('status',h.status,'fundsHeld',h.status='held','replayed',true);END IF;
 now_game:=airlinerra_game.section9_verified_world_instant_v1();
 physical:=r.id::text||':'||(r.departure_utc AT TIME ZONE 'UTC')::date::text||':1';
 IF now_game IS NULL OR r.departure_utc<=now_game OR r.status<>'awaiting_slot_and_dispatch_release' OR r.quoted_cost_usd<=0
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_leg_evidence_v1(physical))
 THEN RETURN jsonb_build_object('status','storage_hold_not_ready','fundsHeld',false);END IF;
 SELECT coalesce(sum(amount_usd),0) INTO total FROM airlinerra_game.airline_ledger WHERE airline_id=p_airline;
 IF total IS DISTINCT FROM a.cash_usd OR a.cash_usd<r.quoted_cost_usd THEN RETURN jsonb_build_object('status','storage_hold_insufficient_or_unreconciled_cash','fundsHeld',false);END IF;
 UPDATE airlinerra_game.airlines SET cash_usd=cash_usd-r.quoted_cost_usd WHERE id=p_airline;
 INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd,recorded_at) VALUES(p_airline,'AIRCRAFT_STORAGE_HOLD',-r.quoted_cost_usd,now_game) RETURNING id INTO lid;
 INSERT INTO airlinerra_game.aircraft_storage_funds_v1(request_id,airline_id,amount_usd,hold_ledger_id,held_at) VALUES(p_request,p_airline,r.quoted_cost_usd,lid,now_game);
 RETURN jsonb_build_object('status','held','fundsHeld',true,'amountUsd',r.quoted_cost_usd,'replayed',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.hold_aircraft_storage_funds_v1(uuid,uuid,uuid) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.guard_storage_departure_funds_v1() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN
 IF NEW.storage_request_id IS NOT NULL AND NEW.phase='departed' AND NOT EXISTS(
 SELECT 1 FROM airlinerra_game.aircraft_storage_funds_v1 h JOIN airlinerra_game.aircraft_storage_relocation_requests_v1 r ON r.id=h.request_id
 JOIN airlinerra_game.airline_ledger l ON l.id=h.hold_ledger_id AND l.airline_id=h.airline_id AND l.entry_kind='AIRCRAFT_STORAGE_HOLD' AND l.amount_usd=-h.amount_usd
 WHERE h.request_id=NEW.storage_request_id AND h.airline_id=NEW.airline_id AND h.status='held' AND h.amount_usd=r.quoted_cost_usd AND h.held_at<=NEW.actual_event_utc)
 THEN RAISE EXCEPTION 'STORAGE_DEPARTURE_FUNDS_NOT_HELD';END IF;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.guard_storage_departure_funds_v1() FROM PUBLIC,anon,authenticated,service_role;
-- Alphabetically after storage_signed_movement_guard.
CREATE TRIGGER storage_zz_departure_funds_guard BEFORE INSERT ON airlinerra_game.section9_operated_flight_movements_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.guard_storage_departure_funds_v1();

-- Caller holds airline -> aircraft -> request locks. Cancel is forbidden
-- after a signed departure, including when arrival has not yet occurred.
CREATE FUNCTION airlinerra_game.refund_cancelled_storage_funds_v1() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE h record; a record; total numeric; lid bigint; now_game timestamptz;
BEGIN
 IF NEW.status<>'cancelled' OR OLD.status=NEW.status THEN RETURN NEW;END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=NEW.id AND phase='departed') THEN RAISE EXCEPTION 'STORAGE_FLIGHT_ALREADY_DEPARTED';END IF;
 SELECT * INTO h FROM airlinerra_game.aircraft_storage_funds_v1 WHERE request_id=NEW.id FOR UPDATE;
 IF NOT FOUND THEN RETURN NEW;END IF;
 IF h.status<>'held' THEN RAISE EXCEPTION 'STORAGE_HOLD_STATE_INVALID';END IF;
 SELECT * INTO a FROM airlinerra_game.airlines WHERE id=h.airline_id FOR UPDATE;
 SELECT coalesce(sum(amount_usd),0) INTO total FROM airlinerra_game.airline_ledger WHERE airline_id=h.airline_id;
 now_game:=airlinerra_game.section9_verified_world_instant_v1();
 IF now_game IS NULL OR h.airline_id<>NEW.airline_id OR h.amount_usd<>NEW.quoted_cost_usd OR total IS DISTINCT FROM a.cash_usd
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_ledger WHERE id=h.hold_ledger_id AND airline_id=h.airline_id AND entry_kind='AIRCRAFT_STORAGE_HOLD' AND amount_usd=-h.amount_usd)
 THEN RAISE EXCEPTION 'STORAGE_REFUND_NOT_RECONCILED';END IF;
 UPDATE airlinerra_game.airlines SET cash_usd=cash_usd+h.amount_usd WHERE id=h.airline_id;
 INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd,recorded_at) VALUES(h.airline_id,'AIRCRAFT_STORAGE_REFUND',h.amount_usd,now_game) RETURNING id INTO lid;
 UPDATE airlinerra_game.aircraft_storage_funds_v1 SET status='refunded',refund_ledger_id=lid WHERE request_id=h.request_id;
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.refund_cancelled_storage_funds_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER refund_cancelled_storage_funds AFTER UPDATE OF status ON airlinerra_game.aircraft_storage_relocation_requests_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.refund_cancelled_storage_funds_v1();

-- Settlement transfers the held amount to the expense category; net cash
-- effect at arrival is zero. Caller must already verify signed arrival/burn.
CREATE FUNCTION airlinerra_game.settle_held_storage_funds_v1(p_request uuid,p_airline uuid,p_total numeric,p_arrived timestamptz)
RETURNS bigint LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE h record; a record; total numeric; rid bigint; eid bigint;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 SELECT * INTO a FROM airlinerra_game.airlines WHERE id=p_airline FOR UPDATE;
 SELECT * INTO h FROM airlinerra_game.aircraft_storage_funds_v1 WHERE request_id=p_request FOR UPDATE;
 IF NOT FOUND OR h.status<>'held' OR h.airline_id<>p_airline OR h.amount_usd IS DISTINCT FROM p_total
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_ledger WHERE id=h.hold_ledger_id AND airline_id=p_airline AND entry_kind='AIRCRAFT_STORAGE_HOLD' AND amount_usd=-h.amount_usd)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 WHERE storage_request_id=p_request AND airline_id=p_airline AND phase='arrived' AND actual_event_utc=p_arrived)
 THEN RAISE EXCEPTION 'STORAGE_EXPENSE_FUNDS_NOT_PROTECTED';END IF;
 SELECT coalesce(sum(amount_usd),0) INTO total FROM airlinerra_game.airline_ledger WHERE airline_id=p_airline;
 IF total IS DISTINCT FROM a.cash_usd THEN RAISE EXCEPTION 'STORAGE_EXPENSE_CASH_UNRECONCILED';END IF;
 INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd,recorded_at) VALUES(p_airline,'AIRCRAFT_STORAGE_REFUND',p_total,p_arrived) RETURNING id INTO rid;
 INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd,recorded_at) VALUES(p_airline,'EXPENSE',-p_total,p_arrived) RETURNING id INTO eid;
 UPDATE airlinerra_game.aircraft_storage_funds_v1 SET status='settled',refund_ledger_id=rid,expense_ledger_id=eid WHERE request_id=p_request;
 RETURN eid;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.settle_held_storage_funds_v1(uuid,uuid,numeric,timestamptz) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
