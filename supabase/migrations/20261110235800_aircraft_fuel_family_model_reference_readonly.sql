-- Model-level fuel family evidence for planning only, with no tail-specific certification.
-- The FAA describes turbine/kerosene vs piston/AVGAS:
-- https://www.faa.gov/newsroom/leaded-aviation-fuel-and-environment
-- The DC-6 6A3 Type Certificate (DC-6 series) lists gasoline and R-2800:
-- https://www.enginehistory.org/Operations/WaterInjServErrors/6A3Rev28.pdf
-- Exact registered-engine grade, airport supplier and uplift are NOT verified.
-- This private read-only view does not enable any operational fuel service.

create or replace view airlinerra_game.aircraft_fuel_family_reference_v1
with (security_invoker = true) as
select
 c.configuration_id,
 c.manufacturer_name,
 c.model_name,
 case
   when c.model_name ilike 'DC-6%' and
     c.engine_option ~* '(R-2800|Double Wasp)'
      then 'AVGAS_PISTON'
   when nullif(btrim(c.engine_option),'') is null
      then 'UNKNOWN_ENGINE'
   else 'TURBINE_KEROSENE_ASSUMED'
 end as fuel_family,
 case
   when c.model_name ilike 'DC-6%' and c.engine_option ~* '(R-2800|Double Wasp)'
      then 'TYPE_CERTIFICATE_MODEL_LEVEL'
   when nullif(btrim(c.engine_option),'') is null then 'ENGINE_REFERENCE_MISSING'
   else 'CATALOG_ENGINE_MODEL_ASSUMPTION'
 end as fuel_evidence_class,
 case
   when c.model_name ilike 'DC-6%' and c.engine_option ~* '(R-2800|Double Wasp)'
    then 'https://www.enginehistory.org/Operations/WaterInjServErrors/6A3Rev28.pdf'
   else 'https://www.faa.gov/newsroom/leaded-aviation-fuel-and-environment'
 end as evidence_source_url,
 null::text as verified_aircraft_fuel_grade,
 null::text as certified_installed_engine_id,
 false::boolean as airport_fuel_compatibility_verified,
 false::boolean as refuelling_approved,
 false::boolean as fuel_financial_settlement_approved
from airlinerra.aircraft_catalog_configuration_inventory c;

revoke all on airlinerra_game.aircraft_fuel_family_reference_v1
from public, anon, authenticated;

comment on view airlinerra_game.aircraft_fuel_family_reference_v1 is
'Fuel-family model inference for aviation fuel planning: 1 model-referenced AVGAS piston, turbine model assumptions, missing engine unknown. No tail-specific grade, uplift, dispatch or cash.';
