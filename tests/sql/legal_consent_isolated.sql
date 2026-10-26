-- Disposable PostgreSQL / synthetic legal acceptance assertions ONLY.
-- Requires bootstrap, both schema drafts and disposable account fixtures.
-- Does not modify the real Airlinerra Supabase project.
do $consent_rules$
declare
  legal_count integer;
  previous_at timestamptz;
  current_at timestamptz;
begin
  if has_schema_privilege('anon','airlinerra_game','USAGE')
     or has_schema_privilege('authenticated','airlinerra_game','USAGE')
     or has_table_privilege('anon','airlinerra_game.account_consents','INSERT')
     or has_table_privilege('authenticated','airlinerra_game.account_consents','INSERT')
     or has_table_privilege('authenticated','airlinerra_game.legal_release_policy','UPDATE')
  then
    raise exception 'Client role has access to private legal records';
  end if;

  select count(*) into legal_count
    from airlinerra_game.account_consents
    where terms_version='test-v1' and privacy_version='test-v1';
  if legal_count <> 5 then
    raise exception 'Expected five synthetic accepted accounts, found %',legal_count;
  end if;
  if exists (
    select 1 from airlinerra_game.account_consents
    where player_id='66666666-6666-4666-8666-666666666666'
  ) then
    raise exception 'Unconsented synthetic player was recorded';
  end if;

  select accepted_at into previous_at from airlinerra_game.account_consents
    where player_id='11111111-1111-4111-8111-111111111111'
      and terms_version='test-v1' and privacy_version='test-v1';
  insert into airlinerra_game.account_consents
    (player_id,terms_version,privacy_version)
  values ('11111111-1111-4111-8111-111111111111','test-v1','test-v1')
  on conflict do nothing;
  select accepted_at into current_at from airlinerra_game.account_consents
    where player_id='11111111-1111-4111-8111-111111111111'
      and terms_version='test-v1' and privacy_version='test-v1';
  if previous_at is distinct from current_at then
    raise exception 'Repeated legal acceptance reset original consent timestamp';
  end if;
end;
$consent_rules$;

-- Test policy-version rotation inside a transaction which rolls back.
begin;
  update airlinerra_game.legal_release_policy
     set terms_version='test-v2'
   where id=true;

  do $legal_version_check$
  begin
    if exists (
      select 1 from airlinerra_game.legal_release_policy p
      join airlinerra_game.account_consents c
        on c.terms_version=p.terms_version
       and c.privacy_version=p.privacy_version
      where p.is_published=true and p.id=true
        and c.player_id='11111111-1111-4111-8111-111111111111'
    ) then
      raise exception 'Old consent wrongly accepted after terms changed';
    end if;
    -- A real activation attempt must enforce the updated published
    -- policy, not merely a synthetic JOIN-based consent comparison.
    begin
      perform airlinerra_game.create_airline_once(
        '11111111-1111-4111-8111-111111111111',
        1::smallint,'Should Reject Old Legal Consent','OURAIRPORTS:101');
      raise exception 'Activation unexpectedly accepted an outdated consent';
    exception when check_violation then
      if sqlerrm <> 'Published terms and verified player consent required' then
        raise exception 'Stale consent rejected for incorrect reason: %', sqlerrm;
      end if;
    end;
  end;
  $legal_version_check$;
rollback;

do $original_policy_restored$
begin
  if not exists (
    select 1 from airlinerra_game.legal_release_policy
     where id=true and terms_version='test-v1'
       and privacy_version='test-v1' and is_published=true
  ) then
    raise exception 'Rotated test policy was not rolled back';
  end if;
  raise notice 'Consent isolation, idempotency and policy rotation checks passed';
end;
$original_policy_restored$;
