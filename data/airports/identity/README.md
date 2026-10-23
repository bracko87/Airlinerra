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

## Military-use screening queue (2026-10-23)

The first **worldwide name-based screening**, run against the **8,153-airport canonical master**, produced [military_use_review_queue.csv](military_use_review_queue.csv): **529 source-ID-matched real facilities in 92 country codes**. The initial review order is: **11** airport names suggesting international/mixed use (P1), **32** specialized RAF/naval/army names (P2), and **486** other name-indicated air bases (P3). These are **screening candidates, not confirmed exclusions**.

Every row explicitly records `civilian_commercial_status=UNVERIFIED`, `military_only_verified=NO`, and `gameplay_decision=NOT_ACTIVE_PENDING_REVIEW`. No row is copied into [verified_military_only.csv](verified_military_only.csv) without a dated aviation-authority or airport-operator source establishing military-only status. The master technical inventory is immutable; independently verified military-only exclusions affect **future game candidacy only**.

**Limitation:** name matching cannot discover every military-only airfield or resolve dual-use eligibility. Extend verification later with source airport type, official AIP/operator/civil access records, and scheduled/cargo evidence, in **one worldwide evidence crosswalk** instead of arbitrary small batches. Zero military-only exclusions are confirmed at this checkpoint. All airports remain non-operational in the game.

## Expanded worldwide military-name audit (23 October 2026)

The original **529 name-based review candidates** were incomplete: they missed RAF/RNAS, RAAF, AFB, many `Air Force Station`, `Army Air Field`, `Joint Base`, `Marine Corps Air Station`, and non-English military nomenclature. A second **single worldwide pass across all 8,153 master records** recovered **106 additional distinct source airport IDs**. The consolidated [military_use_review_queue.csv](military_use_review_queue.csv) now contains **635 distinct candidate facilities across 99 country/territory source codes** (P1 11, P2 32, P3 486, P4 106). P4 is a name-based review hint, not a finding of restricted access. The original 529 source IDs are preserved.

[Military-use screening summary](military_use_screening_summary.json) records exact audit counts and the completion boundary. [Civilian-use evidence](military_use_civilian_evidence.csv) now links **14 source-ID-matched airports** to government, operator, local-airport or operating-airline evidence. These cases include scheduled passenger service as well as more limited use such as civilian offshore helicopters and civilian general aviation. The evidence's exact service class matters: **heliport/GA evidence is not permission for commercial airline passenger or cargo flights**. One airport's charter/cargo *capability* is not proof of an active route. None of these civil-evidenced airports is military-only, and **none is activated for gameplay**.

**Unfinished:** the other **621 candidates do not yet have individual, adequate primary-source evidence**; none may be declared military-only on a name match, and official evidence may be needed for further military airfields not named in these patterns. The [verified_military_only.csv](verified_military_only.csv) remains empty. Even for the 14 positive cases, runway/aircraft performance, airline permissions, actual cargo/passenger access, and final six-category approval are separate requirements. This is a more complete name screening and a partial evidence verification, **not full worldwide eligibility certification**.

Run static integrity tests with `python -m unittest discover -s tests -p test_airport_military_screening_worldwide.py`. Do not accidentally replace the new 635-row queue with the old 529-row output during any subsequent identity refresh; rebuild/reconcile by immutable source ID and only from evidence-backed decisions. No runway master, group data, Supabase import, route scheduling, or production deployment is modified by this review.
