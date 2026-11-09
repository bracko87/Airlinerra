# Section 9 — authenticated player permission applications and status UI

## Added in this milestone

- `server/section9-permission-player-http.mjs` is a strictly same-origin, POST-only, two-action (`status` / `apply`) handler. It requires a verified Supabase Auth user from the hosted Auth server, verifies airline ownership inside the private PostgreSQL functions, and rejects all browser-supplied owner IDs, review, approve, reject or revoke actions.
- `server/section9-permission-player-edge-entry.ts` uses the existing built-in Supabase database connection and the project's existing non-privileged publishable Auth key. It delegates to the private handler. No decision signer or administrator secret is bundled.
- `server/production-game-api.mjs` forwards the single player path `/api/v1/player/permission-applications` to its isolated Edge Function through the existing Netlify same-origin gateway.
- `website/game-permission-applications-client.mjs` has a typed, authenticated browser `status` and `apply` API. It rejects forged application/fee/flight states and never uses database credentials.
- `website/game-permission-applications-view.mjs` and `website/private-player-app.html` render a compact 'My applications' panel **above** the existing licence planner, following the same cards/layout as other player pages. The panel shows signed-game-date status, application progress, recorded fees and active issued permissions from the authoritative API. A separate form supports game operator and directional route rights requests; buttons are disabled unless the server publishes the corresponding open game policy and verified clock.
- There is **no** player approval, fee adjustment, revocation, review-signature, flight activation or money-write endpoint.

### Current production release gate

At the time this integration was authored, World 1 remained **planned**, with the game permission catalogue constrained to `enabled_in_game=false`, zero released price/validity policies, zero licence applications, zero independent reviews, zero issued game licences or route grants, and no active flight. The protected application SQL refuses to accept applications without a current independently signed game day and an administrator-released permission policy. Thus the page shows **Applications not open** and does not invent a price or a processing time. The licence planner's current prices are PROPOSALS, not authority for an in-game charge.

This change does **not** activate the commercial release, configure arbitrary price levels, weaken catalogue constraints, or enable an independent approval worker.

### Verification

- Node tests exercise bearer requirements, exact same-origin routing, unauthorized airline ownership, forged approval actions, closed-world policy, fee disclosure rules, browser-side state checks and safe application data.
- The GitHub focused game CI checks server/browser syntax and the full private website build.
- The isolated Edge Function requires authenticated hosted user verification and private database ownership checks, even though Supabase's platform-level JWT flag follows the preexisting project's custom authenticated Edge pattern.
- Test mocks do not constitute positive production applications or paid approvals. Real-world legal/licensing reference information remains informational.

### Still required

1. Review and configure balanced game costs, processing times and validity for each permission. The current planning includes some no-fee market entitlements, while the first issuance engine requires strictly positive fees: **reconcile these rules before releasing the catalogue**. Do not charge a player for a permission intended to be free.
2. Deploy a separately authorized review/approval producer with independent HMAC key and audited eligibility checks. The player endpoint MUST NEVER accept review decisions.
3. Connect expiry worker to the signed World 1 game-day scheduler and add monitoring. Test paid AND no-fee positive lifecycles in staging with transaction rollback, retries, races and cash reconciliation.
4. Complete independent crew and actual-flight verification, commercial booking/settlement and atomic schedule activation before opening World 1.

The existing draft-only flight schedule constraints remain intact.
