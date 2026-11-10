# Airlinerra Group 2 — Section 5 targeted Medium airport restriction research
Date: 2026-11-10

## User-approved scope
Keep the **754 Local** and **338 Regional** airports simple: no nighttime ban and no aircraft noise Chapter restriction in the *game*, explicitly identified as assumptions. Research the **26 Medium airports** and use source-backed rules where accessible.

## Post-install verified production result

| Category | Total | Neutral game defaults | Source-backed game rules | Restrictions assigned |
|---|---:|---:|---:|---:|
| Local | 754 | 754 | 0 | 0 |
| Regional | 338 | 338 | 0 | 0 |
| Medium | 26 | 19 | 7 | 2 |
| **Total** | **1,118** | **1,111** | **7** | **2** |

Source-backed Medium game profiles:

- **LERL Ciudad Real, Spain:** AirlineSim reports no night ban; noise restricted to **Chapter III / IV**. https://free1.airlinesim.aero/app/info/airports/3872?0=&tabs=0
- **LFPB Paris-Le Bourget, France:** Current French AIP confirms aircraft-type-dependent restrictions; **jet departure from stand prohibited 22:15–06:00 local** under applicable exceptions, other prop and jet arrival restrictions; ICAO noise Chapter and other acoustic constraints. https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_29_OCT_2026/FRANCE/AIRAC-2026-10-29/html/eAIP/FR-AD-2.LFPB-fr-FR.html and https://www.legifrance.gouv.fr/loda/article_lc/LEGIARTI000036691384
- **SADP El Palomar, Argentina:** AirlineSim no nighttime ban, no noise restrictions. https://ellinikon.airlinesim.aero/app/info/airports/99?3=&tabs=0
- **LTAF Adana Şakirpaşa, Türkiye:** AirlineSim no nighttime ban, no noise restrictions. https://yeouido.airlinesim.aero/app/info/airports/2984?2=&tabs=0
- **UKBB Boryspil, Ukraine:** AirlineSim no nighttime ban, no noise restrictions. https://kaitak.airlinesim.aero/app/info/airports/3034?0=&tabs=0
- **UKFF Simferopol, Ukraine:** AirlineSim no nighttime ban, no noise restrictions. https://junkers.airlinesim.aero/app/info/airports/3043?0=&tabs=0
- **YSBK Sydney Bankstown, Australia:** Airservices Australia reports 24-hour operations with noise-abatement procedures, not a Sydney Kingsford Smith-style legislated curfew; no specific ICAO noise Chapter ban found. https://aircraftnoise.airservicesaustralia.com/2020/04/30/bankstown-airport-flight-paths/

The other **19 Medium airports** retain neutral *game defaults*. An online search is not proof that an airport has no restrictions. Missing exact AirlineSim entries, unverified current operating rules and military-only facilities are not represented as sourced.

## Critical distinction for Ukraine and other restricted airports
**Nighttime-ban = No** is not permission to operate. Ukraine's civil airspace has been closed to civilian operations as of November 2026, independently of any historical game curfew/noise model. https://www.easa.europa.eu/en/domains/air-operations/czibs/czib-2022-01r14 and https://www.kmu.gov.ua/en/news/uriad-ukhvalyv-stratehichni-rishennia-dlia-rozvytku-tsyvilnoi-aviatsii-ukrainy . Likewise, military bases may require additional authorization. These require separate operational eligibility gates.

## Changes
- `20261110225500_group2_medium_section5_targeted_restrictions.sql` stores 7 sourced Medium airport game profiles and provides `airlinerra_game.airport_group2_section5_medium_screen_v1`.
- `20261110230000_group2_local_regional_simple_medium_detailed.sql` restores neutral game defaults for Local/Regional airports, superseding the earlier Regional Pampulha rule in *game* while retaining its earlier source history.
- All migrations committed directly on `main`, installed on production Supabase, and checked after installation.
- All **23** Group 2 batches still have game-data completion `game_complete_estimated`.
- No real-world certification; Group 1 still 3,141 airports; World 1 remains planned; zero Group 2 commercial flight activation.

## Engine caution
These are data flags and metadata, **not proof that live scheduling reads or enforces Chapter/clock-specific limits**. Check timetable/flight admission integration separately before claiming these rules actively block bookings.
