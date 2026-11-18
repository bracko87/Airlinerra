-- Independently reviewed maintenance clearance needed for Licence 2.
-- Merely having no open jobs is not evidence of no unresolved critical defect.
begin;
create table if not exists airlinerra_game.licence2_critical_maintenance_clearance_v1(
 world_id smallint not null default 1,
 airline_id uuid not null,
 cleared_game_date date not null,
 clearance_reference text not null check(length(btrim(clearance_reference))>=20),
 verified_by text not null check(length(btrim(verified_by))>=12),
 verified_at timestamptz not null default now(),
 primary key(world_id,airline_id),
 foreign key(world_id,airline_id) references airlinerra_game.airlines(world_id,id),
 constraint licence2_maintenance_clearance_world1_check check(world_id=1)
);
alter table airlinerra_game.licence2_critical_maintenance_clearance_v1 enable row level security;
revoke all on airlinerra_game.licence2_critical_maintenance_clearance_v1 from public,anon,authenticated;
comment on table airlinerra_game.licence2_critical_maintenance_clearance_v1 is
 'Independent owner-reviewed clearance of critical fleet defects; required on the current authoritative game date. No automatic certification.';
commit;