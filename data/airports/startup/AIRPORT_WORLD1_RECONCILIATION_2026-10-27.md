> **SUPERSEDED SNAPSHOT:** This earlier 8,148-airport count is outdated following additional independent runway inspections. See [CURRENT_WORLD1_AIRPORT_CATALOG.md](CURRENT_WORLD1_AIRPORT_CATALOG.md) for 8,139 accepted and 14 rejected.

# Airlinerra World 1 airport reconciliation — 27 October 2026

## Final simulation-catalog counts

- Research candidates: **8,153**
- Original World 1 cohort retained unchanged: **3,140**
- Newly accepted after screening: **5,008**
  - **2,392** satisfy the owner's automatic rule of a source-reported four-letter ICAO designation and a historical asphalt/concrete or PEM runway **longer than 1,200 m**.
  - **2,616** were screened through existing historic runway and identity/source records. These rely on the owner's express historical-evidence acceptance policy and are **not individually verified as currently operational**.
- Definite exclusions: **5** (Creil Air Base, Hagler Army Heliport, Pollock Municipal Airport, Rosaschi Air Park, Searchlight Airport).
- Active/approved in World 1: **8,148**. Rejected airports active: **0**.
- The fictional **Aleksandrovo Airport** is preserved as a clearly fictional simulation facility.

## Files

- [All 8,148 accepted airports](airlinerra_world1_accepted_8148_2026-10-27.csv)
- [5 definite rejections and reasons](airlinerra_airports_rejected_5_2026-10-27.csv)
- [524 high-priority quality-flagged airports from the historical-review subgroup](airlinerra_historical_high_priority_review_524_2026-10-27.csv)

## Database verification

Source of truth: Airlinerra Supabase project `hwllkabgzaynalahvkpz`.

- Decisions: `airlinerra.airport_world1_review_20261027` — 8,153 rows
- Existing screening flags: `airlinerra.airport_quality_audit_flags`
- Game activation: `airlinerra.airport_world_activation` — 8,148 active in World 1
- Approved game airport list: `airlinerra_game.approved_game_airports` — 8,148 in World 1

## Boundaries and follow-up

1. **A source-reported ICAO entry is not an independently authenticated ICAO assignment.** The automatic-safe group follows the owner's requested dataset rule, not current commercial-aviation certification.
2. **Historical runway acceptance is not current commercial-airline permission**. A historical paved runway can coexist with military/private-use limitations, temporary closure, unusable declared distances, or an inactive facility. Those conditions are recorded as separate flags.
3. **524 airports in the historical-review subgroup have HIGH quality flags** requiring additional independent scrutiny before unrestricted commercial scheduling; the quality-review list deliberately avoids conflating these flags with definite rejection.
4. All six airport categories are **provisional**. Some historical-review records were initially defaulted to Local. Runway length alone does not establish traffic volume or hub category.
5. The original 3,140 cohort was not reclassified or modified.
6. Hagler Army Heliport was additionally removed from World 1 because FAA-sourced remarks explicitly prohibit fixed-wing use. The other four rejected entries have documented closure or failed qualifying-runway findings.

Reviewed for Airlinerra simulation game catalog only, **not for real-world flight planning**.
