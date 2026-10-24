# Airlinerra — Phase 3, Operational Constraint Batch 03 — first 20 cases (25 October 2026)

**Partial batch, not yet the full intended 40-case Batch 3.** Saved and read back in Supabase: 20 distinct airport keys; seven moved to the next eligibility check; 13 retain operational holds. Across operational Batches 1–3: 86 reviewed, 29 advanced, 57 not advanced. There are **804** operational holds remaining. All gameplay admissions remain zero; original cohort of 3,140 unchanged.

## Individual decisions (verified in Supabase)

| FAA | Key | Outcome | Critical finding / next verification |
|---|---|---|---|
| 64S | OURAIRPORTS:18957 | Next gate | 2025 Oregon runway/apron reconstruction and dated PPR are not permanent closure; recheck 2026 NOTAM and 50ft width/trees/owner commercial rights. |
| 6G1 | OURAIRPORTS:18986 | Hold | Both avgas and Jet A previously reported unavailable until Jan 2027; active NOTAM, supply alternatives and operator needed. |
| 7F3 | OURAIRPORTS:19055 | Hold | October west apron work and temporary CTAF; verify current apron/ground access, obstruction and owner permission. |
| 7V8 | OURAIRPORTS:19088 | Hold | Unattended without confirmed fuel/FBO; verify handling and operator. |
| 7W5 | OURAIRPORTS:19090 | Hold | RW28 REIL outage, obstacles and 60ft width; verify active NOTAM, LDA and operator. |
| RCM | OURAIRPORTS:19192 | Next gate | Former university FBO lease dispute does not establish runway closure; university owner rights still unconfirmed. |
| ACZ | OURAIRPORTS:19232 | Next gate | Night practice/touch-and-go restriction is not necessarily a blanket arrival curfew; displaced LDA and S-12.5 rating need checking. |
| BST | OURAIRPORTS:19408 | Next gate | Airport owner reports 24h access subject to closures; limited winter FICON reporting is not permanent closure; winter dispatch and owner permission remain. |
| CNC | OURAIRPORTS:19522 | Hold | Main concrete runway differs from too-short secondary; REIL/VASI notices, runway landing distance and aircraft rating outstanding. |
| COQ | OURAIRPORTS:19535 | Hold | S-8/D-12 pavement rating is a significant separate fleet restriction along with REIL outage. |
| CUL | OURAIRPORTS:19566 | Next gate | Holiday office closure is a staffing limitation rather than proof of pavement closure; after-hours fuel and licensed use unverified. |
| DKR | OURAIRPORTS:19634 | Hold | Both PAPIs out, S-12 rating and unattended services; aircraft/approach-specific validation needed. |
| E77 | OURAIRPORTS:19707 | Hold | AWOS outage through early November requires live weather and alternate-data validation. |
| EHA | OURAIRPORTS:19739 | Hold | Fuel unavailability, multiple PAPI failures and RNAV minima restrictions; independent operational checks required. |
| EST | OURAIRPORTS:19772 | Next gate | Seasonal turf-runway restriction does not close the qualifying concrete primary; actual winter service and owner rights pending. |
| EYE | OURAIRPORTS:19786 | Hold | 100LL shortage is fuel-specific, not runway closure; aircraft-type fuel and owner approvals remain unverified. |
| GAS | OURAIRPORTS:19924 | Hold | Holiday/weekday staffing does not close pavement; actual off-hours ground handling remains unconfirmed. |
| GYB | OURAIRPORTS:19995 | Hold | Deer/trees on approach and after-hours service require runway safety and licensed operator checks. |
| H79 | OURAIRPORTS:20017 | Hold | Both PAPI and REIL lighting outages require current NOTAM/minima checks. |
| HTL | OURAIRPORTS:20092 | Next gate | Snow closure applies to 18/36 turf, not separately to 09/27 asphalt; paved winter NOTAM, load and owner rights pending. |

## Evidence standard

Individual per-airport prior evidence URLs, complete original operational issue and mandatory next-verification fields are retained in `airlinerra.airport_expansion_operational_resolution_phase3`. The saved source cycle is 2026-10-01; no live FAA NOTAM validation was performed by this batch. **Advancing means narrower issue, not approved operational service.** No category, admission or activation was changed. The Airlinerra categories remain **Local, Regional, Medium, Large, Major Hub, Mega Hub**.

**Next:** Continue remaining 20 assessments to reach 40 for Batch 3, then verify database status and publish a complete consolidated report.
