# Airlinerra Licence 2 — Foreign Network Expansion Rights

**17 November 2026. User-corrected game design; PROPOSAL, not deployed/issued/approved for release.**

**This document supersedes both** `AIRLINERRA_LICENCE2_FOREIGN_MARKET_CORRECTION_2026-11-17.md` (wrong: treated every incoming home-to-foreign flight as requiring L2) **and** `AIRLINERRA_LICENCE2_FOUR_LEVEL_DESIGN_2026-11-17.md` (wrong: treated licence as home-company operating licence with worldwide airport caps). Do NOT implement the earlier interpretations.

## 1. The exact distinction

**Licence 1 = own airline's AOC, with simplified basic home-market transport rights for this game.** An airline registered in Serbia can operate commercial flights **Serbia -> UK and UK -> Serbia**, **Serbia -> EU and EU -> Serbia**, **Serbia -> Japan and Japan -> Serbia**, **Serbia -> Egypt and Egypt -> Serbia** without L2 foreign-network privileges. Separate aircraft suitability, slots, schedule, maintenance readiness, airport access and other operational gates remain independent. This home-to-foreign rule is a GAME simplification, not an assertion that the real AOC is itself an international traffic-right permit. No per-country bilateral-forms burden in ordinary game operations.

**Licence 2 = EXTRA permission for a company to build a network AWAY from its own home market**, per separately licensed foreign target-market group. Example: Serbian airline receives **L2-EU** to run **Ljubljana -> Zagreb**, **Zagreb -> Ljubljana**, and, with a foreign base appropriately registered in Zagreb, **Zagreb -> Hurghada -> Zagreb**. Foreign-network flights not linked to that Serbian airline's home market consume L2 EU directed-route entitlements.

L2 grants **none** of the following by itself: rights for independent local networks in places not in its permitted markets; operating unsafe or unregistered aircraft; automatic airport slots; automatic open station/base; the right to create routes ignoring licensed-airport categories and per-market directed-route counts.

A licensed EU foreign base may operate its approved **direct** flights from the EU to a country outside the EU and back to the same EU base (e.g. Zagreb↔Hurghada), but cannot establish further **domestic Egyptian routes** (Hurghada->Cairo) or an independent Egyptian base from L2-EU.

Company-specific and per-foreign-market, not per holding. Sister companies must apply separately.

## 2. Route counts (user-explicit correction)

- Licence 2 counts **directed airport-to-airport routes**, not the number of different airports reached and NOT the number of flight departures.
- Zagreb -> Ljubljana = **one** directed L2 route slot.
- Ljubljana -> Zagreb = **a second** L2 route slot.
- Zagreb -> Hurghada = **one** L2-EU route slot; Hurghada -> Zagreb = **another** L2-EU route slot.
- Four flights daily along the same directed pair = **one** L2 route slot. A reciprocal return route has its own slot.
- Belgrade -> Zagreb and Zagreb -> Belgrade remain ordinary Licence 1 flights: neither uses an L2 slot even if the airline also holds L2-EU.
- Count L2 slots **per foreign-market permit**, and count only active approved direct directional connections. No flight/aircraft count or unique-airport-count quota.
- Prevent double charging L2 slots when two permits are potentially applicable; choose an explicit permission source deterministically and audit it. Do not let permit selection bypass geography.

## 3. Market groups proposed (not country-by-country bureaucracy)

- `L2-EU`: EU/EEA foreign network as one market, only for airlines registered outside EU/EEA.
- `L2-US`: US foreign network for airlines registered outside US.
- `L2-UK`: UK foreign network for airlines registered outside UK.
- `L2-JP`: Japan foreign network for airlines registered outside Japan.
- **Other countries, e.g. Egypt:** no L2 foreign-network option in this initial set. They can be served by ordinary home-country ↔ Egypt flights, or through **direct** links to a licensed L2 foreign base, but do not permit Egypt-to-Egypt, Egypt hub-to-third-country routes or local Egyptian base/network rights. If more L2 regions are ever added, that must be an explicit design change.
- Special EU/EEA home-market rules for EU/EEA registered airlines stay separate: their EU/EEA internal route access is part of their **home market**, not a foreign EU L2 permit. They may still need L2-US, L2-UK or L2-JP for foreign networks.
- A non-EU airline holding L2-EU cannot use its EU rights to create other unlicensed local-network hubs outside the EU/EEA.

## 4. Levels: EU figures discussed by user; NOT FINAL

The user requests four levels for the EU; no aircraft-number tier requirements. The proposed numerical EU schedule is:

| L2-EU Level | Max concurrent active directed routes powered by L2-EU | Proposed EU/EEA airport category access |
|---|---:|---|
| 1 | **10** | Local, Regional, Medium (proposal to avoid only 12 currently-approved Local/Regional airports) |
| 2 | **50** | Local, Regional, Medium, Large |
| 3 | **150** | Up to Major Hub |
| 4 | **Unlimited** | All categories, including Mega Hub; exceptionally hard to obtain |

**Important:** Ljubljana and Zagreb are both **Large** in Airlinerra's currently approved game airport catalogue, so under this proposed category table Ljubljana↔Zagreb would require **L2-EU Level 2**, not Level 1; the example's directional route-count logic still applies at any allowed level. Cairo and Hurghada are **Major Hub** in the game. For an L2-EU route EU↔Egypt, category restrictions are checked against the **EU endpoint licensed under L2-EU**; independent foreign airport operational gates still apply. If the user wants a stricter category check on the non-EU endpoint, settle that separately before implementation.

Airlinerra World 1 combined catalogue EU+EEA: 498 airports (393 existing Group 1; 105 prepared/not commercially admitted Group 2). Current Group 1 low categories Local 8 + Regional 4 = 12; Medium 188; Large 153; Major Hub 36; Mega Hub 4. `airlinerra_game.airport_sections1_8_combined_catalog_v1` as of 17 Nov 2026. There are **200** existing Group 1 airports through Medium; the Level 1 default category suggestion reflects this real game imbalance. **No Group 2 flight access implied**.

The USER has not yet set appropriate route limits/number of levels for **US, UK and Japan**. These need market-specific balancing; do **not** assume previous conjectured 4/4/2/2 or universal four levels is already approved.

## 5. Applicant, level progression and risk (partially discussed)

- The airline must have its **own valid AOC**, be registered for **at least 90 game days**, have a registered home airport, **at least one delivered aircraft ready to fly**, and meet independently verified company-specific financial resilience for 90 game days, AOC Safety Rating **>=80/100**, with no unresolved critical maintenance defects before first licence application. **No fleet-quantity tier progression**.
- L2 is **a separate application with a real financial fee**; earlier discussion suggested **$25,000 for first approval and 5-game-day assessment**, but the user has NOT approved region/level upgrade fees or processing periods. Do not silently charge.
- No periodic renewal or expiry of this commercial network permission. Airline can request an optional upgrade **once per 365 game days** and may **skip levels** if it meets independently tested higher conditions.
- Levels should require progressively stronger maturity, stable financial records, safety and maintenance. Final conditions for each EU tier, particularly the very wealthy/stable Level 4, are not yet approved.
- Correction notices, warning grace and licence loss are wanted. 90-game-day correction period with reminders at day 30/60 is proposed, **not yet final**. An invalid AOC or unsafe aircraft always blocks unsafe flight immediately, independent of Licence 2's warning.
- No destructive route dropping / forced ticket cancellation until validated refunds, aircraft-position handling and affected-flight safeguards are implemented.

## 6. Example routes for a Serbian registered company

| Route | L2 required? | Reason |
|---|---|---|
| Belgrade -> London | NO | Ordinary home -> foreign via L1 game rights |
| London -> Belgrade | NO | Foreign -> home |
| Belgrade -> Zagreb | NO | Home -> foreign |
| Zagreb -> Belgrade | NO | Foreign -> home |
| Ljubljana -> Zagreb | L2-EU | Foreign-to-foreign EU network (1 direction, 1 slot), airport category must qualify |
| Zagreb -> Ljubljana | L2-EU | Second direction, second slot |
| Zagreb -> Hurghada | L2-EU | Direct flight from approved EU base to outside destination (1 slot) |
| Hurghada -> Zagreb | L2-EU | Return to licensed EU base (1 slot) |
| Hurghada -> Cairo | NOT ALLOWED | Independent domestic Egypt route, no Egyptian L2 network |
| London -> Manchester | L2-UK | Independent UK domestic route, provided UK L2 category and route allowance qualify |

This is a **GAME-SIMPLIFIED concession for foreign airlines**, not a declaration that real foreign carriers enjoy unrestricted cabotage in EU/UK/US/Japan or that EU/UK/US/JP real regulations have these game levels.

## 7. Implementation constraints

- Any future route-leg entitlement: evaluate registered owner airline, own country/home market, L1 active, L2 permit keyed by **company + world + foreign-market group**, zone/endpoint geography, registered and licensed foreign base where applicable, active directed pair quota and allowable relevant endpoint category. Always still verify aircraft location/slots/operational constraints.
- Do not implement the existing EU national operating-licence `EU_AIRLINE_OPERATING_LICENCE` reference code as L2-EU; they are different real concepts. Introduce distinct L2 foreign-network logical codes only after business decisions finalized.
- Current game database **does not yet issue or enforce** this new L2 foreign-network concession. This document is design-only. No live license, route permission, payment, airport admission, reservation or player account data changed.
