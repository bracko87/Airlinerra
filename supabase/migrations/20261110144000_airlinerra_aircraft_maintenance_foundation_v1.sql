-- Airlinerra maintenance foundation v1: prelaunch configuration only.
-- NOT a flight activation, automatic debit, engine event or airworthiness certification.
-- All prices, durations and check intervals are explicitly GAME RULES / estimates.
-- No fabricated manufacture years, historic condition, or maintenance completions.

CREATE TABLE airlinerra_game.maintenance_check_policy_v1 (
 check_code text PRIMARY KEY CHECK(check_code IN ('daily','weekly','a','b','c','d')),
 display_name text NOT NULL,
 downtime_hours integer NOT NULL CHECK(downtime_hours>0),
 calendar_interval_hours integer,
 calendar_interval_months integer,
 flight_hour_interval numeric(10,2),
 airport_scope text NOT NULL CHECK(airport_scope IN ('any_approved_airport','type_approved_mro')),
 CHECK(num_nonnulls(calendar_interval_hours,calendar_interval_months,flight_hour_interval)>0),
 CHECK(calendar_interval_hours IS NULL OR calendar_interval_hours>0),
 CHECK(calendar_interval_months IS NULL OR calendar_interval_months>0),
 CHECK(flight_hour_interval IS NULL OR flight_hour_interval>0)
);
INSERT INTO airlinerra_game.maintenance_check_policy_v1
 (check_code,display_name,downtime_hours,calendar_interval_hours,calendar_interval_months,flight_hour_interval,airport_scope)
VALUES
 ('daily','Daily',1,24,NULL,NULL,'any_approved_airport'),
 ('weekly','Weekly',3,168,NULL,NULL,'any_approved_airport'),
 ('a','A check',6,NULL,NULL,500,'type_approved_mro'),
 ('b','B check',24,NULL,NULL,750,'type_approved_mro'),
 ('c','C check',168,NULL,24,5500,'type_approved_mro'),
 ('d','D / Heavy check',504,NULL,96,NULL,'type_approved_mro');

CREATE TABLE airlinerra_game.maintenance_cost_groups_v1 (
 group_id smallint PRIMARY KEY CHECK(group_id BETWEEN 1 AND 8),
 group_name text NOT NULL,
 daily_usd numeric(14,2) NOT NULL CHECK(daily_usd>=0),
 weekly_usd numeric(14,2) NOT NULL CHECK(weekly_usd>=0),
 a_usd numeric(14,2) NOT NULL CHECK(a_usd>=0),
 b_usd numeric(14,2) NOT NULL CHECK(b_usd>=0),
 c_usd numeric(14,2) NOT NULL CHECK(c_usd>=0),
 d_usd numeric(14,2) NOT NULL CHECK(d_usd>=0),
 estimate_policy text NOT NULL DEFAULT 'provisional_game_tariff_not_vendor_quote'
);
INSERT INTO airlinerra_game.maintenance_cost_groups_v1
 (group_id,group_name,daily_usd,weekly_usd,a_usd,b_usd,c_usd,d_usd) VALUES
 (1,'Light utility',30,100,600,1500,10000,50000),
 (2,'Small commuter',50,180,1200,4000,20000,85000),
 (3,'Regional turboprop',90,260,2500,8000,35000,180000),
 (4,'Regional jet / midsize',140,550,6000,16000,90000,350000),
 (5,'Small narrowbody',240,900,12000,30000,200000,850000),
 (6,'Standard narrowbody',300,1100,18000,48000,280000,1200000),
 (7,'Medium / large widebody',500,1900,32000,85000,600000,2500000),
 (8,'Heavy / special aircraft',1000,3500,58000,160000,1100000,4800000);

CREATE TABLE airlinerra_game.maintenance_age_tiers_v1 (
 tier smallint PRIMARY KEY,
 min_years smallint NOT NULL CHECK(min_years>=0),
 max_years smallint NOT NULL CHECK(max_years>=min_years),
 cost_multiplier numeric(5,2) NOT NULL CHECK(cost_multiplier>=1)
);
INSERT INTO airlinerra_game.maintenance_age_tiers_v1 VALUES
 (1,0,5,1.00),(2,6,12,1.10),(3,13,20,1.25),(4,21,30,1.45),(5,31,200,1.70);

-- All existing aircraft configurations get a usable GAME cost tier now.
-- Aircraft size and role determine the estimate; not an aircraft-type approval.
CREATE TABLE airlinerra_game.maintenance_model_group_v1 (
 configuration_id bigint PRIMARY KEY REFERENCES airlinerra.aircraft_configurations(id),
 group_id smallint NOT NULL REFERENCES airlinerra_game.maintenance_cost_groups_v1(group_id),
 assignment_basis text NOT NULL DEFAULT 'game_size_mtow_estimate',
 reviewed_as_airworthiness_fact boolean NOT NULL DEFAULT false,
 updated_at timestamptz NOT NULL DEFAULT now()
);
INSERT INTO airlinerra_game.maintenance_model_group_v1(configuration_id,group_id)
SELECT configuration_id,
 CASE
  WHEN mtow_kg<=8000 THEN 1
  WHEN mtow_kg<=16000 THEN 2
  WHEN mtow_kg<=36000 AND (
   (coalesce(family_name,'')||' '||coalesce(model_name,'')) ~*
   '(ATR|Dash 8|Q400|Saab|F27|F50|An-24|An-26|An-32|MA60|MA600|L-410|Short|Dornier 328|D328|C-295|CN-235|Twin Otter)'
  ) THEN 3
  WHEN mtow_kg<=55000 THEN 4
  WHEN mtow_kg<=76000 THEN 5
  WHEN mtow_kg<=125000 THEN 6
  WHEN mtow_kg<=290000 THEN 7
  ELSE 8
 END
FROM airlinerra.aircraft_catalog_configuration_inventory
WHERE mtow_kg IS NOT NULL
ON CONFLICT(configuration_id) DO NOTHING;

-- Baselines are NULL until signed game events or explicitly verified data.
-- "0 since tracking began" is NOT a verified lifetime total.
CREATE TABLE airlinerra_game.aircraft_maintenance_state_v1 (
 aircraft_inventory_id uuid PRIMARY KEY
  REFERENCES airlinerra_game.airline_aircraft_inventory(id) ON DELETE CASCADE,
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 manufacture_year smallint CHECK(manufacture_year BETWEEN 1900 AND 2100),
 manufacture_year_basis text NOT NULL DEFAULT 'unverified',
 condition_pct numeric(5,2) CHECK(condition_pct BETWEEN 0 AND 100),
 condition_basis text NOT NULL DEFAULT 'unverified',
 verified_tracking_started_utc timestamptz,
 tracked_flight_hours numeric(12,2) CHECK(tracked_flight_hours>=0),
 tracked_flight_cycles bigint CHECK(tracked_flight_cycles>=0),
 tracking_source text NOT NULL DEFAULT 'not_started',
 updated_at timestamptz NOT NULL DEFAULT now(),
 CHECK((tracked_flight_hours IS NULL AND tracked_flight_cycles IS NULL)
   OR (verified_tracking_started_utc IS NOT NULL AND
       tracked_flight_hours IS NOT NULL AND tracked_flight_cycles IS NOT NULL))
);
INSERT INTO airlinerra_game.aircraft_maintenance_state_v1
 (aircraft_inventory_id,airline_id)
SELECT id,airline_id FROM airlinerra_game.airline_aircraft_inventory
ON CONFLICT DO NOTHING;

-- Actual check history only: never populate this from catalog model production years.
CREATE TABLE airlinerra_game.aircraft_maintenance_completions_v1 (
 completion_id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 aircraft_inventory_id uuid NOT NULL REFERENCES airlinerra_game.airline_aircraft_inventory(id),
 airline_id uuid NOT NULL REFERENCES airlinerra_game.airlines(id),
 check_code text NOT NULL REFERENCES airlinerra_game.maintenance_check_policy_v1(check_code),
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airport_key text NOT NULL,
 completed_at_utc timestamptz NOT NULL,
 flight_hours_at_completion numeric(12,2) CHECK(flight_hours_at_completion>=0),
 cycles_at_completion bigint CHECK(cycles_at_completion>=0),
 paid_usd numeric(14,2) CHECK(paid_usd>=0),
 source_kind text NOT NULL CHECK(source_kind IN ('verified_game_engine','verified_game_maintenance_record')),
 event_reference text NOT NULL,
 recorded_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(event_reference),
 FOREIGN KEY(world_id,airport_key)
  REFERENCES airlinerra_game.approved_game_airports(world_id,airport_key)
);
CREATE INDEX aircraft_maintenance_history_airframe_idx
 ON airlinerra_game.aircraft_maintenance_completions_v1(aircraft_inventory_id,check_code,completed_at_utc DESC);

-- Research must distinguish an actual MRO provider from a generic hangar estimate.
CREATE TABLE airlinerra_game.maintenance_facility_locations_v1 (
 world_id smallint NOT NULL DEFAULT 1 CHECK(world_id=1),
 airport_key text NOT NULL,
 provider_key text NOT NULL,
 provider_name text NOT NULL,
 research_status text NOT NULL CHECK(research_status IN ('provider_supported','research_pending')),
 source_url text NOT NULL CHECK(source_url LIKE 'https://%'),
 source_note text NOT NULL,
 reviewed_on date,
 created_at timestamptz NOT NULL DEFAULT now(),
 PRIMARY KEY(world_id,airport_key,provider_key),
 FOREIGN KEY(world_id,airport_key)
  REFERENCES airlinerra_game.approved_game_airports(world_id,airport_key)
);
CREATE TABLE airlinerra_game.maintenance_airport_capabilities_v1 (
 world_id smallint NOT NULL CHECK(world_id=1),
 airport_key text NOT NULL,
 provider_key text NOT NULL,
 configuration_id bigint NOT NULL REFERENCES airlinerra.aircraft_configurations(id),
 check_code text NOT NULL CHECK(check_code IN ('a','b','c','d')),
 approval_status text NOT NULL CHECK(approval_status IN ('game_approved','research_pending')),
 scope_basis text NOT NULL,
 source_url text NOT NULL CHECK(source_url LIKE 'https://%'),
 reviewed_on date,
 PRIMARY KEY(world_id,airport_key,configuration_id,check_code),
 FOREIGN KEY(world_id,airport_key,provider_key)
  REFERENCES airlinerra_game.maintenance_facility_locations_v1(world_id,airport_key,provider_key)
);
CREATE INDEX maintenance_airport_by_type_idx
 ON airlinerra_game.maintenance_airport_capabilities_v1(configuration_id,check_code,approval_status,airport_key);

-- Actual, named providers at approved airports; pending sources are NOT bookable.
INSERT INTO airlinerra_game.maintenance_facility_locations_v1
(world_id,airport_key,provider_key,provider_name,research_status,source_url,source_note,reviewed_on)
SELECT a.world_id,a.airport_key,'siaec','SIA Engineering Company','provider_supported',
 'https://www.siaec.com.sg/our_services/base_maintenance/airframe_maintenance.html',
 'Official airframe maintenance provider lists checks up to D and specific aircraft families at Singapore',
 DATE '2026-11-10'
FROM airlinerra_game.approved_game_airports a WHERE a.world_id=1 AND a.airport_code='WSSS'
UNION ALL
SELECT a.world_id,a.airport_key,'lht','Lufthansa Technik','research_pending',
 'https://www.lufthansa-technik.com/en/base-maintenance',
 'Provider supports C and D checks in global network; Hamburg scope by aircraft type pending',
 DATE '2026-11-10'
FROM airlinerra_game.approved_game_airports a WHERE a.world_id=1 AND a.airport_code='EDDH'
UNION ALL
SELECT a.world_id,a.airport_key,'turkish','Turkish Technic','research_pending',
 'https://www.turkishtechnic.com/mro-solution/aircraft-maintenance-services',
 'Provider supports base maintenance; exact location and current aircraft scope require verification',
 DATE '2026-11-10'
FROM airlinerra_game.approved_game_airports a WHERE a.world_id=1 AND a.airport_code='LTFM'
UNION ALL
SELECT a.world_id,a.airport_key,'steng','ST Engineering Hubei','research_pending',
 'https://www.stengg.com/en/newsroom/news-releases/st-engineering-sf-airlines-open-airframe-mro-facility-ezhou-china/',
 'Verified heavy-maintenance facility at Ezhou; per-model game approvals pending',
 DATE '2026-11-10'
FROM airlinerra_game.approved_game_airports a WHERE a.world_id=1 AND a.airport_code='ZHEC';

-- SIA Engineering explicitly names these platforms and capability up to D.
-- Exact aircraft configuration compatibility remains a GAME selection.
-- Exclude earlier 737-200/300/400/500 from its 737 NG / MAX listing.
INSERT INTO airlinerra_game.maintenance_airport_capabilities_v1
(world_id,airport_key,provider_key,configuration_id,check_code,approval_status,scope_basis,source_url,reviewed_on)
SELECT a.world_id,a.airport_key,'siaec',m.configuration_id,c.check_code,'game_approved',
 'official_provider_airframe_family_plus_game_check_mapping',
 'https://www.siaec.com.sg/our_services/base_maintenance/airframe_maintenance.html',
 DATE '2026-11-10'
FROM airlinerra_game.approved_game_airports a
CROSS JOIN airlinerra.aircraft_catalog_configuration_inventory m
CROSS JOIN (VALUES('a'),('b'),('c'),('d')) c(check_code)
WHERE a.world_id=1 AND a.airport_code='WSSS'
AND (
 (m.manufacturer_name='Airbus' AND m.family_name IN ('A320','A330','A340','A350'))
 OR (m.manufacturer_name='Boeing' AND m.family_name IN ('747','777','787'))
 OR (m.manufacturer_name='Boeing' AND m.family_name='737' AND (
      m.model_name ~* '737[- ](6|7|8|9)[0-9]' OR m.model_name ~* '737[ -]MAX'))
 OR (m.manufacturer_name='Embraer' AND m.model_name ~* '^E(170|175|190|195)')
)
ON CONFLICT DO NOTHING;

-- Read-only preview: ONE row per owned airframe/check, all missing history unknown.
-- No calculated condition or fabricated last check date.
CREATE VIEW airlinerra_game.aircraft_maintenance_check_overview_v1
WITH (security_invoker=true) AS
SELECT i.id AS aircraft_inventory_id,i.airline_id,i.registration,
 c.check_code,c.display_name,c.downtime_hours,c.airport_scope,
 m.group_id,g.group_name,
 s.manufacture_year,s.manufacture_year_basis,s.condition_pct,s.condition_basis,
 s.verified_tracking_started_utc,s.tracked_flight_hours,s.tracked_flight_cycles,
 history.completed_at_utc AS last_completed_utc,
 history.flight_hours_at_completion AS last_completed_at_flight_hours,
 CASE c.check_code
  WHEN 'daily' THEN g.daily_usd WHEN 'weekly' THEN g.weekly_usd
  WHEN 'a' THEN g.a_usd WHEN 'b' THEN g.b_usd WHEN 'c' THEN g.c_usd
  WHEN 'd' THEN g.d_usd END AS base_estimate_usd,
 'provisional_game_tariff_not_vendor_quote'::text AS cost_evidence
FROM airlinerra_game.airline_aircraft_inventory i
LEFT JOIN airlinerra_game.aircraft_maintenance_state_v1 s ON s.aircraft_inventory_id=i.id
JOIN airlinerra_game.maintenance_model_group_v1 m ON m.configuration_id=i.configuration_id
JOIN airlinerra_game.maintenance_cost_groups_v1 g ON g.group_id=m.group_id
CROSS JOIN airlinerra_game.maintenance_check_policy_v1 c
LEFT JOIN LATERAL (
 SELECT h.completed_at_utc,h.flight_hours_at_completion
 FROM airlinerra_game.aircraft_maintenance_completions_v1 h
 WHERE h.aircraft_inventory_id=i.id AND h.check_code=c.check_code
 ORDER BY h.completed_at_utc DESC,h.completion_id DESC LIMIT 1
) history ON TRUE;

-- Revoke public access, RLS defense in depth; server verifies player ownership.
ALTER TABLE airlinerra_game.maintenance_check_policy_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.maintenance_cost_groups_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.maintenance_age_tiers_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.maintenance_model_group_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.aircraft_maintenance_state_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.aircraft_maintenance_completions_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.maintenance_facility_locations_v1 ENABLE ROW LEVEL SECURITY;
ALTER TABLE airlinerra_game.maintenance_airport_capabilities_v1 ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON ALL TABLES IN SCHEMA airlinerra_game FROM PUBLIC;
-- Specific grants to existing application roles are managed separately by the platform.
COMMENT ON VIEW airlinerra_game.aircraft_maintenance_check_overview_v1 IS
 'Private, read-only GAME maintenance planning. Baseline history and actual aircraft condition remain unverified unless sourced; no check is marked completed by assumption.';
