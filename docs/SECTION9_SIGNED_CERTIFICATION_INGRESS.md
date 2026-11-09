# Section 9 — independent signed certification events and revocation

## Implemented

A private `section9_operational_certification_events_v1` audit table and `section9_record_verified_certification_event_v1` stored procedure now provide a durable certification event sink for **six distinct independent verifier types**:

| Clearance | Verifier |
|---|---|
| Crew duty and rest | `verified_crew_duty_engine` |
| Game operator licence | `verified_game_licence_engine` |
| Route traffic rights | `verified_game_traffic_rights_engine` |
| Weekly airport slots | `verified_airport_slot_engine` |
| Trusted aircraft operations | `trusted_flight_operations_engine` |
| Commercial bookings and settlement | `verified_commercial_settlement_engine` |

The new backend-only `server/section9-signed-certification-ingress.mjs` **only verifies independently signed decisions**, using a private HMAC key specific to one verifier type. It cannot itself manufacture evidence or activate a flight. It requires a server-side PostgreSQL connection and never handles browser requests.

The signed payload binds World 1, airline, schedule, exact schedule version, clearance type, canonical verifier type, decision (certify/revoke), unique event ID, evidence references and game-date validity window. Invalid payload, wrong source, modified or replay-conflicting signatures are rejected before SQL. Each event is accepted atomically with the authoritative certificate row under a schedule lock.

### Revocation and replay

- Global unique event IDs prevent conflicting duplicates.
- Exact replays are **read-only** and cannot restore a previously revoked certificate.
- An append-only PostgreSQL trigger blocks UPDATE and DELETE of audit events.
- New certified/revoked decisions invalidate the schedule's cached activation preparation immediately.
- Game crew, licence, route and slot approvals additionally require existing verified game evidence to match.
- The six certificate rows are counted toward activation **only when they match their latest append-only signed `certify` event**, including exact schedule, verifier, evidence, dates and recorded timestamp. A directly inserted `review_status='certified'` record without its signed audit event does not count.

### Important trust boundary

The **Node service verifies HMAC signatures**. PostgreSQL receives a verified digest and performs ownership, evidence, chronology, replay and state checks; it does **not independently know the six HMAC secrets**. For security, access to the SQL sink must remain restricted to the protected verified-ingress service and privileged DB infrastructure. The browser roles have no SQL EXECUTE or table write grants.

No signing keys have been generated, deployed, stored in the repository or supplied as production credentials. No certification producer has been wired to call this service. Thus this is the **trusted ingress and audit foundation**, not an assertion that any real crew, licence, flight execution or commercial finance has been independently certified.

## Tests

- Live Supabase migration installed on 9 November 2026.
- Rollback-only SQL acceptance proves: browser-role denial; stale schedule version rejection; missing operator evidence rejection; inability to revoke a nonexistent certificate; unique source-event replay and collision handling; immutable audit records; revocation invalidates preparation; replay does not resurrect revoked status; and **six unsigned certificate rows count as zero** for activation preparation.
- Node tests cover independent per-source signatures, source isolation, tampering, invalid game dates, separate revocation signatures, idempotent replay, database failure and unsafe-response refusal.
- Focused CI runs Node syntax, all existing tests and the complete private website build. No production activation/booking/movement or ledger changes were made.

## Next steps before flight operations

1. Implement and configure each actual independent game verifier, using six separate protected signing secrets, valid game evidence and strict issuer permissions.
2. Revalidate all six signed, non-revoked, unexpired proofs and the evidence fingerprint in the **atomic commercial activation commit**; keep existing draft-only constraints until this is fully proven.
3. Connect trusted aircraft-operation decisions to the durable leased dispatcher, then passenger/cargo allocation and exactly-once booking/expense settlement.
4. Verify actual positive end-to-end activation and operated-flight transactions in an isolated rollback or staging world, concurrent worker recovery, and realistic 500-player load.

World 1 remains planned and **no real flights are active**.
