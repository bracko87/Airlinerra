# Aircraft storage airport admission

Production registry audit, 2026-11-26. Identity matches by ICAO source_ident/source_gps_code. Existing commercial authorization is not changed. These are candidates, not approved storage facilities.

| ICAO | IATA candidate | Airport key | Current roster | Operationally authorized |
|---|---|---|---|---|
| YBAS | ASP | OURAIRPORTS:26900 | GROUP_1 | true |
| LFBT | LDE | OURAIRPORTS:4073 | GROUP_1 | true |
| KROW | ROW | OURAIRPORTS:3856 | GROUP_1 | true |
| LETL | TEV | OURAIRPORTS:316427 | GROUP_2 | false |
| KAVQ | AVW | OURAIRPORTS:19330 | GROUP_2 | false |
| EGDX | DGX | OURAIRPORTS:2409 | GROUP_2 | false |
| EGBP | GBA | OURAIRPORTS:2395 | GROUP_2 | false |
| KVCV | VCV | OURAIRPORTS:21315 | GROUP_2 | false |
| KMHV | MHV | OURAIRPORTS:20507 | absent | false |
| KMZJ | MZJ | OURAIRPORTS:20594 | absent | false |

## Release requirements
- Confirm actual storage/dismantling operator, access permission, runway and aircraft compatibility, airport identity, timezone, curfew/noise, and game fees before enabling each facility. Marana Regional is not Pinal Airpark; keep separate and do not assume storage capability.
- Reuse registry keys. Admit absent airports to a special-purpose relocation-only catalogue, not the commercial roster. Keep Group 1 commercial eligibility unchanged. Group 2 commercial authorization remains unchanged.
- Separate storage capacity reservation from aircraft stand/flight slots. No commercial tickets, cargo sales, passenger demand or normal route creation at special-purpose-only airports.
- Require actual scheduled relocation, fuel, crew, runway, airport fees and signed arrival at the reserved airport before changing fleet status to stored. No direct position writes. Release reservation on cancellation. Intermediate legs must satisfy range.
- Monthly storage charge starts on signed arrival and stops upon verified release; preserve ledger history. Reactivation requires maintenance/inspection and scheduled movement where applicable.
- Tests: no duplicate airport identities; relocation-only destination excluded from commercial route and ticket admissions; unauthorized or unverified facility fails closed; no overbooking storage capacity; no storage status before arrival; retries do not duplicate fees.

No production mutation is authorized by this document. Storage prices/capacities require game-balance approval and real-world capability review.
