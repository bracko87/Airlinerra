
create table if not exists airlinerra.airport_commercial_verification (
  airport_key text primary key references airlinerra.airport_registry(airport_key),
  cohort text not null default 'EXPANSION_3906',
  faa_identifier text not null,
  faa_state text,
  faa_ownership_type text,
  faa_reported_use text,
  faa_reported_airport_status text,
  faa_match_status text,
  runway_length_m numeric,
  runway_width_m numeric,
  runway_surface text,
  runway_condition text,
  faa_source_date date not null,
  faa_source_url text not null,
  source_archive_sha256 text,
  evidence_id bigint references airlinerra.airport_evidence(id),
  research_priority integer not null,
  review_bucket text not null,
  part139_certificate_status text not null default 'NOT_CHECKED',
  scheduled_passenger_verification text not null default 'NOT_CHECKED',
  small_aircraft_charter_verification text not null default 'NOT_CHECKED',
  cargo_flight_verification text not null default 'NOT_CHECKED',
  aircraft_compatibility_verification text not null default 'NOT_CHECKED',
  game_admission_status text not null default 'NOT_APPROVED' check (game_admission_status = 'NOT_APPROVED'),
  next_action text not null,
  operator_evidence_url text,
  independent_review_at timestamptz,
  source_research_note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (research_priority between 1 and 100)
);
create index if not exists airport_commercial_verification_queue_order
on airlinerra.airport_commercial_verification(research_priority,review_bucket,airport_key);
create index if not exists airport_commercial_verification_bucket
on airlinerra.airport_commercial_verification(review_bucket);
alter table airlinerra.airport_commercial_verification enable row level security;
revoke all on table airlinerra.airport_commercial_verification from public, anon, authenticated;
comment on table airlinerra.airport_commercial_verification is
  'Prelaunch evidence-gated US local/regional airport commercial carrier review. FAA public use is not air carrier certification, permissions, passenger/cargo activity or gameplay admission.';
