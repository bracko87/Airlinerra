# Airlinerra — Licence 6: Maintenance Organization Approval (MRO)
**Status: DESIGN SPECIFICATION ONLY — NOT ISSUED / NOT RELEASED**
**2026-11-20 — Reuses Licence 6 after Fifth Freedom was merged into Licence 2.**

## Product decision
One player-facing **Licence 6 — Maintenance Organization Approval** for the same business function worldwide. EASA Part-145, FAA Part 145 and other national approvals are regulatory contexts/checks under this one Airlinerra licence, **not separately purchasable licence numbers**. This is a fictional game certification, not a legal authorisation.

The licence belongs to a **registered `maintenance_mro` operating subsidiary**, not the airline, holding, owner or an airport. No aircraft or airline AOC is required merely to own an MRO company. A licensed maintenance company can service both its holding's fleet and other players' fleets under the **same licence**, once booking and marketplace functionality exists. Publishing external offers is optional and off by default, and each maintenance task must be within the company's approved capabilities. Never let the licence substitute for maintenance-job capability.

## Commercial policy (proposed for game balancing; not regulatory facts)
| Parameter | Design rule |
| --- | --- |
| Application charge | $0 |
| Initial approval fee | $200,000, charged once only after all checks pass at issuance |
| Processing | 10 verified **game days** from submission, with full recheck at review |
| Minimum company age | **None**. Apply as soon as the maintenance subsidiary is registered and all required readiness criteria are satisfied; holding eligibility remains a separate prerequisite |
| Initial facility requirement | **To be defined in the future infrastructure-design phase**. Readiness must eventually verify suitable operational facilities for the declared scope |
| Initial scope | **To be defined** alongside facilities, personnel and approved aircraft/check capabilities |
| Validity | Indefinite while compliant, no automatic annual renewal fee |
| Inspection | Every 365 game days |
| Scope upgrade | Additional work-type, facility and aircraft-family capabilities under the **same** Licence 6; exact infrastructure and staff requirements to be agreed later; no second base licence |
| Aircraft ownership | Not required |
| Licence ownership | Individual MRO operating company, not transferable automatically |
| Suspension | Specific maintenance types/jobs stop where staffing, facilities, tooling, quality, safety, insurance or authority requirements lapse; company-wide suspension for systemic failure |
| Revocation | Serious/fraudulent/repeated safety breaches, loss of legal operating company or prolonged unresolved complete inactivity, with due-process game decision and recorded reason. No automatic revocation merely from a temporary scheduled repair |
| Reinstatement | Correct temporary problems + pass reinspection; only revoked companies must apply again and pay the full fee |

## Future infrastructure and staffing — requirements NOT decided
The specific building types, hangar sizes, construction costs, eligible checks, tools, staff job titles, minimum numbers, salaries, capacity, safety and quality standards, insurance and reserve calculation **remain to be defined with the user later**. Do not treat any earlier suggested staffing numbers, hangar tiers or 90-day reserve amount as approved Licence 6 requirements.

The company must ultimately demonstrate whatever facilities, capabilities, personnel and funds the later MRO infrastructure design requires; the present licence specification must not assume these systems already exist or allow operation without them. Existing Airlinerra aircraft maintenance jobs and airport-provider records are not a substitute for a player-owned MRO company.

The proposed **$200,000 licence approval fee** and **10 verified game days** processing are separate from the future costs of infrastructure, training, tools, salaries, spares and day-to-day operations. No live payment or licence issuance is enabled.

## Single Licence 6 for internal AND external maintenance
- A registered MRO operating subsidiary obtains **one company-specific Licence 6**.
- Under this same licence it can maintain aircraft owned by airlines in its holding and, **without buying any second external-service licence**, accept maintenance work from other players where available and qualified.
- Whether the company can perform a job depends on its approved locations, capabilities, equipment and staff, **not** whether the customer is internal or external.
- If the player does not wish to serve other players, they can keep their company entirely private. Internal services remain available after proper licence and job readiness checks.

## Optional public maintenance-service offers (future marketplace)
- Every MRO company has a **Publish maintenance services** on/off setting, **off by default**.
- Published MRO companies appear in a player-visible maintenance providers directory/search where other airlines can compare services.
- Each company selects **exactly which permitted maintenance services to advertise** and sets its **own price for each service** (e.g. a price for A checks on approved aircraft families, different prices for B or C checks if it is actually qualified).
- Each service offer is tied to an approved maintenance type, aircraft family/model rating and service location. Only genuinely supported and currently available capabilities may be listed.
- Price is a non-negative amount in game USD; the pricing model (flat job price, aircraft size multiplier, parts billed separately, fees/taxes) is deliberately **deferred until the maintenance economy is designed**. There is no automatic imposed price today.
- The company can hide individual services, edit future quotes, temporarily stop receiving new work or unpublish entirely **without losing Licence 6**.
- Existing accepted jobs and contractual prices must not be silently changed or cancelled merely by unpublishing or repricing; define cancellation, deposits, invoices and settlement when building the marketplace.
- External airlines will later be able to see price, approved types, work scope, location and earliest available appointment and request/book work. The MRO company receives the resulting revenue and pays its expenses through its own company ledger.
- This is a design requirement, **not an implemented marketplace or company UI**.

## Process — future implementation, no live issuance now
1. Holding owner establishes a registered `maintenance_mro` subsidiary. **No 30-day subsidiary-age or holding-age waiting requirement for this licence.** Existing prerequisites for establishing a holding are separate and unchanged.
2. The player develops the eventual facilities and staffing requirements (to be specified in a separate infrastructure design). The subsidiary can apply for Licence 6 **as soon as** it meets those requirements.
3. Submit the application free of charge; review and re-check readiness after **10 verified game days**.
4. If eligible, issue the single company Licence 6 and post a **single atomic $200,000 approval fee** to the maintenance company's account. Otherwise do not charge.
5. Internal maintenance can proceed only within approved job capabilities. External maintenance under the same licence becomes possible when the future marketplace is implemented.
6. The company optionally turns on **Publish maintenance services**, selects the approved services/aircraft families/locations to offer and sets a separate price for each service. Default listing visibility is private.
7. Every booking is separately checked for capacity, capability, safety and commercial validity. Repricing or unpublishing must not retroactively alter confirmed contracts.

## Acceptance criteria / infrastructure backlog
- [ ] MRO company registration and independent financial ledger; zero minimum MRO-company age.
- [ ] Define airport site leasing/ownership, physical facility tiers, work scopes, upgrades and capacity in a future design phase.
- [ ] Define MRO staff roles, headcounts, qualifications, scheduling and payroll in a future design phase.
- [ ] Tools/equipment calibration, maintenance manuals, spare parts store and insurance.
- [ ] Explicit per-facility and per-aircraft-family check ratings (daily/weekly/A/B/C/D).
- [ ] Inspections, safety findings, licence and capability suspensions, renewals/reinstatements.
- [ ] Define MRO operating reserve and company cash/ledger readiness in a future financial design phase.
- [ ] Atomic reviewed 10-game-day licence issuance, idempotent $200k fee, release locks and tests.
- [ ] Integrate with existing aircraft maintenance booking / grounding / completion engine without bypassing third-party maintenance.
- [ ] MRO public listing toggle (default private), per-service publish controls and player-defined per-service prices.
- [ ] Later external customer marketplace with availability, accepted bookings, contractual prices and invoices (no additional licence).

## Existing Airlinerra components to reuse
- `holding_subsidiaries_v1.company_kind='maintenance_mro'` exists, though live subsidiary formation is presently locked.
- Existing `maintenance_check_policy_v1`, `aircraft_maintenance_completions_v1`, `maintenance_airport_capabilities_v1` and `maintenance_facility_locations_v1` describe maintenance work or airport/provider capabilities but **do not establish a player-owned certified MRO facility**.
- No real Licence 6 issuance or infrastructure activation is authorised by this specification.
- Retirement of the old stand-alone Fifth Freedom Licence 6 is unrelated to this new MRO licence.

## Regulatory context (NOT identical to game numbers)
Real aircraft maintenance approvals may require facilities, personnel, equipment, technical information, organisational manuals and explicitly scoped ratings. The model should reflect those principles without claiming to issue EASA or FAA certificates.
- EASA Part-145: https://www.easa.europa.eu/en/document-library/easy-access-rules/online-publications/easy-access-rules-continuing-airworthiness
- FAA 14 CFR Part 145: https://www.govinfo.gov/content/pkg/CFR-2026-title14-vol3/xhtml/CFR-2026-title14-vol3-chapI-subchapH.html
