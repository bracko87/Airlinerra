# Airlinerra — Holding ownership, intercompany finance and licences

Date: 2026-11-08. State: **design / planning only**. The new permissions register and
read-only Operations → Licences & Permits page are built. Nothing in this document
authorizes flight operations, creates a holding, charges accounts or grants approvals.

## Confirmed product rules

1. A holding is a **parent ownership and treasury entity**, not an air operator.
2. At most one parent holding per player per world initially. The player must have an
   existing original airline that has completed **60 true operating game days**.
   Airline registration timestamp is not a substitute for verified first operation.
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
- Server derives first **operational game date** from authoritative published
  commercial flight activity, not from `airlines.created_at`.
- Require 60 completed in-game operating days; the game clock and legal eligibility
  must be in a single authoritative world-level service.
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
3. **NOT DONE:** Authoritative first operating game day / world calendar service;
   eligibility date, real 60-day countdown and actual holding-company registry.
4. **NOT DONE:** Atomic world-scoped company treasury, transfer fees and subsidiary
   capital injections with idempotent double-entry postings.
5. **NOT DONE:** Per-company licence grants, verification and application workflow,
   country/market data batches, expiry, renewals and enforcement in route planning.
6. **NOT DONE:** Live financial/legal fees, activation and acceptance/regression
   testing. No pricing assumed until balancing is approved.

## Reference framework

- EU commercial operating licence and AOC: Regulation (EC) 1008/2008,
  https://eur-lex.europa.eu/eli/reg/2008/1008/oj/eng
- EASA AOC: https://www.easa.europa.eu/en/domains/air-operations/air-operator-certificate-aoc
- Part-145: https://www.easa.europa.eu/en/the-agency/faqs/part-145
- ICAO market access/freedoms: https://wasa.icao.int/AboutWASA/WASAExplanatoryNotes
- ICAO dangerous goods: https://www.icao.int/Dangerous-Goods/Technical-Instructions

Country-specific requirements and actual bilateral rights still need research;
these general references do not grant permission to serve a market.
