# Section 9 — private schedule activation certification preparation

## Completed

The World 1 database now contains a **private, version-fenced certification preparation transaction**:

`airlinerra_game.section9_prepare_certified_schedule_activation_v1(player, airline, schedule, expected_version, game_date, days)`

It is **not** a flight activation transaction. It can only store a prepared evidence snapshot for an independently certified, explicitly released schedule, and it leaves the existing hard database constraints `status='draft'` and `operationally_verified=false` untouched.

The transaction checks all of the following together:
- Authenticated-player ownership and exact, currently editable schedule version under an exclusive schedule and aircraft row lock.
- World 1's independently opened state, current signed in-game date and verified tick receipt.
- An independent administrator-controlled commercial release record. **There is no release row installed or enabled by this migration.**
- Six separate independently sourced, version-scoped, time-limited operational certificates: crew duty and qualifications; game operator licence; route traffic rights; departure/arrival slot capacity; trusted operated-flight execution service; and commercial revenue/expenses settlement service.
- The current Section 9 operational readiness and Section 5 airport restrictions preview, conflicts across the aircraft's weekly timetable, delivery anchor, physical position, crew assignments and provisional rest checks.
- Actual weekly slot reservations must match the schedule's generated recurring slot set, and the available airport capacity is checked again excluding the schedule's own existing reservation.

Only if all checks pass does a private preparation row store the exact schedule version, game date, active release reference and fingerprint of the detailed schedule, aircraft, crew, evidence, slot and certified source rows. The fingerprint is an ordinary MD5 change detector; it is **not** a signature or a substitute for independent source authorization.

The source-only `server/section9-activation-preparation-service.mjs` requires an injected independently trusted release authority and checks the database outcome. It has no browser route, cron endpoint or live activation action.

## Validation

- Applied the new private schema and function to the existing Airlinerra Supabase project on 2026-11-09.
- Rollback-only test with an actual synthetic draft proved wrong player ownership and stale version rejection.
- When the world is still planned and six independent certificates are missing, the call returns `blocked_activation_preparation`, `prepared=false`, `flightActivated=false`, `movementRecorded=false`, `bookingsCreated=false`, `ledgerPosted=false`.
- Browser roles have no `EXECUTE` privileges on preparation or access to release/certificate tables.
- No real release or certification was created, and no aircraft movement, booking, ledger entry or active flight was generated.
- Node tests cover malformed requests, independent authority refusal, correct owner derivation, no activation despite a positive preparation flag, and invalid database responses.
- CI runs syntax checks, Node tests and website build; this document does not claim a positive real activation test.

## Remaining work

The actual commercial activation commit still requires the six *independent real verifier services* to be implemented and connected, with real approvals/revocation, a trusted operations authority, and settlement operational readiness. A future database migration must implement an atomic, revalidated activation state transition and carefully replace the draft-only constraints only when those services and launch controls are functional. Preparation snapshots must be rechecked at the instant of activation, not trusted as timeless permissions.

The operating engine remains **disabled**. This milestone makes the verification chain and state management ready for the next integration stage without confusing a prepared record with a departed flight. Full 500-player concurrency tests and real operated-flight arrivals remain pending.
