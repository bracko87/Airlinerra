-- Disposable-only cancellation entitlement journal prototype.
-- This fixture never writes game reservations, player balances or airline ledger.
\set ON_ERROR_STOP on
DO $guard$
BEGIN
 IF current_database()<>'airlinerra_disposable'
 OR current_user<>'postgres'
 OR to_regnamespace('section9_refund_lab') IS NOT NULL
 THEN RAISE EXCEPTION 'REFUND_JOURNAL_DISPOSABLE_ONLY';END IF;
END $guard$;
CREATE SCHEMA section9_refund_lab;
CREATE TABLE section9_refund_lab.bookings(
 reservation_id uuid PRIMARY KEY,
 airline_id uuid NOT NULL,
 physical_flight_id text NOT NULL,
 reservation_key text NOT NULL,
 seats integer NOT NULL CHECK(seats>0),
 paid_upfront boolean NOT NULL,
 recognized_revenue_usd numeric NOT NULL CHECK(recognized_revenue_usd>=0),
 quote_usd numeric NOT NULL CHECK(quote_usd>=0),
 reservation_status text NOT NULL
);
CREATE TABLE section9_refund_lab.entitlements(
 reservation_id uuid PRIMARY KEY REFERENCES section9_refund_lab.bookings(reservation_id),
 airline_id uuid NOT NULL,
 physical_flight_id text NOT NULL,
 decision_key text NOT NULL UNIQUE,
 outcome text NOT NULL CHECK(outcome IN ('no_cash_refund_unpaid','requires_manual_payment_audit')),
 quoted_fare_usd numeric NOT NULL,
 authorized_refund_usd numeric NOT NULL DEFAULT 0 CHECK(authorized_refund_usd=0),
 payment_posted boolean NOT NULL DEFAULT false CHECK(payment_posted=false),
 ledger_posted boolean NOT NULL DEFAULT false CHECK(ledger_posted=false)
);
-- Read booking state under a row lock, then write the only entitlement receipt.
-- The immutable decision never authorizes payment: its purpose is triage.
CREATE FUNCTION section9_refund_lab.stage_recovery(
 p_reservation_id uuid,p_airline_id uuid,p_physical_flight_id text,
 p_decision_key text
) RETURNS text LANGUAGE plpgsql AS $fn$
DECLARE b record;e record;status text;
BEGIN
 IF current_database()<>'airlinerra_disposable' OR current_user<>'postgres'
 THEN RAISE EXCEPTION 'REFUND_JOURNAL_DISPOSABLE_ONLY';END IF;
 IF p_decision_key IS NULL OR length(p_decision_key)<15
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='INVALID_RECOVERY_DECISION_KEY';END IF;
 SELECT * INTO b FROM section9_refund_lab.bookings
 WHERE reservation_id=p_reservation_id FOR UPDATE;
 IF NOT FOUND OR b.airline_id<>p_airline_id
  OR b.physical_flight_id<>p_physical_flight_id
 THEN RETURN 'blocked_reservation_identity';END IF;
 SELECT * INTO e FROM section9_refund_lab.entitlements
 WHERE reservation_id=p_reservation_id FOR UPDATE;
 IF FOUND THEN
   IF e.decision_key<>p_decision_key OR e.airline_id<>p_airline_id
    OR e.physical_flight_id<>p_physical_flight_id
   THEN RETURN 'blocked_conflicting_recovery_decision';END IF;
   RETURN 'recovery_decision_replayed';
 END IF;
 IF b.reservation_status<>'reserved'
 THEN RETURN 'blocked_unexpected_reservation_state';END IF;
 status:=CASE WHEN b.paid_upfront OR b.recognized_revenue_usd>0
   THEN 'requires_manual_payment_audit' ELSE 'no_cash_refund_unpaid' END;
 INSERT INTO section9_refund_lab.entitlements(
  reservation_id,airline_id,physical_flight_id,decision_key,outcome,quoted_fare_usd)
 VALUES(b.reservation_id,b.airline_id,b.physical_flight_id,p_decision_key,
        status,b.quote_usd);
 RETURN status;
END $fn$;
INSERT INTO section9_refund_lab.bookings VALUES
('aaaaaaaa-1000-4000-8000-000000000001',
 '11111111-1111-4111-8111-111111111111','flight:A',
 'demand.s9g1:fixture1',2,false,0,320,'reserved'),
('aaaaaaaa-1000-4000-8000-000000000002',
 '11111111-1111-4111-8111-111111111111','flight:B',
 'demand.s9g1:fixture2',1,true,0,250,'reserved'),
('aaaaaaaa-1000-4000-8000-000000000003',
 '11111111-1111-4111-8111-111111111111','flight:C',
 'demand.s9g1:fixture3',3,false,270,540,'reserved');
DO $acceptance$
DECLARE a text;b text;c text;
BEGIN
 a:=section9_refund_lab.stage_recovery('aaaaaaaa-1000-4000-8000-000000000001',
 '11111111-1111-4111-8111-111111111111','flight:A','cancel:20261123:fixture1');
 b:=section9_refund_lab.stage_recovery('aaaaaaaa-1000-4000-8000-000000000002',
 '11111111-1111-4111-8111-111111111111','flight:B','cancel:20261123:fixture2');
 c:=section9_refund_lab.stage_recovery('aaaaaaaa-1000-4000-8000-000000000003',
 '11111111-1111-4111-8111-111111111111','flight:C','cancel:20261123:fixture3');
 IF a<>'no_cash_refund_unpaid' OR b<>'requires_manual_payment_audit'
 OR c<>'requires_manual_payment_audit'
 THEN RAISE EXCEPTION 'Incorrect recovery classification: %,%,%',a,b,c;END IF;
 a:=section9_refund_lab.stage_recovery('aaaaaaaa-1000-4000-8000-000000000001',
 '11111111-1111-4111-8111-111111111111','flight:A','cancel:20261123:fixture1');
 IF a<>'recovery_decision_replayed' THEN RAISE EXCEPTION 'Idempotency replay failed';END IF;
 a:=section9_refund_lab.stage_recovery('aaaaaaaa-1000-4000-8000-000000000001',
 '11111111-1111-4111-8111-111111111111','flight:A','cancel:20261123:changed');
 IF a<>'blocked_conflicting_recovery_decision' THEN RAISE EXCEPTION 'Changed decision was allowed';END IF;
 a:=section9_refund_lab.stage_recovery('aaaaaaaa-1000-4000-8000-000000000001',
 '22222222-2222-4222-8222-222222222222','flight:A','cancel:20261123:fixture1');
 IF a<>'blocked_reservation_identity' THEN RAISE EXCEPTION 'Foreign airline was allowed';END IF;
 IF (SELECT count(*) FROM section9_refund_lab.entitlements)<>3
 OR (SELECT count(*) FROM section9_refund_lab.entitlements
     WHERE authorized_refund_usd<>0 OR payment_posted OR ledger_posted)<>0
 THEN RAISE EXCEPTION 'Recovery journal incorrectly authorized or posted money';END IF;
 RAISE NOTICE 'PASS disposable recovery classification, stable receipt, conflict, owner check, zero payment';
END $acceptance$;
