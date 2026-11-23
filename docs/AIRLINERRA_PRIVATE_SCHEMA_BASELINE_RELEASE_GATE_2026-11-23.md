# Airlinerra — PRIVATE schema-only baseline and staged release gate

**Date:** 2026-11-23
**Release decision:** BLOCKED. Production release switches and live data have not been changed.

## Why a different method is required

The public GitHub repository's migration directory is not a faithful, restorable copy of all historical Supabase operations. The live database includes foundational tables created outside the present checked-in SQL history. Reconstructing another table every time a disposable replay fails does not prove compatibility.

The repository is **public**. A real schema-only SQL dump may contain private function definitions, privileged policies, owner-only account logic, hardcoded test addresses or credential-like literals. **Do not upload it to this repository, an issue, a pull request, public GitHub Actions artifacts, or chat.**

## What is implemented

- `scripts/ci/airlinerra_private_schema_baseline.sh`: accepts a securely stored Airlinerra database URL, validates exact project identity and TLS, enforces remote read-only sessions, produces a temporary `pg_dump --schema-only` from `airlinerra`, `airlinerra_game` and `public`, then deletes the dump at job exit.
- `tests/sql/airlinerra_private_schema_fingerprint.sql`: calculates seven SHA-256 structural category signatures from catalog definitions (relations, columns, constraints, indexes, functions, policies and triggers) without returning the source SQL or table data.
- `.github/workflows/airlinerra-private-schema-baseline-ci.yml`: validates URL safety and shell syntax. If the required secret is configured, uses local Supabase Docker to restore the schema-only snapshot, compares the seven structural fingerprints and tests two forward-only corrective migrations **only on the local clone**.

The code protects against a wrong-project connection, insecure/unset TLS mode and missing credentials. No source database writes, schema/artifact uploads or release toggles are made.

**Test:** https://github.com/bracko87/Airlinerra/actions/runs/45266970563 — safety checks PASS, **live schema export and restore SKIPPED** because the GitHub secret is absent. This is not a completed database clone or release certification.

## The single required connection prerequisite

Add a GitHub Actions repository secret on `bracko87/Airlinerra`:

- **Secret name:** `AIRLINERRA_SCHEMA_READONLY_URL`
- **Value:** a valid private PostgreSQL connection string to the Airlinerra project `hwllkabgzaynalahvkpz`, database `postgres`, using TLS (`sslmode=require`, `verify-ca` or `verify-full`) and preferably a purpose-scoped, read-only database role.
- **Location:** GitHub repository → Settings → Secrets and variables → Actions → New repository secret.
- **Never share the URL/password in chat, commit it to GitHub source files, or paste it into an issue.**

If using a connection pooler, the URL must have a Supabase pooler host and the project-qualified `postgres.hwllkabgzaynalahvkpz` username. The runner validates this without disclosing credentials.

Once securely configured, run GitHub → Actions → **Airlinerra private schema-only baseline and restore gate** → Run workflow (main). Do not use `db push`, `db reset --remote`, or any command that writes to live production.

## Current read-only structural inventory

On 2026-11-23, read-only catalog fingerprinting of `airlinerra` and `airlinerra_game` returned:

| Object type | Count |
|---|---:|
| Relations (tables, views, materialized views, sequences) | 755 |
| Columns | 9,479 |
| Constraints | 3,624 |
| Indexes | 893 |
| Functions | 415 |
| Policies | 1 |
| User triggers | 74 |

This is an **inventory, not a restorable dump**. The fingerprint query was executed successfully against the live Airlinerra project without reading account or passenger rows.

## Additional release-security audit

Supabase's live security advisor reports:
- 3 functions with mutable `search_path` (to be assessed before an approved forward-only correction).
- 1 authenticated-callable `SECURITY DEFINER` function, `public.airlinerra_own_aircraft_image_path_v1(text)`. Its body explicitly checks `auth.uid()`, the owner, airline and aircraft. It is referenced by four Storage RLS policies for the owner's aircraft images, so revoking EXECUTE blindly would break intended media operations. Review/test its actual security semantics rather than applying a blanket revoke.
- Leaked-password protection disabled in Auth (configuration review, not a SQL migration).
- 444 private RLS-enabled tables without RLS policies, consistent with a deny-by-default possibility but requiring role/schema exposure review; it is not evidence by itself of unprotected access.

Security remediation references:
https://supabase.com/docs/guides/database/database-linter?lint=0011_function_search_path_mutable
https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable
https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection

## Exit criteria

1. Private schema-only snapshot **captured and restored successfully** into disposable local Supabase; matching structural fingerprint and no sensitive artifacts published.
2. Corrective migrations pass on the clone; SQL grants, RLS and signatures rechecked.
3. Reconcile 17 same-name SQL-body drifts, the remaining unmatched GitHub migration names, and private account/airport baseline history without reapplying production changes blindly.
4. Independently accept real aircraft-route-flight-money frontend/backend lifecycle.
5. Obtain explicit production deployment/release approval and verify live changes only after all blockers are closed.

**No paid staging branch was created. No production settings or tables were changed.**

## 23 November 22:01 UTC — latest credential and IPv4 pooler diagnostic

The GitHub secret now passes basic URI formatting validation; local safety scripts pass. The GitHub-hosted runner cannot reach the Direct IPv6 Supabase endpoint. An attempted guarded, schema-identity-verified fallback to officially documented eu-central-1 Supabase Session pooler candidates did **not** authenticate:

- Shared session pooler candidate index 0: other connection failure (raw error/credentials intentionally suppressed).
- Shared session pooler candidate index 1: authentication rejected.
- The SQL export and local restore were **not** reached; no production data/DDL changed.
- The connected Supabase project separately reports `ACTIVE_HEALTHY`; read-only cron check confirms flight dispatch, passenger demand, and final finance workers running successfully.

**Required input:** In Supabase's own **Connect → Session pooler → URI** panel, copy that project's exact session-pooler connection string, replace the database password placeholder with the newly reset password (URL-encode password special characters) and set it as the existing GitHub Actions `AIRLINERRA_SCHEMA_READONLY_URL` secret. Do not simply paste the Direct connection string; do not choose Transaction pooler (port 6543). Never publish the URI or credentials.

**Latest workflow run:** https://github.com/bracko87/Airlinerra/actions/runs/45275280824

This is a connection/authentication prerequisite only, not a schema migration failure. Stop trying blind pooler variants until the authoritative project Session pooler URI is provided.
