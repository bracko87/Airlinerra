# Airlinerra — Swiss specialist airport expansion / batch 01
**Research date:** 2026-10-26  
**Central research project:** Airlinerra Supabase, private `airlinerra` schema  
**Batch marker:** `CH_SPECIALIST_01_2026_10_26`  
**Scope:** The 12 Swiss source-registry runway-qualified airport keys not in the 3,140-record World 1 startup catalog.

## Scope and decision rules

- `airport_registry`: 17 Swiss airports, of which 5 already in `airport_game_world1_catalog`; these 12 are additional candidates.
- All 12 have **source-registry** `RUNWAY_QUALIFIED` status for >=1,200 m asphalt/concrete. This batch independently researches identities, regulator classification and civilian-access status; **it does not certify the latest operational runway length, surface, aircraft compatibility, current NOTAMs or legal carrier permissions for all 12**.
- Keep distinct: **runway-only collection**, **public/civilian or military access**, **commercial operator suitability**, **owner game admission**, and **final six Airlinerra categories** (Local, Regional, Medium, Large, Major Hub, Mega Hub).
- No new `airport_game_world1_catalog` members, `airport_world_activation` changes, final category choices or releases.

## Reviewed airports (all currently NOT APPROVED for game admission)

| ICAO | Airport | Registry qualifying runway (m, surface) | Authority/operator result | Current research gate |
|---|---|---|---|---|
| LSMA | Alpnach Air Base | 1497.8 ASP | FOCA: military field, occasional civil co-use only, no civil operating regulation/SIL sheet. | Military and airline-specific permission hold |
| LSPM | Ambrì | 1237.5 concrete | FOCA: former military field with civil conversion under appeal, not finalized per directory. | Conversion/appeal hold |
| LSZC | Buochs | 1999.8 ASP | FOCA confirms former military-to-civil conversion in 2021. Operator lists 2000 x 40m hard runway, business and cargo services, mandatory PPR. Separate about-us wording cites 1800m asphalt, a physical-vs-usable/source discrepancy to resolve. | Civil aviation research advance; current AIP runway details and carrier-specific permissions outstanding |
| LSMD | Dübendorf Air Base | 2354.9 ASP | FOCA: civilian occasional co-use remains within military setting; proposed larger conversion not yet implemented. Rega heliport civil rules are not fixed-wing airline approval. | Restricted military co-use |
| LSME | Emmen Air Base | 2501.8 ASP | FOCA: only occasional civilian use, without civil operating regulation. | Restricted military co-use |
| LSZS | Engadin/Samedan | 1799.8 ASP | FOCA: regional civil airport; operator offers taxi flights and highlights high-altitude operational limitations. | Civil airport advance; current AIP/aircraft altitude-performance review |
| LSMM | Meiringen Air Base | 2002.8 ASP | FOCA 2026 airspace records identify active military fighter operations. Current civilian permissions not independently established in this batch; do **not** infer a blanket legal ban. | Military access and current AIP recheck |
| LSZM | Mollis | 1799.8 ASP | FOCA: converted civilian airfield; 2025 runway refurbishment. Operator: VFR, PPR and handling mandatory for aircraft over 2.25 tonnes, no runway/approach lights. | Civil advance; post-refurbishment AIP physical screen, PPR and aircraft constraints |
| LSMP | Payerne Air Base | 2857.8 ASP | FOCA: civil co-use with an operating regulation since 2013 and updated permitted times/contingents in Dec 2025. | Military/shared-operation permit and slot restrictions |
| LSGK | Saanen | 1466.1 ASP | FOCA: civilian airfield. Published older directional distances may differ from physical source-registry length; current official AIP values not confirmed here. | Civil advance; runway distance/current AIP recheck |
| LSTS | St. Stephan | 1739.8 ASP | **FOCA 2025-10-31 announcement** granted civil operating permit and operating regulations, whereas directory still uses obsolete 'not converted' wording. Record both; newer decision is more specific. | Civil conversion lead; AIP/current operative conditions/aircraft checks |
| LSGS | Sion | 2000.1 ASPH | FOCA: regional airport; operator states IFR/VFR and full-runway TORA 2000m both directions, LDA 1935m RW07 / 1940m RW25. | Civil airport advance; final AIP pavement/aircraft and commercial operating scope |

**IMPORTANT:** The registry values in the third column were already present before this batch. They are *not newly independently verified official AIP pavement figures*. Some FOCA/operator sources verify operating status or dimensions but not explicit bitumen chemistry; do not silently convert generic `hard surface` into authority-verified asphalt.

## Operator/regulator evidence — HTML sources

- FOCA Alpnach: https://www.bazl.admin.ch/de/flugfeld-alpnach
- FOCA Ambrì, open conversion appeal: https://www.bazl.admin.ch/de/flugfeld-ambri
- FOCA Buochs, completed civilian conversion: https://www.bazl.admin.ch/de/flugfeld-buochs
- Buochs operator physical runway and PPR: https://airportbuochs.ch/en/operation/ and https://airportbuochs.ch/en/registration-lszc/
- Buochs operator about us (shorter 1800m description): https://airportbuochs.ch/en/ueber-uns/
- FOCA Dübendorf co-use: https://www.bazl.admin.ch/de/zivil-mitbenuetzter-militaerflugplatz-duebendorf
- FOCA Emmen co-use: https://www.bazl.admin.ch/de/zivil-mitbenuetzter-militaerflugplatz-emmen
- FOCA Samedan regional airport: https://www.bazl.admin.ch/de/regionalflughafen-samedan
- Engadin airport operator, high-altitude safety and commercial taxi examples: https://www.engadin-airport.ch/en/safety-first/ and https://www.engadin-airport.ch/en/visitor/
- FOCA military airspace/Meiringen exercises: https://www.bazl.admin.ch/de/flugsicherung-und-luftraum
- FOCA Mollis conversion, rehabilitation permit: https://www.bazl.admin.ch/de/flugfeld-mollis
- Mollis operator >2.25 tonne PPR, handling, VFR/lighting limits: https://www.mollisairport.ch/ppr-jet-helicopter
- FOCA Payerne civilian shared-use regulation: https://www.bazl.admin.ch/de/zivil-mitbenuetzter-militaerflugplatz-payerne
- FOCA Saanen civilian field: https://www.bazl.admin.ch/de/flugfeld-saanen
- FOCA St. Stephan 2025 civilian operating permit (supersedes older directory wording for the permit status): https://www.bazl.admin.ch/de/newnsb/I-EXq2Jy3KdSyIOqr7sNN and older directory https://www.bazl.admin.ch/de/flugfeld-st-stephan
- FOCA Sion regional airport: https://www.bazl.admin.ch/de/regionalflughafen-sion
- Sion airport direct directional runway/takeoff/landing data: https://www.sionaeroport.ch/en/pilot-info/

Switzerland's regulator explicitly states that full operating regulations are not systematically published online and may require an information request. Commercial operations therefore **must not** be deemed permitted solely because an airfield is civil or a regional airport. https://www.bazl.admin.ch/de/plangenehmigungen-und-betriebsreglemente

## Persisted database result
- 12 new `airlinerra.airport_evidence` records IDs **2104-2115**, one per airport, all tagged `CH_SPECIALIST_01_2026_10_26`. Each contains source link, runway-registry values, civilian-access review outcome and explicit game-release prohibition.
- 12 `airlinerra.airport_access_reviews` cases populated/updated from FOCA/operator evidence: all identity statuses `VERIFIED`; **all commercial_permission_status `UNVERIFIED`, all game_admission_status `NOT_APPROVED`**.
- `paved_runway_status` remains `UNVERIFIED` for the 12 until a distinct independent current AIP physical pavement gate is completed. This does not retract their existing source-registry technical qualification.
- No mutation to source airport registry, any finalized category or the original World 1 active records.

## High-priority next verification
1. Sion and Samedan: current AIP runway surface, runway-end declared distances, performance-restricting procedures, and airline permissions.
2. Buochs: 2000m runway physical length vs operator about-us 1800m description, exact asphalt/engineering source, PPR/handling/commercial cargo authorizations.
3. Mollis and Saanen: independent fresh surface/physical and direction-specific usable distances; Mollis mandatory >2.25t handling/briefing, no approach/runway lighting.
4. St. Stephan: reconcile FOCA civil permit 2025 with older directory wording and live 2026 operating conditions.
5. Alpnach, Dübendorf, Emmen, Meiringen, Payerne: isolate military access/operating regulations and avoid blanket exclusions purely based on military names.
6. Ambrì: FOCA conversion appeal outcome and resulting civil-operation authority.
7. All 12: latest NOTAMs and formal operator certification/permission before actual modeled commercial operations; final six-level classification separate and owner-controlled.

**Batch decision:** Initial Swiss regulator/operator identity and access audit **recorded and complete**; flight release, independent comprehensive physical runway adjudication and game admission remain pending.
