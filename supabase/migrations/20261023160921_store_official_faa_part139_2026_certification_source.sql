
create table if not exists airlinerra.faa_part139_source_rows (
 effective_date date not null,
 source_row integer not null check (source_row>0),
 state text not null check (state ~ '^[A-Z]{2}$'),
 faa_identifier text not null,
 airport_name text not null,
 associated_city text,
 part139_class text,
 arff_index text,
 inactive_status text,
 hub_size text,
 npias_role text,
 atct text,
 sms_trigger text,
 sms_waiver text,
 source_sheet text not null,
 source_url text not null,
 source_size_bytes integer not null,
 raw_record jsonb not null,
 imported_at timestamptz not null default now(),
 primary key(effective_date,source_row),
 unique(effective_date,state,faa_identifier)
);
create index if not exists faa_part139_by_airport_code on airlinerra.faa_part139_source_rows(effective_date,faa_identifier,state);
alter table airlinerra.faa_part139_source_rows enable row level security;
revoke all on airlinerra.faa_part139_source_rows from public,anon,authenticated;
comment on table airlinerra.faa_part139_source_rows is 'FAA official 2026-09-03 Part 139 published XLSX source snapshot; research only, not commercial flight authorization.';

create table if not exists airlinerra.faa_part139_import_manifest (
 effective_date date primary key,
 source_url text not null,
 source_size_bytes integer not null,
 expected_records integer not null check(expected_records>0),
 imported_records integer not null default 0,
 data_digest_md5 text,
 import_status text not null default 'IN_PROGRESS' check(import_status in ('IN_PROGRESS','VERIFIED','FAILED')),
 source_header jsonb not null default '{}'::jsonb,
 source_sheet text,
 imported_at timestamptz not null default now(),
 verified_at timestamptz,
 notes text
);
alter table airlinerra.faa_part139_import_manifest enable row level security;
revoke all on airlinerra.faa_part139_import_manifest from public,anon,authenticated;
comment on table airlinerra.faa_part139_import_manifest is 'Per-source audit of official FAA certification spreadsheet imports, with exact effective date and normalized-row digest.';
