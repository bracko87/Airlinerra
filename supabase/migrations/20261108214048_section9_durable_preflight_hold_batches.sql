-- Section 9: private, durable allocation manifests with transaction-atomic
-- batches. NO ticket issuance, actual booking, or airline ledger posting.
-- Schedules remain draft-only until a separate certified operations engine.
-- Failed transactions roll back their capacity holds AND cursor together.
CREATE TABLE IF NOT EXISTS airlinerra_game.section9_capacity_hold_plans_v1 (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 start_game_date date NOT NULL CHECK(start_game_date BETWEEN
   DATE '2000-01-01' AND DATE '2199-12-01'),
 market_days smallint NOT NULL CHECK(market_days BETWEEN 2 AND 7),
 manifest_sha256 text NOT NULL CHECK(
   manifest_sha256 ~ '^[0-9a-f]{64}$'),
 allocation_count integer NOT NULL CHECK(
   allocation_count BETWEEN 0 AND 100000),
 next_allocation_seq integer NOT NULL DEFAULT 0 CHECK(
   next_allocation_seq BETWEEN 0 AND 100000),
 status text NOT NULL DEFAULT 'staging' CHECK(status IN
   ('staging','ready','completed','blocked')),
 blocked_reason text,
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now(),
 completed_at timestamptz,
 UNIQUE(world_id,start_game_date,market_days),
 CHECK(next_allocation_seq<=allocation_count),
 CHECK(status<>'completed' OR
   (next_allocation_seq=allocation_count AND completed_at IS NOT NULL))
);
ALTER TABLE airlinerra_game.section9_capacity_hold_plans_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_capacity_hold_plans_v1
 FROM PUBLIC,anon,authenticated;

CREATE TABLE IF NOT EXISTS airlinerra_game.section9_capacity_hold_plan_items_v1 (
 plan_id uuid NOT NULL REFERENCES
   airlinerra_game.section9_capacity_hold_plans_v1(id) ON DELETE CASCADE,
 sequence integer NOT NULL CHECK(sequence BETWEEN 0 AND 99999),
 allocation_key text NOT NULL CHECK(allocation_key ~ '^s9g1:[0-9a-f]{64}$'),
 physical_flight_ids text[] NOT NULL CHECK(
  cardinality(physical_flight_ids) BETWEEN 1 AND 2),
 passengers integer NOT NULL CHECK(passengers BETWEEN 0 AND 1000),
 cargo_tonnes numeric(12,3) NOT NULL CHECK(
  cargo_tonnes BETWEEN 0 AND 1000),
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(plan_id,sequence),
 UNIQUE(plan_id,allocation_key),
 CHECK(passengers>0 OR cargo_tonnes>0)
);
ALTER TABLE airlinerra_game.section9_capacity_hold_plan_items_v1
 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_capacity_hold_plan_items_v1
 FROM PUBLIC,anon,authenticated;
COMMENT ON TABLE airlinerra_game.section9_capacity_hold_plan_items_v1 IS
 'Internal immutable ordered shared-calendar allocation plan. Never treated as a ticket or ledger entry.';

CREATE OR REPLACE FUNCTION airlinerra_game.section9_create_hold_plan_v1(
 p_start date,p_days integer,p_manifest text,p_expected integer
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j airlinerra_game.section9_capacity_hold_plans_v1%ROWTYPE;
BEGIN
 IF p_start IS NULL OR p_start NOT BETWEEN DATE '2000-01-01' AND DATE '2199-12-01'
  OR p_days NOT BETWEEN 2 AND 7
  OR p_manifest IS NULL OR p_manifest !~ '^[0-9a-f]{64}$'
  OR p_expected NOT BETWEEN 0 AND 100000
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_HOLD_PLAN';END IF;
 INSERT INTO airlinerra_game.section9_capacity_hold_plans_v1(
  start_game_date,market_days,manifest_sha256,allocation_count)
 VALUES(p_start,p_days,p_manifest,p_expected)
 ON CONFLICT(world_id,start_game_date,market_days) DO NOTHING;
 SELECT * INTO j FROM airlinerra_game.section9_capacity_hold_plans_v1
  WHERE world_id=1 AND start_game_date=p_start AND market_days=p_days
  FOR UPDATE;
 IF NOT FOUND OR j.manifest_sha256<>p_manifest OR j.allocation_count<>p_expected
 THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_CHANGED_SHARED_CALENDAR_PLAN';END IF;
 RETURN jsonb_build_object('planId',j.id,'status',j.status,
  'expected',j.allocation_count,'nextSequence',j.next_allocation_seq,
  'preflightOnly',true,'bookingsCreated',false,'ledgerPosted',false);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_create_hold_plan_v1(
 date,integer,text,integer) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_stage_hold_plan_chunk_v1(
 p_plan uuid,p_items jsonb
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j airlinerra_game.section9_capacity_hold_plans_v1%ROWTYPE;
 a jsonb; existing airlinerra_game.section9_capacity_hold_plan_items_v1%ROWTYPE;
 seq integer; a_key text; ids text[]; seats integer; weight numeric;
 item_count integer:=0; new_count integer:=0; rows_changed integer;
BEGIN
 SELECT * INTO j FROM airlinerra_game.section9_capacity_hold_plans_v1
  WHERE id=p_plan FOR UPDATE;
 IF NOT FOUND OR j.status<>'staging' THEN
  RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_HOLD_PLAN_NOT_STAGING';END IF;
 IF p_items IS NULL OR jsonb_typeof(p_items)<>'array'
  OR jsonb_array_length(p_items) NOT BETWEEN 1 AND 100
  OR octet_length(p_items::text)>150000
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_PLAN_CHUNK';END IF;
 FOR a IN SELECT value FROM jsonb_array_elements(p_items)
 LOOP
  IF jsonb_typeof(a)<>'object'
   OR coalesce(a->>'sequence','') !~ '^[0-9]{1,6}$'
   OR coalesce(a->>'allocationKey','') !~ '^s9g1:[0-9a-f]{64}$'
   OR jsonb_typeof(a->'flightIds')<>'array'
   OR jsonb_array_length(a->'flightIds') NOT BETWEEN 1 AND 2
   OR coalesce(a->>'passengers','') !~ '^[0-9]{1,4}$'
   OR coalesce(a->>'cargoTonnes','') !~ '^[0-9]{1,4}([.][0-9]{1,3})?$'
  THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_PLAN_ALLOCATION';END IF;
  seq:=(a->>'sequence')::integer;
  a_key:=a->>'allocationKey';
  seats:=(a->>'passengers')::integer;
  weight:=(a->>'cargoTonnes')::numeric;
  SELECT array_agg(v.value ORDER BY v.ordinality) INTO ids
  FROM jsonb_array_elements_text(a->'flightIds')
   WITH ORDINALITY AS v(value,ordinality);
  IF seq<0 OR seq>=j.allocation_count OR seats>1000 OR
    weight>1000 OR (seats=0 AND weight=0) OR
    cardinality(ids) NOT BETWEEN 1 AND 2 OR
    EXISTS(SELECT 1 FROM unnest(ids) AS x(id)
     WHERE id !~ '^[0-9a-fA-F-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[0-9]{1,4}$')
    OR (cardinality(ids)=2 AND ids[1]=ids[2])
  THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INVALID_PLAN_CAPACITY_OR_LEGS';END IF;
  INSERT INTO airlinerra_game.section9_capacity_hold_plan_items_v1(
   plan_id,sequence,allocation_key,physical_flight_ids,passengers,cargo_tonnes)
  VALUES(p_plan,seq,a_key,ids,seats,weight)
  ON CONFLICT(plan_id,sequence) DO NOTHING;
  GET DIAGNOSTICS rows_changed=ROW_COUNT;
  new_count:=new_count+rows_changed;
  SELECT * INTO existing FROM airlinerra_game.section9_capacity_hold_plan_items_v1
    WHERE plan_id=p_plan AND sequence=seq;
  IF NOT FOUND OR existing.allocation_key IS DISTINCT FROM a_key OR
    existing.physical_flight_ids IS DISTINCT FROM ids OR
    existing.passengers IS DISTINCT FROM seats OR
    existing.cargo_tonnes IS DISTINCT FROM weight
  THEN RAISE EXCEPTION USING ERRCODE='23505',
   MESSAGE='SECTION9_HOLD_PLAN_IMMUTABLE_CONFLICT';END IF;
  item_count:=item_count+1;
 END LOOP;
 RETURN jsonb_build_object('status','staged','planId',p_plan,
  'received',item_count,'newItems',new_count,
  'preflightOnly',true,'bookingsCreated',false,'ledgerPosted',false);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_stage_hold_plan_chunk_v1(
 uuid,jsonb) FROM PUBLIC,anon,authenticated;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_seal_hold_plan_v1(
 p_plan uuid
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j airlinerra_game.section9_capacity_hold_plans_v1%ROWTYPE;
 n integer;last_seq integer;
BEGIN
 SELECT * INTO j FROM airlinerra_game.section9_capacity_hold_plans_v1
 WHERE id=p_plan FOR UPDATE;
 IF NOT FOUND OR j.status NOT IN ('staging','ready','completed')
 THEN RAISE EXCEPTION USING ERRCODE='42501',
   MESSAGE='SECTION9_HOLD_PLAN_NOT_SEALABLE';END IF;
 SELECT count(*),max(sequence) INTO n,last_seq FROM
  airlinerra_game.section9_capacity_hold_plan_items_v1
 WHERE plan_id=p_plan;
 IF n<>j.allocation_count OR (n>0 AND last_seq<>n-1)
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_INCOMPLETE_HOLD_PLAN';END IF;
 IF j.status='staging' THEN
  UPDATE airlinerra_game.section9_capacity_hold_plans_v1
   SET status=CASE WHEN n=0 THEN 'completed' ELSE 'ready' END,
    completed_at=CASE WHEN n=0 THEN clock_timestamp() ELSE NULL END,
    updated_at=clock_timestamp()
   WHERE id=p_plan;
 END IF;
 RETURN jsonb_build_object('status',CASE WHEN n=0 THEN 'completed'
  ELSE COALESCE(NULLIF(j.status,'staging'),'ready') END,
  'planId',p_plan,'expected',n,
  'preflightOnly',true,'bookingsCreated',false,'ledgerPosted',false);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_seal_hold_plan_v1(uuid)
 FROM PUBLIC,anon,authenticated;

-- All selected holds, flight initialization and the cursor checkpoint happen
-- within one PostgreSQL transaction. No durable "running" leases to strand.
-- SKIP LOCKED prevents two workers processing the same plan concurrently.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_apply_hold_plan_batch_v1(
 p_plan uuid,p_limit integer DEFAULT 50
) RETURNS jsonb LANGUAGE plpgsql VOLATILE SECURITY INVOKER
 SET search_path TO 'airlinerra_game','pg_catalog'
AS $f$
DECLARE j airlinerra_game.section9_capacity_hold_plans_v1%ROWTYPE;
 a record;physical text;idx integer;action jsonb;outcome jsonb;
 progressed integer:=0;seq integer;
BEGIN
 IF p_plan IS NULL OR p_limit NOT BETWEEN 1 AND 100
 THEN RAISE EXCEPTION USING ERRCODE='22023',
  MESSAGE='SECTION9_INVALID_HOLD_BATCH';END IF;
 SELECT * INTO j FROM airlinerra_game.section9_capacity_hold_plans_v1
  WHERE id=p_plan FOR UPDATE SKIP LOCKED;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','busy_or_unknown',
   'planId',p_plan,'preflightOnly',true,
   'bookingsCreated',false,'ledgerPosted',false);END IF;
 IF j.status='completed' THEN
  RETURN jsonb_build_object('status','completed','planId',p_plan,
   'processed',0,'nextSequence',j.next_allocation_seq,'expected',j.allocation_count,
   'preflightOnly',true,'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 IF j.status<>'ready' THEN
  RETURN jsonb_build_object('status','not_ready','planId',p_plan,
   'planStatus',j.status,'preflightOnly',true,
   'bookingsCreated',false,'ledgerPosted',false);
 END IF;
 seq:=j.next_allocation_seq;
 FOR a IN SELECT * FROM airlinerra_game.section9_capacity_hold_plan_items_v1
  WHERE plan_id=p_plan AND sequence>=j.next_allocation_seq
  ORDER BY sequence LIMIT p_limit
 LOOP
  IF a.sequence<>seq THEN
   RAISE EXCEPTION USING ERRCODE='22023',
    MESSAGE='SECTION9_NONCONTIGUOUS_HOLD_PLAN';END IF;
  -- Each occurrence is revalidated against active operational schedule,
  -- physical aircraft payload, exact weekly slots and fare version.
  FOR idx IN 1..cardinality(a.physical_flight_ids) LOOP
   physical:=a.physical_flight_ids[idx];
   IF physical !~ '^[0-9a-fA-F-]{36}:[0-9]{4}-[0-9]{2}-[0-9]{2}:[0-9]{1,4}$'
   THEN RAISE EXCEPTION USING ERRCODE='22023',
     MESSAGE='SECTION9_INVALID_HOLD_PHYSICAL_KEY';END IF;
   action:=airlinerra_game.section9_initialize_verified_occurrence_v1(
    split_part(physical,':',1)::uuid,
    split_part(physical,':',2)::date,
    split_part(physical,':',3)::integer);
   IF action->>'status'<>'capacity_preflight_initialized' OR
    action->>'physicalFlightId'<>physical
   THEN RAISE EXCEPTION USING ERRCODE='42501',
     MESSAGE='SECTION9_HOLD_FLIGHT_NOT_VERIFIED';END IF;
  END LOOP;
  outcome:=airlinerra_game.section9_hold_verified_itinerary_v1(
   a.allocation_key,a.physical_flight_ids,a.passengers,a.cargo_tonnes);
  IF outcome->>'status'<>'preflight_held'
    OR outcome->>'bookingsCreated'<>'false'
    OR outcome->>'ledgerPosted'<>'false'
  THEN RAISE EXCEPTION USING ERRCODE='42501',
    MESSAGE='SECTION9_HOLD_BOOKING_NOT_AUTHORIZED';END IF;
  progressed:=progressed+1;seq:=seq+1;
 END LOOP;
 IF progressed=0 AND j.next_allocation_seq<>j.allocation_count
 THEN RAISE EXCEPTION USING ERRCODE='22023',
   MESSAGE='SECTION9_HOLD_PLAN_MISSING_ITEMS'; END IF;
 UPDATE airlinerra_game.section9_capacity_hold_plans_v1
 SET next_allocation_seq=seq,
  status=CASE WHEN seq=allocation_count THEN 'completed' ELSE 'ready' END,
  completed_at=CASE WHEN seq=allocation_count THEN clock_timestamp() ELSE NULL END,
  updated_at=clock_timestamp()
 WHERE id=p_plan;
 RETURN jsonb_build_object('status',CASE WHEN seq=j.allocation_count THEN
   'completed' ELSE 'ready' END,'planId',p_plan,
  'processed',progressed,'nextSequence',seq,'expected',j.allocation_count,
  'preflightOnly',true,'bookingsCreated',false,'ledgerPosted',false);
END $f$;
REVOKE EXECUTE ON FUNCTION airlinerra_game.section9_apply_hold_plan_batch_v1(
 uuid,integer) FROM PUBLIC,anon,authenticated;

COMMENT ON TABLE airlinerra_game.section9_capacity_hold_plans_v1 IS
 'Server-only immutable demand batch manifest; no cash or bookings. Each batch advances only atomically with its physical holds.';
