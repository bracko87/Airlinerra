-- Airlinerra aircraft catalog: user-approved duplicate exclusions (2026-11-06)
-- This SQL was executed on production. It preserves all referenced performance,
-- engine, noise and runway research; only the customer-facing catalog excludes
-- the unwanted configurations through its read-only query.
create table if not exists airlinerra.aircraft_catalog_configuration_exclusions (
 configuration_id bigint primary key references airlinerra.aircraft_configurations(id) on delete cascade,
 retained_configuration_id bigint not null references airlinerra.aircraft_configurations(id),
 reason text not null,
 created_at timestamptz not null default now(),
 constraint aircraft_catalog_not_self_exclusion check (configuration_id <> retained_configuration_id)
);
alter table airlinerra.aircraft_catalog_configuration_exclusions enable row level security;
comment on table airlinerra.aircraft_catalog_configuration_exclusions is
 'Configurations excluded from the playable aircraft catalog as user-approved duplicates. Historical performance, certification, runway screens and provenance remain intact.';
insert into airlinerra.aircraft_catalog_configuration_exclusions
 (configuration_id,retained_configuration_id,reason)
values
 (60,89,'Duplicate Dash 8-300 combi display entry: retain verified Air Inuit combi; preserve baseline research and airport screens.'),
 (150,58,'Duplicate DHC-6-300 passenger display entry: retain canonical passenger baseline; preserve Air Kiribati 300HG research and airport screens.')
on conflict (configuration_id) do update set
 retained_configuration_id=excluded.retained_configuration_id,
 reason=excluded.reason;

-- The secure catalog API is the authoritative player aircraft list.
-- Add to AIRCRAFT_LIBRARY_SQL before ORDER BY:
-- where not exists (
--  select 1 from airlinerra.aircraft_catalog_configuration_exclusions exclusion
--  where exclusion.configuration_id=c.id
-- )
-- Excluded (not physically destroyed): Dash 8-300 COMBI-BASE (#60)
--    -> kept AIR-INUIT-PASSENGER combi (#89, verified).
-- Excluded: DHC-6-300 AIR-KIRIBATI-300HG (#150)
--    -> kept PASSENGER-BASE (#58).
-- Each excluded record has 3,141 airport compatibility rows plus other
-- research dependencies, so permanent deletion without comprehensive
-- migration would destroy independent technical evidence.
-- No policies or grants expose exclusions to browser clients.
