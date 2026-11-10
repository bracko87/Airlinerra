# Airlinerra — Group 2 airport research and controlled admission plan

**Date:** 10 November 2026 · **Scope:** owner-pre-approved Group 2 airport cohort, 1,118 airports. This is an *airport* project; crew, airline licences, game-clock processing and financial settlement are not part of these airport-data research steps.

## Executive position

**Group 1:** 3,141 airports, previously completed for simulation game data; do not reset or rebuild.

**Group 2:** 1,118 pre-approved owner-selected airports and Sections 1–8 *estimated game models* have already been imported (PR #50). They are not in the authoritative Group 1 World 1 operating roster. Owner `PRE_APPROVED` means permission to **prepare game data**, not a finding of real civil-commercial rights or permission to launch flights.

**This PR adds live verification infrastructure, not aviation authorizations.** All Group 2 airports remain non-playable. World 1 remains planned.

## Four-stage work plan

### Stage 1 — Reconcile and reuse existing research (done)

Reuse `airlinerra.airport_access_reviews`, `airlinerra.airport_commercial_verification`, `airlinerra.airport_expansion_phase5_gate_reviews` and the already imported 1,828 source-runway observations. Preserve evidence provenance; don't treat a technical shortlist as proof of operating rights.

Existing data has **926 access-review records**, **510 FAA commercial-verification records**, **192 airports lacking an access review**, and **zero confirmed commercial game admissions**. All **1,118** original final-selection decisions say `ACCEPT` for the simulation *catalog shortlist*, but their notes explicitly do **not** grant current aviation commercial permission.

Two Austrian military airbases are explicitly marked as commercial-airline prohibited in the existing AIP-derived access reviews:
- `OURAIRPORTS:29484` — Brumowski Air Base
- `OURAIRPORTS:4436` — Hinterstoisser Air Base

They are automatically held, regardless of other evidence, until an independently sourced correction to the earlier restriction is reviewed.

### Stage 2 — Review queue, 50-airport batches (implemented)

**Database:** `airlinerra_game.airport_group2_source_research_queue_v1` and `airport_group2_research_batches_v1`.

Every airport has a stable priority, next-action text and a numbered batch. The worklist has **23 batches**, maximum **50 airports** per batch.

| Exclusive priority group | Airports | Next work |
|---|---:|---|
| 0: Existing documented prohibition | **2** | Recheck current AIP/operator restriction; **do not release** |
| 1: Physical runway data gaps | **20** | Obtain current runway dimension/designator/declared distance and aircraft suitability |
| 2: Missing access reviews | **183** | Independently confirm civil use, airport/operator ownership and commercial service eligibility |
| 3: FAA source records available | **510** | Use pinned FAA material and operator sources to verify carrier/charter/cargo permissions, infrastructure and restrictions |
| 4: Other airport/operator research | **403** | Independent current runway, operating access, curfew and capacity review |
| **Total** | **1,118** | |

These are *exclusive work priorities*. The 192 total airports without an access-review record are spread between priority 1 and 2. The 20 runway-width game estimates and nine missing source runway observation cases overlap, and are not falsely counted as 29 separate airports.

**Initial Batch 1**: 2 prohibitions, 20 physical-data priorities, 28 missing-access reviews; 50 airports across 24 country codes. Batch 2–4 continue missing-access review, and Batch 5 begins the FAA evidence cases.

### Stage 3 — Independent evidence gates and controlled admission preflight (implemented)

**Database:** `airport_group2_required_reviews_v1`, `airport_group2_review_evidence_events_v1`, `airport_group2_evidence_latest_v1`, `airport_group2_admission_readiness_v1`, and the private function `group2_verify_candidate_admission_v1(airport_key)`.

Each airport requires five common independent reviews:
1. Identity and correct location
2. Current usable paved runway (not merely a historical length)
3. Actual civilian airport access
4. Aircraft compatibility and ground/terminal facilities
5. Operating restrictions, curfews and current access limitations

Then **each intended service** requires its own commercial permission check: passenger and/or cargo. Consequently there are **6,830 gate checks** for 1,118 airports (five common checks × 1,118, plus 1,075 passenger and 165 cargo checks). A passenger-and-cargo airport has seven checks; a single-service airport has six.

The existing preapproval or old FAA/public-use flag is **never** automatically converted to a positive independent review. Real review results can only be recorded as private append-only `verified`, `rejected`, or `withdrawn` events, with source URL, effective date, reviewed date, accountable reviewer, and review notes. Earlier events are retained; the most recent verdict controls readiness. A new rejection/withdrawal revokes any older positive evidence. Browser roles cannot read or write the private evidence ledger.

Readiness states:
- `HARD_HOLD_DOCUMENTED_PROHIBITION`
- `HOLD_REJECTED_EVIDENCE`
- `EVIDENCE_INCOMPLETE_NOT_PLAYABLE`
- `READY_FOR_SEPARATE_OWNER_RELEASE_REVIEW`

**Even all six/seven verified gates do not admit an airport.** The preflight always returns `canJoinWorld1=false` and `canActivateFlights=false`. The separate owner admission decision and release-engine integration belong to Stage 4.

### Stage 4 — Controlled commercial game admission and engine integration (NOT YET DONE)

Only after individual airport review is complete:
1. Record an independently reviewed owner-specific game admission decision, preserving source references, decision date and traffic-service scope.
2. Confirm that an airport is not actually prohibited or unusable and only the intended type of passenger/cargo services is admitted. AIP, FAA, runway and aviation operator data are evidence, not legal certificates issued by the game.
3. In a separate controlled migration, add specifically admitted airports to the authoritative World 1 roster (or a separately approved game world as explicitly chosen) **with safe route, slot, aircraft/runway, demand and fee engine integration**. Do not bulk-promote the 1,118 just because they are pre-approved game-data records.
4. Verify no duplicate official/game lookup codes, invalid aircraft placements, unexpected full-route activation or mismatched capacities; run regression and concurrent slot tests.
5. Release only after production-like quality and owner acceptance; keep the world planned and launch gates closed until the wider airline engines are ready.

No airport admission, flight activation, tickets or airline account writes are performed by Stages 1–3.

## Test evidence

Live Supabase migration was first executed in a full `BEGIN/ROLLBACK` dry run, then applied. Post-install independent SQL acceptance was also rolled back and passed.

`tests/sql/group2_independent_admission_gate_acceptance.sql` validates:
- 1,118 source cases, 6,830 independent service-specific gate requirements, 23 batches of at most 50
- all 510 FAA and 192 missing-access records remain correctly classified
- both documented prohibitions remain hard blocked
- nothing becomes live or financially active
- fake positive evidence **inside rollback only** can reach *separate owner release review* but **never World 1 or flight authority**
- even fully positively reviewed prohibited airbases remain blocked
- passenger+ cargo airports require separate service rights
- evidence is immutable and a newer withdrawal cancels earlier approval
- no player/broker privileges to write, no changes to Group 1 or airline money

## Immediate next research batch

**Batch 1: 50 airports.** Prioritize the two Austrian AIP prohibitions, followed by the 20 missing or incomplete detailed runway-width cases, then the 28 missing-access files. Collect current operator/AIP/FAA evidence with exact physical airport identity; pay special attention to military-only fields, private fields, PPR restrictions and aircraft mass/declared-distance limitations. Existing source observations may prove a historical runway but not its current use or a commercial-airline permit.

No missing source fact should be filled with an invented 'verified' value. Verified findings are separate append-only events with independent source and reviewer, and do not automatically enable a destination.

**Group 1 remains closed for game-data scope, unchanged at 3,141. Group 2 remains prepared but not admitted.**
