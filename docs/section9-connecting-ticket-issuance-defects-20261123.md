# Airlinerra connecting-ticket issuance — verified isolated defect report (2026-11-23)

## Affected production function

`airlinerra_game.section9_issue_verified_demand_hold_tickets_v1(text)`

Source in `supabase/migrations/20261113224000_section9_trusted_demand_hold_to_ticket_bridge_v1.sql`, deployed version inspected previously in the connected production database.

## Finding 1: Ambiguous PL/pgSQL reservation_key identifier

The function declares `reservation_key text` and later queries:

`WHERE b.occurrence_id=flight.id AND b.reservation_key=reservation_key`

PostgreSQL cannot determine whether the last identifier is the column or the PL/pgSQL variable. Real unchanged source, installed only in disposable PostgreSQL 17, produced SQLSTATE `42702` (ambiguous column reference), before any two-leg tickets were written.

Isolated candidate repair: rename the local variable to `v_reservation_key` in its declaration, assignment, comparison and insert values. **Do not change** the table column name.

## Finding 2: Existing seats are double-counted when replaying issued holds

The function checks `inv.passengers_held<flight.booked_seats+h.passengers` before it checks for an existing reservation batch. Once both tickets have been issued, the held seats already correspond to `flight.booked_seats`; replay incorrectly requires those same seats a second time and raises `SECTION9_DEMAND_HOLD_VS_TICKET_INVENTORY_CONFLICT`.

Isolated candidate repair: when the matching reservation batch already exists, permit the later replay validation path to evaluate it instead of treating the booking as new capacity demand. The existing later replay checks still reject altered fare class, seats, fare or booking status.

## Test results and scope

The CI workflow installs the **unchanged** migration function first and explicitly demonstrates finding 1 (no partial tickets). Then it installs an **isolated patched candidate** (only the identifier and hold/replay check differ) and tests:

- Forced failure on second leg: no reservation rows and no partial booked-seat increments
- Successful two-leg issuance: exactly one reserved ticket per leg and consistent held seats
- Replaying the same itinerary: zero additional tickets or seats
- No upfront charge, recognized revenue or ledger posting

The underlying flight, inventory, hold and plan objects are synthetic test fixtures. The corrected candidate is **not** deployed and is **not** proof of production readiness. Do not enable active-flight cancellation or player-facing rescheduling.

## Required before production fix

1. Review current deployed function and any later database migrations that replace it.
2. Produce and review a proper Supabase migration for both corrections, respecting function grants and private-worker restrictions.
3. Test direct bookings and two-leg issuance together against representative isolation and concurrency fixtures.
4. Verify automatic-demand and original issuance worker paths, including lock order, refund policy and history preservation.
5. Apply migrations only through the approved release process, with rollback and monitoring.

No production SQL was changed in this investigation.

## Review-only candidate ready for approval (2026-11-23)

- Candidate SQL: `supabase/migration_candidates/20261123_section9_connecting_ticket_issuance_private_worker_review.sql`
- The candidate is intentionally **outside** `supabase/migrations/` so deployment tooling cannot auto-apply it.
- It checks the pre-existing worker definition, rejects unexpectedly public/client execution grants, and retains the private `postgres` worker restriction.
- CI installs the original function first, reproduces the ambiguous identifier, then applies the **checked-in** candidate SQL in disposable PostgreSQL.
- Candidate verification includes two-leg issuance, deliberate second-leg failure and full rollback, replay without additional tickets, rejection of a modified ticket record, and verification that `anon`, `authenticated`, and `service_role` cannot execute the worker.
- Verified GitHub Actions run: https://github.com/bracko87/Airlinerra/actions/runs/45182867604 (both jobs successful).

Before release: confirm production function has not drifted, review with database owner, generate the actual migration using the Supabase CLI, evaluate automatic-demand workers and concurrent connecting-journey issuance, and schedule rollout monitoring. Do **not** use the candidate alone as approval for active-flight cancellation.
