# Airlinerra — independent dual-leg certification coordination, 20 November 2026

## Confirmed code change and tests
Successful isolated CI: https://github.com/bracko87/Airlinerra/actions/runs/44807782456

Added `server/section9-roundtrip-certification-coordinator.mjs`, which orchestrates existing issuer implementations for **three independently verified clearance types per flight leg**:
1. `operator_licence` (current in-game operator licence source),
2. `route_traffic_rights` (direction-specific rights),
3. `airport_slot_capacity` (reservation-capacity proof).

It processes separate immutable schedule IDs and versions for the outbound FRA–MUC and return MUC–FRA legs. Issuers use distinct HMAC signing secrets; `section9-signed-certification-ingress.mjs` verifies each HMAC before the mocked database sink accepts the event. The coordinator **never** creates the four missing authority certifications, enables schedules, opens tickets, posts revenue or returns a 'certification complete' flag.

A small compatibility fix adds the explicit fixed `clearanceType: 'airport_slot_capacity'` to the existing slot issuer instance, allowing the coordinator to reject mismatched issuer objects. Existing issuer behavior and permissions are otherwise unchanged.

`tests/test_section9_roundtrip_certification_coordinator.mjs` verifies:
- six distinct signed issuer/ingress events across the two schedule identities with independent operator/route/slot source readers;
- return-direction route-rights refusal cannot reuse outbound proof;
- outbound airport-slot refusal stops before any return-leg evidence call;
- replayed certification receipts are not treated as flight activation;
- mismatched schedule identity, invalid game dates, identical outbound/return IDs and incomplete private dependencies are rejected;
- all outputs remain `certificationComplete=false`, `scheduleActivated=false`, `bookingsCreated=false`, `ledgerPosted=false`.

The GitHub workflow `.github/workflows/section9-roundtrip-certification-issuers-ci.yml` runs the new combined tests alongside the existing issuer and ingress suites.

## Verified live deployment facts

Read-only Supabase check: World 1 activation release remains **paused**. There are no rows in the current `section9_schedule_operational_certifications_v1` table, so no claim is made that six real clearances were issued. The tests use actual JS HMAC issuers with synthetic database proof responses, not live operational certificates.

## Remaining exact blockers

The actual pair activation function requires **five non-crew certifications on each leg**, a total of ten:
- operator_licence: existing issuer + source verifier;
- route_traffic_rights: existing issuer + source verifier;
- airport_slot_capacity: existing issuer + source verifier;
- trusted_flight_execution: **independent issuer/source producer is not yet integrated**;
- commercial_finance: **independent issuer/source producer is not yet integrated**.

Consequently, this new coordinator can cover only **six of ten possible clearances** in tests and must remain fail-closed. It cannot activate a commercial service without independent trusted execution and finance certifications. Actual production issuance of AOC and route rights and authentic slot reservation review remain gated by separate release policies.

### Next milestone

Implement an independent private verifier/source proof and signed issuer for `trusted_flight_execution`, then for `commercial_finance`, with separate signing secrets and SQL re-verification at ingestion. Validate both across FRA–MUC and MUC–FRA, including revocation, stale schedule, owner/aircraft mismatch, slot unavailability and release rollback, before running actual full-stack disposable activation-to-settlement. No production World 1 release flags should be switched on without independent operational approval.
