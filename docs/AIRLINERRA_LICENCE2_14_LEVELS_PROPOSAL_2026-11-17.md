**LATEST USER CORRECTION — 17 NOVEMBER 2026:** This document's Licence 2 interpretation is OBSOLETE. **Ordinary home-country ⇄ foreign-country return flights require only Licence 1 under the simplified game rule; Licence 2 is extra foreign NETWORK expansion, with quota counted by DIRECTIONAL ROUTE (not unique airports).** Example: Serbian airline Belgrade⇄London uses L1; Zagreb→Ljubljana and Ljubljana→Zagreb need two L2-EU slots; Zagreb⇄Hurghada uses two L2-EU slots; Hurghada→Cairo remains forbidden. Do NOT implement this historical version. See [current Licence 2 foreign-network design](AIRLINERRA_LICENCE2_FOREIGN_NETWORK_2026-11-17.md).

**SUPERSEDED 17 November 2026:** The user replaced 14 levels with **4** and rejected aircraft-count gates for licence tiers. This historical proposal must NOT be implemented. Use [Four-Level Licence 2 Design](AIRLINERRA_LICENCE2_FOUR_LEVEL_DESIGN_2026-11-17.md) instead.

# Airlinerra — Licence 2: 14 operating levels (DESIGN PROPOSAL)

**17 November 2026.** This is a **discussion draft**, NOT an activated game feature. Specific route ceilings, airport thresholds and minimum fleet sizes below are **PROPOSED**, not yet user-approved.

## Decisions already expressed by the player

- Licence 2 is a meaningful **separate** commercial licence, applied for only after **at least 90 game days of company registration**. It is **not automatically granted with AOC**; this supersedes the automatic-issuance proposal in `AIRLINERRA_LICENCE2_SIMPLE_COMMERCIAL_OPERATING_RIGHTS_2026-11-17.md`.
- Requirements for first application: own active AOC, at least one delivered aircraft ready to fly, registered home airport, sufficient company capital to cover 90 game days of forecast operating costs, Safety Rating **at least 80/100**, and no unresolved critical maintenance defects. Do **not** require separate base-handling contracts, insurance UI, business-plan documents, manual compliance forms, or commercial flights before first approval.
- Earlier discussion suggested **$25,000 charged on approval** and **5-game-day assessment**, not yet confirmed as final economic balance. Earliest possible first licence approval would therefore be **day 95**, assuming all checks pass and the same verified game clock continues.
- Licence 2 is **per distinct airline company**, never per holding. No periodic expiry and **NO licence renewal**. Its existing level can be upgraded at most once **every 365 game days**, with **multi-level jumps allowed** if that airline meets the higher level's requirements.
- AOC remains independently subject to its existing validity and Safety Rating >=70. Licence 2 requires **Safety Rating >=80**, so an airline can retain AOC but fail the commercial-licence standard.
- Basic game home-market rights remain straightforward: own registered country; for EU/EEA airlines, all EU/EEA countries as one shared market; flights from an airline's home market to **any foreign country** permitted without destination-country applications; a non-EU/EEA airline cannot start standalone flights between two foreign countries. Existing operational/maintenance/slot/aircraft position checks still apply. These are simplified **game** rights, not real-world bilateral-law claims.

## PROPOSED 14 levels

Airlinerra's existing category order is **Local < Regional < Medium < Large < Major Hub < Mega Hub**.

| Licence level | Maximum ACTIVE airport-pair routes | Maximum category for airports OTHER than registered home airport | Minimum delivered, ready-to-fly aircraft |
|---:|---:|---|---:|
| 1 | 3 | Medium | 1 |
| 2 | 5 | Medium | 2 |
| 3 | 8 | Large | 3 |
| 4 | 12 | Large | 4 |
| 5 | 18 | Large | 5 |
| 6 | 25 | Major Hub | 7 |
| 7 | 35 | Major Hub | 9 |
| 8 | 50 | Major Hub | 12 |
| 9 | 70 | Mega Hub | 15 |
| 10 | 100 | Mega Hub | 20 |
| 11 | 140 | Mega Hub | 28 |
| 12 | 190 | Mega Hub | 38 |
| 13 | 260 | Mega Hub | 50 |
| 14 | Unlimited, subject to real aircraft/slot constraints | Mega Hub (all categories) | 65 |

**Definition of "one route":** one unique pair of airport keys serving the airline, with reverse direction counted as the same pair. Flight frequency, multiple departures and a return leg do NOT consume extra route slots. Multi-leg travel uses a slot for each separate airport pair. No client-generated IDs or inactive paper schedules count as real routes. An existing real active pair needs aircraft, flight schedule and actual game operational eligibility.

**Home airport exception:** a verified airline's registered home airport is allowed as an endpoint at ALL licence levels even if categorized Mega Hub. This does not exempt the other endpoint, and does not allow arbitrary second high-category bases before the relevant level. Thus a new airline based at an existing Mega Hub can still serve Medium and smaller destinations at Level 1.

**Important game design trade-off:** With this strict maximum-category rule, even Tokyo→Frankfurt may be held until Level 9 if Frankfurt is Mega Hub, even though the simplified game's nationality/foreign-market rights allow the cross-border route. That is *airport-level progression*, not country-specific permission. Confirm whether user wants this strict gate; a softer alternative is to allow a small number of above-category destination airports at low levels.

## How to issue / upgrade without a progression deadlock

- **At first application**, grant the highest level **already met** by verified ready aircraft, Safety Rating >=80, financial reserve, operating readiness and other identical requirements, with a 90-day maturity floor. Do not force a well-funded 10-aircraft airline to Level 1 for a whole real year. The proposed level table's aircraft count is a floor, not the whole decision; any level still requires enough actual company cash to support 90 days of **that fleet's expected costs**. Higher-level safety threshold does **not** invent a second hidden Safety Rating.
- **Annual upgrade:** after at least 365 game days since the last approved level assessment, allow a new application, and jump directly to the highest currently eligible level. There is no automatic upgrade and no annual renewal. Upgrades are based on independently verified fleet, maintenance, cash forecasts and safety; importantly, they do **not** demand operating more routes than the airline's current level permits.
- **Annual upgrade fee:** not yet decided. Never silently apply the previously suggested **$5,000 yearly renewal fee**, since the user expressly rejected periodic renewal.
- Do not fabricate finances: use independently verifiable priced cost models; if a cost item is unsupported, fail the upgrade eligibility explicitly rather than inventing a reserve amount.
- Preserve the company's current licence level when a future upgrade is rejected; give short, specific reasons.

## Warning / suspension concepts (still to finalize)

- Problems eligible for improvement notices: Safety Rating <80, unresolved serious or critical maintenance defects, fewer ready aircraft than the current level requires, no longer meeting 90-day financial reserve, missing home airport, AOC status inactive. Avoid treating ordinary losses or low passenger reviews as independent violations.
- **Provisional 90-game-day correction window**, with notices at day 0/30/60; evaluate from trusted day records. If unresolved after day 90, suspend commercial rights, retain current level as a recoverable record. An invalid AOC or unsafe aircraft must stop affected commercial flights immediately via its own independent safety/airworthiness rules: Licence 2 grace never overrides those.
- Licence 2 itself has no time expiry. Serious proven fraud or insolvency/dissolution may eventually require separate revocation rules, subject to explicit design and trusted proof.
- Restore rights on verified correction and active AOC, preserving level. If the airline's fleet genuinely shrinks, later downgrade/requalification can be discussed; no automatic punitive deletion of company assets, routes or airline accounts.
- For booked flights impacted by a future suspension/downgrade, build atomic cancellation/refund and "already airborne completes safely" handling before turning on route enforcement. No effect on sister airlines.

## Implementation status

This document changes **no operating logic** and makes **no database mutation**. The current licence planner and the earlier separate Licence 2 source still describe an obsolete automatic grant proposal; **do not activate that implementation as Licence 2**. Update the game route-rights and licensing model *only after* the revised level requirements, fees and airport policy are confirmed and tested.
