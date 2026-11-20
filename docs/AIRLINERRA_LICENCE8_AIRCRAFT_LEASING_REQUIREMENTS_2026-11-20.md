# Airlinerra Licence 8 — Aircraft Leasing Company Approval
**Status: Licence-policy foundation only; release-locked and NOT a working leasing marketplace. 2026-11-20.**

## Approved direction
Licence 8 is for a **dedicated aircraft_leasing subsidiary** owned by a holding. It enables future aircraft ownership and **dry leasing** to airlines within the same holding and to other players' airlines with one company licence. **Wet leasing / ACMI is NOT authorized by Licence 8:** it involves an appropriately licensed operating airline, operational control and separately applicable permissions. Licence 8 does not grant an AOC, route rights, crew supply or aircraft dispatch rights.

## Proposed/accepted game-policy terms
| Topic | Game rule |
| --- | --- |
| Eligible company | Registered `aircraft_leasing` subsidiary of an eligible holding |
| Minimum subsidiary age | **0** game days beyond existing holding prerequisites |
| Application charge | **Free** |
| Initial approval fee | **$100,000** once on successful issuance (not application) |
| Processing time | **7 verified game days**, full re-check on approval |
| Validity | Continuing, conditional on compliance |
| Inspection | Every **365 verified game days** |
| Standard renewal fee | None |
| Customers | Own holding's airlines and other players under same Licence 8 |
| Listings | Optional public leasing directory, **off by default** |
| Price control | Lessor defines terms/prices for each eligible aircraft |
| Asset minimum, capital, staffing | **To be designed later**; not invented in this licence-only phase |

The owner accepted implementation of the Licence 8 proposal (including the suggested $100,000 and seven-day terms). Do not automatically make licensing available to players without remaining verified operational prerequisites.

## Leasing model and company scope
- **Dry lease**: the lessor retains asset ownership; lessee airline receives exclusive contractual operating use during the lease, subject to their existing AOC, permitted routes and aviation/insurance requirements.
- Own-group transfers and external leasing may both operate under the same company Licence 8. A subsidiary may operate privately and never publish offers.
- **Wet lease / ACMI** is an airline operation with crew, maintenance and insurance supplied by an operator; not part of the non-operating Licence 8 grant, and must be independently designed under AOC/operator/country/flight permissions if introduced.
- Licence approval by itself does not purchase, register, deliver, dispatch, reposition or make any aircraft airworthy.
- Aircraft ownership, leasehold operational control and financial liabilities must be tracked separately. Aircraft may not be simultaneously leased to more than one lessee or used by a lessor's other airline during an exclusive dry lease.
- Do not duplicate an aircraft when moving between lessor ownership, an airline's operating control or lease expiration. Repossession/return requires verified condition, location, notices and contractual rules.

## Leasing offers and contracts (future design; not live)
- **Publish Aircraft for Lease** is OFF by default; player explicitly selects individually eligible aircraft to list and sets a quoted monthly price and lease duration. Private related-party leases do not require public visibility.
- Later determine deposits, monthly payments, currency, maintenance/insurance obligations, configuration, minimum/maximum term, early termination, late payment, damage, condition, delivery/return, extension and repossession.
- Accepted lease prices and terms are immutable without agreement; editing or hiding a listing must not silently change an accepted contract.
- Offers require ownership verification, no conflicting lease, aircraft condition/location and regulatory/operator eligibility checks before actual lease execution.
- Lease ledger and treasury must distinguish lessor revenue, asset ownership, lessee expense, collateral and contracts. Do not debit live players before these mechanisms exist.

## Lifecycle
- Free application, full eligibility assessment, then **7 verified game days** before review; successful review charges **$100,000 once atomically with licence issuance** to an actual independently auditable lessor ledger. No company-age waiting requirement.
- Each 365 game days, inspect for valid company ownership, compliance, asset/contract custody and financial obligations. Successful annual inspection continues the same licence for no recurring fee.
- Temporary suspension: stop **new lease offers/acceptance** for material compliance, asset ownership or contract administration failures. Existing contracts remain legally/auditably recorded and cannot be silently deleted.
- Serious deliberate fraud, duplicate leasing, asset misrepresentation and major repeated breaches may lead to documented review and revocation, with notices/appeal rules to define later.
- A revoked company cannot accept new leases. Existing asset and customer obligations must follow controlled transfer, continuation or settlement rules; exact deadlines/grace periods are future decisions.
- Reinstatement after correctable suspension requires verification, not another $100,000 initial approval charge. After final revocation, new company approval may require new application and initial fee.

## Phase 1 foundation and release boundaries
- Add `aircraft_leasing` to the **planning-only** subsidiary kind constraint; do not open company formation.
- Add one reference-only `AIRCRAFT_LEASING` permission catalogue entry with $100,000, seven days, enabled_in_game=false.
- Create private, RLS-protected licence release/config, application, approval/status, and future aircraft offer-draft records.
- Enforce **hard false** release flags for formation, submission, issuance, fee collection and marketplace, including lease execution. Draft offers are unlisted and cannot accept bookings.
- Trusted application/review stubs return NOT_RELEASED, make no changes and charge nothing. Readiness must fail while aircraft title, leasing ledger, insurance and lease exclusivity checks do not exist.
- The finance/lease engine, aircraft buy/sell inventory, price-and-availability UI, third-party marketplace, wet-lease operational integration and staff/infrastructure are **later projects, explicitly outside the current licence-only work**.
- Before live cutover, design asset ownership and company finance, verified game-day reviewer and atomic fee, strict lessor/lessee authorization, ownership-transfer and single-active-lease constraints, condition/insurance safeguards, and operational restrictions.

**Do not call Licence 8 completed/live merely because Phase 1 schema and planner exist.**
