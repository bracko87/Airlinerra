-- Negative activation paths, disposable PostgreSQL only.
do $cases$
begin
  -- Neither a closed third world nor an unapproved airport may be used.
  begin
    perform airlinerra_game.create_airline_once(
      '11111111-1111-4111-8111-111111111111',3,'Illegal Third World',101);
    raise exception 'Closed world unexpectedly accepted activation';
  exception when check_violation then null;
  end;

  begin
    perform airlinerra_game.create_airline_once(
      '11111111-1111-4111-8111-111111111111',2,'Wrong Airport',101);
    raise exception 'Wrong-world airport unexpectedly admitted';
  exception when check_violation then null;
  end;

  begin
    perform airlinerra_game.create_airline_once(
      '22222222-2222-4222-8222-222222222222',1,'Expired Member',101);
    raise exception 'Expired trial unexpectedly admitted';
  exception when check_violation then null;
  end;

  begin
    perform airlinerra_game.create_airline_once(
      '44444444-4444-4444-8444-444444444444',1,'Banned Pilot',101);
    raise exception 'Banned user unexpectedly admitted';
  exception when check_violation then null;
  end;

  begin
    perform airlinerra_game.create_airline_once(
      '55555555-5555-4555-8555-555555555555',1,'Suspended Operator',101);
    raise exception 'Suspended membership unexpectedly admitted';
  exception when check_violation then null;
  end;

  begin
    perform airlinerra_game.create_airline_once(
      '66666666-6666-4666-8666-666666666666',1,'Missing Consent',101);
    raise exception 'Unconsented user unexpectedly admitted';
  exception when check_violation then null;
  end;

  if exists (
    select 1 from airlinerra_game.airlines
  ) then
    raise exception 'Failed validation mutated live test airlines';
  end if;
  raise notice 'Negative activation paths correctly rejected';
end;
$cases$;
