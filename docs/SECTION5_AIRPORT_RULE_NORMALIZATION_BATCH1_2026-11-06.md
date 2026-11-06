# Airlinerra — Section 5 airport rule normalization: first implementation batch
Date: 2026-11-06
Project: Airlinerra Supabase `hwllkabgzaynalahvkpz`; World 1.
Status: **implemented in private database** and validated. **Not complete for all airports.**
Live flight scheduling/dispatch activation: **not implemented or authorized**.

## Complete research classification and the normalization queue

- 3,141 approved airports have batch-screening records.
- 1,312 have a positive screened operating/curfew/permission/slot condition; these are **not all nighttime airport-wide flight prohibitions**.
- `airlinerra_game.section5_airport_restriction_normalization_queue_v1` now projects all 1,312 with research links, preliminary tag categories, and the count of available structured rules. This queue does **not** auto-activate anything.
- 1,247 remain in `RESEARCH_ONLY_RULE_NORMALIZATION_PENDING`.
- 36 airports have some hard time/runway rules; 29 have some review-only rules (including existing rules). **Partial structured coverage does not mean every condition at those airports is encoded.**

## Structured rules now in the game database

- 87 time-rule rows across 65 airports in `section5_airport_time_restrictions_v1`; 52 have `game_auto_enforcement=true` and `prohibit_normal_scheduled=true`. Several airports have multiple rows (weekday-specific or arrival/departure restrictions).
- **Five newly promoted hard time rules at four airports:**
  - Aruba AUA: **23:00–07:00 local** ordinary commercial operations outside aerodrome hours. Military, SAR, medevac, humanitarian exceptions remain out of scope.
  - Charleroi CRL: **23:00–06:30 local** ordinary schedules. Late based-aircraft arrival exemptions are not blanket permissions for new night schedules.
  - Leipzig/Halle LEJ: **23:30–05:30 local** **passenger** services only; cargo is not hard blocked by this rule. Current scope uses configuration `use_type=passenger`; future activation requires the actual flight service type to distinguish passenger, cargo and combi operation.
  - Goa GOI: Mon–Fri **08:30–12:30** and **15:30–16:30** local civil scheduled operations restricted during military flying. Authority permission is separately required for civil activity.
- **One verified physical-runway closure:**
  - Goa VOGO/GOI runway 08/26, source runway id `236704`, Saturdays **07:30–11:30 Asia/Kolkata**: recurring maintenance closure. This is a physical-runway restriction; it must not imply every unrelated runway is closed. Any temporary NOTAM can override current operating state.
- **16 newly structured review-only windows** are stored in the same time table with `game_auto_enforcement=false` and `prohibit_normal_scheduled=false`. Airports: ACE, AOJ, BIO, BZO, CJA, FSC, GOU, GPI, HIJ, PNA, SOD, SVQ, TAT, USH, WAE, YKA. They represent published service windows, PPR or slot coordination: **not** hard flight bans.
- Noise quota, certified EPNdB, airline slot quotas, runway-end directional restrictions, season changes and emergency permissions are **not** blindly converted to universal time bans.

## Dynamic scope and calendar

- `section5_airport_time_restrictions_v1` has new nullable `applies_aircraft_use_types`, `active_from`, `active_until`. Existing rules preserve all-aircraft/all-dates behavior because these columns default NULL.
- `section5_universal_airport_leg_restriction_v1` applies these only when the relevant aircraft category matches, then checks local airport time in `timezone_iana` and weekday/date windows, preserving crossing-midnight semantics.
- The universal gate always derives aircraft dynamically by `configuration_id` from `airlinerra.aircraft_catalog_configuration_inventory`; the next 40 aircraft do not require new SQL engine code once added to that inventory.
- Aircraft lacking configuration-matched certified noise Chapter and fully supported runway performance are not automatically given an invented certificate or clearance.
- `canActivateNormalFlight=false` remains in the returned result: all actual commercial flight activation still needs server-side transaction validation and a separate release decision.

## Source authority examples

The research batch record contains the full URL and evidence note for each new rule.

- Leipzig/Halle operator: `https://di5l0vjrkfc7a.cloudfront.net/umwelt/laermschutz/` (passenger-only night closure; freight 24h)
- Aruba ANSP 2026 eAIP: `https://dc-ansp.org/eAIS/eAIP/AIRAC%20AMDT%2003-26_2026_10_01/eAIP/AD%202%20TNCA%20-%20ARUBA%201-en-US.html`
- Charleroi / Wallonia: `https://www.charleroi.be/vivre/coordination-de-la-securite/plan-de-prevention` and 2026 Walloon ordinance linked in the research record
- Goa AAI 2026 AIP: `https://aim-india.aai.aero.in/eaip/eaip-v2-09-2026/eAIP/IN-AD%202.1VOGO-en-GB.html`
- Aomori ordinance: `https://reiki.pref.aomori.lg.jp/reiki_honbun/c001RG00001899.html` (review-only out-of-hours permit)
- Bilbao 2026 ENAIRE AIP: `https://aip.enaire.es/AIP/contenido_AMDT/LE_Amdt_A_2026_10_AD_2_LEBB_en.html` (review-only prior permission extension)

## Files and verification

- Migration: `supabase/migrations/20261106155500_section5_airport_rule_normalization_batch1.sql`. Successfully replayed against the same database (idempotent `ON CONFLICT DO NOTHING`).
- Regression suite: `tests/sql/section5_airport_rule_normalization_batch1_regressions.sql`. Uses rollback-only synthetic dated, weekday and passenger-scope fixture.
- Previous legacy scheduling suite: `tests/sql/section5_timed_route_schedule_gate_regressions.sql` — passed after changes.
- Previous universal gate suite: `tests/sql/section5_universal_restriction_gate_regressions.sql` — passed after changes.
- The active read-only authenticated Supabase Edge Function `airlinerra-noise-curfew-check` version 5 queries the universal database gate automatically. No extra Edge deployment was needed for these rule updates.

## Still outstanding

1. Normalize **1,247 other airports** with researched conditions, reviewing source reliability, operation/aircraft/runway direction applicability, calendar exceptions and precise legal scope before promoting any hard rule.
2. Fill certification gaps (220/272 current aircraft without verified ICAO noise chapter in the earlier Section 5 audit); complete certified noise measurements and quotas where applicable.
3. Verify operating status, NOTAMs, declared distances and usable runway ends before granting final in-game takeoff/landing clearance.
4. Implement a transactional, authenticated **real flight create/edit/activation backend** and call the universal gate for every leg, recurring occurrence and change. Current route planner is browser-session drafts only.
5. Build a player-facing restrictions summary; finish release validation tests. Do not confuse source-screened research with certified real-world aviation permission.

No commercial flights were activated and the public prelaunch release switches were not changed.
