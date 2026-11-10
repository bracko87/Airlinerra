# Group 2 combined aircraft/airport readiness — 2026-11-10

Production Supabase: `hwllkabgzaynalahvkpz`. Two migrations successfully applied:
- `20261110171000_group2_conditional_restriction_preview.sql`
- `20261110172500_group2_aircraft_airport_readiness_preview.sql`

## What works
The restricted SQL function `airlinerra_game.group2_airport_conditional_restriction_preview_v1` evaluates:
- Paris–Le Bourget departures 22:15–06:00 **Europe/Paris** as review-required (aircraft-specific exceptions and arrivals are not a universal closure).
- Ciudad Real Chapter 14 against the recorded game allowance of only ICAO Chapters 3 or 4 as blocked.
- Missing **sourced** ICAO Chapters as review-required instead of treating game relative-noise class as actual certification.
- Other Group 2 airports as having no *recorded game restriction conflict* when no Group 2 restriction flags exist; this is not a clearance or operational permission.

The second function `airlinerra_game.group2_aircraft_airport_readiness_preview_v1` combines that conditional check with aircraft catalog runway requirement, Group 2 runway length and stand-category 10-minute capacity.

Production read-back verified:
1. Le Bourget local 23:00 departure: `REVIEW_REQUIRED_CONDITIONAL_NIGHT_RESTRICTION`.
2. Ciudad Real A340-500 sourced Chapter 14: `BLOCKED_CONDITIONAL_RESTRICTION`.
3. Ciudad Real 737-800 without sourced Chapter: `REVIEW_REQUIRED_UNSOURCED_AIRCRAFT_CHAPTER`.
4. Grant County B737-800: `PRELIMINARY_DATA_COMPATIBLE_NOT_OPERATIONAL` (2,230m catalog requirement, 4,115.7m game runway, capacity 3 per 10-minute terminal interval).

## Critical limits
- Both functions are **server-private**, `STABLE`, read-only and return `canBook=false`, `canDispatch=false`, `canActivateOffice=false`.
- Source Chapter data are scarce: database `section5_aircraft_noise_profiles_v1` has only **5/271** non-null ICAO Chapters. Other game's assigned relative noise classes are not evidence of certification.
- Catalog runway length vs reference length is **not** full-weight performance.
- Capacity per 10 minutes is **not** actual slot reservation availability.
- Curfew/Chapter checks are partial: Le Bourget conditional aircraft type/arrival exemptions and Chapter weight rules not implemented.
- No airspace status, aircraft movement, traffic rights, financial posts or airline approvals are evaluated here.
- No new Group 2 airport is present in the existing operational Section 5 or 6 engine tables.
- The Group 1 approved registry stays **3,141**; Group 2 commercially activated remains **0**; no planned office saves were made by these tests.

## Next deployment boundary
Connect these preview evaluations to an internal gate regression test harness, build complete per-aircraft conditional rule handling and restricted-time rules, integrate live slot reservation and trusted movement checks, then make a separate authorization decision on operational Group 2 admission. Do not swap any active schedule or airport foreign keys based on preview results.
