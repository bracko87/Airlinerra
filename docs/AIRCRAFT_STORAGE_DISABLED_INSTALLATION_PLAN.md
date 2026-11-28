# Disabled aircraft storage installation plan
Candidate only. Production deployment and facility activation are not authorized.

## Verified baseline and revision boundary
Private rehearsal 46066000877 at 6ca40a133a8984b1a26229550206db2bef6acc02 successfully installed and rolled back 62 components and all candidate data on a schema clone with minimal registry fixture. The subsequent Tarbes dimension restrictions passed isolated regression 46067397627 at f852d2269df836594a4330c097e1207783b5aa25 and were subsequently included in successful private runs 46127961768 and 46151229346. Use exact current manifest blob pins; historical receipts must not be treated as approval for a changed component.

## Package boundary
- One atomic transaction, 62 pinned components in manifest order, no automatic COMMIT in review output. No synthetic airport registry inserts in the intended release package.
- Require exact existing nine registry identities and current source compatibility before any future authorized installation.
- Nine candidate records and uniform USD 4000/8000/15000 prices; six service proposals; 271 classification proposals. No active billing class assignments, staged operational profiles or final facility reviews.
- All 18 activation control records present and disabled. Exclude separate read-only preflight and background cron component from the installation payload. No scheduler job creation, commercial runway inventory changes, new airport commercial rights or application deployment.
- Before authorization: renewed private clone rehearsal, exact output digest and commit pin, manual deployment review, restore/backup procedure and application compatibility assessment. Never convert an arbitrary rollback-only file to COMMIT by text replacement in production.

## Blocked release candidate — 28 November 2026
Persistent rehearsal 46151229346 committed all 62 ordered components on a disposable schema clone, reconnected and verified disabled states, preserved registry rows and rejected repeat installation. Verified rollback preview SHA-256: 5f49d38e1485c01fa7cfa74819b12a25bdc3b1c8ff089955d3a5ce287a94e706.
The new candidate builder consumes this exact digest and the persistent rehearsal receipt. It generates an SQL review artifact with the same body, an explicit final COMMIT, and an unconditional authorization error before any installation statement. It also generates a separate digest receipt. Neither file belongs in supabase/migrations; routine CI must prove execution is rejected. Do not manually remove the guard.

## Installation and recovery checklist
- Before approval: review branch differences against the current production application, current dispatcher and ledger sources, existing role grants, and all pending independent migrations. Full commercial runtime parity on real data is not established by the schema clone.
- Before any authorized installation: identify database backup/PITR coverage and a verified recovery point, record the exact candidate and approved target, schedule a maintenance window and pause conflicting deployment/schema writers. Confirm existing operation and ledger baselines. No live credentials in repository or CI artifacts.
- Installation must be atomic, fail on any source drift, retain every candidate inactive and leave application/scheduler unchanged. If transaction fails, rollback and inspect before retrying. After successful commit, run read-only verification and compare pre/post operational baselines before authorizing any further changes.
- After commit, do not indiscriminately restore the whole live database or drop the schema: either could lose unrelated transactions. If needed use a separately reviewed forward repair, or coordinated restore with explicit acceptance of recovery-point data loss. Once activated, suspend new work while preserving signed arrival and billing settlement continuity.
- The authorized execution package and target-specific preflight must be separately reviewed and approved; the blocked candidate does not authorize installation.

## Installation versus activation
1. Review-only build against exact manifest and current registry prerequisites; verify source compatibility and disabled state assertions.
2. Obtain explicit approval for database installation only. Separately design execution boundary and verify real data preconditions inside the transaction; any mismatch aborts. Installation must precede exposing storage controls in the application.
3. With installation confirmed, approve class assignments and each facility independently using exact current readiness evidence. No bulk approval based on candidate status.
4. Enable scheduler and player booking only after verified operational and financial controls. Preserve signed arrival and settlement continuity if suspending new bookings; do not blindly drop installed objects when active movements or sessions exist.

## Roswell independent airport correction
Source: data/airports/startup/runways_3140.csv, historical row:
```
3856,US,244233,03,21,13000,3962.4,150,45.7,PEM,YES,YES,YES,KROW
```
Other source rows include closed 12/30 (244234) and currently present 17/35 (244235). Live registry longest qualifying runway is 3050.4 m ASP; live runway inventory contains only 244235. Published evidence corroborates 03/21 dimensions: https://www.airnav.com/airport/KROW and https://vfrmap.com/fe?q=KROW&req=get_afd . Historical PEM code and published concrete description require explicit normalization; do not infer live operational status from historical source is_open. Keep 12/30 excluded. Review shared longest-runway selection and commercial compatibility before any inventory correction. This change is not part of storage installation. ROW activation remains blocked.

## Current blockers
Verify exact nine live registry identities at execution; settle game-only pavement/width policy, access and runway operational status before activation; complete application compatibility and production backup/recovery review; obtain explicit authorization. Do not enable any production release switches.
