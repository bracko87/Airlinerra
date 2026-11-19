-- Cargo Licence 3: private, company-scoped application/issuance, hard-gated.
-- No existing world, account, permit, or balance is modified by installation.
CREATE TABLE airlinerra_game.licence3_cargo_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 issuance_enabled boolean NOT NULL DEFAULT false,
 fee_ledger_verified boolean NOT NULL DEFAULT false,
 reviewer_verified boolean NOT NULL DEFAULT false,
 release_reference text,
 CONSTRAINT licence3_cargo_not_released_until_cutover_v1
 CHECK (issuance_enabled=false AND fee_ledger_verified=false AND reviewer_verified=false)
);
INSERT INTO airlinerra_game.licence3_cargo_release_v1(world_id) VALUES(1);
CREATE TABLE airlinerra_game.licence3_cargo_applications_v1(
 application_id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 owner_player_id uuid NOT NULL,
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 request_key uuid NOT NULL,
 status text NOT NULL DEFAULT 'submitted'
  CHECK(status IN ('submitted','issued','withdrawn')),
 submitted_game_day date NOT NULL,
 due_game_day date NOT NULL,
 fee_usd numeric NOT NULL DEFAULT 50000 CHECK(fee_usd=50000),
 issued_game_day date,
 fee_ledger_id bigint UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 issued_reference text UNIQUE,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(airline_id,request_key),
 CHECK(due_game_day=submitted_game_day+3),
 CHECK((status='issued')=(issued_game_day IS NOT NULL AND fee_ledger_id IS NOT NULL AND issued_reference IS NOT NULL))
);
CREATE UNIQUE INDEX licence3_cargo_one_open_application_v1 ON airlinerra_game.licence3_cargo_applications_v1(airline_id)
WHERE status='submitted';
CREATE TABLE airlinerra_game.licence3_cargo_approvals_v1(
 airline_id uuid PRIMARY KEY REFERENCES airlinerra_game.airlines(id),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 application_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.licence3_cargo_applications_v1(application_id),
 fee_ledger_id bigint NOT NULL UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 approved_game_day date NOT NULL,
 approval_reference text NOT NULL UNIQUE,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE airlinerra_game.licence3_cargo_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.licence3_cargo_applications_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.licence3_cargo_approvals_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.licence3_cargo_release_v1,
 airlinerra_game.licence3_cargo_applications_v1,
 airlinerra_game.licence3_cargo_approvals_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.licence3_submit_cargo_application_v1(
 p_owner uuid,p_airline uuid,p_request_key uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE a record; d date; readiness jsonb; app record;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE3_TRUSTED_APPLICATION_ONLY';
 END IF;
 IF p_owner IS NULL OR p_airline IS NULL OR p_request_key IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='LICENCE3_APPLICATION_INVALID';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.licence3_cargo_release_v1
  WHERE world_id=1 AND issuance_enabled AND fee_ledger_verified AND reviewer_verified)
 THEN RETURN jsonb_build_object('status','NOT_RELEASED','submitted',false,'charged',false,'issued',false);END IF;
 SELECT * INTO a FROM airlinerra_game.airlines
  WHERE id=p_airline AND world_id=1 AND owner_player_id=p_owner FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE3_AIRLINE_NOT_OWNED';END IF;
 SELECT * INTO app FROM airlinerra_game.licence3_cargo_applications_v1
  WHERE airline_id=p_airline AND request_key=p_request_key;
 IF FOUND THEN RETURN jsonb_build_object('status',app.status,'applicationId',app.application_id,
  'submitted',true,'charged',false,'issued',false,'replay',true);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.licence3_cargo_approvals_v1 WHERE airline_id=p_airline)
 THEN RETURN jsonb_build_object('status','ALREADY_APPROVED','submitted',false,'charged',false,'issued',false);END IF;
 readiness:=airlinerra_game.licence3_cargo_readiness_v1(p_airline);
 IF readiness->>'eligible' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','NOT_ELIGIBLE','readiness',readiness,
  'submitted',false,'charged',false,'issued',false);END IF;
 d:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF d IS NULL OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1
  WHERE world_id=1 AND game_date=d)
 THEN RETURN jsonb_build_object('status','GAME_TICK_UNVERIFIED','submitted',false,'charged',false,'issued',false);END IF;
 INSERT INTO airlinerra_game.licence3_cargo_applications_v1(
  airline_id,owner_player_id,request_key,submitted_game_day,due_game_day)
 VALUES(p_airline,p_owner,p_request_key,d,d+3)
 RETURNING * INTO app;
 RETURN jsonb_build_object('status','SUBMITTED','applicationId',app.application_id,
  'dueGameDay',app.due_game_day,'feeOnApprovalUsd',50000,
  'submitted',true,'charged',false,'issued',false);
END $fn$;

CREATE OR REPLACE FUNCTION airlinerra_game.licence3_review_due_cargo_game_applications_v1(p_limit integer DEFAULT 25)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE d date; app record; a record; readiness jsonb; ledger_id bigint;
 reviewed integer:=0;issued integer:=0;blocked integer:=0;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE3_TRUSTED_REVIEW_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 25 THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='LICENCE3_INVALID_BATCH_LIMIT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.licence3_cargo_release_v1
 WHERE world_id=1 AND issuance_enabled AND fee_ledger_verified AND reviewer_verified)
 THEN RETURN jsonb_build_object('status','NOT_RELEASED','reviewed',0,'issued',0,'charged',false,'flightActivated',false);END IF;
 d:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF d IS NULL OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1
 WHERE world_id=1 AND game_date=d) THEN RETURN jsonb_build_object('status','GAME_TICK_UNVERIFIED',
 'reviewed',0,'issued',0,'charged',false,'flightActivated',false);END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583729,10023) THEN
 RETURN jsonb_build_object('status','REVIEW_BUSY','reviewed',0,'issued',0,'charged',false,'flightActivated',false);END IF;
 FOR app IN SELECT application_id,airline_id,owner_player_id,due_game_day
   FROM airlinerra_game.licence3_cargo_applications_v1
   WHERE status='submitted' AND due_game_day<=d ORDER BY due_game_day,application_id LIMIT p_limit
 LOOP
  SELECT * INTO a FROM airlinerra_game.airlines WHERE id=app.airline_id AND world_id=1 FOR UPDATE;
  IF NOT FOUND OR a.owner_player_id IS DISTINCT FROM app.owner_player_id
  THEN blocked:=blocked+1;CONTINUE;END IF;
  PERFORM 1 FROM airlinerra_game.licence3_cargo_applications_v1
    WHERE application_id=app.application_id AND status='submitted' FOR UPDATE;
  IF NOT FOUND THEN CONTINUE;END IF;
  reviewed:=reviewed+1;
  readiness:=airlinerra_game.licence3_cargo_readiness_v1(app.airline_id);
  IF readiness->>'eligible' IS DISTINCT FROM 'true'
   OR EXISTS(SELECT 1 FROM airlinerra_game.licence3_cargo_approvals_v1 WHERE airline_id=app.airline_id)
   OR a.cash_usd<50000
   OR (SELECT coalesce(sum(amount_usd),0) FROM airlinerra_game.airline_ledger
       WHERE airline_id=app.airline_id) IS DISTINCT FROM a.cash_usd
  THEN blocked:=blocked+1;CONTINUE;END IF;
  UPDATE airlinerra_game.airlines SET cash_usd=cash_usd-50000
   WHERE id=app.airline_id AND cash_usd>=50000;
  IF NOT FOUND THEN RAISE EXCEPTION 'LICENCE3_CONCURRENT_BALANCE_FAILURE';END IF;
  INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
   VALUES(app.airline_id,'EXPENSE',-50000) RETURNING id INTO ledger_id;
  INSERT INTO airlinerra_game.licence3_cargo_approvals_v1(
   airline_id,application_id,fee_ledger_id,approved_game_day,approval_reference)
  VALUES(app.airline_id,app.application_id,ledger_id,d,'cargo-game-licence3-v1-'||app.application_id::text);
  UPDATE airlinerra_game.licence3_cargo_applications_v1
   SET status='issued',issued_game_day=d,fee_ledger_id=ledger_id,
    issued_reference='cargo-game-licence3-v1-'||app.application_id::text
   WHERE application_id=app.application_id AND status='submitted';
  IF NOT FOUND THEN RAISE EXCEPTION 'LICENCE3_APPLICATION_CONCURRENT_CHANGE';END IF;
  issued:=issued+1;
 END LOOP;
 RETURN jsonb_build_object('status','REVIEWED','reviewed',reviewed,'issued',issued,'blocked',blocked,
 'chargeOnlyWithIssuance',true,'flightActivated',false);
END $fn$;

CREATE OR REPLACE FUNCTION airlinerra_game.licence3_cargo_flight_scope_v1(p_airline uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE d date; allowed boolean:=false;
BEGIN
 d:=airlinerra_game.section9_verified_permission_game_day_v1();
 SELECT EXISTS(
  SELECT 1 FROM airlinerra_game.licence3_cargo_approvals_v1 l
  JOIN airlinerra_game.section9_aoc_operating_companies_v1 o ON o.airline_id=l.airline_id
  JOIN airlinerra_game.section9_aoc_certificates_v1 c ON c.airline_id=l.airline_id
  WHERE l.airline_id=p_airline AND l.world_id=1 AND o.world_id=1
  AND o.business_kind='cargo' AND o.company_source='subsidiary'
  AND c.status='active' AND d>=c.issued_game_day AND d<c.expires_game_day
  AND EXISTS(SELECT 1 FROM airlinerra_game.licence3_cargo_release_v1 r
   WHERE r.world_id=1 AND r.issuance_enabled AND r.fee_ledger_verified AND r.reviewer_verified)
 ) INTO allowed;
 RETURN jsonb_build_object('authorized',allowed,'cargoServiceScopeWorldwide',allowed,
 'routeAuthorized',false,'flightActivated',false,
 'status',CASE WHEN allowed THEN 'CARGO_SERVICE_APPROVED_ROUTE_CHECKS_REQUIRED'
 ELSE 'CARGO_SERVICE_NOT_APPROVED' END);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.licence3_submit_cargo_application_v1(uuid,uuid,uuid),
 airlinerra_game.licence3_review_due_cargo_game_applications_v1(integer),
 airlinerra_game.licence3_cargo_flight_scope_v1(uuid)
 FROM public,anon,authenticated,service_role;
