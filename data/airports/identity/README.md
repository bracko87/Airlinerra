# Airlinerra — worldwide identity and location research

**Selected first priority, 23 October 2026:** refresh GPS, ICAO, IATA codes and coordinates for all 8,153 master records in **one** source-ID-based pass. Do not research 49 groups serially. The runway master and existing passenger classification work must stay unchanged.

## Airport functionality rules

An IATA code, ICAO code or GPS code is **not individually required** for every valid civil airfield, commercial charter, or cargo airport. Missing a code is not proof of closure, military-only use, or non-functionality.

- **Game physical eligibility** requires source-backed location, a suitable runway and aircraft-specific performance, plus relevant civilian/commercial permissions and facilities; the current 1,200 m asphalt/concrete threshold is an initial technical screen only.
- Passenger and cargo operations must be evaluated separately. Current traffic statistics and scheduled_service source flags are not operating permissions.
- **Confirmed military-only airports** must be **excluded from playable Airlinerra**, while historical technical records remain archived. Airport names such as "Air Base" are *review hints only*: some facilities are mixed-use.
- **Mixed civilian/military airports** may be considered if relevant civilian commercial access is supported by evidence.
- **UNKNOWN is not NO.** No-code source records must be labeled NOT_REPORTED or SOURCE_REPORTED_UNVERIFIED; don't invent IATA/ICAO allocations.
- **Fictional LYAL**: owner-selected Aleksandrovo, municipality Nova Crnja, Central Banat, Vojvodina, Serbia. Village centre approximately 45.63778 N, 20.59159 E is a settlement reference, **not a verified airport/runway site**. LYAL is owner-defined as a fictional code, not certified by an external ICAO allocation.

## Single worldwide airport ID refresh

The manual-only workflow at .github/workflows/refresh-airport-enrichment.yml now obtains the current [OurAirports global airports.csv](https://github.com/davidmegginson/ourairports-data), pins its full commit hash, and joins by the immutable OurAirports source_airport_id.

For equivalent execution from Windows CMD after downloading the pinned source CSV:

    python -m unittest discover -s tests -p test_airport_identity_worldwide.py
    python scripts/refresh_airport_identity_worldwide.py --airports airports.csv --source-commit FULL_SOURCE_SHA
    python scripts/refresh_airport_identity_worldwide.py --airports airports.csv --source-commit FULL_SOURCE_SHA --check

The one pass produces:
- airport_identity_worldwide.csv — all master source IDs with available GPS/ICAO/IATA/local codes and source statuses; real coordinates where valid; source municipality/type and service signal; military review hints and non-operational gameplay flags
- identity_exceptions.csv — only missing/mismatched source IDs and codes, invalid/missing coordinates and other reported mismatches
- identity_summary.json — exact counts, source SHA and data checksums
- fictional_location_references.csv — owner-confirmed village location context
- verified_military_only.csv — currently empty evidence-backed exclusion register; future date- and source-verified military-only sites will be flagged EXCLUDED_MILITARY_ONLY without deleting their original rows

**Completion definition:** each of the four fields is evaluated worldwide. Missing codes may legitimately remain NOT_REPORTED, but missing real-airport coordinates remain open exceptions until resolved. Neither invented codes nor settlement-centre airport coordinates count as completion.

## Boundaries

This is **research-only**, never activation. The new workflow retains workflow_dispatch/manual-only, has no scheduled or push trigger, and does not deploy Supabase, alter airport runway criteria, promote final six-tier classifications or activate routes. The older data/airports/enriched/ sidecars are a historical 7,846-airport snapshot; this new output is scoped to the 8,153-row master. Supabase migration can later join new identities by stable airport source ID and pinned source SHA.
