# Airlinerra — Private account database installed, World 01 cohort imported
**Verified:** 27 October 2026
**Supabase target:** Airlinerra project `hwllkabgzaynalahvkpz` (the EXISTING central research project)
**Release state:** **PRELAUNCH / ALL WORLDS CLOSED**

## Exact live migrations

These migrations were applied to the existing Airlinerra Supabase database, not to a development branch or to another game project. They are tracked in the project's Supabase migration history:

1. `20261027072557` — `airlinerra_prelaunch_private_account_foundation_20261027`. Source: `docs/sql/airlinerra_game_identity_schema_prelaunch.sql`, with additional fail-closed migration assertions.
2. `20261027072623` — `airlinerra_prelaunch_private_airline_activation_20261027`. Source: `docs/sql/airlinerra_game_activation_prelaunch.sql`, with release-gate/privilege assertions.
3. `20261027072656` — `airlinerra_prelaunch_foundation_3140_game_roster_20261027`. Source: `docs/sql/AIRLINERRA_WORLD1_3140_TO_GAME_ACCOUNT_AIRPORTS_PRELAUNCH_2026-10-26.sql`, plus an explicit join to the previously recorded owner-authorized foundation membership, source-count protection, and post-install privilege and release checks.

GitHub repository branch policy remains **`main` for development**. These migrations have been executed in Supabase and recorded in its history; the existing SQL source files are historical release inputs, not additional scripts to run again.

## Live read-back checks (after all migrations)

| Test | Actual |
|---|---:|
| Existing owner-authorized original cohort | 3,140 |
| World 01 entries in `airlinerra_game.approved_game_airports` | **3,140** |
| World 02/03 approved airports | **0** |
| Missing game-side airport keys versus registration source | **0** |
| Extra game-side keys | **0** |
| Airport name/code/country/municipality mismatches | **0** |
| Approval-reference mismatches | **0** |
| Private account tables | **8** |
| Private account tables with RLS enabled | **8/8** |
| Planned game worlds | **3/3** |
| Enabled platform release gate | **false** |
| Published legal policy rows | **0** |
| Player Auth accounts, airline rows, financial ledger entries | **0** |

Additional SQL authorization checks returned **false** for anonymous and authenticated USAGE on `airlinerra_game`; likewise, direct SELECT on `approved_game_airports` and EXECUTE of `create_airline_once(uuid,smallint,text,text)` are denied to both client roles.

A privileged direct call to `create_airline_once(...)` for a nonexistent synthetic test UUID was explicitly rejected with `Airlinerra airline activation is not enabled`. No airline, credit or trial was created.

The public `airlinerra_site_status.game_state` still reads `prelaunch`. No airport research tables, airport review decisions or category approvals were modified.

## Security Advisor

The Supabase security scan reports informational `rls_enabled_no_policy` findings on private, inaccessible account/research tables. This is expected default-deny design, not evidence that anonymous users can read them. Do not add permissive RLS policies just to clear this informational advisory. Reference: https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy.

## What **is not** complete

- The frontend `PUBLIC_AUTH_ENABLED` remains false and the platform DB activation switch is false. **Supabase Auth's independent server-side public-signup configuration has not yet been verified**, so do not claim provider-level public account signup is definitively blocked.
- No Netlify hosted Functions or trusted PostgreSQL runtime was deployed, and no public production route was opened.
- Real versioned Terms and Privacy content, legal approval, hosted SMTP/redirect origins and production billing remain pending.
- The 3,140 airports are authorized for **simulation game catalog selection**, not real-world commercial operator clearance and not finalized airport categories.
- No player accounts, actual aircraft, airline gameplay or live subscription purchases were created.

## Next integration objective

Verify server-side Supabase Auth registration restrictions; prepare the secret-scoped hosting runtime with validated callbacks, abuse controls and private database access, then conduct **nonpublic hosted** full-account browser tests. Leave all game-world states `planned` and the platform release gate false until the owner explicitly authorizes a future launch.
