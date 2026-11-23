-- World 1: private signed decision sink, atomic issue/fee/ledger,
-- rejection, revocation and clock-driven expiration.
-- SQL must be called ONLY behind independently verified HMAC backend;
-- SQL stores digests and never holds the private signing key.

CREATE OR REPLACE FUNCTION airlinerra_game.section9_decide_game_permission_application_v1(
 p_application uuid,p_event_id text,p_decision text,
 p_review_reference text,p_verified_hmac text,p_game_date date
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE app record;old_event record;airline_row record;
 policy_row record;catalog_row record;day_now date;
 origin_country text;destination_country text;home_country text;
 expected_code text;entry_id bigint;new_expiry date;
 new_status text;
BEGIN
 IF p_application IS NULL OR p_event_id IS NULL OR
  p_event_id !~ '^[A-Za-z0-9._:-]{16,128}$' OR
  p_decision NOT IN('approve','reject','revoke') OR
  length(coalesce(p_review_reference,'')) NOT BETWEEN 12 AND 160 OR
  p_verified_hmac IS NULL OR p_verified_hmac !~ '^[a-f0-9]{64}$' OR
  p_game_date IS NULL OR p_game_date NOT BETWEEN
   DATE '2000-01-01' AND DATE '2199-12-01'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_SIGNED_GAME_PERMISSION_DECISION';END IF;
 -- Lock airline before application to serialize cash with all other
 -- purchases and admissions for the SAME company.
 SELECT a.* INTO airline_row
 FROM airlinerra_game.airlines a
 WHERE a.id=(SELECT app.airline_id
  FROM airlinerra_game.section9_game_permission_applications_v1 app
  WHERE app.id=p_application)
 AND a.world_id=1 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_PERMISSION_DECISION_AIRLINE_NOT_FOUND';END IF;
 SELECT * INTO app
 FROM airlinerra_game.section9_game_permission_applications_v1 p
 WHERE p.id=p_application AND p.airline_id=airline_row.id
 FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_PERMISSION_DECISION_APPLICATION_NOT_FOUND';END IF;
 SELECT * INTO old_event
 FROM airlinerra_game.section9_game_permission_review_events_v1 event
 WHERE event.event_id=p_event_id;
 IF FOUND THEN
  IF old_event.application_id IS DISTINCT FROM p_application
   OR old_event.airline_id IS DISTINCT FROM app.airline_id
   OR old_event.decision IS DISTINCT FROM p_decision
   OR old_event.game_date IS DISTINCT FROM p_game_date
   OR old_event.reviewer_reference IS DISTINCT FROM p_review_reference
   OR old_event.verified_hmac_sha256 IS DISTINCT FROM p_verified_hmac
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_GAME_PERMISSION_DECISION_REPLAY_CONFLICT';END IF;
  RETURN jsonb_build_object(
   'status','game_permission_decision_replayed',
   'applicationId',p_application,'eventId',p_event_id,
   'replayed',true,'applicationStatus',app.status,
   'chargedNow',false,'licenceIssuedNow',false,
   'flightActivated',false,'ledgerPostedNow',false);
 END IF;

 day_now:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF day_now IS NULL OR day_now IS DISTINCT FROM p_game_date
 THEN RETURN jsonb_build_object(
  'status','blocked_unverified_world_or_game_day',
  'applicationId',p_application,'chargedNow',false,
  'licenceIssuedNow',false,'flightActivated',false,
  'ledgerPostedNow',false);END IF;
 IF p_decision IN ('approve','reject') AND
   (app.status IS DISTINCT FROM 'submitted'
    OR app.due_game_date>day_now)
 THEN RETURN jsonb_build_object(
  'status','blocked_application_not_due_or_processed',
  'applicationId',p_application,'chargedNow',false,
  'licenceIssuedNow',false,'flightActivated',false,
  'ledgerPostedNow',false);END IF;
 IF p_decision='revoke' AND app.status IS DISTINCT FROM 'issued'
 THEN RETURN jsonb_build_object(
  'status','blocked_application_not_issued',
  'applicationId',p_application,'chargedNow',false,
  'licenceIssuedNow',false,'flightActivated',false,
  'ledgerPostedNow',false);END IF;

 IF p_decision='approve' THEN
  SELECT * INTO policy_row
  FROM airlinerra_game.section9_game_permission_issuance_policy_v1 p
  WHERE p.permission_code=app.permission_code FOR SHARE;
  SELECT * INTO catalog_row
  FROM airlinerra_game.business_permission_catalog_v1 c
  WHERE c.permission_code=app.permission_code FOR SHARE;
  IF policy_row.release_enabled IS DISTINCT FROM true OR
   policy_row.released_at IS NULL OR
   policy_row.policy_revision IS DISTINCT FROM app.policy_revision OR
   policy_row.validity_game_days IS DISTINCT FROM app.validity_game_days OR
   catalog_row.enabled_in_game IS DISTINCT FROM true OR
   catalog_row.game_fee_usd IS DISTINCT FROM app.fee_usd OR
   catalog_row.processing_game_days IS DISTINCT FROM
    (app.due_game_date-app.applied_game_date)
  THEN RETURN jsonb_build_object(
   'status','blocked_permission_policy_changed_or_disabled',
   'applicationId',p_application,'chargedNow',false,
   'licenceIssuedNow',false,'flightActivated',false,
   'ledgerPostedNow',false);END IF;
  SELECT home.country_iso INTO home_country
  FROM airlinerra_game.airport_reference_profiles home
  WHERE home.world_id=1 AND home.airport_key=airline_row.home_airport_key;
  IF home_country IS NULL OR home_country !~ '^[A-Z]{2}$'
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_GAME_PERMISSION_AIRLINE_JURISDICTION_CHANGED';END IF;
  IF app.permission_code='AIR_OPERATOR_CERTIFICATE' THEN
   IF app.jurisdiction_iso2 IS DISTINCT FROM home_country
   THEN RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_OPERATOR_LICENCE_JURISDICTION_CHANGED';END IF;
  ELSE
   SELECT country_iso INTO origin_country
   FROM airlinerra_game.airport_reference_profiles
   WHERE world_id=1 AND airport_key=app.origin_airport_key;
   SELECT country_iso INTO destination_country
   FROM airlinerra_game.airport_reference_profiles
   WHERE world_id=1 AND airport_key=app.destination_airport_key;
   expected_code:=airlinerra_game.section9_required_game_traffic_permission_v1(
    home_country,origin_country,destination_country,
    app.service_type,p_game_date);
   IF expected_code IS DISTINCT FROM app.permission_code
   THEN RETURN jsonb_build_object(
    'status','blocked_game_traffic_rights_policy_changed',
    'applicationId',p_application,'chargedNow',false,
    'licenceIssuedNow',false,'flightActivated',false,
    'ledgerPostedNow',false);END IF;
   IF NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section9_game_permission_applications_v1 issued
    JOIN airlinerra_game.section9_operator_licence_evidence_v1 lic
     ON lic.issued_application_id=issued.id
    WHERE issued.airline_id=app.airline_id
     AND issued.permission_code='AIR_OPERATOR_CERTIFICATE'
     AND issued.status='issued'
     AND lic.evidence_status='verified'
     AND lic.jurisdiction_iso2=home_country
     AND lic.valid_from<=day_now
     AND lic.valid_until>=day_now+28
    ) THEN RETURN jsonb_build_object(
     'status','blocked_operator_licence_expired_or_revoked',
     'applicationId',p_application,'chargedNow',false,
     'licenceIssuedNow',false,'flightActivated',false,
     'ledgerPostedNow',false);END IF;
  END IF;
  IF EXISTS(
   SELECT 1 FROM airlinerra_game.section9_game_permission_applications_v1 other
   WHERE other.airline_id=app.airline_id AND other.scope_key=app.scope_key
    AND other.id<>app.id AND other.status='issued'
    AND other.valid_until_game_date>=day_now+28
  ) THEN RETURN jsonb_build_object(
   'status','blocked_permission_already_valid',
   'applicationId',p_application,'chargedNow',false,
   'licenceIssuedNow',false,'flightActivated',false,
   'ledgerPostedNow',false);END IF;
  IF airline_row.cash_usd<app.fee_usd
  THEN RETURN jsonb_build_object(
   'status','blocked_insufficient_airline_cash',
   'applicationId',p_application,'chargedNow',false,
   'licenceIssuedNow',false,'flightActivated',false,
   'ledgerPostedNow',false);END IF;
  -- Atomic financial settlement (one transaction and one airline lock).
  -- The existing ledger requires EXPENSE with nonzero negative amount.
  UPDATE airlinerra_game.airlines
  SET cash_usd=cash_usd-app.fee_usd
  WHERE id=app.airline_id AND cash_usd>=app.fee_usd;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='40001',
   MESSAGE='SECTION9_GAME_PERMISSION_CASH_CHANGED_CONCURRENTLY';END IF;
  INSERT INTO airlinerra_game.airline_ledger(
   airline_id,entry_kind,amount_usd)
  VALUES(app.airline_id,'EXPENSE',-app.fee_usd)
  RETURNING id INTO entry_id;
  new_expiry:=day_now+app.validity_game_days;
  IF app.permission_code='AIR_OPERATOR_CERTIFICATE' THEN
   INSERT INTO airlinerra_game.section9_operator_licence_evidence_v1(
    world_id,airline_id,jurisdiction_iso2,evidence_status,
    evidence_reference,reviewed_at,valid_from,valid_until,
    issued_application_id)
   VALUES(1,app.airline_id,home_country,'verified',
    'game-permission-issued-v1-'||app.id::text,
    clock_timestamp(),day_now,new_expiry,app.id)
   ON CONFLICT(airline_id,jurisdiction_iso2) DO UPDATE SET
    evidence_status='verified',
    evidence_reference=EXCLUDED.evidence_reference,
    reviewed_at=EXCLUDED.reviewed_at,
    valid_from=EXCLUDED.valid_from,
    valid_until=EXCLUDED.valid_until,
    issued_application_id=EXCLUDED.issued_application_id;
  ELSE
   INSERT INTO airlinerra_game.section9_route_operating_permission_evidence_v1(
    world_id,airline_id,origin_airport_key,destination_airport_key,
    service_type,evidence_status,evidence_reference,
    reviewed_at,valid_from,valid_until,issued_application_id)
   VALUES(1,app.airline_id,app.origin_airport_key,
    app.destination_airport_key,app.service_type,'verified',
    'game-permission-issued-v1-'||app.id::text,
    clock_timestamp(),day_now,new_expiry,app.id)
   ON CONFLICT(airline_id,origin_airport_key,destination_airport_key,service_type)
   DO UPDATE SET evidence_status='verified',
    evidence_reference=EXCLUDED.evidence_reference,
    reviewed_at=EXCLUDED.reviewed_at,
    valid_from=EXCLUDED.valid_from,
    valid_until=EXCLUDED.valid_until,
    issued_application_id=EXCLUDED.issued_application_id;
  END IF;
  UPDATE airlinerra_game.section9_game_permission_applications_v1
  SET status='issued',issued_game_date=day_now,
   valid_until_game_date=new_expiry,ledger_entry_id=entry_id,
   reviewed_by=p_review_reference,reviewed_at=clock_timestamp(),
   last_review_event_id=p_event_id,updated_at=clock_timestamp()
  WHERE id=p_application;
  new_status:='issued';
 ELSIF p_decision='reject' THEN
  UPDATE airlinerra_game.section9_game_permission_applications_v1
  SET status='rejected',reviewed_by=p_review_reference,
   reviewed_at=clock_timestamp(),last_review_event_id=p_event_id,
   updated_at=clock_timestamp()
  WHERE id=p_application;
  new_status:='rejected';
 ELSE
  UPDATE airlinerra_game.section9_game_permission_applications_v1
  SET status='revoked',reviewed_by=p_review_reference,
   reviewed_at=clock_timestamp(),last_review_event_id=p_event_id,
   updated_at=clock_timestamp()
  WHERE id=p_application;
  IF app.permission_code='AIR_OPERATOR_CERTIFICATE' THEN
   UPDATE airlinerra_game.section9_operator_licence_evidence_v1
   SET evidence_status='revoked',reviewed_at=clock_timestamp()
   WHERE issued_application_id=p_application;
  ELSE
   UPDATE airlinerra_game.section9_route_operating_permission_evidence_v1
   SET evidence_status='revoked',reviewed_at=clock_timestamp()
   WHERE issued_application_id=p_application;
  END IF;
  new_status:='revoked';
 END IF;

 INSERT INTO airlinerra_game.section9_game_permission_review_events_v1(
  event_id,application_id,airline_id,decision,game_date,
  reviewer_reference,verified_hmac_sha256)
 VALUES(p_event_id,p_application,app.airline_id,p_decision,p_game_date,
  p_review_reference,p_verified_hmac);
 -- An operator revocation/expiration affects ALL routes of the airline.
 DELETE FROM airlinerra_game.section9_schedule_activation_preparations_v1
 WHERE airline_id=app.airline_id;
 RETURN jsonb_build_object(
  'status','game_permission_'||new_status,
  'applicationId',p_application,'eventId',p_event_id,
  'applicationStatus',new_status,'validUntilGameDate',
   CASE WHEN new_status='issued' THEN new_expiry ELSE app.valid_until_game_date END,
  'feeChargedUsd',CASE WHEN new_status='issued' THEN app.fee_usd ELSE 0 END,
  'ledgerEntryId',entry_id,
  'replayed',false,'chargedNow',(new_status='issued'),
  'licenceIssuedNow',(new_status='issued'),
  'flightActivated',false,'ledgerPostedNow',(new_status='issued'),
  'bookingsCreated',false,'movementRecorded',false);
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_decide_game_permission_application_v1(
 uuid,text,text,text,text,date)
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_expire_game_permissions_batch_v1(
 p_limit integer DEFAULT 100
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE day_now date;expired_count integer;
BEGIN
 IF p_limit NOT BETWEEN 1 AND 200 THEN RAISE EXCEPTION USING
  ERRCODE='22023',MESSAGE='SECTION9_INVALID_PERMISSION_EXPIRY_LIMIT';END IF;
 day_now:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF day_now IS NULL THEN RETURN jsonb_build_object(
  'status','blocked_unverified_world_or_game_day','expired',0,
  'ledgerPosted',false,'flightActivated',false);END IF;
 WITH expiring AS (
  SELECT id FROM airlinerra_game.section9_game_permission_applications_v1
  WHERE status='issued' AND valid_until_game_date<day_now
  ORDER BY valid_until_game_date,id
  FOR UPDATE SKIP LOCKED LIMIT p_limit
 ),updated AS (
  UPDATE airlinerra_game.section9_game_permission_applications_v1 a
  SET status='expired',updated_at=clock_timestamp()
  FROM expiring e WHERE a.id=e.id
  RETURNING a.id,a.airline_id,a.permission_code
 ),licence AS (
  UPDATE airlinerra_game.section9_operator_licence_evidence_v1 l
  SET evidence_status='revoked',reviewed_at=clock_timestamp()
  FROM updated u
  WHERE l.issued_application_id=u.id
  RETURNING l.airline_id
 ),routes AS (
  UPDATE airlinerra_game.section9_route_operating_permission_evidence_v1 r
  SET evidence_status='revoked',reviewed_at=clock_timestamp()
  FROM updated u
  WHERE r.issued_application_id=u.id
  RETURNING r.airline_id
 ),invalidation AS (
  DELETE FROM airlinerra_game.section9_schedule_activation_preparations_v1 prep
  USING updated u WHERE prep.airline_id=u.airline_id
  RETURNING prep.schedule_id
 )
 SELECT count(*) INTO expired_count FROM updated;
 RETURN jsonb_build_object(
  'status','game_permission_expiry_batch_completed',
  'gameDate',day_now,'expired',expired_count,
  'ledgerPosted',false,'flightActivated',false,
  'movementRecorded',false,'bookingsCreated',false);
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_expire_game_permissions_batch_v1(integer)
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_game_permission_applications_v1(
 p_player uuid,p_airline uuid
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE results jsonb;
BEGIN
 IF NOT EXISTS(
  SELECT 1 FROM airlinerra_game.airlines a
  WHERE a.id=p_airline AND a.owner_player_id=p_player AND a.world_id=1)
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_PERMISSION_APPLICATION_LIST_NOT_OWNED';END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
  'applicationId',a.id,'permissionCode',a.permission_code,
  'scope',a.scope_key,'status',a.status,
  'appliedGameDate',a.applied_game_date,
  'dueGameDate',a.due_game_date,
  'issuedGameDate',a.issued_game_date,
  'validUntilGameDate',a.valid_until_game_date,
  'feeUsd',a.fee_usd,
  'feeCharged',(a.ledger_entry_id IS NOT NULL)
 ) ORDER BY a.applied_at DESC,a.id),'[]'::jsonb) INTO results
 FROM airlinerra_game.section9_game_permission_applications_v1 a
 WHERE a.airline_id=p_airline;
 RETURN jsonb_build_object('worldId',1,'airlineId',p_airline,
  'applications',results,'readOnly',true);
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_owned_game_permission_applications_v1(uuid,uuid)
 FROM PUBLIC,anon,authenticated;
