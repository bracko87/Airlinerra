# Phase 14V — release readiness, 2026-11-22

Decision: keep all new crew and dynamic-turnaround execution switches disabled. No production route or deployment created.

## Verified

- Integrated residual crew recovery, signed movement verification, actual turnaround, occupied aircraft minutes, real ticket reconciliation, clock verification and exact-once finance posting: `tests/sql/section9_recovered_crew_ticket_clock_finance_acceptance.sql` passed. In a rolled-back isolated schema, 200 reserved seats generated $20,000 revenue; $9,900 expenses included $2,100 external crew, leaving $10,100 net. Invalid HMAC, stale clock, mismatched ticket count and wrong contractor cost denied; replay no additional accounting. The fixture injects deterministic time, authoritative clock records, signed synthetic movement records and approved fuel/airport costs; it does not generate these through the real dispatcher.
- Prior isolated turnaround, utilization, internal and external recovery tests passed in Phase 14U/T.
- Live World 1 verified Berlin clock; dispatcher and clock each had 60 successful runs with 0 failures in the checked hour; postarrival and final finance each had 6 successes with 0 failures. Job completion is not proof of a dispatched flight.
- 17 inspected recovery/dispatch/finance helpers were private invoker functions, not executable by anon, authenticated or service_role.
- Zero saleable commercial occurrences, zero current crew plans and zero posted flight settlements at audit. All new release switches disabled. Fixture schema removed.

## Release blockers / scope limits

1. Complete one disposable-world end-to-end scheduler acceptance using actual certification, dated occurrence/capacity, ticket batches, signed dispatch writer, fuel supply/custody, movement, arrival usage, crew binding, dynamic turnaround, postarrival cost approval and settlement jobs. No stubs at the dispatch/financial proof boundaries. Test an independently valid flight while another flight is held; verify one failure cannot roll back an unrelated flight. Do not create test flights in live World 1.
2. Prove initial crew plan creation and rolling coverage for a real activated schedule before enforcing new crew-aware dispatch. Current activation crew mode is deferred_phase1, not global crew enforcement, and there are no current crew plans.
3. Rotation replacement supports one remaining onward sector; more complex changed rotations remain held. Validate or explicitly accept this scope before release. Cancellation, later revision and release of staged residual commitments need explicit lifecycle acceptance; a stranded commitment must not indefinitely block unrelated planning.
4. Confirm recovery lock/commitment behavior and duplicated/replayed events with actual scheduler transactions. Strict delayed/downstream binding failures currently raise and roll back the dispatch call; verify per-event isolation before enabling.
5. Review the combined feature branch and migration ordering, production gate dependency/rollback plan, then obtain explicit activation approval. Do not deploy Netlify as part of this acceptance.

This document is not a release authorization.