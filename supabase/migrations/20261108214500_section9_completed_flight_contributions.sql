-- Section 9: normalize immutable, completed forecast flight rows for
-- efficient cross-date atomic settlement preflight.
-- This creates NO ticket bookings and makes NO airline ledger entries.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_completed_flight_contributions_v1 (
 job_id uuid NOT NULL REFERENCES airlinerra_game.section9_demand_jobs_v1(id) ON DELETE CASCADE,
 physical_flight_id text NOT NULL,
 local_departure_date date NOT NULL,
 schedule_id uuid NOT NULL,
 airline_id uuid NOT NULL,
 schedule_version integer NOT NULL CHECK(schedule_version>=1),
 commercial_version integer NOT NULL CHECK(commercial_version>=1),
 passenger_seats integer NOT NULL CHECK(passenger_seats BETWEEN 0 AND 1000),
 cargo_capacity_tonnes numeric(12,3) NOT NULL CHECK(cargo_capacity_tonnes BETWEEN 0 AND 1000),
 passengers integer NOT NULL CHECK(passengers>=0 AND passengers<=passenger_seats),
 cargo_tonnes numeric(12,3) NOT NULL CHECK(cargo_tonnes>=0 AND cargo_tonnes<=cargo_capacity_tonnes),
 ticket_revenue_usd numeric(16,2) NOT NULL CHECK(ticket_revenue_usd>=0),
 cargo_revenue_usd numeric(16,2) NOT NULL CHECK(cargo_revenue_usd>=0),
 row_payload jsonb NOT NULL CHECK(jsonb_typeof(row_payload)='object'),
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(job_id,physical_flight_id),
 CONSTRAINT section9_contribution_identity CHECK (
  physical_flight_id=schedule_id::text||':'||local_departure_date::text||':'||
   coalesce(row_payload->>'weeklyEntry','')
 ),
 CONSTRAINT section9_contribution_source CHECK (
  row_payload->>'capacitySource'='verified_activated_schedule'
  AND length(coalesce(row_payload->>'verificationSource',''))>=6
 )
);
ALTER TABLE airlinerra_game.section9_completed_flight_contributions_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_completed_flight_contributions_v1
 FROM PUBLIC,anon,authenticated;
CREATE INDEX IF NOT EXISTS section9_contribution_by_flight_day_idx
 ON airlinerra_game.section9_completed_flight_contributions_v1
 (local_departure_date,physical_flight_id,job_id);
COMMENT ON TABLE airlinerra_game.section9_completed_flight_contributions_v1 IS
 'Private, immutable completed-forecast flight contributions. Not bookings or credits.';

CREATE OR REPLACE FUNCTION airlinerra_game.section9_materialize_completed_flights_v1(
 p_job uuid
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j airlinerra_game.section9_demand_jobs_v1%ROWTYPE;
 expected integer; staged integer; matched integer; inserted integer;
BEGIN
 SELECT * INTO j FROM airlinerra_game.section9_demand_jobs_v1
 WHERE id=p_job FOR UPDATE;
 IF NOT FOUND OR j.status<>'completed' OR j.attempt NOT BETWEEN 1 AND 5
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_FORECAST_NOT_COMPLETED'; END IF;
 SELECT coalesce(sum(c.row_count),0)::integer INTO staged
 FROM airlinerra_game.section9_demand_job_chunks_v1 c
 WHERE c.job_id=j.id AND c.attempt=j.attempt AND c.chunk_kind='flight';
 expected:=j.completed_flight_rows;
 IF expected IS NULL OR staged<>expected THEN
  RAISE EXCEPTION USING ERRCODE='22023',MESSAGE='SECTION9_INCOMPLETE_FLIGHT_CHUNKS';END IF;

 IF EXISTS (
  SELECT 1
  FROM airlinerra_game.section9_demand_job_chunks_v1 c
  CROSS JOIN LATERAL jsonb_array_elements(c.result_rows) AS rows(payload)
  WHERE c.job_id=j.id AND c.attempt=j.attempt AND c.chunk_kind='flight'
  AND (
   jsonb_typeof(rows.payload)<>'object'
   OR coalesce(rows.payload->>'capacitySource','')<>'verified_activated_schedule'
   OR length(coalesce(rows.payload->>'verificationSource',''))<6
   OR (rows.payload->>'flightId') IS DISTINCT FROM
      (rows.payload->>'scheduleId')||':'||
      (rows.payload->>'marketDate')||':'||
      (rows.payload->>'weeklyEntry')
   OR coalesce(rows.payload->>'scheduleId','') !~
      '^[0-9a-fA-F-]{36}$'
   OR coalesce(rows.payload->>'airlineId','') !~
      '^[0-9a-fA-F-]{36}$'
   OR coalesce(rows.payload->>'marketDate','') !~
      '^2[0-1][0-9][0-9]-[0-1][0-9]-[0-3][0-9]$'
   OR coalesce(rows.payload->>'weeklyEntry','') !~ '^[0-9]{1,4}$'
   OR coalesce(rows.payload->>'passengers','') !~ '^[0-9]{1,6}$'
   OR coalesce(rows.payload->>'passengerSeats','') !~ '^[0-9]{1,5}$'
   OR coalesce(rows.payload->>'cargoTonnes','') !~ '^[0-9]{1,4}([.][0-9]{1,3})?$'
   OR coalesce(rows.payload->>'cargoCapacityTonnes','') !~ '^[0-9]{1,4}([.][0-9]{1,3})?$'
   OR coalesce(rows.payload->>'ticketRevenueUsd','') !~ '^[0-9]{1,14}([.][0-9]{1,2})?$'
   OR coalesce(rows.payload->>'cargoRevenueUsd','') !~ '^[0-9]{1,14}([.][0-9]{1,2})?$'
   OR coalesce(rows.payload->>'scheduleVersion','') !~ '^[0-9]{1,9}$'
   OR coalesce(rows.payload->>'commercialPlanVersion','') !~ '^[0-9]{1,9}$'
  )
 ) THEN RAISE EXCEPTION USING ERRCODE='22023',
    MESSAGE='SECTION9_UNVERIFIED_CONTRIBUTION_ROW';END IF;

 WITH source AS (
  SELECT c.result_rows,rows.payload AS row_value
  FROM airlinerra_game.section9_demand_job_chunks_v1 c
  CROSS JOIN LATERAL jsonb_array_elements(c.result_rows) AS rows(payload)
  WHERE c.job_id=j.id AND c.attempt=j.attempt AND c.chunk_kind='flight'
 )
 INSERT INTO airlinerra_game.section9_completed_flight_contributions_v1(
  job_id,physical_flight_id,local_departure_date,schedule_id,airline_id,
  schedule_version,commercial_version,passenger_seats,cargo_capacity_tonnes,
  passengers,cargo_tonnes,ticket_revenue_usd,cargo_revenue_usd,row_payload
 )
 SELECT j.id,r.row_value->>'flightId',
  (r.row_value->>'marketDate')::date,
  (r.row_value->>'scheduleId')::uuid,
  (r.row_value->>'airlineId')::uuid,
  (r.row_value->>'scheduleVersion')::integer,
  (r.row_value->>'commercialPlanVersion')::integer,
  (r.row_value->>'passengerSeats')::integer,
  (r.row_value->>'cargoCapacityTonnes')::numeric,
  (r.row_value->>'passengers')::integer,
  (r.row_value->>'cargoTonnes')::numeric,
  (r.row_value->>'ticketRevenueUsd')::numeric,
  (r.row_value->>'cargoRevenueUsd')::numeric,
  r.row_value
 FROM source r
 ON CONFLICT(job_id,physical_flight_id) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;

 SELECT count(*) INTO matched
 FROM airlinerra_game.section9_completed_flight_contributions_v1 x
 WHERE x.job_id=j.id;
 IF matched<>expected OR EXISTS(
  SELECT 1 FROM airlinerra_game.section9_demand_job_chunks_v1 c
  CROSS JOIN LATERAL jsonb_array_elements(c.result_rows) AS rows(payload)
  LEFT JOIN airlinerra_game.section9_completed_flight_contributions_v1 x
    ON x.job_id=c.job_id AND x.physical_flight_id=rows.payload->>'flightId'
  WHERE c.job_id=j.id AND c.attempt=j.attempt AND c.chunk_kind='flight'
   AND (x.row_payload IS DISTINCT FROM rows.payload)
 ) THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_CONTRIBUTION_CONFLICT_OR_MISSING_ROWS';END IF;

 RETURN jsonb_build_object('jobId',j.id,'status','materialized',
  'forecastRows',expected,'storedRows',matched,'insertedNow',inserted,
  'bookingsCreated',false,'ledgerPosted',false);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_materialize_completed_flights_v1(uuid)
 FROM PUBLIC,anon,authenticated;
