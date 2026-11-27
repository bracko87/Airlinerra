# Aircraft storage activation matrix — 2026-11-27

Decision record for the isolated aircraft leasing/storage review branch, not an authorization to deploy. Baseline regression 46030749735 passed (including dual-use runway readiness, browser PPR receipts, revocation, inbound and outbound lifecycle). Source details remain in the three phase evidence files. All nine storage facilities remain unapproved.

| Phase | Registry key | Airport | Proposed game runway limit (takeoff / landing, m) | Width reference (m) | Service window proposal | Release blockers |
|---|---|---|---|---|---|---|
| 1 | OURAIRPORTS:26900 | ASP / YBAS | 2438 / 2438 | 45.1 game | reuse commercial screens | live runway 233325 operational status unknown at prior audit; confirm existing game performance and access |
| 1 | OURAIRPORTS:4073 | LDE / LFBT | 3000 / 2330 | 45.1 game | reuse commercial screens | live runway 235930 status unknown; enforce conservative landing limit in storage only |
| 1 | OURAIRPORTS:3856 | ROW / KROW | 3050 / 3050 | 30.5 game | reuse commercial screens | live runway 244235 status unknown; retain existing conservative runway identity and width |
| 2 | OURAIRPORTS:316427 | TEV / LETL | 2539 / 2539 | 45 | weekday seasonal UTC windows; reviewed holiday calendar | game elevation factor, aircraft width policy, actual reviewed calendar/coordination; no out-of-hours exceptions |
| 2 | OURAIRPORTS:21315 | VCV / KVCV | 3978 / 3978 | 45.72 | 0600–2200 local proposed fuel-service intersection | reviewed service/access policy, elevation and aircraft width, mixed surface |
| 3 | OURAIRPORTS:20594 | MZJ / KMZJ | pending; physical 2087.6 | 45.7 | 0700–1530 local subject to reviewed access days | published declared distances and service days, first-arrival access, elevation/width |
| 3 | OURAIRPORTS:20507 | MHV / KMHV | pending; physical 3810 | 60.96 | pending confirmed service intersection | operator runway source unavailable; reconcile long runway and declared distance/fuel window; elevation/width |
| 3 | OURAIRPORTS:2395 | GBA / EGBP | pending; physical reference 2009 | 45 physical reference | 0900–1700 local, prior permission | current UK AIP declared distances, aircraft width/noise/permission and reviewed service calendar |
| 3 | OURAIRPORTS:2409 | EGSY (legacy EGDX) | pending; operator approx. 1800 | pending | 0900–1700 local, prior permission and sponsor | reconcile identity, current UK AIP declared distances and width, listed fuel review, game sponsor rule |

## New verification notes

Cotswold operator Aerodrome Manual V23 section 5.5 refers declared distances to the UK AIP rather than listing them. Secondary listings disagree with the 2009 m physical reference; do not seed the physical length as declared landing distance. The operator PDF screenshot could not be retrieved in this review, so final approval remains blocked. Source: https://cotswoldairport.com/wp-content/uploads/2025/12/Cotswold-Airport-Aerodrome-Manual-Version-23.pdf . Secondary comparison: https://whatfbo.com/fbos/egbp-kemble/details .

Pinal FAA-derived runway listing corroborates physical dimensions, not all directional declared distances: https://www.globalair.com/airport/apt.runway.aspx?aptcode=mzj . Mojave operator runway page still returns HTTP 403; use the previous FAA reference for the physical length only, not final approval.

## Release conditions

1. Review the live commercial runway status using the existing airport source-evidence process; never set an operational status simply because a storage facility is present. Re-run the Phase 1 read-only preflight.
2. Review storage-only profiles including elevation/width policy and service calendar. A simulation simplification must be recorded as such; unknown restrictions can use the agreed game defaults only after known restrictions have been addressed.
3. Require the exact current readiness snapshot for each candidate; no bulk approval from this matrix. All feature gates default off; no synthetic fixture rows may appear in production.
4. Run full isolated migration compatibility and actual scheduler execution before release. Review web/server deployment ordering and rollback plan; preserve in-flight arrival and settlement continuity.
5. Explicitly authorize the production deployment and individual facility activation. Keep KAVQ excluded. No commercial authorization changes.

Game balance: monthly USD 4000/8000/15000, unlimited storage occupancy and duration. Proposed movement slots are separate from storage occupancy. No real-world dispatch or airport access authorization is implied.
