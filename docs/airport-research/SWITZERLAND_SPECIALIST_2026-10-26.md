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

---

## Batch 03 — Swiss military/civilian-access adjudication (2026-10-26)

**Central research batch marker:** `CH_SPECIALIST_03_2026_10_26`  
**Scope:** Six remaining Switzerland expansion cases with military, mixed-use or appealed civilian-conversion restrictions. This batch validates **access/legal operating status** using the Swiss federal regulator (FOCA/BAZL) and armed forces (VBS/Swiss Air Force), without representing the previously imported paved-runway fields as independently audited current AIP physical dimensions. Source-screened paved runway eligibility remains intact; neither a military name nor restricted access automatically invalidates a ≥1,200 m qualifying physical runway.

### Verified source and research disposition

| ICAO | Airport | Authority evidence / date | Research decision | Game admission |
|---|---|---|---|---|
| **LSMA** | Alpnach Air Base | FOCA current airport directory: occasionally civil co-used military aerodrome under Art. 30 VIL; **no civilian operating regulation or SIL object sheet**. | `ALPNACH_ART30_OCCASIONAL_CIVIL_NO_OPERATING_REGULATION`: military/operation-specific permission required, regular airline use unestablished. | **NOT_APPROVED** |
| **LSMD** | Dübendorf Air Base | FOCA: 2014 civil-conversion ambition interrupted in Oct 2020, new planning in Zurich, existing use remains occasional civil sharing under Art. 30 VIL. Rega helicopter-base 2002 civil regulation does **not** authorize general commercial fixed-wing use. Swiss Air Force continues active military operations. | `DUEBENDORF_ART30_CIVIL_OCCASIONAL_CONVERSION_NOT_COMPLETED`: do not treat planned conversion as already complete. | **NOT_APPROVED** |
| **LSME** | Emmen Air Base | FOCA: occasional civil shared-use military airport **without separate civilian operating regulation/SIL**. Swiss Air Force official page published **2026-01-01** establishes a separate VBS co-use agreement allowing **up to 1,000 civilian flight movements per year** for Lucerne economic development, administered by **RUAG MRO Holding**. 2025 military movements: **18,552**. | `EMMEN_ART30_RUAG_1000_CIVIL_MOVEMENTS_PER_YEAR_GATE`: annual count is neither hourly airline slots nor a blanket right for player airlines. Preserve both FOCA Art. 30 status and narrow co-use quota. | **NOT_APPROVED** |
| **LSMM** | Meiringen Air Base | Swiss Air Force 2026 flight programme/current military operating page: active F/A-18 station, regular military weekday operations, exceptional night/response activities. | `MEIRINGEN_ACTIVE_F18_MILITARY_AIRFIELD_CIVIL_OPERATOR_ACCESS_NOT_ESTABLISHED`: no general civilian commercial entitlement established. **Do not assert a legal total ban** solely from absence of published permissions. | **NOT_APPROVED** |
| **LSMP** | Payerne Air Base | FOCA: regulated military/civilian shared airfield with civilian operating regulation since **2013-09-27**. SIL amendment approved **2025-10-29**; FOCA operating-rules amendment **2025-12-03**, extending hours/movement contingents. Aero-Club Switzerland article published **2026-02-02** confirms appeal period expired and amended operating framework entered into force. | `PAYERNE_EFFECTIVE_2025_AMENDED_CIVIL_OPERATIONS_QUOTAS_AND_MILITARY_GATE`: **advance within restricted regulated civilian research**, not regular unqualified airline admission. Individual hours, movement quota allocation, military coordination and carrier eligibility still unresolved. | **NOT_APPROVED** |
| **LSPM** | Ambrì | FOCA current airport directory explicitly states **former military airport not yet converted; complaint/appeal pending** against civilian conversion decision of **2023-09-05** before Swiss Federal Administrative Court. | `AMBRI_2023_CIVIL_CONVERSION_COURT_APPEAL_UNRESOLVED`: unresolved legal conversion and civilian permissions; physical runway threshold is a separate issue. | **NOT_APPROVED** |

### Legal distinction: civilian co-use ≠ airline entitlement

FOCA distinguishes private licensed airfields and regional airports from military facilities sharing some civil operations. In the contemporary Swiss aerodrome law (VIL Articles 30–31), *occasional* civil operations at military fields require military-airfield command consent; *frequent* civil use has additional operating-regulation requirements. A previously converted civil airfield has different authorization from a proposed conversion facing an unresolved appeal. Do not set `commercial_permission_status='VERIFIED'` from FOCA co-use labels or annual movement caps.

For Emmen specifically, annual 1,000 civilian **movements** administered via RUAG are **not** one thousand Airlinerra scheduled flights and do not translate to slots/hour or seats/flight without a separately approved simulation model and specific access rights.

Payerne's expanded civilian hours are real and current, but the 2025 approval does not supersede individual airport usage restrictions, aircraft performance or military coordination.

### Authority sources independently checked

- Swiss FOCA/BAZL general aerodrome definitions and rules: https://www.bazl.admin.ch/de/flugplaetze-generell
- FOCA Alpnach (LSMA): https://www.bazl.admin.ch/de/flugfeld-alpnach
- FOCA Dübendorf (LSMD): https://www.bazl.admin.ch/de/zivil-mitbenuetzter-militaerflugplatz-duebendorf
- Swiss Air Force Dübendorf operations: https://www.vtg.admin.ch/de/militarflugplatz-dubendorf
- FOCA Emmen (LSME): https://www.bazl.admin.ch/de/zivil-mitbenuetzter-militaerflugplatz-emmen
- Swiss Air Force Emmen **2026**, annual civil co-use quota administered by RUAG: https://www.vtg.admin.ch/de/militarflugplatz-emmen
- Swiss Air Force Meiringen (LSMM), 2026 flight operations: https://www.vtg.admin.ch/de/militaerflugplatz-meiringen
- FOCA Payerne (LSMP) and dated SIL/regulation amendment: https://www.bazl.admin.ch/de/zivil-mitbenuetzter-militaerflugplatz-payerne
- Swiss federal October 29, 2025 plan for Payerne and Samedan: https://www.bazl.admin.ch/de/newnsb/ShrgOidOtnCTr8kMTDaJU
- February 2, 2026 notice on Payerne amended regulation entering into force: https://aeroclub.ch/en/dank-neuem-sil-kann-der-payerne-airport-laengere-betriebszeiten-anbieten/
- FOCA Ambrì (LSPM), 2023 conversion court appeal: https://www.bazl.admin.ch/de/flugfeld-ambri
- FOCA request procedure for current unpublished operating regulations: https://www.bazl.admin.ch/de/plangenehmigungen-und-betriebsreglemente (access request contact **lesa@bazl.admin.ch**)
- Skyguide original NOTAM / flight information: https://www.skyguide.ch/de/dienstleistungen/luftfahrtinformationsdienste

### Persisted data and safeguards

The private Airlinerra Supabase `airlinerra` schema now holds:

- Eight new `airport_evidence` records, **IDs 2126–2133**, source-scoped to `CH_SPECIALIST_03_2026_10_26`, covering all six airport keys. Two each for Emmen (FOCA classification plus Swiss Air Force quota) and Payerne (FOCA amended rule plus in-force confirmation); one for each remaining field.
- Six updated `airport_access_reviews` preserving airport identity and registry source information, with newly precise `review_status`, civilian-access restrictions and research explanations.
- Six immutable `airport_review_events` **IDs 15–20** for reproducible access-case adjudication, linked to the same batch marker.
- `paved_runway_status='UNVERIFIED'` for these six **current independent physical AIP gates**; their older `airport_registry.runway_screen_status='RUNWAY_QUALIFIED'` source screen remains intact.
- **All six** `commercial_permission_status='UNVERIFIED'`, `game_admission_status='NOT_APPROVED'`; no assertions of commercial or final category approvals.

**Across Swiss batches 01–03:** 12 airport candidates reviewed, 29 source-specific evidence records created, 12 access reviews maintained, and 0 game approvals. Existing World 1 3,140 airport records, the six provisional categories and German specialist hold decisions are not changed.

### Remaining Swiss work, priority

1. **Runway physical independent source gate:** current Swiss eAIP AD 2 / AIP AD 1.3 runway lengths, surfaces, declared TORA/LDA and open/closed status for Alpnach, Dübendorf, Emmen, Meiringen, Payerne, Ambrì, and the three remaining civil discrepancy cases Mollis, Saanen, St. Stephan.
2. **Payerne regulatory gate:** read effective December 2025 regulation, detailed applicable hour bands, quotas and military coordination requirements; verify whether any category of commercial passenger/cargo operators can obtain access.
3. **Emmen RUAG agreement gate:** identify eligible civilian operators under the maximum 1,000 movements per year without presuming a general charter/scheduled airline entitlement.
4. **Ambrì conversion court status:** seek updated FOCA/Federal Administrative Court decision or direct official confirmation; retain legal hold while appeal remains listed.
5. **Other military fields:** request individual airfield command/operator permission scope only if eventual game expansion would justify civilian access research. No generic military exclusion from the runway-only catalog.
6. Preserve the owner-controlled final classification order exactly: **Local, Regional, Medium, Large, Major Hub, Mega Hub**, with no inferred final level from runway length.

**Batch-03 conclusion:** Independent civilian/military operating-status research finished and documented for all six; current physical AIP verification and commercial/game-eligibility gates still unresolved. Do not activate.

---

## Batch 04 — Official Payerne limits, Mollis pavement and outstanding Swiss runway discrepancies (2026-10-26)

**Research batch:** `CH_SPECIALIST_04_2026_10_26`  
**Scope:** Payerne (LSMP), Mollis (LSZM), Saanen (LSGK), St. Stephan (LSTS), Ambrì (LSPM). Updated 5 airport access-review research statuses without granting any carrier access or changing World 1.

### Payerne LSMP — exact December 2025 FOCA operating amendments

I checked the **December 3, 2025 FOCA decision**, *Aérodrome militaire avec utilisation civile de Payerne: Modification du règlement d'exploitation - Extension des heures d'exploitation et des contingents*. The decision section **C** approves the amendments, with an important clarification that the **600 annual weekday extended-hour movements** apply **across both morning and evening combined**, not just to evening.

| Day | Base/extended civilian operating time | Specific limits in FOCA approval |
|---|---|---|
| Monday–Friday | **07:00–19:00 base**; **06:00–07:00** and **19:00–22:00 extended** | **600 movements per year for those two extended intervals combined**. Early 06:00–07:00 period must be coordinated with military airbase command and Skyguide. |
| Saturday | **08:00–22:00** | **500 movements per year**. No departures **12:00–13:00** except technical, meteorological or traffic-related rescheduling. Air-traffic-control rest periods must be coordinated through PPR. |
| Sundays/public holidays | **10:00–12:00**, **13:30–20:00** | **200 movements per year** across the specified Sunday/holiday windows. Air-traffic-control breaks may require PPR. |

The decision mentions an **8,400 movements/year potential used in a noise analysis**. Do **not** turn this into a player airline slot allocation or misrepresent it as automatically bookable flights. The approved 600/500/200 quotas are for relevant **civilian aerodrome movements** under the approved operational rules, not Airlinerra allocations or independently certified takeoff/landing aircraft capacities. Additional constraints in the final decision include agreed military/Skyguide air-traffic service provisions, PPR scheduling, and ongoing publication of effective aeronautical information. The operator/airline-specific commercial gate remains `UNVERIFIED`; `game_admission_status='NOT_APPROVED'`.

**Official FOCA decision:** https://www.bazl.admin.ch/dam/de/sd-web/tA4QFgjK1NZ9/2025-12-03-payerne-modification-du-reglement-exploitation-extension-heures-exploitation-et-contingents.pdf (especially source PDF pp. 2, 13, 32–33).  
**Regulator's aviation facility record:** https://www.bazl.admin.ch/de/zivil-mitbenuetzter-militaerflugplatz-payerne .  
**Effective legal follow-up (2026-02-02):** https://aeroclub.ch/en/dank-neuem-sil-kann-der-payerne-airport-laengere-betriebszeiten-anbieten/ .

### Mollis LSZM — new official asphalt evidence without inventing AIP runway length

The **FOCA August 11, 2025 approval** authorizes rehabilitation of the existing **asphalt runway**. The project documents works between **construction chainages km 0.057 and km 1.830** — a **1,773 m resurfacing segment**, which is **not** a published full runway physical length, TORA, TODA, ASDA or LDA. The authority says the pre-existing infrastructure dimensions are not enlarged. The approval planned a closure **September 4–16, 2025** for construction, which must **not** be carried forward as a 2026 current-closure hold without a current NOTAM.

That FOCA approval is independently authoritative for the **asphalt pavement material** and the project scope; completed work, official 2026 post-work physical dimensions and latest declared-direction distances have **not** all been confirmed. Hence the combined database access-review `paved_runway_status` remains `UNVERIFIED` at the **full current physical length / operation gate**, even though registry `RUNWAY_QUALIFIED` and asphalt material corroboration are retained.

Operator's current pilot rules preserve **VFR**, aircraft above **2,250 kg** requiring PPR/handling, higher turning-speed mandatory briefing, no runway/approach lights, Schengen-specific notice, Non-Schengen operations currently unavailable, and no permanent RFF (Cat 4 may be arranged). A Mollis operator-published **November 3/5, 2026** temporary-restricted-area NOTAM describes **future** activity relative to this audit; it is not proof of current October closure.

- Official asphalt reconstruction approval: https://www.bazl.admin.ch/dam/de/sd-web/In1Bxxy2qNzw/2025-08-11-mollis-plangenehmigung-pistensanierung.pdf (source PDF p. 2).
- Operator PPR and aircraft restrictions: https://www.mollisairport.ch/ppr-jet-helicopter
- Operator homepage/current NOTAM bulletins: https://www.mollisairport.ch/

### Saanen LSGK / St. Stephan LSTS — alternative measured lengths remain unresolved

| Airport | Existing immutable registry source | Secondary OpenAIP-derived entry | Difference and decision |
|---|---:|---:|---|
| **LSGK Saanen** | **1,466.1 m ASP** | **1,400 m asphalt**, direction 08/26 | **66.1 m difference**; both qualify for the >=1,200 m physical collection. Original `airport_registry` unchanged. Primary/current Skyguide AIP physical length and per-end TORA/LDA still outstanding. |
| **LSTS St. Stephan** | **1,739.8 m ASP** | **2,050 m asphalt**, direction 14/32 | **310.2 m difference**; both qualify physically for collection. Original registry unchanged. Current official AIP length and declared distances pending; 2025 FOCA civilian conversion approval remains recorded independently. |

Secondary sources are evidence of **conflict**, not authority to overwrite the original records or to release flight operations. Do not treat a historical 1,080–1,090 m usable-distance claim at Saanen as current without primary aeronautical publication.

- Saanen OpenAIP-derived secondary airport page: https://airfield.directory/airfield/LSGK
- Saanen operator mandatory pilot/PPR conditions: https://www.gstaad-airport.ch/en/pilots/
- St. Stephan OpenAIP-derived secondary airport page: https://airfield.directory/airfield/LSTS
- St. Stephan current operator commercial flight-type registration: https://www.airportststephan.ch/anmeldung-einflug-nach-lsts
- FOCA St. Stephan civil-conversion announcement 2025: https://www.bazl.admin.ch/de/newnsb/I-EXq2Jy3KdSyIOqr7sNN

### Ambrì LSPM — conversion appeal checked again

FOCA's current Ambrì airport directory still explicitly states that the **September 5, 2023 civilian-conversion decision** is challenged before the Swiss Federal Administrative Court. There was no independent definitive later judgment found in this review. Preserve `CONVERSION_UNDER_APPEAL`, `commercial_permission_status='UNVERIFIED'`, and `game_admission_status='NOT_APPROVED'`. Source-runway qualification remains independent of the civil operating title.

Primary FOCA status: https://www.bazl.admin.ch/de/flugfeld-ambri

### Database write record and safeguards

- **7 evidence records**, `airlinerra.airport_evidence` IDs **2134–2140**, source batch `CH_SPECIALIST_04_2026_10_26`, added for five airport keys.
- **5 access-review** `review_status` and evidence updates, preserving all unverified commercial permission states and `NOT_APPROVED` game admissions. Full current independent runway checks are **still unresolved**, so neither raw `airport_registry` measurements nor independent physical pass statuses were falsely overwritten.
- **5 airport audit events**, IDs **21–25**, tagged `CH_SPECIALIST_04_2026_10_26`.
- **All Switzerland specialist batches 01–04:** **36 evidence entries covering 12 Swiss airport candidates**. This is a count of cited research observations, **not 36 newly eligible airports**.
- No changes to the original World 1 catalog (3,140 records), world activation, six-category assignments, historic German cases or Austrian specialist admissions.

**Research conclusion:** Payerne's concrete extended-hour quotas can now be encoded as *restrictions* in future dispatch rules, never as player-granted slots. Mollis's asphalt authority evidence is corroborated, while official post-work runway distance and aircraft suitability await confirmation. Saanen and St. Stephan runway conflicts, as well as Ambrì's court appeal, remain documented holds. No new airports activated.
