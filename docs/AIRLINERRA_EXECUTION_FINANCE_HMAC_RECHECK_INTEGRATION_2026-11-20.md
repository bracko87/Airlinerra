# Airlinerra — independent HMAC signer and locked SQL source recheck (20 Nov 2026)

## Completed and tested

### Two private HMAC signers
`server/section9-execution-finance-evidence-signer.mjs` implements two distinct private issuer instances:
- `trusted_flight_execution`, with the expected `trusted_flight_operations_engine` source;
- `commercial_finance`, with the expected `verified_commercial_settlement_engine` source.

Each requires an independent private key and a matching existing `createSection9SignedCertificationIngress` instance. It requests the exact canonical PostgreSQL `section9_execution_finance_source_snapshot_v1` record, verifies the airline ID, schedule ID/version, game date, source status, fingerprint format and no-side-effect flags. A blocked snapshot never gets signed. A positive candidate is HMAC-signed using the standard `section9CertificationPayload` and passed to the existing ingress. **The live certification database sink STILL rejects both types**, and the signer reports failure rather than claiming issuance.

`tests/test_section9_execution_finance_evidence_signer.mjs` runs actual Node SHA-256 HMAC and genuine existing ingress verification with disposable simulated DB sinks. It tests both directions, independent key mismatch, tampering, modified identity, malformed dates, blocked source and the real production-style SQL rejection. GitHub Actions **passed:** https://github.com/bracko87/Airlinerra/actions/runs/44816872073.

### Independently recomputed source verification under SQL schedule lock
`supabase/migrations/20261120232000_section9_execution_finance_same_transaction_source_recheck.sql` adds private `section9_recheck_execution_finance_source_reference_v1`.

It locks the exact current schedule/version `FOR SHARE`, calls the previously installed **real** execution/finance source-snapshot function, verifies candidate state, source reference and the type-specific independent reviewer reference. It never inserts a certification, enables flights or posts money. Calls can be made within a single existing SQL certification-write transaction; **this step did not yet wire the recheck into the live certification sink**.

The unchanged snapshot + preflight functions and new recheck ran together in a disposable PostgreSQL 17 database with synthetic persisted flight/signed-clock/approval fixtures. Both positive source types matched; changed reference, wrong reviewer, mutated route destination, revoked route permission and paused execution policy all failed. GitHub Actions **passed:** https://github.com/bracko87/Airlinerra/actions/runs/44816849614.

## Production safety

The new private recheck SQL function was deployed to live Supabase **without changing release flags**. A read-only SQL test using a nonexistent test schedule returned `sourceCandidateMatches=false`, `certificationIssued=false`, `flightActivated=false`, `ledgerPosted=false`. `anon`, `authenticated` and `service_role` lack EXECUTE permission.

The live `section9_record_verified_certification_event_v1` sink still raises `SECTION9_UNRELEASED_EXECUTION_OR_FINANCE_CERTIFICATION`; there are no actual execution or commercial-finance certificate releases. No player flights, bookings, aircraft movements or balances were changed.

## Remaining exact milestone

1. Integrate the new recheck into the **existing certification-write function**, and in disposable PostgreSQL first test both positive source proofs in the same transaction as append-only certificate writes and certificate audit rows.
2. Verify simultaneous release revocation, stale schedule version, changed fingerprint, forged issuer signatures and replay idempotency all fail closed; protect all other existing certifications against regressions.
3. Only then apply the verified certification-sink integration to production, **without** enabling production commercial flight/finance release flags.
4. Test a complete reciprocal pair with ten valid independent certificates and eventually full-flight lifecycle and controlled explicit commercial release approval.

This is a real signed source-verification increment, **not yet complete production flight authorization**.
