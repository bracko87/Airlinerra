# Worldwide initial airport reconciliation — 22 October 2026

## Verified register accounting

Source-group file row counts on `main`, Groups 1–48: **7,845 real airport candidates**, with no Group 49 runway file. The canonical master `data/airports/airport_register.csv` contains **7,846** rows: these 7,845 source airports plus **one explicitly fictional LYAL record**. See `group_technical_counts.csv`.

The previously announced **30-airport shortfall (7,816/7,846)** was an erroneous running subtotal. It is **not** a backlog of thirty missing airports, and there is no basis to create a fictional Group 49 to make up that difference.

**Technical roster coverage ≠ completeness of worldwide qualifying airports.** An omitted qualifying airport has been found in Uruguay.

## Verified omission: SUMU (Uruguay)

Carrasco General Cesáreo L. Berisso International Airport (SUMU/MVD) has two active runways reported in OurAirports as surface **PEM**, which the source-runway material filter does not automatically treat as asphalt/concrete. Both runway lengths exceed 1,200 m (3,200 m and 2,250 m). Uruguay **DINACIA's July 2026 AIP, SUMU AD 2**, identifies the 3,200 m runway as **concreto asfáltico** (asphalt concrete). It passes Airlinerrra's documented surface and length rules. Source: https://www.dinacia.gub.uy/sites/default/files/aip/2026-07/Ad2-9%20esp.pdf ; original surface: https://ourairports.com/airports/SUMU/runways.html .

The airport operator reports **2,144,071 passengers in 2025**: https://aeropuertodecarrasco.com.uy/en/historic-passenger-record-at-carrasco-airport/ . Uruguay INE independently records **36,825 tonnes of scheduled-flight cargo in 2024**: https://www.gub.uy/instituto-nacional-estadistica/comunicacion/publicaciones/anuario-estadistico-nacional-2025-vol-102/47-transporte-15 .

**Source ID protection:** The precise OurAirports numeric airport ID and runway record IDs have not been retrieved from the original source snapshot; DO NOT infer them from adjacent airport IDs, create duplicate IDs, or silently edit the source register. The official surface is verified but the data import is **pending source-ID resolution**, in `verified_runway_omissions.csv`. Once resolved, add a specific surface override and rerun the normal full rebuild and validations. New global total should then increase by one, assuming no other changes.

## Commercial evidence: major limitations

Groups 45–48 include numerous classifications marked YES after code/name shortlist selection, **without individual airport-level traffic-source joins**. These entries are **provisional candidates**, not verified commercial permissions. In particular, the Group 45 US 172 passenger and 3 cargo counts, and Group 46 Brazil 50 passenger and 7 cargo counts, are *not* final national counts and should not restrict game routes or freight. See `commercial_verification_backlog.csv`.

FAA authoritative 2025 all-airport passenger and all-cargo sheets: https://www.faa.gov/airports/planning_capacity/passenger_allcargo_stats/passenger?year=all . ANAC Brazil movement data is categorized by commercial passenger versus cargo operations and by charter / general aviation classes: https://www.gov.br/anac/pt-br/acesso-a-informacao/dados-abertos/areas-de-atuacao/operador-aeroportuario/dados-de-movimentacao-aeroportuaria/metadados-operador-aeroportuario-dados-de-movimentacao-aeroportuaria .

### Release gate

1. Join source datasets to technical airport IDs, verifying exact code aliases (not name guessing).
2. Separate **scheduled passenger**, **charter passenger**, **commercial cargo**, **general aviation**, and **military access**; keep missing evidence as UNKNOWN.
3. Retain the original source technical candidates and LYAL, and Airlinerra's exact six eventual airport categories.
4. Apply validated group-level CSV corrections with an evidence URL per positive and update derived counts.
5. Execute `python scripts/validate_airports.py && python scripts/validate_historical_airports.py && python scripts/rebuild_runway_register.py` on a complete checkout before accepting a technical register edit.

No Supabase changes or playable-airport activation are authorized by this audit.
