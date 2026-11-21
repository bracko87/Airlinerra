-- Onboard services, foundational game model. All money and reputation effects gated.
CREATE TABLE airlinerra_game.section9_onboard_service_release_v1(
 world_id smallint PRIMARY KEY CHECK(world_id=1),
 snapshot_enabled boolean NOT NULL DEFAULT false,
 settlement_enabled boolean NOT NULL DEFAULT false,
 satisfaction_enabled boolean NOT NULL DEFAULT false
);
INSERT INTO airlinerra_game.section9_onboard_service_release_v1(world_id) VALUES(1);
CREATE TABLE airlinerra_game.section9_onboard_service_catalog_v1(
 sort_order int UNIQUE NOT NULL, item_id text PRIMARY KEY,
 unit_cost_cents integer NOT NULL CHECK(unit_cost_cents>=0),
 included_weight integer NOT NULL CHECK(included_weight>=0),
 default_stock_per_100 int NOT NULL CHECK(default_stock_per_100 BETWEEN 0 AND 200),
 digital boolean NOT NULL, base_purchase_rate numeric NOT NULL CHECK(base_purchase_rate BETWEEN 0 AND 1),
 reference_price_cents int NOT NULL CHECK(reference_price_cents>0),
 basic_delivery_supported boolean NOT NULL
);
INSERT INTO airlinerra_game.section9_onboard_service_catalog_v1 VALUES
(1,'water',65,0,100,false,.28,350,true),
(2,'coffee',150,5,20,false,.14,500,true),
(3,'softdrink',175,6,25,false,.18,550,true),
(4,'alcohol',375,5,10,false,.09,1050,false),
(5,'snack',225,8,20,false,.15,650,true),
(6,'sandwich',525,9,12,false,.10,1350,true),
(7,'hotmeal',950,14,10,false,.07,2200,false),
(8,'specialmeal',1100,6,3,false,.018,2800,false),
(9,'newspaper',55,3,0,true,.07,350,true),
(10,'wifi',225,10,0,true,.12,1200,false),
(11,'fullwifi',550,10,0,true,.055,2300,false),
(12,'entertainment',200,9,0,true,.10,900,false),
(13,'blanket',450,4,10,false,.06,1400,true),
(14,'amenity',675,5,5,false,.025,1900,true);

CREATE TABLE airlinerra_game.section9_onboard_departure_snapshots_v1(
 physical_flight_id text PRIMARY KEY,
 occurrence_id uuid NOT NULL UNIQUE REFERENCES airlinerra_game.section9_dated_flight_occurrences_v1(id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 departure_event_id text NOT NULL UNIQUE,
 departed_at timestamptz NOT NULL,
 passengers integer NOT NULL CHECK(passengers BETWEEN 0 AND 1000),
 package_id text NOT NULL CHECK(package_id ~ '^(none|basic|pkg-[1-9][0-9]{0,5})$'),
 package_version integer NOT NULL CHECK(package_version>=0),
 package_items jsonb NOT NULL CHECK(jsonb_typeof(package_items)='object'),
 reputation_score numeric NOT NULL CHECK(reputation_score BETWEEN 0 AND 100),
 model_version text NOT NULL DEFAULT 'GAME_CABIN_SERVICE_V1',
 captured_at timestamptz NOT NULL DEFAULT clock_timestamp()
);
ALTER TABLE airlinerra_game.section9_onboard_service_release_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_onboard_service_catalog_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.section9_onboard_departure_snapshots_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON airlinerra_game.section9_onboard_service_release_v1,airlinerra_game.section9_onboard_service_catalog_v1,airlinerra_game.section9_onboard_departure_snapshots_v1 FROM PUBLIC,anon,authenticated,service_role;

CREATE OR REPLACE FUNCTION airlinerra_game.section9_onboard_service_calculate_v1(p_key text,p_items jsonb,p_passengers integer,p_minutes numeric,p_reputation numeric)
RETURNS jsonb LANGUAGE plpgsql STABLE SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE c record; item jsonb; mode text; stock integer; price integer; duration_h numeric; length_factor numeric; price_factor numeric;
 rate numeric; loaded integer; sales integer; cost_units integer; row_cost bigint; row_income bigint; cost_total bigint:=0; income_total bigint:=0;
 free_weight integer:=0; paid_count integer:=0; rows jsonb:='[]'; unavailable jsonb:='[]'; satisfaction numeric; j integer;
BEGIN
 IF p_key IS NULL OR length(p_key) NOT BETWEEN 8 AND 180 OR jsonb_typeof(p_items) IS DISTINCT FROM 'object'
 OR p_passengers IS NULL OR p_passengers NOT BETWEEN 0 AND 1000 OR p_minutes IS NULL OR p_minutes NOT BETWEEN 15 AND 1440
 OR p_reputation IS NULL OR p_reputation NOT BETWEEN 0 AND 100 THEN RETURN jsonb_build_object('status','invalid_onboard_calculation');END IF;
 duration_h:=p_minutes/60;
 FOR c IN SELECT * FROM airlinerra_game.section9_onboard_service_catalog_v1 ORDER BY sort_order LOOP
  item:=coalesce(p_items->c.item_id,'{}'::jsonb);
  mode:=coalesce(item->>'mode','off'); stock:=0;price:=0;loaded:=0;sales:=0;cost_units:=0;rate:=0;
  IF mode NOT IN('off','included','onboard') THEN RETURN jsonb_build_object('status','invalid_onboard_service_mode','item',c.item_id);END IF;
  IF mode<>'off' AND NOT c.basic_delivery_supported THEN
   unavailable:=unavailable||jsonb_build_array(c.item_id);
   CONTINUE;
  END IF;
  IF mode='off' THEN CONTINUE;END IF;
  IF mode='included' THEN
   loaded:=CASE WHEN c.digital THEN 0 ELSE p_passengers END;
   cost_units:=p_passengers;IF p_passengers>0 THEN free_weight:=free_weight+c.included_weight;END IF;
  ELSE
   IF coalesce(item->>'onboardCents','') !~ '^[0-9]{1,6}$' OR coalesce(item->>'stockPer100','') !~ '^[0-9]{1,3}$' THEN RETURN jsonb_build_object('status','invalid_onboard_service_price_or_stock','item',c.item_id);END IF;
   price:=(item->>'onboardCents')::integer;stock:=(item->>'stockPer100')::integer;
   IF price NOT BETWEEN 0 AND 100000 OR stock NOT BETWEEN 0 AND 200 THEN RETURN jsonb_build_object('status','invalid_onboard_service_price_or_stock','item',c.item_id);END IF;
   length_factor:=CASE
    WHEN c.item_id='sandwich' THEN least(1.65,greatest(0.35,duration_h/2.6))
    WHEN c.item_id='snack' THEN least(1.55,greatest(0.45,duration_h/2.4))
    ELSE least(1.6,greatest(0.5,0.65+duration_h*0.13)) END;
   price_factor:=least(1.35,greatest(0.25,power(c.reference_price_cents::numeric/greatest(price,100),0.8::numeric)));
   rate:=least(0.65,c.base_purchase_rate*length_factor*(0.7+0.006*p_reputation)*price_factor);
   loaded:=CASE WHEN c.digital THEN 0 ELSE ceil(p_passengers*stock::numeric/100)::int END;
   -- Stable independent passenger/item draws, never clock-dependent.
   SELECT count(*)::int INTO sales FROM generate_series(1,p_passengers) j
    WHERE (('x'||substr(md5(p_key||':'||c.item_id||':'||j::text),1,8))::bit(32)::bigint)::numeric/4294967296 < rate;
   sales:=least(sales,CASE WHEN c.digital THEN p_passengers ELSE loaded END);
   cost_units:=CASE WHEN c.digital THEN sales ELSE loaded END;
   IF sales>0 THEN paid_count:=paid_count+1;END IF;
  END IF;
  row_cost:=cost_units::bigint*c.unit_cost_cents;row_income:=sales::bigint*price;
  cost_total:=cost_total+row_cost;income_total:=income_total+row_income;
  rows:=rows||jsonb_build_array(jsonb_build_object('itemId',c.item_id,'mode',mode,'loadedUnits',loaded,'includedUnits',CASE WHEN mode='included' THEN p_passengers ELSE 0 END,
   'paidSales',sales,'unsoldUnits',CASE WHEN mode='onboard' AND NOT c.digital THEN loaded-sales ELSE 0 END,
   'purchaseRate',round(rate,6),'unitCostCents',c.unit_cost_cents,'priceCents',price,'costCents',row_cost,'revenueCents',row_income));
 END LOOP;
 satisfaction:=CASE WHEN p_passengers=0 THEN 0 ELSE least(10,(free_weight+least(2,round(paid_count*0.5)))*0.2) END;
 RETURN jsonb_build_object('status','onboard_service_game_calculated','modelVersion','GAME_CABIN_SERVICE_V1','passengers',p_passengers,'durationMinutes',p_minutes,
 'reputationScore',p_reputation,'costCents',cost_total,'revenueCents',income_total,'netCents',income_total-cost_total,
 'satisfactionAdjustment',round(satisfaction,2),'unverifiedServicesExcluded',unavailable,'rows',rows,'ledgerPosted',false);
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_onboard_service_calculate_v1(text,jsonb,integer,numeric,numeric) FROM PUBLIC,anon,authenticated,service_role;

-- Capture immutable package terms at a real recorded departure; phase 1 basic only.
-- A missing or unsupported package is deliberately not replaced by a fictional one.
CREATE OR REPLACE FUNCTION airlinerra_game.section9_snapshot_onboard_departure_v1(p_physical text)
RETURNS jsonb LANGUAGE plpgsql SECURITY INVOKER SET search_path TO pg_catalog,airlinerra_game AS $$
DECLARE f record; pkg text; items jsonb; ver int:=0; rep numeric; inserted int;
BEGIN
 IF current_user<>'postgres' THEN RAISE EXCEPTION 'PRIVATE_ONBOARD_SNAPSHOT';END IF;
 IF NOT EXISTS(SELECT 1 FROM airlinerra_game.section9_onboard_service_release_v1 WHERE world_id=1 AND snapshot_enabled) THEN RETURN jsonb_build_object('status','onboard_snapshot_not_released');END IF;
 IF EXISTS(SELECT 1 FROM airlinerra_game.section9_onboard_departure_snapshots_v1 WHERE physical_flight_id=p_physical) THEN RETURN jsonb_build_object('status','onboard_snapshot_already_captured','replayed',true);END IF;
 SELECT o.id,o.airline_id,o.booked_seats,m.engine_event_id,m.actual_event_utc,p.planning_options
 INTO f FROM airlinerra_game.section9_operated_flight_movements_v1 m
 JOIN airlinerra_game.section9_dated_flight_occurrences_v1 o ON o.schedule_id=m.schedule_id AND o.airline_id=m.airline_id
  AND o.schedule_id::text||':'||o.flight_local_date::text||':'||o.weekly_entry::text=m.flight_occurrence_id
 JOIN airlinerra_game.airline_flight_schedule_drafts_v1 s ON s.id=o.schedule_id AND s.airline_id=o.airline_id AND s.version=o.schedule_version
 JOIN airlinerra_game.airline_route_planning_drafts_v1 p ON p.airline_id=s.airline_id AND p.flight_number=s.flight_number
  AND p.aircraft_inventory_id=s.aircraft_inventory_id AND p.origin_airport_key=s.origin_airport_key AND p.destination_airport_key=s.destination_airport_key
  AND p.weekly_schedule=s.weekly_schedule
 WHERE m.flight_occurrence_id=p_physical AND m.phase='departed' AND o.world_id=1 AND o.booking_status='closed';
 IF NOT FOUND THEN RETURN jsonb_build_object('status','onboard_snapshot_missing_verified_departure_or_route');END IF;
 pkg:=f.planning_options->'service'->>'cabinPackageId';
 IF pkg='none' THEN items:='{}'::jsonb;
 ELSIF pkg='basic' THEN items:='{"water":{"mode":"included","stockPer100":100,"onboardCents":350}}'::jsonb;
 ELSE RETURN jsonb_build_object('status','onboard_snapshot_unsupported_package');END IF;
 rep:=coalesce((airlinerra_game.section9_airline_reputation_v1(f.airline_id)->>'reputation')::numeric,70);
 INSERT INTO airlinerra_game.section9_onboard_departure_snapshots_v1(physical_flight_id,occurrence_id,airline_id,departure_event_id,departed_at,passengers,package_id,package_version,package_items,reputation_score)
 VALUES(p_physical,f.id,f.airline_id,f.engine_event_id,f.actual_event_utc,f.booked_seats,pkg,ver,items,rep) ON CONFLICT(physical_flight_id) DO NOTHING;
 GET DIAGNOSTICS inserted=ROW_COUNT;
 RETURN jsonb_build_object('status','onboard_snapshot_captured','replayed',inserted=0,'packageId',pkg,'passengers',f.booked_seats,'ledgerPosted',false);
END;
$$;
REVOKE ALL ON FUNCTION airlinerra_game.section9_snapshot_onboard_departure_v1(text) FROM PUBLIC,anon,authenticated,service_role;
