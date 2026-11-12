/**
 * Owner-scoped seven-game-day flight-occurrence PREVIEW.
 *
 * Not ticket inventory: this query is SELECT-only and cannot create flights,
 * passengers, slots, saleable capacity, revenue or ledger postings.
 *
 * Source: verified World 1 date, owner's operational schedule, origin IANA
 * timezone and explicit reference flight duration. Invalid DST departures
 * are withheld instead of invented.
 */
export const SEVEN_DAY_WINDOW_SQL=`
WITH owned AS MATERIALIZED (
 SELECT s.id AS schedule_id,s.airline_id,s.flight_number,s.version,
  s.weekly_schedule,s.reference_departure_utc,s.reference_arrival_utc,
  s.origin_airport_key,s.destination_airport_key,
  c.confirmed_game_date AS game_date,
  tzcheck.name AS airport_timezone,
  cap.passenger_seats AS verified_seats,
  (SELECT count(*)=2*jsonb_array_length(s.weekly_schedule)
    FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 slot
    WHERE slot.schedule_id=s.id) AS slots_reserved
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airlines a ON a.id=s.airline_id
 JOIN airlinerra_game.holding_world_clock_v1 c ON c.world_id=s.world_id
 JOIN public.airlinerra_game_worlds w ON w.id=s.world_id
 LEFT JOIN airlinerra_game.airport_reference_profiles tz ON
  tz.world_id=s.world_id AND tz.airport_key=s.origin_airport_key
 LEFT JOIN pg_catalog.pg_timezone_names tzcheck ON tzcheck.name=tz.timezone_iana
 LEFT JOIN airlinerra_game.section9_verified_schedule_capacity_v1 cap ON
  cap.schedule_id=s.id AND cap.airline_id=s.airline_id
  AND cap.schedule_version=s.version
 WHERE s.id=$3::uuid AND s.airline_id=$2::uuid
  AND a.owner_player_id=$1::uuid AND s.world_id=1 AND a.world_id=1
  AND w.state='active'
  AND c.clock_source='authoritative_game_engine'
  AND c.confirmed_game_date IS NOT NULL AND c.last_verified_at IS NOT NULL
), entries AS MATERIALIZED (
 SELECT o.*,weekly.item,weekly.ordinality::integer AS weekly_entry,
  d.day_value::date AS local_date,
  (d.day_value::date+(weekly.item->>'time')::time) AS local_departure
 FROM owned o
 CROSS JOIN LATERAL jsonb_array_elements(o.weekly_schedule)
  WITH ORDINALITY AS weekly(item,ordinality)
 CROSS JOIN LATERAL generate_series(
  o.game_date::timestamp,(o.game_date+6)::timestamp,interval '1 day'
 ) d(day_value)
 WHERE jsonb_typeof(weekly.item)='object'
  AND coalesce(weekly.item->>'day','')~'^[0-6]$'
  AND coalesce(weekly.item->>'time','')~'^([01][0-9]|2[0-3]):[0-5][0-9]$'
  AND (weekly.item->>'day')::integer=extract(isodow FROM d.day_value)::integer-1
), resolved AS MATERIALIZED (
 SELECT e.*,
  (e.local_departure AT TIME ZONE e.airport_timezone) AS departure_utc,
  (e.local_departure AT TIME ZONE e.airport_timezone)+
   (e.reference_arrival_utc-e.reference_departure_utc) AS arrival_utc,
  CASE
   WHEN e.airport_timezone IS NULL THEN 'TIMEZONE_UNVERIFIED'
   WHEN ((e.local_departure AT TIME ZONE e.airport_timezone)
      AT TIME ZONE e.airport_timezone) IS DISTINCT FROM e.local_departure
      THEN 'NONEXISTENT_LOCAL_DEPARTURE'
   WHEN (((e.local_departure AT TIME ZONE e.airport_timezone)+interval '1 hour')
      AT TIME ZONE e.airport_timezone)=e.local_departure
     OR (((e.local_departure AT TIME ZONE e.airport_timezone)-interval '1 hour')
      AT TIME ZONE e.airport_timezone)=e.local_departure
      THEN 'AMBIGUOUS_LOCAL_DEPARTURE'
   ELSE NULL END AS time_issue
 FROM entries e
)
SELECT jsonb_build_object(
 'status','seven_day_preview_only',
 'worldId',1,'readOnly',true,'bookingEnabled',false,
 'passengerBookingsCreated',false,'ledgerPosted',false,
 'gameDate',o.game_date,'windowDays',7,
 'lastGameDate',o.game_date+6,
 'scheduleId',o.schedule_id,'flightNumber',o.flight_number,
 'originAirportKey',o.origin_airport_key,
 'destinationAirportKey',o.destination_airport_key,
 'verifiedSeatCapacity',o.verified_seats,
 'slotsReserved',o.slots_reserved,
 'originTimezone',o.airport_timezone,
 'passengerCount',NULL,
 'occurrences',coalesce((
  SELECT jsonb_agg(jsonb_build_object(
   'flightLocalDate',r.local_date,
   'weeklyEntry',r.weekly_entry,
   'departureLocal',r.local_departure,
   'departureUtc',CASE WHEN r.time_issue IS NULL THEN r.departure_utc END,
   'estimatedArrivalUtc',CASE WHEN r.time_issue IS NULL THEN r.arrival_utc END,
   'timeIssue',r.time_issue,
   'status','not_saleable',
   'passengerBookings',NULL,
   'bookingEnabled',false
  ) ORDER BY r.local_date,r.weekly_entry)
  FROM resolved r
 ),'[]'::jsonb)
) AS result FROM owned o
`;
