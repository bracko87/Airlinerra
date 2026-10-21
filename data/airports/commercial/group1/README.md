# Airlinerra — Commercial eligibility review, Group 1 (2026-10-21)

**Scope:** Albania, Armenia, Austria and Azerbaijan. The original `group1_technical_candidates.csv` contains 30 paved-runway candidates. This new review retains **all 30** by immutable OurAirports source airport ID and does not change the worldwide 7,846-airport register.

## Interpretation

- `passenger_commercial_permission=YES`: source-backed passenger-service evidence or official governmental confirmation of the airport's passenger transport role.
- `cargo_commercial_permission=YES`: source-backed cargo-handling operations or official confirmation of freight transport availability; **does not imply cargo tonnes, aircraft type restrictions or freighter movements**.
- `UNKNOWN` is **not** `NO`. Unverified airports stay in the review queue; an airport with a 1,200 m runway alone cannot be activated.
- `MILITARY_ACCESS_REVIEW` describes evidence of military use or the source airport name; it **does not establish a blanket ban** on possible civilian movements. Austrian prior permission is explicitly evidenced by Austro Control's AIP.
- `PUBLIC_AIRPORT_SERVICE_UNVERIFIED` means an operator lists a public/international regional airport but there is no independent 2026 commercial passenger/cargo review conclusion yet.
- Austria's six commercial airports are confirmed by federal government material as open for **passenger, freight and mail transportation**; actual dedicated cargo flight frequency is not asserted and operating-hours publication has a Covid-era caveat. No airport slots or curfews are inferred.
- The airport operator source listing for Azerbaijan has a potentially conflicting airport code assignment (Lachin displayed as UBBF despite Fuzuli also listed as UBBF). This review preserves the original Group 1 identifiers and flags code checks, rather than changing any codes.
- Airports' terminal stands, cargo terminal capacity, noise restrictions, curfews, daily/monthly/yearly demand and annual actual passenger/cargo volume remain **UNKNOWN** and out of this review.

## Files

- `group1_commercial_review.csv`: all 30 individual technical airport candidates with separated passenger/cargo conclusions, source references and review notes.
- `group1_country_counts.csv`: explicit total per country with distinct evidence and still-pending counts.
- `scripts/validate_commercial_group.py`: reusable validator ensuring exact source-ID coverage, evidence URLs for positive decisions, allowed status enum and rollup correctness.

## Next

Continue Groups 2–49 using original country group ownership. Recheck 2026 schedules and official AIPs for ambiguous cases; verify raw codes using regulator/official airport publications. All reviews remain on GitHub. No Supabase import, classification, capacity defaults or gameplay activation is authorized.
