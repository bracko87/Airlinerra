-- Fifth Freedom never substitutes for a separately valid home-to-first-foreign
-- (third/fourth freedom) route permission. The grant must be paid, issued,
-- matched to its route and service, and remain valid through processing.
DO $patch$
DECLARE fn text; marker text;
BEGIN
 SELECT pg_get_functiondef(p.oid) INTO fn
 FROM pg_proc p JOIN pg_namespace n ON n.oid=p.pronamespace
 WHERE n.nspname='airlinerra_game' AND p.proname='licence6_fifth_readiness_v1';
 marker:='IF h IS NOT NULL AND b IS NOT NULL AND c IS NOT NULL AND d IS NOT NULL THEN';
 IF fn IS NULL OR strpos(fn,marker)=0
 THEN RAISE EXCEPTION 'LICENCE6_EXPECTED_PREVIEW_ANCHOR_MISSING';END IF;
 fn:=replace(fn,marker,
 $gate$
 IF d IS NOT NULL AND NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_route_operating_permission_evidence_v1 prior
  JOIN airlinerra_game.section9_game_permission_applications_v1 app
    ON app.id=prior.issued_application_id
     AND app.airline_id=prior.airline_id
     AND app.origin_airport_key=prior.origin_airport_key
     AND app.destination_airport_key=prior.destination_airport_key
     AND app.service_type=prior.service_type
     AND app.status='issued'
     AND app.permission_code IN ('THIRD_FOURTH_FREEDOM','INTEGRATED_MARKET')
     AND app.ledger_entry_id IS NOT NULL
     AND app.issued_game_date=prior.valid_from
     AND app.valid_until_game_date=prior.valid_until
  WHERE prior.world_id=1 AND prior.airline_id=p_airline
    AND prior.origin_airport_key=p_home_airport
    AND prior.destination_airport_key=p_foreign_stop
    AND prior.service_type=p_service_type
    AND prior.evidence_status='verified'
    AND prior.reviewed_at IS NOT NULL
    AND prior.reviewed_at<=clock_timestamp()
    AND prior.valid_from<=d AND prior.valid_until>=d+7
    AND prior.evidence_reference='game-permission-issued-v1-'||app.id::text
 )
 THEN issues:=array_append(issues,'VERIFIED_HOME_TO_FOREIGN_TRAFFIC_RIGHT_REQUIRED');END IF;
 IF h IS NOT NULL AND b IS NOT NULL AND c IS NOT NULL AND d IS NOT NULL THEN
 $gate$);
 EXECUTE fn;
END $patch$;