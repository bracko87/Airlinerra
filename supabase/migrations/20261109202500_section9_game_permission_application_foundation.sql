-- World 1: durable, guarded GAME permission applications and fee settlement.
-- All catalog entries remain disabled by an existing independent hard CHECK.
-- No policy rows, prices, licences, routes, signing keys or releases seeded.

CREATE TABLE airlinerra_game.section9_game_permission_issuance_policy_v1(
 permission_code text PRIMARY KEY REFERENCES
  airlinerra_game.business_permission_catalog_v1(permission_code),
 release_enabled boolean NOT NULL DEFAULT false,
 validity_game_days integer NOT NULL CHECK(validity_game_days BETWEEN 35 AND 1095),
 policy_revision integer NOT NULL DEFAULT 1 CHECK(policy_revision>0),
 reviewed_by text NOT NULL CHECK(length(reviewed_by) BETWEEN 12 AND 160),
 release_reference text CHECK(length(release_reference) BETWEEN 16 AND 160),
 released_at timestamptz,
 reviewed_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 CHECK((release_enabled=true AND release_reference IS NOT NULL
   AND released_at IS NOT NULL) OR
  (release_enabled=false AND released_at IS NULL))
);
ALTER TABLE airlinerra_game.section9_game_permission_issuance_policy_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_game_permission_issuance_policy_v1
 FROM PUBLIC,anon,authenticated;

CREATE TABLE airlinerra_game.section9_game_permission_applications_v1(
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 applicant_player_id uuid NOT NULL,
 request_key uuid NOT NULL,
 permission_code text NOT NULL REFERENCES
  airlinerra_game.business_permission_catalog_v1(permission_code),
 scope_key text NOT NULL CHECK(length(scope_key) BETWEEN 4 AND 200),
 jurisdiction_iso2 text,
 origin_airport_key text,
 destination_airport_key text,
 service_type text CHECK(service_type IN('passenger','cargo')),
 applied_game_date date NOT NULL,
 due_game_date date NOT NULL,
 policy_revision integer NOT NULL CHECK(policy_revision>0),
 fee_usd numeric(14,2) NOT NULL CHECK(fee_usd>0 AND fee_usd<=1000000),
 validity_game_days integer NOT NULL CHECK(validity_game_days BETWEEN 35 AND 1095),
 status text NOT NULL DEFAULT 'submitted'
  CHECK(status IN('submitted','issued','rejected','revoked','expired')),
 issued_game_date date,valid_until_game_date date,
 last_review_event_id text,
 reviewed_by text,
 reviewed_at timestamptz,
 ledger_entry_id bigint UNIQUE REFERENCES airlinerra_game.airline_ledger(id),
 applied_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 updated_at timestamptz NOT NULL DEFAULT clock_timestamp(),
 UNIQUE(airline_id,request_key),
 CHECK(due_game_date>=applied_game_date),
 CHECK(
  (status IN('issued','revoked','expired') AND issued_game_date IS NOT NULL
   AND valid_until_game_date IS NOT NULL AND ledger_entry_id IS NOT NULL)
  OR (status IN('submitted','rejected') AND issued_game_date IS NULL
   AND valid_until_game_date IS NULL AND ledger_entry_id IS NULL)),
 CHECK((permission_code='AIR_OPERATOR_CERTIFICATE' AND
   jurisdiction_iso2 ~ '^[A-Z]{2}$' AND origin_airport_key IS NULL
   AND destination_airport_key IS NULL AND service_type IS NULL) OR
  (permission_code<>'AIR_OPERATOR_CERTIFICATE' AND
   jurisdiction_iso2 IS NULL AND origin_airport_key IS NOT NULL
   AND destination_airport_key IS NOT NULL
   AND origin_airport_key<>destination_airport_key
   AND service_type IN ('passenger','cargo')))
);
CREATE UNIQUE INDEX section9_one_pending_game_permission_scope_idx
 ON airlinerra_game.section9_game_permission_applications_v1
 (airline_id,scope_key) WHERE status='submitted';
CREATE INDEX section9_game_permission_due_idx
 ON airlinerra_game.section9_game_permission_applications_v1
 (status,due_game_date,id);
CREATE INDEX section9_game_permission_expiry_idx
 ON airlinerra_game.section9_game_permission_applications_v1
 (status,valid_until_game_date,id);
ALTER TABLE airlinerra_game.section9_game_permission_applications_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_game_permission_applications_v1
 FROM PUBLIC,anon,authenticated;

CREATE TABLE airlinerra_game.section9_game_permission_review_events_v1(
 event_id text PRIMARY KEY CHECK(event_id ~ '^[A-Za-z0-9._:-]{16,128}$'),
 application_id uuid NOT NULL REFERENCES
  airlinerra_game.section9_game_permission_applications_v1(id)
  ON DELETE RESTRICT,
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 decision text NOT NULL CHECK(decision IN ('approve','reject','revoke')),
 game_date date NOT NULL,
 reviewer_reference text NOT NULL
  CHECK(length(reviewer_reference) BETWEEN 12 AND 160),
 verified_hmac_sha256 text NOT NULL CHECK(verified_hmac_sha256~'^[a-f0-9]{64}$'),
 recorded_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE airlinerra_game.section9_game_permission_review_events_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_game_permission_review_events_v1
 FROM PUBLIC,anon,authenticated;
CREATE TRIGGER section9_permission_reviews_append_only
 BEFORE UPDATE OR DELETE ON
 airlinerra_game.section9_game_permission_review_events_v1
 FOR EACH ROW EXECUTE FUNCTION
 airlinerra_game.section9_reject_certificate_audit_mutation_v1();

ALTER TABLE airlinerra_game.section9_operator_licence_evidence_v1
 ADD COLUMN issued_application_id uuid REFERENCES
 airlinerra_game.section9_game_permission_applications_v1(id) ON DELETE RESTRICT;
ALTER TABLE airlinerra_game.section9_route_operating_permission_evidence_v1
 ADD COLUMN issued_application_id uuid REFERENCES
 airlinerra_game.section9_game_permission_applications_v1(id) ON DELETE RESTRICT;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_permission_game_day_v1()
RETURNS date LANGUAGE sql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
 SELECT clock_row.confirmed_game_date
 FROM public.airlinerra_game_worlds w
 JOIN airlinerra_game.holding_world_clock_v1 clock_row
  ON clock_row.world_id=w.id
 WHERE w.id=1 AND w.state='active' AND
  w.opens_at IS NOT NULL AND w.opens_at<=clock_timestamp()
  AND clock_row.clock_source='authoritative_game_engine'
  AND clock_row.last_verified_at IS NOT NULL
  AND length(coalesce(clock_row.engine_proof_ref,''))>=12
  AND EXISTS(SELECT 1
   FROM airlinerra_game.section9_verified_game_tick_receipts_v1 receipt
   WHERE receipt.world_id=1
    AND receipt.game_date=clock_row.confirmed_game_date)
$f$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_verified_permission_game_day_v1()
 FROM PUBLIC,anon,authenticated;

-- Catalog legal-reference principle is never an actual grant. This
-- helper only selects WHICH game application policy should be required.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_required_game_traffic_permission_v1(
 p_operator text,p_origin text,p_destination text,
 p_service_type text,p_game_day date
) RETURNS text LANGUAGE plpgsql STABLE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE preview jsonb;
BEGIN
 IF p_service_type NOT IN ('passenger','cargo') OR p_game_day IS NULL
 THEN RETURN NULL;END IF;
 preview:=airlinerra_game.aviation_route_rights_preview_v1(
  p_operator,p_origin,p_destination,p_service_type,p_game_day);
 IF preview->>'operationally_authorized' IS DISTINCT FROM 'false' OR
  preview->>'status' IN ('invalid_input','forbidden','agreement_check_required')
 THEN RETURN NULL;END IF;
 RETURN CASE
  WHEN preview->>'reason'='domestic_airline_own_jurisdiction'
   THEN 'DOMESTIC_TRAFFIC'
  WHEN preview->>'reason'='eea_licenced_carrier_intra_market'
   THEN 'INTEGRATED_MARKET'
  WHEN preview->>'reason' IN ('foreign_domestic_cabotage_not_automatically_granted',
    'anz_designation_for_foreign_domestic') THEN 'CABOTAGE'
  WHEN preview->>'required_freedom' IN ('3','4')
   THEN 'THIRD_FOURTH_FREEDOM'
  WHEN preview->>'required_freedom'='7'
   THEN 'SEVENTH_FREEDOM'
  WHEN preview->>'reason' IN (
    'serbia_ecaa_third_fourth_freedom_principle',
    'us_open_skies_international_principle')
   AND (p_operator=p_origin OR p_operator=p_destination)
   THEN 'THIRD_FOURTH_FREEDOM'
  ELSE NULL END;
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_required_game_traffic_permission_v1(text,text,text,text,date)
 FROM PUBLIC,anon,authenticated;

-- Player identity must come from a private authenticated backend, never
-- an unverified player-supplied JSON property. The DB checks ownership.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_submit_game_permission_application_v1(
 p_player uuid,p_airline uuid,p_request_key uuid,p_permission_code text,
 p_origin text DEFAULT NULL,p_destination text DEFAULT NULL,
 p_service_type text DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE owner_row record;existing_row record;policy_row record;catalog_row record;
 day_now date;home_country text;origin_country text;destination_country text;
 expected_code text;scope text;review_fee numeric;review_days integer;
BEGIN
 IF p_player IS NULL OR p_airline IS NULL OR p_request_key IS NULL OR
  length(coalesce(p_permission_code,''))<3
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_PERMISSION_APPLICATION';END IF;
 SELECT a.*,home.country_iso INTO owner_row
 FROM airlinerra_game.airlines a
 LEFT JOIN airlinerra_game.airport_reference_profiles home
  ON home.world_id=a.world_id AND home.airport_key=a.home_airport_key
 WHERE a.id=p_airline AND a.world_id=1 FOR UPDATE OF a;
 IF NOT FOUND OR owner_row.owner_player_id IS DISTINCT FROM p_player
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_PERMISSION_APPLICATION_NOT_OWNED';END IF;
 SELECT * INTO existing_row
 FROM airlinerra_game.section9_game_permission_applications_v1 app
 WHERE app.airline_id=p_airline AND app.request_key=p_request_key;
 IF FOUND THEN
  IF existing_row.permission_code IS DISTINCT FROM p_permission_code OR
   existing_row.origin_airport_key IS DISTINCT FROM p_origin OR
   existing_row.destination_airport_key IS DISTINCT FROM p_destination OR
   existing_row.service_type IS DISTINCT FROM p_service_type
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_PERMISSION_REQUEST_KEY_CONFLICT';END IF;
  RETURN jsonb_build_object(
   'status','permission_application_replayed','applicationId',existing_row.id,
   'applicationStatus',existing_row.status,'replayed',true,
   'charged',false,'licenceIssued',false,'flightActivated',false,
   'ledgerPosted',false);END IF;
 day_now:=airlinerra_game.section9_verified_permission_game_day_v1();
 IF day_now IS NULL THEN RETURN jsonb_build_object(
   'status','blocked_unverified_world_or_game_day','submitted',false,
   'charged',false,'licenceIssued',false,'flightActivated',false,
   'ledgerPosted',false);END IF;
 SELECT * INTO catalog_row
 FROM airlinerra_game.business_permission_catalog_v1 c
 WHERE c.permission_code=p_permission_code FOR SHARE;
 SELECT * INTO policy_row
 FROM airlinerra_game.section9_game_permission_issuance_policy_v1 p
 WHERE p.permission_code=p_permission_code FOR SHARE;
 IF catalog_row.enabled_in_game IS DISTINCT FROM true OR
  catalog_row.game_fee_usd IS NULL OR catalog_row.game_fee_usd<=0 OR
  catalog_row.game_fee_usd>1000000 OR
  catalog_row.processing_game_days NOT BETWEEN 1 AND 90 OR
  policy_row.release_enabled IS DISTINCT FROM true OR
  policy_row.released_at IS NULL OR
  policy_row.validity_game_days NOT BETWEEN 35 AND 1095
 THEN RETURN jsonb_build_object(
  'status','blocked_game_permission_issuance_disabled',
  'permissionCode',p_permission_code,'submitted',false,
  'charged',false,'licenceIssued',false,'flightActivated',false,
  'ledgerPosted',false);END IF;
 IF owner_row.country_iso IS NULL OR
  owner_row.country_iso !~ '^[A-Z]{2}$' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_AIRLINE_HOME_JURISDICTION_MISSING';END IF;
 home_country:=owner_row.country_iso;
 IF p_permission_code='AIR_OPERATOR_CERTIFICATE' THEN
  IF p_origin IS NOT NULL OR p_destination IS NOT NULL
   OR p_service_type IS NOT NULL OR catalog_row.category<>'airline'
   OR catalog_row.holder_scope<>'operating_company'
  THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_OPERATOR_LICENSE_SCOPE_INVALID';END IF;
  scope:='operator:'||home_country;
 ELSE
  IF catalog_row.category<>'traffic_rights' OR
   catalog_row.holder_scope<>'route' OR
   p_origin IS NULL OR p_destination IS NULL OR
   p_origin=p_destination OR
   p_service_type NOT IN('passenger','cargo')
  THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_ROUTE_PERMISSION_SCOPE_INVALID';END IF;
  SELECT country_iso INTO origin_country
  FROM airlinerra_game.airport_reference_profiles
  WHERE world_id=1 AND airport_key=p_origin;
  SELECT country_iso INTO destination_country
  FROM airlinerra_game.airport_reference_profiles
  WHERE world_id=1 AND airport_key=p_destination;
  expected_code:=airlinerra_game.section9_required_game_traffic_permission_v1(
   home_country,origin_country,destination_country,p_service_type,day_now);
  IF expected_code IS DISTINCT FROM p_permission_code
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_ROUTE_GAME_PERMISSION_POLICY_NOT_SUPPORTED';END IF;
  IF NOT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_game_permission_applications_v1 app
   JOIN airlinerra_game.section9_operator_licence_evidence_v1 evidence
    ON evidence.issued_application_id=app.id AND evidence.airline_id=app.airline_id
   WHERE app.airline_id=p_airline
    AND app.permission_code='AIR_OPERATOR_CERTIFICATE'
    AND app.status='issued'
    AND evidence.evidence_status='verified'
    AND evidence.jurisdiction_iso2=home_country
    AND evidence.valid_from<=day_now
    AND evidence.valid_until>=day_now+28)
  THEN RETURN jsonb_build_object(
   'status','blocked_operator_licence_required','submitted',false,
   'charged',false,'licenceIssued',false,'flightActivated',false,
   'ledgerPosted',false);END IF;
  scope:='route:'||p_origin||':'||p_destination||':'||p_service_type;
 END IF;

 IF EXISTS(
  SELECT 1 FROM airlinerra_game.section9_game_permission_applications_v1 app
  WHERE app.airline_id=p_airline AND app.scope_key=scope
   AND app.status='issued'
   AND app.valid_until_game_date>=day_now+28)
 THEN RETURN jsonb_build_object(
  'status','blocked_game_permission_already_valid',
  'submitted',false,'charged',false,'licenceIssued',false,
  'flightActivated',false,'ledgerPosted',false);END IF;
 IF EXISTS(
  SELECT 1 FROM airlinerra_game.section9_game_permission_applications_v1 app
  WHERE app.airline_id=p_airline AND app.scope_key=scope
   AND app.status='submitted')
 THEN RETURN jsonb_build_object(
  'status','blocked_game_permission_application_pending',
  'submitted',false,'charged',false,'licenceIssued',false,
  'flightActivated',false,'ledgerPosted',false);END IF;
 INSERT INTO airlinerra_game.section9_game_permission_applications_v1(
  airline_id,applicant_player_id,request_key,permission_code,scope_key,
  jurisdiction_iso2,origin_airport_key,destination_airport_key,service_type,
  applied_game_date,due_game_date,policy_revision,
  fee_usd,validity_game_days)
 VALUES(p_airline,p_player,p_request_key,p_permission_code,scope,
  CASE WHEN p_permission_code='AIR_OPERATOR_CERTIFICATE'
   THEN home_country ELSE NULL END,
  p_origin,p_destination,p_service_type,
  day_now,day_now+catalog_row.processing_game_days,
  policy_row.policy_revision,catalog_row.game_fee_usd,
  policy_row.validity_game_days)
 RETURNING id,due_game_date,fee_usd INTO existing_row;
 RETURN jsonb_build_object(
  'status','permission_application_submitted',
  'applicationId',existing_row.id,'dueGameDate',existing_row.due_game_date,
  'feeAtIssuanceUsd',existing_row.fee_usd,'submitted',true,
  'charged',false,'licenceIssued',false,'flightActivated',false,
  'ledgerPosted',false);
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_submit_game_permission_application_v1(
 uuid,uuid,uuid,text,text,text,text)
 FROM PUBLIC,anon,authenticated;
