# Airlinerra Group 2 — Fixed batches and Section 1 game-data closure

**Date:** 10 November 2026 · **User acceptance criterion:** same *GAME-data* completeness standard as Group 1 (3,141), not independent aviation certification.

## Current result — completed in production Supabase

| Result | Count |
|---|---:|
| Owner-preapproved Group 2 airports | **1,118** |
| **Immutable batches** | **23** |
| Batches 1–22 | **50 airports each** |
| Batch 23 | **18 airports** |
| Airports with complete Section 1 GAME profile | **1,118 / 1,118** |
| Section 1 batches accepted as `game_complete_estimated` | **23 / 23** |
| Group 1 approved World 1 airports (unchanged) | **3,141** |
| Group 2 airports commercially enabled | **0** |
| Independently verified Section 1 source corrections in new workflow | **0** |

**This is the same distinction as Group 1.** The Group 1 Section 1 record in `world1_game_data_section_acceptance_v1` is explicitly `game_complete_estimated`, with `source_verified_complete=false` and `live_operations_certified=false`. Group 2 is now accepted on that same game-data basis, without claiming real-world airport certification.

## Exactly what Section 1 means for each of the 1,118 airports

Every airport now has a usable, nonempty and internally unique game identity record containing:
- Game airport name and unique `G2-...` game lookup code, plus preserved original source identifier.
- ISO country, source region when known and valid latitude/longitude coordinates.
- A nonempty **game location label** with exact provenance: 1,077 original registry municipality labels, **24** separately sourced **served-city candidates** still awaiting independent review, and **17** fallback airport-name labels explicitly marked *not a real verified municipality*. These are suitable to display *as game-location labels*, not as fake legal towns.
- An IANA game timezone valid in PostgreSQL. Five demonstrably incorrect Australian nearest-airport timezone approximations have been corrected in the **effective Group 2 Section 1 read model**, using current Australian state daylight-saving rules.
- A non-NULL game elevation. Existing nearest-airport approximations and **11** clearly marked zero-elevation game fallbacks are retained and NOT called real airport altitudes.
- The **two** missing official GPS-code fields remain NULL (Chamical and Kyiv/Zhuliany); the independently unique game lookup key is usable for play, but is **not represented as an official GPS/ICAO/IATA identifier**.

The five Australian state-timezone game-model fixes are:
- Goondiwindi QLD: `Australia/Sydney` → `Australia/Brisbane`
- Horsham VIC: `Australia/Adelaide` → `Australia/Melbourne`
- Moomba SA: `Australia/Brisbane` → `Australia/Adelaide`
- Port Keats NT: `Australia/Perth` → `Australia/Darwin`
- Renmark SA: `Australia/Melbourne` → `Australia/Adelaide`

Source: [Reserve Bank of Australia daylight saving 2026](https://www.rba.gov.au/schedules-events/daylight-saving.html), with additional checks against [Tourism Australia's region/time-zone guide](https://www.australia.com/en/facts-and-planning/about-australia/time-zones.html). The original Group 2 source snapshot stays unchanged for traceability. These are game read-model corrections, **not automatic scheduling deployment**, a real-world airline authorization or a statement that all other timezone assignments have been independently checked.

## Batch ownership and permanence

`airport_group2_fixed_batch_members_v1` freezes all **1,118** existing priority-review assignments, numbered `batch_number=1..23` and `case_number=1..50`. It inherits the previous review priority ordering, so original **Batch 1's 50 research cases keep their assigned case numbers**. Each airport appears **once only** and cannot silently move between batches when the underlying research queue changes.

The same fixed membership will be used for the next seven game-data/source sections, avoiding lost or repeated airports.

`airport_group2_section1_batch_completion_v1` provides per-batch live completeness, source-gap counts and what is still estimated. `airport_group2_section1_batch_acceptance_v1` stores one immutable per-batch game-data closure record. `airport_group2_section1_overall_status_v1` returns the total **23/23** batches and **1,118/1,118** complete.

All these objects are private; `anon` and `authenticated` cannot edit or directly read them. Tables are RLS-protected. Changes to Batch assignments/closure evidence are denied by append-only triggers.

## Source hierarchy: official first; AirlineSim only secondary

For the **41** source municipality fields missing in the original registry, the Section 1 model uses 24 previously collected airport-operator/aviation-authority **served-city candidates** or 17 **airport-name game fallbacks**. It does **not** backfill fictional municipalities. There are still two official GPS-source blanks and 11 unsourced zero-elevation game estimates.

AirlineSim's public airport listings remain useful to compare occasional **IATA/ICAO spelling** and to locate possible missing source information. In prior research, six code comparisons from [AirlineSim's public Western Australia listing](https://paine.airlinesim.aero/action/info/county?id=10) covered Onslow, Mount Keith and Telfer. None was promoted to an official source or used to create fictitious town/permission data. No proprietary AirlineSim demand, airport category, landing/stand fee or aircraft-use data was bulk-copied.

Published aeronautical materials can also have licensing conditions for commercial reuse, and current effective editions must be reviewed. This closure uses existing Airlinerra source records, minimal referenced observations and explicitly labeled game fallbacks, rather than importing an external aviation publisher's entire data catalogue.

## Distinguish game closure from real source verification

**Section 1 game-data: CLOSED for Group 2**, same definition as Group 1.

**Independent source verification: OPEN** for municipality accuracy (41 original NULLs), official GPS codes (2), original elevation estimates (including 11 zero), and other game timezone assumptions. The five proven AU state-time discrepancies are fixed only in the game-data read model, not in immutable original source records. The new source-review event ledger remains at **zero independently approved corrections**.

No airport is made commercially playable or legally certified. The World 1 game remains **planned**; the operational flight engine, slot/aircraft restrictions and admission gates are unchanged.

**Next step in the agreed strict sequence:** use these **same 23 fixed batches** for **Group 2 Section 2 — Classification**, checking the 1,118 existing owner-selected tier and passenger/cargo-intention values. Game models already exist for Sections 2–8 but each needs its own explicit group-wise acceptance and remaining source-research notes. Do not restart Section 1 solely because the independent real-world research continues.

## Auditing and verification

- Migration tested inside a full `BEGIN...ROLLBACK` dry run, applied to Airlinerra production Supabase, and passed an independent **post-install rollback-only** SQL acceptance.
- Acceptance asserts 23 fixed batches (22 × 50 + 18), 1,118 unique airports and nonempty game-required fields; matches batch data to its frozen acceptance and the original Batch 1 ordering.
- Checks all five Australian timezone effective view corrections; source snapshots remain unmodified.
- Source gaps retained exactly: 41 original missing municipality fields, 24 sourced served-city labels, 17 explicit fallback game labels, 2 GPS blanks, 11 altitude-zero fallbacks.
- Ensures 3,141 Group 1 airports unchanged, zero new commercial flight authorization, and zero real flight movements.
- Protected RLS/grants; tests explicitly reject edits to membership and acceptance.

**Database status name:** `game_complete_estimated`. Do not rename it to `source_verified_complete` or `operationally_certified`.
