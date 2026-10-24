# Airlinerra — U.S. Expansion Batch 52 (2026-10-24)

**IN PROGRESS — NOT COMPLETE.** The latest verified completed batch is Batch 51: 1,743 of 1,929 reviewed, 186 unreviewed, and zero game admissions. Batch 52 has begun, but repeated safety-check blocks prevent database writes and full queue retrieval. At least the first source review for `OURAIRPORTS:18682` / 3DW was saved by a confirmed one-row SQL update; a fresh aggregate/readback must establish the exact new total. **Do not count all ten below as reviewed.**

These ten airport keys were obtained from the actual unreviewed queue before the access blockage. Their research evidence is first-pass and does NOT grant commercial-service clearance.

| FAA | State | Immutable key | Airport | Evidence | Airport-specific finding and hold | Persistence |
|---|---|---|---|---|---|---|
| 3DW | MO | `OURAIRPORTS:18682` | Downtown Airport, Springfield | [FAA-derived](https://www.airnav.com/airport/3DW) | 4,037×50ft asphalt, 8,000lb single-wheel capacity, nonstandard lights; distinct from Springfield-Branson scheduled SGF | Saved (single-row return); pending final readback |
| 3GV | MO | `OURAIRPORTS:18700` | East Kansas City, Grain Valley | [FAA-derived](https://www.airnav.com/airport/3GV) | 4,507×44ft main runway, 11,000lb single-wheel, 303ft displaced RW09, nonstandard lights and deficient safety areas; privately owned | Not saved |
| 3I2 | WV | `OURAIRPORTS:18703` | Mason County, Point Pleasant | [FAA-derived](https://www.airnav.com/airport/3I2) | Weekday attendance 10:00–14:00, PAPI/REIL/MIRL runway 07/25, AWOS | Not saved |
| 3R2 | LA | `OURAIRPORTS:18731` | Le Gros Memorial, Crowley | [FAA-derived](https://www.airnav.com/airport/3R2) | Weekday staffing 08:00–17:00, runway 04/22 lighting and REIL, no certified airline verified | Not saved |
| 3U7 | MT | `OURAIRPORTS:18745` | Benchmark, Lewis and Clark National Forest | [FAA-derived](https://www.airnav.com/airport/3U7) | 6,000×100ft but **POOR pavement**, long cracks and weeds; no snow removal, 5,434ft elevation and dangerous mountain turbulence | Not saved |
| 40G | AZ | `OURAIRPORTS:18756` | Valle, near Grand Canyon | [FAA-derived](https://www.airnav.com/airport/40G) | Public GA at almost 6,000ft field elevation; density altitude and desert/mountain conditions, owner and carrier rights pending | Not saved |
| 46U | WY | `OURAIRPORTS:18785` | Alpine | [FAA-derived](https://www.airnav.com/airport/46U) | Unattended at 5,637ft altitude, limited winter ramp/parking, landing/overnight fees, mountain conditions | Not saved |
| 49R | TX | `OURAIRPORTS:18799` | Real County, Leakey | [FAA-derived](https://www.airnav.com/airport/49R) | Unattended GA airfield; confirm pavement, services and licensed commercial operators | Not saved |
| 4A5 | AR | `OURAIRPORTS:18803` | Searcy County/Marshall | [FAA-derived](https://www.airnav.com/airport/4A5) | FAA lists 4,003×75ft fair asphalt and 12,500lb rating, runway 05/23 PAPI/REIL out indefinitely; [airport website](https://www.buffaloriverairport.com/) also describes a 2,500×100ft grass strip; reconcile facilities | Not saved |
| 4F2 | TX | `OURAIRPORTS:18813` | Panola County–Sharpe Field, Carthage | [FAA-derived](https://www.airnav.com/airport/4F2) | 24h self-serve 100LL, weekday attendance, runway 17/35 lighting and PAPI; no Jet A listed or carrier proven | Not saved |

No game admission or activation was performed. Game tiers remain exactly six: **Local, Regional, Medium, Large, Major Hub, Mega Hub**.

**Restart checklist:** (1) verify current aggregate and the ten immutable keys in Supabase; (2) save the nine missing notes without overwriting already-reviewed records; (3) select/research exactly forty further unreviewed keys; (4) read back fifty complete unique Batch 52 records; (5) update GitHub report to completed only after verification. Do not accidentally count historical Batch 50/51 records again.
