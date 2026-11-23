# Airlinerra — genuine signed movement, cancellation, and fuel-custody lock regression (23 Nov 2026)

## Outcome

**PASS** — disposable PostgreSQL 17 GitHub Actions:
https://github.com/bracko87/Airlinerra/actions/runs/45249818525

This verified the actual `section9_record_signed_operated_flight_movement_v1` SQL function
(as corrected by forward-only migration `20261123200000_section9_signed_movement_cancellation_guard.sql`)
and the **unchanged** production `section9_cancel_unflown_occurrence_v1` function,
both installed in a fresh disposable local database.

### Successful acceptance cases

1. Cancel first, then provide a **genuinely valid HMAC** with a disposable secret: departure raises `SECTION9_SIGNED_DEPARTURE_OCCURRENCE_NOT_OPEN`; no movement record survives.
2. Real HMAC departure first: movement recorded; the actual cancellation function refuses the already-operated occurrence.
3. Hold aircraft's fuel custody row in one transaction while another transaction acquires the production cancellation/dispatch advisory lock, waits on custody, calls the actual movement writer, and closes the occurrence. Concurrent actual cancellation loses; movement count is exactly one and cancellation count zero.

Tests use `pgcrypto` for actual HMAC computation, not a placeholder signature, and check SQL row postconditions.

### Corrections made

- The low-level signed writer now acquires advisory transaction lock `(583729,10041)`, shared with dispatch and cancellation.
- Signed departures require a matching *open* verified saleable dated occurrence, checked before movement insertion.
- Corrected a PostgreSQL variable-versus-table-alias collision where `anchor` was both a PL/pgSQL record and a query alias.
- Avoided assigning an uninitialized `anchor` record in the verified starter-airport fallback. The starter airport now requires a present valid key.

### Trust and release limits

- **Production was not modified or released.** The forward-only SQL migration is committed to GitHub, but must be applied and checked by the normal controlled deployment process.
- The database is a minimal synthetic fixture with dummy company, schedule, aircraft, airport, world clock and release evidence. The fixture enables release gates only within its disposable database to reach the signed writer. It does not attest to actual World 1 release readiness.
- Only a custody row lock is exercised directly in test orchestration. The complete real fuel preflight, approved refill, departure receipt, arrival burn, and fuel-quantity reconciliation functions were **not** invoked.
- Real airline certification, airport permission, slot, boarding, and financial settlement workflows were not invoked as integrated producers.
- The shared lock test is on a successful signed departure path and does not replace a full, operational dispatcher and cancellation end-to-end test.

### Files

- `tests/sql/section9_real_cancellation_disposable_bootstrap.sql`
- `tests/sql/section9_real_signed_movement_disposable_dependencies.sql`
- `supabase/migrations/20261123200000_section9_signed_movement_cancellation_guard.sql`
- `.github/workflows/section9-real-signed-cancel-race-ci.yml`

### Next boundary

Run the **real** fuel-preflight and signed-departure fuel receipt functions alongside both actual signed movement and actual cancellation in a complete disposable dependency stack. Assert rollback of movement, fuel receipt and occurrence when preflight or custody revision fails. Then validate migration application on an isolated staging database before any production deployment.
