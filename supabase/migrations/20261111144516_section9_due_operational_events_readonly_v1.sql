-- Section 9: database-time-gated, READ-ONLY flight operation candidates.
-- This is for a FUTURE independent execution producer. A scheduled leg is
-- never proof that an aircraft actually departed or arrived.
-- No movement/economic writes, no signed evidence and no release changes.

CREATE OR REPLACE FUNCTION airlinerra_game.section9_due_operation_candidates_v1(
 p_airline uuid,p_aircraft uuid,p_utc_date date
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','pg_catalog'
AS $function$
DECLARE
 plan jsonb; candidate jsonb; due_events jsonb:='[]'::jsonb;
 observed_at timestamptz;future_count integer:=0;
 recorded_count integer:=0;eligible_count integer:=0;
BEGIN
 IF p_airline IS NULL OR p_aircraft IS NULL OR p_utc_date IS NULL
    OR p_utc_date NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-31'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_DUE_OPERATION_REQUEST'; END IF;
 observed_at:=clock_timestamp();
 plan:=airlinerra_game.section9_operated_day_candidates_for_aircraft_v1(
   p_airline,p_aircraft,p_utc_date);
 IF plan->>'status' IS DISTINCT FROM 'verified_operational_candidates_only'
 THEN RETURN jsonb_build_object(
  'status',coalesce(plan->>'status','operation_candidate_source_unavailable'),
  'worldId',1,'utcDate',p_utc_date,'dueEvents','[]'::jsonb,
  'dueCount',0,'futureCount',0,'alreadyRecordedCount',0,
  'readOnly',true,'requiresTrustedOperationDecision',true,
  'movementRecorded',false,'flightActivated',false,
  'bookingsCreated',false,'ledgerPosted',false); END IF;
 IF plan->>'readOnly' IS DISTINCT FROM 'true'
    OR plan->>'movementRecorded' IS DISTINCT FROM 'false'
    OR plan->>'requiresTrustedOperationDecision' IS DISTINCT FROM 'true'
    OR jsonb_typeof(plan->'candidates')<>'array'
 THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_UNTRUSTED_OPERATION_CANDIDATE_CONTRACT';END IF;

 FOR candidate IN SELECT value FROM jsonb_array_elements(plan->'candidates')
 LOOP
  eligible_count:=eligible_count+1;
  IF eligible_count>500 OR candidate->>'scheduledEventUtc' IS NULL
     OR candidate->>'eventId' IS NULL
  THEN RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_UNSAFE_DUE_EVENT_SOURCE'; END IF;
  IF (candidate->>'scheduledEventUtc')::timestamptz>observed_at
  THEN future_count:=future_count+1;
  ELSIF EXISTS(
   SELECT 1 FROM airlinerra_game.section9_operated_flight_movements_v1 m
   WHERE m.world_id=1 AND m.engine_event_id=candidate->>'eventId'
  ) THEN recorded_count:=recorded_count+1;
  ELSE due_events:=due_events||jsonb_build_array(candidate);
  END IF;
 END LOOP;
 RETURN jsonb_build_object(
  'status','verified_due_operation_candidates_only',
  'worldId',1,'airlineId',p_airline,'aircraftInventoryId',p_aircraft,
  'utcDate',p_utc_date,
  'sampledAtUtc',to_char(observed_at AT TIME ZONE 'UTC',
      'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
  'dueEvents',due_events,'dueCount',jsonb_array_length(due_events),
  'futureCount',future_count,'alreadyRecordedCount',recorded_count,
  'readOnly',true,'requiresTrustedOperationDecision',true,
  'movementRecorded',false,'flightActivated',false,
  'bookingsCreated',false,'ledgerPosted',false);
END $function$;

REVOKE ALL ON FUNCTION
 airlinerra_game.section9_due_operation_candidates_v1(uuid,uuid,date)
 FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION
 airlinerra_game.section9_due_operation_candidates_v1(uuid,uuid,date)
 IS 'Private read-only, database-wall-clock-filtered candidate events. No flight execution authority, no signing and no movement.';
