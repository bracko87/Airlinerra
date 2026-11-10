# Group 2 — Section 1 Identity & Geography | Official-source research pass 2

**Audit date:** 2026-11-10  
**Scope:** 1,118 owner-pre-approved Group 2 airports, Section 1 ONLY.  
**Source priority:** original Airlinerra registry → official airport operator / local government / national AIP → AirlineSim only as limited fallback/code comparison.

This is **source research**, not automatic authority verification. These new records are append-only/private. The original Group 1 roster (3,141), Group 2 game profiles, airport tiers, runways, charges, flights and financial ledgers are unchanged.

## Verified database research progress

| Metric | Previous | Now | Still requires review |
|---|---:|---:|---|
| Original registry municipalities missing | 41 | 41 | 41 source fields remain NULL |
| Missing-locality cases with **a primary served-city candidate** | 3 | **24** | Proposed **served city** must not silently overwrite exact municipality |
| Missing-locality cases without primary served-city candidate | 38 | **17** | Find official operator/authority evidence or establish no meaningful municipal locality |
| Official published *elevation candidates* | 0 | **7** | Review exact edition/datum then update game estimates separately |
| AirlineSim code-only comparisons | 6 | **6** | None used as authority evidence or municipal name |
| Material Australian timezone rule conflicts with nearest-Airport game estimates | Untracked | **5** | Review actual state/territory time rules, then safely correct before scheduling |
| Missing source GPS fields | 2 | 2 | Argentine Chamical and Kyiv Zhuliany require source-code checks |
| Source-estimated game timezones | 1,118 | 1,118 | Values retain their estimate flags; **five have identified conflicts** |
| Independently approved canonical changes | 0 | **0** | Never fake an independent aviation review |

**Caveat:** A website confirming that the airport **serves** Ballarat or Shepparton is not necessarily evidence of the exact physical administrative subdivision (Mitchell Park or Kialla). Keep `source_municipality` NULL until the required semantics and source agree. Military/mining/island airports may have no meaningful served city at all.

## 21 additional primary-source served-city candidates (installed)

| Candidate served city | Airport source key | Official publisher/source |
|---|---|---|
| Condobolin | `OURAIRPORTS:26949` | [NSW planning department — airports safeguarding](https://www.planningportal.nsw.gov.au/development-and-assessment/policies-and-guidelines/key-guidance/national-airports-safeguarding-framework) |
| Clermont | `OURAIRPORTS:26956` | [Isaac Regional Council](https://www.isaac.qld.gov.au/Facilities/Aerodrome) |
| Corryong | `OURAIRPORTS:26964` | [Towong Shire Council](https://www.towong.vic.gov.au/2-residents/recreation-and-facilities/airports) |
| Cootamundra | `OURAIRPORTS:26965` | [Cootamundra–Gundagai Council](https://www.cgrc.nsw.gov.au/your-services/council-facilities/cootamundra-aerodrome/) |
| Gunnedah | `OURAIRPORTS:26989` | [Gunnedah Council community/airport notice](https://www.gunnedah.nsw.gov.au/Community) |
| Goondiwindi | `OURAIRPORTS:26990` | [Goondiwindi Regional Council](https://www.grc.qld.gov.au/News-and-Community/Community-Facilities/Aerodromes) |
| Goulburn | `OURAIRPORTS:26995` | [Goulburn Airport operator](https://www.goulburnairport.com.au/) |
| Hamilton | `OURAIRPORTS:27007` | [Southern Grampians Shire](https://www.sthgrampians.vic.gov.au/Hamilton-Airport) |
| Horsham | `OURAIRPORTS:27011` | [Horsham Rural City Council, Aug 2026](https://www.hrcc.vic.gov.au/Our-Council/News-and-Media/Latest-News/Council-seeks-funding-for-critical-Aerodrome-upgrade) |
| Innisfail (site Mundoo) | `OURAIRPORTS:27013` | [Cassowary Coast Council](https://www.cassowarycoast.qld.gov.au/Living-Here/Places-and-Spaces/Aerodromes) |
| Kempsey | `OURAIRPORTS:27025` | [Kempsey Shire Council](https://www.kempsey.nsw.gov.au/Business/Business-facilities/Kempsey-Airport) |
| Kingaroy | `OURAIRPORTS:27027` | [South Burnett Regional Council](https://www.southburnett.qld.gov.au/Places-and-spaces/Facilities/Aerodromes) |
| Nyngan | `OURAIRPORTS:27091` | [Bogan Shire Council](https://bogan.nsw.gov.au/visit/getting-to-nyngan) |
| Renmark | `OURAIRPORTS:27125` | [Renmark Paringa Council, June 2026](https://www.renmarkparinga.sa.gov.au/noticeboard/latest-news/2026/renmark-paringa-council-meeting-update-june) |
| Scone | `OURAIRPORTS:27134` | [Upper Hunter Shire Council](https://www.upperhunter.nsw.gov.au/News/Upper-Hunter-Shire-Council-Meeting-%E2%80%93-Monday-25-November-2024) |
| Shepparton (site Kialla) | `OURAIRPORTS:27138` | [Greater Shepparton City Council](https://greatershepparton.com.au/region/aerodrome) |
| Stawell | `OURAIRPORTS:27150` | [Northern Grampians Council](https://www.ngshire.vic.gov.au/Council/Governance-and-transparency/Council-publications/Stawell-Aerodrome-Master-Plan) |
| Miles | `OURAIRPORTS:27786` | [Western Downs Council](https://www.wdrc.qld.gov.au/Services-Payments/Aerodromes-Aircraft-Landing-Areas) |
| Ludhiana (site Sahnewal) | `OURAIRPORTS:26568` | [Airports Authority of India](https://www.aai.aero/en/airports/ludhiana) |
| Phrae (site Nachack) | `OURAIRPORTS:26651` | [Thailand CAAT eAIP VTCP, Oct 2025](https://aip.caat.or.th/2025-10-30-AIRAC/html/eAIP/VT-AD-2.VTCP-en-GB.html) |
| Pattani (site Bothong/Nongchik) | `OURAIRPORTS:26671` | [Thailand CAAT eAIP VTSK, Aug 2026](https://aip.caat.or.th/2026-08-06-AIRAC/html/eAIP/VT-AD-2.VTSK-en-GB.html) |

These join **three earlier official served-city candidates** (Ballarat, Onslow, Dalby), yielding 24. The database retains the source URL and a field-specific warning on each. **None is yet an independent verified municipality.**

## Seven airport elevation corrections supported by published sources

| Airport | Current approximate GAME elevation (ft) | Published source candidate (ft) | Primary source |
|---|---:|---:|---|
| Corryong | 539 | 963 | [Towong Shire Council](https://www.towong.vic.gov.au/2-residents/recreation-and-facilities/airports) |
| Goondiwindi | 701 | 714 | [Goondiwindi Regional Council](https://www.grc.qld.gov.au/News-and-Community/Community-Facilities/Aerodromes) |
| Goulburn | 1,886 | 2,141 | [Goulburn Airport operator](https://www.goulburnairport.com.au/) |
| Shepparton | 705 | 374 | [Greater Shepparton City Council](https://greatershepparton.com.au/region/aerodrome) |
| Ludhiana | 775 | 834 | [Airports Authority of India AIP VILD](https://aim-india.aai.aero/eaip-v2-06-2024/eAIP/IN-AD%202.1VILD-en-GB.html) |
| Phrae | 811 | 540 | [Thailand CAAT AIP VTCP 2025](https://aip.caat.or.th/2025-10-30-AIRAC/html/eAIP/VT-AD-2.VTCP-en-GB.html) |
| Pattani | 16 | 8 | [Thailand CAAT AIP VTSK 2026](https://aip.caat.or.th/2026-08-06-AIRAC/html/eAIP/VT-AD-2.VTSK-en-GB.html) |

Current game elevations are **nearest-airport estimates**, not published airport altitudes. Candidate values are retained separately for a review-controlled correction. A source's runway elevation is not proof of safe operational availability.

## Five actual Australian timezone conflicts requiring game-source correction

State/territory timezone rules are documented by [NSW Department of Communities & Justice](https://dcj.nsw.gov.au/about-us/daylight-saving/definitions-of-time-and-how-time-is-regulated.html) and the [Reserve Bank of Australia, daylight saving 2026](https://www.rba.gov.au/schedules-events/daylight-saving.html). This is governmental civil time-rule evidence, not an airport operating certificate.

| Airport | Region | Current GAME timezone | Proposed IANA zone | November 10, 2026 local offset error |
|---|---|---|---|---|
| Goondiwindi | QLD | Australia/Sydney | **Australia/Brisbane** | **+60 minutes** |
| Horsham | VIC | Australia/Adelaide | **Australia/Melbourne** | **−30 minutes** |
| Moomba | SA | Australia/Brisbane | **Australia/Adelaide** | **−30 minutes** |
| Port Keats | NT | Australia/Perth | **Australia/Darwin** | **−90 minutes** |
| Renmark | SA | Australia/Melbourne | **Australia/Adelaide** | **+30 minutes** |

The private `airport_group2_section1_timezone_discrepancy_v1` calculates actual June and November offsets using PostgreSQL timezone definitions so differences are testable, not invented. NSW/VIC alias variations which have equivalent offsets are not incorrectly counted as material errors. Exception regions such as Broken Hill and Lord Howe must not be generically overridden merely by state.

**These five are presently SOURCE CORRECTION CANDIDATES, not live code changes.** Because game date/time calculations must remain deterministic, the old approximate profile must be corrected via a separately reviewed source acceptance and tested against schedule conversion before any airport is admitted for flights.

## The 17 remaining missing-locality cases (source research still open)

| Country | Airport(s) | Required next action |
|---|---|---|
| UAE | Al Dhafra Air Base (OMAM) | Confirm legal site locality, military restrictions |
| Australia | Argyle (YARG), Barrow Island (YBWX), Leigh Creek (YLEC), Ballera (YLLE), Mount Keith (YMNE), Tindal (YPTN), Telfer (YTEF) | Airport operator / AIP data; mine/island/RAAF sites may have *no conventional served city* |
| Botswana | Thebephatshwa (FBTP) | Military-airbase geographic provenance |
| DR Congo | Kisangani Simisini (FZIA) | Current civil aviation authority and city mapping |
| Republic of Congo | Ouesso (FCOU) | National AIP or local operator reference |
| India | Ratnagiri (VARG), Bokaro (VEBK), Bathinda AFS (VIBT) | Official AAI / Coast Guard / Air Force; sites may have restricted civil access |
| Laos | Savannakhet (VLSK) | Current Lao civil aviation airport/aeronautical publication |
| Saudi Arabia | Thumamah (OETH) | Saudi GACA or operator; confirm private field/locality |
| Venezuela | La Fria (SVLF) | Current INAC/AIP local airport and municipality reference |

**Do not fill source municipality from airport name alone.** For industrial sites, islands and airbases, the appropriate result may be `NO_MUNICIPALITY_APPLICABLE`, with a separate verified *regional display label*, rather than a fictional city.

## Source governance and next action

The new migration `20261110151000_group2_section1_official_localities_elevations.sql` inserts **21 official served-city** and **7 official altitude** source candidates into the protected immutable Section1 candidate ledger. `20261110152000_group2_section1_timezone_rule_conflicts.sql` stores the **five** discrepancy records and exposes a private DST-testable view. Neither writes canonical game profiles.

**Section 1 is NOT closed.** Prioritize review of the five timezone errors before any real scheduling; independently approve the 24 served-city candidates, review the 17 remaining cases and 7 elevation corrections, verify the two missing GPS fields and ensure 1,118 timezones have documented game provenance. Only then decide exact official/estimated closure and move on to Section 2.

**No change to Group 1 (3,141), Group 2 preapproved count (1,118), World1 planned status, player routes or airline ledger.** AirlineSim remains secondary code comparison only (six prior code references) because this batch found official sources.
