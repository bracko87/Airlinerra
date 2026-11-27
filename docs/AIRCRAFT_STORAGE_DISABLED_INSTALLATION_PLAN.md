# Disabled aircraft storage installation plan
Candidate only. Production deployment and facility activation are not authorized.

## Verified baseline and revision boundary
Private rehearsal 46066000877 at 6ca40a133a8984b1a26229550206db2bef6acc02 successfully installed and rolled back 62 components and all candidate data on a schema clone with minimal registry fixture. The subsequent Tarbes dimension restrictions passed isolated regression 46067397627 at f852d2269df836594a4330c097e1207783b5aa25 but have not passed a renewed integrated rehearsal. Use exact current manifest blob pins; historical receipts must not be treated as approval for a changed component.

## Package boundary
- One atomic transaction, 62 pinned components in manifest order, no automatic COMMIT in review output. No synthetic airport registry inserts in the intended release package.
- Require exact existing nine registry identities and current source compatibility before any future authorized installation.
- Nine candidate records and uniform USD 4000/8000/15000 prices; six service proposals; 271 classification proposals. No active billing class assignments, staged operational profiles or final facility reviews.
- All 18 activation control records present and disabled. Exclude separate read-only preflight and background cron component from the installation payload. No scheduler job creation, commercial runway inventory changes, new airport commercial rights or application deployment.
- Before authorization: renewed private clone rehearsal, exact output digest and commit pin, manual deployment review, restore/backup procedure and application compatibility assessment. Never convert an arbitrary rollback-only file to COMMIT by text replacement in production.

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
Renew integrated rehearsal of changed Tarbes screen; verify exact nine live registry identities at execution; settle game-only pavement/width policy, access and runway operational status; prepare and verify final executable installation and approval receipt; obtain explicit authorization. Do not enable any production release switches.
