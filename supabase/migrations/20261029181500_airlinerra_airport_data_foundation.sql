-- Airlinerra World 1 approved-airport master data foundation.
-- Additive private tables only. No public/browser grants, costs, aircraft,
-- route changes or changes to existing airport approvals.
-- Source code systems and runway observations are source-reported UNVERIFIED;
-- never promote them to operational facts without independent evidence.
create table if not exists airlinerra_game.airport_reference_profiles (
  world_id smallint not null,
  airport_key text not null,
  display_name text not null,
  catalog_code text,
  icao_reported text,
  iata_reported text,
  gps_reported text,
  local_reported text,
  source_ident text,
  municipality text,
  country_iso text not null check (country_iso ~ '^[A-Z]{2}$'),
  region_iso text,
  timezone_iana text,
  timezone_verified_on date,
  latitude_deg numeric(10,6) check (latitude_deg between -90 and 90),
  longitude_deg numeric(10,6) check (longitude_deg between -180 and 180),
  elevation_ft numeric(10,1),
  provisional_category text check (provisional_category in ('Local','Regional','Medium','Large','Major Hub','Mega Hub')),
  approved_category text check (approved_category in ('Local','Regional','Medium','Large','Major Hub','Mega Hub')),
  category_approved_on date,
  longest_runway_observed_m numeric(10,1) check (longest_runway_observed_m > 0),
  airport_kind text not null default 'real' check (airport_kind in ('real','fictional')),
  identity_verification text not null default 'source_unverified' check (identity_verification in ('source_unverified','partially_verified','verified')),
  coordinates_verification text not null default 'source_unverified' check (coordinates_verification in ('source_unverified','verified','not_applicable')),
  profile_release_status text not null default 'research' check (profile_release_status in ('research','review_required','approved')),
  populated_from text not null default 'existing_approved_directory',
  refreshed_at timestamptz not null default now(),
  primary key (world_id,airport_key),
  foreign key (world_id,airport_key) references airlinerra_game.approved_game_airports(world_id,airport_key) on delete restrict,
  check ((latitude_deg is null) = (longitude_deg is null)),
  check (approved_category is null or category_approved_on is not null),
  check (timezone_iana is null or timezone_verified_on is not null)
);
create index if not exists airport_reference_profiles_country_idx on airlinerra_game.airport_reference_profiles(world_id,country_iso,display_name);

create table if not exists airlinerra_game.airport_runway_inventory (
  world_id smallint not null,
  airport_key text not null,
  source_runway_id text not null,
  runway_designator text,
  length_m numeric(10,1) check (length_m > 0),
  width_m numeric(10,1) check (width_m > 0),
  surface_reported text,
  lighted_reported boolean,
  source_identifier text not null default 'historic_ourairports',
  source_snapshot_hash text,
  source_effective_on date,
  source_url text,
  verification text not null default 'historical_unverified'
    check (verification in ('historical_unverified','review_required','verified')),
  operational_status text not null default 'unknown'
    check (operational_status in ('unknown','operational','restricted','closed')),
  last_checked_at timestamptz,
  primary key (world_id,airport_key,source_runway_id),
  foreign key (world_id,airport_key) references airlinerra_game.airport_reference_profiles(world_id,airport_key) on delete restrict,
  check (verification='verified' or operational_status='unknown'),
  check (verification<>'verified' or last_checked_at is not null)
);
create index if not exists airport_runway_inventory_airport_idx on airlinerra_game.airport_runway_inventory(world_id,airport_key);

create table if not exists airlinerra_game.airport_facilities (
  world_id smallint not null,
  airport_key text not null,
  terminal_count integer check(terminal_count>=0),
  passenger_gate_count integer check(passenger_gate_count>=0),
  aircraft_stand_count integer check(aircraft_stand_count>=0),
  contact_stand_count integer check(contact_stand_count>=0),
  remote_stand_count integer check(remote_stand_count>=0),
  cargo_stand_count integer check(cargo_stand_count>=0),
  jet_bridge_count integer check(jet_bridge_count>=0),
  apron_area_m2 numeric check(apron_area_m2>=0),
  parking_position_count integer check(parking_position_count>=0),
  hangar_capacity_count integer check(hangar_capacity_count>=0),
  customs_available boolean,
  international_operations_allowed boolean,
  scheduled_passenger_service boolean,
  cargo_handling_available boolean,
  ground_handling_available boolean,
  fuel_available boolean,
  arff_category text,
  operating_hours_local text,
  curfew_details text,
  noise_restrictions text,
  weather_minima text,
  facility_status text not null default 'pending'
    check(facility_status in ('pending','research','partially_verified','verified')),
  source_url text,
  source_effective_on date,
  primary key(world_id,airport_key),
  foreign key(world_id,airport_key) references airlinerra_game.airport_reference_profiles(world_id,airport_key) on delete restrict
);

-- An actual declared airport capacity/slot allocation is not a count of gates.
-- Store separately from Airlinerra's future game slot supply.
create table if not exists airlinerra_game.airport_capacity_observations (
  id bigint generated always as identity primary key,
  world_id smallint not null,
  airport_key text not null,
  season_label text not null,
  observation_kind text not null
    check(observation_kind in ('published_declared_capacity','coordinator_allocation','research_estimate')),
  movement_type text not null check(movement_type in ('all','arrival','departure')),
  window_description text not null,
  movements_per_hour integer check(movements_per_hour>=0),
  movements_per_day integer check(movements_per_day>=0),
  coordination_level text,
  source_authority text,
  source_url text,
  source_effective_on date,
  verification text not null default 'unverified'
    check(verification in ('unverified','review_required','verified')),
  reviewed_on date,
  foreign key(world_id,airport_key) references airlinerra_game.airport_reference_profiles(world_id,airport_key) on delete restrict,
  check(verification<>'verified' or (source_authority is not null and source_url is not null and reviewed_on is not null))
);
create index if not exists airport_capacity_by_airport_idx on airlinerra_game.airport_capacity_observations(world_id,airport_key,season_label);

create table if not exists airlinerra_game.airport_traffic_observations (
  id bigint generated always as identity primary key,
  world_id smallint not null,
  airport_key text not null,
  period_year smallint not null check(period_year between 1950 and 2100),
  period_month smallint check(period_month between 1 and 12),
  metric text not null check(metric in
   ('passengers_total','passengers_domestic','passengers_international',
    'cargo_tonnes_total','cargo_tonnes_domestic','cargo_tonnes_international',
    'aircraft_movements_total','commercial_movements')),
  traffic_value numeric(20,3) not null check(traffic_value>=0),
  coverage_scope text not null default 'airport_total'
   check(coverage_scope in ('airport_total','scheduled_only','all_commercial','estimated_market')),
  source_authority text not null,
  source_url text not null,
  source_effective_on date,
  verification text not null default 'source_unverified'
   check(verification in ('source_unverified','review_required','verified')),
  reviewed_on date,
  foreign key(world_id,airport_key) references airlinerra_game.airport_reference_profiles(world_id,airport_key) on delete restrict,
  check(verification<>'verified' or reviewed_on is not null)
);
create index if not exists airport_traffic_by_airport_idx on airlinerra_game.airport_traffic_observations(world_id,airport_key,period_year,metric);

-- Future modelled passenger/cargo OD demand: must never be labelled historical traffic.
create table if not exists airlinerra_game.airport_market_demand_models (
  world_id smallint not null,
  origin_airport_key text not null,
  destination_airport_key text not null,
  model_version text not null,
  scenario_label text not null,
  effective_year smallint not null check(effective_year between 1950 and 2100),
  estimated_weekly_passengers numeric check(estimated_weekly_passengers>=0),
  estimated_weekly_cargo_tonnes numeric check(estimated_weekly_cargo_tonnes>=0),
  model_input_reference text not null,
  reviewed_on date,
  primary key (world_id,origin_airport_key,destination_airport_key,model_version,scenario_label,effective_year),
  foreign key (world_id,origin_airport_key) references airlinerra_game.airport_reference_profiles(world_id,airport_key) on delete restrict,
  foreign key (world_id,destination_airport_key) references airlinerra_game.airport_reference_profiles(world_id,airport_key) on delete restrict,
  check(origin_airport_key<>destination_airport_key)
);

-- Field-level evidence: source URL, date, method, review and previous revisions.
create table if not exists airlinerra_game.airport_field_evidence (
  evidence_id bigint generated always as identity primary key,
  world_id smallint not null,
  airport_key text not null,
  field_path text not null check(field_path ~ '^[a-z][a-z0-9_.]{1,100}$'),
  evidence_value jsonb,
  source_authority text not null,
  source_url text,
  source_license text,
  source_observed_on date,
  recorded_at timestamptz not null default now(),
  verification text not null default 'research'
    check(verification in ('research','rejected','unverified','verified')),
  reviewer_note text,
  foreign key(world_id,airport_key) references airlinerra_game.airport_reference_profiles(world_id,airport_key) on delete restrict
);
create index if not exists airport_field_evidence_lookup_idx on airlinerra_game.airport_field_evidence(world_id,airport_key,field_path);

create table if not exists airlinerra_game.airport_data_work_queue (
  world_id smallint not null,
  airport_key text not null,
  data_area text not null check(data_area in
   ('codes','coordinates_timezones','runways','facilities_gates','capacity_slots','traffic_demand','operating_rules')),
  research_status text not null default 'pending'
   check(research_status in ('pending','researching','review_required','complete','not_applicable')),
  priority smallint not null default 3 check(priority between 1 and 5),
  assigned_reviewer text,
  research_notes text,
  last_updated timestamptz not null default now(),
  primary key(world_id,airport_key,data_area),
  foreign key(world_id,airport_key) references airlinerra_game.airport_reference_profiles(world_id,airport_key) on delete restrict
);

-- Private schema, server-owned reads only. RLS defense in depth with NO client policies.
alter table airlinerra_game.airport_reference_profiles enable row level security;
alter table airlinerra_game.airport_runway_inventory enable row level security;
alter table airlinerra_game.airport_facilities enable row level security;
alter table airlinerra_game.airport_capacity_observations enable row level security;
alter table airlinerra_game.airport_traffic_observations enable row level security;
alter table airlinerra_game.airport_market_demand_models enable row level security;
alter table airlinerra_game.airport_field_evidence enable row level security;
alter table airlinerra_game.airport_data_work_queue enable row level security;
revoke all on table
 airlinerra_game.airport_reference_profiles,
 airlinerra_game.airport_runway_inventory,
 airlinerra_game.airport_facilities,
 airlinerra_game.airport_capacity_observations,
 airlinerra_game.airport_traffic_observations,
 airlinerra_game.airport_market_demand_models,
 airlinerra_game.airport_field_evidence,
 airlinerra_game.airport_data_work_queue
 from public,anon,authenticated;
revoke all on sequence
 airlinerra_game.airport_capacity_observations_id_seq,
 airlinerra_game.airport_traffic_observations_id_seq,
 airlinerra_game.airport_field_evidence_evidence_id_seq
 from public,anon,authenticated;

-- Base directory: approved airports are THE ONLY allowed source set.
-- Code entries remain labelled source-unverified (none are reviewed).
insert into airlinerra_game.airport_reference_profiles(
 world_id,airport_key,display_name,catalog_code,icao_reported,iata_reported,
 gps_reported,local_reported,source_ident,municipality,country_iso,region_iso,
 latitude_deg,longitude_deg,provisional_category,longest_runway_observed_m,airport_kind)
select a.world_id,a.airport_key,a.airport_name,a.airport_code,
 codes.icao,codes.iata,codes.gps,codes.local_code,codes.source_ident,
 a.municipality,a.country_iso,r.region_code,
 c.latitude_deg,c.longitude_deg,
 p.proposed_category,c.longest_qualifying_runway_m,
 case when a.airport_key like 'FICTIONAL:%' then 'fictional' else 'real' end
from airlinerra_game.approved_game_airports a
left join airlinerra.airport_game_world1_catalog c
 on c.world_number=a.world_id and c.airport_key=a.airport_key
left join airlinerra.airport_game_profiles p on p.airport_key=a.airport_key
left join airlinerra.airport_registry r on r.airport_key=a.airport_key
left join lateral (
 select max(code_value) filter(where code_system='ICAO') icao,
        max(code_value) filter(where code_system='IATA') iata,
        max(code_value) filter(where code_system='GPS') gps,
        max(code_value) filter(where code_system='LOCAL') local_code,
        max(code_value) filter(where code_system='SOURCE_IDENT') source_ident
 from airlinerra.airport_codes codes where codes.airport_key=a.airport_key
) codes on true
where a.world_id=1
on conflict (world_id,airport_key) do nothing;

-- Import the existing observations, explicitly NOT verified operating runways.
insert into airlinerra_game.airport_runway_inventory
 (world_id,airport_key,source_runway_id,runway_designator,length_m,width_m,
  surface_reported,lighted_reported,source_snapshot_hash,source_effective_on,source_url)
select a.world_id,a.airport_key,o.source_runway_id,o.runway_ident,o.length_m,o.width_m,
 o.surface,
 case when o.source_details->>'lighted_source'='1' then true
      when o.source_details->>'lighted_source'='0' then false else null end,
 o.source_snapshot_hash,o.source_effective_date,o.source_url
from airlinerra_game.approved_game_airports a
join airlinerra.airport_runway_observations o on o.airport_key=a.airport_key
where a.world_id=1 and o.evidence_origin='HISTORIC_OURAIRPORTS_SOURCE_ONLY'
on conflict (world_id,airport_key,source_runway_id) do nothing;

-- Blank facility records mean UNKNOWN, never zero.
insert into airlinerra_game.airport_facilities(world_id,airport_key)
select world_id,airport_key from airlinerra_game.airport_reference_profiles where world_id=1
on conflict (world_id,airport_key) do nothing;

insert into airlinerra_game.airport_data_work_queue(world_id,airport_key,data_area,priority)
select p.world_id,p.airport_key,a.area,
 case when a.area in ('codes','coordinates_timezones','runways') then 2 else 3 end
from airlinerra_game.airport_reference_profiles p
cross join (values ('codes'),('coordinates_timezones'),('runways'),
 ('facilities_gates'),('capacity_slots'),('traffic_demand'),('operating_rules')) a(area)
where p.world_id=1
on conflict (world_id,airport_key,data_area) do nothing;
