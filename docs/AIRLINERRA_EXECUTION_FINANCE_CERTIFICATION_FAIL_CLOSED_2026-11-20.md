# Airlinerra — missing flight-execution and finance certificates: fail-closed database patch

20 November 2026

## Production bug discovered and fixed

The live implementation of `airlinerra_game.section9_record_verified_certification_event_v1` contained a fallback `ELSE ... eligible:=true;` for two clearance types that do **not** have independent, released source verifiers:

- `trusted_flight_execution`
- `commercial_finance`

Although the private Node ingress requires a valid HMAC, that alone is not sufficient to establish live aircraft, schedule, slot or financial-engine readiness. Unlike the licence/traffic-rights/airport-slot branches, these two clearance types were **not** rechecked against an independently verified database source in the same certification transaction.

## Implementation

Migration: `supabase/migrations/20261120211500_section9_unreleased_execution_finance_certification_fail_closed.sql`.

The migration reads the currently installed PostgreSQL function definition, checks for the expected original fallback exactly once and replaces it with an explicit SQLSTATE 42501 rejection:

`SECTION9_UNRELEASED_EXECUTION_OR_FINANCE_CERTIFICATION`

If a different deployed definition is encountered, migration aborts rather than blindly overwriting newer source logic. It is idempotent on a patched function and reasserts that public, player and service roles cannot call the certification sink.

**Applied to Airlinerra production Supabase.** Verified via read-only SQL on deployed function source:
- `future_authority_fail_closed = true`
- `still_contains_fail_open = false`
- `anon_execute = false`
- `authenticated_execute = false`
- `service_role_execute = false`
- World 1 activation policy remains `paused`.

The migration does not grant licences, create certifications, release commercial flights, change a player account or post money.

## Automated tests

`tests/test_section9_unreleased_certification_fail_closed.mjs` checks the replacement target, explicit rejection, guarded migration, public privilege revocation and no operation/finance mutation statements.

The existing real issuer coordination, slot and source-signature tests run together with the patch regression:

https://github.com/bracko87/Airlinerra/actions/runs/44809208644

**No real execution/finance certification was issued.** The two missing independent services remain to be built.

## Next implementation milestone

Implement **independently sourced** `trusted_flight_execution` and `commercial_finance` proof readers that use authoritative game clock, persisted owned aircraft and schedule, verified slot/route rights, approved signed flight producer release and released game fuel/finance model. Then create two separately keyed backend certification issuer services. Only after the same-transaction PostgreSQL source rechecks are implemented should the explicit rejection be replaced. Validate real source denial in production while flags are paused and affirmative synthetic proofs in disposable PostgreSQL. The existing three issuers remain in use.

The eight-licence framework, Group 2 hold and production commercial release gates remain unchanged.
