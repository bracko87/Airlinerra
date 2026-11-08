-- Section 9 operating-flight handoff and vectorized route-market demand.
-- These capacities are NOT provided by the player. Only the trusted future
-- activation service may register them after Section 5 readiness and actual
-- seat/cargo configuration verification. Drafts never qualify.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_verified_schedule_capacity_v1(
 schedule_id uuid PRIMARY KEY REFERENCES airlinerra_game.airline_flight_schedule_drafts_v1(id) ON DELETE CASCADE,
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 schedule_version integer NOT NULL CHECK(schedule_version>=1),
 passenger_seats integer NOT NULL CHECK(passenger_seats BETWEEN 0 AND 1000),
 cargo_capacity_tonnes numeric(10,3) NOT NULL CHECK(cargo_capacity_tonnes BETWEEN 0 AND 1000),
 verification_source text NOT NULL CHECK(length(verification_source) BETWEEN 6 AND 120),
 verified_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE airlinerra_game.section9_verified_schedule_capacity_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_verified_schedule_capacity_v1 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.section9_verified_schedule_capacity_v1 IS
 'Reserved for a future authoritative flight-activation/seat-layout verifier. A schedule DRAFT is never eligible for live demand allocation. Player request handlers have NO capacity-registration action.';

CREATE OR REPLACE FUNCTION airlinerra_game.section9_register_verified_schedule_capacity_v1(
 p_schedule_id uuid,p_airline_id uuid,p_passenger_seats integer,
 p_cargo_capacity_tonnes numeric,p_verification_source text
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE s record; c record; result jsonb;
BEGIN
 SELECT d.id,d.airline_id,d.version,d.status,d.operationally_verified,
  d.configuration_id INTO s
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 WHERE d.id=p_schedule_id AND d.airline_id=p_airline_id FOR UPDATE;
 IF NOT FOUND OR s.status<>'active' OR s.operationally_verified IS DISTINCT FROM true THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_SCHEDULE_NOT_ACTIVATED';
 END IF;
 SELECT maximum_passenger_seats,maximum_cargo_payload_kg INTO c
 FROM airlinerra.aircraft_configurations WHERE id=s.configuration_id;
 IF c IS NULL OR p_passenger_seats IS NULL OR p_passenger_seats<0
   OR p_passenger_seats>least(1000,coalesce(c.maximum_passenger_seats,0))
   OR p_cargo_capacity_tonnes IS NULL OR p_cargo_capacity_tonnes<0
   OR p_cargo_capacity_tonnes>least(1000,coalesce(c.maximum_cargo_payload_kg,0)/1000)
   OR p_verification_source IS NULL OR length(p_verification_source) NOT BETWEEN 6 AND 120
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_CAPACITY_PROOF'; END IF;
 INSERT INTO airlinerra_game.section9_verified_schedule_capacity_v1(
  schedule_id,airline_id,schedule_version,passenger_seats,
  cargo_capacity_tonnes,verification_source)
 VALUES(s.id,s.airline_id,s.version,p_passenger_seats,
  p_cargo_capacity_tonnes,p_verification_source)
 ON CONFLICT(schedule_id) DO UPDATE SET
  airline_id=excluded.airline_id,schedule_version=excluded.schedule_version,
  passenger_seats=excluded.passenger_seats,
  cargo_capacity_tonnes=excluded.cargo_capacity_tonnes,
  verification_source=excluded.verification_source,verified_at=now();
 RETURN jsonb_build_object('verified',true,'scheduleId',s.id,
  'scheduleVersion',s.version,'source',p_verification_source);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_register_verified_schedule_capacity_v1(
 uuid,uuid,integer,numeric,text) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_daily_flight_page_v1(
 p_world_id smallint,p_local_date date,p_limit integer DEFAULT 1000,
 p_after_schedule_id uuid DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE result jsonb;
BEGIN
 IF p_world_id<>1 OR p_local_date IS NULL OR p_limit NOT BETWEEN 1 AND 2000
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_FLIGHT_PAGE';END IF;
 SELECT coalesce(jsonb_agg(jsonb_build_object(
  'id',s.id::text||':'||p_local_date::text,'scheduleId',s.id,
  'airlineId',s.airline_id,'origin',s.origin_airport_key,
  'destination',s.destination_airport_key,'status','operational_verified',
  'marketDate',p_local_date,'departureUtc',s.departure_utc,
  'arrivalUtc',s.departure_utc+s.duration,
  'passengerSeats',s.passenger_seats,'cargoTonnes',s.cargo_tonnes,
  'fareUsd',s.economy_fare_usd,
  'cargoRateUsd',s.cargo_rate_usd_per_tonne,
  'marketingBoost',0,'marketingAuthorized',false,
  'weeklyDepartures',s.weekly_departures,
  'capacitySource','verified_activated_schedule',
  'commercialPlanVersion',s.commercial_version)
  ORDER BY s.id),'[]'::jsonb) INTO result
 FROM (
  SELECT d.id,d.airline_id,d.origin_airport_key,d.destination_airport_key,
   cap.passenger_seats,cap.cargo_capacity_tonnes AS cargo_tonnes,
   plan.economy_fare_usd,plan.cargo_rate_usd_per_tonne,
   plan.version AS commercial_version,
   jsonb_array_length(d.weekly_schedule) AS weekly_departures,
   d.reference_arrival_utc-d.reference_departure_utc AS duration,
   ((p_local_date::timestamp+(j."time")::time::interval)
     AT TIME ZONE tz.timezone_iana) AS departure_utc
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
  JOIN airlinerra_game.section9_verified_schedule_capacity_v1 cap
   ON cap.schedule_id=d.id AND cap.airline_id=d.airline_id
    AND cap.schedule_version=d.version
  JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
   ON plan.schedule_id=d.id AND plan.airline_id=d.airline_id
  JOIN airlinerra_game.airport_reference_profiles tz
   ON tz.world_id=d.world_id AND tz.airport_key=d.origin_airport_key
  CROSS JOIN LATERAL jsonb_to_recordset(d.weekly_schedule) AS j(day integer,"time" text)
  WHERE d.world_id=p_world_id AND d.status='active' AND d.operationally_verified=true
   AND d.id>coalesce(p_after_schedule_id,'00000000-0000-0000-0000-000000000000'::uuid)
   AND j.day=extract(isodow from p_local_date)::int-1
   AND tz.timezone_iana IS NOT NULL
  ORDER BY d.id LIMIT p_limit
 ) s;
 RETURN result;
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_verified_daily_flight_page_v1(
 smallint,date,integer,uuid) FROM PUBLIC,anon,authenticated;

-- Batches are server-only. Use only real origin/destination pairs in the
-- verified network (direct and qualifying one-connection itineraries).
-- Aggregation is once per origin in the batch, not one query per airline.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_market_batch_v1(
 p_world_id smallint,p_month smallint,p_pairs jsonb
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE result jsonb; n integer;
BEGIN
 IF p_world_id<>1 OR p_month NOT BETWEEN 1 AND 12
   OR p_pairs IS NULL OR jsonb_typeof(p_pairs)<>'array'
   OR jsonb_array_length(p_pairs)>1000
 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_MARKET_BATCH';END IF;
 SELECT count(*) INTO n FROM jsonb_to_recordset(p_pairs)
  AS x(origin text,destination text)
 WHERE origin IS NULL OR destination IS NULL OR origin=destination
  OR length(origin)>120 OR length(destination)>120;
 IF n>0 THEN RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INVALID_MARKET_PAIR';END IF;
 WITH pairs AS (
  SELECT DISTINCT x.origin,x.destination
  FROM jsonb_to_recordset(p_pairs) AS x(origin text,destination text)
 ), origin_summary AS (
  SELECT r.origin_airport_key AS origin,
   count(*)::numeric n_priorities,
   sum(greatest(0,r.current_modelled_priority_passengers_day)::numeric) raw_weight,
   sum(greatest(0,r.current_modelled_priority_passengers_day)::numeric*
      CASE p_month WHEN 1 THEN dst.jan_pct WHEN 2 THEN dst.feb_pct WHEN 3 THEN dst.mar_pct WHEN 4 THEN dst.apr_pct WHEN 5 THEN dst.may_pct WHEN 6 THEN dst.jun_pct WHEN 7 THEN dst.jul_pct WHEN 8 THEN dst.aug_pct WHEN 9 THEN dst.sep_pct WHEN 10 THEN dst.oct_pct WHEN 11 THEN dst.nov_pct WHEN 12 THEN dst.dec_pct END::numeric/100) seasonal_weight
  FROM airlinerra_game.section7_current_destination_priorities r
  JOIN airlinerra_game.airport_seasonal_demand_profiles dst
   ON dst.world_id=r.world_id AND dst.airport_key=r.destination_airport_key
  WHERE r.world_id=p_world_id AND r.origin_airport_key IN(SELECT origin FROM pairs)
  GROUP BY r.origin_airport_key
 ), market AS (
  SELECT p.origin,p.destination,
   coalesce(o.gameplay_avg_daily_outbound_passengers,o.avg_daily_outbound_passengers,0)::numeric
       * (CASE p_month WHEN 1 THEN os.jan_pct WHEN 2 THEN os.feb_pct WHEN 3 THEN os.mar_pct WHEN 4 THEN os.apr_pct WHEN 5 THEN os.may_pct WHEN 6 THEN os.jun_pct WHEN 7 THEN os.jul_pct WHEN 8 THEN os.aug_pct WHEN 9 THEN os.sep_pct WHEN 10 THEN os.oct_pct WHEN 11 THEN os.nov_pct WHEN 12 THEN os.dec_pct END::numeric/100) AS available_pax,
   coalesce(o.avg_daily_outbound_cargo_tonnes,0)::numeric AS available_cargo,
   pr.current_modelled_priority_passengers_day::numeric AS prior_raw,
   (CASE p_month WHEN 1 THEN ds.jan_pct WHEN 2 THEN ds.feb_pct WHEN 3 THEN ds.mar_pct WHEN 4 THEN ds.apr_pct WHEN 5 THEN ds.may_pct WHEN 6 THEN ds.jun_pct WHEN 7 THEN ds.jul_pct WHEN 8 THEN ds.aug_pct WHEN 9 THEN ds.sep_pct WHEN 10 THEN ds.oct_pct WHEN 11 THEN ds.nov_pct WHEN 12 THEN ds.dec_pct END::numeric/100) AS destination_factor,
   orig.n_priorities,orig.raw_weight,orig.seasonal_weight
  FROM pairs p
  JOIN airlinerra_game.airport_daily_traffic_pool_baselines o
   ON o.world_id=p_world_id AND o.airport_key=p.origin
  JOIN airlinerra_game.airport_daily_traffic_pool_baselines d
   ON d.world_id=p_world_id AND d.airport_key=p.destination
  JOIN airlinerra_game.airport_seasonal_demand_profiles os
   ON os.world_id=p_world_id AND os.airport_key=p.origin
  JOIN airlinerra_game.airport_seasonal_demand_profiles ds
   ON ds.world_id=p_world_id AND ds.airport_key=p.destination
  JOIN origin_summary orig ON orig.origin=p.origin
  LEFT JOIN airlinerra_game.section7_current_destination_priorities pr
   ON pr.world_id=p_world_id AND pr.origin_airport_key=p.origin
    AND pr.destination_airport_key=p.destination
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object(
  'origin',m.origin,'destination',m.destination,
  'passengers',round(greatest(0,m.available_pax)*
   CASE WHEN m.prior_raw IS NOT NULL THEN
    CASE WHEN m.seasonal_weight>0 THEN
     0.8*greatest(0,m.prior_raw)*m.destination_factor/m.seasonal_weight
    ELSE 0 END
   ELSE 0.2/greatest(1,3140-m.n_priorities) END,2),
  'cargoTonnes',round(greatest(0,m.available_cargo)*
   CASE WHEN m.prior_raw IS NOT NULL THEN
    CASE WHEN m.raw_weight>0 THEN
     0.8*greatest(0,m.prior_raw)/m.raw_weight
    ELSE 0 END
   ELSE 0.2/greatest(1,3140-m.n_priorities) END,3),
  'source','section7_budget_conserving_v1','cargoBasis','provisional')
  ORDER BY m.origin,m.destination),'[]'::jsonb) INTO result FROM market m;
 RETURN result;
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_market_batch_v1(
 smallint,smallint,jsonb) FROM PUBLIC,anon,authenticated;
