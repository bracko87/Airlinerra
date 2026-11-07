# Section 4 — Terminals & Facilities: World 1 closure audit
**Checked:** 7 November 2026. **Scope:** all 3,141 approved Airlinerra airports. **Data:** live Supabase private airport facilities and profiles.

## Executive conclusion
**Section 4 is not complete.** Every airport has a facilities row and estimated terminal counts. But there are **zero fully verified records**, **89** airports with no gate/stand counts, and **11 entire operational facility fields blank for every airport**. Only **10** facilities records hold any source URL. Existing values are largely **game-tier estimates**, not certified/individually confirmed physical facts.

## Populated and missing
| Data point | Populated | Still missing |
|---|---:|---:|
| Terminal count (modelled) | 3,141 | 0 |
| Passenger gates | 3,052 | 89 |
| Aircraft stands, contact/remote/cargo stand breakdown | 3,052 each | 89 each |
| Cargo priority | 3,125 | 16 |
| Jet bridge count | 0 | 3,141 |
| Apron area | 0 | 3,141 |
| Parking-position count | 0 | 3,141 |
| Hangar/maintenance capacity | 0 | 3,141 |
| Customs availability | 0 | 3,141 |
| International operations allowed | 0 | 3,141 |
| Scheduled passenger service availability | 0 | 3,141 |
| Cargo handling service availability | 0 | 3,141 |
| Ground handling service availability | 0 | 3,141 |
| Fuel service availability | 0 | 3,141 |
| Fire and rescue (ARFF) category | 0 | 3,141 |
| Cargo movement share percentage (optional supporting evidence) | 2 | 3,139 |

**Research status:** 3,052 `pending`; 89 `research`; **0 `verified`**. The `facilities_gates` research queue separately marks **all 3,141 as pending**.

**Source evidence:** 10 records contain a `source_url`, and none of the 6,546 entries in `airport_field_evidence` references a Section 4 facility field. A generic airport website is not necessarily evidence for the specific terminal/gate number.

**Game-vs-real:** Current `terminal_count` is set to only **1, 2 or 3** for all airports, based mostly on game tier; do **not** report this as a verified actual number of terminals. Stand counts are similarly tier-derived game capacity estimates, even though the arithmetic currently balances. A category change caused the 89 intentional unpopulated stand records.

## 89 airports with missing gates and aircraft stand breakdown
| Tier | Missing | Total in tier |
|---|---:|---:|
| Major Hub | 42 | 229 |
| Medium | 29 | 1778 |
| Large | 11 | 887 |
| Mega Hub | 7 | 41 |
| Regional | 0 | 102 |
| Local | 0 | 104 |

**Reason:** 71 `tier_correction_requires_section4_facility_reverification_20261104` and 18 `owner_category_6_to_5_pending_operational_reverification_20261104`. These need review against the new category, not a blind copy of old counts.

| # | Code | Airport | Country | Game tier |
|---:|---|---|---|---|
| 1 | BOM | Chhatrapati Shivaji Maharaj International Airport | IN | Mega Hub |
| 2 | DXB | Dubai International Airport | AE | Mega Hub |
| 3 | DOH | Hamad International Airport | QA | Mega Hub |
| 4 | NRT | Narita International Airport | JP | Mega Hub |
| 5 | MNL | Ninoy Aquino International Airport | PH | Mega Hub |
| 6 | SHA | Shanghai Hongqiao International Airport | CN | Mega Hub |
| 7 | TPE | Taiwan Taoyuan International Airport | TW | Mega Hub |
| 8 | AYT | Antalya International Airport | TR | Major Hub |
| 9 | TLV | Ben Gurion International Airport | IL | Major Hub |
| 10 | BRU | Brussels Airport | BE | Major Hub |
| 11 | CAI | Cairo International Airport | EG | Major Hub |
| 12 | YYC | Calgary International Airport | CA | Major Hub |
| 13 | CLT | Charlotte Douglas International Airport | US | Major Hub |
| 14 | CKG | Chongqing Jiangbei International Airport | CN | Major Hub |
| 15 | CVG | Cincinnati Northern Kentucky International Airport | US | Major Hub |
| 16 | CPH | Copenhagen Kastrup Airport | DK | Major Hub |
| 17 | HNL | Daniel K. Inouye International Airport | US | Major Hub |
| 18 | DTW | Detroit Metropolitan Wayne County Airport | US | Major Hub |
| 19 | NLU | Felipe Ángeles International Airport | MX | Major Hub |
| 20 | HGH | Hangzhou Xiaoshan International Airport | CN | Major Hub |
| 21 | LAS | Harry Reid International Airport | US | Major Hub |
| 22 | HEL | Helsinki Vantaa Airport | FI | Major Hub |
| 23 | CJU | Jeju International Airport | KR | Major Hub |
| 24 | BCN | Josep Tarradellas Barcelona-El Prat Airport | ES | Major Hub |
| 25 | MCI | Kansas City International Airport | US | Major Hub |
| 26 | KWI | Kuwait International Airport | KW | Major Hub |
| 27 | LGA | LaGuardia Airport | US | Major Hub |
| 28 | LHW | Lanzhou Zhongchuan International Airport | CN | Major Hub |
| 29 | LIS | Lisbon Humberto Delgado Airport | PT | Major Hub |
| 30 | STN | London Stansted Airport | GB | Major Hub |
| 31 | MEL | Melbourne Airport | AU | Major Hub |
| 32 | MSP | Minneapolis–Saint Paul International Airport / Wold–Chamberlain Field | US | Major Hub |
| 33 | BNA | Nashville International Airport | US | Major Hub |
| 34 | MCO | Orlando International Airport | US | Major Hub |
| 35 | ORY | Paris-Orly Airport | FR | Major Hub |
| 36 | PHX | Phoenix Sky Harbor International Airport | US | Major Hub |
| 37 | FCO | Rome–Fiumicino Leonardo da Vinci International Airport | IT | Major Hub |
| 38 | SLC | Salt Lake City International Airport | US | Major Hub |
| 39 | SAN | San Diego International Airport | US | Major Hub |
| 40 | SEA | Seattle–Tacoma International Airport | US | Major Hub |
| 41 | STL | St. Louis Lambert International Airport | US | Major Hub |
| 42 | ARN | Stockholm-Arlanda Airport | SE | Major Hub |
| 43 | URC | Ürümqi Tianshan International Airport | CN | Major Hub |
| 44 | IAD | Washington Dulles International Airport | US | Major Hub |
| 45 | WUH | Wuhan Tianhe International Airport | CN | Major Hub |
| 46 | XIY | Xi'an Xianyang International Airport | CN | Major Hub |
| 47 | XMN | Xiamen Gaoqi International Airport | CN | Major Hub |
| 48 | CGO | Zhengzhou Xinzheng International Airport | CN | Major Hub |
| 49 | ZRH | Zürich Airport | CH | Major Hub |
| 50 | BEY | Beirut Rafic Hariri International Airport | LB | Large |
| 51 | CZX | Changzhou Benniu International Airport | CN | Large |
| 52 | OMA | Eppley Airfield | US | Large |
| 53 | FAT | Fresno Yosemite International Airport | US | Large |
| 54 | LXA | Lhasa Gonggar International Airport | CN | Large |
| 55 | BTS | M. R. Štefánik Airport | SK | Large |
| 56 | NTG | Nantong Xingdong International Airport | CN | Large |
| 57 | PIT | Pittsburgh International Airport | US | Large |
| 58 | RUN | Roland Garros Airport | RE | Large |
| 59 | YTY | Yangzhou Taizhou Airport | CN | Large |
| 60 | ZAZ | Zaragoza Airport | ES | Large |
| 61 | AAL | Aalborg Airport | DK | Medium |
| 62 | YEI | Bursa Yenişehir Airport | TR | Medium |
| 63 | COS | City of Colorado Springs Municipal Airport | US | Medium |
| 64 | CFE | Clermont-Ferrand Auvergne airport | FR | Medium |
| 65 | DEB | Debrecen International Airport | HU | Medium |
| 66 | YQX | Gander International Airport | CA | Medium |
| 67 | CUU | General Roberto Fierro Villalobos International Airport | MX | Medium |
| 68 | GRQ | Groningen Airport Eelde | NL | Medium |
| 69 | AGT | Guaraní International Airport | PY | Medium |
| 70 | AOE | Hasan Polatkan Airport | TR | Medium |
| 71 | IBR | Ibaraki Airport | JP | Medium |
| 72 | IVL | Ivalo Airport | FI | Medium |
| 73 | KLV | Karlovy Vary Airport | CZ | Medium |
| 74 | KSF | Kassel Airport | DE | Medium |
| 75 | KLU | Klagenfurt Airport | AT | Medium |
| 76 | LPI | Linköping City Airport | SE | Medium |
| 77 | MST | Maastricht Aachen Airport | NL | Medium |
| 78 | SLA | Martín Miguel de Güemes International Airport | AR | Medium |
| 79 | KRP | Midtjyllands Airport / Air Base Karup | DK | Medium |
| 80 | CND | Mihail Kogălniceanu International Airport | RO | Medium |
| 81 | PED | Pardubice Airport | CZ | Medium |
| 82 | RGL | Piloto Civil Norberto Fernández International Airport | AR | Medium |
| 83 | PDV | Plovdiv International Airport | BG | Medium |
| 84 | NDG | Qiqihar Sanjiazi Airport | CN | Medium |
| 85 | RES | Resistencia International Airport | AR | Medium |
| 86 | SCR | Scandinavian Mountains Airport | SE | Medium |
| 87 | TMP | Tampere-Pirkkala Airport | FI | Medium |
| 88 | VAA | Vaasa Airport | FI | Medium |
| 89 | RKZ | Xigaze Peace Airport / Shigatse Air Base | CN | Medium |

## Other fields present but belong primarily to other sections
The `airport_facilities` table also has **0** populated fields for `operating_hours_local`, `curfew_details`, `noise_restrictions`, and `weather_minima`. These are addressed under **Section 5 — Airport Operations & Weather**. Do not duplicate those studies just to declare Section 4 complete. Detailed slot allocation, movement and capacity constraints belong under **Section 6**.

## Required tasks before declaring game-data completion
1. Resolve the **89** changed-category airports and recalculate/verify gates, total stands, contact/remote/cargo splits using the approved six-tier and passenger/cargo model. Retain source/provenance for any independently checked figures.
2. Resolve the **16** unassigned cargo-priority flags and avoid treating unknown data as a negative answer.
3. Define and fill game values or explicit `unknown/not modelled` states for jet bridges, apron, aircraft parking positions and hangar/maintenance capacity. Never present simulated values as official airport data.
4. Define operational gameplay policy for customs, international flights, scheduled passenger handling, cargo handling, ground handling and fuel. Where data is unknown, choose and label a provisional *game rule* rather than asserting real-world availability.
5. Define a clear game ARFF/fire-rescue requirement and fallback. Never falsely claim a real certified rescue category.
6. Separate equipment/facility data from **Section 5** time/noise/weather rules and **Section 6** airport slot capacity. Decide which values are essential Section 4 blockers vs later integrations.
7. Validate all 3,141 facilities with nonnegative counts, consistent stand splits, justified tier/category updates, per-field source/provenance and released game-ready statuses. Close/reconcile the 3,141 open `facilities_gates` queue entries only after verification of the applicable game baseline.
8. Connect facility permissions/capabilities to the route/airport player interface and future operational-fleet system; run signed-in production validation. Full live flight dispatch also depends on issue #10.

**Important definition:** You may finish Section 4 as *game-data complete* by explicitly approving simulated facility defaults for unverified cases. That is not the same as verifying all 3,141 physical airports with official source documents.

## Existing dependencies
- Section 5 source-backed airport restrictions: GitHub issue #9.
- Real operational aircraft, crew, fleet positioning and active flight execution: GitHub issue #10.
- No database rows or game values were modified by this read-only audit.