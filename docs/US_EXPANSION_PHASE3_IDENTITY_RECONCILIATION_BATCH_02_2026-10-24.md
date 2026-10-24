# Airlinerra — Phase 3 Airport Identity Reconciliation, Batch 02: Final Seven (2026-10-24)

**Supabase-completed, independently read back: 74 of 74 canonical identities reconciled; zero identity holds.** Batch 02 evaluated the final seven, verified their current FAA identity and stored source-specific caveats and next actions. The original airport registry codes, coordinates and physical airport keys were NOT overwritten.

**Important scope:** Canonical airport identity resolution is *not* a guarantee of uninterrupted historical operating status or absolute validation of an unofficial ICAO/GPS alias. Any raw source mismatch is recorded for a controlled later migration. These 74 are now `IDENTITY_RECONCILED_NEXT_ELIGIBILITY`, meaning runway, owner restrictions and aircraft-specific landing suitability still need checking. Zero are admitted into gameplay.

## Seven final reconciled cases

| Current FAA | Immutable airport key | Original source code | Source-backed canonical identification and remaining qualifications | Next action | Evidence |
|---|---|---|---|---|---|
| 1PP | `OURAIRPORTS:20675` | KO11 | The FAA historical NPIAS table identifies O11 as Stilwell/Cherokee Nation Airport, Oklahoma; archive airport information identifies the same airport name and approximately 35.757,-94.650. The 2026 FAA record identifies 1PP Stilwell/Cherokee Nation at 35.7571847,-94.6498569, public use w... | Canonical FAA airport 1PP and physical location established. Confirm tribal owner permissions, poor paved runway condition, exact O11 to 1PP historical regulatory tran... | [Source](https://www.faa.gov/sites/faa.gov/files/airports/planning_capacity/npias/current/NPIAS_App_A_part_5.pdf) |
| 22T | `OURAIRPORTS:10193` | 36MI | Tecumseh Mills is current FAA 22T, Michigan, approximately 42.033849,-83.878354; the historical OurAirports facility page rooted under 36MI identifies local code 22T and older registry coordinates 42.034351,-83.879328. This confirms one physical airport with historical source identifier... | Retain original 36MI as historical source provenance and canonical 22T for matching. Resolve airport-specific runway/owner commercial rights separately. | [Source](https://ourairports.com/airports/36MI/closest-navaids.html?show=&sort=&start=1300) |
| 2E5 | `OURAIRPORTS:18576` | K2E5 | FAA 2026 Dell City Municipal is 2E5, Texas, at approximate coordinates 31.9475,-105.1917. Historic/secondary international-code catalogs associate KGDP with Dell City Municipal itself; KGDP is not demonstrated to be a distinct airport. Canonical FAA identifier 2E5 confirmed, preserve KG... | Use FAA 2E5 for operational identification; mark KGDP unverified historical/secondary GPS/ICAO alias and keep original source value unchanged. Verify runway loading, l... | [Source](https://www.airnav.com/airport/2E5) |
| 71J | `OURAIRPORTS:19024` | K71J | Current FAA procedure list explicitly identifies 71J (K71J) as Ozark/Blackwell Field, AL, and original registry facility name/coordinates are consistent. Registry K71U GPS-code entry is noncanonical relative to published FAA K71J; preserve it as a legacy/error field, not a separate lice... | Use canonical 71J (K71J) in airport matching, never use K71U as proof of FAA code; defer source_gps_code correction until controlled provenance review. Verify runway/f... | [Source](https://www.faa.gov/air_traffic/flight_info/aeronav/procedures/application/index.cfm?event=procedure.results&nasrId=71J&orderBy=procedure&orderDirection=asc&tab=charts) |
| H04 | `OURAIRPORTS:20003` | KH04 | City of Vinita and FAA current publications identify H04 as Vinita Municipal at 36.6146163,-95.1516948, with runway 17/35. Old registry coordinate 36.632999,-95.151398 is approximately 2.0 km north of the actual airport and must not be used for map routing. Earlier Weatherford/OJA attri... | Use canonical FAA/Vinita location 36.6146163,-95.1516948 in any later admission migration; audit geospatial update and check live runway LDA, narrow 60ft runway, opera... | [Source](https://cityofvinita.com/191/FAA-Information) |
| RGA | `OURAIRPORTS:20129` | KI39 | Kentucky Transportation Cabinet lists Central Kentucky Regional (aka Madison Airport) at Richmond under historical I39; current FAA 2026 source identifies the same airport as RGA/KRGA. Consistent airport name, town and source coordinates confirm one physical airport; original KI39 retai... | Use current FAA RGA as canonical identifier and preserve old KI39. Review present FAA runway/owner/operating rules without assuming old I39 airport conditions are curr... | [Source](https://transportation.ky.gov/Aviation/Pages/Kentucky-Airports.aspx?ID=17) |
| RGK | `OURAIRPORTS:20926` | KRGK | Red Wing city states Red Wing Regional RGK is physically at W7245 Highway 35, Bay City, Wisconsin, while owned and operated by City of Red Wing, Minnesota. Existing candidate FAA state MN is administrative/marketing; registry US-MN geographical region is wrong for physical jurisdiction;... | Use physical geographic region US-WI in later game integration, distinct from FAA Minnesota administrative listing. Update original registry geographic fields only thr... | [Source](https://www.redwingmn.gov/400/Red-Wing-Airport) |

### Evidence interpretation

- **1PP Stilwell/Cherokee Nation, OK** — Historical [FAA NPIAS airport inventory](https://www.faa.gov/sites/faa.gov/files/airports/planning_capacity/npias/current/NPIAS_App_A_part_5.pdf) identifies **O11** as Stilwell/Cherokee Nation. Current [2026 FAA-derived airport data](https://www.airnav.com/airport/1PP) identifies **1PP** and approximately 35.757185,-94.649857; retained 2007-era facility coordinates place the same named tribal airport essentially at that site. The October 2019 FAA activation field does **not independently establish a precise code-change effective date**. Owner commercial permissions and pavement repairs remain unresolved.
- **22T Tecumseh Mills, MI** — [Older OurAirports facility entry under 36MI](https://ourairports.com/airports/36MI/closest-navaids.html?show=&sort=&start=1300) identifies local code **22T**, airport name and matching Tecumseh location. Current [FAA-derived record](https://www.airnav.com/airport/22T) is 22T. Same physical airport, with remaining aircraft/owner verification.
- **2E5 Dell City, TX** — FAA canonical **2E5**, while the raw legacy `KGDP` reference is used in older/secondary ICAO code lists for **Dell City Municipal**, not demonstrably a separate airport. Keep official FAA **2E5** as canonical; do not treat KGDP as verified *current* FAA ICAO assignment.
- **71J Ozark/Blackwell, AL** — [FAA instrument-procedure lookup](https://www.faa.gov/air_traffic/flight_info/aeronav/procedures/application/index.cfm?event=procedure.results&nasrId=71J&orderBy=procedure&orderDirection=asc&tab=charts) explicitly reports **71J (K71J)**. Raw source GPS field `K71U` is not treated as authoritative. Same name and location, canonical code verified.
- **H04 Vinita, OK** — [City of Vinita](https://cityofvinita.com/191/FAA-Information) and [FAA data](https://www.airnav.com/airport/H04) agree on current **H04** and canonical coordinates, distinct from Weatherford **OJA**. Old registry coordinate is about **2km away**; its corrected canonical position is saved in the *separate* resolution table. Game routing must not consume the original erroneous coordinate uncorrected.
- **RGA Central Kentucky Regional, KY** — [Kentucky Transportation Cabinet](https://transportation.ky.gov/Aviation/Pages/Kentucky-Airports.aspx?ID=17) still lists historical **I39** for Central Kentucky Regional/Madison near Richmond, while current FAA airport identity is **RGA**. Historical name/city/location identify one airfield; preserve original KI39 code.
- **RGK Red Wing Regional, WI (physical)** — [City of Red Wing airport address](https://www.redwingmn.gov/400/Red-Wing-Airport) is **W7245 Highway 35, Bay City, Wisconsin**, while owner/operator and FAA city name reference Red Wing, Minnesota. Saved `physical_region_code=US-WI` separately; original registry `US-MN` is not yet migrated.

## Canonical location overrides saved independently

The location overrides below are stored in `airlinerra.airport_expansion_identity_resolution_phase3`, **not written into the original airport registry**. Other geographical overrides from prior reconciliation include **HEF = US-VA**, **CBE = US-WV** and **RGK = US-WI**.

| Current FAA | Raw registry latitude, longitude | Verified canonical latitude, longitude | Physical region |
|---|---|---|---|
| 1PP | 35.757000, -94.649902 | 35.7571847, -94.6498569 | US-OK |
| H04 | 36.632999, -95.151398 | 36.6146163, -95.1516948 | US-OK |

Airport admission and map/route integration must explicitly consume verified canonical overrides after a separately authorized source migration; until then, the original 74 airports cannot be assumed location-safe for gameplay merely because `IDENTITY_HOLD` is zero.

## Full Phase 3 screening after Batch 02

| Status | Count |
|---|---:|
| `PRELIMINARY_SHORTLIST` | 1013 |
| `OPERATIONAL_CONSTRAINT_HOLD` | 833 |
| `IDENTITY_RECONCILED_NEXT_ELIGIBILITY` | 74 |
| `PROVISIONAL_EXCLUSION_REVIEW` | 8 |
| `RUNWAY_CONDITION_OR_DATA_HOLD` | 1 |
| **Total** | **1,929** |

The verified integrity audit returned **74 unique identity records, zero remaining `IDENTITY_HOLD` rows, zero reconciliation-to-stage inconsistencies and no duplicate additions**. The game remains untouched: **zero expansion admissions, zero activations, zero approved categories** and the original **3,140-airport cohort unchanged**.

## Remaining eligibility work

**Next:** Evaluate eight provisional runway exclusions and the one missing pavement-condition record (AST). Dated NOTAMs must be checked against current operating windows, while damaged/asphalt-closed and displaced-threshold airports require direction-specific usable LDA. Afterward, progress through the 833 operating-constraint holds and the 1,013 preliminary shortlisted fields by type-specific runway, owner, and geospatial validity. Current commercial scheduled flights are **not a prerequisite** for an airport to enter an airline-management simulation.

Exactly six eventual game categories are **Local, Regional, Medium, Large, Major Hub, Mega Hub**. Phase 3 decisions assign none; they only screen and retain source evidence.

**No airport activation, category change or original 3,140 roster mutation was made.**
