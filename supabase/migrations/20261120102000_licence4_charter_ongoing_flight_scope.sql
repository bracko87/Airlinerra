-- Charter/VIP Licence 4: validate all ongoing operating conditions at flight-scope check.
-- Existing issued licences stay recorded; flight use suspends automatically
-- when company, AOC, fleet, payment provenance or release is invalid.
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
REVOKE ALL ON FUNCTION airlinerra_game.licence4_charter_flight_scope_v1(uuid)
 FROM PUBLIC,anon,authenticated,service_role;