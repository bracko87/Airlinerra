# Section 8 — World 1 Airline Operating Fees: GAME DATA COMPLETE
**Game acceptance:** 9 November 2026. **Scope:** 3,141 airports / 271 aircraft configurations.
**Authoritative game-data status:** `game_complete_estimated` in `airlinerra_game.airport_data_master_categories` and in `world1_game_data_section_acceptance_v1`. **Source-verified tariff:** no. **Actual airline money posting:** no. **World 1:** planned.

## What the user requested

Airline operational fees must vary by all six airport classes, and by tourism or major-city background; terminal positions must cost more than remote positions; cargo operations must pay for cargo handling; add control tower/terminal navigation and distance/weight-based en-route ATC charges. Aircraft fuel price and whether to buy fuel at origin/destination were explicitly deferred.

The game already has 3,141 tier/background-adjusted landing, parking and passenger fee baselines in `airport_game_fees`. **Do not apply an additional tourism multiplier to those existing baselines**: they already include a background adjustment. The new ancillary-service multiplier applies ONLY to additional handling and parking/cargo services.

## Production implementation

- `section8_fee_category_policy_v1` — six private RLS-backed policies for takeoff movement, ground handling, terminal/remote/cargo stand price factors, terminal ATC, per-passenger security/border processing and per-tonne cargo handling.
- `section8_airspace_navigation_policy_v1` — global game navigation proxy: **$65 / 100 km at 50 tonnes**, with 40 km terminal-area distance deduction, aircraft weight factor and no route-zone legal tariff attribution. The first **60 minutes after arrival** are free for parking.
- `section8_repriced_airport_fee_audit_v1` — auditable old/new JSON snapshots for the **90 airport fee rows explicitly flagged for Section 8 repricing** after category changes; corrected from current tier median + a bounded existing individual variation + documented city/tourism game factor. The other **3,051** airport fee rows are untouched.
- `section8_airport_operating_tariffs_v1` — complete private read-only 3,141-airport tariff view, including tier, game-background provenance and other calculated game-only fee components.
- `section8_quote_flight_operating_fees_v1` — *private read-only* function with ten separate itemized charges and total (all USD) based on approved origin/destination, trusted game aircraft configuration/MTOW, origin/departure stand type, passengers, cargo tonnes, destination stand/parking time and great-circle game distance. It cannot update ledger, wallets, bookings, aircraft positions or schedules.
- `20261109221500_section8_quote_strict_world_guard.sql` — fail-closed World 1 only (even for a NULL world ID).
- Existing `section6_airport_slot_capacity_v1` stand types (terminal, remote and cargo) are reused, and unavailable stand categories are rejected in quote calculation.

## Pricing events — when to charge after actual flights exist

| Cost line | Game calculation / billing moment |
|---|---|
| Origin airport takeoff/movement | Based on origin landing-fee reference, category-specific movement fraction, and MTOW; once at departure |
| Arrival landing | Based on destination landing-fee reference and MTOW; once at landing |
| Departure ground handling | Origin category, aircraft size, selected terminal/remote/cargo position, and airport background; once at departure |
| Arrival stand parking | Destination parking daily reference, position multiplier and actual **chargeable minutes after first 60 free**; pro-rated 24-hour basis; bill the parking interval **once** in the rotation, not once on arrival AND again before next departure |
| Departure terminal ATC / approach-tower proxy | Category-specific unit rate weighted by MTOW to power 0.7; once per departure; **separate** from en-route |
| En-route ATC/navigation | Global game rate × (great circle km minus 40 km terminal distance) / 100 × sqrt(MTOW tonnes/50); charged once per physical flight, NOT once per country without zone evidence |
| Departure passenger facility charge | Existing origin airport passenger rate × actual departing passengers |
| Departure passenger security charge | Game category fee × actual departing passengers |
| International passenger processing | Fee at origin × departing passengers **only when countries differ**; domestic flights zero |
| Cargo export/import handling | Origin and destination category/background per-tonne fees × actual tonnes, separately itemized. Zero cargo means zero cargo charges. Cargo-only flights receive zero passenger fees |

`game_operating_fee_preview_only` returns `canPostToLedger=false`, `cashPosted=false`, `operationAuthorized=false` and `fuelIncluded=false`. This is a **planning** quote; an independently authorized Section 9 settlement producer must use actual flown journeys, loaded passengers/cargo, times, verified aircraft, stable event IDs and a frozen tariff-version snapshot.

### Stand and tier parameters

| Tier | Departure movement as share of landing | Terminal parking factor | Remote parking factor | Terminal navigation base | Security/pax | Cargo/tonne |
|---|---:|---:|---:|---:|---:|---:|
| Local | 12% | 1.55 | 0.70 | $25 | $1 | $20 |
| Regional | 14% | 1.55 | 0.70 | $50 | $1.50 | $35 |
| Medium | 16% | 1.60 | 0.70 | $95 | $2.50 | $60 |
| Large | 18% | 1.65 | 0.70 | $160 | $3.50 | $90 |
| Major Hub | 20% | 1.70 | 0.70 | $250 | $4.50 | $125 |
| Mega Hub | 22% | 1.75 | 0.72 | $360 | $5.50 | $160 |

These are **invented USD game-balance starting prices**, not ICAO/DFS/Eurocontrol unit rates. The existing airport-specific landing/parking/passenger fees remain the primary category and background adjustment. Touristic airports currently in the data (1,112) receive a **10% additional uplift only on NEW service charges**, such as cargo, parking and ground handling. Capital/large-city game backgrounds have smaller new-service factors.

### Worked game-only example — Frankfurt (FRA) to Ibiza (IBZ)

Assume catalogue 737-8200 (82,190 kg MTOW), 100 departing passengers, no cargo, 180 minutes parked after arrival, and the same terminal/remote stand choice on both ends:

| Stand choice | Total planned airline expenses | Ground handling at departure | Destination parking | En-route ATC |
|---|---:|---:|---:|---:|
| Terminal | **$10,862.75** | $2,877.96 | $105.06 | $1,103.02 |
| Remote | **$9,108.37** | $1,184.07 | $44.57 | $1,103.02 |

All figures are live query results from the current **game model**, not travel pricing, regulatory tariffs or a billed flight. A cargo-only ATR 72-600F with 2 tonnes in cargo stands for the same example gives a game fee preview of **$3,647.24**, including $336.00 origin and $198.00 destination cargo handling. These figures should be compared with actual airline profitability during Section 9 balancing; they are not automatically affordable for every airfare or business model.

## International navigation and what is NOT finished

Real air-navigation fees depend on service providers and the flight's actual path through charging zones, rather than airport category alone. Section 8 implements a global weight/distance **GAME proxy** and a separate terminal ATC fee now. It does **not** assert which individual national ATC providers handled a fictional flight or bill per-country FIR rates. Later aircraft-operation work may replace the proxy with versioned FIR-zone pricing, but only after a defensible authoritative zone/route calculation exists.

Real conditional fees are also variable: de-icing, emissions/noise programmes, airport/local taxes, optional servicing, special cargo, towing and overflight exemptions may not apply to every flight. The initial Section 8 game model handles the normal universal charges requested; any conditional source-linked cost needs a separate pricing policy rather than inventing a universal fee.

**Fuel is deliberately separate:** no refueling, origin-versus-destination price choice, fuel expense or fuel ledger entry here. A sensible future approach is automatic safe refueling by default with optional player planning, constrained by range, reserve, aircraft maximum weight, available fuel/airport services and actual location. That belongs to the later fuel/operation integration, not Section 8 closure.

## Security and acceptance

- The three private pricing/audit tables have RLS enabled and no direct `anon` or `authenticated` grants.
- The SQL quote is `SECURITY INVOKER`, private and denied to both browser roles.
- All 3,141 tariff airport profiles have valid category policies; 271 model weights cover the configuration catalogue.
- Repricing snapshots prove exactly 90 model rows changed; no unflagged baseline was repriced.
- Stand price comparisons, 60-min grace, international/domestic, cargo, actual mass and distance, missing stand, non-existent aircraft, overcapacity, null/wrong world, no fuel and no money posting passed rollback-only live database tests.
- World 1 remains planned; no active commercial flights or movement events, and the existing airline ledger was unchanged.
- Section 8 was formally closed for **game-price inputs and private fee calculations**, while factual source review remains Section 10 and **actual money settlement stays Section 9**.

## Public references for REAL-WORLD fee structure, not the invented game rates
- ICAO Policies on Charges (Doc 9082): https://www.icao.int/sites/default/files/2024-12/9082_cons_en.pdf
- ICAO Airport Economics Manual (Doc 9562): https://www.icao.int/sites/default/files/2024-12/9562_3ed_en.pdf
- EUROCONTROL CRCO, April 2026: https://www.eurocontrol.int/publication/customer-guide-route-charges
- DFS Germany terminal/en-route charges: https://dfs.de/homepage/en/company/legal-framework/charges/
- Fraport airport charges: https://www.fraport.com/en/business-areas/operations/airport-charges.html

The public references explain real charge categories and real route/terminal weight/distance charging approaches; they do not approve Airlinerra's USD prices.

## Next Section 9 handoff
1. Build a private, independently authorized, actual-operated-flight **expense intent** for every fee line above, bound to the exact schedule, tariff version, aircraft and completed flight event.
2. Create idempotent finance posting after verified flight operation and booked passenger/cargo evidence; debit each cost only once; reverse via compensating entries.
3. Show live itemized cost estimates to owners before route activation (through authenticated game API), and compare ticket/cargo revenue with fuel+crew+maintenance to balance solvency.
4. Connect World 1 verified game-day producer, operations worker, crew/slot/permission certificates, settlement and load test with 500 players. **No launch switch in Section 8 migration.**
