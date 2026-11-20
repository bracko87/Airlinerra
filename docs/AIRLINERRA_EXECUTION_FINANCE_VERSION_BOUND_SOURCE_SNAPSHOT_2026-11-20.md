# Airlinerra — version-bound execution/finance source snapshots (20 Nov 2026)

## Actual implementation

**Production SQL function installed:** `airlinerra_game.section9_execution_finance_source_snapshot_v1(airline, schedule, version, game_day, clearance_type)`

Migration: `supabase/migrations/20261120224500_section9_execution_finance_source_snapshot_candidates.sql`.

Unlike the previous diagnostics-only preflight, this new private read-only function creates a **candidate source fingerprint from the current persisted operational facts** when all checked prerequisites pass. Those source facts include the exact draft schedule and version, owning airline and aircraft, aircraft configuration, route endpoints, UTC times, weekly schedule, reviewed execution/activation release references, fuel/settlement release proof references, and (for commercial finance) the approved finance release reference.

It composes the previous independent source preflight rather than trusting caller-supplied fields. The preflight requires the signed-verified Berlin game date, fuel model, aircraft eligibility and three existing signed certification audit records. The new function checks further that the separate fuel + settlement release policy has independent execution producer, fuel writer and settlement writer references.

When all inputs pass, it returns `source_snapshot_candidate_not_authorized`, a deterministic MD5 fingerprint of source state, and the corresponding candidate reference. **It never returns `verified=true`, `certificateIssued=true` or `sourceAuthorityReleased=true`.** If any prerequisite is missing, it returns a blocked status and null fingerprint. No signature is created. The production signed-certification sink still explicitly refuses both missing certificate types.

## Verified live result

After applying the migration, a deliberately nonexistent synthetic FRA–MUC schedule ID with World 1 release paused returned:
- `blocked_unreleased_execution_finance_source_snapshot`;
- blockers for paused commercial activation, trusted execution not released, fuel engine not activated, missing saved draft/version;
- `candidateReady=false`;
- `sourceFingerprint=null`, `sourceReference=null`;
- `verified=false`, `certificateIssued=false`, `sourceAuthorityReleased=false`, `ledgerPosted=false`.

SQL privileges for `anon`, `authenticated` and `service_role` were confirmed false.

## Code and regression verification

- `server/section9-execution-finance-snapshot-reader.mjs`: requires exact scope identity, correct ready/blocked fingerprint format, forbids pretending candidate evidence is an issued certificate, releases the DB connection on error.
- `tests/test_section9_execution_finance_snapshot_reader.mjs`: includes synthetic ready and blocked response validation, fake-approval rejection, date/identity invalidation, private SQL contract.
- CI success: https://github.com/bracko87/Airlinerra/actions/runs/44813989826

## Remaining boundaries

A positive candidate output was tested through the Node reader's synthetic response contract, **not yet through a fully populated disposable PostgreSQL database with all release/source evidence**. The live database remains blocked, correctly. The fingerprint is a state-change identifier, **not a cryptographic signature of issuer authority or authorization to launch a flight**. It must never be accepted directly by the signing ingress. Two genuinely independent positive signers, separate private keys and same-transaction database source re-verification remain to implement. The complete ten-certification FRA–MUC roundtrip and real full lifecycle test are still pending.

No production release flags, licences, flights, bookings or player balances were altered.
