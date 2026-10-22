# Worldwide initial airport reconciliation — 22 October 2026

## Verified register accounting

Updated Group 1–48 technical files contain **8,151 real runway-qualified airport candidates**; the canonical master `data/airports/airport_register.csv` contains **8,152 records**, including one fictional LYAL airport. There is no Group 49 technical file. The original 7,846-record baseline has increased by 304 real-world airports after further recovery. See `group_technical_counts.csv`.

The previously announced **30-airport shortfall (7,816/7,846)** was an erroneous running subtotal. It is **not** a backlog of thirty missing airports, and there is no basis to create a fictional Group 49 to make up that difference.

**Technical roster coverage ≠ completeness of all worldwide qualifying airports.** SUMU (Uruguay) and KSEA (United States) were confirmed missing from the old baseline and have since been **added on main with original OurAirports IDs**.

## Verified omission: SUMU (Uruguay)

Carrasco General Cesáreo L. Berisso International Airport (SUMU/MVD) has two active runways reported in OurAirports as surface **PEM**, which the current `airport_surface.py` parser now recognizes as eligible composite asphalt/concrete material. Both runway lengths exceed 1,200 m (3,200 m and 2,250 m). Uruguay **DINACIA's July 2026 AIP, SUMU AD 2**, identifies the 3,200 m runway as **concreto asfáltico** (asphalt concrete). It passes Airlinerra's documented surface and length rules. Source: https://www.dinacia.gub.uy/sites/default/files/aip/2026-07/Ad2-9%20esp.pdf ; original surface: https://ourairports.com/airports/SUMU/runways.html .

The airport operator reports **2,144,071 passengers in 2025**: https://aeropuertodecarrasco.com.uy/en/historic-passenger-record-at-carrasco-airport/ . Uruguay INE independently records **36,825 tonnes of scheduled-flight cargo in 2024**: https://www.gub.uy/instituto-nacional-estadistica/comunicacion/publicaciones/anuario-estadistico-nacional-2025-vol-102/47-transporte-15 .

**Source ID protection:** Source airport **6247 (SUMU)** and runway **246026** are present in Group 48 and the master; the official 3,200 m runway surface override is recorded. The case is marked **ADDED_TO_MAIN** in `verified_runway_omissions.csv`. Do not duplicate it. New global total should then increase by one, assuming no other changes.

## Commercial evidence: major limitations

Groups 45–48 include numerous classifications marked YES after code/name shortlist selection, **without individual airport-level traffic-source joins**. These entries are **provisional candidates**, not verified commercial permissions. In particular, the Group 45 US 172 passenger count (the original 3 cargo short-list has now been corrected to 136 FAA-verified all-cargo airport matches), and Group 46 Brazil 50 passenger and 7 cargo counts, are *not* final national counts and should not restrict game routes or freight. See `commercial_verification_backlog.csv`.

FAA authoritative 2025 all-airport passenger and all-cargo sheets: https://www.faa.gov/airports/planning_capacity/passenger_allcargo_stats/passenger?year=all . ANAC Brazil movement data is categorized by commercial passenger versus cargo operations and by charter / general aviation classes: https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/operador-aeroportuario/dados-de-movimentacao-aeroportuaria/metadados-operador-aeroportuario-dados-de-movimentacao-aeroportuaria .

### Release gate

1. Join source datasets to technical airport IDs, verifying exact code aliases (not name guessing).
2. Separate **scheduled passenger**, **charter passenger**, **commercial cargo**, **general aviation**, and **military access**; keep missing evidence as UNKNOWN.
3. Retain the original source technical candidates and LYAL, and Airlinerra's exact six eventual airport categories.
4. Apply validated group-level CSV corrections with an evidence URL per positive and update derived counts.
5. Execute `python scripts/validate_airports.py && python scripts/validate_historical_airports.py && python scripts/rebuild_runway_register.py` on a complete checkout before accepting a technical register edit.

No Supabase changes or playable-airport activation are authorized by this audit.

## FAA all-cargo crosscheck (22 October 2026)

Final FAA 2025 all-cargo landed-weight publication (released 22 September 2026) identifies 153 qualifying positive-airport records, with 136 exactly joined to US airports in Group 45 (133 newly marked cargo YES plus three already positive). The remaining codes include 14 unmatched US entries / crosswalk cases and three facilities classified in other jurisdiction groups (Puerto Rico, Guam). The list of 14 unmatched US sources is in `faa_2025_cargo_airports_missing_from_roster.csv`. The missing airports are **not** to be rejected from the game; verify runway-specific surface labels first. The 136 records are a verified lower-bound subset, **not** all US commercial cargo capability.

## Additional verified runway omission: Seattle–Tacoma (KSEA)

The earlier Group 45 technical screen and worldwide register omitted **KSEA**, but the omission has since been corrected. OurAirports represents the three active runways with surface label `PEM`, not a qualifying explicit concrete/asphalt label. The **Port of Seattle** states all three active runways are concrete/grooved and measures the longest 16L/34R at **11,901 ft (about 3,627 m)**: https://www.portseattle.org/page/sea-airport-basics . The Port also reports **427,971 tonnes of air cargo for 2025** and passenger air-carrier activity; the FAA final CY2025 all-cargo report independently lists SEA as a cargo airport. Source airport **3875 (KSEA)** and runway **242182** are now included in Group 45 and the master; `PEM` is recognized by the current surface parser. This case is marked **ADDED_TO_MAIN**. Do not duplicate it.

## Recheck against active main branch (22 October 2026)

The master now contains 8,152 records; Group 45 has 2,888 source candidates (2,879 US), and Group 48 has 117 (including SUMU). Earlier paragraphs and 136-airport US cargo numbers above describe the pre-recovery snapshot; the separate verification backlog records 149 FAA-supported US cargo-positive airports after expansion. Historic audit claims must not override current source records. Additional technical omissions may still exist and require source-based checking.

## FAA finalized CY2025 US passenger boarding crosswalk — 22 October 2026

The 2,879 Group45 U.S. airport source IDs were matched to the official FAA 2025 enplanement table through the public OurAirports `id` -> `local_code` / `iata_code` crosswalk, constrained to the source U.S. state. **1,266** stable-ID joined FAA positive records: **386 primary commercial service**, **64 nonprimary commercial service**, and **816 FAA general aviation with reported passenger boardings**. **450** are classified passenger YES as proven FAA 2025 commercial-service boardings, compared with the prior unverified 172-name shortlist. The 816 GA-class rows are NOT counted as scheduled airline service. **1,613** technical airport records lack an unambiguous positive FAA 2025 match, and remain UNKNOWN for commercial passenger purposes (this is not negative evidence). **66** FAA positive P/CS records were not matched into the technical runway pool and require qualification review; there were 516 FAA P/CS airports nationally in the source table. Importantly, FAA commercial-service classification does NOT split scheduled from charter/nonscheduled; a separate carrier schedule/operating-mode source is required. Cargo count **149** remains separately evidence-supported. See `data/airports/commercial/group45/group45_faa_2025_passenger_crosswalk.csv` and `data/airports/reconciliation/faa_2025_unmatched_commercial_service_airports.csv`. Sources: https://www.faa.gov/airports/planning_capacity/passenger_allcargo_stats/passenger/arp-cy2025-all-enplanements.pdf, https://davidmegginson.github.io/ourairports-data/airports.csv.

## FAA 2025 unmatched passenger service runway audit — 22 October 2026

The 66 FAA 2025 P/CS LOCIDs initially unmatched to the **U.S. Group 45** crosswalk were rejoined to original OurAirports airport IDs and individual runway records, respecting the *FAA state or territory*: **13 already exist in the worldwide register** (many are filed under AS, GU, MP, PR, VI; Ronald Reagan Washington National KDCA is US-DC although FAA state indicates VA); **33 have no qualifying runway of 1,200m or longer**; **17 have gravel or other unqualified runway surfaces**; **one Alaska source airport has no open runway recorded**; **two were erroneously missing despite qualifying PEM (part concrete, part asphalt) surfaces**.

The two verified additions are **PGWT Tinian International** (source ID `5434`, runway `235364`, 2,621.3m, MP, Group 25) and **TJRV José Aponte de la Torre** (source ID `42321`, runway `254009`, 3,352.8m, PR, Group 43). Their respective Group 25 and 43 technical and commercial files, country counts, and full canonical master were updated; no prior source ID was discarded. Both have affirmative FAA 2025 commercial passenger enplanements (TNI 24,851; RVR 23,214), with **cargo still UNKNOWN**. A runway physically qualifying does not imply unlimited route/civil access; in particular Tinian airport's published PPR conditions still apply to certain flights.

**Current global source total: 8,151 real runway-qualified + one fictional LYAL = 8,152** across 48 technical groups. No Group 49 technical file exists. The **U.S. P/CS matched count remains 450**, because both additions are in other geography groups rather than US; cargo-positive U.S. count remains 149.

Detailed 66-row audit: `faa_2025_unmatched_runway_audit.csv`. The original FAA unmatched LOCID list now carries a disposition for each airport: `faa_2025_unmatched_commercial_service_airports.csv`. FAA PEM legend: https://aeronav.faa.gov/Upload_313-d/supplements/CS_EC_20250807.pdf ; airport-specific Tinian FAA supplement: https://aeronav.faa.gov/Upload_313-d/supplements/CS_PAC_20250807.pdf ; Ceiba TJRV current runway: https://www.airnav.com/airport/NRR .
