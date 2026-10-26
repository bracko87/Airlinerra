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

---

## Batch 02 — civilian/converted airport technical and operational evidence (2026-10-26)

**Marker:** `CH_SPECIALIST_02_2026_10_26`  
**Result:** Six civil/civil-converted airport cases re-evaluated. Three advanced to independently supported paved-runway `VERIFIED` under the research database's access-review field, three retain `UNVERIFIED` pending current official physical/declared-distance reconciliation. All six commercial permissions for any specific Airlinerra airline and all game-admission statuses remain unapproved.

### Source-by-source decision matrix

| Code | Authority/operator evidence | Confirmed physical screen | Remaining operations/permission hold |
|---|---|---|---|
| **LSGS Sion** | Skyguide's published AIP Switzerland **AD 2.12/2.13** chart dated 28 Nov 2024, hosted by Sion qualification site: RWY **07/25, 2,000 x 40 m ASPHALT**; TORA 2,000 m both directions; LDA **1,935 m** RW07 and **1,940 m** RW25. Sion training authority explicitly describes **private, commercial, and scheduled traffic** in principle. | **VERIFIED** source evidence; original registry **2000.1 m ASPH** retained unchanged | Crew IFR qualifications type A/B (with weather/day/night restrictions), high mountain terrain, fire services and operator-specific scheduling/aircraft limitations; latest 2026 AIP/NOTAM and individual carrier access still pending |
| **LSZS Samedan / Engadin** | Engadin Airport AG familiarization briefing v7.10 (2022; PDF visually inspected) RWY **03/21, 1,840 x 40 m asphalt/concrete**; indexed operator briefing May 2026 corroborates. Source-registry **1,799.8 m ASP**, a **40.2 m difference**. Operator mentions private, commercial/business and **unscheduled** IFR/VFR operations. Elevation about **5,600 ft AMSL**, RW03 downhill 0.4%, RW21 uphill 0.4%, no runway/approach lighting. | **VERIFIED** operator physical paved runway; original source preserved | High-altitude performance, runway slope, lighting/daytime, mandatory familiarization, current official AIP declared distances, commercial charter aircraft authorization; **no blanket scheduled airline permission claimed** |
| **LSZC Buochs** | Airport Buochs AG operations page reports RWY **06/24, 2,000 x 40 m hard surface**, while the same operator's about-us page says **1,800 m ASPHALT** and explicitly describes private/business/commercial/cargo airport activity. | **VERIFIED** because operator explicitly independently documents >=1,800 m asphalt, **not** because the generic `hard surface` descriptor proves asphalt. Registry 1999.8 m ASP preserved. | **200 m operator-page discrepancy**, physical versus usable definition, current official AIP/declared distances, PPR and airline-specific permissions. No automatic cargo or scheduled flight approval |
| **LSZM Mollis** | Operator PPR page: >2,250 kg MTOM PPR **24h** in advance and mandatory handling; VFR only, no runway/approach lights, no standing rescue/fire brigade (Cat 4 on request), Jet A1, restricted operating and customs conditions. Site carries dated NOTAM notices; later windows must be checked at flight time. | **UNVERIFIED** at updated current AIP gate; existing registry 1,799.8 m ASP remains technically qualified source data | Post-2025 refurbishment AIP pavement/length confirmation, declared distances, aircraft weight/performance and legal charter/cargo scope |
| **LSGK Saanen / Gstaad** | Gstaad Airport AG requires a PPR for **each departure and arrival**, mountain briefing, limited hours, fire services by prearrangement (Cat 2–5 require 5h notice), Jet A1. Secondary aviation source lists **1,400 x 40 m asphalt** versus registry **1,466.1 m ASP**. Historical source reports shorter usable directional distances, NOT assumed current. | **UNVERIFIED** official-current runway comparison; preserve source runway qualification | Current Skyguide official AIP 08/26 physical runway, TORA/LDA, mountain restrictions and aircraft compatibility before commercial flight approval |
| **LSTS St. Stephan** | FOCA announced civil use conversion and indefinite operating permit on **31 Oct 2025**. Current operator confirms approval and businessjet movements. Its arrival-reporting form explicitly offers commercial taxi flights, commercial sightseeing flights, commercial work flights, passenger counts and cargo weight. Other references conflict between **1,740 m** (registry approx 1,739.8m) and **2,050 m** asphalt descriptions. | **UNVERIFIED** independent current official AIP physical reconciliation; registry qualifying physical runway protected | Determine primary-source length, TORA/LDA, operating regulation and permitted aircraft/commercial transport types; a form with commercial flight categories is **not a carrier operating license** |

### Sources used (verify publication date and official authority)

- Sion official Skyguide AIP Switzerland AD2.12/13 (the available PDF chart is dated Nov **2024**, and contains other pages amended in 2025): https://www.sion-qualification.ch/wp-content/uploads/2017/02/lsgs-AD2-1-2.pdf — physical runway page 6 (zero-index PDF page 5).
- Sion airport pilot information and runway distances, repeatedly published as **NOT FOR OPERATIONAL USE**: https://www.sionaeroport.ch/en/pilot-info/
- Sion qualification operator briefing, types of permitted traffic, IFR types A/B and RFF: https://www.sion-qualification.ch/airport-briefing/
- Engadin operator v7.10 PDF inspected (2022 original): https://www.engadin-airport.ch/wp-content/uploads/2023/08/SMV-PILOT-BRIEFING-V7.10_.pdf — physical runway page 8 (zero-index PDF page 7), traffic page 6 (zero-index 5).
- Engadin operator newer 2026 briefing indexed but oversized for direct PDF rendering: https://www.engadin-airport.ch/wp-content/uploads/2026/05/Briefing-Familiarization-LSZS.pdf (listing consistent 1840 x40 asphalt/concrete; do not treat the web-index snippet as a complete latest AIP audit).
- Buochs operator primary sources: https://airportbuochs.ch/en/operation/ and https://airportbuochs.ch/en/ueber-uns/ .
- Mollis airport PPR, technical and rescue requirements: https://www.mollisairport.ch/ppr-jet-helicopter ; https://www.mollisairport.ch/ .
- Saanen official operator pilot rules: https://www.gstaad-airport.ch/en/pilots/ ; secondary 1400m length: https://www.vacc.ch/en/airports_and_charts/LSGK .
- St. Stephan FOCA permit announcement: https://www.bazl.admin.ch/de/newnsb/I-EXq2Jy3KdSyIOqr7sNN ; operator confirmation: https://www.airportststephan.ch/ ; commercial flight type reporting: https://www.airportststephan.ch/anmeldung-einflug-nach-lsts ; contradictory secondary source: https://www.learn-atc.com/tools/aerodrome/LSTS .

### Persistent database trace / safeguards

- Added **9** research evidence records **2117–2125** to `airlinerra.airport_evidence`, batch `CH_SPECIALIST_02_2026_10_26` covering all six airport keys.
- Updated **six** `airlinerra.airport_access_reviews`: `paved_runway_status='VERIFIED'` for **LSGS, LSZS, LSZC** and retained `UNVERIFIED` for **LSZM, LSGK, LSTS**. Civil access remains verified for all six; `commercial_permission_status='UNVERIFIED'` and `game_admission_status='NOT_APPROVED'` for all.
- Inserted six audit events **9–14**, using the same batch marker in `airlinerra.airport_review_events`.
- No change to `airport_registry`, `airport_game_world1_catalog`, `airport_world_activation`, source codes, German specialist decisions or final six-category assignments. The original **3,140 World 1 records** are preserved.

**Next work:** After this batch, evaluate Swiss military/shared aviation cases and recover current official AIP declared distances for the three runway-conflict cases. Actual aircraft eligibility must be checked on a per-aircraft, per-direction, weather/terrain/permission basis; the runway-only collection threshold is never an aircraft-compatibility permission.
