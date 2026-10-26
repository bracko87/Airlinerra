-- Airlinerra game/account foundation — REVIEW ONLY, NOT APPLIED.
-- Prepared 2026-10-26, for a future OWNER-AUTHORIZED Supabase migration.
-- IMPORTANT: do NOT execute this against production until the launch schema
-- approval, privacy/legal terms, backfill plan and current schema checks.
-- Does NOT touch private airport research schema: airlinerra.*.
-- Does NOT activate gameplay, grant research access, or create actual airlines.
begin;

create schema if not exists airlinerra_game;
revoke all on schema airlinerra_game from public, anon, authenticated;

-- Public directory contains ONLY non-sensitive metadata.
-- No real world is open. Values become mutable only by a trusted operator.
create table if not exists public.airlinerra_game_worlds (
  id smallint primary key check (id between 1 and 3),
  name text not null,
  state text not null default 'planned'
    check (state in ('planned','registration_open','active','locked','retired')),
  registered_at timestamptz not null default now(),
  opens_at timestamptz,
  constraint game_world_name_length check (char_length(name) between 2 and 80)
);
alter table public.airlinerra_game_worlds enable row level security;
revoke all on public.airlinerra_game_worlds from public, anon, authenticated;
grant select on public.airlinerra_game_worlds to anon, authenticated;
create policy "World directory is publicly readable"
  on public.airlinerra_game_worlds for select to anon, authenticated
  using (true);

insert into public.airlinerra_game_worlds (id, name, state) values
  (1,'Founding World','planned'),
  (2,'Expansion World','planned'),
  (3,'Future World','planned')
on conflict (id) do nothing;

-- Profiles are optional until a verified, authenticated user creates one.
-- Do not trust editable profile fields for operator roles or entitlement.
create table if not exists public.airlinerra_player_profiles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null
    check (char_length(trim(display_name)) between 2 and 40),
  locale text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table public.airlinerra_player_profiles enable row level security;
revoke all on public.airlinerra_player_profiles from public, anon, authenticated;
grant select, insert, update (display_name, locale, updated_at)
  on public.airlinerra_player_profiles to authenticated;
create policy "Profile owner can read"
  on public.airlinerra_player_profiles for select to authenticated
  using ((select auth.uid()) = user_id
    and coalesce((select auth.jwt())->>'is_anonymous', 'false') = 'false');
create policy "Profile owner can insert"
  on public.airlinerra_player_profiles for insert to authenticated
  with check ((select auth.uid()) = user_id
    and coalesce((select auth.jwt())->>'is_anonymous', 'false') = 'false');
create policy "Profile owner can update"
  on public.airlinerra_player_profiles for update to authenticated
  using ((select auth.uid()) = user_id
    and coalesce((select auth.jwt())->>'is_anonymous', 'false') = 'false')
  with check ((select auth.uid()) = user_id
    and coalesce((select auth.jwt())->>'is_anonymous', 'false') = 'false');

-- Private tables: neither exposed via the Data API nor granted to client roles.
-- Policies are intentionally absent; all state mutations require a vetted
-- server-side transaction subject to fresh identity and entitlement checks.
create table if not exists airlinerra_game.account_entitlements (
  player_id uuid primary key references auth.users(id) on delete cascade,
  trial_started_at timestamptz,
  trial_ends_at timestamptz,
  membership_state text not null default 'none'
    check (membership_state in ('none','trial','active','past_due','expired','suspended')),
  created_at timestamptz not null default now(),
  constraint trial_interval_exact check (
    (trial_started_at is null and trial_ends_at is null)
    or (trial_started_at is not null
        and trial_ends_at = trial_started_at + interval '168 hours')
  )
);
alter table airlinerra_game.account_entitlements enable row level security;

create table if not exists airlinerra_game.world_memberships (
  world_id smallint not null references public.airlinerra_game_worlds(id),
  player_id uuid not null references auth.users(id) on delete cascade,
  state text not null default 'reserved'
    check (state in ('reserved','active','suspended','left')),
  joined_at timestamptz not null default now(),
  primary key (world_id,player_id)
);
alter table airlinerra_game.world_memberships enable row level security;

create table if not exists airlinerra_game.airlines (
  id uuid primary key default gen_random_uuid(),
  world_id smallint not null,
  owner_player_id uuid not null,
  name text not null
    check (char_length(trim(name)) between 3 and 80),
  home_airport_source_id bigint not null,
  -- Research source IDs are NOT gameplay approvals. Before airlines can
  -- exist, a server transaction must check a separately approved game roster.
  cash_usd numeric(18,2) not null default 0 check (cash_usd >= 0),
  created_at timestamptz not null default now(),
  unique (world_id,owner_player_id),
  foreign key (world_id,owner_player_id)
    references airlinerra_game.world_memberships(world_id,player_id)
);
create unique index if not exists airlinerra_airline_name_per_world
  on airlinerra_game.airlines(world_id,lower(name));
alter table airlinerra_game.airlines enable row level security;

create table if not exists airlinerra_game.airline_ledger (
  id bigint generated always as identity primary key,
  airline_id uuid not null references airlinerra_game.airlines(id),
  entry_kind text not null,
  amount_usd numeric(18,2) not null check (amount_usd <> 0),
  recorded_at timestamptz not null default now(),
  constraint valid_entry_kind check (
    entry_kind in ('STARTING_CAPITAL','AIRCRAFT_PURCHASE','AIRCRAFT_LEASE','REVENUE','EXPENSE','ADJUSTMENT')
  )
);
-- Exactly one startup grant ($5 million) per airline; future secure
-- activation transaction must create its ledger entry and balance atomically.
create unique index if not exists airlinerra_one_startup_credit_per_airline
  on airlinerra_game.airline_ledger (airline_id)
  where entry_kind = 'STARTING_CAPITAL';
alter table airlinerra_game.airline_ledger enable row level security;

-- Defensive grants. No anon or authenticated privileges on private schema.
revoke all on all tables in schema airlinerra_game from public, anon, authenticated;
revoke all on all sequences in schema airlinerra_game from public, anon, authenticated;
commit;
