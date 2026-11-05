-- Airlinerra aircraft-profile live fleet inventory foundation.
-- Applied to production on 2026-11-05. This records only real airframes,
-- not the isolated airline_aircraft_test_fixtures used by engine tests.
-- One row is one airline-controlled aircraft. No sample rows inserted.
create table if not exists airlinerra_game.airline_aircraft_inventory (
 id uuid primary key default gen_random_uuid(),
 airline_id uuid not null references airlinerra_game.airlines(id) on delete cascade,
 configuration_id bigint not null references airlinerra.aircraft_configurations(id),
 registration text not null,
 ownership_type text not null check (ownership_type in ('owned','leased')),
 fleet_status text not null default 'in_service'
  check (fleet_status in ('in_service','maintenance','stored','retired')),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 constraint airline_aircraft_inventory_registration_unique unique (airline_id,registration)
);
create index if not exists airline_aircraft_inventory_usage_idx
 on airlinerra_game.airline_aircraft_inventory(configuration_id,fleet_status,airline_id);
alter table airlinerra_game.airline_aircraft_inventory enable row level security;
comment on table airlinerra_game.airline_aircraft_inventory is
 'Real airline airframe inventory for future ownership/leasing lifecycle; excludes test fixtures. Each row is one actual aircraft and is only exposed via server-authenticated queries.';
comment on column airlinerra_game.airline_aircraft_inventory.fleet_status is
 'Only in_service counts as currently in use in aircraft profiles; maintenance, stored and retired aircraft are excluded.';

-- This table has deliberately no direct browser-facing RLS grants or policies.
-- Private aircraft-library endpoint authenticates the user and reads the report
-- via its existing server-side PostgreSQL pool connection.
