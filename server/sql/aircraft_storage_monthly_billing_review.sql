-- ROLLBACK-ONLY REVIEW. Monthly storage fees, unlimited number of months.
-- Billing terms are captured from approved facility prices and an explicit
-- aircraft configuration class; never infer the class from passenger seats.
BEGIN;
CREATE TABLE airlinerra_game.aircraft_storage_billing_classes_v1(
 configuration_id bigint PRIMARY KEY,
 billing_class text NOT NULL CHECK(billing_class IN ('regional','narrowbody','widebody')),
 approval_reference text NOT NULL CHECK(btrim(approval_reference)<>'')
);
CREATE TABLE airlinerra_game.aircraft_storage_billing_terms_v1(
 request_id uuid PRIMARY KEY REFERENCES airlinerra_game.aircraft_storage_sessions_v1(request_id),
 billing_class text NOT NULL CHECK(billing_class IN ('regional','narrowbody','widebody')),
 monthly_usd numeric(14,2) NOT NULL CHECK(monthly_usd>0),
 anchor_game_date date NOT NULL,
 price_reference text NOT NULL CHECK(btrim(price_reference)<>'')
);
CREATE TABLE airlinerra_game.aircraft_storage_monthly_receipts_v1(
 request_id uuid NOT NULL REFERENCES airlinerra_game.aircraft_storage_billing_terms_v1(request_id),
 month_number integer NOT NULL CHECK(month_number>0),
 due_game_date date NOT NULL,
 coverage_end_game_date date NOT NULL CHECK(coverage_end_game_date>due_game_date),
 amount_usd numeric(14,2) NOT NULL CHECK(amount_usd>0),
 ledger_id bigint NOT NULL UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 paid_at timestamptz NOT NULL,
 PRIMARY KEY(request_id,month_number)
);
ALTER TABLE airlinerra_game.aircraft_storage_billing_classes_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.aircraft_storage_billing_terms_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.aircraft_storage_monthly_receipts_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.aircraft_storage_billing_classes_v1,airlinerra_game.aircraft_storage_billing_terms_v1,airlinerra_game.aircraft_storage_monthly_receipts_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.capture_storage_billing_terms_v1() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE category text; price numeric; ref text;
BEGIN
 SELECT c.billing_class,
 CASE c.billing_class WHEN 'regional' THEN f.monthly_regional_usd WHEN 'narrowbody' THEN f.monthly_narrowbody_usd WHEN 'widebody' THEN f.monthly_widebody_usd END,
 f.evidence_reference||' | '||c.approval_reference
 INTO category,price,ref
 FROM airlinerra_game.aircraft_storage_relocation_requests_v1 r
 JOIN airlinerra_game.aircraft_storage_billing_classes_v1 c ON c.configuration_id=(r.quote->>'configurationId')::bigint
 JOIN airlinerra_game.aircraft_storage_facilities_v1 f ON f.world_id=NEW.world_id AND f.airport_key=NEW.airport_key
 WHERE r.id=NEW.request_id AND f.review_state='approved';
 IF NOT FOUND OR price IS NULL OR price<=0 OR ref IS NULL THEN RAISE EXCEPTION 'STORAGE_BILLING_TERMS_MISSING';END IF;
 INSERT INTO airlinerra_game.aircraft_storage_billing_terms_v1 VALUES(NEW.request_id,category,price,(NEW.storage_started_utc AT TIME ZONE 'Europe/Berlin')::date,ref);
 RETURN NEW;
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.capture_storage_billing_terms_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER capture_storage_billing_terms AFTER INSERT ON airlinerra_game.aircraft_storage_sessions_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.capture_storage_billing_terms_v1();
CREATE FUNCTION airlinerra_game.reject_storage_billing_receipt_mutation_v1() RETURNS trigger
LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
BEGIN RAISE EXCEPTION 'STORAGE_BILLING_RECORD_IMMUTABLE';END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.reject_storage_billing_receipt_mutation_v1() FROM PUBLIC,anon,authenticated,service_role;
CREATE TRIGGER storage_terms_immutable BEFORE UPDATE OR DELETE ON airlinerra_game.aircraft_storage_billing_terms_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.reject_storage_billing_receipt_mutation_v1();
CREATE TRIGGER storage_receipts_immutable BEFORE UPDATE OR DELETE ON airlinerra_game.aircraft_storage_monthly_receipts_v1 FOR EACH ROW EXECUTE FUNCTION airlinerra_game.reject_storage_billing_receipt_mutation_v1();

CREATE FUNCTION airlinerra_game.storage_month_anniversary_v1(p_anchor date,p_offset integer) RETURNS date
LANGUAGE sql IMMUTABLE STRICT SET search_path=pg_catalog AS $fn$
 SELECT (p_anchor+make_interval(months=>p_offset))::date
$fn$;
REVOKE ALL ON FUNCTION airlinerra_game.storage_month_anniversary_v1(date,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.post_aircraft_storage_month_v1(p_airline uuid,p_request uuid,p_month integer)
RETURNS jsonb LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE a record; s record; t record; prior record; v_now timestamptz; day_key date; due date; ends date; n integer; max_n integer; ledger_total numeric; lid bigint;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_month IS NULL OR p_month<1 THEN RAISE EXCEPTION 'INVALID_STORAGE_MONTH';END IF;
 v_now:=airlinerra_game.section9_verified_world_instant_v1();
 IF v_now IS NULL THEN RETURN jsonb_build_object('status','game_clock_unverified','ledgerPosted',false);END IF;
 day_key:=(v_now AT TIME ZONE 'Europe/Berlin')::date;
 SELECT * INTO a FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'STORAGE_AIRLINE_UNKNOWN';END IF;
 SELECT * INTO s FROM airlinerra_game.aircraft_storage_sessions_v1 WHERE request_id=p_request AND airline_id=p_airline FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'STORAGE_SESSION_NOT_OWNED';END IF;
 SELECT * INTO t FROM airlinerra_game.aircraft_storage_billing_terms_v1 WHERE request_id=p_request;
 IF NOT FOUND THEN RAISE EXCEPTION 'STORAGE_BILLING_TERMS_MISSING';END IF;
 SELECT * INTO prior FROM airlinerra_game.aircraft_storage_monthly_receipts_v1 WHERE request_id=p_request AND month_number=p_month;
 IF FOUND THEN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_ledger WHERE id=prior.ledger_id AND airline_id=p_airline AND entry_kind='EXPENSE' AND amount_usd=-prior.amount_usd) THEN RAISE EXCEPTION 'STORAGE_RECEIPT_LEDGER_MISMATCH';END IF;
 RETURN jsonb_build_object('status','already_paid','ledgerPosted',false,'month',p_month,'amountUsd',prior.amount_usd);END IF;
 IF s.storage_started_utc>v_now OR (s.storage_ended_utc IS NOT NULL AND s.storage_ended_utc>v_now) THEN RETURN jsonb_build_object('status','storage_session_clock_mismatch','ledgerPosted',false);END IF;
 SELECT count(*)::integer,coalesce(max(month_number),0) INTO n,max_n FROM airlinerra_game.aircraft_storage_monthly_receipts_v1 WHERE request_id=p_request;
 IF n<>max_n OR EXISTS(SELECT 1 FROM airlinerra_game.aircraft_storage_monthly_receipts_v1 x WHERE x.request_id=p_request AND
 (x.amount_usd<>t.monthly_usd OR x.due_game_date<>airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,x.month_number-1)
 OR x.coverage_end_game_date<>airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,x.month_number)
 OR NOT EXISTS(SELECT 1 FROM airlinerra_game.airline_ledger l WHERE l.id=x.ledger_id AND l.airline_id=p_airline AND l.entry_kind='EXPENSE' AND l.amount_usd=-x.amount_usd)))
 THEN RAISE EXCEPTION 'STORAGE_BILLING_HISTORY_INCONSISTENT';END IF;
 IF p_month<>n+1 THEN RETURN jsonb_build_object('status','requires_next_month','nextMonth',n+1,'ledgerPosted',false);END IF;
 due:=airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,p_month-1);
 ends:=airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,p_month);
 -- First month is charged on arrival; subsequent periods start on the
 -- original Berlin calendar anniversary. Ended sessions retain arrears only.
 IF s.storage_ended_utc IS NOT NULL AND p_month>1 AND due>=(s.storage_ended_utc AT TIME ZONE 'Europe/Berlin')::date THEN RETURN jsonb_build_object('status','storage_ended','ledgerPosted',false);END IF;
 IF due>day_key THEN RETURN jsonb_build_object('status','not_due','dueGameDate',due,'ledgerPosted',false);END IF;
 SELECT coalesce(sum(amount_usd),0) INTO ledger_total FROM airlinerra_game.airline_ledger WHERE airline_id=p_airline;
 IF a.cash_usd IS DISTINCT FROM ledger_total THEN RETURN jsonb_build_object('status','cash_ledger_unreconciled','ledgerPosted',false);END IF;
 IF a.cash_usd<t.monthly_usd THEN RETURN jsonb_build_object('status','insufficient_cash','amountDueUsd',t.monthly_usd,'ledgerPosted',false);END IF;
 UPDATE airlinerra_game.airlines SET cash_usd=cash_usd-t.monthly_usd WHERE id=p_airline;
 INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd,recorded_at) VALUES(p_airline,'EXPENSE',-t.monthly_usd,v_now) RETURNING id INTO lid;
 INSERT INTO airlinerra_game.aircraft_storage_monthly_receipts_v1 VALUES(p_request,p_month,due,ends,t.monthly_usd,lid,v_now);
 RETURN jsonb_build_object('status','paid','ledgerPosted',true,'month',p_month,'amountUsd',t.monthly_usd,'dueGameDate',due,'coverageEndGameDate',ends);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.post_aircraft_storage_month_v1(uuid,uuid,integer) FROM PUBLIC,anon,authenticated,service_role;

CREATE FUNCTION airlinerra_game.run_aircraft_storage_billing_v1(p_limit integer) RETURNS jsonb
LANGUAGE plpgsql SET search_path=pg_catalog AS $fn$
DECLARE day_key date; candidate record; results jsonb:='[]'::jsonb; j jsonb;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN RAISE EXCEPTION USING ERRCODE='42501';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 100 THEN RAISE EXCEPTION 'INVALID_STORAGE_BATCH_LIMIT';END IF;
 day_key:=(airlinerra_game.section9_verified_world_instant_v1() AT TIME ZONE 'Europe/Berlin')::date;
 FOR candidate IN SELECT s.request_id,s.airline_id,n.paid+1 AS next_month
 FROM airlinerra_game.aircraft_storage_sessions_v1 s JOIN airlinerra_game.aircraft_storage_billing_terms_v1 t USING(request_id)
 CROSS JOIN LATERAL(SELECT count(*)::integer AS paid FROM airlinerra_game.aircraft_storage_monthly_receipts_v1 x WHERE x.request_id=s.request_id) n
 WHERE airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,n.paid)<=day_key
 AND (s.storage_ended_utc IS NULL OR n.paid=0 OR airlinerra_game.storage_month_anniversary_v1(t.anchor_game_date,n.paid)<(s.storage_ended_utc AT TIME ZONE 'Europe/Berlin')::date)
 ORDER BY s.airline_id,s.request_id LIMIT p_limit
 LOOP
 j:=airlinerra_game.post_aircraft_storage_month_v1(candidate.airline_id,candidate.request_id,candidate.next_month);
 results:=results||jsonb_build_array(j||jsonb_build_object('requestId',candidate.request_id));
 END LOOP;
 RETURN jsonb_build_object('status','storage_billing_batch_checked','gameDate',day_key,'results',results);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.run_aircraft_storage_billing_v1(integer) FROM PUBLIC,anon,authenticated,service_role;
ROLLBACK;
