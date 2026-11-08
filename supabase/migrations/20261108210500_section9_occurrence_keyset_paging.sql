-- Section 9: paging by PHYSICAL flight occurrence, not only schedule id.
-- A verified weekly schedule may contain two departures on the same weekday:
-- schedule-id-only keysets skip the second occurrence at page boundaries.
-- Preserve v1 for compatibility; the private backend uses v2 exclusively.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verified_daily_flight_page_v2(
 p_world_id smallint,p_local_date date,p_limit integer DEFAULT 1000,
 p_after_schedule_id uuid DEFAULT NULL,p_after_weekly_entry integer DEFAULT NULL
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE result jsonb;
BEGIN
 IF p_world_id<>1 OR p_local_date IS NULL
    OR p_local_date NOT BETWEEN DATE '2000-01-01' AND DATE '2200-12-31'
    OR p_limit NOT BETWEEN 1 AND 2000
    OR (p_after_schedule_id IS NULL) <> (p_after_weekly_entry IS NULL)
    OR (p_after_weekly_entry IS NOT NULL AND
       p_after_weekly_entry NOT BETWEEN 1 AND 10000)
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_OCCURRENCE_PAGE'; END IF;

 WITH occurrences AS (
   SELECT d.id AS schedule_id,d.airline_id,d.origin_airport_key,
    d.destination_airport_key,d.version AS schedule_version,
    cap.passenger_seats,cap.cargo_capacity_tonnes AS cargo_tonnes,
    plan.economy_fare_usd,plan.cargo_rate_usd_per_tonne,
    plan.version AS commercial_version,
    jsonb_array_length(d.weekly_schedule) AS weekly_departures,
    d.reference_arrival_utc-d.reference_departure_utc AS flight_duration,
    tz.timezone_iana,
    (p_local_date::timestamp +
      (j.item->>'time')::time::interval) AS local_departure,
    j.ordinality::integer AS weekly_entry,
    cap.verification_source
   FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
   JOIN airlinerra_game.section9_verified_schedule_capacity_v1 cap
     ON cap.schedule_id=d.id AND cap.airline_id=d.airline_id
       AND cap.schedule_version=d.version
   JOIN airlinerra_game.section9_route_commercial_plans_v1 plan
     ON plan.schedule_id=d.id AND plan.airline_id=d.airline_id
   JOIN airlinerra_game.airport_reference_profiles tz
     ON tz.world_id=d.world_id AND tz.airport_key=d.origin_airport_key
   CROSS JOIN LATERAL jsonb_array_elements(d.weekly_schedule)
      WITH ORDINALITY AS j(item,ordinality)
   WHERE d.world_id=p_world_id AND d.status='active'
     AND d.operationally_verified IS TRUE
     AND tz.timezone_iana IS NOT NULL
     AND (j.item->>'day') ~ '^[0-6]$'
     AND (j.item->>'time') ~ '^([01][0-9]|2[0-3]):[0-5][0-9]$'
     AND (j.item->>'day')::integer=extract(isodow from p_local_date)::int-1
     AND (p_after_schedule_id IS NULL OR
       (d.id,j.ordinality)>(p_after_schedule_id,p_after_weekly_entry))
   ORDER BY d.id,j.ordinality
   LIMIT p_limit
 ), stamped AS (
   SELECT o.*,
      (o.local_departure AT TIME ZONE o.timezone_iana) AS departure_utc
   FROM occurrences o
 ), tagged AS (
   SELECT s.*,
     CASE
       WHEN (s.departure_utc AT TIME ZONE s.timezone_iana)
          IS DISTINCT FROM s.local_departure THEN 'nonexistent'
       WHEN ((s.departure_utc-INTERVAL '1 hour')
           AT TIME ZONE s.timezone_iana)=s.local_departure
         OR ((s.departure_utc+INTERVAL '1 hour')
           AT TIME ZONE s.timezone_iana)=s.local_departure
       THEN 'ambiguous'
       ELSE 'valid'
     END AS time_status
   FROM stamped s
 )
 SELECT coalesce(jsonb_agg(jsonb_build_object(
   'id',s.schedule_id::text||':'||p_local_date::text||':'||s.weekly_entry::text,
   'scheduleId',s.schedule_id,'weeklyEntry',s.weekly_entry,
   'scheduleVersion',s.schedule_version,
   'airlineId',s.airline_id,'origin',s.origin_airport_key,
   'destination',s.destination_airport_key,'status','operational_verified',
   'marketDate',p_local_date,
   'originTimeZone',s.timezone_iana,
   'localDeparture',s.local_departure,
   'localTimeStatus',s.time_status,
   'departureUtc',s.departure_utc,
   'arrivalUtc',s.departure_utc+s.flight_duration,
   'passengerSeats',s.passenger_seats,'cargoTonnes',s.cargo_tonnes,
   'fareUsd',s.economy_fare_usd,
   'cargoRateUsd',s.cargo_rate_usd_per_tonne,
   'marketingBoost',0,'marketingAuthorized',false,
   'weeklyDepartures',s.weekly_departures,
   'capacitySource','verified_activated_schedule',
   'verificationSource',s.verification_source,
   'commercialPlanVersion',s.commercial_version)
   ORDER BY s.schedule_id,s.weekly_entry),'[]'::jsonb)
 INTO result FROM tagged s;
 RETURN result;
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_verified_daily_flight_page_v2(
 smallint,date,integer,uuid,integer) FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section9_verified_daily_flight_page_v2(
 smallint,date,integer,uuid,integer) IS
 'Server-only verified occurrences paged by (schedule ID, weekly entry). A spring gap or autumn overlap is reported as invalid to the runner; no silent local-time correction.';
