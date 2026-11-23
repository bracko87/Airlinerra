-- Fifth Freedom Licence 6: private route-scoped application and atomic issuance.
-- Market fee is selected ONLY by a separately reviewed country-pair policy.
-- Live release remains impossible under the existing hard release constraint.
CREATE TABLE airlinerra_game.licence6_fifth_applications_v1(
 application_id uuid PRIMARY KEY DEFAULT extensions.gen_random_uuid(),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 owner_player_id uuid NOT NULL,
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 request_key uuid NOT NULL,
 home_airport_key text NOT NULL,
 foreign_stop_airport_key text NOT NULL,
 foreign_destination_airport_key text NOT NULL,
 service_type text NOT NULL CHECK(service_type IN('passenger','cargo')),
 fee_usd numeric NOT NULL CHECK(fee_usd BETWEEN 100000 AND 250000),
 status text NOT NULL DEFAULT 'submitted' CHECK(status IN('submitted','issued','withdrawn')),
 applied_game_day date NOT NULL,
 due_game_day date NOT NULL,
 issued_game_day date,
 expires_game_day date,
 fee_ledger_id bigint UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 issued_reference text UNIQUE,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(airline_id,request_key),
 CHECK(due_game_day=applied_game_day+7),
 CHECK((status='issued')=(issued_game_day IS NOT NULL AND
  expires_game_day IS NOT NULL AND fee_ledger_id IS NOT NULL AND
  issued_reference IS NOT NULL)),
 CHECK(expires_game_day IS NULL OR expires_game_day=issued_game_day+365),
 CHECK(home_airport_key<>foreign_stop_airport_key AND
  foreign_stop_airport_key<>foreign_destination_airport_key AND
  home_airport_key<>foreign_destination_airport_key)
);
CREATE UNIQUE INDEX licence6_fifth_one_pending_itinerary_v1
 ON airlinerra_game.licence6_fifth_applications_v1(
 airline_id,home_airport_key,foreign_stop_airport_key,
 foreign_destination_airport_key,service_type)
 WHERE status='submitted';
CREATE TABLE airlinerra_game.licence6_fifth_approvals_v1(
 approval_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 application_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.licence6_fifth_applications_v1(application_id),
 home_airport_key text NOT NULL,
 foreign_stop_airport_key text NOT NULL,
 foreign_destination_airport_key text NOT NULL,
 service_type text NOT NULL CHECK(service_type IN('passenger','cargo')),
 fee_ledger_id bigint NOT NULL UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 approved_game_day date NOT NULL,
 expires_game_day date NOT NULL,
 approval_reference text NOT NULL UNIQUE,
 created_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK(expires_game_day=approved_game_day+365)
);
CREATE UNIQUE INDEX licence6_fifth_one_active_grant_per_route_v1
 ON airlinerra_game.licence6_fifth_approvals_v1(
 airline_id,home_airport_key,foreign_stop_airport_key,
 foreign_destination_airport_key,service_type);
ALTER TABLE airlinerra_game.licence6_fifth_applications_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.licence6_fifth_approvals_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.licence6_fifth_applications_v1,
 airlinerra_game.licence6_fifth_approvals_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.licence6_submit_fifth_application_v1(
 p_owner uuid,p_airline uuid,p_home text,p_stop text,p_destination text,
 p_service text,p_request_key uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE a record; old_app record; eligibility jsonb;day_now date;
 quoted_fee numeric;new_app record;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE6_TRUSTED_SUBMISSION_ONLY';END IF;
 IF p_owner IS NULL OR p_airline IS NULL OR p_request_key IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='LICENCE6_INVALID_REQUEST';END IF;
 IF NOT EXISTS(
  SELECT 1 FROM airlinerra_game.licence6_fifth_release_v1
  WHERE world_id=1 AND issuance_enabled AND fee_review_verified
   AND market_authority_verified AND route_enforcement_verified)
 THEN RETURN jsonb_build_object('status','NOT_RELEASED','submitted',false,
  'charged',false,'issued',false,'flightActivated',false);END IF;
 SELECT * INTO a FROM airlinerra_game.airlines
 WHERE id=p_airline AND world_id=1 AND owner_player_id=p_owner FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE6_NOT_OWNED';END IF;
 SELECT * INTO old_app FROM airlinerra_game.licence6_fifth_applications_v1
 WHERE airline_id=p_airline AND request_key=p_request_key;
 IF FOUND THEN
  IF old_app.home_airport_key IS DISTINCT FROM p_home OR
    old_app.foreign_stop_airport_key IS DISTINCT FROM p_stop OR
    old_app.foreign_destination_airport_key IS DISTINCT FROM p_destination OR
    old_app.service_type IS DISTINCT FROM p_service
  THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='LICENCE6_REQUEST_KEY_REUSE_MISMATCH';END IF;
  RETURN jsonb_build_object('status',old_app.status,'submitted',true,
   'applicationId',old_app.application_id,'charged',false,'issued',false,
   'replay',true,'flightActivated',false);
 END IF;
 eligibility:=airlinerra_game.licence6_fifth_readiness_v1(
  p_airline,p_home,p_stop,p_destination,p_service);
 IF eligibility->>'eligible' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','NOT_ELIGIBLE','submitted',false,
  'charged',false,'issued',false,'issues',eligibility->'issues',
  'flightActivated',false);END IF;
 quoted_fee:=(eligibility->>'feeUsd')::numeric;
 IF quoted_fee IS NULL OR quoted_fee NOT BETWEEN 100000 AND 250000
 THEN RETURN jsonb_build_object('status','NO_APPROVED_MARKET_FEE',
  'submitted',false,'charged',false,'issued',false,'flightActivated',false);END IF;
 day_now:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF day_now IS NULL OR NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1
  WHERE world_id=1 AND game_date=day_now)
 THEN RETURN jsonb_build_object('status','GAME_CLOCK_UNVERIFIED',
  'submitted',false,'charged',false,'issued',false,'flightActivated',false);END IF;
 IF EXISTS(
  SELECT 1 FROM airlinerra_game.licence6_fifth_approvals_v1
  WHERE airline_id=p_airline AND home_airport_key=p_home
    AND foreign_stop_airport_key=p_stop
    AND foreign_destination_airport_key=p_destination
    AND service_type=p_service AND expires_game_day>day_now)
 THEN RETURN jsonb_build_object('status','ALREADY_APPROVED',
  'submitted',false,'charged',false,'issued',false,'flightActivated',false);END IF;
 IF EXISTS(
  SELECT 1 FROM airlinerra_game.licence6_fifth_applications_v1
  WHERE airline_id=p_airline AND home_airport_key=p_home
    AND foreign_stop_airport_key=p_stop
    AND foreign_destination_airport_key=p_destination
    AND service_type=p_service AND status='submitted')
 THEN RETURN jsonb_build_object('status','ALREADY_SUBMITTED',
  'submitted',false,'charged',false,'issued',false,'flightActivated',false);END IF;
 INSERT INTO airlinerra_game.licence6_fifth_applications_v1(
  airline_id,owner_player_id,request_key,home_airport_key,
  foreign_stop_airport_key,foreign_destination_airport_key,
  service_type,fee_usd,applied_game_day,due_game_day)
 VALUES(p_airline,p_owner,p_request_key,p_home,p_stop,p_destination,
  p_service,quoted_fee,day_now,day_now+7)
 RETURNING * INTO new_app;
 RETURN jsonb_build_object('status','SUBMITTED',
  'applicationId',new_app.application_id,'dueGameDay',new_app.due_game_day,
  'feeOnApprovalUsd',quoted_fee,'submitted',true,'charged',false,
  'issued',false,'flightActivated',false);
END $fn$;

CREATE OR REPLACE FUNCTION airlinerra_game.licence6_review_due_fifth_applications_v1(
 p_limit integer DEFAULT 25)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE
 d date;app record;airline record;eligibility jsonb;
 entry_id bigint; reviewed integer:=0;issued integer:=0;blocked integer:=0;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE6_TRUSTED_REVIEW_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 25
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='LICENCE6_INVALID_REVIEW_LIMIT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.licence6_fifth_release_v1
  WHERE world_id=1 AND issuance_enabled AND fee_review_verified
    AND market_authority_verified AND route_enforcement_verified)
 THEN RETURN jsonb_build_object('status','NOT_RELEASED','reviewed',0,
  'issued',0,'charged',false,'flightActivated',false);END IF;
 d:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF d IS NULL OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1
  WHERE world_id=1 AND game_date=d)
 THEN RETURN jsonb_build_object('status','GAME_CLOCK_UNVERIFIED','reviewed',0,'issued',0);END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583729,10026)
 THEN RETURN jsonb_build_object('status','REVIEW_BUSY','reviewed',0,'issued',0);END IF;
 FOR app IN
 SELECT * FROM airlinerra_game.licence6_fifth_applications_v1
 WHERE status='submitted' AND due_game_day<=d
 ORDER BY due_game_day,application_id LIMIT p_limit
 LOOP
  SELECT * INTO airline FROM airlinerra_game.airlines
  WHERE id=app.airline_id AND world_id=1 FOR UPDATE;
  IF NOT FOUND OR airline.owner_player_id IS DISTINCT FROM app.owner_player_id
  THEN blocked:=blocked+1;CONTINUE;END IF;
  PERFORM 1 FROM airlinerra_game.licence6_fifth_applications_v1
  WHERE application_id=app.application_id AND status='submitted' FOR UPDATE;
  IF NOT FOUND THEN CONTINUE;END IF;
  reviewed:=reviewed+1;
  eligibility:=airlinerra_game.licence6_fifth_readiness_v1(
   app.airline_id,app.home_airport_key,app.foreign_stop_airport_key,
   app.foreign_destination_airport_key,app.service_type);
  IF eligibility->>'eligible' IS DISTINCT FROM 'true'
   OR (eligibility->>'feeUsd')::numeric IS DISTINCT FROM app.fee_usd
   OR airline.cash_usd<app.fee_usd
   OR (SELECT coalesce(sum(amount_usd),0) FROM airlinerra_game.airline_ledger
       WHERE airline_id=app.airline_id) IS DISTINCT FROM airline.cash_usd
   OR EXISTS(SELECT 1 FROM airlinerra_game.licence6_fifth_approvals_v1
    WHERE airline_id=app.airline_id
     AND home_airport_key=app.home_airport_key
     AND foreign_stop_airport_key=app.foreign_stop_airport_key
     AND foreign_destination_airport_key=app.foreign_destination_airport_key
     AND service_type=app.service_type AND expires_game_day>d)
  THEN blocked:=blocked+1;CONTINUE;END IF;
  UPDATE airlinerra_game.airlines SET cash_usd=cash_usd-app.fee_usd
  WHERE id=app.airline_id AND cash_usd>=app.fee_usd;
  IF NOT FOUND THEN RAISE EXCEPTION 'LICENCE6_CONCURRENT_BALANCE_FAILURE';END IF;
  INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
  VALUES(app.airline_id,'EXPENSE',-app.fee_usd)
  RETURNING id INTO entry_id;
  INSERT INTO airlinerra_game.licence6_fifth_approvals_v1(
   airline_id,application_id,home_airport_key,foreign_stop_airport_key,
   foreign_destination_airport_key,service_type,fee_ledger_id,
   approved_game_day,expires_game_day,approval_reference)
  VALUES(app.airline_id,app.application_id,app.home_airport_key,
   app.foreign_stop_airport_key,app.foreign_destination_airport_key,
   app.service_type,entry_id,d,d+365,
   'fifth-freedom-game-v1-'||app.application_id::text)
  ON CONFLICT(airline_id,home_airport_key,foreign_stop_airport_key,
    foreign_destination_airport_key,service_type)
  DO UPDATE SET application_id=excluded.application_id,
   fee_ledger_id=excluded.fee_ledger_id,approved_game_day=excluded.approved_game_day,
   expires_game_day=excluded.expires_game_day,approval_reference=excluded.approval_reference,
   created_at=clock_timestamp();
  UPDATE airlinerra_game.licence6_fifth_applications_v1 SET
   status='issued',issued_game_day=d,expires_game_day=d+365,
   fee_ledger_id=entry_id,issued_reference=
    'fifth-freedom-game-v1-'||app.application_id::text
  WHERE application_id=app.application_id AND status='submitted';
  IF NOT FOUND THEN RAISE EXCEPTION 'LICENCE6_APPLICATION_CONCURRENT_CHANGE';END IF;
  issued:=issued+1;
 END LOOP;
 RETURN jsonb_build_object('status','REVIEWED','reviewed',reviewed,
  'issued',issued,'blocked',blocked,'chargeOnlyWithIssuance',true,
  'flightActivated',false,'foreignSegmentAuthorized',false);
END $fn$;

-- Independently available operator grant; the actual multi-segment traffic-rights
-- classifier and dispatch release remain closed pending full integration.
CREATE OR REPLACE FUNCTION airlinerra_game.licence6_fifth_grant_scope_v1(
 p_airline uuid,p_home text,p_stop text,p_destination text,p_service text)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE d date; valid boolean:=false;
BEGIN
 d:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF d IS NOT NULL THEN
  SELECT EXISTS(
   SELECT 1 FROM airlinerra_game.licence6_fifth_approvals_v1 grant_row
   JOIN airlinerra_game.licence6_fifth_applications_v1 app
    ON app.application_id=grant_row.application_id
      AND app.airline_id=grant_row.airline_id
      AND app.status='issued'
      AND app.issued_game_day=grant_row.approved_game_day
      AND app.fee_ledger_id=grant_row.fee_ledger_id
   JOIN airlinerra_game.airline_ledger ledger
    ON ledger.id=grant_row.fee_ledger_id
     AND ledger.airline_id=grant_row.airline_id
     AND ledger.entry_kind='EXPENSE' AND ledger.amount_usd=-app.fee_usd
   JOIN airlinerra_game.airlines airline
    ON airline.id=grant_row.airline_id AND airline.world_id=1
     AND airline.owner_player_id=app.owner_player_id
   JOIN airlinerra_game.airport_reference_profiles home
    ON home.world_id=1 AND home.airport_key=grant_row.home_airport_key
   JOIN airlinerra_game.airport_reference_profiles stop
    ON stop.world_id=1 AND stop.airport_key=grant_row.foreign_stop_airport_key
   JOIN airlinerra_game.airport_reference_profiles dest
    ON dest.world_id=1 AND dest.airport_key=grant_row.foreign_destination_airport_key
   JOIN airlinerra_game.licence6_fifth_market_policies_v1 policy
    ON policy.world_id=1 AND policy.operator_country_iso2=home.country_iso
      AND policy.first_foreign_country_iso2=stop.country_iso
      AND policy.second_foreign_country_iso2=dest.country_iso
      AND policy.service_type=grant_row.service_type
   WHERE grant_row.world_id=1 AND grant_row.airline_id=p_airline
    AND grant_row.home_airport_key=p_home AND grant_row.foreign_stop_airport_key=p_stop
    AND grant_row.foreign_destination_airport_key=p_destination AND grant_row.service_type=p_service
    AND grant_row.approved_game_day<=d AND grant_row.expires_game_day>d
    AND policy.country_rights_verified AND policy.fee_usd=app.fee_usd
    AND policy.approved_from_game_day<=d AND policy.expires_game_day>d
    AND EXISTS(SELECT 1 FROM airlinerra_game.licence6_fifth_release_v1 r
      WHERE r.world_id=1 AND r.issuance_enabled AND r.fee_review_verified
       AND r.market_authority_verified AND r.route_enforcement_verified)
    AND EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_certificates_v1 cert
      WHERE cert.world_id=1 AND cert.airline_id=p_airline
       AND cert.status='active' AND cert.issued_game_day<=d AND cert.expires_game_day>d)
    AND EXISTS(SELECT 1 FROM airlinerra_game.licence2_airline_market_permits_v1 l2
      WHERE l2.world_id=1 AND l2.airline_id=p_airline AND l2.status='approved')
  ) INTO valid;
 END IF;
 RETURN jsonb_build_object('status',CASE WHEN valid
   THEN 'FIFTH_FREEDOM_GAME_GRANT_RECORDED_ROUTE_CHECKS_REQUIRED'
   ELSE 'FIFTH_FREEDOM_GAME_GRANT_NOT_ACTIVE' END,
 'operatorGameGrantRecorded',valid,'foreignSegmentAuthorized',false,
 'routeAuthorized',false,'flightActivated',false,
 'realWorldAviationRightsGranted',false);
END $fn$;
REVOKE ALL ON FUNCTION airlinerra_game.licence6_submit_fifth_application_v1(
 uuid,uuid,text,text,text,text,uuid),
 airlinerra_game.licence6_review_due_fifth_applications_v1(integer),
 airlinerra_game.licence6_fifth_grant_scope_v1(uuid,text,text,text,text)
 FROM PUBLIC,anon,authenticated,service_role;
DO $cron$
BEGIN
 IF NOT EXISTS(SELECT 1 FROM cron.job WHERE jobname='airlinerra-licence6-fifth-review-v1')
 THEN PERFORM cron.schedule('airlinerra-licence6-fifth-review-v1',
 '*/5 * * * *','SELECT airlinerra_game.licence6_review_due_fifth_applications_v1(25)');
 END IF;
END $cron$;
