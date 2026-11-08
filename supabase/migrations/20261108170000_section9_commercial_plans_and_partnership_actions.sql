-- Section 9: secure airline-commercial planning and bilateral interlining.
-- All player actions require a trusted owner ID from the authenticated server.
-- No real tickets, paid marketing, or ledger postings are created by this migration.

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_route_commercial_plans_v1 (
 schedule_id uuid PRIMARY KEY REFERENCES airlinerra_game.airline_flight_schedule_drafts_v1(id) ON DELETE CASCADE,
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 economy_fare_usd numeric(10,2) NOT NULL CHECK(economy_fare_usd BETWEEN 1 AND 100000),
 cargo_rate_usd_per_tonne numeric(12,2) NOT NULL DEFAULT 0
  CHECK(cargo_rate_usd_per_tonne BETWEEN 0 AND 1000000),
 marketing_budget_usd_per_day numeric(10,2) NOT NULL DEFAULT 0
  CHECK(marketing_budget_usd_per_day BETWEEN 0 AND 100000),
 marketing_status text NOT NULL DEFAULT 'planned'
  CHECK(marketing_status='planned'),
 version integer NOT NULL DEFAULT 1 CHECK(version>=1),
 updated_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE airlinerra_game.section9_route_commercial_plans_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_route_commercial_plans_v1 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_route_commercial_plan_airline_idx
 ON airlinerra_game.section9_route_commercial_plans_v1(airline_id,schedule_id);
COMMENT ON TABLE airlinerra_game.section9_route_commercial_plans_v1 IS
 'Owner editable fare/cargo/marketing budget PLANS for protected drafts; no bookings, no marketing charge or unverified demand boost.';

CREATE OR REPLACE FUNCTION airlinerra_game.section9_save_owned_commercial_plan_v1(
 p_player_id uuid,p_airline_id uuid,p_schedule_id uuid,
 p_economy_fare_usd numeric,p_cargo_rate_usd numeric,
 p_marketing_budget_usd numeric
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE row record;
BEGIN
 IF p_economy_fare_usd IS NULL OR p_economy_fare_usd<1 OR p_economy_fare_usd>100000
  OR p_cargo_rate_usd IS NULL OR p_cargo_rate_usd<0 OR p_cargo_rate_usd>1000000
  OR p_marketing_budget_usd IS NULL OR p_marketing_budget_usd<0 OR p_marketing_budget_usd>100000
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_COMMERCIAL_PLAN';END IF;
 PERFORM 1 FROM airlinerra_game.airlines a
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 d ON d.airline_id=a.id
 WHERE a.id=p_airline_id AND a.world_id=1 AND a.owner_player_id=p_player_id
  AND d.id=p_schedule_id AND d.status='draft';
 IF NOT FOUND THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_COMMERCIAL_PLAN_NOT_OWNED';
 END IF;
 INSERT INTO airlinerra_game.section9_route_commercial_plans_v1(
  schedule_id,airline_id,economy_fare_usd,cargo_rate_usd_per_tonne,
  marketing_budget_usd_per_day)
 VALUES(p_schedule_id,p_airline_id,p_economy_fare_usd,p_cargo_rate_usd,
  p_marketing_budget_usd)
 ON CONFLICT(schedule_id) DO UPDATE SET
  economy_fare_usd=excluded.economy_fare_usd,
  cargo_rate_usd_per_tonne=excluded.cargo_rate_usd_per_tonne,
  marketing_budget_usd_per_day=excluded.marketing_budget_usd_per_day,
  version=airlinerra_game.section9_route_commercial_plans_v1.version+1,
  updated_at=now()
 WHERE airlinerra_game.section9_route_commercial_plans_v1.airline_id=p_airline_id
 RETURNING * INTO row;
 IF row IS NULL THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_COMMERCIAL_PLAN_NOT_OWNED';END IF;
 RETURN jsonb_build_object('scheduleId',row.schedule_id,
  'economyFareUsd',row.economy_fare_usd,
  'cargoRateUsdPerTonne',row.cargo_rate_usd_per_tonne,
  'marketingBudgetUsdPerDay',row.marketing_budget_usd_per_day,
  'marketingStatus','planned','version',row.version,
  'paidMarketingActive',false,'bookingsEnabled',false);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_save_owned_commercial_plan_v1(
 uuid,uuid,uuid,numeric,numeric,numeric) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_get_owned_commercial_plan_v1(
 p_player_id uuid,p_airline_id uuid,p_schedule_id uuid
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE v jsonb;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines a
  JOIN airlinerra_game.airline_flight_schedule_drafts_v1 d ON d.airline_id=a.id
  WHERE a.id=p_airline_id AND a.owner_player_id=p_player_id AND a.world_id=1
   AND d.id=p_schedule_id)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_COMMERCIAL_PLAN_NOT_OWNED';END IF;
 SELECT jsonb_build_object('scheduleId',p_schedule_id,'economyFareUsd',x.economy_fare_usd,
  'cargoRateUsdPerTonne',x.cargo_rate_usd_per_tonne,
  'marketingBudgetUsdPerDay',x.marketing_budget_usd_per_day,
  'marketingStatus',x.marketing_status,'version',x.version,
  'paidMarketingActive',false,'bookingsEnabled',false)
 INTO v FROM airlinerra_game.section9_route_commercial_plans_v1 x
 WHERE x.schedule_id=p_schedule_id AND x.airline_id=p_airline_id;
 RETURN coalesce(v,jsonb_build_object('scheduleId',p_schedule_id,'economyFareUsd',null,
  'cargoRateUsdPerTonne',null,'marketingBudgetUsdPerDay',null,
  'marketingStatus','not_planned','version',0,'paidMarketingActive',false,
  'bookingsEnabled',false));
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_get_owned_commercial_plan_v1(
 uuid,uuid,uuid) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_manage_partnership_v1(
 p_player_id uuid,p_airline_id uuid,p_action text,
 p_other_airline_code text DEFAULT NULL,p_agreement_id bigint DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE other_id uuid; left_id uuid;right_id uuid;found_id bigint;
 ag airlinerra_game.section9_interline_agreements_v1%ROWTYPE; now_at timestamptz:=clock_timestamp();
 partner_count integer;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines a
  WHERE a.id=p_airline_id AND a.owner_player_id=p_player_id AND a.world_id=1)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_AIRLINE_NOT_OWNED';END IF;
 IF p_action='propose' THEN
  IF p_agreement_id IS NOT NULL OR p_other_airline_code IS NULL
   OR length(trim(p_other_airline_code)) NOT BETWEEN 2 AND 3
   OR upper(trim(p_other_airline_code)) !~ '^[A-Z0-9]{2,3}$'
  THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_PARTNER_CODE';END IF;
  SELECT count(*),min(a.id::text)::uuid INTO partner_count,other_id
  FROM airlinerra_game.airlines a WHERE a.world_id=1 AND a.id<>p_airline_id
   AND (a.iata_code=upper(trim(p_other_airline_code))
    OR a.icao_code=upper(trim(p_other_airline_code)));
  IF partner_count<>1 THEN
   RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='SECTION9_PARTNER_NOT_FOUND_OR_AMBIGUOUS';END IF;
  left_id:=least(p_airline_id,other_id);
  right_id:=greatest(p_airline_id,other_id);
  INSERT INTO airlinerra_game.section9_interline_agreements_v1(
    world_id,left_airline_id,right_airline_id,agreement_status,
    left_approved_at,right_approved_at)
  VALUES(1,left_id,right_id,'proposed',
   CASE WHEN p_airline_id=left_id THEN now_at END,
   CASE WHEN p_airline_id=right_id THEN now_at END)
  ON CONFLICT(world_id,left_airline_id,right_airline_id) DO UPDATE
   SET left_approved_at=
     CASE WHEN airlinerra_game.section9_interline_agreements_v1.agreement_status='terminated'
       THEN excluded.left_approved_at
       ELSE coalesce(airlinerra_game.section9_interline_agreements_v1.left_approved_at,
                     excluded.left_approved_at) END,
       right_approved_at=
     CASE WHEN airlinerra_game.section9_interline_agreements_v1.agreement_status='terminated'
       THEN excluded.right_approved_at
       ELSE coalesce(airlinerra_game.section9_interline_agreements_v1.right_approved_at,
                     excluded.right_approved_at) END,
       agreement_status=
     CASE WHEN airlinerra_game.section9_interline_agreements_v1.agreement_status='active'
       THEN 'active' ELSE 'proposed' END,
       valid_from=
     CASE WHEN airlinerra_game.section9_interline_agreements_v1.agreement_status='active'
       THEN airlinerra_game.section9_interline_agreements_v1.valid_from ELSE NULL END,
       valid_until=NULL
  RETURNING id INTO found_id;
 ELSE
  IF p_other_airline_code IS NOT NULL OR p_agreement_id IS NULL
   OR p_action NOT IN('approve','terminate')
  THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_PARTNER_ACTION';END IF;
  SELECT * INTO ag FROM airlinerra_game.section9_interline_agreements_v1
   WHERE id=p_agreement_id AND world_id=1
    AND p_airline_id IN(left_airline_id,right_airline_id)
   FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_PARTNERSHIP_NOT_OWNED';END IF;
  IF p_action='terminate' THEN
   UPDATE airlinerra_game.section9_interline_agreements_v1
    SET agreement_status='terminated',
     valid_until=CASE WHEN valid_from IS NOT NULL
       THEN greatest(now_at,valid_from+interval '1 microsecond') ELSE NULL END
    WHERE id=ag.id;
  ELSIF ag.agreement_status='terminated' THEN
   RAISE EXCEPTION USING ERRCODE='P0001',MESSAGE='SECTION9_TERMINATED_PROPOSAL_REQUIRES_RESTART';
  ELSE
   UPDATE airlinerra_game.section9_interline_agreements_v1 SET
    left_approved_at=CASE WHEN p_airline_id=left_airline_id THEN
      coalesce(left_approved_at,now_at) ELSE left_approved_at END,
    right_approved_at=CASE WHEN p_airline_id=right_airline_id THEN
      coalesce(right_approved_at,now_at) ELSE right_approved_at END
    WHERE id=ag.id;
  END IF;
  found_id:=ag.id;
 END IF;
 UPDATE airlinerra_game.section9_interline_agreements_v1
 SET agreement_status='active',valid_from=coalesce(valid_from,now_at),valid_until=NULL
 WHERE id=found_id AND agreement_status='proposed'
  AND left_approved_at IS NOT NULL AND right_approved_at IS NOT NULL;
 SELECT * INTO ag FROM airlinerra_game.section9_interline_agreements_v1
  WHERE id=found_id;
 RETURN jsonb_build_object('agreementId',ag.id,'status',ag.agreement_status,
  'myApproved',CASE WHEN p_airline_id=ag.left_airline_id
    THEN ag.left_approved_at IS NOT NULL ELSE ag.right_approved_at IS NOT NULL END,
  'otherApproved',CASE WHEN p_airline_id=ag.left_airline_id
    THEN ag.right_approved_at IS NOT NULL ELSE ag.left_approved_at IS NOT NULL END,
  'bookingsEnabled',false,'validFrom',ag.valid_from);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_manage_partnership_v1(
 uuid,uuid,text,text,bigint) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_list_owned_partnerships_v1(
 p_player_id uuid,p_airline_id uuid
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE v jsonb;
BEGIN
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines
  WHERE id=p_airline_id AND owner_player_id=p_player_id AND world_id=1)
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_AIRLINE_NOT_OWNED';END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'agreementId',ag.id,'status',ag.agreement_status,
   'otherAirlineId',other.id,'otherAirlineName',other.name,
   'otherAirlineCode',coalesce(other.iata_code,other.icao_code),
   'myApproved',CASE WHEN ag.left_airline_id=p_airline_id
       THEN ag.left_approved_at IS NOT NULL ELSE ag.right_approved_at IS NOT NULL END,
   'otherApproved',CASE WHEN ag.left_airline_id=p_airline_id
       THEN ag.right_approved_at IS NOT NULL ELSE ag.left_approved_at IS NOT NULL END,
   'canApprove',ag.agreement_status='proposed' AND
      CASE WHEN ag.left_airline_id=p_airline_id
       THEN ag.left_approved_at IS NULL ELSE ag.right_approved_at IS NULL END,
   'validFrom',ag.valid_from)
   ORDER BY other.name,ag.id),'[]'::jsonb) INTO v
 FROM airlinerra_game.section9_interline_agreements_v1 ag
 JOIN airlinerra_game.airlines other
   ON other.id=CASE WHEN ag.left_airline_id=p_airline_id
      THEN ag.right_airline_id ELSE ag.left_airline_id END
 WHERE ag.world_id=1 AND p_airline_id IN(ag.left_airline_id,ag.right_airline_id);
 RETURN jsonb_build_object('agreements',v,
  'status','owner_verified','bookingAllowed',false);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_list_owned_partnerships_v1(uuid,uuid)
 FROM PUBLIC,anon,authenticated;
