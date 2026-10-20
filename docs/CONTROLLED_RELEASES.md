# Airlinerra — public-development single-branch process (effective 2026-10-20)

## Branch and repository status
- The only active development branch is **`main`**. The old `staging` branch was fast-forwarded into `main` on 2026-10-20 and is retired from active use. Never commit to or open a PR against legacy `staging`.
- The repository is intentionally **public during development**. A later switch to private does not remove already published or forked code.
- **Public GitHub repository ≠ published game.** No Netlify production integration, live payment settings, or production Supabase migrations are authorized by this development workflow.

## Normal development
1. Read `AGENTS.md` on `main`.
2. Check the latest `main` commit and work on that branch only. Do not assume a default branch or use legacy `staging`.
3. Validate data and code locally. For airport collection, run `python scripts/validate_airports.py`, `python scripts/validate_historical_airports.py`, and `python scripts/rebuild_runway_register.py`; confirm committed master and conflict files are unchanged when regenerated.
4. Preserve existing airport groups, the fictional LYAL entry, all review queues and source IDs. Airport technical selection requires a non-closed asphalt/concrete runway of at least 1,200 m. Six eventual airport categories are fixed; current screening only assigns minimum Level 1.
5. Commit to `main` only after validation. No PR/merge between development branches is necessary.
6. Keep group-screening and backfill GitHub Actions as `workflow_dispatch` only; use them deliberately for exceptional source refreshes, not as a required paid or repeated validation step.
7. Do not introduce production credentials, user records or financial information to this public source repository.

## Production launch — separate future decision
- Do not automatically publish unfinished source just because it is on `main`. Before connecting Netlify to `main`, obtain owner authorization and confirm how automatic deployments will be controlled.
- At launch, audit both working tree and Git history for exposed secrets, rotate any accidentally disclosed credentials, review data privacy, and change repository visibility as explicitly authorized in GitHub settings.
- Once private, standard GitHub Actions may become metered again. Adjust CI policy and budget before turning on recurring checks.
- Never treat making a repository private again as revoking already downloaded or forked code.

## Scope isolation
Never modify Famioo, Tennis Legacy, ProPeloton Manager, Game Control Center, or other repositories as part of an Airlinerra migration.
