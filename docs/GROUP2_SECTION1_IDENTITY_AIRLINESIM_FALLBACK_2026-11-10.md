# Airlinerra Group 2 — Section-by-section airport source review

**Established:** 10 November 2026
**User instruction:** Review Group 2 properly, **one section at a time**, and consult [AirlineSim](https://www.airlinesim.aero/) as an additional reference *only when airport data is missing or cannot be independently found*. Group 1's existing 3,141 airport model is frozen and not part of this task.

## The source-use rule (all eight sections)

1. **Authoritative primary source**: published current national AIP/aviation authority, official aerodrome operator, state or municipal aviation agency, and directly supported source observation. Verify airport identity, document effective period, restrictions and the source's actual claim.
2. **Existing Airlinerra collected original registry and review records**: retain actual provenance and compare against official source; do not silently replace known/unknown with an unrelated nearby airport's facts.
3. **AirlineSim**: public *third-party simulated airport database*. Its public airport listings can help identify possible ICAO/IATA codes, runway lengths, time restrictions, traffic ratings and other areas worth checking. **It is not an aviation authority.** Its game's demand bars, airport-size tiers, slots, fees, passenger traffic and simulated world availability are not real-world verified airport values and must not be copied into Airlinerra's game economy or source-verification gates. Do not bulk-scrape their proprietary database. Copy only very limited individual factual code comparisons, with source URL and game-specific caveat; otherwise link to the page for research.
4. **When no reliable value is found**, preserve the NULL unknown or the currently marked GAME estimate and leave the review unresolved. Never invent a current civil/commercial licence, runway access, airport curfew, municipality, IATA code or time zone. Facts may be historical, conditional or local to a specific aircraft.

Each section separately tracks original sourced fields, exact gaps, proposed corrections, independent review, source URLs, and *whether anything has been approved for game use*. No stage of this process grants real or simulated commercial flight permission. Source research never automatically admits a Group 2 airport to the Group 1 World 1 approved roster.

## Ordered work plan — complete one before moving to the next

| Step | Section | Review scope | Initial position |
|---|---|---|---|
| 1 | **Identity & Geography** | Airport name, ISO country, coordinates, town/locality, ICAO/IATA/GPS code, timezone/elevation with provenance; duplicate/reused identity checks | **Active now** |
| 2 | Classification | Owner six-tier category and passenger/cargo intended services, backed by appropriate facts and game-balance consistency | Not opened in this review |
| 3 | Runways | Current runway lengths/widths, surfaces, declared distances, runway designators and critical operational conditions | Not opened in this review |
| 4 | Terminals & Facilities | Passenger/remote/cargo stands, services, realistic game capacity by tier; source versus game estimation | Not opened in this review |
| 5 | Operations & Restrictions | Official curfews/noise, PPR and civilian/military access, opening/closing restrictions | Not opened in this review |
| 6 | Capacity & Slots | Aircraft movements, stand types and slot policies; clearly distinguish published slot coordination from game estimates | Not opened in this review |
| 7 | Passenger & Cargo Demand | Confirm transport market context without using another game's proprietary demand bars as verified figures | Not opened in this review |
| 8 | Airport Economics | Group 1-approved landing, parking, tower, cargo and passenger GAME policies; external charges only for comparison with official published fee documents | Not opened in this review |

**Checkpoint:** Section 1 stays open until its remaining source gaps are resolved or each unknown is explicitly accepted as an estimated, non-authoritative game value. Do not represent sections 2–8 as newly verified merely because their first-pass game models were imported in PR #50.

## Section 1 — completed audit and preserved discrepancies

The Group 2 game profiles contain **1,118** unique airport identities. All have nonempty airport name, ISO country and valid latitude/longitude. These were sourced from the preapproval/registry data and have not now been independently recertified as current aviation facts.

| Source-quality fact | Airports / entries | Current handling |
|---|---:|---|
| Group 2 airport identity game profiles | **1,118** | Present and retained |
| Original registry municipalities missing | **41** | Still NULL; game display uses airport name, not a manufactured town |
| Missing municipalities with new official operator **served-city candidates** | **3** | Proposed, awaiting independent review |
| Missing municipalities without any new primary candidate | **38** | Research still needed |
| Original GPS-code fields missing | **2** | Unchanged, source check required (Chamical AR-0744 and Kyiv-Zhuliany UKKK) |
| Time zones supplied by **game estimation** | **1,118** | Remain estimates; none marked authority verified |
| Ukrainian country-timezone game fallback | **11** | Explicit Europe/Kyiv game assumption; no aviation operation/civil access inferred |
| Zero-elevation fallback | **11** | Not a physical elevation claim; linked to those Ukraine source gaps |
| New AirlineSim public comparisons | **6 factual code mentions** / 3 airports | Third-party simulation reference only |
| Independently approved new Section 1 identity sources | **0** | None invented or auto-promoted |

### Direct operator candidate localities (3)

| Game key | Airport | Candidate served city | Primary source |
|---|---|---|---|
| `OURAIRPORTS:26916` | Ballarat YBLT | **Ballarat** (airport physically in Mitchell Park suburb) | [City of Ballarat operator airport page](https://www.ballarat.vic.gov.au/Airport) |
| `OURAIRPORTS:27866` | Onslow YOLW | **Onslow** | [Shire of Ashburton airport operator](https://www.ashburton.wa.gov.au/community/shire-facilities/onslow-airport.aspx) |
| `OURAIRPORTS:26969` | Dalby YDAY | **Dalby** | [Western Downs Regional Council airport and aerodrome list](https://www.wdrc.qld.gov.au/Services-Payments/Aerodromes-Aircraft-Landing-Areas) |

The **served city** is not always the exact legal municipality/local council area (e.g. Ballarat is physically in Mitchell Park). Proposed served-city data must not be silently written into the registry's `source_municipality` field without deciding the intended semantics.

### Actual AirlineSim fallback sample (three publicly listed airports)

Public airport-country listing from a specific AirlineSim game world:
[AirlineSim public Western Australia airport listing](https://paine.airlinesim.aero/action/info/county?id=10)

| Airport | Airlinerra source ICAO | AirlineSim listing ICAO | AirlineSim listing IATA | Meaning |
|---|---|---|---|---|
| Onslow | YOLW | YOLW | ONS | Codes agree / IATA candidate only |
| Mount Keith | YMNE | YMNE | WME | Codes agree / IATA candidate only |
| Telfer | YTEF | YTEF | TEF | Codes agree / IATA candidate only |

The six observations are append-only private reference entries. They do **not** auto-populate official IATA or ICAO fields and are **not** used to fill a municipality. Note the AirlineSim public page may change by game world, not represent a current authoritative national code listing, and may require game-specific account access elsewhere.

### Database objects created

- `airport_group2_section1_source_candidates_v1` — private, immutable source candidates with exact source classification, URL, proposed fact, explanatory note, explicit pending statuses, and mandatory `independently_authority_verified=false`, `may_replace_game_profile=false`.
- `airport_group2_section1_identity_quality_v1` — live one-row-per-airport Section 1 audit, retaining source completeness and estimate provenance and showing the next research action.
- `airport_group2_section1_progress_v1` — aggregate count for 1,118 identities, 41 municipality gaps, three proposed city sources, two GPS gaps, all 1,118 estimated time zones, eleven zero-elevation fallbacks and six AirlineSim comparisons.

The original Group 2 identity profile, original owner/source records, Section 2–8 models, 3,141 Group 1 roster, operational restriction controls, airline money and World 1 launch gate have **not** changed. RLS and all anonymous/player grants are closed for the private research views and candidate table.

## Next work — still Section 1, NOT Section 2

- Source all remaining **38 missing towns**, starting with official airport-operator or government aerodrome directories. For unclear municipal boundaries, record both **served city** and local administrative municipality separately rather than guessing.
- Verify **two missing GPS-code fields** against current national codes, not another game's label.
- Verify time zones (especially 11 Ukrainian cases) and original airport elevations using authoritative aviation/national references, and distinguish a *civil time zone rule* from the airport's current NOTAM/flight availability.
- Check duplicate or reassigned airport identifiers, conflicts with Group 1, wrong-country coordinate positions and closed/replaced airports.
- For a proposed primary-source correction, obtain a genuinely independent accountable reviewer, and only then update the canonical fact through a separate reviewed migration with rollback/coverage tests. A public source candidate is NOT itself an approved gate.
- When Section 1 has a clearly documented approved-vs-estimated resolution for all 1,118 records, report the exact completeness and source-confidence counts, formally close Section 1 if justified, then begin **Section 2**.

This organized workflow replaces the habit of repeating the same 1,118 airports as simultaneously 'finished' and 'not finished'. It reports the **game-data models** and **real-world verification** separately.
