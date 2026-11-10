# Airlinerra — Cabin seat catalog and aircraft row geometry (2026-11-10)

Status: **40 game-priced seat choices (10 per class) + 271/271 aircraft cabin row defaults in production Supabase.**
No installed airframes were reconfigured, and no funds or flight operations were changed.

## How to use the data

The aircraft floorplan now uses the `cabin_model_row_geometry_v1` entry corresponding to the aircraft configuration, not seat capacity thresholds alone. A typical single-aisle Airbus A319 shows **3–3**, an Airbus A220 **2–3**, an Embraer E-Jet **2–2**, and a 777 **3–4–3**. Each cabin class can use a separate number of seats abreast. Seats expand sideways across the **entire usable illustrated cabin width**, while the aisle(s) remain clear.

**Proof level is essential:** 271 records are assigned, but **none is marked manually verified yet**. 4 have a manufacturer-supported family arrangement, 37 an operator-supported typical row arrangement, 140 require family/model research and 90 are cargo-only. Airline-specific arrangements and exact row geometries still need manual validation.

The **real-world brand/product references** are sourced; seat pitch, width, space-unit multiplier and installation prices shown below are **Airlinerra game assumptions**, not certified product dimensions, supplier quotes, regulatory clearances or an airline seat purchase agreement. The 11 earlier generic options remain to protect saved drafts; 29 additional real-product references bring the catalog to 10 per class.

## Seat options

| Cabin | Seat option | Pitch (in, game) | Width (in, game) | Space units | Install price (USD, game) | Research reference |
|---|---|---:|---:|---:|---:|---|
| economy | Safran Z85 · dense | 29.0 | 17.2 | 0.96 | 540 | [Safran Z85](https://www.safran-group.com/products-services?category%5B0%5D=381-passenger-seats) |
| economy | RECARO R1 · slimline | 29.0 | 17.3 | 0.97 | 550 | [RECARO R1](https://www.recaro-as.com/en/aircraft-seats/economy-class.html) |
| economy | Standard economy | 30.0 | 17.5 | 1.00 | 450 | Generic real-world category; game baseline |
| economy | RECARO R2 · comfort | 30.0 | 17.8 | 1.02 | 680 | [RECARO R2](https://www.recaro-as.com/en/aircraft-seats/economy-class.html) |
| economy | Safran Z200 · classic | 31.0 | 17.8 | 1.06 | 770 | [Safran Z200](https://www.safran-group.com/products-services?category%5B0%5D=381-passenger-seats) |
| economy | Safran Z300 · long-haul | 32.0 | 18.0 | 1.12 | 1050 | [Safran Z300](https://www.safran-group.com/products-services?category%5B0%5D=381-passenger-seats) |
| economy | RECARO R3 · long-range | 32.0 | 18.5 | 1.13 | 900 | [RECARO R3](https://www.recaro-as.com/en/aircraft-seats/economy-class/r3.html) |
| economy | Extra legroom economy | 34.0 | 18.0 | 1.15 | 700 | Generic real-world category; game baseline |
| economy | Safran Z400 · comfort | 34.0 | 18.5 | 1.20 | 1250 | [Safran Z400](https://www.safran-group.com/products-services?category%5B0%5D=381-passenger-seats) |
| economy | Comfort economy | 36.0 | 18.5 | 1.25 | 950 | Generic real-world category; game baseline |
| premium | Premium economy | 38.0 | 19.5 | 1.40 | 1700 | Generic real-world category; game baseline |
| premium | ZIM ZP450 · premium | 38.0 | 19.0 | 1.44 | 2800 | [ZIM ZP450](https://www.zim.aero/en-us/product-range/premium) |
| premium | RECARO PL3530 | 40.0 | 19.5 | 1.48 | 2600 | [RECARO PL3530](https://www.recaro-as.com/en/aircraft-seats/economy-class/pl3530.html) |
| premium | Safran Z535i | 40.0 | 20.0 | 1.52 | 3100 | [Safran Z535i](https://www.safran-group.com/products-services/premium-economy-class-seat-z535i) |
| premium | Collins MiQ · premium | 40.0 | 20.0 | 1.56 | 3400 | [Collins MiQ](https://www.rtx.com/collinsaerospace/what-we-do/industries/commercial-aviation/cabin/seating/business-class/miq) |
| premium | RECARO R4 | 41.0 | 20.0 | 1.57 | 3300 | [RECARO R4](https://www.recaro-as.com/en/press/press-releases/details/recaro-launches-the-next-generation-of-premium-class-seating-r4.html) |
| premium | Premium recliner | 42.0 | 20.0 | 1.60 | 2600 | Generic real-world category; game baseline |
| premium | ZIM ZP610 · shell | 41.0 | 19.0 | 1.61 | 4100 | [ZIM ZP610](https://www.zim.aero/en-us/products/zim-zp600-series) |
| premium | Safran AIRGO FX Premium | 42.0 | 20.0 | 1.72 | 3900 | [AIRGO FX PREMIUM](https://www.safran-group.com/products-services?category%5B0%5D=381-passenger-seats) |
| premium | Geven Comoda AQ | 44.0 | 20.5 | 1.87 | 4500 | [Geven Comoda AQ](https://www.geven.com/products-hx) |
| business | Business recliner | 44.0 | 20.5 | 1.90 | 4400 | Generic real-world category; game baseline |
| business | Collins MiQ · business | 43.0 | 20.5 | 1.93 | 5500 | [Collins MiQ](https://www.rtx.com/collinsaerospace/what-we-do/industries/commercial-aviation/cabin/seating/business-class/miq) |
| business | RECARO R5 · recliner | 44.0 | 21.0 | 1.94 | 5300 | [RECARO R5](https://www.recaro-as.com/en/press/press-releases/details/recaro-aircraft-seating-debuts-new-seat-naming-concept-at-aix-2024.html) |
| business | Safran Z600 · regional | 45.0 | 20.5 | 1.99 | 4900 | [Safran Z600](https://www.safran-group.com/products-services?category%5B0%5D=381-passenger-seats) |
| business | Lie-flat business | 74.0 | 21.0 | 3.30 | 10000 | Generic real-world category; game baseline |
| business | Collins Diamond · flat | 76.0 | 21.0 | 3.42 | 15100 | [Collins Diamond family](https://www.rtx.com/collinsaerospace/what-we-do/industries/commercial-aviation/cabin/seating/business-class/maya) |
| business | RECARO R7 · lie-flat | 79.0 | 21.5 | 3.56 | 16000 | [RECARO R7](https://www.recaro-as.com/en/press/press-releases/details/recaro-aircraft-seating-debuts-new-seat-naming-concept-at-aix-2024.html) |
| business | ZIMluxury · lie-flat | 77.0 | 22.0 | 3.62 | 17400 | [ZIMluxury](https://www.aeroexpo.online/prod/zim-flugsitz-gmbh-171913.html) |
| business | Safran FUSIO · suite | 80.0 | 22.0 | 3.83 | 19500 | [Safran FUSIO](https://www.safran-group.com/products-services/business-class-seat-fusio) |
| business | Business suite | 79.0 | 22.0 | 3.90 | 15000 | Generic real-world category; game baseline |
| first | First-class recliner | 60.0 | 23.0 | 3.00 | 9000 | Generic real-world category; game baseline |
| first | First-class suite | 82.0 | 25.0 | 5.20 | 26000 | Generic real-world category; game baseline |
| first | Emirates A380 private suite | 84.0 | 26.0 | 5.65 | 42000 | [Emirates A380 Private Suite](https://www.emirates.com/media-centre/elevating-luxury-emirates-unveils-more-enhancements-to-first-class/) |
| first | ANA First Square | 83.0 | 27.0 | 5.90 | 58000 | [ANA First Square](https://www.ana.co.jp/en/jp/guide/flight_service_info/int-service/f/seat/) |
| first | ANA THE Suite | 85.0 | 28.0 | 6.15 | 65000 | [ANA THE Suite](https://www.ana.co.jp/en/de/travel-information/cabin/b777-300er-first-class/) |
| first | Private first-class suite | 88.0 | 28.0 | 6.30 | 38000 | Generic real-world category; game baseline |
| first | Singapore A380 Suite | 90.0 | 28.0 | 6.40 | 80000 | [Singapore Airlines A380 Suites](https://www.singaporeair.com/en_UK/us/flying-withus/cabins/suites/) |
| first | Lufthansa Allegris First | 92.0 | 30.0 | 7.10 | 92000 | [Lufthansa Allegris First Class Suite](https://www.lufthansa.com/de/en/discover-lufthansa/allegris) |
| first | Emirates 777 Game Changer | 94.0 | 30.0 | 7.20 | 75000 | [Emirates 777 Game Changer Suite](https://www.emirates.com/us/english/experience/our-fleet/gamechanger/) |
| first | Air France La Première | 94.0 | 30.0 | 7.70 | 100000 | [Air France La Première](https://corporate.airfrance.com/en/news/air-france-unveils-its-new-la-premiere-experience-highest-expression-travel) |

## Every model / configuration — initial row assignment

**Columns**: Economy, Premium Economy, Business, First indicate seats abreast from left to right separated by aisles. The figure is a typical **layout pattern**, not an exact airline LOPA/certification. A380 and other double-deck aircraft require separate floorplans by deck in a later phase. Combi aircraft retain only their existing passenger-part capacity.

| Config ID | Manufacturer / aircraft | Type | Reference passengers | Economy | Premium | Business | First | Review status |
|---:|---|---|---:|---|---|---|---|---|
| 15 | Airbus A300-600F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 162 | Airbus A300-600R | passenger | 274 | 2–4–2 | 2–2–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 163 | Airbus A310-300 | passenger | 243 | 2–4–2 | 2–2–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 167 | Airbus A310-300 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 189 | Airbus A318-100 | passenger | 136 | 3–3 | 2–2 | 2–2 | 1–1 | operator_supported_pattern |
| 16 | Airbus A319-100 | passenger | 156 | 3–3 | 2–2 | 2–2 | 1–1 | operator_supported_pattern |
| 118 | Airbus A319neo | passenger | 160 | 3–3 | 2–2 | 2–2 | 1–1 | operator_supported_pattern |
| 3 | Airbus A320-200 | passenger | 180 | 3–3 | 2–2 | 2–2 | 1–1 | operator_supported_pattern |
| 72 | Airbus A320neo | passenger | 194 | 3–3 | 2–2 | 2–2 | 1–1 | operator_supported_pattern |
| 190 | Airbus A320P2F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 117 | Airbus A321-100 | passenger | 205 | 3–3 | 2–2 | 2–2 | 1–1 | operator_supported_pattern |
| 17 | Airbus A321-200 | passenger | 220 | 3–3 | 2–2 | 2–2 | 1–1 | operator_supported_pattern |
| 88 | Airbus A321-200 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 73 | Airbus A321-200P2F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 191 | Airbus A321LR | passenger | 244 | 3–3 | 2–2 | 2–2 | 1–1 | operator_supported_pattern |
| 18 | Airbus A321neo | passenger | 244 | 3–3 | 2–2 | 2–2 | 1–1 | operator_supported_pattern |
| 19 | Airbus A321XLR | passenger | 244 | 3–3 | 2–2 | 2–2 | 1–1 | operator_supported_pattern |
| 20 | Airbus A330-200 | passenger | 406 | 2–4–2 | 2–2–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 87 | Airbus A330-200 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 164 | Airbus A330-200F (factory freighter) | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 74 | Airbus A330-200P2F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 21 | Airbus A330-300 | passenger | 440 | 2–4–2 | 2–2–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 122 | Airbus A330-300P2F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 115 | Airbus A330-800neo | passenger | 406 | 2–4–2 | 2–2–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 22 | Airbus A330-900neo | passenger | 465 | 2–4–2 | 2–2–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 169 | Airbus A340-200 | passenger | 420 | 2–4–2 | 2–2–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 116 | Airbus A340-300 | passenger | 440 | 2–4–2 | 2–2–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 239 | Airbus A340-500 | passenger | 375 | 2–4–2 | 2–2–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 23 | Airbus A340-600 | passenger | 297 | 2–4–2 | 2–2–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 24 | Airbus A350-1000 | passenger | 480 | 3–3–3 | 2–3–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 240 | Airbus A350-1000ULR | passenger | 238 | 3–3–3 | 2–3–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 25 | Airbus A350-900 | passenger | 440 | 3–3–3 | 2–3–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 192 | Airbus A350-900ULR | passenger | 440 | 3–3–3 | 2–3–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 233 | Airbus A350F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 26 | Airbus A380-800 | passenger | 509 | 3–4–3 | 2–3–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 13 | Airbus Canada A220-100 | passenger | 135 | 2–3 | 2–2 | 1–1 | 1–1 | manufacturer_supported_pattern |
| 14 | Airbus Canada A220-300 | passenger | 160 | 2–3 | 2–2 | 1–1 | 1–1 | manufacturer_supported_pattern |
| 159 | Antonov An-12BK | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 158 | Antonov An-12BP | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 10 | Antonov An-124-100 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 214 | Antonov An-148-100 | passenger | 85 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 124 | Antonov An-24 | passenger | 48 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 227 | Antonov An-26B | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 125 | Antonov An-26B-100 | combi | 42 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 126 | Antonov An-32 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 228 | Antonov An-72 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 170 | Antonov An-74TK-100 | combi | 52 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 178 | Antonov An-74TK-100 | passenger | 52 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 179 | Antonov An-74TK-100 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 156 | ATR ATR 42-300 | passenger | 48 | 2–2 | 1–1 | 1–1 | 1–1 | operator_supported_pattern |
| 241 | ATR ATR 42-300 | combi | 30 | 2–2 | 1–1 | 1–1 | 1–1 | operator_supported_pattern |
| 142 | ATR ATR 42-320 | passenger | 48 | 2–2 | 1–1 | 1–1 | 1–1 | operator_supported_pattern |
| 154 | ATR ATR 42-320 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 242 | ATR ATR 42-320 | combi | 30 | 2–2 | 1–1 | 1–1 | 1–1 | operator_supported_pattern |
| 111 | ATR ATR 42-500 | passenger | 48 | 2–2 | 1–1 | 1–1 | 1–1 | operator_supported_pattern |
| 27 | ATR ATR 42-600 | passenger | 50 | 2–2 | 1–1 | 1–1 | 1–1 | operator_supported_pattern |
| 182 | ATR ATR 72-200 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 202 | ATR ATR 72-200 | passenger | 74 | 2–2 | 1–1 | 1–1 | 1–1 | operator_supported_pattern |
| 80 | ATR ATR 72-500 | passenger | 68 | 2–2 | 1–1 | 1–1 | 1–1 | operator_supported_pattern |
| 177 | ATR ATR 72-500 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 28 | ATR ATR 72-600 | passenger | 78 | 2–2 | 1–1 | 1–1 | 1–1 | operator_supported_pattern |
| 203 | ATR ATR 72-600 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 243 | ATR ATR 72-600 | combi | 44 | 2–2 | 1–1 | 1–1 | 1–1 | operator_supported_pattern |
| 4 | ATR ATR 72-600F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 113 | Avro Avro RJ100 | passenger | 112 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 112 | Avro Avro RJ85 | passenger | 100 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 244 | Avro RJ70 | passenger | 82 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 123 | Beechcraft Beechcraft 1900C | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 204 | Beechcraft Beechcraft 1900C | passenger | 19 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 93 | Beechcraft Beechcraft 1900D | passenger | 19 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 205 | Beechcraft Beechcraft 1900D | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 94 | Beechcraft Beechcraft Model 99 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 29 | Boeing 717-200 | passenger | 106 | 2–3 | 2–2 | 1–1 | 1–1 | game_estimate_needs_review |
| 245 | Boeing 727-200 | passenger | 189 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 139 | Boeing Boeing 727-200 Freighter | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 230 | Boeing 737 MAX 10 | passenger | 230 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 229 | Boeing 737 MAX 7 | passenger | 172 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 35 | Boeing 737 MAX 8 | passenger | 210 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 36 | Boeing 737 MAX 9 | passenger | 220 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 193 | Boeing 737-200 | passenger | 130 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 246 | Boeing 737-200 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 30 | Boeing 737-200C | combi | 112 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 155 | Boeing 737-300 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 187 | Boeing 737-300 | passenger | 147 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 31 | Boeing 737-300C | combi | 130 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 114 | Boeing 737-400SF | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 119 | Boeing 737-600 | passenger | 132 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 32 | Boeing 737-700 | passenger | 149 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 247 | Boeing 737-700C | combi | 121 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 120 | Boeing 737-700F (converted freighter) | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 1 | Boeing 737-800 | passenger | 189 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 85 | Boeing 737-800 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 86 | Boeing 737-800 | combi | 90 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 161 | Boeing 737-800 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 121 | Boeing 737-800BCF | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 33 | Boeing 737-800SF | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 2 | Boeing 737-8200 | passenger | 197 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 194 | Boeing 737-900 | passenger | 189 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 34 | Boeing 737-900ER | passenger | 220 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 138 | Boeing Boeing 737-300SF | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 143 | Boeing Boeing 737-400 | passenger | 156 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 153 | Boeing Boeing 737-400 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 160 | Boeing Boeing 737-400 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 188 | Boeing Boeing 737-400 | combi | 72 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 144 | Boeing Boeing 737-500 | passenger | 122 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 248 | Boeing 747-200B | passenger | 550 | 3–4–3 | 2–3–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 166 | Boeing 747-200C (convertible) | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 195 | Boeing 747-200F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 249 | Boeing 747-200M | combi | 330 | 3–4–3 | 2–3–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 250 | Boeing 747-300 | passenger | 605 | 3–4–3 | 2–3–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 37 | Boeing 747-400 | passenger | 371 | 3–4–3 | 2–3–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 38 | Boeing 747-400BCF | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 252 | Boeing 747-400ER | passenger | 524 | 3–4–3 | 2–3–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 168 | Boeing 747-400ERF | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 39 | Boeing 747-400F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 253 | Boeing 747-400M | combi | 350 | 3–4–3 | 2–3–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 41 | Boeing 747-8 Intercontinental | passenger | 605 | 3–4–3 | 2–3–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 40 | Boeing 747-8F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 42 | Boeing 757-200 | passenger | 186 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 196 | Boeing 757-200 | combi | 148 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 43 | Boeing 757-200F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 44 | Boeing 757-300 | passenger | 243 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 254 | Boeing 767-200 | passenger | 290 | 2–3–2 | 2–2–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 197 | Boeing 767-200 Freighter | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 255 | Boeing 767-200ER | passenger | 255 | 2–3–2 | 2–2–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 256 | Boeing 767-300 | passenger | 350 | 2–3–2 | 2–2–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 45 | Boeing 767-300BCF | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 46 | Boeing 767-300BDSF | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 47 | Boeing 767-300ER | passenger | 350 | 2–3–2 | 2–2–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 48 | Boeing 767-300F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 49 | Boeing 767-400ER | passenger | 409 | 2–3–2 | 2–2–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 198 | Boeing 777-200 | passenger | 440 | 3–4–3 | 2–3–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 50 | Boeing 777-200ER | passenger | 335 | 3–4–3 | 2–3–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 51 | Boeing 777-200LR | passenger | 335 | 3–4–3 | 2–3–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 199 | Boeing 777-300 | passenger | 550 | 3–4–3 | 2–3–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 52 | Boeing 777-300ER | passenger | 390 | 3–4–3 | 2–3–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 257 | Boeing 777-300ERSF | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 258 | Boeing 777-8F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 234 | Boeing 777-9 | passenger | 450 | 3–4–3 | 2–3–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 5 | Boeing 777F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 84 | Boeing 787-10 | passenger | 340 | 3–3–3 | 2–3–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 53 | Boeing 787-8 | passenger | 240 | 3–3–3 | 2–3–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 54 | Boeing 787-9 | passenger | 285 | 3–3–3 | 2–3–2 | 1–2–1 | 1–2–1 | operator_supported_pattern |
| 259 | Bombardier CRJ100 | passenger | 50 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 100 | Bombardier CRJ100 Parcel Freighter | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 130 | Bombardier CRJ1000 | passenger | 104 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 99 | Bombardier CRJ200 | passenger | 50 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 55 | Bombardier CRJ550 | passenger | 50 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 56 | Bombardier CRJ700 | passenger | 78 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 57 | Bombardier CRJ900 | passenger | 90 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 260 | British Aerospace BAe 146-100 | passenger | 94 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 183 | British Aerospace BAe 146-200 | passenger | 112 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 186 | British Aerospace BAe 146-200 | passenger | 70 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 176 | British Aerospace BAe 146-200QT | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 207 | British Aerospace BAe 146-300 | passenger | 112 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 75 | British Aerospace BAe 146-300QT | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 206 | British Aerospace Jetstream 31 | passenger | 19 | 1–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 98 | British Aerospace Jetstream 32 | passenger | 19 | 1–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 97 | British Aerospace Jetstream 41 | passenger | 30 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 147 | CASA CASA C-212-200 Aviocar | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 9 | COMAC C909-700 (formerly ARJ21-700) | passenger | 97 | 2–3 | 2–2 | 1–1 | 1–1 | game_estimate_needs_review |
| 222 | COMAC C909-700F (ARJ21F) | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 8 | COMAC C919-100 | passenger | 192 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 104 | De Havilland Canada Dash 7-100 | passenger | 50 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 59 | De Havilland Canada Dash 8-100 | combi | 37 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 91 | De Havilland Canada Dash 8-100 | passenger | 37 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 149 | De Havilland Canada Dash 8-100 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 105 | De Havilland Canada Dash 8-202 | passenger | 37 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 60 | De Havilland Canada Dash 8-300 | combi | 45 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 89 | De Havilland Canada Dash 8-300 | combi | 45 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 90 | De Havilland Canada Dash 8-300 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 148 | De Havilland Canada Dash 8-300 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 200 | De Havilland Canada Dash 8-300 | passenger | 56 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 61 | De Havilland Canada Dash 8-400 (Q400) | passenger | 90 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 261 | De Havilland Canada Dash 8-400 (Q400) | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 262 | De Havilland Canada Dash 8-400 (Q400) | combi | 68 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 140 | De Havilland Canada DHC-6-100 Twin Otter | passenger | 19 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 141 | De Havilland Canada DHC-6-200 Twin Otter | passenger | 19 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 58 | De Havilland Canada DHC-6-300 | passenger | 19 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 150 | De Havilland Canada DHC-6-300 | passenger | 19 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 12 | De Havilland Canada DHC-6-400 | passenger | 19 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 263 | Deutsche Aircraft D328eco | passenger | 40 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 62 | Dornier Dornier 228 | passenger | 19 | 1–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 264 | Dornier Dornier 228 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 102 | Dornier Dornier 328-110 | passenger | 33 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 101 | Dornier Dornier 328JET | passenger | 33 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 131 | Douglas Aircraft Company DC-6 cargo-configured | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 63 | Embraer E170 | passenger | 78 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 64 | Embraer E175 | passenger | 88 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 65 | Embraer E190 | passenger | 114 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 79 | Embraer E195 | passenger | 122 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 265 | Embraer E195F (P2F) | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 145 | Embraer Embraer E190F (P2F) | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 129 | Embraer E190-E2 | passenger | 114 | 2–2 | 1–1 | 1–1 | 1–1 | manufacturer_supported_pattern |
| 11 | Embraer E195-E2 | passenger | 136 | 2–2 | 1–1 | 1–1 | 1–1 | manufacturer_supported_pattern |
| 208 | Embraer EMB 110 Bandeirante | passenger | 21 | 1–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 209 | Embraer EMB 110 Bandeirante | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 95 | Embraer EMB 120 Brasilia | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 201 | Embraer EMB 120 Brasilia | passenger | 30 | 1–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 76 | Embraer ERJ 135 | passenger | 37 | 1–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 77 | Embraer ERJ 140 | passenger | 44 | 1–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 78 | Embraer ERJ 145 | passenger | 50 | 1–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 96 | Fairchild Swearingen SA227 Metroliner | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 210 | Fairchild Swearingen SA227 Metroliner | passenger | 19 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 212 | Fokker F27 Friendship | passenger | 62 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 266 | Fokker F27 Friendship | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 184 | Fokker F28-1000C Fellowship | passenger | 70 | 2–3 | 2–2 | 1–1 | 1–1 | game_estimate_needs_review |
| 267 | Fokker F28-4000 | passenger | 85 | 2–3 | 2–2 | 1–1 | 1–1 | game_estimate_needs_review |
| 66 | Fokker Fokker 100 | passenger | 109 | 2–3 | 2–2 | 1–1 | 1–1 | game_estimate_needs_review |
| 103 | Fokker Fokker 50 | passenger | 56 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 211 | Fokker Fokker 50 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 67 | Fokker Fokker 70 | passenger | 80 | 2–3 | 2–2 | 1–1 | 1–1 | game_estimate_needs_review |
| 223 | Harbin Aircraft Y-12E | passenger | 18 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 224 | Harbin Aircraft Y-12F | passenger | 19 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 225 | Harbin Aircraft Y-12F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 232 | Ilyushin Il-114-300 | passenger | 68 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 221 | Ilyushin Il-62M | passenger | 198 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 110 | Ilyushin Il-76TD | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 220 | Ilyushin Il-96-300 | passenger | 300 | 3–3–3 | 2–3–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 165 | Ilyushin Il-96-400T | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 171 | Let Aircraft Industries L-410 NG | passenger | 19 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 213 | Let Aircraft Industries L-410 UVP-E | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 92 | Let Aircraft Industries L-410 UVP-E20 | passenger | 19 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 132 | Lockheed L-100-30 Hercules | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 109 | Lockheed Lockheed L-382G Hercules | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 268 | Lockheed L-1011-1 TriStar | passenger | 400 | 2–5–2 | 2–3–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 269 | Lockheed L-1011-500 TriStar | passenger | 330 | 2–5–2 | 2–3–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 137 | Lockheed Lockheed L-188 Electra Freighter | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 270 | McDonnell Douglas DC-10-30 | passenger | 380 | 2–5–2 | 2–3–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 271 | McDonnell Douglas DC-10-30F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 185 | McDonnell Douglas DC-9-15F | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 272 | McDonnell Douglas MD-11 | passenger | 410 | 2–5–2 | 2–3–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 6 | McDonnell Douglas MD-11 Freighter | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 273 | McDonnell Douglas MD-11C | combi | 300 | 2–5–2 | 2–3–2 | 1–2–1 | 1–2–1 | game_estimate_needs_review |
| 175 | McDonnell Douglas MD-82 | passenger | 172 | 2–3 | 2–2 | 1–1 | 1–1 | game_estimate_needs_review |
| 174 | McDonnell Douglas MD-83 | passenger | 172 | 2–3 | 2–2 | 1–1 | 1–1 | game_estimate_needs_review |
| 127 | McDonnell Douglas MD-83SF | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 173 | McDonnell Douglas MD-87 | passenger | 139 | 2–3 | 2–2 | 1–1 | 1–1 | game_estimate_needs_review |
| 274 | McDonnell Douglas MD-88 | passenger | 172 | 2–3 | 2–2 | 1–1 | 1–1 | game_estimate_needs_review |
| 128 | McDonnell Douglas MD-88SF | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 236 | McDonnell Douglas MD-90-30 | passenger | 172 | 2–3 | 2–2 | 1–1 | 1–1 | game_estimate_needs_review |
| 82 | Saab Saab 2000 | passenger | 53 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 172 | Saab Saab 340A | passenger | 37 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 180 | Saab Saab 340A | combi | 34 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 181 | Saab Saab 340A | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 68 | Saab Saab 340B | passenger | 37 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 134 | Saab Saab 340B | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 151 | Saab Saab 340B | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 146 | Saab Saab 340B(F) | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 108 | Short Brothers Shorts SD3-30 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 238 | Short Brothers Shorts SD3-30 | passenger | 30 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 83 | Short Brothers Short 360 | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 237 | Short Brothers Short 360 | passenger | 39 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 69 | Sukhoi Civil Aircraft Superjet 100-95 | passenger | 103 | 2–3 | 2–2 | 1–1 | 1–1 | game_estimate_needs_review |
| 215 | Sukhoi Civil Aircraft Superjet 100-95LR | passenger | 103 | 2–3 | 2–2 | 1–1 | 1–1 | game_estimate_needs_review |
| 106 | Textron Aviation Cessna 208B Grand Caravan | passenger | 13 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 152 | Textron Aviation Cessna 208B Grand Caravan | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 107 | Textron Aviation Cessna 208B Grand Caravan EX | passenger | 13 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 7 | Textron Aviation Cessna 408 SkyCourier | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 133 | Textron Aviation Cessna 408 SkyCourier | passenger | 19 | 1–1 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 218 | Tupolev Tu-154B-2 | passenger | 180 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 70 | Tupolev Tu-204-100B | passenger | 210 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 216 | Tupolev Tu-204-100C | cargo | 0 | Cargo only | Cargo only | Cargo only | Cargo only | cargo_not_applicable |
| 217 | Tupolev Tu-204-300 | passenger | 164 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 71 | Tupolev Tu-214 | passenger | 210 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 81 | Xian Aircraft MA60 | passenger | 60 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 226 | Xian Aircraft MA600 | passenger | 60 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 231 | Yakovlev MC-21-310 | passenger | 211 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |
| 235 | Yakovlev SJ-100 (PD-8) | passenger | 103 | 2–3 | 2–2 | 1–1 | 1–1 | game_estimate_needs_review |
| 219 | Yakovlev Yak-40 | passenger | 36 | 2–2 | 1–1 | 1–1 | 1–1 | game_estimate_needs_review |
| 157 | Yakovlev Yak-42D | passenger | 120 | 3–3 | 2–2 | 2–2 | 1–1 | game_estimate_needs_review |

## Manual review backlog

All 271 configurations have default data; **0/271** have been manually approved as an individual model layout. When reviewing a model later, confirm and record:
- Exact economy seats across (e.g. 3–3), class-specific row arrangements, single vs twin aisle, deck count.
- Seat capacity by actual aisle/galley/lavatory/crew/exits, row blocking, emergency exit zones and aircraft model-specific geometry.
- Aircraft fit and certification status for each proposed seat product. **Do not equate a game 'fits by units' result with installation approval.**
- Sources and whether a configuration corresponds to a specific airline or a generic manufacturer variant.
- Change its `manually_verified` field only after source-backed review, with `reviewed_at`. No unverified model is automatically approved by this migration.

## Technical implementation

- Migration: `supabase/migrations/20261110184500_airlinerra_40_real_reference_seats_and_model_geometry_v1.sql`.
- Evidence label correction: `supabase/migrations/20261110185800_airlinerra_cabin_pattern_review_sources_v1.sql`.
- Tables: `airlinerra_game.cabin_seat_types_v1`, `airlinerra_game.cabin_model_row_geometry_v1`.
- Read-only seat + geometry through `cabin-overview` in owner-verified `server/fleet-acquisition-service.mjs` (Supabase Edge function `airlinerra-fleet-acquisition` v14).
- Frontend: `website/cabin-configuration-manager.mjs` draws model-specific rows, supplier reference links, four cabin class styles and shows status.
- Existing `cabin-save-draft` still only writes airline-owned cabin drafts, not installed seats or finances.
- Verified example: A319-100 reference 156 Economy, 26 rows of 3–3; the drawn outer seat blocks fill approximately 93.7% of cabin illustration width while keeping a central aisle.
