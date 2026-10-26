-- Airlinerra one-time disposable CI guard. NO DDL or DML in this file.
-- Execute BEFORE creating the synthetic auth schema or installing draft tables.
-- Deliberately rejects the shared airport-research project and any reused DB.
do $preflight$
declare
  major_version integer;
begin
  major_version := current_setting('server_version_num')::integer / 10000;
  if current_database() <> 'airlinerra_disposable' then
    raise exception 'Refusing Airlinerra integration testing outside disposable database';
  end if;
  if major_version <> 17 then
    raise exception 'PostgreSQL 17 test target required, got version %', major_version;
  end if;
  if current_user <> 'postgres' then
    raise exception 'Expected isolated PostgreSQL test administrator';
  end if;
  if exists (
    select 1 from pg_namespace
    where nspname in ('airlinerra','airlinerra_game','auth')
  ) then
    raise exception 'Expected empty disposable DB; refusing pre-existing project schemas';
  end if;
  if to_regclass('public.airlinerra_site_status') is not null
     or to_regclass('public.airlinerra_game_worlds') is not null
     or to_regclass('public.airlinerra_player_profiles') is not null then
    raise exception 'This is an existing Airlinerra database, not a disposable test';
  end if;
  raise notice 'Disposable test verified: PostgreSQL 17, empty project, no research schema';
end;
$preflight$;
