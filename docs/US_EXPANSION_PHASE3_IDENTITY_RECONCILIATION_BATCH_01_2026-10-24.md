# Airlinerra — Phase 3: Airport Identity Reconciliation, Batch 01 (2026-10-24)

**STATUS: VERIFIED IN SUPABASE.** All **74** candidate identity-hold cases were individually cross-checked against the current FAA matching information, historical FAA-location-identifier change tables and relevant airport-specific owner/current-FAA data. This review specifically separates confirmed old→new location identifiers from exceptional incorrect notes and geographic/administrative issues. Historical registry `source_ident` values and immutable airport keys were preserved.

## Reconciliation result

| Result | Airport records |
|---|---:|
| **Published historical identifier lineage corroborated** | **61** |
| **Current canonical identity/source error independently reconciled** | **6** |
| **Total identity issues resolved to next eligibility stage** | **67 / 74** |
| **Special unresolved code/geographic source cases** | **7** |
| Duplicate airport keys created / source keys overwritten | **0 / 0** |
| Final game admissions, world activations, category approvals | **0 / 0 / 0** |
| Original playable airport cohort | **3,140 unchanged** |

Resolved does **not** mean cleared to join the game. All 67 move only to `IDENTITY_RECONCILED_NEXT_ELIGIBILITY`, where their runway, aircraft, local owner and operational restrictions still require verification. All seven unresolved cases remain `IDENTITY_HOLD`.

## Current complete Phase 3 selection table

| Stage | Airports |
|---|---:|
| Preliminary physical shortlist, pending final eligibility | 1,013 |
| Operational constraint hold | 833 |
| **Identity reconciled, next eligibility check** | **67** |
| Identity unresolved | 7 |
| Provisional exclusion review | 8 |
| Pavement data/condition hold | 1 |
| **Total selection records** | **1,929** |

The prior shortlist count is **unchanged**. No additional airport has been activated or assigned an official game tier.

## How the 61 historical code changes were validated

The [AirNav published U.S. public-use airport identifier change ledger](https://www.airnav.com/airports/id-changes-all.html) gives direct **old identifier → current FAA identifier** mappings for 61 physical candidates. Each mapping matched the database's original `source_ident` after appropriate ICAO `K` prefix handling, the **current FAA identifier**, and an already recorded exact FAA facility/location match. The original airport key, source identifier, names and coordinates were **not rewritten**; published old/new code history is stored in the separate identity evidence ledger.

Some airports have a marketing municipality different from a physically nearby city—for instance Covington/Atlanta labeling. That does not by itself indicate a second runway or duplicate airport; canonical FAA code, airport name and geographic position must all remain consistent.

| Current FAA | State | Immutable airport key | Historical → current code | Candidate airport name | Published source |
|---|---|---|---|---|---|
| BFZ | AL | `OURAIRPORTS:19114` | 8A0 → BFZ | Albertville Regional Airport/Thomas J Br... | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| CQF | AL | `OURAIRPORTS:18845` | 4R4 → CQF | H L Sonny Callahan Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| HDL | AL | `OURAIRPORTS:18369` | 0J6 → HDL | Headland Municipal Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| ADF | AR | `OURAIRPORTS:20461` | M89 → ADF | Dexter B Florence Memorial Field | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| JTC | AZ | `OURAIRPORTS:19608` | D68 → JTC | Springerville Municipal Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| CFO | CO | `OURAIRPORTS:19903` | FTG → CFO | Colorado Air and Space Port | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| CO4 | CO | `OURAIRPORTS:19222` | A50 → CO4 | Colorado Springs East Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| FLY | CO | `OURAIRPORTS:18306` | 00V → FLY | Meadow Lake Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| RCV | CO | `OURAIRPORTS:19147` | 8V1 → RCV | Astronaut Kent Rominger Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| RYA | CO | `OURAIRPORTS:18629` | 2V5 → RYA | Wray Municipal Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| BCR | FL | `OURAIRPORTS:18477` | 1J0 → BCR | Tri-County Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| FHB | FL | `OURAIRPORTS:18881` | 55J → FHB | Fernandina Beach Municipal Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| FIN | FL | `OURAIRPORTS:21400` | XFL → FIN | Flagler Executive Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| FPY | FL | `OURAIRPORTS:18757` | 40J → FPY | Perry-Foley Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| CNI | GA | `OURAIRPORTS:18786` | 47A → CNI | Cherokee County Regional Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| CPP | GA | `OURAIRPORTS:18709` | 3J7 → CPP | Greene County Regional Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| CVC | GA | `OURAIRPORTS:19175` | 9A1 → CVC | Covington Municipal Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| EBA | GA | `OURAIRPORTS:18556` | 27A → EBA | Elbert County Airport Patz Field | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| HMP | GA | `OURAIRPORTS:18805` | 4A7 → HMP | Atlanta Speedway Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| JCA | GA | `OURAIRPORTS:18439` | 19A → JCA | Jackson County Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| MAN | ID | `OURAIRPORTS:21014` | S67 → MAN | Nampa Municipal Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| GPC | IN | `OURAIRPORTS:18823` | 4I7 → GPC | Putnam County Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| I20 | IN | `OURAIRPORTS:20770` | 2IG4 → I20 | Ed-Air Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| JHN | KS | `OURAIRPORTS:18597` | 2K3 → JHN | Stanton County Municipal Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| BYL | KY | `OURAIRPORTS:21353` | W38 → BYL | Williamsburg Whitley County Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| GDA | KY | `OURAIRPORTS:18916` | 5M9 → GDA | Marion-Crittenden County James C Johnson... | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| JQD | KY | `OURAIRPORTS:19062` | 7K4 → JQD | Ohio County Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| SJS | KY | `OURAIRPORTS:20244` | K22 → SJS | Big Sandy Regional Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| SYM | KY | `OURAIRPORTS:45427` | M97 → SYM | Morehead-Rowan County Clyde A. Thomas Re... | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| APS | LA | `OURAIRPORTS:18483` | 1L0 → APS | Port of South Louisiana Executive Region... | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| IYA | LA | `OURAIRPORTS:18387` | 0R3 → IYA | Abbeville Chris Crusta Memorial Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| MNE | LA | `OURAIRPORTS:19805` | F24 → MNE | Minden Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| REG | LA | `OURAIRPORTS:20297` | L38 → REG | Louisiana Regional Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| FYG | MO | `OURAIRPORTS:20541` | MO6 → FYG | Washington Regional Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| OZS | MO | `OURAIRPORTS:20007` | H21 → OZS | Camdenton Memorial Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| PCD | MO | `OURAIRPORTS:20236` | K02 → PCD | Perryville Regional Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| JVW | MS | `OURAIRPORTS:20412` | M16 → JVW | John Bell Williams Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| RVF | MT | `OURAIRPORTS:19076` | 7S1 → RVF | Ruby Valley Field | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| SCR | NC | `OURAIRPORTS:18938` | 5W8 → SCR | Siler City Municipal Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| BAC | ND | `OURAIRPORTS:18981` | 6D8 → BAC | Barnes County Municipal Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| BRG | NM | `OURAIRPORTS:19709` | E80 → BRG | Belen Regional Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| DNA | NM | `OURAIRPORTS:18929` | 5T6 → DNA | Doña Ana County International Jetport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| SXU | NM | `OURAIRPORTS:20135` | I58 → SXU | Santa Rosa Route 66 Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| RTS | NV | `OURAIRPORTS:18853` | 4SD → RTS | Reno-Stead Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| TMT | NV | `OURAIRPORTS:19204` | 9U3 → TMT | Austin Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| HTF | NY | `OURAIRPORTS:18819` | 4G6 → HTF | Hornell Municipal Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| IUA | NY | `OURAIRPORTS:19598` | D38 → IUA | Canandaigua Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| JPX | NY | `OURAIRPORTS:20093` | HTO → JPX | Town of East Hampton Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| GDK | OH | `OURAIRPORTS:20124` | I19 → GDK | Greene County/Lewis A. Jackson Regional ... | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| JRO | OH | `OURAIRPORTS:20131` | I43 → JRO | James A Rhodes Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| SCA | OH | `OURAIRPORTS:20120` | I12 → SCA | Sidney Municipal Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| GZL | OK | `OURAIRPORTS:19834` | F84 → GZL | Stigler Regional Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| RCE | OK | `OURAIRPORTS:19807` | F29 → RCE | Clarence E Page Municipal Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| JSY | OR | `OURAIRPORTS:18851` | 4S3 → JSY | Joseph State Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| XNX | TN | `OURAIRPORTS:20427` | M33 → XNX | Music City Executive Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| LUV | TX | `OURAIRPORTS:18581` | 2F5 → LUV | Lamesa Municipal Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| TXW | TX | `OURAIRPORTS:21161` | T65 → TXW | Mid Valley International Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| SVR | UT | `OURAIRPORTS:21261` | U42 → SVR | South Valley Regional Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| W11 | WI | `OURAIRPORTS:9987` | 31WI → W11 | Sullivan Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| DUB | WY | `OURAIRPORTS:21257` | U25 → DUB | Dubois Municipal Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |
| DWX | WY | `OURAIRPORTS:19205` | 9U4 → DWX | Dixon Airport | [Alias history](https://www.airnav.com/airports/id-changes-all.html) |

## Six additional independently reconciled source/geography cases

| FAA | Immutable airport key | Resolution and remaining eligibility context | Evidence |
|---|---|---|---|
| A08 | `OURAIRPORTS:19213` | A08 is Vaiden Field, Marion AL; incorrect Wetumpka description replaced with source-backed Vaiden record. Active lighting/marking restrictions still require evaluation. | [Evidence](https://www.airnav.com/airport/A08) |
| HEF | `OURAIRPORTS:20041` | FAA aeronautical procedure tables categorize HEF under Washington DC administratively; the physical airport is in Manassas Virginia as FAA airport overview confirms. Registry geographic region US-VA is appropriate; do not overw... | [Evidence](https://www.faa.gov/flight_deck/hef) |
| CBE | `OURAIRPORTS:19462` | Airport owner confirms Greater Cumberland Regional CBE physically Wiley Ford West Virginia while FAA administrative airport state is Maryland. Current geographic registry US-WV and FAA MD admin labeling intentionally differ. | [Evidence](https://cbeairport.com/about/) |
| HFJ | `OURAIRPORTS:20444` | HFJ is Monett Regional, Missouri; prior Neosho Hugh Robinson citation removed from commercial research and preserved in audit event as a cross-airport mistake. | [Evidence](https://www.airnav.com/airport/HFJ) |
| N58 | `OURAIRPORTS:20614` | Canonical 2026 N58 is Samsarg Field at Fernley Nevada, matching coordinates. Registry Tiger Field is an older name, not another active airport. Poor 40ft pavement/ditch and animal hazards remain. | [Evidence](https://www.airnav.com/airport/N58) |
| FZI | `OURAIRPORTS:19918` | Canonical 2026 FZI is Donald P Miller Airport in Fostoria Ohio. Registry Fostoria Metropolitan name is legacy branding for same field and code; source label provenance retained. | [Evidence](https://www.airnav.com/airport/FZI) |

**A08 — Vaiden Field, Alabama.** The FAA-derived 2026 airport record says **Vaiden Field at Marion**, not Wetumpka. Its published runway is about **6,400×80ft asphalt**, with **all airfield lighting reported inoperable** and severely faded runway markings. The incorrect Wetumpka research description was replaced, while restrictions remain operative follow-up. [Current FAA-derived airport detail](https://www.airnav.com/airport/A08).

**HFJ — Monett Regional, Missouri.** Earlier commercial research incorrectly used **Neosho-Hugh Robinson Memorial** information. Corrected to [Monett-specific FAA-derived record](https://www.airnav.com/airport/HFJ); Neosho's original misattribution is retained in the audit event for traceability.

**FZI — Donald P Miller Airport, Ohio.** Current FAA airport name differs from registry's historical **Fostoria Metropolitan** label. Same airport ID and position; display-name change must be applied carefully during subsequent controlled integration. [Current FAA-derived record](https://www.airnav.com/airport/FZI).

**N58 — Samsarg Field, Nevada.** Historic **Tiger Field** registry display name differs from current FAA **Samsarg Field**; matching code/geolocation indicates one airfield. Source reports very poor/narrow asphalt, adjacent ditches, gradients and animals, so identity resolution does **not** imply acceptable runway. [FAA-derived N58 detail](https://www.airnav.com/airport/N58).

**HEF — Manassas Regional, VA.** The FAA [airport overview](https://www.faa.gov/flight_deck/hef) confirms the runway physically near Manassas **Virginia**, while FAA terminal-procedure publications can administratively list it under **Washington, DC**. Hence `faa_state=DC` does not automatically mean bad FAA data, while original registry `region_code=US-VA` is geographically correct. Do not overwrite administrative origin with game geographic status.

**CBE — Greater Cumberland Regional, WV.** [Airport owner](https://cbeairport.com/about/) explicitly confirms physical airfield at Wiley Ford **West Virginia** with FAA administrative classification under **Maryland**. Retain jurisdiction/provenance distinctions rather than silently changing both to one state.

Three incorrect Phase 1 `source_research_note` entries—**A08, HFJ, H04**—were explicitly corrected and independently preserved as **three `PHASE3_RESEARCH_SOURCE_CORRECTION` audit events**, including previous notes and URLs. **H04 is not marked resolved** because the registry and currently published FAA latitude still differ materially.

## Seven cases still needing evidence or data correction

| FAA | Immutable key | Why not yet reconciled | Required next work |
|---|---|---|---|
| 71J | `OURAIRPORTS:19024` | Current FAA screen matches 71J, but published historical-identifier list does not directly resolve 71J or the underlying source... | Current FAA record identifies Ozark/Blackwell Field as 71J in Alabama but registry source_gps_code K71U differs; resolve provenance and other airport identity before c... |
| RGA | `OURAIRPORTS:20129` | Current FAA screen matches RGA, but published historical-identifier list does not directly resolve I39 or the underlying source... | Reconcile original I39/KI39 and current RGA/KRGA geolocation and name with FAA, no duplicate key; check charter/cargo permits. |
| 22T | `OURAIRPORTS:10193` | Current FAA screen matches 22T, but published historical-identifier list does not directly resolve 36MI or the underlying sourc... | Reconcile FAA 22T / historical 36MI identity and coordinates before code change; confirm owner use rights and approach LDA. |
| RGK | `OURAIRPORTS:20926` | Current FAA screen matches RGK, but published historical-identifier list does not directly resolve RGK or the underlying source... | Reconcile actual geographic state against FAA administrative locality using coordinates, preserve immutable key; verify commercial minimum standards. |
| 1PP | `OURAIRPORTS:20675` | Current FAA screen matches 1PP, but published historical-identifier list does not directly resolve O11 or the underlying source... | Reconcile old O11/KO11 airport identity and current 1PP with source coordinates; require owner/tribal commercial permission and pavement repair evidence. |
| H04 | `OURAIRPORTS:20003` | Current FAA screen matches H04, but published historical-identifier list does not directly resolve H04 or the underlying source... | Reconcile H04 Vinita official FAA/owner source and coordinates versus separate OJA Weatherford; replace erroneous research linkage after independent evidence check, th... |
| 2E5 | `OURAIRPORTS:18576` | Current FAA screen matches 2E5, but published historical-identifier list does not directly resolve 2E5 or the underlying source... | Resolve code collision against NASR/OurAirports while preserving immutable key; then verify declared runway lengths, narrow night lighting and 12,500lb single-wheel lo... |

- **H04 Vinita, OK:** Corrected research now identifies Vinita rather than Weatherford/OJA. Current FAA coordinate is approximately **36.614616, -95.151695**, while old registry contains **36.632999, -95.151398**. Investigate coordinate discrepancy and physical runway identity before changing registry geography.
- **71J Ozark/Blackwell:** Current FAA code/owner confirmed as **71J**, but source GPS field still reads `K71U`; do not manufacture an ICAO code without source evidence.
- **2E5 Dell City:** Registry `source_gps_code=KGDP` conflicts with current FAA `2E5`; investigate why unrelated code is present.
- **1PP Stilwell/Cherokee Nation:** Registry code `O11` to current `1PP` lineage is not yet independently confirmed; tribal owner commercial permission and serious pavement issues remain separate.
- **22T Tecumseh Mills:** Old `36MI` registration/source history not corroborated in the published public-use historical lookup.
- **RGA Richmond, KY:** Old `I39` to current `RGA` transition not found in that history list. Current code alone is insufficient to prove origin.
- **RGK Red Wing:** Owner Red Wing, Minnesota describes airport physically in **Wisconsin**. Registry geographical state is still `US-MN`. Clarify administrative versus physical jurisdiction and record a verified geographic correction before future playable airport integration.

## Safety controls and next engineering task

- Exactly six eventual game airport categories: **Local, Regional, Medium, Large, Major Hub, Mega Hub**. No classification was assigned by this audit.
- Identifiers can be considered resolved while the aircraft/runway/owner eligibility gate remains a hold. These distinct dimensions are now represented separately in Supabase.
- `airlinerra.airport_expansion_identity_resolution_phase3` stores all 74 evidence records; RLS is enabled and public/anon/authenticated direct privileges revoked.
- `airlinerra.airport_expansion_selection_phase3` remains unapproved and its check constraint explicitly recognizes `IDENTITY_RECONCILED_NEXT_ELIGIBILITY`. Database integrity read-back returned **74 unique identity records**, **67 resolved**, **7 unresolved** and **zero** selection/status inconsistencies.
- Continue with the seven actual code/geography exceptions; then perform current runway, aircraft and owner-use eligibility checks for identity-reconciled candidates and the 1,013 preliminary shortlist. Do **not** add airports to world activation, change game categories, or count unconfirmed runway extensions as existing pavement.

**Result: Phase 3 identity reconciliation progress = 67/74 confirmed, 7 require further evidence. Game expansion admissions remain zero.**
