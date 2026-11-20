-- Apply company-specific safety limits and 90-day revocation / reapplication rules.
-- Reissue is NOT free: a revoked company must qualify again and pay its full fee.
-- Licence 3: safety threshold 50, reapplication after true revocation, and audited fee recovery.
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
 IF EXISTS(SELECT 1 FROM airlinerra_game.licence3_cargo_approvals_v1 approval
  LEFT JOIN airlinerra_game.licence34_company_compliance_v1 health
    ON health.airline_id=approval.airline_id AND health.licence_code='CARGO_OPERATIONS_SCOPE'
  WHERE approval.airline_id=p_airline AND health.revoked_game_day IS NULL)
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
   OR EXISTS(SELECT 1 FROM airlinerra_game.licence3_cargo_approvals_v1 approval
     LEFT JOIN airlinerra_game.licence34_company_compliance_v1 health
       ON health.airline_id=approval.airline_id AND health.licence_code='CARGO_OPERATIONS_SCOPE'
     WHERE approval.airline_id=app.airline_id AND health.revoked_game_day IS NULL)
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
  VALUES(app.airline_id,app.application_id,ledger_id,d,'cargo-game-licence3-v1-'||app.application_id::text)
  ON CONFLICT(airline_id) DO UPDATE SET
   application_id=excluded.application_id,fee_ledger_id=excluded.fee_ledger_id,
   approved_game_day=excluded.approved_game_day,approval_reference=excluded.approval_reference,
   created_at=clock_timestamp();
  INSERT INTO airlinerra_game.licence34_company_compliance_v1
   (airline_id,licence_code,last_checked_game_day)
  VALUES(app.airline_id,'CARGO_OPERATIONS_SCOPE',d)
  ON CONFLICT(airline_id,licence_code) DO UPDATE SET
   no_aircraft_since_game_day=NULL,last_checked_game_day=excluded.last_checked_game_day,
   revoked_game_day=NULL,revocation_reason=NULL,updated_at=clock_timestamp();
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
DECLARE
 d date;
 allowed boolean:=false;
BEGIN
 d:=airlinerra_game.section9_verified_permission_game_day_v1();
 SELECT EXISTS(
  SELECT 1
  FROM airlinerra_game.licence3_cargo_approvals_v1 l
  JOIN airlinerra_game.licence3_cargo_applications_v1 app
   ON app.application_id=l.application_id AND app.airline_id=l.airline_id
   AND app.world_id=l.world_id AND app.status='issued'
   AND app.fee_usd=50000 AND app.fee_ledger_id=l.fee_ledger_id
   AND app.issued_game_day=l.approved_game_day
  JOIN airlinerra_game.airline_ledger fee
   ON fee.id=l.fee_ledger_id AND fee.airline_id=l.airline_id
   AND fee.entry_kind='EXPENSE' AND fee.amount_usd=-50000
  JOIN airlinerra_game.airlines a
   ON a.id=l.airline_id AND a.world_id=l.world_id
   AND a.owner_player_id=app.owner_player_id
  JOIN airlinerra_game.section9_aoc_operating_companies_v1 o
   ON o.airline_id=l.airline_id AND o.world_id=l.world_id
   AND o.business_kind='cargo' AND o.company_source='subsidiary'
  JOIN airlinerra_game.holding_groups_v1 holding
   ON holding.id=o.holding_id AND holding.world_id=l.world_id
   AND holding.owner_player_id=a.owner_player_id
  JOIN airlinerra_game.holding_subsidiaries_v1 subsidiary
   ON subsidiary.id=o.subsidiary_id AND subsidiary.holding_id=holding.id
   AND subsidiary.world_id=l.world_id AND subsidiary.company_kind='cargo_airline'
   AND subsidiary.formation_state='registered'
  JOIN airlinerra_game.section9_aoc_certificates_v1 c
   ON c.airline_id=l.airline_id AND c.world_id=l.world_id
  WHERE l.airline_id=p_airline AND l.world_id=1 AND d IS NOT NULL
   AND l.approved_game_day<=d
   AND c.status='active' AND c.issued_game_day<=d AND c.expires_game_day>d
   AND EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_release_policy_v1 aoc
    WHERE aoc.world_id=1 AND aoc.issuance_enabled AND aoc.flight_enforcement_enabled)
   AND (airlinerra_game.section9_aoc_safety_score_v1(l.airline_id,d)->>'rating')::integer>=50
   AND NOT EXISTS(SELECT 1 FROM airlinerra_game.licence34_company_compliance_v1 health
    WHERE health.airline_id=l.airline_id AND health.licence_code='CARGO_OPERATIONS_SCOPE'
      AND health.revoked_game_day IS NOT NULL)
   AND EXISTS(SELECT 1 FROM airlinerra_game.licence3_cargo_release_v1 r
    WHERE r.world_id=1 AND r.issuance_enabled AND r.fee_ledger_verified AND r.reviewer_verified)
   AND EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory fleet
    JOIN airlinerra_game.section5_aircraft_engine_and_icao_game_library_v1 model
     ON model.configuration_id=fleet.configuration_id
    WHERE fleet.airline_id=l.airline_id AND fleet.fleet_status='in_service'
     AND model.use_type IN ('cargo','combi'))
 ) INTO allowed;
 RETURN jsonb_build_object(
  'status',CASE WHEN allowed THEN 'CARGO_SERVICE_APPROVED_ROUTE_CHECKS_REQUIRED'
    ELSE 'CARGO_SERVICE_NOT_APPROVED' END,
  'authorized',allowed,'cargoServiceScopeWorldwide',allowed,
  'routeAuthorized',false,'flightActivated',false);
END $fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.licence3_cargo_readiness_v1(p_airline uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE
  a record; company record; day_now date;
  aircraft_count integer:=0; problems text[]:=array[]::text[];
  valid_aoc boolean:=false;fee numeric:=50000;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
   RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='CARGO_LICENCE3_TRUSTED_READ_ONLY';
 END IF;
 IF p_airline IS NULL THEN
   RETURN jsonb_build_object('status','AIRLINE_REQUIRED','eligible',false,'canApply',false,'feeUsd',fee,'processingGameDays',3,'issued',false,'charged',false);
 END IF;
 SELECT id,owner_player_id,world_id,cash_usd INTO a
 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1;
 IF NOT FOUND THEN
   RETURN jsonb_build_object('status','AIRLINE_NOT_FOUND','eligible',false,'canApply',false,'feeUsd',fee,'processingGameDays',3,'issued',false,'charged',false);
 END IF;
 SELECT o.* INTO company FROM airlinerra_game.section9_aoc_operating_companies_v1 o
 WHERE o.airline_id=p_airline AND o.world_id=1;
 IF NOT FOUND OR company.company_source IS DISTINCT FROM 'subsidiary'
    OR company.business_kind IS DISTINCT FROM 'cargo'
    OR company.holding_id IS NULL OR company.subsidiary_id IS NULL
    OR NOT EXISTS (
      SELECT 1 FROM airlinerra_game.holding_groups_v1 h
      JOIN airlinerra_game.holding_subsidiaries_v1 s
      ON s.holding_id=h.id
      WHERE h.id=company.holding_id AND s.id=company.subsidiary_id
        AND h.world_id=1 AND s.world_id=1
        AND h.owner_player_id=a.owner_player_id
        AND s.company_kind='cargo_airline'
    )
 THEN problems:=array_append(problems,'VERIFIED_HOLDING_CARGO_SUBSIDIARY_REQUIRED');END IF;
 day_now:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF day_now IS NULL THEN problems:=array_append(problems,'VERIFIED_GAME_DAY_REQUIRED');END IF;
 SELECT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_aoc_certificates_v1 c
   WHERE c.airline_id=p_airline AND c.world_id=1 AND c.status='active'
     AND day_now IS NOT NULL AND c.issued_game_day<=day_now AND c.expires_game_day>day_now
 ) INTO valid_aoc;
 IF NOT valid_aoc THEN problems:=array_append(problems,'ACTIVE_OWN_AOC_REQUIRED');END IF;
 SELECT count(*) INTO aircraft_count
 FROM airlinerra_game.airline_aircraft_inventory f
 JOIN airlinerra_game.section5_aircraft_engine_and_icao_game_library_v1 m
   ON m.configuration_id=f.configuration_id
 WHERE f.airline_id=p_airline AND f.fleet_status='in_service'
  AND m.use_type IN ('cargo','combi');
 IF aircraft_count<1 THEN problems:=array_append(problems,'ONE_IN_SERVICE_CARGO_AIRCRAFT_REQUIRED');END IF;
 IF day_now IS NOT NULL AND
  (airlinerra_game.section9_aoc_safety_score_v1(p_airline,day_now)->>'rating')::integer<50
 THEN problems:=array_append(problems,'SAFETY_BELOW_50_FOR_LICENCE3');END IF;
 IF a.cash_usd<fee THEN problems:=array_append(problems,'INSUFFICIENT_COMPANY_CASH_FOR_FEE');END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra_game.business_permission_catalog_v1
  WHERE permission_code='CARGO_OPERATIONS_SCOPE' AND enabled_in_game=true)
 THEN problems:=array_append(problems,'CARGO_LICENCE_ISSUANCE_NOT_RELEASED');END IF;
 RETURN jsonb_build_object(
 'status','LICENCE3_READ_ONLY_READINESS',
 'airlineId',p_airline,'gameDay',day_now,
 'eligible',cardinality(problems)=0,'canApply',false,
 'issues',to_jsonb(problems),
 'inServiceCargoAircraftCount',aircraft_count,'ownAocValid',valid_aoc,
 'feeUsd',fee,'processingGameDays',3,'applicationFeeUsd',0,
 'scope','WORLDWIDE_CARGO_SERVICE_ONLY',
 'worldwideRoutesGranted',false,'flightActivated',false,
 'issued',false,'charged',false);
END $fn$;

-- Licence 4: safety threshold 70, reapplication after true revocation, and audited fee recovery.
CREATE OR REPLACE FUNCTION airlinerra_game.licence4_submit_charter_application_v1(
 p_owner uuid,p_airline uuid,p_request_key uuid
) RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE a record; d date; readiness jsonb; app record;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE4_TRUSTED_APPLICATION_ONLY';
 END IF;
 IF p_owner IS NULL OR p_airline IS NULL OR p_request_key IS NULL
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='LICENCE4_APPLICATION_INVALID';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.licence4_charter_release_v1
  WHERE world_id=1 AND issuance_enabled AND fee_ledger_verified AND reviewer_verified)
 THEN RETURN jsonb_build_object('status','NOT_RELEASED','submitted',false,'charged',false,'issued',false);END IF;
 SELECT * INTO a FROM airlinerra_game.airlines
  WHERE id=p_airline AND world_id=1 AND owner_player_id=p_owner FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE4_AIRLINE_NOT_OWNED';END IF;
 SELECT * INTO app FROM airlinerra_game.licence4_charter_applications_v1
  WHERE airline_id=p_airline AND request_key=p_request_key;
 IF FOUND THEN RETURN jsonb_build_object('status',app.status,'applicationId',app.application_id,
  'submitted',true,'charged',false,'issued',false,'replay',true);END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.licence4_charter_approvals_v1 approval
  LEFT JOIN airlinerra_game.licence34_company_compliance_v1 health
    ON health.airline_id=approval.airline_id AND health.licence_code='CHARTER_VIP_SCOPE'
  WHERE approval.airline_id=p_airline AND health.revoked_game_day IS NULL)
 THEN RETURN jsonb_build_object('status','ALREADY_APPROVED','submitted',false,'charged',false,'issued',false);END IF;
 readiness:=airlinerra_game.licence4_charter_readiness_v1(p_airline);
 IF readiness->>'eligible' IS DISTINCT FROM 'true'
 THEN RETURN jsonb_build_object('status','NOT_ELIGIBLE','readiness',readiness,
  'submitted',false,'charged',false,'issued',false);END IF;
 d:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF d IS NULL OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1
  WHERE world_id=1 AND game_date=d)
 THEN RETURN jsonb_build_object('status','GAME_TICK_UNVERIFIED','submitted',false,'charged',false,'issued',false);END IF;
 INSERT INTO airlinerra_game.licence4_charter_applications_v1(
  airline_id,owner_player_id,request_key,submitted_game_day,due_game_day)
 VALUES(p_airline,p_owner,p_request_key,d,d+3)
 RETURNING * INTO app;
 RETURN jsonb_build_object('status','SUBMITTED','applicationId',app.application_id,
  'dueGameDay',app.due_game_day,'feeOnApprovalUsd',40000,
  'submitted',true,'charged',false,'issued',false);
END $fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.licence4_review_due_charter_game_applications_v1(p_limit integer DEFAULT 25)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE d date; app record; a record; readiness jsonb; ledger_id bigint;
 reviewed integer:=0;issued integer:=0;blocked integer:=0;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='LICENCE4_TRUSTED_REVIEW_ONLY';END IF;
 IF p_limit IS NULL OR p_limit NOT BETWEEN 1 AND 25 THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='LICENCE4_INVALID_BATCH_LIMIT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.licence4_charter_release_v1
 WHERE world_id=1 AND issuance_enabled AND fee_ledger_verified AND reviewer_verified)
 THEN RETURN jsonb_build_object('status','NOT_RELEASED','reviewed',0,'issued',0,'charged',false,'flightActivated',false);END IF;
 d:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF d IS NULL OR NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1
 WHERE world_id=1 AND game_date=d) THEN RETURN jsonb_build_object('status','GAME_TICK_UNVERIFIED',
 'reviewed',0,'issued',0,'charged',false,'flightActivated',false);END IF;
 IF NOT pg_catalog.pg_try_advisory_xact_lock(583729,10023) THEN
 RETURN jsonb_build_object('status','REVIEW_BUSY','reviewed',0,'issued',0,'charged',false,'flightActivated',false);END IF;
 FOR app IN SELECT application_id,airline_id,owner_player_id,due_game_day
   FROM airlinerra_game.licence4_charter_applications_v1
   WHERE status='submitted' AND due_game_day<=d ORDER BY due_game_day,application_id LIMIT p_limit
 LOOP
  SELECT * INTO a FROM airlinerra_game.airlines WHERE id=app.airline_id AND world_id=1 FOR UPDATE;
  IF NOT FOUND OR a.owner_player_id IS DISTINCT FROM app.owner_player_id
  THEN blocked:=blocked+1;CONTINUE;END IF;
  PERFORM 1 FROM airlinerra_game.licence4_charter_applications_v1
    WHERE application_id=app.application_id AND status='submitted' FOR UPDATE;
  IF NOT FOUND THEN CONTINUE;END IF;
  reviewed:=reviewed+1;
  readiness:=airlinerra_game.licence4_charter_readiness_v1(app.airline_id);
  IF readiness->>'eligible' IS DISTINCT FROM 'true'
   OR EXISTS(SELECT 1 FROM airlinerra_game.licence4_charter_approvals_v1 approval
     LEFT JOIN airlinerra_game.licence34_company_compliance_v1 health
       ON health.airline_id=approval.airline_id AND health.licence_code='CHARTER_VIP_SCOPE'
     WHERE approval.airline_id=app.airline_id AND health.revoked_game_day IS NULL)
   OR a.cash_usd<40000
   OR (SELECT coalesce(sum(amount_usd),0) FROM airlinerra_game.airline_ledger
       WHERE airline_id=app.airline_id) IS DISTINCT FROM a.cash_usd
  THEN blocked:=blocked+1;CONTINUE;END IF;
  UPDATE airlinerra_game.airlines SET cash_usd=cash_usd-40000
   WHERE id=app.airline_id AND cash_usd>=40000;
  IF NOT FOUND THEN RAISE EXCEPTION 'LICENCE4_CONCURRENT_BALANCE_FAILURE';END IF;
  INSERT INTO airlinerra_game.airline_ledger(airline_id,entry_kind,amount_usd)
   VALUES(app.airline_id,'EXPENSE',-40000) RETURNING id INTO ledger_id;
  INSERT INTO airlinerra_game.licence4_charter_approvals_v1(
   airline_id,application_id,fee_ledger_id,approved_game_day,approval_reference)
  VALUES(app.airline_id,app.application_id,ledger_id,d,'charter-vip-game-licence4-v1-'||app.application_id::text)
  ON CONFLICT(airline_id) DO UPDATE SET
   application_id=excluded.application_id,fee_ledger_id=excluded.fee_ledger_id,
   approved_game_day=excluded.approved_game_day,approval_reference=excluded.approval_reference,
   created_at=clock_timestamp();
  INSERT INTO airlinerra_game.licence34_company_compliance_v1
   (airline_id,licence_code,last_checked_game_day)
  VALUES(app.airline_id,'CHARTER_VIP_SCOPE',d)
  ON CONFLICT(airline_id,licence_code) DO UPDATE SET
   no_aircraft_since_game_day=NULL,last_checked_game_day=excluded.last_checked_game_day,
   revoked_game_day=NULL,revocation_reason=NULL,updated_at=clock_timestamp();
  UPDATE airlinerra_game.licence4_charter_applications_v1
   SET status='issued',issued_game_day=d,fee_ledger_id=ledger_id,
    issued_reference='charter-vip-game-licence4-v1-'||app.application_id::text
   WHERE application_id=app.application_id AND status='submitted';
  IF NOT FOUND THEN RAISE EXCEPTION 'LICENCE4_APPLICATION_CONCURRENT_CHANGE';END IF;
  issued:=issued+1;
 END LOOP;
 RETURN jsonb_build_object('status','REVIEWED','reviewed',reviewed,'issued',issued,'blocked',blocked,
 'chargeOnlyWithIssuance',true,'flightActivated',false);
END $fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.licence4_charter_flight_scope_v1(p_airline uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE
 d date;
 allowed boolean:=false;
BEGIN
 d:=airlinerra_game.section9_verified_permission_game_day_v1();
 SELECT EXISTS(
  SELECT 1
  FROM airlinerra_game.licence4_charter_approvals_v1 l
  JOIN airlinerra_game.licence4_charter_applications_v1 app
   ON app.application_id=l.application_id AND app.airline_id=l.airline_id
   AND app.world_id=l.world_id AND app.status='issued'
   AND app.fee_usd=40000 AND app.fee_ledger_id=l.fee_ledger_id
   AND app.issued_game_day=l.approved_game_day
  JOIN airlinerra_game.airline_ledger fee
   ON fee.id=l.fee_ledger_id AND fee.airline_id=l.airline_id
   AND fee.entry_kind='EXPENSE' AND fee.amount_usd=-40000
  JOIN airlinerra_game.airlines a
   ON a.id=l.airline_id AND a.world_id=l.world_id
   AND a.owner_player_id=app.owner_player_id
  JOIN airlinerra_game.section9_aoc_operating_companies_v1 o
   ON o.airline_id=l.airline_id AND o.world_id=l.world_id
   AND o.business_kind IN ('charter','vip') AND o.company_source='subsidiary'
  JOIN airlinerra_game.holding_groups_v1 holding
   ON holding.id=o.holding_id AND holding.world_id=l.world_id
   AND holding.owner_player_id=a.owner_player_id
  JOIN airlinerra_game.holding_subsidiaries_v1 subsidiary
   ON subsidiary.id=o.subsidiary_id AND subsidiary.holding_id=holding.id
   AND subsidiary.world_id=l.world_id AND subsidiary.company_kind='charter_airline'
   AND subsidiary.formation_state='registered'
  JOIN airlinerra_game.section9_aoc_certificates_v1 c
   ON c.airline_id=l.airline_id AND c.world_id=l.world_id
  WHERE l.airline_id=p_airline AND l.world_id=1 AND d IS NOT NULL
   AND l.approved_game_day<=d
   AND c.status='active' AND c.issued_game_day<=d AND c.expires_game_day>d
   AND EXISTS(SELECT 1 FROM airlinerra_game.section9_aoc_release_policy_v1 aoc
    WHERE aoc.world_id=1 AND aoc.issuance_enabled AND aoc.flight_enforcement_enabled)
   AND (airlinerra_game.section9_aoc_safety_score_v1(l.airline_id,d)->>'rating')::integer>=70
   AND NOT EXISTS(SELECT 1 FROM airlinerra_game.licence34_company_compliance_v1 health
    WHERE health.airline_id=l.airline_id AND health.licence_code='CHARTER_VIP_SCOPE'
      AND health.revoked_game_day IS NOT NULL)
   AND EXISTS(SELECT 1 FROM airlinerra_game.licence4_charter_release_v1 r
    WHERE r.world_id=1 AND r.issuance_enabled AND r.fee_ledger_verified AND r.reviewer_verified)
   AND EXISTS(SELECT 1 FROM airlinerra_game.airline_aircraft_inventory fleet
    JOIN airlinerra_game.section5_aircraft_engine_and_icao_game_library_v1 model
     ON model.configuration_id=fleet.configuration_id
    WHERE fleet.airline_id=l.airline_id AND fleet.fleet_status='in_service'
     AND model.use_type IN ('passenger','combi'))
 ) INTO allowed;
 RETURN jsonb_build_object(
  'status',CASE WHEN allowed THEN 'CHARTER_VIP_APPROVED_ROUTE_CHECKS_REQUIRED'
    ELSE 'CHARTER_VIP_NOT_APPROVED' END,
  'authorized',allowed,'charterVipServiceScope',allowed,
  'routeAuthorized',false,'flightActivated',false);
END $fn$;
CREATE OR REPLACE FUNCTION airlinerra_game.licence4_charter_readiness_v1(p_airline uuid)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $fn$
DECLARE
  a record; company record; day_now date;
  aircraft_count integer:=0; problems text[]:=array[]::text[];
  valid_aoc boolean:=false;fee numeric:=40000;
BEGIN
 IF current_user IS DISTINCT FROM 'postgres' THEN
   RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='CHARTER_VIP_LICENCE4_TRUSTED_READ_ONLY';
 END IF;
 IF p_airline IS NULL THEN
   RETURN jsonb_build_object('status','AIRLINE_REQUIRED','eligible',false,'canApply',false,'feeUsd',fee,'processingGameDays',3,'issued',false,'charged',false);
 END IF;
 SELECT id,owner_player_id,world_id,cash_usd INTO a
 FROM airlinerra_game.airlines WHERE id=p_airline AND world_id=1;
 IF NOT FOUND THEN
   RETURN jsonb_build_object('status','AIRLINE_NOT_FOUND','eligible',false,'canApply',false,'feeUsd',fee,'processingGameDays',3,'issued',false,'charged',false);
 END IF;
 SELECT o.* INTO company FROM airlinerra_game.section9_aoc_operating_companies_v1 o
 WHERE o.airline_id=p_airline AND o.world_id=1;
 IF NOT FOUND OR company.company_source IS DISTINCT FROM 'subsidiary'
    OR company.business_kind NOT IN ('charter','vip')
    OR company.holding_id IS NULL OR company.subsidiary_id IS NULL
    OR NOT EXISTS (
      SELECT 1 FROM airlinerra_game.holding_groups_v1 h
      JOIN airlinerra_game.holding_subsidiaries_v1 s
      ON s.holding_id=h.id
      WHERE h.id=company.holding_id AND s.id=company.subsidiary_id
        AND h.world_id=1 AND s.world_id=1
        AND h.owner_player_id=a.owner_player_id
        AND s.company_kind='charter_airline' AND s.formation_state='registered'
    )
 THEN problems:=array_append(problems,'VERIFIED_HOLDING_CHARTER_SUBSIDIARY_REQUIRED');END IF;
 day_now:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF day_now IS NULL THEN problems:=array_append(problems,'VERIFIED_GAME_DAY_REQUIRED');END IF;
 SELECT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_aoc_certificates_v1 c
   WHERE c.airline_id=p_airline AND c.world_id=1 AND c.status='active'
     AND day_now IS NOT NULL AND c.issued_game_day<=day_now AND c.expires_game_day>day_now
 ) INTO valid_aoc;
 IF NOT valid_aoc THEN problems:=array_append(problems,'ACTIVE_OWN_AOC_REQUIRED');END IF;
 SELECT count(*) INTO aircraft_count
 FROM airlinerra_game.airline_aircraft_inventory f
 JOIN airlinerra_game.section5_aircraft_engine_and_icao_game_library_v1 m
   ON m.configuration_id=f.configuration_id
 WHERE f.airline_id=p_airline AND f.fleet_status='in_service'
  AND m.use_type IN ('passenger','combi');
 IF aircraft_count<1 THEN problems:=array_append(problems,'ONE_IN_SERVICE_PASSENGER_AIRCRAFT_REQUIRED');END IF;
 IF day_now IS NOT NULL AND
  (airlinerra_game.section9_aoc_safety_score_v1(p_airline,day_now)->>'rating')::integer<70
 THEN problems:=array_append(problems,'SAFETY_BELOW_70_FOR_LICENCE4');END IF;
 IF a.cash_usd<fee THEN problems:=array_append(problems,'INSUFFICIENT_COMPANY_CASH_FOR_FEE');END IF;
 IF NOT EXISTS (SELECT 1 FROM airlinerra_game.business_permission_catalog_v1
  WHERE permission_code='CHARTER_VIP_SCOPE' AND enabled_in_game=true)
 THEN problems:=array_append(problems,'CHARTER_VIP_LICENCE_ISSUANCE_NOT_RELEASED');END IF;
 RETURN jsonb_build_object(
 'status','LICENCE4_READ_ONLY_READINESS',
 'airlineId',p_airline,'gameDay',day_now,
 'eligible',cardinality(problems)=0,'canApply',false,
 'issues',to_jsonb(problems),
 'inServiceCharterAircraftCount',aircraft_count,'ownAocValid',valid_aoc,
 'feeUsd',fee,'processingGameDays',3,'applicationFeeUsd',0,
 'scope','CHARTER_VIP_SERVICE_ONLY',
 'worldwideRoutesGranted',false,'flightActivated',false,
 'issued',false,'charged',false);
END $fn$;
