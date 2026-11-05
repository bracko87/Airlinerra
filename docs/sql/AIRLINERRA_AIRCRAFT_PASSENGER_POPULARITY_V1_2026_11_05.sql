-- Mirror of applied Supabase production migration: aircraft_passenger_popularity_v1_20261105
-- Retained for code review, recovery and reproducible environments.
create table if not exists airlinerra_game.aircraft_passenger_popularity_v1 (
  configuration_id bigint primary key references airlinerra.aircraft_configurations(id) on delete cascade,
  popularity_score smallint not null check (popularity_score between 1 and 6),
  passenger_demand_multiplier numeric(4,2) generated always as (
    case popularity_score
      when 1 then 0.60
      when 2 then 0.75
      when 3 then 0.90
      when 4 then 1.00
      when 5 then 1.15
      when 6 then 1.30
    end
  ) stored,
  basis text not null default 'GAME_DESIGN_ESTIMATE_V1' check (basis='GAME_DESIGN_ESTIMATE_V1'),
  updated_at timestamptz not null default now()
);
comment on table airlinerra_game.aircraft_passenger_popularity_v1 is 'Airlinerra fictional/game-balanced passenger preference by aircraft configuration, not a survey, safety rating, certification or dispatch permission. No cargo-only scores. Demand effect is not live until a passenger booking engine calls it.';
comment on column airlinerra_game.aircraft_passenger_popularity_v1.popularity_score is 'Game passenger preference: 1 = very low, 6 = very high; model baseline, not individual airframe condition';
comment on column airlinerra_game.aircraft_passenger_popularity_v1.passenger_demand_multiplier is 'Proposed strong demand multiplier for later booking integration; not automatically applied to live routes.';
alter table airlinerra_game.aircraft_passenger_popularity_v1 enable row level security;
revoke all on airlinerra_game.aircraft_passenger_popularity_v1 from public, anon, authenticated;
insert into airlinerra_game.aircraft_passenger_popularity_v1(configuration_id,popularity_score)
select c.id,
  (case
    when m.name='Airbus' and (v.model_name ~ '^(A350|A380|A320neo|A319neo|A321neo|A321LR|A321XLR|A330-.*neo)') then 6
    when m.name='Airbus Canada' and v.model_name like 'A220-%' then 6
    when m.name='Boeing' and (v.model_name like '787-%' or v.model_name in ('747-8 Intercontinental','777-9')) then 6
    when m.name='Embraer' and v.model_name in ('E190-E2','E195-E2') then 6
    when m.name='Airbus' and (v.model_name ~ '^A(319-100|320-200|321-100|321-200|330-200|330-300|340-600)$') then 5
    when m.name='Airbus' and v.model_name ~ '^A(300|310)' then 3
    when m.name='Airbus' and v.model_name ~ '^A340' then 4
    when m.name='Boeing' and (v.model_name ~ '^(737 MAX|737-800$|737-8200$|737-900ER$|777-|747-400$)') then 5
    when m.name='Boeing' and v.model_name ~ '^737-200' then 1
    when m.name='Boeing' and v.model_name ~ '^(737-300|737-400|Boeing 737-400|Boeing 737-500)' then 3
    when m.name='Boeing' and v.model_name ~ '^(737-600|737-700|737-900$|757-|767-)' then 4
    when m.name='Embraer' and v.model_name ~ '^E(170|175|190|195)$' then 5
    when m.name='ATR' and v.model_name ~ '(42|72)-600$' then 5
    when m.name='ATR' and v.model_name ~ '(42|72)-500$' then 4
    when m.name='De Havilland Canada' and v.model_name ~ '^Dash 8-400' then 5
    when m.name='Bombardier' and v.model_name='CRJ200' then 2
    when m.name='Bombardier' and v.model_name ~ '^CRJ' then 4
    when m.name='COMAC' and v.model_name like 'C919%' then 4
    when m.name='COMAC' then 3
    when m.name='Ilyushin' and v.model_name='Il-62M' then 1
    when m.name='Ilyushin' and v.model_name='Il-96-300' then 2
    when m.name='Ilyushin' and v.model_name='Il-114-300' then 4
    when m.name='Tupolev' and v.model_name='Tu-154B-2' then 1
    when m.name='Tupolev' then 2
    when m.name='Yakovlev' and v.model_name='Yak-40' then 1
    when m.name='Yakovlev' and v.model_name='Yak-42D' then 2
    when m.name='Yakovlev' and v.model_name in ('MC-21-310','SJ-100 (PD-8)') then 4
    when m.name='Antonov' and v.model_name='An-24' then 1
    when m.name='Antonov' and v.model_name='An-148-100' then 3
    when m.name='Antonov' then 2
    when m.name='Xian Aircraft' and v.model_name='MA60' then 2
    when m.name='Xian Aircraft' then 3
    when v.production_start_year is null then 3
    when v.production_start_year>=2014 then 5
    when v.production_start_year>=2003 then 4
    when v.production_start_year>=1980 then 3
    when v.production_start_year>=1970 then 2
    else 1
  end)::smallint
from airlinerra.aircraft_configurations c
join airlinerra.aircraft_variants v on v.id=c.variant_id
join airlinerra.aircraft_families f on f.id=v.family_id
join airlinerra.aircraft_manufacturers m on m.id=f.manufacturer_id
where c.use_type in ('passenger','combi')
on conflict (configuration_id) do nothing;

