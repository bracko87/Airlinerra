# Airlinerra — Licence 6: Maintenance Organization Approval (MRO)
**Status: DESIGN SPECIFICATION ONLY — NOT ISSUED / NOT RELEASED**
**2026-11-20 — Reuses Licence 6 after Fifth Freedom was merged into Licence 2.**

## Product decision
One player-facing **Licence 6 — Maintenance Organization Approval** for the same business function worldwide. EASA Part-145, FAA Part 145 and other national approvals are regulatory contexts/checks under this one Airlinerra licence, **not separately purchasable licence numbers**. This is a fictional game certification, not a legal authorisation.

The licence belongs to a **registered `maintenance_mro` operating subsidiary**, not the airline, holding, owner or an airport. No aircraft or airline AOC is required merely to own an MRO company. A maintenance company may service its holding's fleet or, in a future update, other players' fleets — only when the particular facility and maintenance work are approved. Never let the licence substitute for maintenance-job capability.

## Commercial policy (proposed for game balancing; not regulatory facts)
| Parameter | Design rule |
| --- | --- |
| Application charge | $0 |
| Initial approval fee | $200,000, charged once only after all checks pass at issuance |
| Processing | 10 verified **game days** from submission, with full recheck at review |
| Minimum company age | 30 verified **game days**, beginning at actual subsidiary registration |
| Initial facility requirement | 1 approved location with at least one suitable operational line-maintenance bay/workshop |
| Initial scope | Line maintenance: daily, weekly and A checks, for declared aircraft family/type scope only |
| Validity | Indefinite while compliant, no automatic annual renewal fee |
| Inspection | Every 365 game days |
| Scope upgrade | Additional facility/tooling/staff/capability verification; no duplicate base licence fee |
| Aircraft ownership | Not required |
| Licence ownership | Individual MRO operating company, not transferable automatically |
| Suspension | Specific maintenance types/jobs stop where staffing, facilities, tooling, quality, safety, insurance or authority requirements lapse; company-wide suspension for systemic failure |
| Revocation | Serious/fraudulent/repeated safety breaches, loss of legal operating company or prolonged unresolved complete inactivity, with due-process game decision and recorded reason. No automatic revocation merely from a temporary scheduled repair |
| Reinstatement | Correct temporary problems + pass reinspection; only revoked companies must apply again and pay the full fee |

### Financial readiness: separate the $200k licence fee from business costs
At the time of issuance, require (a) the fully paid/owned or active leased qualifying facility, (b) purchased or active rented approved tooling, (c) paid/contracted minimum staff, (d) **90 game days of verified projected MRO operating reserves**, and (e) sufficient remaining cash to pay the $200,000 licence fee *in addition to* the reserve. A balance field alone is not proof of reserve: use an audited projected-cost and payroll estimate. Hangar construction costs, tool prices, salaries, lease costs and inspections must later come from the facility/economy systems; do **not** hard-code arbitrary purchase amounts in the licence.

## Facility/capability design for future implementation (NOT BUILT)
- **Line-maintenance workshop / bay**: one assigned airport, 1 concurrent aircraft job slot by default; apron/approved line area possible; daily, weekly and A checks only within the facility's and staff's rated scope.
- **Medium hangar**: separate future upgrade; capable of B checks only for compatible aircraft size/models once staffing, equipment, footprint and bay capacity are verified.
- **Heavy maintenance hangar**: future upgrade for C checks, aircraft-type/capacity scoped; requires heavy-maintenance certification and qualified staff.
- **Heavy overhaul complex**: future upgrade for D checks, model-specific expertise, overhaul equipment and stronger facility controls.
- Building a hangar does **not** grant a check category automatically. Facility physical size, airport land/right-to-operate, ground access, utilities, fire/environment safety, permitted noise/curfew, capacity/bays, tools, qualified staff, technical documentation and inspection all matter.
- The existing Airlinerra A=6h, B=1 game day, C=1 week, D=3 weeks timing policy remains authoritative. Existing airport third-party maintenance options must remain available to airline owners who do not create an MRO subsidiary.
- No automatic global MRO network: each location must be recorded, activated, checked and inspected. New branches are location approvals under Licence 6, not new licence numbers.
- Different aircraft models/families require declared approved technical scope, such as Airbus A320 family vs Boeing 737 family; no unrestricted all-aircraft approval.

## Minimum initial staffing to obtain line-maintenance approval (game design baseline)
- 1 accountable MRO/maintenance manager;
- 1 independent quality-and-safety responsible person (may not sign off their own audits);
- 1 certifying maintenance engineer authorised for the selected aircraft family;
- 2 maintenance technicians authorised to work under the company's procedures;
- Staff are assigned to the MRO company and one maintenance base, have relevant training/competence, schedules and payroll. Role counts above are **game balancing defaults, not regulatory minimum headcounts**. A future staffing capacity engine must determine how many concurrent jobs and shifts are possible. Extra shifts/bays require staff.

## Tools, evidence, operating reserves (future systems)
- Basic line-maintenance tool and ground-service kit, calibrated inspection instruments, PPE and safety equipment, suitable aircraft stands and parts storage.
- Access to approved aircraft manuals and maintenance records; spare parts and consumables available per task; safety and quality manuals; maintenance release-to-service authority.
- Approved facility location and lease/ownership record; required airport/operator permissions; maintenance inspection certificate; approval of actual aircraft family and check types.
- Insurance/compliance provisions with realistic recurring operating costs; payroll and parts costs are separate expenses, not included in the licence fee.

## Process — no live issuance until supporting systems exist
1. Player has an eligible holding and establishes a **registered `maintenance_mro`** subsidiary.
2. Player selects airport / country and obtains eligible site rights. Facility/bay and ownership/lease confirmed.
3. Player assigns a qualified manager, independent quality officer, certifying engineer and technicians.
4. Player acquires tools, verifies maintenance manuals, parts handling, quality and safety.
5. Player selects precise check types and aircraft-family ratings; verifies 90-game-day reserve and $200k issuance funds.
6. Free application submitted; after 10 verified game days, company, location, staff, scope, reserves and game authority rechecked.
7. If eligible, an **atomic, exactly-once $200k company ledger charge** and company-specific licence record are created; otherwise no fee and application remains blocked/rejected per reviewed policy.
8. Annually schedule a game inspection. Individually gate EVERY maintenance booking by company licence, facility availability/size, qualified staff, parts, tooling, aircraft family, permitted check type and job capacity.
9. Maintenance requests for other players require a later MRO marketplace, price quote, scheduled slot, payment and signed maintenance completion. Not part of Licence 6 issuance work.

## Acceptance criteria / infrastructure backlog
- [ ] MRO company registration and financial ledger.
- [ ] Airport site leasing/ownership, physical hangars and line bays, upgrades and capacity.
- [ ] MRO staff roles, qualifications, aircraft type ratings, scheduling and payroll.
- [ ] Tools/equipment calibration, maintenance manuals, spare parts store and insurance.
- [ ] Explicit per-facility and per-aircraft-family check ratings (daily/weekly/A/B/C/D).
- [ ] Inspections, safety findings, licence and capability suspensions, renewals/reinstatements.
- [ ] 90-day audited reserve readiness and company cash/ledger checks.
- [ ] Atomic reviewed 10-game-day licence issuance, idempotent $200k fee, release locks and tests.
- [ ] Integrate with existing aircraft maintenance booking / grounding / completion engine without bypassing third-party maintenance.
- [ ] Separate MRO marketplace for other player airlines in a later development phase.

## Existing Airlinerra components to reuse
- `holding_subsidiaries_v1.company_kind='maintenance_mro'` exists, though live subsidiary formation is presently locked.
- Existing `maintenance_check_policy_v1`, `aircraft_maintenance_completions_v1`, `maintenance_airport_capabilities_v1` and `maintenance_facility_locations_v1` describe maintenance work or airport/provider capabilities but **do not establish a player-owned certified MRO facility**.
- No real Licence 6 issuance or infrastructure activation is authorised by this specification.
- Retirement of the old stand-alone Fifth Freedom Licence 6 is unrelated to this new MRO licence.

## Regulatory context (NOT identical to game numbers)
Real aircraft maintenance approvals may require facilities, personnel, equipment, technical information, organisational manuals and explicitly scoped ratings. The model should reflect those principles without claiming to issue EASA or FAA certificates.
- EASA Part-145: https://www.easa.europa.eu/en/document-library/easy-access-rules/online-publications/easy-access-rules-continuing-airworthiness
- FAA 14 CFR Part 145: https://www.govinfo.gov/content/pkg/CFR-2026-title14-vol3/xhtml/CFR-2026-title14-vol3-chapI-subchapH.html
