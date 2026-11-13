-- Montenegro Official Gazette 156/2026: Tivat mandatory opening 07:00-16:30
-- every day 2026-10-25 through 2027-03-27, local time.
-- Outside-hours landings/departures need prior operator consent and daylight
-- (SR-30 min to SS+30 min). This is an evidence-only review rule, NOT a
-- blanket ban or operational clearance. No auto enforcement or grant.
INSERT INTO airlinerra_game.section5_airport_time_restrictions_v1
(world_id,airport_key,airport_code,rule_code,rule_kind,affected_operations,
 local_start,local_end,weekday_iso,prohibit_normal_scheduled,game_auto_enforcement,
 exceptions_expected,source_url,evidence_authority,evidence_note,evidence_checked_on,
 applies_aircraft_use_types,active_from,active_until)
SELECT 1::smallint,'OURAIRPORTS:4615','LYTV',
 'TIVAT_WINTER_2026_27_OUTSIDE_MANDATORY_OPEN_HOURS',
 'OPERATING_HOURS_REVIEW','both',
 '16:30'::time,'07:00'::time,NULL::smallint[],false,false,true,
 'https://www.sluzbenilist.me/propisi/399378',
 'MONTENEGRO_OFFICIAL_GAZETTE_156_2026',
 'Order 05-348/26-7787/2 effective 2026-10-25. Tivat must be open daily 07:00-16:30 local to 2027-03-27. Flight outside published hours requires prior airport operator consent and daylight SR-30 min to SS+30 min. This entry is review-only: not a blanket curfew, no automatic clearance or exception grant. Full text: https://invero.me/montenegro/legislation/naredbu-o-vremenu-u-kojem-aerodromi-moraju-biti-otvoreni-za-vazdusni-saobracaj--doc8e8bf318',
 DATE '2026-11-13',ARRAY['passenger','cargo','combi']::text[],
 DATE '2026-10-25',DATE '2027-03-27'
WHERE EXISTS (
 SELECT 1 FROM airlinerra_game.airport_reference_profiles p
 WHERE p.world_id=1 AND p.airport_key='OURAIRPORTS:4615'
   AND p.icao_reported='LYTV' AND p.country_iso='ME'
)
ON CONFLICT (world_id,airport_key,rule_code) DO NOTHING;
