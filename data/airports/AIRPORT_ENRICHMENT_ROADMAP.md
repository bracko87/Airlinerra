# Airlinerra — Airport enrichment and commercial-readiness roadmap

Status: **Phase A worldwide identifiers/coordinates/runway sidecars implemented 2026-10-21; Serbia commercial-evidence pilot implemented; global commercial eligibility, slot capacity, curfews and demand engine remain future work**.
Source baseline: runway-qualified master `data/airports/airport_register.csv` (7,846 records as of 2026-10-21; includes fictional LYAL).

**Latest canonical master (2026-10-22): 8,153 airports (8,152 real + fictional LYAL).** The 7,846 baseline above is historical, as is the existing detailed source geometry enrichment. A **new reference-only, non-operational GitHub-to-future-Supabase handoff** is specified in [migration/README.md](migration/README.md), implemented by `scripts/prepare_airport_reference_handoff.py` and tested by `tests/test_airport_reference_handoff.py`. It emits repeatable airport/access/traffic/runway-source CSVs with manifest hashes; it does not create tables, apply Supabase SQL, grant permissions or deploy the game. Refresh pinned-source geometry against the current 8,153 airport master before importing complete coordinates/runways.
Branch: `main` only. Keep original source group screens and master untouched until a validated migration is deliberately planned.
This plan supersedes the prior runway-only **scope for future work**, but does not change the current official runway screening requirements or authorize a Supabase/game deployment.

## Identity priority update (2026-10-23)

The owner selected four immediate fields: GPS code, ICAO code, IATA code, and real-airport latitude/longitude. One independent global 8,153-row source-ID join is now prepared at [identity/README.md](identity/README.md) and through the manual-only refresh-airport-enrichment workflow; skip country-by-country identity collection. Preserve unassigned/unreported code statuses rather than inventing values; evaluate actual civilian aviation operations independently. Exclude *confirmed military-only* sites from gameplay, not from the immutable technical research master. A military-looking name alone is not proof. Aleksandrovo LYAL is in Central Banat, Serbia, but the settlement centroid must not be misrepresented as exact runway coordinates. No Supabase or live gameplay activation.

## Decision: one worldwide automated data pass, followed by grouped verification

**Do not try to manually research ~8,000 airports in a single operation.**
1. Bulk join every real airport by immutable `source_airport_id` to the same pinned OurAirports `airports.csv` and `runways.csv`, without overwriting raw source records. Capture identifiers, coordinates, runway geometries and candidate scheduled-service indicators. Report unmatched IDs and missing values.
2. Use a **Serbia pilot** (including Kovin and the explicitly fictional LYAL) to test the commercial-filter methodology, evidence, slot/capacity model and route-distance calculation on a small varied set.
3. Enrich the remainder by original Groups 1–49, so every group has documented country totals, screened/not-yet-verified counts, exceptions, source evidence and validation. Split very large groups (United States, Brazil, etc.) into review sub-batches **without** splitting source-country ownership or double-counting airports.
4. After reliable geometry/operational records are available, integrate these versioned reference data into Supabase and implement the live demand/flight-slot engine. Supabase is **not** required for research or verification on GitHub.

## Commercial traffic: four different questions — never conflate

- **Legally permitted access:** commercial passenger service permitted? commercial cargo permitted? military/private/restricted? `YES | NO | UNKNOWN` independently for passengers and cargo. If unknown, do not call the airport commercial-ready.
- **Physical capability:** can appropriate commercial aircraft operate given paved runway(s), available length/width, aircraft mass/performance, pavement strength when available, local constraints, and minimum passenger/cargo facilities? Record `CONFIRMED | ESTIMATED | UNVERIFIED | NOT_CAPABLE` independently.
- **Current real-world service:** scheduled passenger, charter/general aviation, cargo-only, mixed or none (evidence + as-of date). OurAirports `scheduled_service` is a helpful screening signal, **not** proof of legal cargo approval, volume, or current timetable.
- **Game market potential:** modeled demand is independent from historical scheduled flights. Airports can have commercial potential with no existing schedule, but this must not be represented as real-world statistics.

Keep ALL original runway-qualified candidates as historical research records. Assign a separate game status: `ACTIVE_CONFIRMED`, `LIMITED_CONFIRMED`, `POTENTIAL_UNVERIFIED`, `RESTRICTED`, `NOT_COMMERCIAL`, or `NEEDS_REVIEW`. Passenger and cargo permissions are separate; neither status nor existence of a 1,200m runway automatically grants gameplay activation. Zero-access facilities remain outside the playable selection unless explicitly fictional/game-design exceptions are approved.

## Proposed normalized reference datasets (CSV now, SQL tables later)

### Airport identity and location (one row per source ID)
`airport_id` (internal stable key); `source_airport_id`; `country_iso`; `airport_name`; `icao_code`; `iata_code`; `gps_code`; `local_code`; `source_ident`; `latitude_deg`; `longitude_deg`; `elevation_ft`; `municipality`; `region`; `timezone_iana`; `source_snapshot`; `verification_status`.

- Validate numeric latitude [-90,90], longitude [-180,180], coordinate presence, sensible location/country, and collisions.
- Actual `icao_code` is NOT interchangeable with OurAirports `ident` or `gps_code`; missing ICAO/IATA is allowed and NOT replaced with a guessed code.
- Preserve ambiguous identifiers in a conflict review queue; specifically preserve the existing Iran OIBH conflict.
- Coordinates for fictional **Aleksandrovo LYAL** remain `UNKNOWN` until its owner approves a fictional location: do not invent a latitude/longitude.

### Runways (one row per original qualifying paved runway)
`airport_id`; `source_runway_id`; `runway_designator_low/high`; `length_m`; `width_m`; `surface_raw`; `surface_verified`; `closed`; `lighted`; `heading`; `threshold_coordinates`; `declared_TORA_TODA_ASDA_LDA` (if documented); `pavement_strength` (if documented); `evidence`; `as_of`.

- **Playable runway** must be non-closed, >=1,200 m, confirmed asphalt or concrete, in line with established eligibility. Record ALL qualifying runways, not merely the single longest. Do not accidentally treat multiple directions of one strip as separate runways.
- Other physical surfaces can remain in provenance or review files, but do not count as usable paved runways or activate them.
- Airport aircraft compatibility will eventually also depend on width, declared distances, altitude, aircraft weight and performance, not just nominal strip length.

### Operations, facilities, capacity and restrictions
`airport_id`; `passenger_permission`; `cargo_permission`; `service_type`; `civilian_access_status`; `scheduled_service_flag`; `passenger_terminal_available`; `cargo_facility_available`; `customs_status`; `operating_hours`; `timezone_iana`; `curfew_windows_local`; `noise_limits`; `restrictions_and_exemptions`; `passenger_gates`; `remote_stands`; `apron_stands`; `published_runway_movements_per_hour`; `published_apron_limit`; `evidence`; `confidence`.

- **Runway slots ≠ runway count.** Separate real published declared capacity (when known) from **game-estimated hourly movement capacity**. Model runway interaction, availability, operating hours, turn-around occupancy, stands and aircraft types. Gates are contact positions; remote stands and apron parking are distinct capacity constraints and may require buses/handling.
- Default unknown restrictions or gate counts to `UNKNOWN`, not to `0` / `NO`. Unknown must not be silently treated as no curfew or unlimited slots.
- Curfews use airport-local IANA timezone and date-dependent schedules; include weekday/season/exemptions when known. Noise restrictions are not necessarily identical to closed-hour curfews.

### Traffic demand and simulation (separate game-generated data)
`airport_id`; `calendar_date`; `passenger_demand_origin`; `passenger_demand_destination`; `cargo_tonnes_origin`; `cargo_tonnes_destination`; `actual_observed_passengers`; `actual_observed_cargo_tonnes`; `data_kind`; `model_version`.

- Distinguish **published observed traffic** from **modeled Airlinerra demand**. There is no reliable universal free source guaranteeing daily/weekly/monthly/yearly observed passenger and cargo traffic at every airfield; leave absent observed values null.
- Build game demand from geography/catchment population, economy, tourism, cargo industries, seasonality, existing connectivity and competition. Flight schedules and airline decisions convert potential demand into actual in-game movements and served traffic.
- Store primary daily model inputs/outputs; aggregate weeks and real calendar months/years from daily figures, with fixed model-version and data-source traceability. Avoid independently invented daily/monthly/yearly statistics that do not add up.
- A low-volume airport may have charter or cargo potential while receiving no scheduled passenger market. Capture passenger and cargo independently.

## Sources and verification policy

1. **Bulk structural source:** pinned OurAirports datasets (source airport IDs, coordinates, codes, scheduled service, each runway's dimensions and status). Provenance: dataset URL, download hash, date, raw value.
2. **Critical operational confirmation:** official national AIPs/NOTAM sources, airport operators, national aviation regulators, slot coordinators and applicable official airport/statistical publications. Check each source's commercial reuse rights.
3. **When unavailable:** `UNKNOWN` plus a specific review reason and source URL (if any). Do not invent permission, night restrictions, stands, traffic or capacity. Published values and transparent game approximations must occupy different fields.
4. **Field-level audit:** value, evidence source, source date, confidence (`OFFICIAL`, `COMMUNITY`, `MODELED`, `UNVERIFIED`) and reviewer/decision history. Surface overrides remain airport-specific.

## Group acceptance checks

For each group report: input airport count; identity matched; valid coordinates; ICAO/IATA/local-code coverage; playable runway count and length/width validation; passenger-capable/cargo-capable/restricted/not-commercial/unverified counts; source-backed curfews and stand/capacity data; game-demand readiness; exceptions and outstanding reviews. Every country gets a total. Never count missing data as zero or invent official measurements.

Automated integrity gates: one stable primary key per airport; no dropped historical airports; known fictional LYAL preserved; no code collisions silently resolved; lat/lon ranges; runway airport foreign keys; surfaces verified; no duplicate original runways; chronological metadata and versioning; daily/weekly/monthly/yearly demand consistency; source licenses recorded.

## Implementation order and first group

- **Phase A (all airports, bulk):** build normalized sidecar snapshots and validation scripts for location, codes and all qualifying runway records. Keep the current `airport_register.csv` and screened Groups 1–49 unchanged.
- **Pilot Serbia / Group 9:** review Belgrade, Niš, Morava/Kraljevo, Kovin, other runway-qualified Serbia airfields, plus fictional LYAL, to test independent passenger/cargo status and commercial suitability. **Do not presume Kovin lacks commercial permission; verify.** Never fabricate LYAL's GPS coordinates or traffic.
- **Phase B (group-by-group):** official operational eligibility, cargo facilities, curfews, stands and restriction evidence prioritized by airports likely to enter the game; mark others unverified.
- **Phase C (engine):** published capacity where available; otherwise documented deterministic game-slot estimates. Build daily passenger and cargo demand + consistent weekly/monthly/yearly aggregation, with independent market potential and airplane movement calculations.
- **Phase D (deployment):** only after validation and owner's explicit authorization, create relational schema/migrations and import GitHub-versioned snapshots into Supabase for live multiplayer worlds. Keep GitHub as the reproducible reference-data source, Supabase as live operational/game-state storage.

Airlinerra's **six** future airport categories remain exactly: Local, Regional, Medium, Large, Major Hub, Mega Hub. Commercial eligibility and group inclusion are NOT the final six-tier assignment.

## Implementation checkpoint — 2026-10-21

- Worldwide identity, location, code snapshots: `data/airports/enriched/airport_identity.csv` (7,846 airport records; 7,845 source coordinates, fictional LYAL blank).
- Paved runway inventory: `data/airports/enriched/qualifying_runways.csv` (9,260 individual non-closed >=1200m source/override runways). This is *not* all physical runways and is not certification for arbitrary aircraft or the usable declared distances.
- Code coverage: 5,409 source-reported ICAO entries and 5,179 source-reported IATA entries; these are **unverified identifiers**, not government certification.
- Commercial operations: `data/airports/enriched/commercial_review_queue.csv` (7,846 unverified passenger/cargo entries; unknown does not imply 0 or NO). `data/airports/enriched/serbia_commercial_pilot.csv` holds documented observations for seven Serbia records.
- Both source CSVs pinned to OurAirports commit `b529623d2a0b09a9be78d37fc7a7a5e1e16e3451`; regenerate with `scripts/enrich_airport_reference.py`, validate with `scripts/validate_airport_enrichment.py`.
- Master `airport_register.csv` and fictional LYAL preserved unchanged; no Supabase updates or game activation.
- **Priority source discrepancy:** Ponikve LYUZ operator says 1,830m usable asphalt vs old source candidate approximately 3,087m. Verify runway declared distances before the airplane/slot engine (see Serbia pilot).
