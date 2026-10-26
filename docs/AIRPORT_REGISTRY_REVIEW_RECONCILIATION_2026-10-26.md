# Airlinerra airport registry ↔ access-review reconciliation — 2026-10-26

**Type:** Read-only production database audit; **no airport records edited**.  
**Project:** Supabase Airlinerra, private `airlinerra` schema.  
**Repository:** `bracko87/Airlinerra`, development on `main`.  
**Status:** Research-only; no gameplay admissions or category approvals.

## Verified source counts

| Dataset / cohort | Airports | Access reviews | Game profiles | Missing coverage |
|---|---:|---:|---:|---:|
| `ORIGINAL_3140` | 3,140 | 3,140 | 3,140* | 0 |
| `EXPANSION_3906` | 3,906 | 3,906 | 3,906* | 0 |
| `OTHER_MASTER` | 1,106 | 0 | 0 | 1,106 |
| `FICTIONAL` | 1 | 0 | 0 | 1 |
| **Total** | **8,153** | **7,046** | **7,046** | **1,107** |

*7,046 profile rows exist and all match registry rows. Cohort subtotals from the same key-set comparison and cohort counts.*

The 7,046 access reviews all join to `airport_registry`, with **zero orphaned records**. The 1,107 missing reviews are fully explained by the `OTHER_MASTER` and `FICTIONAL` cohorts. All **8,153** master records have `runway_screen_status='RUNWAY_QUALIFIED'` and `minimum_eligible_level=1`; this is a **technical minimum only**, not an approved category or operating permission.

## Review-state facts

- **ORIGINAL_3140**: all 3,140 access reviews are `HOLD`. All four identity/paved-runway/civilian-access/commercial-permission fields in this *access review* are `UNVERIFIED`; these rows have no `review_date` or `source_review_note`. This does not erase previous runway research: it means the subsequent access-admission workflow has not verified these dimensions. **Do not treat the 3,140 as gameplay-ready.**
- **EXPANSION_3906**: 1,929 have identity, paved runway and civilian-access status `VERIFIED` but `commercial_permission_status='UNVERIFIED'`. Another 129 have identity verified only. The remaining 1,848 are unverified on those three access fields, with various hold reasons.
- **All 7,046** have `commercial_permission_status='UNVERIFIED'`, `passenger_scheduled_status='UNVERIFIED'`, `game_admission_status='NOT_APPROVED'`. **Zero** have `owner_approved_at`.
- **All 7,046 game-profile rows** have a proposed category from exactly six approved category names: Local 2,551; Regional 1,562; Medium 1,752; Large 906; Major Hub 205; Mega Hub 70. **Zero** have `final_category` or `category_approved_at`. Proposed classes must not be presented as final.
- `airlinerra.airport_world_activation` contains **0 rows**. The future `airlinerra_game` account schema has **0 deployed tables**. Research and gameplay activation are separate.
- 1,106 unreviewed `OTHER_MASTER` records are OurAirports source IDs with `RUNWAY_QUALIFIED`; the additional unreviewed record is fictional `FICTIONAL:fictional:RS:LYAL` (Aleksandrovo).

## Architecture mismatch detected (must fix before a deployed migration)

The stable research airport identity is `airport_registry.airport_key text`; its `source_airport_id` is also **text**, not uniformly numeric:

- **8,152** real OurAirports source IDs are numeric strings.
- **1** fictional Aleksandrovo airport has source ID `fictional:RS:LYAL` and key `FICTIONAL:fictional:RS:LYAL`.

However, the not-yet-applied game-schema draft defines `airlinerra_game.approved_game_airports.source_airport_id bigint` and `airlinerra_game.airlines.home_airport_source_id bigint`. The trusted server validator `server/airline-activation.mjs` only accepts positive BIGINT values. The fictional airport cannot pass this contract, and assuming a raw numeric source ID as globally unique is weaker than the registry's stable namespaced key.

**Required pre-migration design decision:** use stable `airport_key` as a text key across game approvals, airlines and API, **or** introduce an explicit server-owned numeric surrogate mapping for every airport including the fictional one. Prefer preserving existing research `airport_key` to avoid silent rewrites. Keep game approval a separate explicit operator decision and enforce a foreign key or independent provenance check that an approved key exists in the vetted registry. Update server adapter, SQL, tests, and migration contracts *together* before deploying anything. Do not discard fictional Aleksandrovo or fabricate an OurAirports numeric ID.

## Recommended implementation order

1. **Identity contract** — align the draft game airport references with registry keys, with regression tests including both a numeric OurAirports key and fictional LYAL. Keep all release switches disabled.
2. **Review-coverage initialization** — if approved for data writes, initialize **1,107 missing access-review + game-profile placeholders** without overwriting any existing 7,046 rows; default to `UNVERIFIED`, `HOLD`, `NOT_APPROVED` and no final category. Treat fictional LYAL separately under the fictional designation; never invent real-world aviation permissions. Preserve all original provenance. Coverage completion is not verification completion.
3. **Evidence-driven access/permission review** — carry forward source-specific runway evidence, then prioritize the 1,929 expansion airports with three verified physical/public-use fields for commercial permission and suitability review. In parallel reconcile older 3,140 `HOLD` rows against their existing evidence, instead of rerunning the basic runway screening from scratch.
4. **Six-category finalization and explicit per-world admission** — only after evidence checks, finalize one of exactly: 1 Local, 2 Regional, 3 Medium, 4 Large, 5 Major Hub, 6 Mega Hub. Owner/operator explicitly approves each game airport for World 01; no automatic admission based only on runways.
5. **Separate account/platform release gate** — run the manual-only isolated PostgreSQL Actions workflow and resolve any actual failing SQL before the game-account migration or signup. Worlds 01–03 and financial features remain disabled until separately approved.

## Next safety checks

- Do not delete/reclassify original rows in bulk.
- Do not convert `VERIFIED` physical fields into `APPROVED` gameplay rows.
- Never assume `UNVERIFIED` means an airport is unusable; it means evidence is not yet recorded.
- No live database changes were made while compiling this audit.
