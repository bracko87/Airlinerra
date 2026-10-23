# Airlinerra airport research → Supabase migration readiness review
Date: 23 October 2026

**Decision supported:** create a **dedicated Airlinerra Supabase project** for normalized airport research/review data, with a GitHub version-controlled source pipeline. Do **not** repurpose Tennis Legacy or ProPeloton. No project or paid service has been created in this review.

## Actual project state (checked)
- Connected Supabase projects: **Tennis Legacy: Rise to Glory** and **ProPeloton Manager**. **No connected Airlinerra Supabase project**.
- In GitHub, `docs/deferred/airports_database_schema_draft.sql` exists, but is explicitly marked **unvalidated / not applied**.
- A non-operational snapshot exporter already exists: `scripts/prepare_airport_reference_handoff.py`, with `data/airports/migration/README.md`, stable `airport_key` and SHA-256 manifest.
- Airport master: 8,153 technical rows (including fictional LYAL); original 3,140 scheduled-service shortlist preserved; 3,906 second-pass Local/Regional research candidates (2,077 U.S.). Technical qualification does not establish commercial/operational access.
- FAA U.S. independent screen: 1,929 passed physical/public-use checks, 148 held. Among passed, 40 need runway/category discrepancy follow-up; 1,889 are in an operator-permission review queue. **Zero approved game airports**. The Part 139 crosswalk is not yet successfully run.

## Why the old SQL draft must NOT be executed unchanged
1. `public.airports` conflates research records and game-active state; it lacks standardized source-key provenance, municipality/region, GPS/local codes, original vs game-only codes, code collision handling, identifier-verification status and source snapshot dates.
2. `airport_runways` lacks observed width, end identifiers/headings, geometry/evidence provenance and multi-source observations. Default `runway_operational=true` is unsafe for unverified source records.
3. `airport_restrictions` alone does not record **separate passenger/charter/cargo authorization**, public/private access, Part 139 class, evidence links, verifier, status transitions or effective dates.
4. Proposed tier, final tier and game-world-specific activation/capacity are not normalized separately. The six allowed categories must be `Local, Regional, Medium, Large, Major Hub, Mega Hub`; none of the new 3,906 is approved.
5. Source evidence from the original 3,140, the 3,906 expansion, NOAA/FAA/other authorities, and B02 commercial traffic would not survive in full merely through the original 3-table draft.
6. Existing exporter covers master, runway *links*, access/traffic review and limited capacity evidence but **does not yet export the latest 3,906 individual admission decisions or the U.S. FAA/Part139 sidecars**. Without extending the exporter those review decisions could be lost at migration.

## Recommended normalized design (private research schema first)
| Table / concept | Purpose / invariant |
|---|---|
| `airport_registry` | One stable `airport_key` (source_type + source ID), name, country, municipality, region, coordinates; source code/identity not overwritten by game values |
| `airport_codes` | Code type (`FAA_LID`, `GPS`, `ICAO`, `IATA`, `LOCAL`, `GAME_*`), provenance, official-vs-fictional flag, conflict review; do NOT globally unique-constraint unverified source codes across distinct authorities |
| `airport_runways` | Per-source runway ID, runway ends, usable length/width, surface and operational status; qualifications distinct from raw observations |
| `airport_source_observations` | Source authority/URL, source effective date, snapshot/hash, fields actually reported, verification status and conflict history |
| `airport_access_reviews` | Separate civilian access, charter passenger, scheduled passenger, cargo, owner/operator permissions; UNKNOWN not NO |
| `airport_certifications` | FAA Part 139 / other authority certificates with class, permitted-operation hints, effective date, independent verification and exceptions |
| `airport_review_events` | Immutable audit trail: airport, decision (hold/rejected/approved), specific reason, reviewer, supporting evidence |
| `airport_game_profiles` | Proposed **six-tier** category separate from final category, simulation-only codes, capacity estimates, no authority implied |
| `world_airport_activation` | One row per future world + airport, default inactive; only owner-approved final-game and commercial permission supports activation |
| `import_batches` | Source commit, input manifest SHA-256, file versions, counts, result, rollback anchor |

Keep research data in a **non-exposed PostgreSQL schema** where possible. Expose game-approved read-only views separately with proper RLS; never make all research rows visible to players. Back-end administrative writes only; no service-role keys in browser clients.

## Low-risk migration sequence
1. Choose dedicated Airlinerra Supabase project/organization and **confirm any new-project cost before creation**. Do not run schema DDL in either unrelated existing game project.
2. Finalize schema in version-controlled migrations and test it in an isolated environment. Avoid applying `docs/deferred/...sql` directly.
3. Extend deterministic exporter to include 3,906 admission statuses and FAA evidence, Part 139 only after its completed verified crosswalk. Keep an immutable original source payload and hashed manifests.
4. Stage 8,153 master airports plus linked runway, codes, source-evidence and review records using stable keys. Use transactional upserts, not delete/reinsert, with NULL distinct from false/zero. Build validation queries for 8,153/3,140/3,906/2,077, all six categories, LYAL and mismatched IDs.
5. Compare all imported counts/hashes to GitHub, reconcile unmatched runway details and source conflicts, test rollback and RLS. **No game-world activation** until a separate approved deployment.
6. Subsequent research runs: scheduled data acquisition in a job/worker with explicit source pin → staging/import → validation → private review tables. Commit scripts, schema and audit manifests to GitHub. External evidence discovery still costs time; Supabase speeds database operations but does not itself certify real airports.

## Cost/effort assessment
- **Volume:** several thousand airport rows and runway/source-evidence sidecars: routine for PostgreSQL, not a large data migration.
- **Engineering complexity:** **moderate**, concentrated in designing normalization, loading new FAA/expansion sidecars and preserving evidence/approval history. The hard work is verifying commercial permissions, not copying CSV bytes.
- **Delay risk:** continuing to invent separate CSV representations of approvals would make eventual reconciliation more complicated. Do the schema and non-operational import soon; postpone live game deployment.
- **Approval boundary:** this review does not authorize billing, project creation, credential exchange, database mutations, or gameplay activation.

## Existing failed U.S. FAA Part 139 workflow
Run #2 failed on duplicate FAA `SITE_NO` (`23747.31`), not on a PostgreSQL issue. Corrected code now cross-matches `SITE_NO` plus `ARPT_ID`; identical ambiguous pairs remain on hold. Regression tests added, but a new successful workflow run is still required before recording Part 139 outcomes.
