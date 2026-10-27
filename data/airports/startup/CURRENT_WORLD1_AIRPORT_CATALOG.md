# Airlinerra — Current World 1 airport catalog (27 October 2026)

**Current database-verified catalog.** Supersedes previous 8,148- and 8,139-airport snapshots.

## Live database reconciliation

| Acceptance basis | Airports |
|---|---:|
| Original simulation cohort retained unchanged | 3,140 |
| Source-reported ICAO + paved runway >1,200 m | 2,391 |
| Historical paved-runway/identifier admission | 2,605 |
| **Active and approved for World 1 simulation** | **8,136** |
| **Rejected and inactive** | **17** |
| Registered original candidates | 8,153 |

## Current lists

- [World 1 accepted airports — 8,136](airlinerra_world1_accepted_8136_2026-10-27.csv)
- [Definitively rejected — 17](airlinerra_world1_rejected_17_2026-10-27.csv)
- [Independent source reviews — 21 cases, including 12 failed and nine runway passes](airlinerra_independent_runway_checks_21_2026-10-27.csv)
- [870 current high-priority flagged accepted airports](airlinerra_high_priority_870_2026-10-27.csv)

## Latest inspection findings

- Grand Geneva Resort Airport C02: FAA-derived 2026 status **closed indefinitely** despite historical asphalt length.
- Upperville Airport 2VG2: reported closed since 2023 despite historical 5,100 ft asphalt runway.
- Hiroshima Heliport RJBH: **present heliport only has a 35 x 30 m surface**, confirmed by Hiroshima City. Historic 1,800 m fixed-wing runway record was incorrectly carried forward from the former Hiroshima West Airport.
- Sabre Army Airfield KEOD: FAA 2026 verifies 5,000 ft (1,524 m) concrete fixed-wing runway with 24h military prior-permission restriction; the game-display name is corrected from `Sabre Army Heliport` to `Sabre Army Airfield (Fort Campbell)`.
- Custer State Park Airport 3V0: historical 4,000 ft asphalt runway confirmed from FAA-derived records, but not independently proven current in Oct 2026.
- Bartow Executive KBOW and Palacios Municipal KPSX: each has a separate qualifying 1,524 m paved runway despite other poor-condition surfaces. Both retained in catalog with alternate-runway-condition warnings.

## Verification boundaries

- Source-reported `ICAO` codes are not independently verified on every row. Do not conflate local IDs and official ICAO indicators.
- Historical runway observations are accepted for **simulation-only** under owner-approved policy, not as current aircraft operating authorization.
- 870 admitted non-foundation airports retain HIGH quality flags: 526 in historical-review subgroup, 344 in ICAO-rule subgroup. Some independently checked runway passes may still have operational or commercial permission restrictions.
- Airport six-category assignments remain provisional: Local, Regional, Medium, Large, Major Hub, Mega Hub.
- All original 3,140 founding airports have been preserved.
- Source of truth: Supabase Airlinerra project `hwllkabgzaynalahvkpz`, tables `airlinerra.airport_world1_review_20261027`, `airlinerra.airport_world_activation`, `airlinerra_game.approved_game_airports`, and `airlinerra.airport_independent_runway_checks_20261027`.

**Not usable as a real-world flight-planning source.**
