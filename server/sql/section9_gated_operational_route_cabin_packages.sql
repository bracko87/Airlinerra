-- Owner-validated, immutable service terms for a verified operational schedule.
ALTER TABLE airlinerra_game.section9_onboard_service_release_v1 ADD COLUMN custom_route_packages_enabled boolean NOT NULL DEFAULT false;
CREATE TABLE airlinerra_game.section9_route_onboard_packages_v1(
 schedule_id uuid PRIMARY KEY REFERENCES airlinerra_game.airline_flight_schedule_drafts_v1(id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 schedule_version integer NOT NULL CHECK(schedule_version>=1),
 package_id text NOT NULL CHECK(package_id ~ '^(none|basic|pkg-[1-9][0-9]{0,5})$'),
 package_version integer NOT NULL CHECK(package_version>=0),
 package_items jsonb NOT NULL CHECK(jsonb_typeof(package_items)='object'),
 created_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE airlinerra_game.section9_route_onboard_packages_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_route_onboard_packages_v1 FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_resolve_route_onboard_package_v1(p_player uuid,p_airline uuid,p_package text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE saved record; item jsonb; items jsonb; unsupported jsonb; normalized jsonb:='{}'; c record; mode text; price int; v int:=0;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_ROUTE_PACKAGE';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.airlines WHERE id=p_airline AND owner_player_id=p_player AND world_id=1) THEN RETURN jsonb_build_object('status','blocked_airline_not_owned');END IF;
 IF p_package IS NULL OR p_package !~ '^(none|basic|pkg-[1-9][0-9]{0,5})$' THEN RETURN jsonb_build_object('status','blocked_invalid_cabin_package');END IF;
 IF p_package='none' THEN items:='{}';
 ELSIF p_package='basic' THEN items:='{"water":{"mode":"included","onboardCents":350}}';
 ELSE
  IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_onboard_service_release_v1 WHERE world_id=1 AND snapshot_enabled AND settlement_enabled AND custom_route_packages_enabled) THEN RETURN jsonb_build_object('status','blocked_custom_cabin_packages_not_released');END IF;
  SELECT cset.version,pkg->'items' AS items INTO saved
  FROM airlinerra_game.airline_cabin_service_settings_v1 cset CROSS JOIN LATERAL jsonb_array_elements(cset.state->'packages') pkg
  WHERE cset.airline_id=p_airline AND cset.world_id=1 AND pkg->>'id'=p_package;
  IF NOT FOUND OR jsonb_typeof(saved.items) IS DISTINCT FROM 'object' THEN RETURN jsonb_build_object('status','blocked_cabin_package_not_saved');END IF;
  items:=saved.items;v:=saved.version;
 END IF;
 FOR c IN SELECT * FROM airlinerra_game.section9_onboard_service_catalog_v1 ORDER BY sort_order LOOP
  item:=coalesce(items->c.item_id,'{}');
  mode:=coalesce(item->>'mode','off');
  IF mode NOT IN('off','included','onboard') THEN RETURN jsonb_build_object('status','blocked_invalid_cabin_package');END IF;
  IF mode='off' THEN CONTINUE;END IF;
  IF NOT c.basic_delivery_supported THEN RETURN jsonb_build_object('status','blocked_cabin_service_not_supported','details',jsonb_build_object('itemId',c.item_id));END IF;
  price:=0;
  IF mode='onboard' THEN
   IF coalesce(item->>'onboardCents','') !~ '^[0-9]{1,6}$' THEN RETURN jsonb_build_object('status','blocked_invalid_cabin_package');END IF;
   price:=(item->>'onboardCents')::int;
   IF price NOT BETWEEN 0 AND 100000 THEN RETURN jsonb_build_object('status','blocked_invalid_cabin_package');END IF;
  END IF;
  normalized:=normalized||jsonb_build_object(c.item_id,jsonb_build_object('mode',mode,'onboardCents',price));
 END LOOP;
 RETURN jsonb_build_object('status','route_cabin_package_valid','packageId',p_package,'packageVersion',v,'items',normalized);
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_resolve_route_onboard_package_v1(uuid,uuid,text) FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_create_active_route_with_cabin_v1(p_player uuid,p_airline uuid,p_aircraft uuid,p_flight text,p_origin text,p_destination text,p_weekly jsonb,p_depart_stand text,p_arrive_stand text,p_turnaround integer,p_fare numeric,p_package text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE pkg jsonb; result jsonb; sid uuid; changed int;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_GAME_ROUTE_CREATION_ONLY';END IF;
 pkg:=airlinerra_game.section9_resolve_route_onboard_package_v1(p_player,p_airline,coalesce(p_package,'basic'));
 IF pkg->>'status' IS DISTINCT FROM 'route_cabin_package_valid' THEN RETURN pkg||jsonb_build_object('routeCreated',false);END IF;
 -- No route or slots are saved when package validation fails.
 result:=airlinerra_game.section9_create_active_route_from_weekly_v1(p_player,p_airline,p_aircraft,p_flight,p_origin,p_destination,p_weekly,p_depart_stand,p_arrive_stand,p_turnaround,p_fare);
 IF result->>'routeCreated'='true' THEN
  sid:=(result->>'scheduleId')::uuid;
  INSERT INTO airlinerra_game.section9_route_onboard_packages_v1(schedule_id,airline_id,schedule_version,package_id,package_version,package_items)
  VALUES(sid,p_airline,(result->>'scheduleVersion')::int,pkg->>'packageId',(pkg->>'packageVersion')::int,pkg->'items');
  UPDATE airlinerra_game.airline_route_planning_drafts_v1 SET planning_options=jsonb_set(planning_options,'{service,cabinPackageId}',to_jsonb(pkg->>'packageId'),true)
  WHERE airline_id=p_airline AND flight_number=p_flight AND aircraft_inventory_id=p_aircraft;
  GET DIAGNOSTICS changed=ROW_COUNT;
  IF changed<>1 THEN RAISE EXCEPTION 'ROUTE_CABIN_METADATA_MISSING_ROLLBACK';END IF;
  result:=result||jsonb_build_object('cabinPackageId',pkg->>'packageId','cabinPackageVersion',(pkg->>'packageVersion')::int);
 END IF;
 RETURN result;
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_create_active_route_with_cabin_v1(uuid,uuid,uuid,text,text,text,jsonb,text,text,integer,numeric,text) FROM PUBLIC,anon,authenticated,service_role;
CREATE OR REPLACE FUNCTION airlinerra_game.section9_snapshot_onboard_departure_v1(p_physical text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'airlinerra_game'
AS $function$
DECLARE f record; route_package record; pkg text; items jsonb; ver int:=0; rep numeric; inserted int;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_ONBOARD_SNAPSHOT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_onboard_service_release_v1 WHERE world_id=1 AND snapshot_enabled) THEN RETURN jsonb_build_object('status','onboard_snapshot_not_released');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_onboard_departure_snapshots_v1 WHERE physical_flight_id=p_physical) THEN RETURN jsonb_build_object('status','onboard_snapshot_already_captured','replayed',true);END IF;
 SELECT o.id,o.airline_id,o.schedule_id,o.schedule_version,o.booked_seats,m.engine_event_id,m.actual_event_utc,p.planning_options
 INTO f FROM airlinerra_game.section9_operated_flight_movements_v1 m
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.schedule_id=m.schedule_id AND o.airline_id=m.airline_id
  AND o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text=m.flight_occurrence_id
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.version=o.schedule_version
 LEFT JOIN airlinerra_game.airline_route_planning_drafts_v1 p ON p.airline_id=s.airline_id AND p.flight_number=s.flight_number
  AND p.aircraft_inventory_id=s.aircraft_inventory_id AND p.origin_airport_key=s.origin_airport_key AND p.destination_airport_key=s.destination_airport_key
  AND p.weekly_schedule=s.weekly_schedule
 WHERE m.flight_occurrence_id=p_physical AND m.phase='departed' AND o.world_id=1 AND o.booking_status='closed';
 IF NOT FOUND THEN RETURN jsonb_build_object('status','onboard_snapshot_missing_verified_departure_or_route');END IF;
 SELECT * INTO route_package FROM airlinerra_game.section9_route_onboard_packages_v1 WHERE schedule_id=f.schedule_id AND airline_id=f.airline_id AND schedule_version=f.schedule_version;
 IF FOUND THEN
  pkg:=route_package.package_id;items:=route_package.package_items;ver:=route_package.package_version;
 ELSE
  -- Legacy operational route creator only ever supported Basic.
  pkg:=f.planning_options->'service'->>'cabinPackageId';
  IF pkg='none' THEN items:='{}'::jsonb;
  ELSIF pkg='basic' THEN items:='{"water":{"mode":"included","onboardCents":350}}'::jsonb;
  ELSE RETURN jsonb_build_object('status','onboard_snapshot_unsupported_package');END IF;
 END IF;
 rep:=coalesce((airlinerra_game.section9_airline_reputation_v1(f.airline_id)->>'reputation')::numeric,70);
 INSERT INTO airlinerra_game.section9_onboard_departure_snapshots_v1(physical_flight_id,occurrence_id,airline_id,departure_event_id,departed_at,passengers,package_id,package_version,package_items,reputation_score)
 VALUES(p_physical,f.id,f.airline_id,f.engine_event_id,f.actual_event_utc,f.booked_seats,pkg,ver,items,rep) ON CONFLICT(physical_flight_id) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 RETURN jsonb_build_object('status','onboard_snapshot_captured','replayed',inserted=0,'packageId',pkg,'passengers',f.booked_seats,'ledgerPosted',false);
END;
$function$;
