# Airlinerra FRA–MUC — trusted flight execution gate, 20 November 2026

## What was completed
The existing *private* `server/section9-live-game-flight-runner.mjs` no longer chooses due-flight dates from a bare PostgreSQL UTC clock without first checking a signed World 1 game-hour source.

It now queries the already-implemented `airlinerra_game.section9_verified_berlin_game_hour_v1()` and requires all of:
- `status='verified_berlin_realtime_hour'`, `worldId=1`, `authoritativeGameHourAvailable=true`;
- `readOnly=true`, `flightActivated=false`, `movementRecorded=false`, `ledgerPosted=false`;
- valid official `gameDate` exactly matching verified `berlinDate`;
- a parseable authoritative `gameHourUtc` with a real UTC offset. The due-operation lookup uses the **UTC date of this independently verified hour**, not the Berlin local date; for instance Berlin 00:30 on 12 Nov is UTC 23:30 on 11 Nov.
- If any proof is stale, missing, malformed or inconsistent, the worker returns `flight_execution_unverified_game_hour` **before** reading a fleet, requesting flight attestations, or writing movements.

This is an operational safety integration, not a new clock implementation. The database's verified-hour function independently checks the world opening, signed daily receipt, World 1 clock and authorized producer status. The flight runner continues to use private attestation and movement-ingress HMACs, and never creates bookings or posts a ledger entry.

## Verification
- Regression tests for missing, denied, stale, wrong-world and malformed hour proofs.
- Berlin-midnight versus UTC-date regression while retaining correct due-occurrence lookups.
- `flight-phase-execution-ci.yml` completed successfully at https://github.com/bracko87/Airlinerra/actions/runs/44774656985 .
- Read-only World 1 database proof (20 November): `verified_berlin_realtime_hour`, `gameDate=2026-11-20`, `authoritativeGameHourAvailable=true`.
- Production activation state was `paused`, trusted execution `disabled`, finance posting `paused`. This work did not change release flags, register flights, move aircraft, open seats, post tickets or debit airlines.

## Still required for real commercial flights
1. Actual independently certified airline, owned aircraft, persisted schedule version and local airport/slot eligibility. The FRA–MUC airports are individually authorized, but that does not issue flight approvals.
2. Atomic activation of real flight occurrences after all independently signed certificate checks and engine releases.
3. Ticket capacity, booking generation and passenger demand tied to signed occurrences.
4. Verified departure AND arrival, trusted flight-position and fuel consumption, and completed-flight-only exactly-once revenue/cost settlement.
5. Isolated fixture end-to-end verification across the complete financial path; then production controlled release after independent evidence and owner approval.

The existing eight-licence framework and Group 2 aircraft/airport authorization holds remain unchanged.
