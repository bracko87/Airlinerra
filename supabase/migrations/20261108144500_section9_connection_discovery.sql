-- Section 9 Phase 2: agreement-ready, read-only connecting-flight discovery.
-- Only protected owned schedule drafts are considered; never imply an active itinerary.
-- No full-world timetable scans; route and partner filters run before recurrence expansion.

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_interline_agreements_v1 (
 id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 left_airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 right_airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 agreement_status text NOT NULL DEFAULT 'proposed'
  CHECK(agreement_status IN ('proposed','active','terminated')),
 left_approved_at timestamptz,
 right_approved_at timestamptz,
 valid_from timestamptz,
 valid_until timestamptz,
 created_at timestamptz NOT NULL DEFAULT now(),
 CONSTRAINT section9_distinct_airlines_v1 CHECK(left_airline_id<>right_airline_id),
 CONSTRAINT section9_bilateral_activation_v1 CHECK(agreement_status<>'active' OR
  (left_approved_at IS NOT NULL AND right_approved_at IS NOT NULL
   AND valid_from IS NOT NULL)),
 CONSTRAINT section9_agreement_window_v1 CHECK(valid_until IS NULL OR
   (valid_from IS NOT NULL AND valid_until>valid_from)),
 UNIQUE(world_id,left_airline_id,right_airline_id)
);
ALTER TABLE airlinerra_game.section9_interline_agreements_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_interline_agreements_v1 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.section9_interline_agreements_v1 IS
 'Reserved for future authorized bilateral interline/codeshare workflows. No player activation API is provided. Only active double-approved records qualify.';

CREATE INDEX IF NOT EXISTS section9_draft_arrival_lookup_idx
 ON airlinerra_game.airline_flight_schedule_drafts_v1
 (world_id,destination_airport_key,status,airline_id);
CREATE INDEX IF NOT EXISTS section9_draft_departure_lookup_idx
 ON airlinerra_game.airline_flight_schedule_drafts_v1
 (world_id,origin_airport_key,status,airline_id);

CREATE OR REPLACE FUNCTION airlinerra_game.section9_schedule_connections_preview_v1(
 p_player_id uuid,p_schedule_id uuid
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $func$
DECLARE result jsonb;
BEGIN
 IF NOT EXISTS(
   SELECT 1 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
   JOIN airlinerra_game.airlines a ON a.id=d.airline_id
   WHERE d.id=p_schedule_id AND a.owner_player_id=p_player_id
    AND a.world_id=1 AND d.status='draft')
 THEN RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_SCHEDULE_NOT_OWNED'; END IF;

 WITH target AS (
  SELECT d.*,p.timezone_iana as origin_tz,po.minimum_transfer_minutes AS inbound_mct,
   pd.minimum_transfer_minutes AS outbound_mct
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
  JOIN airlinerra_game.airport_reference_profiles p
   ON p.world_id=d.world_id AND p.airport_key=d.origin_airport_key
  JOIN airlinerra_game.section9_airport_transfer_policy_v1 po
   ON po.world_id=d.world_id AND po.airport_key=d.origin_airport_key
  JOIN airlinerra_game.section9_airport_transfer_policy_v1 pd
   ON pd.world_id=d.world_id AND pd.airport_key=d.destination_airport_key
  WHERE d.id=p_schedule_id
 ), permitted_airlines AS (
  SELECT airline_id FROM (
   SELECT airline_id FROM target
   UNION
   SELECT CASE WHEN ag.left_airline_id=t.airline_id THEN ag.right_airline_id
      ELSE ag.left_airline_id END
   FROM airlinerra_game.section9_interline_agreements_v1 ag
   JOIN target t ON t.airline_id IN(ag.left_airline_id,ag.right_airline_id)
   WHERE ag.world_id=1 AND ag.agreement_status='active'
     AND ag.left_approved_at IS NOT NULL AND ag.right_approved_at IS NOT NULL
     AND ag.valid_from<=t.reference_departure_utc
     AND (ag.valid_until IS NULL OR ag.valid_until>t.reference_arrival_utc)
  ) permitted
 ), candidates AS (
  SELECT d.*,a.name as airline_name,p.timezone_iana as origin_tz
  FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
  JOIN target t ON d.world_id=t.world_id
  JOIN permitted_airlines allow ON allow.airline_id=d.airline_id
  JOIN airlinerra_game.airlines a ON a.id=d.airline_id AND a.world_id=d.world_id
  JOIN airlinerra_game.airport_reference_profiles p ON p.world_id=d.world_id
    AND p.airport_key=d.origin_airport_key
  WHERE d.status='draft' AND d.id<>p_schedule_id
    AND (d.destination_airport_key=t.origin_airport_key
     OR d.origin_airport_key=t.destination_airport_key)
 ), target_occurrences AS (
  SELECT t.origin_airport_key,t.destination_airport_key,t.inbound_mct,t.outbound_mct,
   ((date_trunc('week',t.reference_departure_utc AT TIME ZONE t.origin_tz)::date
      + 7*w.n + (j->>'day')::int)::timestamp
      + ((j->>'time')::time)::interval) AT TIME ZONE t.origin_tz AS departure_utc,
   t.reference_arrival_utc-t.reference_departure_utc AS flight_duration
  FROM target t CROSS JOIN generate_series(0,3) w(n)
  CROSS JOIN LATERAL jsonb_array_elements(t.weekly_schedule) AS j
 ), matching_departures AS (
  SELECT c.id,c.airline_id,c.airline_name,c.flight_number,
   c.origin_airport_key,c.destination_airport_key,
   ((date_trunc('week',t.reference_departure_utc AT TIME ZONE c.origin_tz)::date
      + 7*w.n + (j->>'day')::int)::timestamp
      + ((j->>'time')::time)::interval) AT TIME ZONE c.origin_tz AS departure_utc,
    c.reference_arrival_utc-c.reference_departure_utc AS flight_duration
  FROM candidates c CROSS JOIN target t
  CROSS JOIN generate_series(-1,4) w(n)
  CROSS JOIN LATERAL jsonb_array_elements(c.weekly_schedule) j
 ), matched AS (
  SELECT 'inbound'::text direction,m.id,m.airline_id,m.airline_name,m.flight_number,
   m.origin_airport_key as other_airport_key,
   round(EXTRACT(EPOCH FROM (t.departure_utc -
       (m.departure_utc+m.flight_duration)))/60)::int AS transfer_minutes,
   t.inbound_mct AS minimum_transfer_minutes
  FROM target_occurrences t
  JOIN matching_departures m ON m.destination_airport_key=t.origin_airport_key
  WHERE t.inbound_mct IS NOT NULL AND
   m.departure_utc+m.flight_duration BETWEEN
    t.departure_utc-interval '12 hours'
    AND t.departure_utc-t.inbound_mct*interval '1 minute'
  UNION ALL
  SELECT 'outbound'::text,m.id,m.airline_id,m.airline_name,m.flight_number,
   m.destination_airport_key,
   round(EXTRACT(EPOCH FROM (m.departure_utc -
        (t.departure_utc+t.flight_duration)))/60)::int,
   t.outbound_mct
  FROM target_occurrences t
  JOIN matching_departures m ON m.origin_airport_key=t.destination_airport_key
  WHERE t.outbound_mct IS NOT NULL AND
   m.departure_utc BETWEEN
    t.departure_utc+t.flight_duration+t.outbound_mct*interval '1 minute'
    AND t.departure_utc+t.flight_duration+interval '12 hours'
 ), ranked AS (
  SELECT direction,id,airline_id,airline_name,flight_number,other_airport_key,
   min(transfer_minutes) AS shortest_transfer_minutes,
   min(minimum_transfer_minutes) as minimum_required_minutes,
   count(*) AS matched_occurrences
  FROM matched GROUP BY direction,id,airline_id,airline_name,flight_number,other_airport_key
 ), numbered AS (
  SELECT r.*,row_number() OVER(PARTITION BY direction
   ORDER BY shortest_transfer_minutes,flight_number,id) AS result_rank
  FROM ranked r
 )
 SELECT jsonb_build_object(
   'status','draft_only_connections_not_bookable',
   'scheduleId',p_schedule_id,
   'inboundMinimumMinutes',(SELECT inbound_mct FROM target),
   'outboundMinimumMinutes',(SELECT outbound_mct FROM target),
   'maximumMinutes',720,'weeksChecked',4,
   'inboundCount',(SELECT count(*) FROM ranked WHERE direction='inbound'),
   'outboundCount',(SELECT count(*) FROM ranked WHERE direction='outbound'),
   'inbound',coalesce((SELECT jsonb_agg(jsonb_build_object(
     'scheduleId',id,'flightNumber',flight_number,'airlineId',airline_id,
     'airlineName',airline_name,'otherAirportKey',other_airport_key,
     'shortestTransferMinutes',shortest_transfer_minutes,
     'minimumRequiredMinutes',minimum_required_minutes,
     'matchesInFourWeeks',matched_occurrences
     ) ORDER BY result_rank) FROM numbered
     WHERE direction='inbound' AND result_rank<=25),'[]'::jsonb),
   'outbound',coalesce((SELECT jsonb_agg(jsonb_build_object(
     'scheduleId',id,'flightNumber',flight_number,'airlineId',airline_id,
     'airlineName',airline_name,'otherAirportKey',other_airport_key,
     'shortestTransferMinutes',shortest_transfer_minutes,
     'minimumRequiredMinutes',minimum_required_minutes,
     'matchesInFourWeeks',matched_occurrences
     ) ORDER BY result_rank) FROM numbered
     WHERE direction='outbound' AND result_rank<=25),'[]'::jsonb),
   'capacityChecked',false,'interlineEnabled',true,
   'flightActivationAllowed',false
 ) INTO result;
 RETURN result;
END $func$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_schedule_connections_preview_v1(uuid,uuid)
 FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_owned_route_preview_v1(
 p_player_id uuid,p_airline_id uuid,p_schedule_id uuid,p_month smallint
) RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $function$
DECLARE s record; market jsonb; connections jsonb;
BEGIN
 SELECT d.world_id,d.origin_airport_key,d.destination_airport_key,
  d.flight_number,d.status INTO s
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 d
 JOIN airlinerra_game.airlines a ON a.id=d.airline_id
 WHERE a.id=p_airline_id AND a.owner_player_id=p_player_id AND a.world_id=1
  AND d.id=p_schedule_id AND d.status='draft';
 IF NOT FOUND THEN
  RAISE EXCEPTION USING ERRCODE='42501',MESSAGE='SECTION9_ROUTE_NOT_OWNED';
 END IF;
 market:=airlinerra_game.section9_route_market_preview_v1(
  s.world_id,s.origin_airport_key,s.destination_airport_key,p_month);
 connections:=airlinerra_game.section9_schedule_connections_preview_v1(
  p_player_id,p_schedule_id);
 RETURN jsonb_build_object('scheduleId',p_schedule_id,'flightNumber',s.flight_number,
  'status','draft_market_estimate','market',market,'connections',connections,
  'passengersAllocated',false,'cargoAllocated',false,'flightActivationAllowed',false);
END $function$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_owned_route_preview_v1(
 uuid,uuid,uuid,smallint) FROM PUBLIC,anon,authenticated;
