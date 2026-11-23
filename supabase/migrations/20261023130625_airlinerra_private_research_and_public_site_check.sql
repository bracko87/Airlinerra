
-- Airlinerra isolated research schema. No playable airports or airline accounts seeded.
create schema if not exists airlinerra;
revoke all on schema airlinerra from public, anon, authenticated;
create table if not exists airlinerra.airport_registry (
  airport_key text primary key,
  source_type text not null check (source_type in ('OURAIRPORTS','FICTIONAL')),
  source_airport_id text not null,
  country_iso text not null check (country_iso ~ '^[A-Z]{2}$'),
  airport_name text not null,
  source_ident text,
  source_gps_code text,
  municipality text,
  region_code text,
  latitude_deg numeric(10,6) check (latitude_deg between -90 and 90),
  longitude_deg numeric(10,6) check (longitude_deg between -180 and 180),
  longest_qualifying_runway_m numeric(9,1) check (longest_qualifying_runway_m > 0),
  longest_qualifying_surface text,
  runway_screen_status text not null default 'SOURCE_ONLY_UNVERIFIED',
  minimum_eligible_level integer check (minimum_eligible_level between 1 and 6),
  source_details jsonb not null default '{}'::jsonb,
  added_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (source_type, source_airport_id)
);
create index if not exists airport_registry_country on airlinerra.airport_registry(country_iso);
create index if not exists airport_registry_name on airlinerra.airport_registry(airport_name);

create table if not exists airlinerra.airport_cohorts (
  airport_key text not null references airlinerra.airport_registry(airport_key) on delete restrict,
  cohort text not null check (cohort in ('ORIGINAL_3140','EXPANSION_3906','OTHER_MASTER','FICTIONAL')),
  source_file text not null,
  source_snapshot_date date,
  added_at timestamptz not null default now(),
  primary key (airport_key, cohort)
);
create index if not exists airport_cohorts_type on airlinerra.airport_cohorts(cohort);

create table if not exists airlinerra.airport_codes (
  id bigint generated always as identity primary key,
  airport_key text not null references airlinerra.airport_registry(airport_key) on delete restrict,
  code_system text not null check (code_system in ('SOURCE_IDENT','GPS','ICAO','IATA','FAA_LID','LOCAL','GAME_GPS','GAME_ICAO','GAME_IATA')),
  code_value text not null,
  provenance text not null default 'SOURCE_REPORTED_UNVERIFIED',
  source_url text,
  source_effective_date date,
  is_game_only boolean not null default false,
  review_status text not null default 'UNVERIFIED',
  created_at timestamptz not null default now(),
  unique(airport_key,code_system,code_value),
  constraint code_game_flag_consistency check (
    (code_system in ('GAME_GPS','GAME_ICAO','GAME_IATA') and is_game_only)
    or (code_system not in ('GAME_GPS','GAME_ICAO','GAME_IATA') and not is_game_only)
  )
);
create index if not exists airport_codes_lookup on airlinerra.airport_codes(code_system, code_value);

create table if not exists airlinerra.airport_runway_observations (
  id bigint generated always as identity primary key,
  airport_key text not null references airlinerra.airport_registry(airport_key) on delete restrict,
  source_runway_id text,
  runway_ident text,
  length_m numeric(9,1) check (length_m > 0),
  width_m numeric(8,1) check (width_m > 0),
  surface text,
  reported_operational_status text not null default 'UNVERIFIED',
  evidence_origin text not null,
  source_url text,
  source_effective_date date,
  source_snapshot_hash text,
  source_details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique(airport_key,evidence_origin,source_runway_id)
);
create index if not exists airport_runways_by_airport on airlinerra.airport_runway_observations(airport_key);

create table if not exists airlinerra.airport_access_reviews (
  airport_key text primary key references airlinerra.airport_registry(airport_key) on delete restrict,
  identity_status text not null default 'UNVERIFIED',
  paved_runway_status text not null default 'UNVERIFIED',
  civilian_access_status text not null default 'UNVERIFIED',
  passenger_scheduled_status text not null default 'UNVERIFIED',
  passenger_charter_status text not null default 'UNVERIFIED',
  cargo_status text not null default 'UNVERIFIED',
  commercial_permission_status text not null default 'UNVERIFIED',
  review_status text not null default 'HOLD',
  evidence_url text,
  source_review_note text,
  review_date date,
  approved_by text,
  owner_approved_at timestamptz,
  game_admission_status text not null default 'NOT_APPROVED',
  last_updated timestamptz not null default now(),
  constraint no_implicit_game_approval check (
    game_admission_status <> 'APPROVED_FOR_GAME'
    or (owner_approved_at is not null
      and approved_by is not null
      and evidence_url is not null
      and identity_status = 'VERIFIED'
      and paved_runway_status = 'VERIFIED'
      and civilian_access_status = 'VERIFIED'
      and commercial_permission_status = 'VERIFIED')
  )
);
create index if not exists airport_review_queue on airlinerra.airport_access_reviews(review_status);

create table if not exists airlinerra.airport_certifications (
  id bigint generated always as identity primary key,
  airport_key text not null references airlinerra.airport_registry(airport_key) on delete restrict,
  authority text not null,
  certificate_type text not null,
  certificate_class text,
  arff_index text,
  certificate_status text not null default 'SOURCE_REPORTED_UNVERIFIED',
  effective_date date,
  verified_by text,
  source_url text,
  provenance jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  unique (airport_key,authority,certificate_type,certificate_class)
);

create table if not exists airlinerra.airport_evidence (
  id bigint generated always as identity primary key,
  airport_key text not null references airlinerra.airport_registry(airport_key) on delete restrict,
  evidence_type text not null,
  source_authority text,
  source_url text,
  source_effective_date date,
  field_values jsonb not null default '{}'::jsonb,
  reliability_status text not null default 'UNVERIFIED',
  reviewer_notes text,
  created_at timestamptz not null default now()
);
create index if not exists airport_evidence_by_airport on airlinerra.airport_evidence(airport_key);

create table if not exists airlinerra.airport_game_profiles (
  airport_key text primary key references airlinerra.airport_registry(airport_key) on delete restrict,
  proposed_category text check (proposed_category in ('Local','Regional','Medium','Large','Major Hub','Mega Hub')),
  final_category text check (final_category in ('Local','Regional','Medium','Large','Major Hub','Mega Hub')),
  slots_per_hour_estimate integer check (slots_per_hour_estimate between 0 and 200),
  capacity_origin text not null default 'UNVERIFIED',
  approved_capacity_per_hour integer,
  category_approved_at timestamptz,
  updated_at timestamptz not null default now(),
  constraint final_tier_has_approval check(final_category is null or category_approved_at is not null),
  constraint no_unauthorized_capacity check(approved_capacity_per_hour is null or capacity_origin = 'OWNER_APPROVED')
);

create table if not exists airlinerra.airport_world_activation (
  world_number smallint not null check (world_number between 1 and 3),
  airport_key text not null references airlinerra.airport_registry(airport_key) on delete restrict,
  active boolean not null default false,
  activated_at timestamptz,
  created_at timestamptz not null default now(),
  primary key (world_number,airport_key),
  constraint inactive_without_activation check(not active or activated_at is not null)
);

create table if not exists airlinerra.airport_review_events (
  id bigint generated always as identity primary key,
  airport_key text not null references airlinerra.airport_registry(airport_key) on delete restrict,
  event_type text not null,
  previous_status text,
  new_status text,
  evidence_url text,
  reviewer text,
  source_run_id text,
  details jsonb not null default '{}'::jsonb,
  recorded_at timestamptz not null default now()
);
create index if not exists airport_review_events_idx on airlinerra.airport_review_events(airport_key,recorded_at desc);

create table if not exists airlinerra.import_batches (
  id bigint generated always as identity primary key,
  source_name text not null,
  github_commit text,
  source_sha256 text,
  imported_rows integer not null default 0,
  import_status text not null default 'IN_PROGRESS',
  started_at timestamptz not null default now(),
  completed_at timestamptz,
  metadata jsonb not null default '{}'::jsonb
);

-- The only public Data API table is a deliberately small non-sensitive
-- site availability record, not a reference to private research rows.
create table if not exists public.airlinerra_site_status (
  id text primary key check(id='main'),
  site_name text not null default 'Airlinerra',
  backend_state text not null check(backend_state in ('ready','maintenance')),
  game_state text not null default 'prelaunch' check(game_state in ('prelaunch','live')),
  source_revision text,
  last_checked_at timestamptz not null default now()
);
alter table public.airlinerra_site_status enable row level security;
revoke all on public.airlinerra_site_status from public, anon, authenticated;
grant select on public.airlinerra_site_status to anon, authenticated;
drop policy if exists "airlinerra_public_site_status_read" on public.airlinerra_site_status;
create policy "airlinerra_public_site_status_read"
on public.airlinerra_site_status for select to anon,authenticated using (id='main');
insert into public.airlinerra_site_status(id,site_name,backend_state,game_state,source_revision)
values('main','Airlinerra','ready','prelaunch','initial-db-2026-10-23')
on conflict(id) do update set backend_state='ready', game_state='prelaunch', source_revision='initial-db-2026-10-23',last_checked_at=now();

-- Defensive RLS even though the research schema is not exposed.
alter table airlinerra.airport_registry enable row level security;
alter table airlinerra.airport_cohorts enable row level security;
alter table airlinerra.airport_codes enable row level security;
alter table airlinerra.airport_runway_observations enable row level security;
alter table airlinerra.airport_access_reviews enable row level security;
alter table airlinerra.airport_certifications enable row level security;
alter table airlinerra.airport_evidence enable row level security;
alter table airlinerra.airport_game_profiles enable row level security;
alter table airlinerra.airport_world_activation enable row level security;
alter table airlinerra.airport_review_events enable row level security;
alter table airlinerra.import_batches enable row level security;
