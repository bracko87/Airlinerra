# Airlinerra — Platform foundation, identity and game-world architecture
**Date:** 2026-10-26  
**Status:** implementation plan / proposed operational defaults; not a production launch authorization  
**Repository:** `bracko87/Airlinerra` — **main only**  
**Current Supabase:** dedicated project `hwllkabgzaynalahvkpz` in `eu-central-1`

## 1. Verified starting point

- Website: a static Netlify-oriented prelaunch site in `website/`; site-status read via a *publishable* Supabase key. No user-authentication JavaScript or account pages yet.
- Database: dedicated private `airlinerra` airport-research schema, and `public.airlinerra_site_status` advertising `game_state=prelaunch`. No player world or airline entities found in the schema review.
- The research schema must remain private, with no public gameplay grants. The `airport_world_activation` research table does **not** mean a playable world is online.
- **Worlds:** capacity for exactly three worlds; **World 01** first launch; World 02 and 03 later. All three real-time, 1 real day = 1 game day; no historical eras.
- New airline begins with **USD 5,000,000** and **zero aircraft**. Players must subsequently buy or lease aircraft.
- Seven-day free trial and then paid membership were previously agreed; price/billing terms remain undecided. No live signup, subscription charge or gameplay activation is authorized at this time.

## 2. Domain, DNS, and email: order matters

**Preferred domain:** `airlinerra.com`. **Availability snapshot 2026-10-26:** Namecheap's live search displayed this exact domain as **available**, and advertised a conditional **$6.48 first-year new-customer promotion** (code `NEWCOM648`). This is *not* a completed reservation or purchase. Regular/renewal pricing and any checkout fees were not verified; registrar status may change at any time. Alternative `airlinerra.net` was not independently checked. Require explicit owner agreement on registrar and final checkout terms before registration/payment; keep registrar access owner-controlled with MFA/auto-renew.

After purchase:
1. Establish authoritative DNS and connect `airlinerra.com` and `www.airlinerra.com` to the existing isolated Netlify site; verify HTTPS, redirect/canonical URL, existing `/health`, and no exposure of repository `data/`.
2. Add/verify the domain in existing business-mail provider (currently known historical Next Quest Studio setup: Zoho Mail); configure **receiving** MX records based on that provider's actual data-centre instructions, and verify incoming/outgoing mail.
3. Proposed role addresses, mapped to an owner-approved mailbox/alias destination: `contact@airlinerra.com` (general), `support@airlinerra.com` (player support), `privacy@airlinerra.com` (data requests), `billing@airlinerra.com` (billing), optionally `admin@airlinerra.com` (internal only). Do not publish an address before receiving is tested.
4. Keep **transactional sending distinct from inbox aliases**: `no-reply@auth.airlinerra.com` (or dedicated authenticated subdomain) for signup confirmation, reset, account-change notices. Use a verified SMTP provider integrated with Supabase Auth. A Resend sending domain is not an incoming mailbox. Existing Resend domain list contains *no Airlinerra domain*, and verification for other domains cannot be assumed to apply here.
5. Authenticate mail with provider-supplied SPF, DKIM and DMARC; do not add competing SPF TXT records. Check return-path/bounce handling and test major email recipients, including spam-folder delivery. Add `postmaster@` and `abuse@` routing where required.
6. Do not enable production signup until custom SMTP is verified. Supabase's default sender is expressly unsuitable for public production accounts.
7. Record registrar owner, renewal/cost, DNS provider, MX provider, sender provider, and verification evidence in a **private operations secret inventory** (never GitHub source or public Trello cards).

**Owner decisions remaining:** registrable domain, registrar/payment, mailbox alias recipient, outbound mail provider, whether the studio's Zoho account accommodates an additional domain, and final privacy/legal contacts.

## 3. Identity model: one account, multiple isolated worlds

Architecture:

```text
Supabase Auth: one global human identity (auth.users.id)
      |
      +-- player_profile (display name, locale, preferences)
      +-- membership (trial/subscription entitlement; billing integration later)
      +-- world_memberships (one player-world membership per world)
                 |
                 +-- airlines (max one airline per player per world)
                        +-- aircraft / routes / finance / schedules
                          (every gameplay row scoped by world_id and airline_id)
```

**Important design defaults (proposals to be validated with owner before launch):**
- One personal login works for every world; a player does **not** register three separate accounts.
- At most one *owned airline* per account per world, enforced by a database uniqueness constraint; account can participate in distinct worlds independently.
- Membership/trial entitlement is **account-wide**, not a renewable trial for each new world. The **seven-day trial starts on first successful airline activation**, rather than account registration before any playable world opens. Store immutable initial `trial_started_at` and calculate `trial_ends_at` on trusted server time; never restart trial when switching worlds.
- Separate world identities, economies, aircraft inventories, rankings and flight clocks. Changing worlds cannot copy money, aircraft, or progress.
- World 01: planned/open to future accounts at launch; Worlds 02–03: `planned`, not selectable for airline creation. State machine: `planned -> registration_open -> active -> locked -> retired`, with server-side enforcement. A planned world must never advertise as currently live.
- World choice happens **after authentication**. The player may inspect a world directory but can only create/enter an airline in a server-open world.
- The player chooses airline name, operating country and home airport **after** entering the world; airport must be selected from an independently approved gameplay-eligible set, never from unapproved research candidates.
- Airline creation is a single idempotent server transaction: validate world state, user account/entitlement, unique airline/world membership, name and approved airport; allocate **$5,000,000** and **0 aircraft**; log initial ledger entry. Repeated clicks must not double-credit money.
- The existing airport research database may later serve a curated read-only import process but must not be exposed to public API clients.

## 4. Player journey and page routes

```text
Public homepage
  -> Register (email, password, username/display name, accept terms/privacy)
  -> Send verification email
  -> Verify email / safe callback
  -> Sign in
  -> Account overview / choose world
       -> World 01 (if explicitly opened by operator)
           -> Create airline -> approved home airport -> game dashboard
       -> Worlds 02, 03 -> visible but locked ("Coming later")

Returning:
  Homepage -> Sign in -> active account session -> world selector or last eligible world
  Direct game URL -> validate session AND world ownership -> game (otherwise sign in)

Forgot password:
  "Forgot password?" -> enter email -> always show same neutral acknowledgement
  -> email with expiring, one-use recovery link -> verified callback
  -> choose and confirm new password -> revoke prior sessions where supported
  -> explicit login/secure account overview (do not open a world automatically)

Settings:
  change password, change email (requires verification), logout,
  logout other sessions, privacy/export/delete account request, support
```

Security requirements:
- Prefer official `@supabase/supabase-js` Auth client: `signUp`, `signInWithPassword`, `resetPasswordForEmail`, `updateUser`, `signOut`. Use current Supabase documentation; token verification/PKCE callback must match selected hosting architecture.
- Enable email confirmation, strict allowlisted redirect URLs on exact owned domain and localhost dev port `5187` only; reject open redirects.
- Require acceptable passwords; no plain-text credentials in logs/analytics. Use Supabase managed password hashing and token management; never implement custom password tables.
- Generic forgot-password confirmation to avoid exposing whether an email exists. Rate limits plus CAPTCHA/abuse protection on public auth endpoints; monitor deliverability.
- Authorize with a server-side user ID (`auth.uid()`), world scope and ownership constraints. **Never** trust client-selected `world_id`, `airline_id`, user-editable metadata or local storage as permission.
- RLS on all exposed profile/world/airline tables, restrictive ownership rules for `SELECT/INSERT/UPDATE/DELETE`; server-only permissions for balances and entitlements; consider a private/internal transaction for crediting startup funds.
- Clear account/session state when changing users; use secure browser session practices; protect login and reset callbacks from token leakage (CSP/referrer controls). Require MFA for admin/operator accounts; consider optional player MFA later.
- Keep public site prelaunch until tested. Do not attach login buttons to dead routes or pretend auth is working.

## 5. Implementation sequencing and gates

**Gate A — Identity/domain operations**
- Owner selects purchasable domain and authorizes checkout; create registrar record, lock/MFA/renewal; connect Netlify and verify TLS/health.
- Configure Zoho (or approved inbox provider) receiving aliases with tested routing; configure separate outbound sender and domain authentication.
- Configure Supabase Auth URL allowlist, email templates, SMTP, reset callback and abuse controls; test only with authorized addresses while prelaunch.

**Gate B — Non-production software foundation (safe now)**
- Add versioned auth/world schema plan and migrations following existing Supabase practices; preserve current research tables.
- Implement accessible register/verify/login/logout/forgot/reset/profile/world-directory pages matching Airlinerra navy/white/orange design.
- Add route guards, server-side world join RPC, RLS security tests and account lifecycle tests. Develop on GitHub `main` per Airlinerra's repository policy, while keeping release/deployment disconnected or gated.
- Maintain world states in database even when there are zero active worlds.

**Gate C — End-to-end staging/QA**
- Registration -> confirmation -> login -> logout -> relogin; expired links, invalid links, duplicate accounts, blocked redirects.
- Password reset -> password change -> old credentials rejected; recovery email delivery and neutral responses.
- Two simulated worlds: ensure cross-world data access is denied; double-submit airline creation cannot duplicate funds; initial cash/aircraft correct.
- Trial begins only at first permitted activation, is account-wide and uses server time; trial expiry suspends operations but preserves airline data pending billing policy.
- Load/capacity, rollback/backups, EU privacy/legal pages, support workflow, mail health and monitoring.

**Gate D — Launch, separately authorized**
- Only after explicit owner approval: publish actual account entry points, open World 01, permit first airline, activate subscription/payment flows once product price and legal terms are final.
- Worlds 02 and 03 remain locked until separate release decisions. No airport gameplay eligibility changes are part of the platform-foundation work.

## 6. Proposed Trello board

**Board:** `Airlinerra — Project Development` (Next Quest Studio workspace)  
**Lists:** `Backlog`, `Ready`, `In Progress`, `Review & Testing`, `Blocked / Owner Action`, `Completed`.

Initial cards (single cards, no checklists by default):
1. Register and secure the Airlinerra domain — **Blocked / Owner Action**
2. Connect custom domain, HTTPS and production DNS — **Ready after domain**
3. Create branded mail aliases and test incoming replies — **Ready after domain**
4. Verify transactional domain and integrate Supabase Auth SMTP — **Ready after domain**
5. Define player identity, privacy settings and permissions — **Ready**
6. Build registration and email-confirmation flow — **Ready**
7. Build login, persistent sessions and logout — **Ready**
8. Build forgot-password and reset-password flow — **Ready**
9. Build world directory (World 01 planned; World 02/03 locked) — **Ready**
10. Build world membership and one-airline-per-world transaction — **Backlog**
11. Implement account-wide trial entitlement and future billing boundary — **Backlog**
12. Execute auth/RLS, multi-world isolation, and abuse/security QA — **Backlog**
13. Approve separate launch gate for first playable world — **Blocked / Owner Action**

No Trello board/card creation has occurred yet; user must connect the Trello plugin or provide an authenticated session first.

## 7. Out of scope / release safeguards

- No production user registration or actual accounts today, no world economy or payments activated.
- No schema grants exposing the private airport research database to customers.
- No airport gameplay admissions, final category assignments, runway eligibility or research data changes.
- No secret keys or personal customer details in GitHub or Trello.
- This file is a starting architecture and operations checklist. Proposed defaults are not claims that they have already been implemented or approved as final policy.
