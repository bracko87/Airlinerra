-- Runs only after eight same-player activation calls have completed in
-- disposable PostgreSQL 17. Must not run on Airlinerra's real database.
do $verify$
declare
  v_first_trial timestamptz;
  v_second record;
  v_paid record;
  v_replay record;
begin
  if (select count(*) from airlinerra_game.airlines) <> 1 then
    raise exception 'Two competing requests created an incorrect airline count';
  end if;
  if (select count(*) from airlinerra_game.airline_ledger
      where entry_kind='STARTING_CAPITAL') <> 1 then
    raise exception 'Duplicate or absent startup credit';
  end if;
  if (select cash_usd from airlinerra_game.airlines
      where owner_player_id='11111111-1111-4111-8111-111111111111') <> 5000000.00 then
    raise exception 'Starting balance should be exactly 5 million';
  end if;
  if (select count(*) from airlinerra_game.account_entitlements
      where player_id='11111111-1111-4111-8111-111111111111'
        and membership_state='trial'
        and trial_ends_at=trial_started_at + interval '168 hours') <> 1 then
    raise exception 'One-time 168-hour trial missing';
  end if;

  select e.trial_ends_at into v_first_trial
  from airlinerra_game.account_entitlements e
  where player_id='11111111-1111-4111-8111-111111111111';

  select * into v_replay from airlinerra_game.create_airline_once(
    '11111111-1111-4111-8111-111111111111',1::smallint,'Aurelia Airways','OURAIRPORTS:101');
  if v_replay.newly_created or v_replay.starting_balance_usd <> 5000000.00 then
    raise exception 'Replay changed previously created airline';
  end if;

  begin
    perform airlinerra_game.create_airline_once(
      '11111111-1111-4111-8111-111111111111',1::smallint,'A Different Airline','OURAIRPORTS:101');
    raise exception 'Changed-name replay succeeded';
  exception when unique_violation then null;
  end;

  select * into v_second from airlinerra_game.create_airline_once(
    '11111111-1111-4111-8111-111111111111',2::smallint,'Atlantic Routes','FICTIONAL:fictional:RS:LYAL');
  if not v_second.newly_created or v_second.starting_balance_usd <> 5000000.00 then
    raise exception 'Second world must create a new airline with only one credit';
  end if;
  if (select e.trial_ends_at from airlinerra_game.account_entitlements e
      where e.player_id='11111111-1111-4111-8111-111111111111') is distinct from v_first_trial then
    raise exception 'Second world restarted or modified account-wide trial';
  end if;

  -- Already-paid player without a prior trial must not be forced to take one.
  select * into v_paid from airlinerra_game.create_airline_once(
    '33333333-3333-4333-8333-333333333333',1::smallint,'Paid Flyer','OURAIRPORTS:101');
  if not v_paid.newly_created or v_paid.starting_balance_usd <> 5000000.00 then
    raise exception 'Paid membership without a trial should be eligible';
  end if;
  if exists (
    select 1 from airlinerra_game.account_entitlements
    where player_id='33333333-3333-4333-8333-333333333333'
      and (membership_state<>'active'
        or trial_started_at is not null
        or trial_ends_at is not null)
  ) then
    raise exception 'Paid membership should not start a new trial';
  end if;

  if (select count(*) from airlinerra_game.airlines) <> 3
     or (select count(*) from airlinerra_game.airline_ledger
         where entry_kind='STARTING_CAPITAL') <> 3
     or (select count(*) from airlinerra_game.world_memberships
         where state='active') <> 3 then
    raise exception 'Cross-world ledger/member counts are incorrect';
  end if;
  if exists (select 1 from airlinerra_game.airlines where cash_usd <> 5000000.00) then
    raise exception 'An airline received incorrect starting funds';
  end if;
  raise notice 'Concurrent startup credit, replay, paid plan and two-world invariants passed';
end;
$verify$;
