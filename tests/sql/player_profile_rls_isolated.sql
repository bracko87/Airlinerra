-- Run only on disposable PostgreSQL with bootstrap_auth_stubs.sql.
-- Proves player A can read/update their own profile, not player B's.
insert into public.airlinerra_player_profiles (user_id,display_name,locale)
values ('22222222-2222-4222-8222-222222222222','Other Manager','de-DE');

do $roles$
begin
 if has_table_privilege('anon','public.airlinerra_player_profiles','SELECT')
    or has_table_privilege('anon','public.airlinerra_player_profiles','INSERT')
    or has_table_privilege('authenticated','public.airlinerra_player_profiles','DELETE')
    or has_column_privilege('authenticated','public.airlinerra_player_profiles','user_id','UPDATE')
    or has_column_privilege('authenticated','public.airlinerra_player_profiles','created_at','UPDATE')
    or has_column_privilege('authenticated','public.airlinerra_player_profiles','updated_at','UPDATE') then
   raise exception 'Excessive API profile privileges';
 end if;
 if has_function_privilege('authenticated',
      'airlinerra_game.create_airline_once(uuid,smallint,text,bigint)','EXECUTE') then
   raise exception 'Authenticated client can invoke private airline activation';
 end if;
end;
$roles$;

begin;
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"is_anonymous":false}',true);

insert into public.airlinerra_player_profiles (user_id,display_name,locale)
values ('11111111-1111-4111-8111-111111111111','Original Manager','en-US');

update public.airlinerra_player_profiles
 set display_name='Updated Manager'
where user_id='11111111-1111-4111-8111-111111111111';

do $owned_profile$
declare v_count integer; v_name text;
begin
  select count(*) into v_count from public.airlinerra_player_profiles;
  if v_count <> 1 then
    raise exception 'Player can read somebody else''s profile';
  end if;
  select display_name into v_name from public.airlinerra_player_profiles;
  if v_name <> 'Updated Manager' then
    raise exception 'Owner update was not persisted';
  end if;
  begin
    insert into public.airlinerra_player_profiles (user_id,display_name)
    values ('33333333-3333-4333-8333-333333333333','Impostor');
    raise exception 'Cross-account profile insertion was allowed';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.airlinerra_player_profiles
       set user_id='22222222-2222-4222-8222-222222222222'
     where user_id='11111111-1111-4111-8111-111111111111';
    raise exception 'Profile ownership identifier could be reassigned';
  exception when insufficient_privilege then null;
  end;
  begin
    update public.airlinerra_player_profiles
       set created_at='1900-01-01'
     where user_id='11111111-1111-4111-8111-111111111111';
    raise exception 'Immutable creation timestamp could be edited';
  exception when insufficient_privilege then null;
  end;
end;
$owned_profile$;
commit;

-- Anonymous JWTs can carry role "authenticated"; owner policy must still
-- reject them even if the JWT sub matches an existing profile.
begin;
set local role authenticated;
select set_config('request.jwt.claim.sub',
 '11111111-1111-4111-8111-111111111111',true);
select set_config('request.jwt.claims','{"is_anonymous":true}',true);
do $anonymous_check$
begin
 if (select count(*) from public.airlinerra_player_profiles) <> 0 then
   raise exception 'Anonymous authenticated user can read player profile';
 end if;
end;
$anonymous_check$;
commit;

do $success$
begin
 raise notice 'Player profile RLS, restricted grants and anonymous claim checks passed';
end;
$success$;
