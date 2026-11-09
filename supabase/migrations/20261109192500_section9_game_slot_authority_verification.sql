-- Section 9: private independent GAME slot-clearance verifier.
-- Checks actual stand reservations and capacity, never grants user licences,
-- activates flights, issues HMACs, moves aircraft or handles money.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_verify_slot_clearance_source_v1(
 p_airline uuid,p_schedule uuid,p_expected_version integer,p_game_day date
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
SET search_path TO 'airlinerra_game','airlinerra','pg_catalog'
AS $f$
DECLARE
 target record;world_row record;clock_row record;
 slot_check jsonb;restriction_check jsonb;
 proposed_count integer;reserved_count integer;mismatch_count integer;
 capacity_count integer;proof text;
 blockers text[]:=ARRAY[]::text[];
BEGIN
 IF p_airline IS NULL OR p_schedule IS NULL
  OR p_expected_version IS NULL OR p_expected_version<1
  OR p_game_day IS NULL OR p_game_day NOT BETWEEN
      DATE '2000-01-01' AND DATE '2199-12-01'
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_SLOT_CLEARANCE_REQUEST';END IF;

 SELECT s.*,f.fleet_status,f.configuration_id AS fleet_configuration
 INTO target
 FROM airlinerra_game.airline_flight_schedule_drafts_v1 s
 JOIN airlinerra_game.airline_aircraft_inventory f
  ON f.id=s.aircraft_inventory_id AND f.airline_id=s.airline_id
 WHERE s.id=p_schedule AND s.airline_id=p_airline AND s.world_id=1
 FOR SHARE OF s,f;
 IF NOT FOUND THEN RAISE EXCEPTION USING ERRCODE='42501',
  MESSAGE='SECTION9_SLOT_CLEARANCE_SCHEDULE_NOT_FOUND';END IF;
 IF target.version IS DISTINCT FROM p_expected_version OR
  target.status IS DISTINCT FROM 'draft' OR
  target.operationally_verified IS DISTINCT FROM false
 THEN RETURN jsonb_build_object(
  'status','blocked_stale_or_non_draft_schedule',
  'worldId',1,'verified',false,'readOnly',true,'flightActivated',false,
  'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);END IF;
 SELECT state,opens_at INTO world_row
 FROM public.airlinerra_game_worlds WHERE id=1 FOR SHARE;
 SELECT confirmed_game_date,clock_source,last_verified_at,engine_proof_ref
 INTO clock_row FROM airlinerra_game.holding_world_clock_v1
 WHERE world_id=1 FOR SHARE;
 IF world_row.state IS DISTINCT FROM 'active'
  OR world_row.opens_at IS NULL
  OR world_row.opens_at>clock_timestamp()
  OR clock_row.clock_source IS DISTINCT FROM 'authoritative_game_engine'
  OR clock_row.confirmed_game_date IS DISTINCT FROM p_game_day
  OR clock_row.last_verified_at IS NULL
  OR length(coalesce(clock_row.engine_proof_ref,''))<12
  OR NOT EXISTS(
   SELECT 1 FROM airlinerra_game.section9_verified_game_tick_receipts_v1 r
   WHERE r.world_id=1 AND r.game_date=p_game_day)
 THEN RETURN jsonb_build_object(
  'status','blocked_unverified_world_or_game_day',
  'worldId',1,'verified',false,'readOnly',true,'flightActivated',false,
  'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);END IF;

 -- The schedule writer locks these same per-airport capacity records before
 -- changing recurring reservations. Hold read locks to prevent changes to
 -- the counters while this source-verification statement is executing.
 PERFORM 1 FROM airlinerra_game.section6_airport_slot_capacity_v1 c
 WHERE c.world_id=1 AND c.airport_key IN
  (target.origin_airport_key,target.destination_airport_key)
 ORDER BY c.airport_key FOR SHARE;
 SELECT count(*)::integer INTO capacity_count
 FROM airlinerra_game.section6_airport_slot_capacity_v1 c
 WHERE c.world_id=1 AND c.airport_key IN
  (target.origin_airport_key,target.destination_airport_key);
 IF capacity_count<>2 THEN
  blockers:=array_append(blockers,'CAPACITY_CONFIGURATION_MISSING');END IF;
 IF target.fleet_status IS DISTINCT FROM 'in_service'
  OR target.fleet_configuration IS DISTINCT FROM target.configuration_id
 THEN blockers:=array_append(blockers,'FLEET_CONFIGURATION_CHANGED');END IF;
 IF NOT EXISTS(
  SELECT 1 FROM airlinerra_game.section9_verified_schedule_capacity_v1 cap
  WHERE cap.schedule_id=p_schedule AND cap.airline_id=p_airline
   AND cap.schedule_version=p_expected_version
 ) THEN blockers:=array_append(blockers,'VERIFIED_AIRCRAFT_CAPACITY_MISSING');END IF;

 restriction_check:=airlinerra_game.section5_weekly_route_restriction_gate_v1(
  1::smallint,target.origin_airport_key,target.destination_airport_key,
  target.configuration_id,target.reference_departure_utc,
  target.reference_arrival_utc,target.weekly_schedule);
 IF restriction_check->>'weeklyTimetableChecked' IS DISTINCT FROM 'true'
  OR (restriction_check->>'gameHardBlocked') IS DISTINCT FROM 'false'
  OR (restriction_check->>'needsReview') IS DISTINCT FROM 'false'
 THEN blockers:=array_append(blockers,'UNRESOLVED_AIRPORT_RESTRICTION');END IF;

 SELECT count(*)::integer INTO proposed_count
 FROM airlinerra_game.section6_weekly_slot_proposals_v1(
  1::smallint,target.origin_airport_key,target.destination_airport_key,
  target.reference_departure_utc,target.reference_arrival_utc,
  target.weekly_schedule,target.departure_stand_type,target.arrival_stand_type);
 SELECT count(*)::integer INTO reserved_count
 FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 r
 WHERE r.schedule_id=p_schedule;
 SELECT count(*)::integer INTO mismatch_count FROM (
  (SELECT p.airport_key,p.stand_type,p.direction,p.weekday,p.minute_of_day
   FROM airlinerra_game.section6_weekly_slot_proposals_v1(
    1::smallint,target.origin_airport_key,target.destination_airport_key,
    target.reference_departure_utc,target.reference_arrival_utc,
    target.weekly_schedule,target.departure_stand_type,target.arrival_stand_type) p
   EXCEPT
   SELECT r.airport_key,r.stand_type,r.direction,r.weekday,r.minute_of_day
   FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 r
   WHERE r.schedule_id=p_schedule)
  UNION ALL
  (SELECT r.airport_key,r.stand_type,r.direction,r.weekday,r.minute_of_day
   FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 r
   WHERE r.schedule_id=p_schedule
   EXCEPT
   SELECT p.airport_key,p.stand_type,p.direction,p.weekday,p.minute_of_day
   FROM airlinerra_game.section6_weekly_slot_proposals_v1(
    1::smallint,target.origin_airport_key,target.destination_airport_key,
    target.reference_departure_utc,target.reference_arrival_utc,
    target.weekly_schedule,target.departure_stand_type,target.arrival_stand_type) p)
 ) mismatched;
 IF proposed_count=0 OR proposed_count<>reserved_count OR mismatch_count<>0
 THEN blockers:=array_append(blockers,'RECURRING_SLOT_RESERVATIONS_MISMATCH');END IF;
 slot_check:=airlinerra_game.section6_weekly_slot_preflight_v1(
  1::smallint,target.origin_airport_key,target.destination_airport_key,
  target.reference_departure_utc,target.reference_arrival_utc,
  target.weekly_schedule,target.departure_stand_type,target.arrival_stand_type,
  p_schedule);
 IF slot_check->>'available' IS DISTINCT FROM 'true' OR
  slot_check->>'departureAvailable' IS DISTINCT FROM 'true' OR
  slot_check->>'arrivalAvailable' IS DISTINCT FROM 'true'
 THEN blockers:=array_append(blockers,'AIRPORT_CAPACITY_RECHECK_FAILED');END IF;

 IF cardinality(blockers)>0 THEN
  RETURN jsonb_build_object(
   'status','blocked_slot_clearance_evidence',
   'worldId',1,'verified',false,'readOnly',true,
   'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
   'blockers',to_jsonb(blockers),
   'proposedSlots',proposed_count,'reservedSlots',reserved_count,
   'mismatchedSlots',mismatch_count,'flightActivated',false,
   'movementRecorded',false,'bookingsCreated',false,'ledgerPosted',false);
 END IF;

 proof:=md5(jsonb_build_object(
  'scheduleId',target.id,'version',target.version,
  'worldGameDate',p_game_day,
  'model','section6_weekly_stand_capacity_v1',
  'restrictionSnapshot',restriction_check,
  'capacitySource',(SELECT to_jsonb(v)
    FROM airlinerra_game.section9_verified_schedule_capacity_v1 v
    WHERE v.schedule_id=p_schedule AND v.schedule_version=p_expected_version),
  'proposedSlotCount',proposed_count,
  'reservations',(SELECT coalesce(jsonb_agg(to_jsonb(r) ORDER BY
    r.airport_key,r.stand_type,r.direction,r.weekday,r.minute_of_day),
    '[]'::jsonb)
    FROM airlinerra_game.section6_weekly_airport_slot_reservations_v1 r
    WHERE r.schedule_id=p_schedule),
  'capacityRows',(SELECT coalesce(jsonb_agg(to_jsonb(c) ORDER BY
    c.airport_key),'[]'::jsonb)
    FROM airlinerra_game.section6_airport_slot_capacity_v1 c
    WHERE c.world_id=1 AND c.airport_key IN
     (target.origin_airport_key,target.destination_airport_key))
 )::text);
 RETURN jsonb_build_object(
  'status','verified_game_airport_slots',
  'worldId',1,'airlineId',p_airline,
  'scheduleId',p_schedule,'scheduleVersion',p_expected_version,
  'gameDate',p_game_day,'validThroughGameDate',p_game_day+28,
  'clearanceType','airport_slot_capacity',
  'sourceKind','verified_airport_slot_engine',
  'sourceReference','game-slot-capacity-v1-'||proof,
  'reviewerReference','independent-game-slot-authority-v1',
  'proofFingerprint',proof,
  'verified',true,'readOnly',true,
  'proposedSlots',proposed_count,'reservedSlots',reserved_count,
  'flightActivated',false,'movementRecorded',false,
  'bookingsCreated',false,'ledgerPosted',false);
END $f$;
REVOKE ALL ON FUNCTION
 airlinerra_game.section9_verify_slot_clearance_source_v1(uuid,uuid,integer,date)
 FROM PUBLIC,anon,authenticated;
COMMENT ON FUNCTION airlinerra_game.section9_verify_slot_clearance_source_v1(
 uuid,uuid,integer,date) IS
 'Read-only game slot clearance evidence requiring signed game clock and exact existing reservation/capacity. Not a legal airport slot certificate. Only a separately signed private issuer may submit its proof.';
