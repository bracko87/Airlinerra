**LATEST USER CORRECTION — 17 NOVEMBER 2026:** This document's Licence 2 interpretation is OBSOLETE. **Ordinary home-country ⇄ foreign-country return flights require only Licence 1 under the simplified game rule; Licence 2 is extra foreign NETWORK expansion, with quota counted by DIRECTIONAL ROUTE (not unique airports).** Example: Serbian airline Belgrade⇄London uses L1; Zagreb→Ljubljana and Ljubljana→Zagreb need two L2-EU slots; Zagreb⇄Hurghada uses two L2-EU slots; Hurghada→Cairo remains forbidden. Do NOT implement this historical version. See [current Licence 2 foreign-network design](AIRLINERRA_LICENCE2_FOREIGN_NETWORK_2026-11-17.md).

# Licence 2 — Foreign-market permits: correction to earlier planning (17 November 2026)

**Status: interpretation correction and proposed architecture. Not an approved economic balance and NOT live.**

## User's intended meaning

Licence 1 is the home airline's AOC (safety operator certificate). **Licence 2 is a permit sought by an airline based OUTSIDE a destination market**, to allow flights serving that market.

Example: A Serbian airline with its own Serbian AOC wants **Belgrade → London**. It applies for **L2-UK**; it is **NOT** asking for a British home-company operating licence. A Japanese airline needs **L2-EU** to serve Europe; a German airline needs **L2-US** to serve the US. UK and Japanese home airlines do not apply for permits intended only for *foreign* carriers entering their own market.

**Earlier interpretation of Licence 2 as the airline's national home-country operating licence and all airlines receiving it with their AOC was WRONG.** In particular:
- [Four-level design](AIRLINERRA_LICENCE2_FOUR_LEVEL_DESIGN_2026-11-17.md) incorrectly treats L2 as a universal company/home operating licence with worldwide airport caps; **do not implement this document without complete foreign-permit redesign**.
- [Fourteen-level draft](AIRLINERRA_LICENCE2_14_LEVELS_PROPOSAL_2026-11-17.md) is obsolete.
- [Simplified basic market-access draft](AIRLINERRA_LICENCE2_SIMPLE_COMMERCIAL_OPERATING_RIGHTS_2026-11-17.md) is only usable as a separate home market access policy, not a definition of a foreign-market application.
- Current read-only `website/licensing-planner.mjs` and legacy `EU_AIRLINE_OPERATING_LICENCE` row still describe home-carrier economic licensing. **Do not rename this real regulatory reference to a foreign permit or activate it as an L2-* market grant.** Future foreign permits need distinct logical codes and a secure owner-scoped application workflow.

## Proposed foreign-market permits — NOT FINAL

| Permit | Applicant company registration | Target market | Proposed game levels |
|---|---|---|---|
| L2-EU/EEA | Outside EU/EEA | EU + Norway, Iceland, Liechtenstein | 4 |
| L2-US | Outside United States | US | 4 |
| L2-UK | Outside UK | UK | 2 |
| L2-JP | Outside Japan | Japan | 2 |

These game levels are NOT real regulatory classes. A foreign permit allows **home market ↔ destination market**, NOT domestic carriage within a foreign country and NOT a general right to fly between two airports wholly inside a foreign market. Existing independently approved airline home-market rights stay separate. Do not invent a per-destination-country paperwork requirement inside the EU/EEA; model its zone as one game market. For other destinations not in these groups, decide separately whether simplified international access remains automatic, with no extra licence.

## Actual World 1 airport catalogue for permit balancing (17 Nov 2026)

From `airlinerra_game.airport_sections1_8_combined_catalog_v1`, `world_id=1`. Group 1 has the existing approval cohort; Group 2 prepared **not commercially admitted**.

| Target market | Existing Group 1 | Group 2 prepared | All catalogue |
|---|---:|---:|---:|
| EU/EEA (excluding Switzerland) | 393 | 105 | 498 |
| US | 483 | 554 | 1,037 |
| UK | 40 | 17 | 57 |
| Japan | 78 | 1 | 79 |

Level caps, processing costs, pre-application 90-day company maturity, 90-day finances, safety >=80, annual upgrade without renewal, suspension and corrective workflows still need to be adapted to a **PER AIRLINE × PER TARGET MARKET** permission, not one universal company level. E.g., an airline can hold L2-EU Level 2 and L2-UK Level 1 simultaneously.

## Real-world analogues and accurate naming

- Europe: **EASA Third-Country Operator (TCO) safety authorisation** for foreign carriers; EASA states it does **NOT** itself issue commercial traffic rights (these remain with states). For gameplay, a bundled L2-EU permit could be an intentional simplification, and must not falsely claim a legal EASA TCO grants EU-wide traffic rights. https://www.easa.europa.eu/en/domains/air-operations/tco-third-country-operators and https://www.easa.europa.eu/en/faq/21600
- USA: **DOT Foreign Air Carrier Permit / exemption** (economic authority), alongside **FAA Part 129 Operations Specifications** (safety). https://www.transportation.gov/policy/aviation-policy/licensing/foreign-carriers and https://www.faa.gov/hazmat/air_carriers/operations/part_129
- UK: **CAA Foreign Carrier Permit** for all non-UK carriers (including EU/EEA), plus UK TCO safety requirements. UK domestic *Type A / B* licences are NOT the analogue. https://www.caa.co.uk/commercial-industry/airlines/licensing/foreign-carrier-permits/applying-for-a-foreign-carrier-permit/
- Japan: **foreign international air transport business permission** under Civil Aeronautics Act Article 129. This is different from licensing a Japan-based carrier. https://www.mlit.go.jp/koku/15_bf_000038.html

## Strict implementation guardrails

1. Permit state keyed by **airline company + target market + world**, not parent company and not airline origin country alone. A company may have multiple L2-* permits and different levels.
2. Do not issue any foreign market permit to a company whose jurisdiction is the same market; use its independently documented home-market operating right instead.
3. Do not grant domestic **foreign cabotage** or third-country↔third-country standalone flights by virtue of foreign entry permit. Consider route-specific operational/foreign service rights separately only if player wants them (no per-country paperwork by default).
4. Airport numerical and category limits count airports **inside that target permit market**, not global served airports; no double counting connections/frequencies.
5. Do not touch current active flight gates, licence fee transactions, airport admission or bookings until user confirms exact levels, costs and suspensions.
