# Airlinerra — Flat cabin plan, extra legroom, comfort and refit quote (2026-11-10)

## Implemented and verified

GitHub `main`, Supabase project `hwllkabgzaynalahvkpz`, protected Fleet API `airlinerra-fleet-acquisition` v15.

1. **A319 cabin row pattern**: Economy 3–3, Premium Economy 3–3, Business 2–2, First 1–1. Other aircraft retain their model-row patterns. A319 Premium 3–3 is an airline/operator-style example, **not** a certified LOPA for every individual airframe. Source: https://seatinside.com/aircraft/airbus-a319-100 . Official Airbus A319 aircraft-characteristics reference: https://www.aircraft.airbus.com/sites/g/files/jlcbta126/files/2025-07/AC_A319_20250715.pdf .
2. **Illustration**: flat-ended rectangular cabin with blue FRONT galley and warm-neutral REAR galley/lavatory; First is ahead of Business, ahead of Premium, ahead of Economy. Rows fill usable cabin width with appropriate aisle count; seating is **illustrative**, not exit/weight-and-balance certification.
3. **Capacity**: show `spacePct` and per-class `Space %`, not confusing raw game units. Invalid/overfull layouts remain visible as a flat rectangle with **NO SPACE** text and save disabled.
4. **Extra legroom**: single editable `extraLegroomCm` 0–20 cm, tenths supported, uniformly added to each selected seat type's reference pitch. It lengthens seat row spacing in the top view. Game-space formula:
   `seatSpace = seats * baseSeatSpaceUnits * (1 + extraLegroomCm / (seatPitchInches * 2.54))`.
   This is an approximation, not physically certified seat placement. Server independently validates the formula, capacity and each seat type before saving.
5. **Owner-only design persistence**: `airlinerra_game.aircraft_cabin_drafts_v1.extra_legroom_cm numeric(4,1) not null default 0 check (0..20)`, safe for existing drafts. Cabin API `cabin-save-draft` accepts optional `extraLegroomCm` for backward-compatible older clients; `cabin-overview` returns `draftExtraLegroomCm` for owned aircraft. No installation, transfer, airline cash debit, flight cancellation or automatic MRO booking is triggered.
6. **Comfort rating**: weighted 0–100 score based on class, type footprint and added pitch; displays potential small booking preference between -1.5% and +1.5% **as a game design preview only**. This adjustment is **not connected to real passenger bookings** because trusted booking settlement is not yet active.
7. **Quote**: per-seat *game-estimate* equipment value plus **one combined removal-and-installation** job. Default site labour base = `$5,000 + $150 × proposed seats + $75 × currently installed seats`; selected site multiplier 0.6–1.5 is applied to labour only. Example A319 156 RECARO R1 economy seats, 0 cm extra: $85,800 seats + $40,100 removal/install = **$125,900 indicative replacement** at 1.0× site. A real provider quote, ferry flight cost, additional repairs, age and downtime allocation are not guaranteed.
8. **Space proof** for 156-seat A319 R1: 0 cm = 97.0% usage, 2 cm = 99.6% and valid, 3 cm = 101.0%, **NO SPACE**. Seat model/price are game balance assumptions.
9. **Stability**: Same-airline clock/summary refresh no longer erases an unsaved cabin design in progress; aircraft profile modal also preserves extra pitch and displays the quote in read-only form.

## Verification

- A319 model-row change and draft field verified in Supabase; no existing saved drafts modified.
- Owner-only SQL and new draft-write SQL EXPLAIN successfully executed, without inserting records.
- UI/source tests cover class ordering, no-space visibility, flat frame, pitch-sensitive capacity, 0–100 rating, capped booking-preview range, price formula, server-side tampering refusal, same-owner isolation and backward compatibility.
- Dedicated cabin/MRO workflow and aircraft profile workflow passed with complete website build. CI links:
  - https://github.com/bracko87/Airlinerra/actions/runs/42871207143
  - https://github.com/bracko87/Airlinerra/actions/runs/42871207070
- **Not yet independently browser-verified** in the user's local account. Broader main CI has pre-existing onboarding/local-registration test failures; do not claim general production stability.
- World 1 market not opened, no airline funds charged and no cabin refit activated.
