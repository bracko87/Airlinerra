# Airlinerra — Phase A: Six-tier airport classification review (proposal v1)

## Scope and guardrails

The current working technical master contains **8,153** airports, including **8,152 real** airports and the owner-defined fictional **LYAL**. This Phase A output is a **separate, non-operational REVIEW**. It does **not** populate the real-airport `assigned_category` field, authorize passenger or cargo routes, infer civilian access, update Supabase, or deploy the game.

Categories (exact names, 1–6): **Local, Regional, Medium, Large, Major Hub, Mega Hub**. The screened runway minimum (1,200 m paved) establishes only *minimum technical Level 1*, **not** the final six-tier category.

## Proposed *provisional* passenger-volume tiers (not yet approved game policy)

| Candidate tier | Positive annual passenger metric, subject to source-specific definitions |
|---|---:|
| Local | 1–9,999 |
| Regional | 10,000–99,999 |
| Medium | 100,000–999,999 |
| Large | 1,000,000–9,999,999 |
| Major Hub | 10,000,000–49,999,999 |
| Mega Hub | 50,000,000+ |

These are **draft game-design thresholds**, not an official ICAO/ACI airport classification. The Brazil source is ANAC's 2025 air-transport flight-stage open data, as reconciled by source airport ID in `commercial/group46/group46_brazil_anac_2025_official_crosswalk.csv`. Endpoint-associated passengers are **not independent audited airport totals**; values are historical, may require identity reconciliation, and do not establish 2026 scheduled-flight rights. For Brazil, only **positive regular passenger observations** generate a provisional tier; Argentina's official **mixed regular/nonregular annual totals** are a separate provisional evidence class. Nonregular/charter-only activity, freight-only activity and missing matches do **not** create an automatic tier. The reported cargo kilograms remain a **separate signal**; a future combined passenger/cargo rule and operational access assessment is still needed.

## Review statuses

- `OWNER_ASSIGNED`: protected fictional airport LYAL, final **Local**.
- `PROVISIONAL_REGULAR_TRAFFIC`: Brazil 2025 ANAC regular passengers >0; a draft candidate tier, **not final**.
- `PROVISIONAL_OFFICIAL_ANNUAL_TOTAL`: Argentina 2025 official named-airport annual passenger total (rounded thousands); a draft candidate tier, **not final**.
- `NONREGULAR_ONLY_REVIEW`: 2025 nonregular passenger proxy only; no auto category.
- `CARGO_ONLY_REVIEW`: positive freight proxy but no positive passenger proxy; no auto category.
- `NEEDS_EVIDENCE`: source absent or insufficient; **UNKNOWN is not NO**, and cannot automatically mean Local.
- `EXISTING_FINAL_ASSIGNMENT`: preserves any future separately approved assignment without rewriting it.

The initial worldwide review uses separately labeled Brazil **regular-passenger stage-endpoint proxies** and Argentina **rounded annual airport passenger totals**. These two metrics are not equivalent and must not be merged or compared as if they were independently audited counts. Historical ANAC crosswalk has 577 airport IDs; Coroa do Avião/SIFC source ID **335361** is excluded by its separate official runway-exclusion record, leaving **576** eligible Brazil airports. The Iran OIBH source-code conflict remains a separate review item.

## Refresh / validation

Run `python scripts/build_airport_classification_review.py` after verified source changes. Run `python scripts/build_airport_classification_review.py --check` to confirm the committed review is reproducible. Unit tests: `python -m unittest discover -s tests -p test_airport_classification.py`.

The next dataset milestones are airport-specific passenger and freight sources for **additional countries**, verification of civilian access, identifier conflicts, consistent cargo thresholds and human review before promoting *any* real airport to a final tier. Supabase is unnecessary for this data-preparation phase.


## Argentina ANAC official annual airport passengers (2025)

The official [ANAC December 2025 report](https://docs.anac.gob.ar/index.php/s/pk8HDnYWX5X3aKL/download/Informe%20Mensual%20Diciembre%202025.pdf) (section **Pasajeros Totales por Aeropuerto**) lists 38 individually named airports and an aggregate **Otros**. The original quantities are in **thousands**, rounded; positive totals cover embarked/disembarked passengers from both regular and nonregular commercial flights, while the three most recent months were provisionally reported in the December 31, 2025 snapshot. Do not distribute **Otros** to unnamed airports. These totals use `ANAC_TOTAL_PAX_ROUNDED_1000` and produce **provisional** `PROVISIONAL_OFFICIAL_ANNUAL_TOTAL` tiers, not final categories or 2026 permissions. This inclusive Argentina passenger measure must NOT be treated as interchangeable with Brazil's **regular-only stage-endpoint** proxy. The original source-ID mapping is `commercial/group46/group46_argentina_anac_2025_official_passenger_totals.csv`.

The SABE Aeroparque runway recovery increases the worldwide technical master from 8,152 to **8,153** including fictional LYAL, with Argentina **121** and Brazil **576**. Airports absent from positive named-source coverage remain **UNKNOWN, not NO**.
\n\n## B02 South America evidence (2026-10-22)\n\nPeru official **regular** arrivals+departures annual 2025 values are reported in **thousands** and stored as approximate values in the review's `regular_passenger_proxy`, tagged `PERU_DGAC_REGULAR_PAX_ROUNDED_1000`. Ecuador Quito/Guayaquil official **annual total cargo tonnes** use a distinct `annual_cargo_tonnes_proxy` signal and cannot generate passenger tiers. The B02 source-specific supporting files and validation are described in [B02 report](../commercial/batchB02/B02_RESEARCH_REPORT.md). These figures do not authorize gameplay, and no real airport's final category is assigned.\n

## Chile 2025 MOP/JAC quarterly domestic-only passenger lower bounds

The Chile MOP / Dirección General de Concesiones quarterly 2025 **Gráfico 13** plots *national/domestic passenger traffic* in **thousands** at 11 regional concessioned airports. The official source is JAC. Four independently rounded quarters are summed to estimate domestic traffic for 2025. The observation **excludes international traffic and excludes Santiago SCEL entirely**. Do not treat this as complete airport annual traffic or regular-only passenger observations. The distinct `domestic_passenger_floor_proxy` and `PROVISIONAL_DOMESTIC_FLOOR` status indicate a conservative **minimum category proposal** using the original six thresholds, subject to upgrade after reviewing international traffic. Source links are in [Chile 2025 quarterly crosswalk](../commercial/batchB02/b02_chile_2025_official_domestic_quarterly_totals.csv). No final tier or player operating permissions were changed.


## Secondary-source Colombia evidence status (2026-10-22)

Nine 2025 Colombian main-airport passenger counts are provisionally tiered from a public PSMV table attributing its comparison figures to Aerocivil. Their specific `CO_AEROCIVIL_2025_SECONDARY_ATTRIBUTED_PAX` metric has `PROVISIONAL_B02_SECONDARY_REPORTED_2025` status, not `PROVISIONAL_B02_2025_AIRPORT_TRAFFIC`, to prevent secondhand reports being treated as directly source-reconciled official observations. First-party underlying Aerocivil dataset and conflicting Cartagena/Cali totals still require auditing. Missing 2025 official observations remain UNKNOWN; **none of these tiers is a final user-authorized category or route permission**. See [B02 report](../commercial/batchB02/B02_RESEARCH_REPORT.md).
