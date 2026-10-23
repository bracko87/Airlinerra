# Airlinerra — Supabase airport research sync audit (23 October 2026)

This is a **verified read-only snapshot** of the already existing, isolated Supabase project `hwllkabgzaynalahvkpz` in EU Frankfurt, compared with GitHub `main` research files. This document records remaining work; it **does not** authorize gameplay activation, publicly expose airport data, or make final commercial-use decisions.

## Where the data lives

- **GitHub `main`:** versioned primary research, source CSVs, original runway screens (Groups 1–49), provisional six-tier reviews, traffic/cargo evidence, audit exceptions, official source links, identity and military screening files. Preserve each immutable OurAirports source airport ID. Do not edit or delete raw source evidence because an airport is deemed ineligible for gameplay.
- **Supabase private `airlinerra` schema:** normalized working reference database with research import and review state. All 11 airport research tables have RLS enabled and no public policies. The separate **public** `airlinerra_site_status` table is only for the prelaunch frontend health check.
- **Gameplay/world activation:** independent and not enabled. `airlinerra.airport_world_activation` contains zero rows.

## Confirmed Supabase counts (read-only SQL, 2026-10-23)

| Item | Verified |
| --- | ---: |
| `airport_registry` | 8,153 (8,152 real + fictional LYAL) |
| `airport_cohorts` | 8,153 |
| `airport_codes` | 32,887 |
| `airport_runway_observations` | 2,045 observations (2,045 distinct airports) |
| `airport_evidence` | 2,077 |
| `airport_access_reviews` | 7,046 |
| `airport_game_profiles` | 7,046 |
| `airport_certifications` | 0 |
| `airport_review_events` | 0 |
| `airport_world_activation` | 0 |
| successful `import_batches` | 6 |
| duplicated (source_type, source_airport_id) rows | 0 |

**Cohorts:** original 3,140; Local/Regional expansion 3,906; other runway-qualified master 1,106; protected fictional LYAL 1. The 7,046 original+expansion records have access-review and provisional game-profile rows. **1,106 other-master records plus LYAL have no access-review or game-profile rows**, which is a review backlog, not evidence of airport invalidity.

**Airport identity fields:** all 8,152 real records have source-reported latitude and longitude; LYAL runway coordinates remain deliberately NULL because the village location is *not* an airport site. Real-airport municipality is missing in **248** rows (52 original, 158 expansion, 38 other). Source-reported GPS codes exist for 7,777 airports; the other 376 real airports have no source-reported GPS value. Source-code coverage: ICAO 5,520 airports, IATA 5,301 airports, FAA LID 2,058, LOCAL 4,078, SOURCE_IDENT 8,153. A missing ICAO/IATA/GPS code is **not automatically a data mistake or a reason to exclude an airport**.

**Categories:** the 7,046 preliminary profiles have six-category proposals (Local 2,551; Regional 1,562; Medium 1,752; Large 906; Major Hub 205; Mega Hub 70). All 7,046 **final** categories are NULL; the remaining 1,107 records do not yet have profiles. Owner-defined fictional LYAL is locally classified as Level 1 / Local in GitHub, but is not a real ICAO-certified airport.

**Access:** all 7,046 access-review records remain `NOT_APPROVED` for gameplay. Actual access-review statuses include incomplete/hold and FAA source-only review categories; these are not commercial operating authorizations.

**Imported dataset list in database audit:** `airport_register.csv` 8,153; `airport_identity_worldwide.csv` 8,153; `airports_3140.csv` 3,140; `candidates_local_regional.csv` 3,906; `game_admission_status_3906.csv` 3,906; `us_faa_review_2026_10_01.csv` 2,077. All six are logged as SUCCESS, tied to historical recorded commit `3e8d2d7318…`. **These table counts do not prove that every later GitHub research sidecar is imported or that row-level content matches the latest repository revision.** A stable-ID and file-hash/manifest reconciliation is required before claiming complete synchronization.

## Outstanding research and import work, in order

1. **Reconcile exact GitHub source-ID sets and source hashes with Supabase.** Compare the 8,153 immutable `source_type:source_airport_id` keys, country group counts, protected LYAL, date-stamped import manifest and all source checksums. Do not replace records via truncation or blindly mark current because counts match.
2. **Import new evidence as non-operational research, not approvals.** Map the latest GitHub six-tier classification evidence, dated passenger/cargo measures, runway source IDs, airport identity/source status, and civil/military evidence into the normalized schema using reversible staged upserts with per-field provenance. Detailed runway observations currently exist for only 2,045 distinct airports, not every runway. Never pretend `longest_qualifying_runway_m` is full runway geometry.
3. **Keep unresearched records visible.** Create or maintain a review backlog for the 1,106 `OTHER_MASTER` real airports, 248 missing real-airport municipalities, code-related source exceptions, access and capacity holds. GPS/ICAO/IATA `NOT_REPORTED` is not equivalent to `NO`. Do not invent codes or coordinates.
4. **Military and mixed-use aviation:** GitHub `data/airports/identity/military_use_review_queue.csv` contains **635 candidate sites** from name screening, of which **14** have individually linked civilian-use evidence and **621** still need individual adequate evidence. These are **review candidates**, not proven military-only exclusions. Do not delete them from the technical inventory, infer military-only from names, or auto-approve the 14 for commercial passenger/cargo operations. No verified military-only exclusions recorded in `verified_military_only.csv`.
5. **Final admission and category approval later:** keep exactly six final categories — Local, Regional, Medium, Large, Major Hub, Mega Hub — and separate technical runway qualification, commercial permissions, capacity, cargo/passenger demand and game-world activation. No airport is operational until independently approved.

## Safe repeatable SQL audit (read-only)

```sql
select count(*) from airlinerra.airport_registry;
select cohort, count(*) from airlinerra.airport_cohorts group by cohort order by cohort;
select count(*) from airlinerra.airport_registry
where source_type = 'OURAIRPORTS' and (latitude_deg is null or longitude_deg is null);
select count(*) from airlinerra.airport_registry
where source_type = 'OURAIRPORTS' and nullif(btrim(municipality),'') is null;
select count(*) from airlinerra.airport_registry a
left join airlinerra.airport_access_reviews r using(airport_key)
where r.airport_key is null;
select count(*) from airlinerra.airport_world_activation where active;
```

**Status at this checkpoint:** base master and important identity/review fields already imported. Full GitHub-sidecar synchronization and evidence-backed non-sorted research are still open. Preserve independent raw sources and no-game-activation boundary while proceeding.
