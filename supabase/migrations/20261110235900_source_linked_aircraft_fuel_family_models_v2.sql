-- Manufacturer / engine-maker model-level fuel family evidence for the
-- 18 catalog aircraft whose specific engine_option field was not filled.
-- This research supports the general TURBINE fuel family, NOT any
-- individual aircraft's installed powerplant, specific approved fuel
-- grade, airport pump availability, or financial/dispatch activation.
create or replace view airlinerra_game.aircraft_fuel_family_reference_v2
with (security_invoker = true) as
with model_evidence(configuration_id,expected_model,source_url) as
(values
( 11::bigint, 'E195-E2'::text, 'https://www.rtx.com/news/news-center/2026/04/28/pratt-whitney-recognized-as-embraers-best-supplier-of-the-year-for-outstanding'::text),
( 13::bigint, 'A220-100'::text, 'https://www.aircraft.airbus.com/en/newsroom/stories/2025-08-a-geared-propulsion-system-to-deliver-industry-leading-efficiency'::text),
( 14::bigint, 'A220-300'::text, 'https://www.aircraft.airbus.com/en/newsroom/stories/2025-08-a-geared-propulsion-system-to-deliver-industry-leading-efficiency'::text),
( 23::bigint, 'A340-600'::text, 'https://www.rolls-royce.com/products-and-services/civil-aerospace/widebody/trent-500.aspx'::text),
( 45::bigint, '767-300BCF'::text, 'https://services.boeing.com/news/boeing-completes-750-quick-engine-change-kit'::text),
( 46::bigint, '767-300BDSF'::text, 'https://services.boeing.com/news/boeing-completes-750-quick-engine-change-kit'::text),
( 50::bigint, '777-200ER'::text, 'https://www.boeing.com/commercial/777'::text),
( 53::bigint, '787-8'::text, 'https://www.boeing.com/content/theboeingcompany/us/en/commercial/787.html'::text),
( 54::bigint, '787-9'::text, 'https://www.boeing.com/content/theboeingcompany/us/en/commercial/787.html'::text),
( 60::bigint, 'Dash 8-300'::text, 'https://www.mtu.de/de/engines/zivile-triebwerke/turboprops/pw100/150a/'::text),
( 79::bigint, 'E195'::text, 'https://www.ge.com/news/press-releases/copa-orders-cf34-10-powered-embarer-190-aircraft'::text),
( 84::bigint, '787-10'::text, 'https://www.boeing.com/content/theboeingcompany/us/en/commercial/787.html'::text),
( 95::bigint, 'EMB 120 Brasilia'::text, 'https://www.embraer.com/centro-historico-aeronaves-historicas-emb-120-brasilia/pt/'::text),
( 102::bigint, 'Dornier 328-110'::text, 'https://www.mtu.de/de/engines/zivile-triebwerke/turboprops/pw100/150a/'::text),
( 123::bigint, 'Beechcraft 1900C'::text, 'https://www.rtx.com/prattwhitney/products/general-aviation-engines/pt6a'::text),
( 162::bigint, 'A300-600R'::text, 'https://www.airbus.com/en/newsroom/stories/2022-10-28-october-50th-anniversary-of-the-first-flight-of-the-airbus-a300'::text),
( 163::bigint, 'A310-300'::text, 'https://www.airbus.com/en/newsroom/stories/2022-10-28-october-50th-anniversary-of-the-first-flight-of-the-airbus-a300'::text),
( 167::bigint, 'A310-300'::text, 'https://www.airbus.com/en/newsroom/stories/2022-10-28-october-50th-anniversary-of-the-first-flight-of-the-airbus-a300'::text)
)
select b.configuration_id,b.manufacturer_name,b.model_name,
 case when b.fuel_family='UNKNOWN_ENGINE' and e.configuration_id is not null
  then 'TURBINE_KEROSENE_ASSUMED' else b.fuel_family end as fuel_family,
 case when b.fuel_family='UNKNOWN_ENGINE' and e.configuration_id is not null
  then 'MANUFACTURER_MODEL_FAMILY_REFERENCE' else b.fuel_evidence_class end as fuel_evidence_class,
 coalesce(e.source_url,b.evidence_source_url) as evidence_source_url,
 b.verified_aircraft_fuel_grade,
 b.certified_installed_engine_id,
 b.airport_fuel_compatibility_verified,
 b.refuelling_approved,
 b.fuel_financial_settlement_approved,
 (b.fuel_family='UNKNOWN_ENGINE' and e.configuration_id is not null) as inferred_without_installed_engine
from airlinerra_game.aircraft_fuel_family_reference_v1 b
left join model_evidence e on e.configuration_id=b.configuration_id and e.expected_model=b.model_name;

revoke all on airlinerra_game.aircraft_fuel_family_reference_v2
from public, anon, authenticated;
comment on view airlinerra_game.aircraft_fuel_family_reference_v2 is
'18 source-linked model-level turbine family classifications, preserving 1 gasoline DC-6; exact tail engine/fuel grade unverified. No refuelling, dispatch, cash.';
