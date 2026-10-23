# Airlinerra — Supabase is the central airport research database

**Implementation verified on 23 October 2026.** Supabase project `hwllkabgzaynalahvkpz` (`Airlinerra`, eu-central-1 Frankfurt) is the **central working structured database**. GitHub `main` remains the transparent, versioned *source archive*, codebase and source of original research evidence. A GitHub change is **not automatically synced to the database**; follow controlled imports and verify source hashes before assuming the working database is current.

## Existing normalized working tables

The private `airlinerra` schema already contains `airport_registry` (**8,153** airports, 8,152 real and fictional LYAL), `airport_cohorts` (8,153), `airport_codes` (32,887), `airport_access_reviews` (7,046), `airport_game_profiles` (7,046), `airport_evidence` (2,077), `airport_runway_observations` (**11,304**), `airport_certifications` (0), `airport_review_events` (0), `airport_world_activation` (**0**), and `import_batches` (6 earlier successes). These counts are separate from the research archive below.

All airport working tables remain RLS-protected and outside the public Data API. Only the separately guarded `public.airlinerra_site_status` is used for the public website connectivity check.

## Added private, versioned research catalog

- `airlinerra.research_source_snapshots`: immutable pair `(source_path, source_git_blob_sha)` with GitHub commit, expected/imported source rows, status, notes and verification time.
- `airlinerra.research_source_rows`: original source rows as JSONB keyed by `(source_path, source_git_blob_sha, row_number)`, with optional foreign key to stable `airport_registry.airport_key`.
- `airlinerra.airport_research_overview`: private, `security_invoker` summary of all 8,153 airport records, joining available classification, source/military hints, civil evidence, code/city exceptions, and access state.
- `airlinerra.airport_research_backlog`: private prioritized inspection view; priority 10 means no access review yet, 30 means missing municipality, 40 military-name source review, 50 unreported GPS code, 90 remaining final classification review. These priorities **do not authorize gameplay or automatically reject an airport**.

The catalog holds **34,119 source rows** from 13 versioned CSV files, including 2 empty verified exception/exclusion files. This is a stored research catalog; **do not sum these rows to claim unique airports** because multiple sources link to the same airport.

### Imported source files

| Research file (under `data/airports/`) | Rows | State |
| --- | ---: | --- |
| `identity/airport_identity_worldwide.csv` | 8,153 | Verified |
| `classification/airport_classification_review.csv` | 8,153 | Verified |
| `identity/military_use_review_queue.csv` | 635 | Verified |
| `identity/military_use_civilian_evidence.csv` | 14 | Verified |
| `identity/fictional_location_references.csv` | 1 | Verified |
| `identity/identity_exceptions.csv` | 0 | Verified; empty source |
| `identity/verified_military_only.csv` | 0 | Verified; empty source |
| `enriched/qualifying_runways.csv` | 9,260 | Verified with exception |
| `enriched/commercial_review_queue.csv` | 7,846 | Verified with exception |
| `enriched/serbia_commercial_pilot.csv` | 7 | Verified |
| `commercial/batchB02/b02_colombia_2025_aerocivil_regular_airport_endpoints.csv` | 46 | Verified |
| `commercial/batchB02/b02_2025_metric_reconciliation_queue.csv` | 3 | Verified; 1 country-scope row |
| `operations/b02_2025_published_capacity_evidence.csv` | 1 | Verified |

**Runway normalization:** 9,259 historical individual runway rows linked to current airport IDs were added to `airport_runway_observations`, retaining their own length, width, surface, end geometry, source ID and provenance JSON. Existing 2,045 observations were preserved, yielding **11,304** records for **8,059** distinct airports. Historic rows are explicitly `HISTORIC_OURAIRPORTS_SOURCE_ONLY` and operational status `UNVERIFIED`. This is NOT a declaration of 8,059 currently operational airports or that the older runway snapshot fully covers the current worldwide master.

**Historical unmatched airport:** archived runway row 185 (source runway ID `602402`) and archived commercial-review row 665 refer to old OurAirports airport ID `335361`, identifier `BR-0856`. This source ID is absent from today's master, so both records are deliberately preserved as unlinked historical research, **not** auto-created in the master. The B02 metric reconciliation archive has one legitimate `Ecuador nationwide` scope row without an individual airport ID; it remains unlinked by design.

**Coding and classification safeguards:** retain source-reported GPS/ICAO/IATA codes exactly; absent codes are `NOT_REPORTED`, not invented or proof of inability to operate. Final six-tier categories for real airports are NOT approved: Local, Regional, Medium, Large, Major Hub, Mega Hub. 635 military-name flags are candidate reviews, not military-only exclusions; 14 positive civil-use records do not themselves authorize flights. The fictional Aleksandrovo/LYAL settlement centre is stored as a location *reference*, not a runway coordinate. World activation count remains zero.

## Outstanding work / next source-controlled sync

1. **Not fully synced:** GitHub also contains many raw group-screen files, per-airport traffic/cargo supporting artifacts and historical raw snapshots beyond the 13 files above. Those have **not all been individually reconciled into the new source archive**. Do not claim a complete repository-wide mirror yet. Some relevant data is already represented in normalized Supabase rows, so compare by pinned source-ID and digest rather than blindly duplicating.
2. 1,106 real airports in `OTHER_MASTER` (and fictional LYAL separately) lack `airport_access_reviews` and `airport_game_profiles` rows. Preserve them and create explicit unreviewed statuses as needed; NEVER auto-admit.
3. 248 real airports have no source-reported municipality, 376 no source-reported GPS code. Missing an ICAO or IATA code can be legitimate. Evidence-backed follow-ups, not invented values.
4. Confirmed game admission, actual commercial access, aircraft-specific suitability, cargo/passenger demand, service classes, capacity and final six-tier categories are independent later approvals.
5. When a GitHub research CSV changes, ingest it as a NEW immutable `source_path + Git blob SHA` snapshot; reconcile every row by stable `source_type:source_airport_id`; verify expected vs loaded and unmatched rows; only then mark verified. Never `TRUNCATE` or silently reclassify older evidence.
6. No Netlify gameplay launch or live airline creation is authorized by these research imports. The Netlify homepage remains a separate prelaunch site.

## Simple SQL overview

```sql
select airport_key,country_iso,airport_name,research_priority,
       next_research_action,outstanding_research_flags
from airlinerra.airport_research_backlog
order by research_priority,country_iso,airport_name
limit 100;

select source_path,source_git_blob_sha,expected_rows,imported_rows,import_status,source_notes
from airlinerra.research_source_snapshots
order by recorded_at desc,source_path;

select count(*) from airlinerra.airport_registry;
select count(*) from airlinerra.airport_world_activation where active;
```

**Security:** New tables explicitly enable RLS, revoke anon/authenticated access, and views use `security_invoker=true`. Supabase Security Advisor's informational `rls_enabled_no_policy` is intentional for these private research tables; policies are not added simply to suppress that notice. No service role keys or credentials were added to GitHub.
