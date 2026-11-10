-- Airlinerra gameplay simplification, approved 2026-11-10:
-- All aircraft use ONE modelled turbine/kerosene fuel family for the GAME.
-- THIS IS NOT A REAL-WORLD CLAIM about piston aircraft (notably DC-6).
-- Keep source-linked historical model classifications untouched in v1/v2.
-- No fuel certification, airport supply, refuelling, aircraft dispatch or cash.
create or replace view airlinerra_game.aircraft_game_fuel_family_v1
with (security_invoker = true) as
select
  research.configuration_id,
  research.manufacturer_name,
  research.model_name,
  'TURBINE_KEROSENE_ASSUMED'::text as fuel_family,
  'UNIVERSAL_GAMEPLAY_ASSUMPTION'::text as fuel_evidence_class,
  null::text as evidence_source_url,
  research.fuel_family as research_fuel_family,
  research.fuel_evidence_class as research_fuel_evidence_class,
  research.evidence_source_url as research_source_url,
  research.verified_aircraft_fuel_grade,
  research.certified_installed_engine_id,
  research.inferred_without_installed_engine,
  false::boolean as airport_fuel_compatibility_verified,
  false::boolean as refuelling_approved,
  false::boolean as fuel_financial_settlement_approved
from airlinerra_game.aircraft_fuel_family_reference_v2 research;

revoke all on airlinerra_game.aircraft_game_fuel_family_v1
from public, anon, authenticated;

comment on view airlinerra_game.aircraft_game_fuel_family_v1 is
'Game balancing only: all 271 aircraft use the turbine/kerosene pricing family, including real piston types. Underlying real-model research preserved in separate columns/view. NOT verified fuel grade, airport quote, refuelling authority, dispatch or financial activation.';
