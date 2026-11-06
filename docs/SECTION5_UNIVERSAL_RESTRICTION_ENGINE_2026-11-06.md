# Airlinerra Section 5 — Universal airport/time/runway/noise restriction engine
Status: database screening deployed; live flight activation NOT implemented or authorized.
Database: Airlinerra Supabase `hwllkabgzaynalahvkpz` (not ProPeloton).
Date: 2026-11-06.

## Installed

- `airlinerra_game.section5_universal_route_restriction_gate_v1(world_id, origin_airport_key, destination_airport_key, configuration_id, departure_utc, arrival_utc, origin_runway_source_id DEFAULT NULL, destination_runway_source_id DEFAULT NULL)` returns JSONB.
- `airlinerra_game.section5_universal_airport_leg_restriction_v1` applies each end's airport rules using the relevant local timezone.
- `airlinerra_game.section5_local_restriction_window_match_v1` matches crossing-midnight weekdays and optional seasonal date windows.
- `airlinerra_game.section5_runway_specific_restrictions_v1` supports sourced runway-level departure/arrival windows, and Chapter bans ONLY with a configuration-matched certificate. Default `enforce_in_game=false`. Research-only runway data must not be automatically enforced as a blanket airport ban.
- `server/noise-curfew-route-edge-entry.ts` uses the new gate. Existing authenticated **read-only** Supabase Edge Function `airlinerra-noise-curfew-check` was updated to **active version 5** on 2026-11-06, preserving fresh Auth verification and `canActivateNormalFlight=false`. This is NOT a live scheduling/activation write endpoint.
- Versioned migration: `supabase/migrations/20261106144500_section5_universal_airport_restriction_gate.sql`.
- Regression suite: `tests/sql/section5_universal_restriction_gate_regressions.sql` (temporary test rules are rolled back).

## Aircraft compatibility

The checker looks up **configuration IDs in `airlinerra.aircraft_catalog_configuration_inventory` dynamically**. There is no 272-aircraft allowlist and no hardcoded model list in the new engine. The 40+ upcoming models will be recognized after their configuration rows are promoted to the canonical inventory. For each future configuration, complete technical performance and, where applicable, engine/airframe noise certification. If a full-weight runway formula is not available, the catalog runway reference is **informational** and triggers review; it cannot generate an invented hard runway-length ban. Time-only runway restrictions still block even if performance is pending.

Noise Chapter exclusions are hard-blocked ONLY when a verified official airport ban matches a `CERTIFICATE_CONFIGURATION_MATCHED` aircraft certificate. Model-level or assumed Chapter values are not sufficient to impose hard bans. Noise slots, quota-count budgets, EPNdB limits and unknown certifications remain review flags until their real measurements, authority rules, and ledgers are available.

## Decisions

- `BLOCKED_BY_GAME_AIRPORT_RUNWAY_OR_NOISE_RESTRICTION`: game restriction blocks a normal planned flight. Individual airport result explains reason.
- `REVIEW_REQUIRED_GAME_RESTRICTION_SCREEN`: no confirmed hard ban, but unresolved runway/certificate/local restrictions. Never treat as real-world dispatch approval.
- `PRELIMINARY_ALLOW_GAME_RESTRICTION_SCREEN`: no identified conflict in this gate; still not activation clearance.
- `canActivateNormalFlight` is **always false** until an authenticated, transactionally enforced flight scheduler checks this gate AND aircraft ownership, crew, runway operational status, capacity/slots, traffic rights, actual flight time/weight/weather, and network conflicts.
- `realWorldDispatchApproved` is **always false**. This is game simulation data, not certified aviation permission.

## Current verified database numbers

- World1 approved airports: 3,141; research screening records: 3,141.
- Positive operating/curfew conditions: 1,312, **not** 1,312 complete airport-wide curfews.
- Local noise findings: 539, **not** 539 certified aircraft bans.
- Existing structured time rules: 66 at 45 airports, of which 47 prohibitive rules at 32 airports are flagged for automatic game enforcement. Runway-specific rule table starts **empty** until rule evidence is normalized and safely scoped.
- Present canonical aircraft configurations: 272; 220 have no verified ICAO noise Chapter certificate; only 9 have configuration-matched noise certification. Additional 40 aircraft are not yet added here.
- Imported runway inventory mostly has `historical_unverified` operational status; a physical runway length screen is **not** real-world operational clearance.

## Mandatory next tasks (do not mark flight enforcement fully live yet)

1. Normalize the remaining positive airport research into precise rules. Distinguish entire-airport closures from restrictions that apply to a runway end, engine class, aircraft certificate, daylight hours, season, quota, voluntary noise abatement, and special permission. Keep uncertain sources as research-only.
2. Add runway-end direction identifiers to operational rules once end-specific AIP evidence is available; the current per-runway table uses physical `source_runway_id` and an operation, not an individual takeoff/landing runway end.
3. Connect this server-side gate to every actual create/edit/activate recurring-flight transaction and re-check in the transaction; don't enforce only in the browser. No such live flight scheduling write path exists yet: present `website/route-planner.mjs` saves account-local drafts.
4. Ensure real ownership, maintenance/crew, airline licensing, scheduling conflict and airport slot/quota ledgers are checked alongside this gate. Unknown restrictions must not be called verified clearance.
5. Repeat the SQL regressions and API/source tests after the 40 aircraft are added. Verify blocked and review paths for them.
6. Keep public Netlify/Auth activation and game commercial-flight execution release-guarded. GitHub main may redeploy the public static website; source changes do NOT independently authorize live game launch.

## Test inputs

- FUK (ourairports key `OURAIRPORTS:5564`), configuration 3 at 23:30 local -> airport night closure blocked.
- CVX (`OURAIRPORTS:19570`), configuration 3 -> full-weight runway-length game screen blocked.
- CDG -> MUC daytime, configuration 3 -> review, not an invented ban.
- Select nonexistent runway ID -> invalid-runway block.
- A rollback-scoped rule restricting MUC physical runway 236229 at midday blocks that runway while automatic selection finds 236228.
- A rollback-scoped Chapter 4 runway ban blocks configuration 57 (matched Chapter 4 certificate), but does not block configuration 3 on an unverified Chapter guess.

All fixture rules are rolled back. Existing `tests/sql/section5_timed_route_schedule_gate_regressions.sql` also passed, with legacy helpers left intact.
