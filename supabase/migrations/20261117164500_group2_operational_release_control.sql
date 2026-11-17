-- Explicit owner-controlled airport release ledger; there is no mass activation.
create table if not exists airlinerra_game.airport_group2_operational_releases_v1 (
  world_id smallint not null default 1 check (world_id=1),
  airport_key text not null,
  release_status text not null check (release_status in ('approved','revoked')),
  review_reference text not null check (length(btrim(review_reference))>=8),
  reviewed_at timestamptz not null default now(),
  primary key(world_id,airport_key),
  foreign key(world_id,airport_key)
   references airlinerra_game.airport_sections1_8_combined_members_v1(world_id,airport_key)
);
alter table airlinerra_game.airport_group2_operational_releases_v1 enable row level security;
revoke all on airlinerra_game.airport_group2_operational_releases_v1 from public,anon,authenticated;
create or replace function airlinerra_game.guard_group2_operational_release_v1()
returns trigger language plpgsql set search_path='airlinerra_game','airlinerra','pg_catalog'
as $$
begin
 if not exists(select 1 from airlinerra_game.airport_sections1_8_combined_members_v1 m
   where m.world_id=new.world_id and m.airport_key=new.airport_key and m.source_group='GROUP_2')
 then raise exception 'GROUP2_RELEASE_REQUIRES_GROUP2_AIRPORT'; end if;
 if new.release_status='approved' and not exists (
   select 1 from airlinerra_game.airport_group2_admission_readiness_v1 a
   join airlinerra_game.approved_game_airports registry on registry.world_id=new.world_id and registry.airport_key=a.airport_key
   join airlinerra_game.section6_airport_slot_capacity_v1 slot on slot.world_id=new.world_id and slot.airport_key=a.airport_key
   join airlinerra_game.section5_airport_operating_policy_v1 policy on policy.world_id=new.world_id and policy.airport_key=a.airport_key
   where a.airport_key=new.airport_key
     and a.ready_for_owner_release_review=true
     and a.documented_commercial_prohibition=false
 )
 then raise exception 'GROUP2_RELEASE_REQUIRED_EVIDENCE_OR_OPERATIONAL_ENGINES_MISSING'; end if;
 return new;
end $$;
drop trigger if exists trg_guard_group2_operational_release_v1 on airlinerra_game.airport_group2_operational_releases_v1;
create trigger trg_guard_group2_operational_release_v1
before insert or update on airlinerra_game.airport_group2_operational_releases_v1
for each row execute function airlinerra_game.guard_group2_operational_release_v1();
comment on table airlinerra_game.airport_group2_operational_releases_v1
is 'Owner-reviewed release ledger. Only verified Group 2 airports present in registry/slot/operating engine may be approved. No bulk or implicit activation.';
