# Airlinerra — future Supabase airport handoff

**Preparation only (22 October 2026). No database migration, schema deployment, game activation or production release.** GitHub remains the authoritative source for collected airport research. This handoff is a portable, reproducible reference-data export for a *later*, explicitly approved Airlinerra Supabase project.

## Reference data stored in GitHub

- The canonical master file is data/airports/airport_register.csv: **8,153 airports** (8,152 real runway-qualified, plus fictional LYAL), names, country, source ID, airport code, technical runway summary.
- Source screens under data/airports/generated/group1 through group49 preserve individual qualifying runway IDs and their original grouping. Group 49 currently has zero qualifying entries.
- data/airports/classification/airport_classification_review.csv contains all proposed passenger tiers and source-defined cargo/passenger signals. Exactly six tiers are supported: **Local, Regional, Medium, Large, Major Hub, Mega Hub**. No real airport has an approved final category.
- data/airports/commercial/group* contains preliminary passenger/cargo-service reviews, their evidence links, notes and verification dates. A historic YES here is **not a legal flight permission**, a game authorization, or a capacity number.
- data/airports/commercial/batchB02 and later batches preserve original agency/operator reports, qualifications, measurement type, time period and caveats. Source-specific quarterly rows are retained even when a compact review includes an annual proposal.
- The older data/airports/enriched/ files contain coordinates, source ICAO/IATA fields, width and individual runway geometries from a **7,846-airport snapshot**, which is **outdated relative to the current 8,153 master**. Refresh and reconcile this pinned source before attempting a complete 8,153-airport geometry import. Do not guess the location of fictional LYAL.

Do not store live airline/player accounts, payment details, keys or private customer data in the public GitHub repository. Public research CSVs and their integrity records fit well in GitHub. For large licensed raw data archives or media, prefer permitted external/object storage with checksums and provenance links.

## Prepare a non-operational reference-only snapshot

The Python 3.12+ exporter scripts/prepare_airport_reference_handoff.py reads the current files without modifying them. It does **not** connect to Supabase or need credentials. In Windows CMD, from the Airlinerra repository root:

    python scripts/prepare_airport_reference_handoff.py --check
    python -m unittest discover -s tests -p test_airport_reference_handoff.py
    python scripts/prepare_airport_reference_handoff.py --out-dir build\airport-reference-handoff

The first command performs checks **without writing files**. The last command generates the following disposable output files in the explicitly selected local folder:

| Output | Included data | Protection |
|---|---|---|
| airport_reference.csv | Each master airport, stable key, identifiers, longest technical runway, qualifying runway count, provisional category and existing final category | Every record is flagged game_active=false. Real airport final categories remain blank. |
| airport_traffic_review.csv | Original annual passenger/cargo proxies, domestic-only floors, source measurement definition, review statuses, year and source URL | Unknown is not zero. Secondary Colombia counts remain secondary. Passenger and cargo are independent. |
| airport_access_review.csv | Initial passenger/cargo commercial review fields, sources, notes and verification dates | operational_access_status=UNVERIFIED everywhere, even where a historical review says YES. |
| airport_runway_source_links.csv | Source ID of each runway from technical group screens and associated airport | Runway IDs are **not** full runway geometry, width or separately verified dimensions; do not copy each airport's longest runway length to all its runways. |
| airport_capacity_evidence.csv | Verified as-of dated published infrastructure throughput evidence (currently Lima 2025) | `game_slot_capacity_approved=false` for every record; never convert published runway capacity directly to player slots. |
| snapshot_manifest.json | Output format version, record counts, SHA-256 of every consumed original CSV and every output CSV | Provides repeatability and a comparison/rollback anchor. Explicitly states no Supabase or game activation was performed. |

**Stable join key:** source_type + ':' + source_airport_id, e.g. OURAIRPORTS:6217 or FICTIONAL:fictional:RS:LYAL. Keep the untouched original source_airport_id separately. Never join by ICAO, GPS or IATA alone: those fields can differ, be absent, or collide (Iran OIBH remains unresolved).

The exporter rejects dropped or duplicated airport IDs, inconsistent master/review identities, group records missing from the technical master, duplicate original runway IDs, invalid runway counts, invalid categories, and automatic final-category promotion. Protected LYAL must remain intact. If a check fails, fix the original source/evidence record deliberately—never invent a default in the export.

## Actual Supabase migration — later and only when authorized

1. **Approve the data scope.** Complete the classification and cargo research as far as intended; verify permissions and technical capability independently. Refresh the 7,846-airport detailed identity/runway sidecar to match the current 8,153-airport master. Preserve license/source checks and review unresolved identifiers.
2. **Create one isolated Airlinerra Supabase project** or non-production staging environment. Design normalized airport, runway, passenger evidence, cargo evidence, access-review and source-provenance tables. Game-world operational state must be separate. The historical SQL at docs/deferred/airports_database_schema_draft.sql is explicitly **unvalidated and deferred**; it is *not* deployable as-is.
3. **Stage the exact hashed snapshot.** Load reference files to staging tables using their immutable airport_key as a unique external key, not airport names/codes. Reconcile source-runway IDs without assuming complete geometry. Upsert in a transaction with validated staging rows and documented rollback; never truncate/delete live rows because of a temporary source gap.
4. **Check every imported record.** Compare GitHub manifest hashes, original 8,153 source IDs, country counts, qualifying runway references, the fictional airport, six-tier candidate distribution, source-specific 2025 passenger/cargo measures and review statuses. Keep NULL and UNKNOWN distinct from NO and numeric zero. Reject any promotion of provisional proposals into final assignments without explicit approval.
5. **Only then approve game rules separately.** Implement commercial-access decisions, aircraft compatibility, slots, facilities, fees, passenger/cargo demand and world-specific operations as later tasks. An airport being runway-qualified or having 2025 traffic evidence must never activate it for players. Player airlines, fleet and transactions belong in Supabase, not GitHub.
6. **For future research updates:** commit revised official evidence to GitHub, re-export, compare the manifest with the last imported snapshot, validate differences and apply controlled incremental upserts. Maintain import version, audit and rollback history.

**Current B02 milestone:** 94 of 311 technically eligible airports have provisional passenger tiers (36 additional Colombia Aerocivil regular-flight proposals). Nine Colombian entries explicitly depend on secondary reporting. Four B02 airports now have structured 2025 annual cargo tonnes in the classification review (including Peru Lima). A separate published infrastructure capacity observation exists for Lima; no game slots have been approved. Lack of cargo data is UNKNOWN, not zero or a prohibition.

No Supabase database, SQL migration, automated production trigger, credentials or payment keys are used here. Full repository-wide Python/GitHub Actions validation remains an independent requirement before any real database import.


**New B02 quality check:** The [B02 measurement reconciliation queue](../commercial/batchB02/b02_2025_metric_reconciliation_queue.csv) keeps source-definition conflicts open. Neither passenger/cargo numbers nor published runway throughput must be auto-promoted into game demand, traffic or slot capacity. The exporter includes provenance hashes for the dated [published capacity file](../operations/b02_2025_published_capacity_evidence.csv) and marks all records non-operational.


**Colombia direct-data milestone:** the latest [official Aerocivil 2025 regular endpoint crosswalk](../commercial/batchB02/b02_colombia_2025_aerocivil_regular_airport_endpoints.csv) adds independently labeled regular-passenger and cargo-plus-mail evidence for 46 eligible airports. Historical 10 other-scope passenger tiers remain unchanged; 36 new provisional tiers were generated. The migration handoff retains `regular_passenger_proxy` and `regular_cargo_proxy_kg` independently of `annual_total_passenger_proxy`, and does not treat mail-augmented cargo kg as pure freight or live cargo rights.
