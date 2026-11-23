create table if not exists airlinerra.research_source_snapshots (
  source_path text not null,
  source_git_blob_sha text not null,
  source_commit text not null,
  source_kind text not null default 'CSV',
  expected_rows integer not null check (expected_rows >= 0),
  imported_rows integer not null default 0 check(imported_rows >= 0),
  import_status text not null default 'IN_PROGRESS' check(import_status in ('IN_PROGRESS','VERIFIED','FAILED','SUPERSEDED')),
  recorded_at timestamptz not null default now(),
  verified_at timestamptz,
  source_notes text,
  primary key(source_path,source_git_blob_sha)
);
create table if not exists airlinerra.research_source_rows (
  source_path text not null,
  source_git_blob_sha text not null,
  row_number integer not null check(row_number >= 1),
  airport_key text null references airlinerra.airport_registry(airport_key),
  row_data jsonb not null,
  imported_at timestamptz not null default now(),
  primary key(source_path,source_git_blob_sha,row_number),
  foreign key(source_path,source_git_blob_sha) references airlinerra.research_source_snapshots(source_path,source_git_blob_sha)
);
create index if not exists research_source_rows_airport_key_idx on airlinerra.research_source_rows(airport_key);
create index if not exists research_source_rows_path_idx on airlinerra.research_source_rows(source_path,source_git_blob_sha);
alter table airlinerra.research_source_snapshots enable row level security;
alter table airlinerra.research_source_rows enable row level security;
revoke all on airlinerra.research_source_snapshots from public, anon, authenticated;
revoke all on airlinerra.research_source_rows from public, anon, authenticated;
comment on table airlinerra.research_source_snapshots is 'Immutable GitHub source CSV snapshot provenance; research only, never operational approval';
comment on table airlinerra.research_source_rows is 'Versioned original CSV row content keyed to source airport IDs; research only, no direct game access';
