-- Run ONLY in a disposable, isolated Supabase/PostgreSQL test environment
-- AFTER applying both review-only SQL drafts.
-- Read-only checks; this file does not populate accounts or open worlds.
-- Invocation: psql -v ON_ERROR_STOP=1 -f tests/sql/airline_activation_isolated_assertions.sql
do $airlinerra_test$
declare
  f record;
  expected text;
begin
  if not exists (select 1 from pg_namespace where nspname='airlinerra_game') then
    raise exception 'private game schema missing';
  end if;

  if has_schema_privilege('anon','airlinerra_game','USAGE')
     or has_schema_privilege('authenticated','airlinerra_game','USAGE') then
    raise exception 'private schema leaked to public roles';
  end if;

  if (select count(*) from public.airlinerra_game_worlds) <> 3
     or exists (
        select 1 from public.airlinerra_game_worlds
         where state <> 'planned'
       ) then
    raise exception 'launch worlds must be exactly three and all planned';
  end if;

  if (select count(*) from airlinerra_game.approved_game_airports) <> 0 then
    raise exception 'no game airport can be approved at prelaunch';
  end if;

  if (select count(*) from airlinerra_game.airlines) <> 0
     or (select count(*) from airlinerra_game.airline_ledger) <> 0
     or (select count(*) from airlinerra_game.account_entitlements) <> 0
     or (select count(*) from airlinerra_game.world_memberships) <> 0 then
    raise exception 'no prelaunch airline, trial, money or membership can exist';
  end if;

  if not exists (
    select 1 from airlinerra_game.platform_release_gate
     where id = true and enabled = false
  ) then
    raise exception 'platform gate must exist and be disabled';
  end if;

  if exists (select 1 from airlinerra_game.legal_release_policy) then
    raise exception 'legal release policy must not be pre-approved';
  end if;

  -- Verify the actual function call is denied while the release gate
  -- is disabled, before any test account or airport has been prepared.
  begin
    perform airlinerra_game.create_airline_once(
      '11111111-1111-4111-8111-111111111111',1,'Closed By Default',101);
    raise exception 'Activation succeeded despite a disabled platform gate';
  exception when check_violation then null;
  end;

  if has_function_privilege('anon',
     'airlinerra_game.create_airline_once(uuid,smallint,text,bigint)','EXECUTE')
     or has_function_privilege('authenticated',
     'airlinerra_game.create_airline_once(uuid,smallint,text,bigint)','EXECUTE')
  then
    raise exception 'private activation function exposed to browser roles';
  end if;

  for f in
    select n.nspname,c.relname,c.relrowsecurity
      from pg_class c join pg_namespace n on n.oid=c.relnamespace
     where n.nspname='airlinerra_game'
       and c.relkind in ('r','p')
  loop
    if not f.relrowsecurity then
      raise exception 'private table missing RLS: %',f.relname;
    end if;
  end loop;

  if not exists (
    select 1 from pg_indexes
    where schemaname='airlinerra_game'
      and indexname='airlinerra_one_startup_credit_per_airline'
      and indexdef ilike '%UNIQUE%'
  ) then
    raise exception 'exactly-once startup credit index missing';
  end if;

  if not exists (
    select 1 from pg_constraint
    where conname='airlines_world_id_owner_player_id_key'
      and contype='u'
  ) then
    raise exception 'one airline per user per world uniqueness missing';
  end if;

  if not exists (
    select 1 from pg_trigger
    where tgname='airlinerra_airline_world_gate' and not tgisinternal
  ) then
    raise exception 'world-state insert guard trigger missing';
  end if;

  raise notice 'Airlinerra isolated schema invariants passed; no game data created';
end;
$airlinerra_test$;
