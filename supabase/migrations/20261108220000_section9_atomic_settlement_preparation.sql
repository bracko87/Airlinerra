-- Section 9: atomically prepare, but DO NOT POST, cross-day settlements.
-- This is a server-only preflight. It must not activate flights, reserve
-- commercial passenger tickets, change airline cash, or write airline_ledger.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_prepared_occurrence_settlements_v1(
 physical_flight_id text PRIMARY KEY,
 schedule_id uuid NOT NULL REFERENCES airlinerra_game.airline_flight_schedule_drafts_v1(id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 local_departure_date date NOT NULL,
 schedule_version integer NOT NULL CHECK(schedule_version>=1),
 commercial_version integer NOT NULL CHECK(commercial_version>=1),
 passenger_seats integer NOT NULL CHECK(passenger_seats BETWEEN 0 AND 1000),
 passengers integer NOT NULL CHECK(passengers BETWEEN 0 AND 1000),
 cargo_capacity_tonnes numeric(12,3) NOT NULL CHECK(cargo_capacity_tonnes BETWEEN 0 AND 1000),
 cargo_tonnes numeric(12,3) NOT NULL CHECK(cargo_tonnes>=0 AND cargo_tonnes<=cargo_capacity_tonnes),
 ticket_revenue_usd numeric(16,2) NOT NULL CHECK(ticket_revenue_usd>=0),
 cargo_revenue_usd numeric(16,2) NOT NULL CHECK(cargo_revenue_usd>=0),
 source_job_proofs jsonb NOT NULL CHECK(jsonb_typeof(source_job_proofs)='array'
    AND jsonb_array_length(source_job_proofs)=3),
 status text NOT NULL DEFAULT 'preflight_only' CHECK(status='preflight_only'),
 prepared_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT section9_prepared_seat_limit CHECK(passengers<=passenger_seats),
 CONSTRAINT section9_prepared_identity CHECK(
    physical_flight_id LIKE schedule_id::text||':'||local_departure_date::text||':%'
 )
);
ALTER TABLE airlinerra_game.section9_prepared_occurrence_settlements_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_prepared_occurrence_settlements_v1
 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_prepared_airline_day_idx
 ON airlinerra_game.section9_prepared_occurrence_settlements_v1
 (airline_id,local_departure_date);

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_unposted_revenue_intents_v1(
 physical_flight_id text NOT NULL REFERENCES
  airlinerra_game.section9_prepared_occurrence_settlements_v1(physical_flight_id),
 revenue_kind text NOT NULL CHECK(revenue_kind IN ('PASSENGER_REVENUE','CARGO_REVENUE')),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 amount_usd numeric(16,2) NOT NULL CHECK(amount_usd>0 AND amount_usd<=1000000000000),
 status text NOT NULL DEFAULT 'unposted' CHECK(status='unposted'),
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(physical_flight_id,revenue_kind)
);
ALTER TABLE airlinerra_game.section9_unposted_revenue_intents_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_unposted_revenue_intents_v1
 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_unposted_intents_airline_idx
 ON airlinerra_game.section9_unposted_revenue_intents_v1(airline_id,revenue_kind);
COMMENT ON TABLE airlinerra_game.section9_unposted_revenue_intents_v1 IS
 'Future-only revenue intents. Deliberately no airline_ledger or airline cash effect.';

CREATE OR REPLACE FUNCTION airlinerra_game.section9_prepare_verified_settlement_batch_v1(
 p_world_id smallint,p_target_date date,
 p_after_flight_id text DEFAULT NULL,p_limit integer DEFAULT 100
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE jobs_count int;materialized_ok bool;source_proofs jsonb;
 rec record;oper record;processed int:=0;new_count int:=0;new_intents int:=0;
 added int;cursor_id text;exists_before int;
BEGIN
 IF p_world_id<>1 OR p_target_date IS NULL OR
  p_target_date NOT BETWEEN DATE '2000-01-01' AND DATE '2200-12-31'
  OR p_limit NOT BETWEEN 1 AND 250
  OR (p_after_flight_id IS NOT NULL AND
       (length(p_after_flight_id)>120 OR length(p_after_flight_id)<10))
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_PREPARE_BATCH'; END IF;

 -- Three completed demand days are required to account for inbound,
 -- outbound and midnight-crossing connections to the same physical flight.
 SELECT count(*),coalesce(bool_and(
  j.status='completed' AND j.completed_flight_rows IS NOT NULL
  AND j.completed_flight_rows=(
    SELECT count(*) FROM airlinerra_game.section9_completed_flight_contributions_v1 c
    WHERE c.job_id=j.id)),false)
 INTO jobs_count,materialized_ok
 FROM airlinerra_game.section9_demand_jobs_v1 j
 WHERE j.world_id=p_world_id AND j.model_version='network_forecast_v1'
   AND j.game_date BETWEEN p_target_date-1 AND p_target_date+1;
 IF jobs_count<>3 OR NOT materialized_ok THEN
  RETURN jsonb_build_object('status','blocked_incomplete_or_unmaterialized_forecasts',
   'gameDate',p_target_date,'completedDays',jobs_count,
   'materialized',materialized_ok,'settlementPrepared',false,
   'ledgerPosted',false,'bookingsCreated',false);
 END IF;

 SELECT jsonb_agg(jsonb_build_object('jobId',id,'attempt',attempt,
  'gameDate',game_date) ORDER BY game_date)
 INTO source_proofs FROM airlinerra_game.section9_demand_jobs_v1
 WHERE world_id=p_world_id AND model_version='network_forecast_v1'
  AND game_date BETWEEN p_target_date-1 AND p_target_date+1;

 -- Work is bounded and indexed by actual local departure date. No
 -- scans across 3,141 airports or arbitrary player market pairs.
 FOR rec IN
  WITH selected_flights AS (
   SELECT DISTINCT c.physical_flight_id
   FROM airlinerra_game.section9_completed_flight_contributions_v1 c
   JOIN airlinerra_game.section9_demand_jobs_v1 j ON j.id=c.job_id
   WHERE j.world_id=p_world_id AND j.model_version='network_forecast_v1'
    AND j.game_date BETWEEN p_target_date-1 AND p_target_date+1
    AND c.local_departure_date=p_target_date
    AND (p_after_flight_id IS NULL OR c.physical_flight_id>p_after_flight_id)
   ORDER BY c.physical_flight_id
   LIMIT p_limit
  )
  SELECT c.physical_flight_id, min(c.schedule_id::text)::uuid AS schedule_id,
    min(c.airline_id::text)::uuid AS airline_id,
    min(c.schedule_version) AS schedule_version,
    min(c.commercial_version) AS commercial_version,
    min(c.passenger_seats) AS passenger_seats,
    min(c.cargo_capacity_tonnes) AS cargo_capacity_tonnes,
    sum(c.passengers)::integer AS passengers,
    sum(c.cargo_tonnes)::numeric(12,3) AS cargo_tonnes,
    sum(c.ticket_revenue_usd)::numeric(16,2) AS ticket_revenue_usd,
    sum(c.cargo_revenue_usd)::numeric(16,2) AS cargo_revenue_usd,
    count(DISTINCT c.job_id) AS contributor_count,
    count(DISTINCT c.schedule_id) AS schedule_id_variants,
    count(DISTINCT c.airline_id) AS airline_id_variants,
    count(DISTINCT c.schedule_version) AS schedule_version_variants,
    count(DISTINCT c.commercial_version) AS commercial_version_variants,
    count(DISTINCT c.passenger_seats) AS passenger_capacity_variants,
    count(DISTINCT c.cargo_capacity_tonnes) AS cargo_capacity_variants,
    count(DISTINCT c.row_payload->>'departureUtc') AS departure_variants,
    count(DISTINCT c.row_payload->>'arrivalUtc') AS arrival_variants,
    min((c.row_payload->>'weeklyEntry')::integer) AS weekly_entry
  FROM selected_flights sf
  JOIN airlinerra_game.section9_completed_flight_contributions_v1 c
    ON c.physical_flight_id=sf.physical_flight_id
   AND c.local_departure_date=p_target_date
  JOIN airlinerra_game.section9_demand_jobs_v1 j ON j.id=c.job_id
   AND j.world_id=p_world_id
   AND j.game_date BETWEEN p_target_date-1 AND p_target_date+1
   AND j.model_version='network_forecast_v1'
  GROUP BY c.physical_flight_id
  ORDER BY c.physical_flight_id
 LOOP
  IF rec.contributor_count NOT BETWEEN 1 AND 3 OR
    rec.schedule_id_variants<>1 OR rec.airline_id_variants<>1 OR
    rec.schedule_version_variants<>1 OR rec.commercial_version_variants<>1 OR
    rec.passenger_capacity_variants<>1 OR rec.cargo_capacity_variants<>1 OR
    rec.departure_variants<>1 OR rec.arrival_variants<>1 OR
    rec.passengers>rec.passenger_seats OR
    rec.cargo_tonnes>rec.cargo_capacity_tonnes OR
    rec.ticket_revenue_usd<0 OR rec.cargo_revenue_usd<0
  THEN RAISE EXCEPTION USING ERRCODE='22023',
     MESSAGE='SECTION9_CROSS_DAY_CAPACITY_OR_VERSION_CONFLICT';END IF;
  -- Independently recheck activated schedule, verified capacity, exact
  -- version and fleet status under a shared row lock.
  SELECT d.airline_id,d.version,d.status,d.operationally_verified,
   d.weekly_schedule,d.aircraft_inventory_id,f.fleet_status,
   cap.passenger_seats,cap.cargo_capacity_tonnes,
   cap.schedule_version,plan.version AS commercial_version
  INTO oper
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
  JOIN airlinerra_game.airline_aircraft_inventory f
    ON f.id=d.aircraft_inventory_id AND f.airline_id=d.airline_id
  JOIN airlinerra_game.section9_verified_schedule_capacity_v1 cap
    ON cap.schedule_id=d.id AND cap.airline_id=d.airline_id
  JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
    ON plan.schedule_id=d.id AND plan.airline_id=d.airline_id
  WHERE d.id=rec.schedule_id
  FOR SHARE OF d,f,cap,plan;
  IF NOT FOUND OR oper.status<>'active' OR
    oper.operationally_verified IS DISTINCT FROM true OR
    oper.fleet_status<>'in_service' OR
    oper.airline_id<>rec.airline_id OR
    oper.version<>rec.schedule_version OR
    oper.schedule_version<>rec.schedule_version OR
    oper.commercial_version<>rec.commercial_version OR
    oper.passenger_seats<>rec.passenger_seats OR
    oper.cargo_capacity_tonnes<>rec.cargo_capacity_tonnes OR
    rec.weekly_entry NOT BETWEEN 1 AND jsonb_array_length(oper.weekly_schedule) OR
    ((oper.weekly_schedule->(rec.weekly_entry-1)->>'day')::int
      IS DISTINCT FROM extract(isodow from p_target_date)::int-1)
  THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_OPERATION_NOT_ACTIVATED_OR_VERIFIED';END IF;
  IF NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slot
    WHERE slot.schedule_id=rec.schedule_id AND slot.direction='departure'
  ) OR NOT EXISTS(
    SELECT 1 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slot
    WHERE slot.schedule_id=rec.schedule_id AND slot.direction='arrival'
  ) THEN RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_VERIFIED_AIRPORT_SLOTS_MISSING'; END IF;

  INSERT INTO airlinerra_game.section9_prepared_occurrence_settlements_v1(
   physical_flight_id,schedule_id,airline_id,local_departure_date,
   schedule_version,commercial_version,passenger_seats,passengers,
   cargo_capacity_tonnes,cargo_tonnes,ticket_revenue_usd,cargo_revenue_usd,
   source_job_proofs)
  VALUES(rec.physical_flight_id,rec.schedule_id,rec.airline_id,
   p_target_date,rec.schedule_version,rec.commercial_version,
   rec.passenger_seats,rec.passengers,rec.cargo_capacity_tonnes,
   rec.cargo_tonnes,rec.ticket_revenue_usd,rec.cargo_revenue_usd,
   source_proofs)
  ON CONFLICT (physical_flight_id) DO NOTHING;
  GET DIAGNOSTICS added=ROW_COUNT;
  new_count:=new_count+added;
  IF EXISTS(
   SELECT 1 FROM airlinerra_game.section9_prepared_occurrence_settlements_v1 x
   WHERE x.physical_flight_id=rec.physical_flight_id
    AND (x.schedule_id<>rec.schedule_id OR x.airline_id<>rec.airline_id
     OR x.local_departure_date<>p_target_date
     OR x.schedule_version<>rec.schedule_version
     OR x.commercial_version<>rec.commercial_version
     OR x.passenger_seats<>rec.passenger_seats OR x.passengers<>rec.passengers
     OR x.cargo_capacity_tonnes<>rec.cargo_capacity_tonnes
     OR x.cargo_tonnes<>rec.cargo_tonnes
     OR x.ticket_revenue_usd<>rec.ticket_revenue_usd
     OR x.cargo_revenue_usd<>rec.cargo_revenue_usd
     OR x.source_job_proofs<>source_proofs)
  ) THEN RAISE EXCEPTION USING ERRCODE='23505',
    MESSAGE='SECTION9_PREPARED_SETTLEMENT_REPLAY_CONFLICT';END IF;

  IF rec.ticket_revenue_usd>0 THEN
   INSERT INTO airlinerra_game.section9_unposted_revenue_intents_v1(
    physical_flight_id,revenue_kind,airline_id,amount_usd)
   VALUES(rec.physical_flight_id,'PASSENGER_REVENUE',
    rec.airline_id,rec.ticket_revenue_usd)
   ON CONFLICT DO NOTHING;
   GET DIAGNOSTICS added=ROW_COUNT;
   new_intents:=new_intents+added;
   IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_unposted_revenue_intents_v1
     WHERE physical_flight_id=rec.physical_flight_id
      AND revenue_kind='PASSENGER_REVENUE'
      AND airline_id=rec.airline_id AND amount_usd=rec.ticket_revenue_usd)
   THEN RAISE EXCEPTION USING ERRCODE='23505',
     MESSAGE='SECTION9_PASSENGER_REVENUE_INTENT_CONFLICT';END IF;
  END IF;
  IF rec.cargo_revenue_usd>0 THEN
   INSERT INTO airlinerra_game.section9_unposted_revenue_intents_v1(
    physical_flight_id,revenue_kind,airline_id,amount_usd)
   VALUES(rec.physical_flight_id,'CARGO_REVENUE',
    rec.airline_id,rec.cargo_revenue_usd)
   ON CONFLICT DO NOTHING;
   GET DIAGNOSTICS added=ROW_COUNT;
   new_intents:=new_intents+added;
   IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_unposted_revenue_intents_v1
     WHERE physical_flight_id=rec.physical_flight_id
      AND revenue_kind='CARGO_REVENUE'
      AND airline_id=rec.airline_id AND amount_usd=rec.cargo_revenue_usd)
   THEN RAISE EXCEPTION USING ERRCODE='23505',
     MESSAGE='SECTION9_CARGO_REVENUE_INTENT_CONFLICT';END IF;
  END IF;
  processed:=processed+1;cursor_id:=rec.physical_flight_id;
 END LOOP;

 RETURN jsonb_build_object('status','prepared_unposted',
  'gameDate',p_target_date,'flightsInspected',processed,
  'newProofs',new_count,'newRevenueIntents',new_intents,
  'nextFlightCursor',cursor_id,
  'hasMore',processed=p_limit,
  'ledgerPosted',false,'bookingsCreated',false,
  'operationalActivationChanged',false);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_prepare_verified_settlement_batch_v1(
 smallint,date,text,integer) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section9_prepare_verified_settlement_batch_v1(
 smallint,date,text,integer) IS
 'Private all-or-nothing indexed settlement PREPARATION from 3 completed forecasts. Rechecks activated flight and slots. Does NOT reserve commercial bookings or credit cash/ledger.';
