# Section 9 — game permission application, issuance and expiry lifecycle

## Built 9 November 2026

This milestone creates the **durable private game-licence application engine**. The **existing catalogue-wide `enabled_in_game=false` CHECK remains**: no real application is accepted, no fee is charged and no game permission is issued until a separately approved game release and pricing configuration exist.

### Game model

The licence and route-permission reference catalogue stays research/reference-only. Operators apply for **game** permissions, not actual government licences. The private policy table `section9_game_permission_issuance_policy_v1` requires explicitly set release flag, reviewer, release reference, validity in game days and version; **no policy row was seeded**. The existing catalogue must also be explicitly enabled with nonzero USD fee and a 1–90-game-day processing duration. No fees or validity durations were guessed or set during this rollout.

### Application flow

`section9_submit_game_permission_application_v1(player,airline,request_key,permission_code,origin,destination,service_type)`

- Requires actual airline ownership, an opened World 1 and the current independently signed game-day clock/tick.
- Allows an operator-certificate application only in the carrier's home jurisdiction; route applications are directional and service-specific.
- A route applicant must already hold an independently **issued** (and still valid) game operator licence, and the relevant game right must match the existing legal reference classification. The reference alone never grants a route.
- Snapshots the configured, released permission code, exact price, processing days, validity, policy revision, applicant and jurisdiction/route. The request key and per-scope pending index prevent duplicate and simultaneous pending submissions.
- Records `submitted` and a future game-day review date **without charging cash**. A rejected application never costs money.
- Supports owner-scoped private listing of applications, including pending/issued/rejected/revoked/expired status, due game day and whether a fee was posted.

### Independent review and exactly-once fee settlement

`section9_decide_game_permission_application_v1(application,event,decision,reviewer,verified_hmac,game_day)`

- Private-only SQL sink for **separately signed decisions**, one `approve`, `reject` or `revoke` event at a time. The Node ingress validates HMAC with a dedicated **independent reviewer secret**, which is never stored in PostgreSQL or committed.
- Locks the airline row **before** the application row, preventing two fee charges or money races between concurrent reviews. An exact event replay returns read-only; conflicting event IDs fail.
- Checks current signed game clock, due day, unchanged released pricing/policy/version, jurisdiction, game legal classification, and a still-valid, issued operator licence for route grants.
- Approval checks cash and, **in one database transaction**, deducts the exact application fee, posts a single negative `EXPENSE` ledger row, changes the application to `issued`, sets game-day validity and upserts the existing verified operator or route evidence row with a foreign key to the source application.
- Rejection changes status without a cash or ledger write.
- Revocation invalidates the actual issued game evidence and does not refund a previously issued fee. All cached activation preparations for the airline are invalidated.
- Append-only private signed review audit prevents rewriting historical decisions.
- The current game-licence and route-rights verifiers were strengthened to require that the `verified` evidence is linked to an actual `issued` application and its ledger transaction, not just a manually set `verified` flag.

### Expiration

`section9_expire_game_permissions_batch_v1(limit)` checks the verified current World 1 game day, takes bounded `SKIP LOCKED` batches and expires grants **only once they have passed their configured validity date**. It revokes matching in-game evidence and invalidates stale activation preparations. The permission source-verifier already rejects expired evidence even before the batch is run.

The backend module `server/section9-game-permission-application-service.mjs` has three private adapters: application/list under verified player-session identity, independently signed review ingress, and a bounded expiration worker. **They are not attached to the player HTTP API or a production cron yet**; no privileged HMAC key was configured or deployed.

## Testing

Rollback-only Supabase acceptance passed for: closed world blocks, mismatched owner blocks, a simulated signed day does **not** override the disabled catalogue, application key replay, synthetic blocked approval no money, no-charge rejection, replay/no second ledger, conflicting review event and no unintended movements or aircraft positions. Temporary fixture rows were rolled back.

Focused Node tests cover fake identity, malformed scopes, positive **mock** application issuance and signed review with ledger confirmation, independent HMAC/edited payload rejection, revoked/rejected/replay responses, blocked-policy outcomes, bounded expiry and no unsafe cash/movement responses.

**Positive real-money issuance was not executed**, because that would require temporarily relaxing a protected production permission constraint and configuring non-approved prices. These safety guards are intentionally unchanged. A separate staging or approved release procedure must test that complete positive path before enabling players.

## Still needed before players can use it

- Decide and configure in-game fees, processing durations, permission-validity terms and explicit game-release policy. Existing hard `enabled_in_game=false` catalogue restriction must be relaxed in a separately reviewed, tested release migration **only when** the rules and signing services are deployed. This PR does not do it.
- Implement and deploy a real independent application reviewer/decision producer with protected HMAC key and revocation process. Integrate a player route with the existing verified Supabase Edge Function and status UI. Never trust a browser-submitted owner ID or signed reviewer decision.
- Privately schedule the bounded expiration worker from verified game-day ticks.
- Independently complete crew, flight operations, commercial settlement and atomic commercial flight activation; then integrated positive and concurrency/load tests.

World 1 remains planned; no active flight schedules, aircraft movements, or real application fees have been generated.
