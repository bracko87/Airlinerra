-- Section 9 Phase 1: airport transfer policy, complete game seasonality coverage,
-- and a source-preserving on-demand origin/destination market estimate.
-- No real flights or passengers are activated or allocated by this migration.
-- Keep Section 7 priority budgets authoritative; do not rewrite its 79,255 links.

INSERT INTO airlinerra_game.airport_seasonal_demand_profiles(
 world_id,airport_key,profile,jan_pct,feb_pct,mar_pct,apr_pct,
 may_pct,jun_pct,jul_pct,aug_pct,sep_pct,oct_pct,nov_pct,dec_pct,verified)
SELECT a.world_id,a.airport_key,'neutral_unverified_game_default_v1',
 100,100,100,100,100,100,100,100,100,100,100,100,false
FROM airlinerra_game.approved_game_airports a
LEFT JOIN airlinerra_game.airport_seasonal_demand_profiles s
 ON s.world_id=a.world_id AND s.airport_key=a.airport_key
WHERE a.world_id=1 AND s.airport_key IS NULL
ON CONFLICT(world_id,airport_key) DO NOTHING;

CREATE OR REPLACE VIEW airlinerra_game.section9_airport_transfer_policy_v1
WITH (security_invoker=true) AS
 SELECT p.world_id,p.airport_key,
  COALESCE(p.approved_category,p.provisional_category) AS airport_category,
  CASE COALESCE(p.approved_category,p.provisional_category)
    WHEN 'Local' THEN 25 WHEN 'Regional' THEN 30
    WHEN 'Medium' THEN 40 WHEN 'Large' THEN 45
    WHEN 'Major Hub' THEN 55 WHEN 'Mega Hub' THEN 65
    ELSE NULL END::integer AS minimum_transfer_minutes,
  720::integer AS maximum_transfer_minutes,
  f.airport_background,f.background_verified,
  s.profile AS seasonal_profile,s.verified AS seasonal_source_verified,
  'game_category_base_v1'::text AS transfer_rule_source
 FROM airlinerra_game.airport_reference_profiles p
 JOIN airlinerra_game.approved_game_airports a
  ON a.world_id=p.world_id AND a.airport_key=p.airport_key
 JOIN airlinerra_game.airport_game_fees f
  ON f.world_id=p.world_id AND f.airport_key=p.airport_key
 JOIN airlinerra_game.airport_seasonal_demand_profiles s
  ON s.world_id=p.world_id AND s.airport_key=p.airport_key;
REVOKE ALL ON airlinerra_game.section9_airport_transfer_policy_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON VIEW airlinerra_game.section9_airport_transfer_policy_v1 IS
 'Airlinerra game minimum connection times: Local25, Regional30, Medium40, Large45, MajorHub55, MegaHub65; max 720min. Category changes are reflected automatically. Not official airport MCT.';

-- Improve origin-scoped Section 7 lookups for large player networks.
CREATE INDEX IF NOT EXISTS section9_priority_origin_model_lookup_v1_idx
 ON airlinerra_game.section7_airport_destination_priorities
 (world_id,origin_airport_key,model_version,destination_airport_key);

CREATE OR REPLACE FUNCTION airlinerra_game.section9_route_market_preview_v1(
 p_world_id smallint,p_origin_airport_key text,p_destination_airport_key text,
 p_month smallint
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $function$
DECLARE result jsonb;
BEGIN
 IF p_world_id<>1 OR p_month NOT BETWEEN 1 AND 12
   OR p_origin_airport_key IS NULL OR p_destination_airport_key IS NULL
   OR p_origin_airport_key=p_destination_airport_key
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_MARKET_REQUEST'; END IF;
 WITH endpoints AS (
  SELECT o.world_id,o.airport_key origin_key,d.airport_key destination_key,
   coalesce(o.gameplay_avg_daily_outbound_passengers,o.avg_daily_outbound_passengers,0)::numeric as outbound_pax,
   coalesce(o.avg_daily_outbound_cargo_tonnes,0)::numeric as outbound_cargo_tonnes,
   CASE p_month WHEN 1 THEN os.jan_pct WHEN 2 THEN os.feb_pct WHEN 3 THEN os.mar_pct WHEN 4 THEN os.apr_pct WHEN 5 THEN os.may_pct WHEN 6 THEN os.jun_pct WHEN 7 THEN os.jul_pct WHEN 8 THEN os.aug_pct WHEN 9 THEN os.sep_pct WHEN 10 THEN os.oct_pct WHEN 11 THEN os.nov_pct WHEN 12 THEN os.dec_pct END::numeric AS origin_season_index,
   ds.profile destination_season_profile,CASE p_month WHEN 1 THEN ds.jan_pct WHEN 2 THEN ds.feb_pct WHEN 3 THEN ds.mar_pct WHEN 4 THEN ds.apr_pct WHEN 5 THEN ds.may_pct WHEN 6 THEN ds.jun_pct WHEN 7 THEN ds.jul_pct WHEN 8 THEN ds.aug_pct WHEN 9 THEN ds.sep_pct WHEN 10 THEN ds.oct_pct WHEN 11 THEN ds.nov_pct WHEN 12 THEN ds.dec_pct END::numeric AS destination_season_index,
   fg.airport_background destination_background,fg.background_verified,
   dp.minimum_transfer_minutes destination_minimum_connection_minutes
  FROM airlinerra_game.airport_daily_traffic_pool_baselines o
  JOIN airlinerra_game.airport_daily_traffic_pool_baselines d
   ON d.world_id=o.world_id AND d.airport_key=p_destination_airport_key
  JOIN airlinerra_game.airport_seasonal_demand_profiles os
   ON os.world_id=o.world_id AND os.airport_key=o.airport_key
  JOIN airlinerra_game.airport_seasonal_demand_profiles ds
   ON ds.world_id=d.world_id AND ds.airport_key=d.airport_key
  JOIN airlinerra_game.airport_game_fees fg
   ON fg.world_id=d.world_id AND fg.airport_key=d.airport_key
  JOIN airlinerra_game.section9_airport_transfer_policy_v1 dp
   ON dp.world_id=d.world_id AND dp.airport_key=d.airport_key
  WHERE o.world_id=p_world_id AND o.airport_key=p_origin_airport_key
 ), demand_priors AS (
  SELECT r.destination_airport_key,
   greatest(0,coalesce(r.current_modelled_priority_passengers_day,0))::numeric as base_passengers,
   (CASE p_month WHEN 1 THEN dst.jan_pct WHEN 2 THEN dst.feb_pct WHEN 3 THEN dst.mar_pct WHEN 4 THEN dst.apr_pct WHEN 5 THEN dst.may_pct WHEN 6 THEN dst.jun_pct WHEN 7 THEN dst.jul_pct WHEN 8 THEN dst.aug_pct WHEN 9 THEN dst.sep_pct WHEN 10 THEN dst.oct_pct WHEN 11 THEN dst.nov_pct WHEN 12 THEN dst.dec_pct END::numeric/100) AS season_factor
  FROM airlinerra_game.section7_current_destination_priorities r
  JOIN airlinerra_game.airport_seasonal_demand_profiles dst
   ON dst.world_id=r.world_id AND dst.airport_key=r.destination_airport_key
  WHERE r.world_id=p_world_id AND r.origin_airport_key=p_origin_airport_key
 ), totals AS (
  SELECT COUNT(*)::numeric as priority_destination_count,
   coalesce(sum(base_passengers),0)::numeric as raw_priority_weight,
   coalesce(sum(base_passengers*season_factor),0)::numeric as seasonal_priority_weight,
   coalesce(sum(base_passengers*season_factor)
     FILTER(WHERE destination_airport_key=p_destination_airport_key),0)::numeric as target_priority_season_weight,
   coalesce(sum(base_passengers)
     FILTER(WHERE destination_airport_key=p_destination_airport_key),0)::numeric as target_priority_raw_weight,
   count(*) FILTER(WHERE destination_airport_key=p_destination_airport_key)>0 as is_priority
  FROM demand_priors
 )
 SELECT jsonb_build_object(
  'model','section9_monthly_market_preview_v1','worldId',p_world_id,
  'originAirportKey',p_origin_airport_key,'destinationAirportKey',p_destination_airport_key,
  'month',p_month,'destinationBackground',e.destination_background,
  'backgroundVerified',e.background_verified,
  'destinationSeasonProfile',e.destination_season_profile,
  'destinationSeasonIndex',e.destination_season_index,
  'originSeasonIndex',e.origin_season_index,
  'isPriorityDestination',t.is_priority,
  'originPassengersPerDay',e.outbound_pax,
  'priorityDestinations',t.priority_destination_count,
  'directPassengersPerDay',
    round(greatest(0,e.outbound_pax*e.origin_season_index/100) *
      CASE WHEN t.is_priority THEN
        CASE WHEN t.seasonal_priority_weight>0 THEN
         0.8 * t.target_priority_season_weight/t.seasonal_priority_weight
        ELSE 0 END
      ELSE 0.2/greatest(1,3140-t.priority_destination_count) END,2),
  'cargoTonnesPerDay',
    round(greatest(0,e.outbound_cargo_tonnes) *
      CASE WHEN t.is_priority THEN
        CASE WHEN t.raw_priority_weight>0 THEN
         0.8 * t.target_priority_raw_weight/t.raw_priority_weight
        ELSE 0 END
      ELSE 0.2/greatest(1,3140-t.priority_destination_count) END,3),
  'minimumTransferMinutesAtDestination',e.destination_minimum_connection_minutes,
  'maximumTransferMinutes',720,
  'passengerBasis','Section 7 origin pool and current priority weights; destination seasonal weights normalized within the original 80% budget',
  'cargoBasis','Provisional Section 7 destination-weight distribution of origin cargo pool, not independently verified route cargo',
  'includesConnections',false,'includesAirlineCompetition',false,
  'flightActivationAllowed',false
 ) INTO result
 FROM endpoints e CROSS JOIN totals t;
 IF result IS NULL THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_AIRPORT_DATA_UNAVAILABLE';
 END IF;
 RETURN result;
END $function$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_route_market_preview_v1(
 smallint,text,text,smallint) FROM PUBLIC,anon,authenticated;
