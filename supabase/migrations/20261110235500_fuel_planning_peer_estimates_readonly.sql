-- Airlinerra World 1 fuel planning: private, explicitly provisional data coverage.
-- NO dispatch, no game engine enablement and no airline money changes.
-- All 139 model-fallback rates are game estimates using a donor model's
-- provisional km/100 rate, not manufacturer-confirmed consumption.
-- Existing 132 positive rate rows remain unchanged. All types remain unverified.
create or replace view airlinerra_game.aircraft_fuel_planning_profiles_v1
with (security_invoker = true) as
select
 c.configuration_id,
 c.manufacturer_name,
 c.model_name,
 c.use_type,
 c.mtow_kg,
 c.cruise_speed_kmh,
 case when r.full_kg_per_100km > 0 then
   round(r.full_kg_per_100km::numeric,2)
 else round((d.full_kg_per_100km *
   power((c.mtow_kg / d.donor_mtow_kg)::double precision,0.82) *
   power((c.cruise_speed_kmh / d.donor_speed_kmh)::double precision,0.20))::numeric,2)
 end as full_kg_per_100km,
 case when r.full_kg_per_100km > 0 and r.empty_kg_per_100km > 0 then
   round(r.empty_kg_per_100km::numeric,2)
 else round((
   (case when r.full_kg_per_100km > 0 then r.full_kg_per_100km
     else d.full_kg_per_100km *
       power((c.mtow_kg / d.donor_mtow_kg)::double precision,0.82) *
       power((c.cruise_speed_kmh / d.donor_speed_kmh)::double precision,0.20)
   end) * (case when d.empty_kg_per_100km > 0
    then least(.98,greatest(.65,d.empty_kg_per_100km/d.full_kg_per_100km))
    else .86 end))::numeric,2)
 end as empty_kg_per_100km,
 case when r.full_kg_per_100km > 0 and r.half_kg_per_100km > 0 then
   round(r.half_kg_per_100km::numeric,2)
 else round((
   (case when r.full_kg_per_100km > 0 then r.full_kg_per_100km
     else d.full_kg_per_100km *
       power((c.mtow_kg / d.donor_mtow_kg)::double precision,0.82) *
       power((c.cruise_speed_kmh / d.donor_speed_kmh)::double precision,0.20)
   end) * (case when d.half_kg_per_100km > 0
     then least(.99,greatest(.75,d.half_kg_per_100km/d.full_kg_per_100km))
     else .93 end))::numeric,2)
 end as half_kg_per_100km,
 case when r.full_kg_per_100km > 0 then 'EXISTING_PROVISIONAL_DISTANCE_RATE'
 else 'DERIVED_PEER_AIRCRAFT_GAME_ESTIMATE' end as rate_evidence,
 case when r.full_kg_per_100km > 0 then null::bigint else d.donor_id end as reference_peer_configuration_id,
 case when r.full_kg_per_100km > 0 then null::text else d.donor_model end as reference_peer_model,
 case when r.full_kg_per_100km > 0 then null::numeric
 else round((c.mtow_kg / d.donor_mtow_kg)::numeric,3) end as peer_mtow_ratio,
 case when r.full_kg_per_100km > 0 then 'PROVISIONAL_EXISTING'
 when d.donor_id is not null
   and c.manufacturer_name=d.donor_manufacturer
   and c.family_name=d.donor_family
   and c.mtow_kg between d.donor_mtow_kg*.75 and d.donor_mtow_kg*1.25
 then 'ESTIMATE_SAME_FAMILY_PEER'
 when d.donor_id is not null and
   c.mtow_kg between d.donor_mtow_kg*.7 and d.donor_mtow_kg*1.3
 then 'ESTIMATE_MASS_MATCH'
 else 'LOW_CONFIDENCE_PEER_ESTIMATE'
 end as confidence_class,
 cap.fuel_tank_capacity_kg,
 -- This view only models amounts. The type of fuel has NOT been verified.
 'FUEL_TYPE_NEEDS_RESEARCH'::text as fuel_type_status,
 false::boolean as approved_for_dispatch,
 false::boolean as approved_for_accounting,
 true::boolean as requires_further_evidence
from airlinerra.aircraft_catalog_configuration_inventory c
left join airlinerra.aircraft_simple_fuel_per_100km_v1 r
 on r.configuration_id=c.configuration_id
left join airlinerra.aircraft_catalog_fuel_capacity_game_v1 cap
 on cap.configuration_id=c.configuration_id
left join lateral (
 select p.configuration_id as donor_id,
 p.model_name as donor_model,
 p.manufacturer_name as donor_manufacturer,
 p.family_name as donor_family,
 p.mtow_kg as donor_mtow_kg,
 p.cruise_speed_kmh as donor_speed_kmh,
 pr.full_kg_per_100km,
 pr.empty_kg_per_100km,
 pr.half_kg_per_100km
 from airlinerra.aircraft_catalog_configuration_inventory p
 join airlinerra.aircraft_simple_fuel_per_100km_v1 pr
 on pr.configuration_id=p.configuration_id
 where pr.full_kg_per_100km>0
 and p.mtow_kg>0 and p.cruise_speed_kmh>0
 and c.mtow_kg>0 and c.cruise_speed_kmh>0
 and (p.cruise_speed_kmh<=650)=(c.cruise_speed_kmh<=650)
 order by
 (case when p.family_name=c.family_name and
   p.manufacturer_name=c.manufacturer_name then 0 else 1 end)
 + abs(ln(p.mtow_kg/c.mtow_kg))*2
 + abs(ln(p.cruise_speed_kmh/c.cruise_speed_kmh))*.5
 + (case when p.use_type=c.use_type then 0 else .35 end),
 p.configuration_id limit 1
) d on coalesce(r.full_kg_per_100km,0)<=0;

-- Not exposed to browser roles. Protected server tools may read this view.
revoke all on airlinerra_game.aircraft_fuel_planning_profiles_v1
 from public, anon, authenticated;
comment on view airlinerra_game.aircraft_fuel_planning_profiles_v1 is
'Provisional model-specific fuel planning; 139 peer estimates NOT researched manufacturer facts. Read-only. No flight activation, charges, or fuel gameplay enablement.';
