# Airlinerra — U.S. Airport Expansion Batch 52 (2026-10-24)

**COMPLETED AND DATABASE-VERIFIED:** 50 unique formerly unreviewed airport source-review records persisted and independently read back from Supabase `airlinerra.airport_commercial_verification`. Overall: **1,793 / 1,929 reviewed (92.95%), 136 pending, zero gameplay approvals**. The original 3,140 playable airports were not modified.

## Important restrictions

- **3GV East Kansas City MO:** 44ft-wide main runway, low wheel loading, displaced threshold and nonstandard lights/safety areas.
- **3U7 Benchmark MT:** 6,000ft length does not remove poor pavement, missing snow clearance, mountain turbulence and access risks.
- **7V5 Brush CO:** 6,000lb wheel rating, faded markings and nonstandard lights.
- **T69 Sinton TX:** 8,000lb wheel rating, narrow 55ft main strip with displaced thresholds, turf crosswind CLOSED.
- **AKQ Wakefield VA:** 12,500lb wheel loading, algae-obscured markings and displaced thresholds.
- **F45 North Palm Beach County FL:** operator explicitly classifies as general aviation without scheduled airline activity, despite FBO and jet aircraft access.
- **O61 Cameron Park CA:** 4,051x50ft runway, 12,500lb owner-estimated loading and **1,509ft displaced RW31 threshold**.
- **T50 Menard County TX:** 4,100x60ft fair runway, faded markings and displaced RW15 threshold; PAPI reported U/S.
- **SVE Susanville CA:** operator restricts aircraft to **12,000lb**, even with Jet A available.
- **8S0 Starr-Browning MT:** irregular snow removal, livestock and nonstandard markings.
- **BYI Burley ID:** primary and crosswind runways both have displaced thresholds; aircraft-specific landing distances essential.

These are **first-pass facility/runway sources, not commercial passenger, charter or cargo certification**. Airport access, current official FAA NOTAMs, carrier permits, aircraft weight, pavement and operating permissions must be verified separately.

## Complete 50-airport evidence ledger

The recorded screen runway length is **not automatically usable landing or takeoff distance**. All 50 are `NOT_APPROVED`.

### Records 1–10

| FAA | State | Immutable key | Screen runway m | Airport-specific source | Factual review and unresolved limitations | Reviewed UTC |
|---|---|---|---:|---|---|---|
| 3DW | MO | `OURAIRPORTS:18682` | 1230.5 | [Evidence](https://www.airnav.com/airport/3DW) | FAA October 2026 Springfield Downtown 3DW: 4037x50ft runway; 8000lb single-wheel limit; nonstandard lights; Jet A and 100LL. Commercial carrier authorization not established. | 2026-10-24 08:12:38.445066+00 |
| 3GV | MO | `OURAIRPORTS:18700` | 1373.7 | [Evidence](https://www.airnav.com/airport/3GV) | East Kansas City, Grain Valley: 4,507×44ft main runway, 11,000lb single-wheel, 303ft displaced RW09, nonstandard lights and deficient safety areas; privately owned. First-pass FAA-derived facility evidence; current airline/charter/cargo commercial authorization unverified. | 2026-10-24 08:21:58.933629+00 |
| 3I2 | WV | `OURAIRPORTS:18703` | 1219.2 | [Evidence](https://www.airnav.com/airport/3I2) | Mason County, Point Pleasant: Weekday attendance 10:00–14:00, PAPI/REIL/MIRL runway 07/25, AWOS. First-pass FAA-derived facility evidence; current airline/charter/cargo commercial authorization unverified. | 2026-10-24 08:21:58.933629+00 |
| 3R2 | LA | `OURAIRPORTS:18731` | 1311.9 | [Evidence](https://www.airnav.com/airport/3R2) | Le Gros Memorial, Crowley: Weekday staffing 08:00–17:00, runway 04/22 lighting and REIL, no certified airline verified. First-pass FAA-derived facility evidence; current airline/charter/cargo commercial authorization unverified. | 2026-10-24 08:21:58.933629+00 |
| 3U7 | MT | `OURAIRPORTS:18745` | 1828.8 | [Evidence](https://www.airnav.com/airport/3U7) | Benchmark, Lewis and Clark National Forest: 6,000×100ft but POOR pavement, long cracks and weeds; no snow removal, 5,434ft elevation and dangerous mountain turbulence. First-pass FAA-derived facility evidence; current airline/charter/cargo commercial authorization unverified. | 2026-10-24 08:22:13.976117+00 |
| 40G | AZ | `OURAIRPORTS:18756` | 1279.9 | [Evidence](https://www.airnav.com/airport/40G) | Valle, near Grand Canyon: Public GA at almost 6,000ft field elevation; density altitude and desert/mountain conditions, owner and carrier rights pending. First-pass FAA-derived facility evidence; current airline/charter/cargo commercial authorization unverified. | 2026-10-24 08:22:13.976117+00 |
| 46U | WY | `OURAIRPORTS:18785` | 1776.1 | [Evidence](https://www.airnav.com/airport/46U) | Alpine: Unattended at 5,637ft altitude, limited winter ramp/parking, landing/overnight fees, mountain conditions. First-pass FAA-derived facility evidence; current airline/charter/cargo commercial authorization unverified. | 2026-10-24 08:22:13.976117+00 |
| 49R | TX | `OURAIRPORTS:18799` | 1211.6 | [Evidence](https://www.airnav.com/airport/49R) | Real County, Leakey: Unattended GA airfield; confirm pavement, services and licensed commercial operators. First-pass FAA-derived facility evidence; current airline/charter/cargo commercial authorization unverified. | 2026-10-24 08:22:29.275532+00 |
| 4A5 | AR | `OURAIRPORTS:18803` | 1220.1 | [Evidence](https://www.airnav.com/airport/4A5) | Searcy County/Marshall: FAA lists 4,003×75ft fair asphalt and 12,500lb rating, runway 05/23 PAPI/REIL out indefinitely; [airport website](https://www.buffaloriverairport.com/) also describes a 2,500×100ft grass strip; reconcile facilities. First-pass FAA-derived facility evidence; current airline/charter/cargo commercial authorization unverified. | 2026-10-24 08:22:29.275532+00 |
| 4F2 | TX | `OURAIRPORTS:18813` | 1219.2 | [Evidence](https://www.airnav.com/airport/4F2) | Panola County–Sharpe Field, Carthage: 24h self-serve 100LL, weekday attendance, runway 17/35 lighting and PAPI; no Jet A listed or carrier proven. First-pass FAA-derived facility evidence; current airline/charter/cargo commercial authorization unverified. | 2026-10-24 08:22:29.275532+00 |

### Records 11–20

| FAA | State | Immutable key | Screen runway m | Airport-specific source | Factual review and unresolved limitations | Reviewed UTC |
|---|---|---|---:|---|---|---|
| AKQ | VA | `OURAIRPORTS:19273` | 1321.9 | [Evidence](https://www.airnav.com/airport/AKQ) | FAA effective Oct 2026 Wakefield Municipal runway 03/21 4337x75ft fair asphalt, 12,500lb single-wheel capacity; thresholds displaced 298ft RW03 / 471ft RW21, markings poor/algae, nearby trees; 100LL only and no repairs. Nominal 1322m not usable LDA; aircraft hold, no carrier proven. | 2026-10-24 08:24:47.18891+00 |
| T69 | TX | `OURAIRPORTS:21163` | 1317.7 | [Evidence](https://www.airnav.com/airport/T69) | FAA Oct 2026 Sinton/Alfred C Bubba Thomas: primary runway 14/32 4323x55ft fair asphalt, 8,000lb single-wheel; thresholds displaced 250ft and 400ft; turf 03/21 CLOSED indefinitely. Jet A/100LL and repairs available, but restricted paved width/loading require hold. | 2026-10-24 08:24:47.18891+00 |
| 61A | AL | `OURAIRPORTS:18944` | 1311.6 | [Evidence](https://www.airnav.com/airport/61A) | FAA Oct 2026 Camden Municipal at Camden AL publicly accessible GA; initial paved runway screen ~4303ft, 2026 FAA runway-condition and aircraft limits need owner confirmation. No scheduled airline or named certificated charter/cargo routes verified. | 2026-10-24 08:24:47.18891+00 |
| 7V5 | CO | `OURAIRPORTS:19085` | 1310.6 | [Evidence](https://www.airnav.com/airport/7V5) | FAA Sep/Oct 2026 Brush Municipal Colorado runway 07/25 4300x60ft FAIR asphalt, 6,000lb published wheel rating; markings badly faded, nonstandard runway lights and RW25 threshold displaced 195ft for night operations. 4280ft elevation; very restrictive aircraft/loading hold. | 2026-10-24 08:24:47.18891+00 |
| 9K8 | KS | `OURAIRPORTS:19194` | 1310.6 | [Evidence](https://www.cityofkingman.com/page/airport) | City of Kingman confirms Clyde Cessna Field 9K8 primary paved runway 18/36 4300x75ft concrete, 30,000lb single-wheel, pilot-controlled lights and 100LL; GA instruction/maintenance not scheduled commercial airline or charter authority. | 2026-10-24 08:24:47.18891+00 |
| A32 | CA | `OURAIRPORTS:19218` | 1310.6 | [Evidence](https://www.airnav.com/airport/A32) | FAA Oct 2026 Butte Valley Airport A32 near Dorris CA, unattended at elevation 4243ft and pilot-activated MIRL runway 16/34. Current runway pavement rating, mountain/winter access and fuel/charter permission remain to check. | 2026-10-24 08:24:47.18891+00 |
| F45 | FL | `OURAIRPORTS:19818` | 1310.6 | [Evidence](https://discover.pbc.gov/airports/pages/north-county.aspx) | Palm Beach County identifies North Palm Beach County General Aviation F45 as GA reliever, no airline activity; runway 14/32 4300x75ft limited to 30,000lb, FBO 24h and flight schools. FDOT differentiates precision-capable runway 09R/27L from visual-only 09L/27R. No scheduled airline. | 2026-10-24 08:24:47.18891+00 |
| JDN | MT | `OURAIRPORTS:20207` | 1310.6 | [Evidence](https://www.airnav.com/airport/JDN) | FAA Oct 2026 Jordan Airport at Jordan Montana, public small airfield 2667ft elevation. Confirm actual published paved runway condition, seasonal access, fuel and any authorized charter/cargo operators; rural GA record alone is not admission. | 2026-10-24 08:24:47.18891+00 |
| RNP | MI | `OURAIRPORTS:20946` | 1310.6 | [Evidence](https://www.airnav.com/airport/RNP) | FAA-derived Owosso Community Airport RNP at Owosso Michigan; main runway ~4300ft candidate screen. Verify exact present pavement/declared distances, services, winter maintenance and carrier permissions; no scheduled airline service confirmed. | 2026-10-24 08:24:47.18891+00 |
| 9V9 | SD | `OURAIRPORTS:19210` | 1310.3 | [Evidence](https://www.airnav.com/airport/9V9) | FAA Oct 2026 Chamberlain Municipal 9V9 South Dakota, public GA airport near Chamberlain. Validate live runway condition, fuel/repairs and winter access with manager; no independent evidence of scheduled airline or licensed passenger/air-cargo routes. | 2026-10-24 08:24:47.18891+00 |
