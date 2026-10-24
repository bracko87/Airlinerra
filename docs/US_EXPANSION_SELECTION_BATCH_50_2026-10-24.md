# Airlinerra — Batch 50 — complete in Supabase; GitHub ledger pending

Verified database checkpoint: 1,693 of 1,929 reviewed, 236 pending, zero gameplay approvals. All 50 Batch 50 records are complete in Supabase. The remaining report entries have not yet been published here.

Initial ten candidate FAA IDs from the unreviewed queue: 2A2 AR, 2A6 AR, 2E5 TX, 2F0 TX, 2G2 OH, 2J3 GA, 2J5 GA, 2K4 OK, 2M0 KY, and 2R0 MS. All have FAA-derived airport-specific research from October 2026. Notable holds: 2A2 maximum 12,500lb aircraft and 50ft runway with displaced threshold; 2F0 poor-condition crosswind runway, displaced thresholds and nonstandard lights.

**Do not mark Batch 50 complete or start Batch 51 before Supabase verifies 50 new distinct airport records.** No gameplay approvals or activation.

## Ten researched records — NOT YET saved in Supabase

| FAA | State | Immutable key | Airport | Airport-specific evidence | First-pass finding |
|---|---|---|---|---|---|
| 2A2 | AR | `OURAIRPORTS:18567` | Holley Mountain Airpark | [FAA-derived source](https://www.airnav.com/airport/2A2) | Runway 4795x50ft, displaced threshold and steep runway-end drop-offs; explicitly closed above 12500lb. |
| 2A6 | AR | `OURAIRPORTS:18569` | Holly Grove Municipal | [FAA-derived source](https://www.airnav.com/airport/2A6) | Attended Mon-Sat daytime; runway lights pilot-activated; airport beacon marked out indefinitely. |
| 2E5 | TX | `OURAIRPORTS:18576` | Dell City Municipal | [FAA-derived source](https://www.airnav.com/airport/2E5) | Unattended, 3703ft field elevation; verify fuel, aircraft density altitude and operator access. |
| 2F0 | TX | `OURAIRPORTS:18578` | Iraan Municipal | [FAA-derived source](https://www.airnav.com/airport/2F0) | Main runway 4085x60ft fair, displaced thresholds, nonstandard lights; crosswind strip poor with potholes; 100LL only. |
| 2G2 | OH | `OURAIRPORTS:18584` | Jefferson County Airpark | [FAA-derived source](https://www.airnav.com/airport/2G2) | Attended 0900-1700, RNAV 14/32 and AWOS; wildlife caution. |
| 2J3 | GA | `OURAIRPORTS:18595` | Louisville Municipal, Georgia | [FAA-derived source](https://www.airnav.com/airport/2J3) | 5002x100ft fair runway, 26000lb single-wheel, Jet A/100LL, major repairs; not Louisville Kentucky. |
| 2J5 | GA | `OURAIRPORTS:18596` | Millen Airport | [FAA-derived source](https://www.airnav.com/airport/2J5) | Unattended field, dusk to 2200 runway lights then pilot activation; AWOS and PAPI. |
| 2K4 | OK | `OURAIRPORTS:18598` | Scott Field, Mangum | [FAA-derived source](https://www.airnav.com/airport/2K4) | Unattended, RNAV 17/35; runway-adjacent power lines, drainage ditch and ultralight activity. |
| 2M0 | KY | `OURAIRPORTS:18602` | Princeton-Caldwell County | [FAA-derived source](https://www.airnav.com/airport/2M0) | Unattended, 24/7 card 100LL; no repair services, RNAV published, no Jet A verified. |
| 2R0 | MS | `OURAIRPORTS:18613` | Waynesboro Municipal | [FAA-derived source](https://www.airnav.com/airport/2R0) | Staff weekdays 0600-1200 with after-hours callout and pilot-controlled runway lights. |

Every record remains pending database persistence, read-back, and commercial permission verification. DO NOT count any as reviewed yet.

## Saved Supabase evidence records 11–20

| FAA | State | Immutable key | Airport evidence | Individual finding and outstanding checks | Reviewed UTC |
|---|---|---|---|---|---|
| ONY | TX | `OURAIRPORTS:20754` | [Source](https://www.airnav.com/airport/ONY) | FAA Oct 2026 Olney Municipal ONY: three ~5100x75ft paved runways; runway 13/31 has major cracking, loose stones and vegetation in first/last thirds despite overlaid centre 1600ft. 100LL only, no airframe/engine repairs. RUNWAY-CONDITION HOLD for 13/31; scheduled airline/charter permissions unverified. | 2026-10-24 07:47:37.097642+00 |
| DMW | MD | `OURAIRPORTS:19643` | [Source](https://carrollcountyregionalairport.com/airport-services/) | Carroll County Regional DMW operator Westminster MD lists charter business Skytech, Jet A/100LL, flight school, maintenance, runway/taxiway lighting and PAPI. Named charter company is a lead requiring current Part 135/licensing/aircraft fit verification; not scheduled airline admission. | 2026-10-24 07:47:37.097642+00 |
| MQB | IL | `OURAIRPORTS:20553` | [Source](https://www.airnav.com/airport/MQB) | FAA-derived Macomb Municipal MQB Illinois public-use facility, screen runway ~5100ft. Specific runway pavement/obstacle status, FBO fuel services and current airline/charter/cargo privileges require airport management confirmation; no approved operator established. | 2026-10-24 07:47:37.097642+00 |
| SUW | WI | `OURAIRPORTS:21120` | [Source](https://www.superiorwi.gov/231/Richard-I-Bong-Memorial-Airport) | Superior city Richard I Bong Memorial SUW official site reports longest runway 5100x75ft, 100LL/Jet A, repairs, medevac helicopters, flight instruction and recreational aviation. Separate from Duluth DLH airline airport; medical aviation not automatic scheduled or certificated charter service. | 2026-10-24 07:47:37.097642+00 |
| LUM | WI | `OURAIRPORTS:20382` | [Source](https://www.airnav.com/airport/LUM) | FAA Oct 2026 Menomonie Municipal/Score Field LUM WI runway 09/27 5074x75ft asphalt FAIR, crosswind 18/36 3470x75ft also FAIR, Jet A+/100LL and major repairs. Current condition/approach obstructions and commercial charter certification need operator review. | 2026-10-24 07:47:37.097642+00 |
| 42J | FL | `OURAIRPORTS:18766` | [Source](https://www.fdot.gov/aviation/airportslist/42J) | FDOT annual inspection Keystone Heights 42J FL: main runway 05/23 nonprecision/visual with RW05 displaced threshold; crosswind 11/29 VISUAL ONLY. License/inspection does not grant carrier route rights; aircraft-specific usable landing distance pending. | 2026-10-24 07:47:37.097642+00 |
| FOM | UT | `OURAIRPORTS:19888` | [Source](https://www.airnav.com/airport/FOM) | FAA-derived Fillmore Municipal FOM Utah 5040x75ft ASPHALT FAIR, S-12 pavement, 4910ft elevation, runway markings POOR/faded, snow clearance secondary priority. 100LL/Jet A; aircraft loading, winter and charter rights require verification. | 2026-10-24 07:47:37.097642+00 |
| O05 | CA | `OURAIRPORTS:20672` | [Source](https://www.airnav.com/airport/O05) | FAA Oct 2026 Rogers Field O05 Chester CA, 5020x100ft ASPHALT FAIR, elevation 4534ft, mountain trees and seasonal firefighting aircraft on field, RNAV 34 only; 100LL/Jet A but no repairs. Confirm seasonal closure, density-altitude/charter permissions. | 2026-10-24 07:47:37.097642+00 |
| FPY | FL | `OURAIRPORTS:18757` | [Source](https://www.taylorcountygov.com/residents/perry_foley_airport/index.php) | Taylor County Perry-Foley FPY FL; FDOT 2026 directory lists runways 18/36 5013x100ft and 12/30 4754x100ft, both asphalt/concrete, 100LL and Jet A, weekday attendance; not evidence of scheduled passenger or cargo operator authorization. | 2026-10-24 07:47:37.097642+00 |
| HSB | IL | `OURAIRPORTS:20085` | [Source](https://www.airnav.com/airport/HSB) | FAA-derived Harrisburg-Raleigh HSB Illinois public GA airfield in runway-condition follow-up queue, candidate ~5000ft. Verify current paved runway rating, lighting, service and commercial charter/cargo rights with operator; no scheduled airline established. | 2026-10-24 07:47:37.097642+00 |
