# Group 2 prepared-airport information API — live release and safeguard record
Date: 2026-11-10

## Actual production change
Supabase project `hwllkabgzaynalahvkpz`, Edge Function **airlinerra-game** upgraded from deployed version **14** to **15**. The upgrade was a surgical patch to the actual 18-file live bundle; **all other 16 files were carried forward byte-for-byte**.

Only:
- `server/canonical-game-api.mjs`: added `/api/v1/player/prepared-airports` to the already authenticated player read paths.
- `server/player-read-service.mjs`: added a parameterized, read-only prepared airport lookup with the same verified-user, origin and JSON request controls as existing approved-airport lookups.

Live existing `/api/v1/player/airports` query and airport-office service remain unchanged. The three deployed airport-office source files, previously absent in the repository, were also copied to GitHub `main`, and the canonical router there was reconciled to preserve them in future deployments.

The prepared airport route returns only `source_group='GROUP_2'`, `commercial_access_scope='GROUP2_PREPARED_NOT_ADMITTED'`, `game_data_status='game_complete_estimated'` rows; all results explicitly specify `commercialAccess:false`, `bookable:false`, `canActivateFlights:false`. Responses are paginated and require user authentication. It does not touch approved airport admission, schedule reservation, route planning, dispatch or the game's financial ledger.

## Post-deployment verification
A fresh readback of production Edge Function confirmed version **15**, ACTIVE, 18 bundled files, new route/handler, and airport-office imports preserved. Production database counts remained:
- Combined Section 1–8 game catalog **4,259**
- Approved Group 1 **3,141**
- Prepared Group 2 **1,118**
- Group 2 commercially activated **0**

The localhost preview gateway on `main` now permits forwarding the protected prepared route to the deployed Edge Function; the route is read-only. Associated Node source tests updated to expect forwarding with a bearer token, while rejecting malformed auth.

## Remaining verification and UI
- No authenticated live HTTP call was performed with a real test-user session. The live 200/401/403 behavior and page rendering are therefore **not end-to-end confirmed**.
- Existing customer-facing airport list and route planner still use approved Group 1 only. The new route is not automatically surfaced in the player UI and does not activate Group 2.
- GitHub CI has not reported a passing run for these latest commits. Source-level tests are committed but not verified as executed by CI.
- Further integration requires the new informational results to be rendered in a dedicated, non-bookable part of the airport page, plus the separate Section 5/6 live-engine integration and explicit commercial admission tests.
- Older notes that say the prepared endpoint is undeployed have been superseded by this release record.
