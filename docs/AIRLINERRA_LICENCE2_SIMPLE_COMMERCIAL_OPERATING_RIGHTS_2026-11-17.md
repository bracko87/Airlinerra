# Airlinerra — Licence 2: Commercial Operating Licence and Basic Market Access

**Simplified game specification — 17 November 2026**  
**Status:** agreed design direction; **NOT implemented / enabled as operating route permission**.

## One simple rule instead of country-by-country applications

When a separately incorporated commercial airline receives its own valid AOC (Licence 1), Airlinerra also gives it its **own commercial operating licence automatically** for the country where THAT AIRLINE COMPANY is registered. Do not issue to the holding; a holding's subsidiaries never share certificates or scores.

- **Fee:** $0 extra beyond AOC. **Processing:** no extra wait. **Renewal:** automatic and free while that company has a valid AOC. No separate annual renewal application, financial-score bar or country paperwork for Licence 2.
- **Home market:** commercial domestic routes between airports in the airline's registered country are allowed automatically.
- **EU/EEA shared market:** A company registered in an **EU member state, Norway, Iceland or Liechtenstein** treats the entire EU/EEA as its shared domestic market for game route access. It can create standalone flights Germany→France, France→Belgium, Germany→Germany, Norway→France, etc., even if its home country is Germany. No per-country permission application.
- **Every other registered country:** its own country is its home market, **not** the EU/EEA market. A Serbian airline can sell Serbia→Serbia; a Japanese airline Japan→Japan; a US airline US→US. None automatically gets stand-alone Berlin→Paris, France→Belgium, or another country's domestic routes.
- **Ordinary international routes:** for game simplicity, allow a commercial airline to create a flight **between its home market and ANY foreign country** automatically, with no per-country bilateral/traffic-right licence application. Examples: Japanese airline Tokyo↔Frankfurt; Serbian airline Belgrade↔Paris; US airline New York↔Tokyo. For an EU/EEA airline, the shared EU/EEA market is its home market: German airline Paris↔Tokyo is also permitted by THIS SIMPLIFIED GAME MODEL.
- **Third-country ↔ third-country stand-alone services:** not included for a non-EU/EEA airline if **neither end is inside its own home country**. E.g., Japanese airline Frankfurt→Paris, US airline Tokyo→Frankfurt, Serbian airline Paris→Brussels are not automatically permitted. A new registered airline subsidiary in a region has its own local market rights if it receives its own AOC/licence.
- NO extra country-by-country forms, approvals or fees for everyday domestic, EU/EEA-internal or home-market↔international flight creation. If any later advanced market-rights options are built, they must be optional and must not block ordinary routes the licence already covers.

## At-a-glance examples

| Registered airline | Berlin→Munich | Paris→Brussels | Belgrade→Paris | Tokyo→Frankfurt | Frankfurt→Paris |
|---|---|---|---|---|---|
| Germany (EU) | Allowed | Allowed | Allowed | Allowed | Allowed |
| Norway (EEA) | Allowed | Allowed | Allowed | Allowed | Allowed |
| Serbia | Not automatic | Not automatic | Allowed | Not automatic | Not automatic |
| Japan | Not automatic | Not automatic | Not automatic | Allowed | Not automatic |

"Allowed" here means *market rights granted automatically by Licence 2*; actual flight operation still needs correct aircraft location, schedule, maintenance readiness, slots/airport conditions and all independent operational checks. An airline cannot teleport aircraft or repeatedly depart without repositioning.

## Validity and loss

If that exact company's AOC expires or is not valid, Licence 2's commercial rights become **inactive**. Correcting the AOC safety issues and automatically reinstating its AOC **reactivates** the same company-level commercial rights with no new charge. No licence-wide punishment from mere low profits, a poor Company Image or inactive routes. Company bankruptcy/dissolution is separately managed in the future company lifecycle. No separate 0–100 financial health rating or Licence 2 safety rating.

A cargo subsidiary losing its AOC/licence NEVER suspends a passenger sister airline or the parent holding.

## Product scope, not legal equivalence

These are deliberately GAME-SIMPLIFIED route eligibility rules, **not assertions about legal bilateral traffic rights**. In reality airlines have agreements, regulatory and country-specific rules, and Switzerland has separate aviation market arrangements despite not being in the EEA. To honor the user's request for an **EU/EEA-only shared game market** and no per-country bureaucracy, Switzerland is not automatically included in the EU/EEA game market in this initial draft. Review separately only if user changes that rule.

## Implementation guardrails

1. The existing read-only catalogue identifier `EU_AIRLINE_OPERATING_LICENCE` is an EU reference; **do not silently treat that EU-only database row as a worldwide licence**. Implement a generic company-scoped **commercial operating licence/market profile**, with EU/EEA as an included region attribute and other companies registered to their own countries.
2. Trusted server determines registered country from the operating-company record and derives a boolean `sharedEeaMarket`; never from player-provided country, flight airport location, airline name or holding registration. Cross-world and cross-company isolation.
3. Decide origin/destination market rights using trusted airport country IDs. EU/EEA market as a single home market for a qualifying carrier; every other country a single home country. Routes are allowed when both airports lie in that home market, OR when at least one endpoint is inside the home market and the other is anywhere else. Otherwise block with a simple "Route is outside this airline's home market" explanation.
4. Licence 2 must not bypass AOC or independent operational flight permissions. Keep other licences (cargo/VIP, dangerous goods etc.) as later **separate design discussions**; do not silently activate or remove them now.
5. Existing section9 route rights applications and verifiers may currently insist on individual permission codes. They must be **reconciled and tested before this product simplification is enabled**; do not cut security gates or invent active rights in production.
6. No live-game licence, money, passenger booking, route or release policy is changed by this document.

## Official context

EU and EEA internal aviation market: https://transport.ec.europa.eu/transport-modes/air/international-aviation/status-aviation-relations-country/norway_en

EU–Switzerland agreement (real-world exception excluded from initial simplified game rule): https://eur-lex.europa.eu/legal-content/EN/LSU/?uri=CELEX%3A02002A0430%2802%29-20230101
