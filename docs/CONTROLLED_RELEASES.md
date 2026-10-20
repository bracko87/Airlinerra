# Controlled releases — Airlinerra

## Branch roles
- `staging`: integration and development branch. Always specify this branch when writing files.
- `main`: protected production baseline. Do not modify outside approved releases.

## Workflow
1. Read `AGENTS.md` and this document on `staging`.
2. Work in small independent changes, on `staging` (or short-lived feature branches targeting staging).
3. Validate and document changes before opening a release PR.
4. For production, compare `staging...main`; review migration consequences, schema validation, tests and any UI screenshots.
5. Release only following an explicit decision by the owner. Merge through PR to `main`.
6. Use two manual release windows per day (morning and evening). No exact clock times have been set; do not invent them.
7. Urgent releases require the same minimum validation and explicit approval, even outside the windows.
8. Production deployment (when configured) is sourced ONLY from `main`.

## Release checklist
- [ ] Review full file diff and confirm no unauthorized changes.
- [ ] Run automated checks and fix failures.
- [ ] In the current runway-only airport collection phase, confirm airport CSV integrity: >=1200 m, asphalt/concrete, runway open, minimum eligible Level 1; do NOT require final six-category, civilian approval or operational data yet.
- [ ] Review Supabase migrations and rollback strategy; do not auto-apply production migrations.
- [ ] Obtain explicit owner authorization.
- [ ] Merge approved PR into `main` within release window (or validated urgent exception).
- [ ] Verify deployed behavior and record release outcome.

## Scope isolation
Airlinerra project, repository, database and deployment must be independent from ProPeloton Manager and Game Control Center.
