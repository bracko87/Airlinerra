-- Mirror of applied Supabase production migration: aircraft_passenger_popularity_demand_calculator_v1_20261105
-- Retained for code review, recovery and reproducible environments.
create or replace function airlinerra_game.adjust_passenger_demand_for_popularity_v1(
  p_configuration_id bigint,
  p_base_passengers integer
) returns integer
language sql
stable
strict
security invoker
set search_path = pg_catalog
as $$
  select case
    when p_base_passengers < 0 then null
    when c.use_type not in ('passenger','combi') then null
    when popularity.popularity_score is null then null
    else least(
      round(p_base_passengers::numeric * popularity.passenger_demand_multiplier),
      2147483647::numeric
    )::integer
  end
  from airlinerra.aircraft_configurations c
  left join airlinerra_game.aircraft_passenger_popularity_v1 popularity
    on popularity.configuration_id=c.id
  where c.id=p_configuration_id
$$;
comment on function airlinerra_game.adjust_passenger_demand_for_popularity_v1(bigint,integer) is 'Read-only Airlinerra planning calculator. Adjusts base passenger interest by game-design aircraft appeal. Not automatically connected to live flights, sales or dispatch; does not authorize operation.';
revoke all on function airlinerra_game.adjust_passenger_demand_for_popularity_v1(bigint,integer) from public, anon, authenticated;
