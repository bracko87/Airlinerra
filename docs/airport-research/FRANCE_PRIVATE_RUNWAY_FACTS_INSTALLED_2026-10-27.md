# Airlinerra — Private Versioned Runway Facts: Installation Report

**Installed:** 2026-10-27 in Supabase project `hwllkabgzaynalahvkpz`  
**Scope:** Research-only, private schema `airlinerra`, 14 French airport keys with source-validated physical-runway discrepancies  
**State:** INSTALLED AND READ-BACK TESTED — NOT CONNECTED TO SIMULATION, REGISTRATION, WEBSITE OR AIRLINE SCHEDULING

## Installed migrations

1. `airlinerra_private_versioned_runway_research_facts_20261027`: four `airlinerra` tables with primary keys, airport/evidence foreign keys, material and directional distance checks, private RLS (no user policies), revoke public/client grants.
2. `airlinerra_private_runway_research_security_invoker_view_20261027`: `airlinerra.runway_research_facts`, a **security-invoker** private joined source/physical/review view. No client-role access.
3. `airlinerra_private_runway_direction_research_takeoff_landing_gate_20261027`: explicit independent takeoff and landing direction statuses, including the runway-specific Le Bourget restrictions.

Canonical schema SQL archive: [FRANCE_RUNWAY_FACTS_SCHEMA_2026-10-27.sql](FRANCE_RUNWAY_FACTS_SCHEMA_2026-10-27.sql). **Do not rerun it**: the migrations already exist in the target project.

## Verified installed data

| Table/view | Rows | Purpose |
|---|---:|---|
| `airlinerra.runway_source_versions` | 18 | Links every published runway pair to its independent airport evidence record/source/effective date |
| `airlinerra.runway_physical_facts` | 18 | Meter length, width and specific material classification for 14 distinct airport keys |
| `airlinerra.runway_direction_facts` | 10 | Only source-established TORA/TODA/ASDA/LDA and two Le Bourget direction-specific prohibitions |
| `airlinerra.runway_permission_facts` | 72 | Four separate types per source version: scheduled passenger, charter, cargo, civil general; no automatic carrier approval |
| `airlinerra.runway_research_facts` | 18 | Private research read-only joined view, **not a game eligibility view** |

Multiple runway pairs intentionally exist for **Le Bourget (3)**, **Melun (2)** and **Saint-Yan (2)**, preventing the old single-longest-runway import bug.

**Material gate:** only the three official bituminous-concrete Le Bourget runways and Villacoublay's explicitly bituminous runway are `VERIFIED` in **these source-specific new rows**. This does **not** erase separate existing older airport-level pavement reviews; e.g. Saint-Nazaire historically has additional material evidence but the exact subtype of the October register-only source is `UNVERIFIED` here. All unspecified `revêtue` and `macadam` sources remain `UNVERIFIED` (not rejected), including the exact-length 1,200 m second paved runway at Saint-Yan.

**Runway directions:** Le Bourget RW07/25 has distinct published TORA/TODA/ASDA/LDA; RW09 `landing_status='PROHIBITED'` and RW27 `takeoff_status='PROHIBITED'`. Both scheduled and charter passenger operations are separately `PROHIBITED` on all three Le Bourget runway source records. Lannion has only independently known LDA 1,376/1,463m, its TORA remains **NULL**. Melun RW28 is physical **1,972m**, TODA **2,650m** with **678m clearway**, LDA **1,890m**. Unknown operating distances throughout the layer remain NULL rather than being copied from physical length. LFMO Orange remains macadam-unverified with military public-use restrictions.

## Results of live tests

[Runway facts regression SQL](FRANCE_RUNWAY_FACTS_VALIDATION_2026-10-27.sql) was executed in the private project. **All 16 Boolean assertions returned TRUE**, including 14 airport coverage, 18 records, airport-specific physical lengths, Le Bourget's restrictions, Lannion/Orange/Melun distinctions, Creil's exclusion, private view grants and **3,140 preserved World 1 approved keys**. Supporting consistency queries returned **zero** mismatched airport-evidence identities, illegal verified material classifications, LDA longer than physical runway and TODA shorter than TORA.

Supabase security check: `anon` and `authenticated` have **no USAGE** on schema `airlinerra`, and no SELECT on new tables or view. All four tables have RLS enabled with **no policies deliberately** (denies client access), and the view is `security_invoker=true`. Security advisor reports this pattern as informational `rls_enabled_no_policy`, not an exposure. [Supabase RLS guidance](https://supabase.com/docs/guides/database/postgres/row-level-security). The performance advisor returned no **new** unindexed foreign-key finding for these tables; unrelated older database findings remain.

## Unchanged protective boundaries

- Original `airlinerra.airport_registry` remains **8,153** rows, including immutable historical imported physical lengths.
- `airlinerra_game.approved_game_airports` has exactly **3,140** World 1 keys and no newly approved French airport.
- `airlinerra.airport_world_activation` still has **3,140 active World 1 rows**.
- Closed Creil LFPC remains absent from approved World 1 and from the derived research pilot dataset.
- No public site release, migration of user/airline accounts, Netlify deployment, Supabase Auth changes or change to game flight scheduling.
- No six-tier category assignments were made: categories remain exactly **Local, Regional, Medium, Large, Major Hub, Mega Hub**.

## Engineering handoff — deliberately not implemented

Before consuming research facts in game simulation: introduce a separate permissioned, read-only *published gameplay runway release* review, verify all current effective full AD2 declared distances and material gate, model dated NOTAM/PPR and carrier-specific permissions, test aircraft-performance profiles, and explicitly authorize airport/world-specific promotion. A versioned research source record must **never** itself flip a game admission or scheduling switch.

The [14 corrections register](FRANCE_RUNWAY_CORRECTION_PROPOSALS_2026-10-27.json) remains **source-validated but not applied to original imports**. The future architecture sketch is [here](FRANCE_DERIVED_RUNWAY_FACTS_DESIGN_2026-10-27.md).
