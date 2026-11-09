# Section 9 — independent in-game airport slot clearance source

## Implemented — 9 November 2026

**One of the six required operational verifier sources now has concrete game-side checking and private signed issuance code.** It does not activate flights.

### PostgreSQL private source

`section9_verify_slot_clearance_source_v1(airline, schedule, expected_version, game_day)`

- Refuses an unopened World 1 or a game day that lacks both the authoritative signed clock state and a matching verified tick receipt.
- Requires the exact current, editable draft schedule version and in-service aircraft with matching configuration, plus verified passenger/cargo capacity for that schedule version.
- Holds read locks on both airport slot-capacity rows while checking. The existing schedule writer uses update locks on those rows, preventing a slot reservation change from interleaving that check.
- Re-runs the Section 5 airport noise/curfew/runway schedule check; any game hard block, invalid timetable or unresolved restriction review fails closed.
- Recomputes all weekly stand-type slot proposals and requires the stored recurring reservations to match **exactly**, including both missing and extra reserved buckets.
- Rechecks per-10-minute and hourly arrival/departure capacity for both airports, excluding the schedule's own existing reservations.
- Returns a deterministic proof fingerprint of the schedule, verified aircraft capacity, current airport capacity records, exact reservations and restriction screening. It returns `verified=true` only when all checks pass.
- Is `SECURITY INVOKER`, private, with no browser/anon/authenticated EXECUTE grants.

### Independent server-only issuer

`server/section9-game-slot-clearance-issuer.mjs`

- Requires a protected database connection, the **airport-slot authority's own secret**, and the `airport_slot_capacity` signed certification ingress.
- Validates every field of the fresh private proof before producing a deterministic signed event. No proof, no signature and no certification.
- Uses the dedicated Section 9 HMAC payload and sends it to the separate event-ingress verifier. The ingress verifies the signature and invokes the private audit SQL, not the browser.
- The SQL certification sink **recalculates the same slot proof inside the certificate-write transaction** and compares the source and reviewer references. An old signature cannot certify slot evidence that has since changed.
- Signed event replay remains idempotent and revocation remains available through the independent certification event service.
- Does not modify world opening, flight status, passenger/cargo bookings, airport slot reservations, aircraft positions or airline money.

### Verification

- Supabase migrations applied to Airlinerra on 9 November 2026.
- Rollback-only SQL test passed for unopened world, stale schedule version, missing recurring airport reservations, and refusal to record a fake signed slot clearance without reservation evidence. No permanent rows were created.
- Node test suite covers exact HMAC payload, valid proof mapping, blocked world, stale/incorrect proof, duplicate replay, failed SQL, malformed identifiers, and refusal if any component pretends to activate flights or post money.
- Focused CI syntax, Node tests and private website build are part of PR; positive Node test uses **mock verified slot evidence**. There is **no real production positive slot-clearance**, because World 1 remains planned and has no operating schedules.
- Signing credentials were not generated or deployed; no automatic Cron or user-facing route was created.

## Remaining work

Five independent authority sources still need real game implementations and integration: crew certification, operator licensing, route traffic permissions, actual flight-operation execution, and commercial booking/settlement. Airport slot authority itself requires secured secret configuration and a private scheduler at launch.

The final activation transaction must revalidate all six signed and non-revoked certificates atomically with the schedule version, aircraft placement, restrictions, game clock and slot/crew rights, before enabling status changes. Preserve the existing draft-only hard database constraints until real execution and settlement are reliable. Full 500-player live-like load testing remains pending.
