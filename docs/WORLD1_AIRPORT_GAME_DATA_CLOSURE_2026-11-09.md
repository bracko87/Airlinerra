# Airlinerra World 1 — Airport game data closure and remaining owner decisions
**Date:** 9 November 2026
**World:** 1 · 3,141 approved airports

## Why this closure was necessary
Previous status reports mixed three independent milestones: GAME data completeness, independent factual/source verification, and actual flight-operation readiness. This led to reopening finished game data. This migration separates them formally.

The original `airport_data_master_categories` statuses now read:
- **1 Identity & Geography: `game_complete_estimated`**
- **2 Airport Classification: `game_complete_estimated`**
- **3 Runways: `game_complete_estimated`**
- **4 Terminals & Facilities: `game_complete_estimated` (unchanged since 7 Nov)**
- **5 Airport Operations & Weather: `game_complete_estimated`** for simplified game rules/data, not actual weather/airline safety dispatch
- **6 Capacity & Slots: `game_complete_estimated`** for airport game models and transactional DRAFT slot reservations
- **7 Passenger & Cargo Traffic: `game_complete_estimated`** for game baseline demand, seasonality and market priority
- **8 Airport Economics: `partially_populated`** pending owner approval of the game fee balance (all 3,141 game prices are populated)
- **9 Demand & Flight Operations: `partially_populated`** (real commercial activation/bookings/settlement not complete)
- **10 Evidence & Validation: `partially_populated`** (real-world source research and final release validation remain)

These statuses are **not** a certification of real-world airport data, regulatory flight permission or a game-launch approval. None of the independent source-verification flags, owner final category approvals, source conflict queues, aircraft facts, airport numerical data, operating restrictions, licence policies, game clock, accounts, aircraft movements or commercial schedules were changed.

## How Sections 1–7 passed

| Section | Current acceptance | Limits intentionally kept |
|---|---|---|
| 1 Identity | 3,141 game names, municipalities, display codes, country, IANA timezone and game elevation; real airports have coordinates; zero unresolved game code research | Many official names/municipalities and published codes remain source-unverified; 1 fictional airport |
| 2 Classification | All 3,141 assigned a valid one of six tiers; 0 open game consistency exceptions; owner category choices and 96 case decisions kept; fee categories match | 0 individual final *factual* category approvals — not fabricated |
| 3 Runways | 4,022 existing physical dimensions with positive length/width across 3,140 real airports; Aleksandrovo fictional 2,200 m design stored in dedicated game table | 4,013 runway operational statuses remain unknown; source geometry material/identity and reported closures require research |
| 4 Facilities | Existing 3,141 game-facility complete profiles, Section 4 acceptance rerun passed | Facilities include category estimates rather than measured gates |
| 5 Night/noise | 3,141 simplified Yes/No game records, 0 unchecked defaults, 2,993 AirlineSim pages checked, 2 user screenshots, 146 not found explicitly retained; game noise Chapter populated for 271 aircraft | 218 aircraft chapter assignments game-estimated; official curfew/noise exceptions and live NOTAM/weather still distinct |
| 6 Capacity/slots | 3,141 nonnegative game airport stand/slot models; full transactional draft scheduling and curfew integration regression rerun PASSED | No live operating slot reservations; no published airport coordinators' slot data inferred |
| 7 Traffic | 3,141 complete passenger/cargo daily baseline pools, 3,141 month season profiles, 3,141 origin-priority allocations without top-destination mismatches | Simulated market potential is not revenue, bookings or actual passengers |

## Section 8 — actual airport game pricing to approve

Current database price ranges in **USD**, game rates (not official aviation tariffs):

| Tier | Airports | Landing fee range | Daily parking range | Fee per departing passenger |
|---|---:|---:|---:|---:|
| Local | 104 | $82–200 | $33–103 | $2–5 |
| Regional | 102 | $188–450 | $74–212 | $4–8 |
| Medium | 1,778 | $400–6,000 | $150–2,500 | $6–35 |
| Large | 887 | $489–5,965 | $185–2,464 | $7–34 |
| Major Hub | 229 | $1,103–6,000 | $429–2,500 | $11–35 |
| Mega Hub | 41 | $1,582–6,000 | $629–2,500 | $15–35 |

Every airport has complete, nonnegative fees and matching latest category. No airport price was changed. **The high upper values are present in some Medium/Large rows**, so balance should be considered globally and tested before treating the whole economy as final.

**Owner decision requested:** Approve the existing rates *as a preliminary Airlinerra game-price baseline* (future balancing allowed), or request adjustments before closing Section 8. No official-source airport tariff endorsement is requested.

## Section 9 — preserve existing licence planner, fix execution mismatch

The current player-visible planning rules (proposals, not charged) specify:

- Original airline AOC: included with original airline activation; subsidiary AOC: proposed **$150,000**, **7 game days**; at least one suitable delivered/inspected aircraft and qualified crew required for approval.
- Domestic traffic and integrated-market rights: **free when eligible**, immediate after verification.
- Ordinary international third/fourth freedom: **free when already covered by verified market access**, otherwise needs specific approval.
- Fifth freedom: proposed **$100,000–250,000**, **7 days**, only when the exact multi-country market allows it.
- Seventh freedom: proposed **$200,000**, **10 days**, only for verified eligible routes.
- Foreign cabotage: proposed **$250,000**, **10 days**, only where an actual market allows it; never purchasable merely by paying money.

**Technical blocker (not an owner action):** Initial server issuance currently requires fees greater than $0 and processing days of at least 1, and the game policy catalogue cannot yet be enabled. The independent grant engine must be revised to safely support **free/instant verified entitlements** and the original airline AOC without fake charges. Fifth-freedom requires additional multi-leg route entitlement modelling. Preserve the planner and do not silently charge the user.

**Owner decision requested:** Confirm whether the existing licence planner pricing/time framework above should be treated as the initial gameplay configuration (subject to actual market eligibility). No need to re-decide every operational eligibility detail; those remain the already documented planning requirements.

## Evidence and operations remain separate

- `airlinerra_game.world1_game_data_section_acceptance_v1`: private, RLS-protected immutable completion **snapshot** by section; explicitly `source_verified_complete=false` and `live_operations_certified=false`.
- `airport_data_work_queue`, `airport_field_evidence`, source conflicts, individual runway operational status and category factual-approval flags remain intact.
- Section 9 still needs the real independent crew authority, approval engine, commercial flight activation, movement producer, actual bookings/cargo and financial settlement, connected signed game clock and 500-player end-to-end testing.
- Section 10 source and launch validation remains separate. The airport-register workflow has an unrelated failing CSV validation job; repair separately before publishing.
- World 1 stays planned; no commercial flights, new licences, money transfers or movements.

**Regression results:** The live rollback-only Section 6 draft slot + curfew integration test passed. Existing Section 4 game facility acceptance passed. The new Section 1–8 closure migration passed rollback-first and then installed. The new non-mutating regression acceptance passed against production after install. No invented aviation facts or player charges.
