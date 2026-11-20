# Airlinerra — atomic signed execution and finance certificate sink integration

Date: 20 November 2026.

## Implemented and verified

**CI passed:** https://github.com/bracko87/Airlinerra/actions/runs/44818050949

The original `airlinerra_game.section9_record_verified_certification_event_v1` production SQL body, originally in `supabase/migrations/20261109195500_section9_game_licence_certification_freshness.sql`, was installed intact in fresh disposable PostgreSQL 17; then the previously deployed production fail-closed migration and the new source-recheck integration migration were both applied to that original function. The test did not replace the actual certification-write function with a simplified mock.

New integration migration:
`supabase/migrations/20261120234000_section9_atomic_execution_finance_certification_sink_integrated.sql`

It replaces only the explicit *unreleased execution/finance* branch with the `section9_recheck_execution_finance_source_reference_v1` invocation. The existing writer already takes the exact saved schedule row `FOR UPDATE`; the source recheck locks the same schedule version `FOR SHARE`, recomputes the persisted operational release/schedule/clock/fuel/fingerprint facts and validates the independent type-specific reviewer and source reference **before the append-only event and current certification rows are written**. The migration guards the expected old function definition and preserves revocations of execution rights from anonymous, authenticated and service roles.

Disposable PostgreSQL fixtures:
- `tests/sql/section9_disposable_source_snapshot_positive_bootstrap.sql` and `tests/sql/section9_disposable_execution_finance_sink_fixture.sql`, with invented in-service aircraft, route, clock, release policy and three historical certification-event rows;
- `tests/sql/section9_disposable_execution_finance_sink_acceptance.sql`, with actual source-positive certification writes for each of the two missing authorities and exact-id replay idempotency;
- `.github/workflows/section9-atomic-execution-finance-certs-ci.yml`, including the disposable database guard and automatic extraction of the **original** production certification function.

Assertions passed: two correctly scoped event/certificate records, replay does not duplicate records, invalid source after modified destination is blocked, revocation of existing independent route-rights evidence is blocked, changed reviewed settlement-writer evidence is blocked, denied attempts do not leak certificate records, no schedule becomes active.

**Cryptographic verification boundary:** This PostgreSQL test passes structurally valid synthetic HMAC hex values while invoking the database function as the isolated test administrator. It proves the SQL writer's source verification and atomic writes, **not** that PostgreSQL itself checks a cryptographic HMAC. The real private Node ingress authenticates independent signing keys using SHA-256 HMAC and was tested separately: https://github.com/bracko87/Airlinerra/actions/runs/44816872073 . The private certificate DB function remains inaccessible to browser, authenticated player and service roles.

## Production implementation

The new migration **was applied to live Airlinerra Supabase** after the isolated SQL test succeeded. Subsequent live read-only checks confirmed:
- The installed certification SQL contains the new `fresh_execution_finance_proof:=` source recheck.
- The prior unconditional rejection branch is replaced, **but currently no source can pass with paused release policies**.
- `anon`, `authenticated` and `service_role` still have **no EXECUTE permission**.
- World 1 `activation=paused`, `execution=disabled`, `finance=paused`.
- Zero `trusted_flight_execution` / `commercial_finance` certification rows and zero event rows.

No player aircraft, bookings, routes, flights, balances or game-release controls were modified.

## Remaining work — do not conflate with release readiness

1. Wire the six older signed clearances + four newly enabled signed-execution/finance clearances through one **real** end-to-end two-leg coordinator and test all ten certificates in a single disposable database, with per-leg replay and negative cases. The existing positive pair activation previously used synthetic certification fixtures.
2. Validate that private signing keys and HMAC ingress and actual transactional source checks are all invoked in the same full lifecycle; the separate isolated tests are not a complete end-to-end proof.
3. Test full round-trip bookable inventory → ticket purchase → signed movement phases → approved fuel/airport costs → exactly-once financial posting, then authorize a carefully controlled production release separately.

Production commercial operations and finance remain disabled. The eight-licence design was not changed.
