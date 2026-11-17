-- Game-only fuel model release. These are estimated in-game values,
-- NOT real-world aircraft performance or certified dispatch data.
-- Global flight execution and ledger-posting policies remain paused.
begin;
alter table airlinerra_game.section9_game_fuel_model_snapshot_v1
 drop constraint section9_game_fuel_model_sna_operational_dispatch_release_check,
 drop constraint section9_game_fuel_model_sna_financial_settlement_release_check,
 add constraint section9_fuel_model_dispatch_state_game_v2
 check (operational_dispatch_release in ('NOT_RELEASED','RELEASED')),
 add constraint section9_fuel_model_finance_state_game_v2
 check (financial_settlement_release in ('NOT_RELEASED','RELEASED'));
update airlinerra_game.section9_game_fuel_model_snapshot_v1
set operational_dispatch_release='RELEASED',
    financial_settlement_release='RELEASED'
where game_calculation_ready=true and
 tank_capacity_kg>0 and cruise_speed_kmh>0 and
 empty_kg_per_100km>0 and
 half_kg_per_100km>=empty_kg_per_100km and
 full_kg_per_100km>=half_kg_per_100km
 and fuel_game_family='TURBINE_KEROSENE_ASSUMED';
do $$
begin
 if (select count(*) from airlinerra_game.section9_game_fuel_model_snapshot_v1
     where operational_dispatch_release='RELEASED' and financial_settlement_release='RELEASED'
     and game_calculation_ready=true)<>271
 then raise exception 'GAME_FUEL_MODEL_RELEASE_INCOMPLETE';end if;
 if exists (select 1 from airlinerra_game.section9_game_fuel_model_snapshot_v1
  where (operational_dispatch_release='RELEASED' or financial_settlement_release='RELEASED')
   and (game_calculation_ready is distinct from true or tank_capacity_kg is null
   or cruise_speed_kmh<=0 or empty_kg_per_100km<=0 or half_kg_per_100km<empty_kg_per_100km
   or full_kg_per_100km<half_kg_per_100km))
 then raise exception 'INVALID_GAME_FUEL_MODEL_RELEASE';end if;
 if exists (select 1 from airlinerra_game.section9_flight_finance_posting_release_v1
   where release_state='approved')
 then raise exception 'UNEXPECTED_ACTIVE_CASH_POSTING_WHILE_TESTING_GAME_FUEL_MODELS';end if;
end $$;
commit;