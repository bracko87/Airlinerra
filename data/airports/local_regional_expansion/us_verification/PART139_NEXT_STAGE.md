# U.S. airport certification cross-check — next verification stage

**Prepared 23 October 2026. Research-only, not a game release.**

The U.S. FAA runway/public-use stage has completed: 2,077 original new candidates, of which 1,929 have qualifying paved runways and public-use source flags; 148 are held for pavement, access, closed or identity issues. None is authorized for gameplay.

## New Part 139 comparison

The existing October 1, 2026 FAA NASR archive (`APT_BASE.csv`) contains official FAA data fields:

- `FAR_139_TYPE_CODE`: airport certificate class (I, II, III, IV) and ARFF index when reported.
- `FAR_139_CARRIER_SER_CODE`: source scheduled carrier-service code; not by itself a route authorization.
- `ARFF_CERT_TYPE_DATE`: reported certification date.
- `SITE_NO` and `ARPT_ID`: exact joins to the independently matched FAA airport register.

The new `scripts/verify_us_part139_nasr.py` checks all 2,077 airports against the **same downloadable October 2026 NASR ZIP SHA-256** as the successful FAA physical screen and refuses to join if the SHA differs. It is not guessing the Part 139 class from the size or name of the airport.

**When run**, it writes:

1. `us_part139_nasr_2026_10_01.csv` — one record per candidate with explicit FAA class/ARFF fields and conservative checks for three different passenger-aircraft service types, plus cargo and small charter hold statuses.
2. `us_part139_nasr_summary.json` — exact FAA certificate indicator counts (overall and among the 1,929 physical/public-use airports), Alaska exception count and evidence provenance.

These two files are **not yet generated** until the updated workflow is run. Do not claim Part 139 matches before the outputs exist and tests pass.

## Authoritative class limits (FAA)

| Aircraft operation | Class I | Class II | Class III | Class IV |
|---|---|---|---|---|
| Scheduled passenger, 10–30 seats | Possible subject to other rules | Possible subject to other rules | Possible subject to other rules | Not covered |
| Scheduled passenger, 31+ seats (ATR 42 type) | Possible subject to other rules | Not covered | Not covered | Not covered |
| Unscheduled passenger, 31+ seats | Possible subject to other rules | Possible subject to other rules | Not covered | Possible subject to other rules |

Sources:

- FAA: https://www.faa.gov/airports/airport_safety/part139_cert/classes-of-airports
- FAA September 3, 2026 official certification list: https://www.faa.gov/airports/airport_safety/part139_cert/part_139_airport_certification_status_list
- FAA October 1, 2026 NASR: https://www.faa.gov/air_traffic/flight_info/aeronav/Aero_Data/NASR_Subscription/2026-10-01/

A certificate indicator is **not** clearance for a particular airline, commercial charter, cargo service, aircraft type, runway performance, route, or time slot. A missing Part 139 indicator **does not disqualify small-aircraft charter or cargo flights** that are otherwise lawful and permitted. Alaska has specific statutory exceptions; preserve them for separate review.

## How to run

Go to [Verify US airport candidates against FAA](https://github.com/bracko87/Airlinerra/actions/workflows/verify-us-airports-faa.yml), choose **Run workflow**, branch `main`. The job is manual-only, performs regression tests and the existing FAA verification, then checks Part 139 from the same source. It validates the output and commits research files to `main` only if complete. It never edits the original 3,140 shortlist or the 8,153 runway master, and does not activate any game airport.

Do not mistake the green result of the **earlier** run for success of this new Part 139 step. A new workflow run must finish to establish those results.
