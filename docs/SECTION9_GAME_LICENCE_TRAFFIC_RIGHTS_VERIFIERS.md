# Section 9 — game operator-licence and route-traffic-rights verifiers

## Implemented on 9 November 2026

This change adds the next **two sources of independent game operational clearance**, following the signed certification ingress and game-slot verifier. They are server-only and fail closed. It does **not** enable any licence, create applications, approve players, turn on the world or activate flights.

### 1. Operator game licence

Private PostgreSQL function:

`airlinerra_game.section9_verify_game_operator_licence_v1(airline, schedule, expected_version, game_day)`

It verifies:

- The exact World 1 airline, existing draft schedule and schedule version.
- A World 1 game opening plus the authoritative confirmed game date and signed game-day receipt.
- A known, valid operator jurisdiction from the airline's **home airport country** (not the route origin).
- An in-service aircraft with unchanged configuration.
- The `AIR_OPERATOR_CERTIFICATE` game catalogue entry must be **explicitly enabled**, scoped to airline operating companies and have a configured non-null game fee and processing time.
- A matching operator's game licence evidence row must be `verified`, independently reviewed, with a nonempty evidence reference, and valid through the entire next 28 game days. Unverified, revoked or expired records do not qualify.
- Only then can it emit a deterministic version- and game-day-bound `verified_game_operator_licence` proof. A source proof is **not legal authority** and **not a flight**.

**Current state:** the business permission catalogue has a hard database constraint `enabled_in_game=false`, and `AIR_OPERATOR_CERTIFICATE` has no game fee or processing time. It is **not possible to issue the licence yet**; the verifier intentionally returns `GAME_OPERATOR_LICENCE_ISSUANCE_DISABLED`.

### 2. Route traffic-rights game grants

Private PostgreSQL function:

`airlinerra_game.section9_verify_game_route_traffic_rights_v1(airline, schedule, expected_version, game_day)`

It requires the operator-game-licence proof from the first source. It checks the exact origin and destination countries, distinguishes passenger, cargo and combi aircraft, and requires individual verified game grants for **every applicable service type** (both passenger and cargo for combi).

Existing `aviation_route_rights_preview_v1` data classifies the relevant legal context (domestic, integrated EEA market, third/fourth freedom, seventh freedom or cabotage). Its `operationally_authorized=false` result is **reference-only**, not an airline permission. The new verifier treats explicit forbidden/unknown cases as blocks. A right is only accepted when a matching route-specific, service-specific private game grant is verified, has full 28-game-day validity, and its applicable `business_permission_catalog_v1` entry is actually enabled and configured with a fee and processing days.

Where the existing legal preview cannot reliably classify a required right (including some fifth/seventh-freedom itineraries), the verifier **fails closed** instead of inventing legal permissions or bypassing route-specific authorization.

**Current state:** all traffic-rights catalogue entries are disabled, so route traffic rights cannot be certified yet.

### 3. Signed independent issuing service

`server/section9-game-permission-verifier-issuer.mjs`

- Requires a private DB connection, one **dedicated signing secret per clearance type**, and the corresponding existing independently signed certification ingress.
- Reads a current private source proof and checks exact airline, schedule version, game day, 28-game-day horizon, verifier type, immutable proof fingerprint and no movement/financial side effects.
- Signs only a fully verified proof, then sends a deterministic certification event through the existing signed audit/approval service. Replays remain idempotent and do not manufacture fresh approvals.
- The private certification SQL sink **recalculates each underlying proof in its own write transaction** and matches exact source and reviewer reference. A stale HMAC event cannot certify newly revoked evidence.
- The activation-preparation function now **re-verifies both current licence and route-rights source proofs**, matching their current fingerprints against the accepted signed certificates. A change in the underlying evidence or game catalogue invalidates readiness even if the old event is still present.
- No secrets were configured or deployed and no player-facing HTTP, Cron or application endpoint was added.

### Testing and limitations

Rollback-only live Supabase acceptance checked an unopened world, stale draft, synthetic 'verified' evidence without an enabled licence, route-rights dependency on the operator licence, forged signed-certificate attempts, and rejection at activation preparation. All temporary records were rolled back; no active flights, movements, bookings or money were created.

Node regression tests include positive **mock-proofs** for both independent signature paths, distinct secrets, separate passenger/cargo coverage, cross-schedule invalid identity and signature/data tampering, unavailable database, blocked game settings, replay and refusal of any fake activation/ledger result. The mock positive path **is not a real game licence issuance** or a real positive production flight test.

The draft-only database flight constraint and the game catalogue's `enabled_in_game=false` hard constraint remain unchanged. This deliberately prevents accidental commercial flight activation.

## What is next

1. Implement the player-facing **game licence application/issuance lifecycle**, including eligibility requirements, in-game processing time, fees, game balance posting, issuance, expiry and revocation. Only when ready should administrators explicitly enable the appropriate game catalogue entries.
2. Connect the independent crew-duty/rest authority, real flight-execution decision producer and commercial settlement verifier, each with its own protected signing key.
3. Implement the final atomic activation commit, with fresh six-source verification under lock, and positive end-to-end staging tests.
4. Run actual 500-player/multiworker simulated game-load and recovery testing. Route-planning mock tests are not sufficient for that.
