# Airlinerra — Phase 5 Operation Verification Intake

**26 October 2026 · Supabase private research schema · GitHub main**

## Completed

Built an administrator-only, repeatable research workflow for one proposed aircraft operation at a specific runway end, with a proposed airline/operator, service class and flight date. **No game approvals, live deployments or commercial permissions.**

| Verified | Count |
| --- | ---: |
| Initial pilot cases | 6 |
| Gates per case | 11 |
| Evidence gate rows | 66 |
| Verified gates | 0 |
| Cases missing operator/aircraft/date | 5 |
| Fallon direction evidence holds | 1 |
| Phase 5 airports still unapproved | 211 of 211 |
| Original cohort preserved | 3,140 |
| World activation rows | 0 |

## Eleven evidence checks

1. FAA runway-end identity and direction source
2. Original FAA NASR provenance
3. Registered aircraft and airworthiness
4. Approved aircraft flight manual and flight-specific performance
5. Pavement, runway width and load suitability
6. Named operator's FAA certificate and operational specifications
7. Applicable DOT economic authority
8. Signed airport-owner commercial-use permission
9. Fuel, handling, rescue and access arrangements
10. Intended flight-date NOTAM, runway conditions and weather
11. Service-type security, customs and related rules

Required case intake fields include a nominated operator and aircraft, model, registration, relevant AFM revision, operation type, date, takeoff/landing weights, wingspan and required runway width, adjusted landing and takeoff requirements, and performance assumptions. All remain blank until supported documentation is provided.

## Status logic

FAA published landing distance is always distinct from the FAA AIM physical-runway assumption. Source TORA or an allowed physical-runway fallback is used separately to screen takeoff. Landing, takeoff and runway width must each pass. Fallon RW03 remains on declared-distance manual hold. Verified evidence requires reviewer and dated documents; evidence expired by the flight date does not qualify. Even a fully collected case can only reach **manual adjudication, not gameplay admission**.

## Current pilot cases

| FAA | Runway end | State |
| --- | --- | --- |
| FLX | 03 | Direction evidence hold |
| GWR | 16 | Awaiting operator, aircraft and flight date |
| HND | 17R | Awaiting operator, aircraft and flight date |
| PAAQ | 16 | Awaiting operator, aircraft and flight date |
| PRO | 14 | Awaiting operator, aircraft and flight date |
| RDK | 05 | Awaiting operator, aircraft and flight date |

## Archived code

- [Database schema, gate placeholders and updated readiness view](./sql/AIRLINERRA_PHASE5_NAMED_OPERATOR_AIRCRAFT_FLIGHT_GATE_WORKFLOW_2026-10-26.sql)
- [Private atomic case creator](./sql/AIRLINERRA_PHASE5_ADMIN_RESEARCH_CASE_CREATOR_2026-10-26.sql)
- [Database acceptance tests](./sql/AIRLINERRA_PHASE5_NAMED_OPERATOR_AIRCRAFT_FLIGHT_GATE_TESTS_2026-10-26.sql)

All six cases and 66 gate entries were independently verified. An administrator-only `SECURITY INVOKER` function can create a case and eleven checks atomically. It rejects an unknown runway or conflicting case identifier; calling it twice with identical values is idempotent. Both tables have RLS and no ordinary-app-user read/write access; the case function has no public execution privilege.

Relevant authorities: [FAA Part 135 certification](https://www.faa.gov/licenses_certificates/airline_certification/135_certification) and [US DOT commercial air-carrier authorization](https://www.transportation.gov/policy/aviation-policy/how-become-certificated-air-carrier). The exact applicable FAA regime depends on the intended operation; a generic Part 135 assumption would be incorrect.

## Next step

Create an authenticated, private administrator evidence-review workflow with explicit reviewers and revocation/expiry tracking. Do not launch a public interface or approve an airport without a later separately authorized admission process.
