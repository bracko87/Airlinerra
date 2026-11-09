# Airlinerra — Holding ownership, intercompany finance and licences

Date: 2026-11-08. State: **production-installed reference and finance foundations,
with every holding registration, subsidiary formation and treasury posting locked off**.
The permissions catalogue and Operations → Licences & Permits page are implemented.
The server-owned Holding page can now read an authenticated 60-day eligibility preview.
No operating approval, actual holding, subsidiary, payment or money transfer is created.

## Updated eligibility decision — 9 November 2026

The original airline qualifies by **age since registration**, not by completed
flights or an in-game simulation clock. The authoritative registration timestamp
is `airlinerra_game.airlines.created_at`. Count **60 elapsed 24-hour calendar
days**, using the PostgreSQL server clock. No daily login or completed flight
is required. The original airline becomes *age-eligible* at `created_at + 60 days`.
Holding registration remains independently disabled until the feature is released
and relevant world/ownership, finance and legal checks pass.

This supersedes the earlier first-flight/game-day requirement **for holding
eligibility only**. The in-game world clock remains essential for flight
schedules and economic simulation, but no longer blocks the holding date.
Source of truth: `airlinerra_game.holding_registration_eligibility_v2`.
The older `holding_eligibility_preview_v1` is legacy and must not be used
to determine holding availability.

For the initially registered airline (29 October 2026 at 08:12:26 UTC),
the 60-day threshold is 28 December 2026 at 08:12:26 UTC.
No actual holding, payment or licence has been created.

**Flight academy:** The initial flight academy belongs under the original
airline as future training infrastructure (instructors, simulators and
training aircraft). It is not an automatic additional holding subsidiary.
A separately trading academy for outside customers could become a
licensed training subsidiary later; the jurisdiction and programme may
require ATO/DTO or equivalent approvals. The feature and training fleet
are not yet implemented.

## Confirmed product rules

1. A holding is a **parent ownership and treasury entity**, not an air operator.
2. At most one parent holding per player per world initially. The player must have an
   existing original airline that was **registered at least 60 calendar days ago**.
   This is measured from the server-stored airline registration timestamp.
3. On formation, the original airline becomes a subsidiary without replacing its
   legal identity, aircraft, routes, employees or financial history.
4. The holding can incorporate additional separately funded subsidiaries:
   regional, passenger, low-cost, cargo, charter/VIP airlines, and maintenance/MRO.
   Commercial model labels like 'regional' do not themselves create special licences.
5. A new legally separate airline needs valid **applicable** national operator
   authorisation and any specific operations/aircraft approvals. An EU example is a
   separate AOC and commercial operating licence; approved activities depend on
   the operator and jurisdiction.
6. An MRO requires an applicable maintenance organisation approval with the
   correct facility, staff and aircraft/task scope. An EU example is Part-145.
7. No subsidiary **inherits** an AOC, maintenance approval, or route right merely
   because its holding or sibling owns one. A branch of an existing airline is
   different from a separately incorporated subsidiary.
8. Flight schedules and foreign hubs require route- and operator-specific market
   access; ICAO freedom definitions are NOT an automatic grant. The existing
   `airlinerra_game.aviation_air_service_rights_v1` table currently contains zero
   verified bilateral entries. Four existing hub policies remain disabled.

## Proposed treasury and incorporation flow

### Form the parent holding
- Server validates player and original airline ownership and world membership.
- Server reads the original airline's registration time from `airlines.created_at`,
  adds 60 full calendar days, and compares it with the server clock.
- No completed flight or game-world clock is needed for this waiting-period
  calculation. World launch and legal/finance eligibility still apply separately.
- Validate sufficient funds for a modest game formation fee, minimum safe reserves,
  and appropriate incorporation requirements. **No amounts are final yet.**
- Create parent holding and ownership link for the original airline atomically.
  No manual duplication of airline cash/fleet/route inventory.

### Add a new regional airline or cargo subsidiary
- The parent holding chooses entity type, country of incorporation and company name.
- Show the *company registration fee* separately from *capital committed* and
  *application / certification fees*. These are distinct accounting events.
- Fund the subsidiary by **equity** or a repayable **intercompany loan** from
  the holding treasury. The holding treasury must first actually receive eligible
  cash (such as a permitted dividend or loan) from a subsidiary, or other
  approved legitimate source.
- Before creation, validate holdco balance, cash-after-reserves, company limits,
  operator-specific ownership/legal requirements, and world isolation.
- Company appears as pending/inactive until its own applicable operating licences
  and approvals are verified. Simply forming a company never enables flights.

### Treasury movements
- Support documented types: equity contribution, dividend, loan issue, loan
  repayment, interest, legitimate service payment, and game banking fee.
- Transfers use a single server-side serializable/locked transaction with
  idempotency key, immutable linked debit/credit journal lines, ownership checks,
  same-world checks and sufficient unlocked cash.
- Record a **separately itemized**, small game transfer fee, debited from
  the sender, posted to a platform fee account. Fees and caps need balancing;
  never use a percentage of aircraft catalog estimates or arbitrary UI money.
- Reverse or cancel through compensating journal entries, not a balance edit.
- Prevent circular cash exploits, borrowing to satisfy blocked reserve checks,
  cross-world transfers, replay/duplicate payments and parent-owned asset duplication.
- Do not permit transferring money just by changing a browser-side balance.

## Licensing and market-right architecture

The read-only `airlinerra_game.business_permission_catalog_v1` holds 16 reference
**types**. It is not a table of licenses issued to any player. It intentionally has
RLS enabled, no direct client SELECT grants and a check preventing active game
status. Every game fee and processing time is NULL.

Future operational records must be distinct:
- `company_permission_grants`: specific operating company, country/authority,
  granted code, authorised activities and aircraft/facility scopes, effective
  and expiry dates, verification status, evidence, suspension/renewal.
- `company_permission_applications`: company-specific request, qualification
  snapshot, paid application fee, pending/approved/rejected/expired state,
  reviewed evidence and immutable decision history.
- `operator_market_access`: company and home licence nationality, specific
  origin/destination/stop markets, service type, relevant ICAO freedom(s),
  treaty/market basis, validity period, exceptions and evidence.
- `company_business_registrations`: jurisdiction, company form, owner, state
  and creation costs without suggesting this alone grants an AOC.
- Real world research and fictional game balance must occupy different columns.
- One *grant* belongs to one company, with a defined jurisdiction and scope.
  A holdco does not automatically allow foreign cabotage.
- Route and company activation must run one **server authoritative** permissions
  gate; frontend-only warnings are not sufficient.

## Implementation order

1. **DONE:** 16-row master reference catalogue; sources, evidence status, zero
   active grants and disabled applications. Original hub rules unchanged.
2. **DONE:** Operations → Licences & Permits read-only page and server-authenticated
   catalogue endpoint; link from Holding.
3. **DONE for age calculation:** The read-only server-owned holding API now
   reports the exact registration-age eligibility date and remaining days based on
   `airlines.created_at`. It works even when the game worlds are planned and no
   flights have completed. The previously created first-flight/game-clock reference
   tables remain for other game engine work, but no longer gate the holding counter.
   Actual holding registration is still **NOT DONE**.
4. **PARTIAL:** Separate zero-frozen treasury accounts, draft-only idempotent
   transfer intent schema and exact-cent fee/capital preview contract exist.
   Atomic world-scoped **posted** double-entry movements, actual operating-company
   cash integration, fee schedules and subsidiary capital injection remain NOT DONE.
   The existing `airlines` table enforces UNIQUE(world_id,owner_player_id);
   multi-airline operators require a deliberate change to that ownership model
   before any additional real airline is created.
5. **NOT DONE:** Per-company licence grants, verification and application workflow,
   country/market data batches, expiry, renewals and enforcement in route planning.
6. **NOT DONE:** Live financial/legal fees, activation and acceptance/regression
   testing. No pricing assumed until balancing is approved.

## Current deployed foundations (no live financial effects)

- `airlinerra_game.holding_world_policy_v1`: one hard-disabled, unpriced 60-day
  policy for each of three worlds.
- `airlinerra_game.holding_world_clock_v1`: NULL game date for every planned world;
  authoritative-game-engine evidence required for later updates.
- `airlinerra_game.airline_first_operating_day_v1`: first **settled commercial flight**
  evidence only; currently empty.
- `airlinerra_game.holding_groups_v1` and `holding_subsidiaries_v1`:
  world-scoped, owner-safe, planning-only entities, both currently empty.
- `airlinerra_game.holding_treasury_accounts_v1`: balance fields hard-locked at
  `0.00`, independently of original airline cash.
- `airlinerra_game.holding_transfer_intents_v1`: world/holding ownership FKs,
  separate source/destination, unique idempotency keys and `draft`-only state;
  cannot post actual transfers.
- `airlinerra_game.holding_registration_eligibility_v2`: authoritative
  server-filtered 60-calendar-day age view using `created_at`. This supersedes
  the old operating-flight/game-clock view for holding eligibility.
- `server/holding-finance-contract.mjs`: pure, exact-integer-cents fee and funding
  preview; rejects self transfers, subsidiary-to-subsidiary shortcuts, foreign
  worlds/groups, reserved-cash violations, and absent/zero fee policy.
- `/api/v1/player/holding-status`: authenticated, read-only; live Edge API v14
  uses the registration-age view, preserves all unrelated deployed functions,
  and exposes no holding write route.
- SQL reconstruction: `docs/sql/AIRLINERRA_HOLDING_OWNERSHIP_FINANCE_V1_2026-11-08.sql` plus the 2026-11-09 registration-age v2 SQL file.
- Existing registered airline and $5m seed ledger remain untouched.

## Reference framework

- EU commercial operating licence and AOC: Regulation (EC) 1008/2008,
  https://eur-lex.europa.eu/eli/reg/2008/1008/oj/eng
- EASA AOC: https://www.easa.europa.eu/en/domains/air-operations/air-operator-certificate-aoc
- Part-145: https://www.easa.europa.eu/en/the-agency/faqs/part-145
- ICAO market access/freedoms: https://wasa.icao.int/AboutWASA/WASAExplanatoryNotes
- ICAO dangerous goods: https://www.icao.int/Dangerous-Goods/Technical-Instructions

Country-specific requirements and actual bilateral rights still need research;
these general references do not grant permission to serve a market.
