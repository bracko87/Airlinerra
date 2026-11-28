# Aircraft storage release readiness — 28 November 2026

Review only. No approval to install, merge to main, deploy application or activate storage.

## Verified evidence
- Private persistent installation: run 46151229346 at b50721fbca7361801c06352fc45c44486817a558, all 62 components installed in a disposable schema clone, minimal local airport identity fixtures, 18 disabled control records, repeat installation refused and persisted fingerprint unchanged.
- Verified rollback preview SHA-256: 5f49d38e1485c01fa7cfa74819b12a25bdc3b1c8ff089955d3a5ce287a94e706.
- Blocked installation candidate SHA-256: 3e9e6fa6e17f0036f3e2beb5ce1eb9d5683d2d9447d4241018386c554e40edec. Actual refusal before installation verified again in run 46154422547.
- Synchronized review commit 84f7d9c84147f136cb13e34ad6d45624aac7c1d1 includes main 63a904b329e56094f7c5424ae8dde10a8a3f51a0. Eight workflow runs successful. Route planner suite 661/661, application build successful, both factory lease budget tests passed. Other runs: 46154422548, 46154422589, 46154422568, 46154422590, 46154422640, 46154422572, 46154419157.
- No production data copied into the disposable clone except separately recorded minimal public airport identity fixtures.

## Before requesting production installation approval
1. Recheck current main, the exact candidate digest, source functions and ledger fingerprints, nine airport registry identities, existing storage object absence, and existing aircraft configuration coverage using read-only queries. Check dependencies and live operational baselines; do not infer full live-data compatibility from schema-only verification.
2. Review shared commercial dispatcher and crew history changes under disabled controls, including non-atomic departure path and existing in-flight arrivals. Confirm no new scheduler or booking path can run on installation alone. Resolve any gaps before installation approval.
3. Confirm backup/PITR availability, recovery point and a coordinated maintenance window; a full restore can lose unrelated transactions. No production backup has been created or verified by this review.
4. Prepare a separate target-specific execution package with explicit authorization, atomic preflight and post-install assertions. Current blocked candidate must never be executed or manually unblocked.

## Distinct approvals
- Disabled database installation only: nine inactive candidate facilities; six service proposals; 271 billing proposals; no scheduler, application deployment or activation. Keep main unchanged during installation review.
- Application deployment: separate approval and smoke checks of existing fleet, factory budget, route and finance functions.
- Operational activation: separate approval for class mappings, individual facility readiness, service and access rules, and worker/booking release order. Roswell runway correction and unverified operational/pavement status remain separate blockers. Do not bulk activate.

Agreed monthly prices USD 4000 / 8000 / 15000; unlimited storage duration and occupancy. No production changes performed.
