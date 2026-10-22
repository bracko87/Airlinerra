# Airlinerra — B02 South America: consolidated evidence ledger (2026-10-22)

**Latest progress: 94/311 runway-qualified airports have candidate passenger tiers**, up from 58 following 36 new Colombia official regular-flight endpoint proposals; **217 remain without positive source-matched passenger tier evidence**. This is **30.2% provisional coverage, NOT a completed batch**. The nine previously entered secondary Colombia totals still retain a separate measurement definition, while a new official regular-flight proxy is stored independently. All real-airport final category fields remain blank and no flight access or cargo rights are granted. Batch scope: 13 South American country/territory codes outside Argentina and Brazil, 311 eligible real records in the 8,153-airport master.

## Verified work imported

- **Peru (PE):** official Ministry of Foreign Trade and Tourism / DGAC *2025 General Movement of Passengers in Peru Airports*, page **22**, regular commercial air service annual passenger movements (arrivals+departures), reported **in thousands**. **25 airport rows** matched by original OurAirports source ID and airport identifier, yielding **25 provisional categories**. Peru has 42 runway-qualified airport rows, so 17 remain without matched 2025 regular traffic evidence. The official report lists additional smaller airfields that were not confidently mapped to eligible technical master IDs; no invented IDs.
- **Ecuador (EC):** official DGAC 2025 report separately documents **397,798.54 annual cargo tonnes at Quito Mariscal Sucre (SEQM, source ID 308273)** and **26,991.92 tonnes at Guayaquil José Joaquín de Olmedo (SEGU, source ID 6056)**. The country-level 2025 total is 424,790.46 tonnes in that report, exactly the sum of these figures. The two airports are marked **CARGO_ONLY_REVIEW**: no passenger category is assigned from freight evidence; these statistics do not imply there were no passenger flights.
- Other B02 airports retain **UNKNOWN** passenger evidence. Official national sources located for **Bolivia**, **Chile** and **Colombia** are listed in [B02 source index](b02_official_2025_source_index.csv); no guessed individual totals have been imported.

## Source citations, units and limitations

- Peru PDF: https://cdn.www.gob.pe/uploads/document/file/10074446/8207018-informe-anual-movimiento-general-de-pasajeros-en-los-aeropuertos-del-peru-ano-2025.pdf?v=1780349699
- Ecuador DGAC: https://www.aviacioncivil.gob.ec/el-transporte-aereo-ecuatoriano-movilizo-a-8-millones-de-pasajeros-en-el-2025/
- Peru numeric examples: Jorge Chávez Lima **27,219 thousand**, Cusco **4,697 thousand**, Arequipa **2,345 thousand** regular passenger arrival/departure movements. Every imported integer is the published thousands multiplied by 1,000, explicitly an *estimate* because the source is rounded.
- Different source definitions across **Brazil stage-endpoint regular observations**, **Argentina total regular+nonregular observations**, and **Peru regular commercial annual figures** remain labeled separately. Never blend these metrics without a harmonization review.
- Ecuador cargo tonne figures remain `annual_cargo_tonnes_proxy` — **not** `regular_cargo_proxy_kg`. Annual tonnes are not proof of available commercial cargo permissions.
- All technical airport IDs, runway eligibility, six final-tier rules, source conflict queues and fictional **LYAL** stay unchanged. No Supabase, playable operations or final categories are authorized.

## B02 backlog

Finish country-source downloads, per-airport annual statistics and source-ID crosswalks for Chile, Colombia, Bolivia, Ecuador's passenger aviation, and the remaining territories. The whole B02 research batch is **PARTIALLY COMPLETED** only. Do not claim the source index establishes 2025 per-airport movement for unverified sources.


## Chile official 2025 four-quarter domestic evidence (follow-up)

**11/46 Chile runway-qualified airports** now have a source-ID- and ICAO-code-matched **domestic-only lower-bound passenger estimate** for calendar 2025. The data are from Ministry of Public Works/Dirección General de Concesiones quarterly reports, Gráfico 13 (underlying JAC statistics), all quantities in **thousands**. Each rounded quarter was summed, preserving the individual source observations in [the Chile crosswalk](b02_chile_2025_official_domestic_quarterly_totals.csv). These are not the full airport totals, exclude international air traffic, and do not cover Santiago Arturo Merino Benítez/SCEL. The provisional category is a **minimum floor only**, not a final game category; absence of traffic at the other 35 Chile airports remains UNKNOWN.

- Q1: https://concesiones.mop.gob.cl/uploads/sites/4/2025/06/INFORME-TRIMESTRAL-1-2025.pdf
- Q2: https://concesiones.mop.gob.cl/uploads/sites/4/2025/09/INF2_2025VF.pdf
- Q3: https://concesiones.mop.gob.cl/uploads/sites/4/2025/09/2025_3T_vf.pdf
- Q4: https://concesiones.mop.gob.cl/uploads/sites/4/2025/09/2025_4T_publicar.pdf

Bolivia's official December 2025 national traffic report confirms **5,552,973 airline passengers transported** January–December countrywide but does not provide a reconciled 2025 per-airport annual arrivals/departures table, so **zero Bolivian provisional categories were generated**. Official source: https://www.dgac.gob.bo/wp-content/uploads/2026/06/INFORME-DE-ESTADISTICA-DICIEMBRE.pdf


## Consolidated October 22 research addition: 11 airport-specific traffic observations

**47/311** B02 runway-qualified airports now have provisional passenger tiers (**15.1% evidence coverage**), up from 36. These are NOT final game-category assignments, flight access permissions, or an assertion that Batch B02 is complete. Another **264 airports** retain UNKNOWN passenger-tier status. Airport IDs and code crosswalks plus separate measurement metrics and URLs are in [the new evidence file](b02_additional_2025_verified_airport_totals.csv).

| Country | 2025 airport evidence | Passengers | Scope and caveat |
|---|---|---:|---|
| Chile | Santiago SCEL | 26,517,871 | Airport operator annual domestic+international total; preexisting 11 other airport domestic-only floors remain separate |
| Colombia | Cartagena SKCG | 7,756,298 | Airport concession operator annual domestic+international traffic |
| Ecuador | Quito SEQM | approximately 5,400,000 | Rounded Quiport figure, not exact; independent 397,798.54 tonnes cargo retained |
| Ecuador | Guayaquil SEGU | 3,813,013 | Official DGAC 2,217,260 international + 1,595,753 domestic; independent 26,991.92 tonnes cargo retained |
| French Guiana | Cayenne SOCA | 531,457 | Airport consultation report 2025 commercial traffic |
| Guyana | Cheddi Jagan SYCJ | 973,016 | Government airport-specific 2025 figure |
| Paraguay | Silvio Pettirossi SGAS | 1,323,613 | DINAC 1,285,104 regular + 38,509 nonregular; a mixed-service measure |
| Paraguay | Guarani SGES | 3,247 | DINAC domestic regular arrived + departed Jan-May 2025; both endpoint traffic counts are not unique passengers nationally |
| Uruguay | Carrasco SUMU | 2,084,836 | DINACIA 1,041,789 arrivals + 1,043,047 departures, different scope from airport operator's reported 2,144,071 |
| Uruguay | Punta del Este SULS | 119,183 | DINACIA detailed 57,972 arrivals + 61,211 departures; summary table elsewhere in bulletin incorrectly overstates total |
| Uruguay | Salto SUSO | 7,887 | DINACIA airport commercial 2025 movements |

Unmatched airport counts after this import: Bolivia 23; Chile 34; Colombia 75; Ecuador 28; Falklands 1; French Guiana 1; Guyana 3; Paraguay 10; Peru 17; Suriname 1; Uruguay 4; Venezuela 67; South Georgia and the South Sandwich Islands 0 runway matches. No-match means **UNKNOWN**, never proof of no flights, nor an automatic Local category.

Source-specific data definitions must remain independent. Cargo remains independent of passenger tier decisions. The code includes an identity validation for B02 extra source IDs and a regression test for retaining Ecuador annual cargo evidence. Full Python classification and runway validations must pass before B02 could be called technically validated. No Supabase/game deployment is needed or authorized.


## Colombia — 2025 Aerocivil-attributed SECONDARY top-airport comparison

The [PSMV / Corporación Pro Santa Marta Vital comparative table reproduced March–April 2026](https://mundinoticias.com.co/el-aeropuerto-internacional-simon-bolivar-de-santa-marta-se-consolida-como-el-quinto-mas-importante-del-pais-en-movilidad-de-pasajeros/) attributes the 2025 airport totals to Aerocivil. It supplies **nine additional positive B02 airport identities** beyond the already imported Cartagena SKCG airport-operator record. Until the underlying Aerocivil 2025 source dataset is directly acquired and airport-level scope reconciled, these nine values carry the distinct `CO_AEROCIVIL_2025_SECONDARY_ATTRIBUTED_PAX` passenger metric and `PROVISIONAL_B02_SECONDARY_REPORTED_2025` review status. They are **not claimed as directly verified first-party official traffic observations**.

| Airport (ICAO) | Secondary-attributed 2025 passenger number | Draft category only |
|---|---:|---|
| Bogotá El Dorado (SKBO) | 45,470,711 | Major Hub |
| Rionegro José María Córdova (SKRG) | 14,242,539 | Major Hub |
| Cali Alfonso Bonilla Aragón (SKCL) | 6,903,591 | Large |
| Santa Marta Simón Bolívar (SKSM) | 3,787,551 | Large |
| Barranquilla Ernesto Cortissoz (SKBQ) | 3,260,194 | Large |
| Pereira Matecaña (SKPE) | 2,636,158 | Large |
| San Andrés Gustavo Rojas Pinilla (SKSP) | 2,521,155 | Large |
| Bucaramanga Palonegro (SKBG) | 2,039,037 | Large |
| Cúcuta Camilo Daza (SKCC) | 1,570,545 | Large |

**Reconciliation conflicts must remain visible.** The same PSMV table reports Cartagena SKCG **7,659,279** passengers, while its separately sourced airport-operator record in this repository is **7,756,298**. We retain the operator record without overwriting it; different methods/scopes are possible and must be checked at source. The Cali 2025 total above of **6,903,591** is also marginally different from a separate Aerocivil-attributed secondary report citing **6,905,419**. Neither discrepancy is resolved by treating a secondhand publication as an official aviation-authority crosswalk.

New Colombia candidate coverage: **10/76**, including 9 secondary claims. Total B02 passenger candidate coverage: **56/311 (18.0%)**, leaving **255** records without a provisional passenger tier. Continued priority: direct bulk Aerocivil source import, JAC Chile airport-level 2025 totals, Ecuador DGAC airport report, remaining B02 country source mapping, and independent passenger/cargo permission verification. The existing technical runway criteria, exact six provisional tiers, fictional LYAL and final assigned categories are unchanged.

**Chile official bulk discovery:** [JAC monthly traffic documentation](https://jac-mtt.github.io/jac-docs/docs/series/trafico-aereo/) describes the downloadable national traffic series, including separate 2025 domestic/international airports, chargeable/free passengers, freight tons and directional movement fields. [2025 source page](https://www.jac.gob.cl/estadisticas2/informes-estadisticos-mensuales-del-trafico-aereo/) also links airport breakdowns. Use the CSV/xlsx in a future data-ingestion run and match the original airport IDs; do not overwrite the prior 11 domestic-only lower bounds until the full records are independently matched.

**CI:** GitHub's airport validation workflow remains manual-only. A browser attempt was blocked by lack of an authenticated workflow-write GitHub session, so the new commits have **not** been certified by a fresh GitHub Actions run. Perform the full Python CI check before claiming technical completion.


## Guyana and Suriname — official 2025 airport-source reconciliation (follow-up)

Two additional first-party airport-specific passenger **minimum/floor** observations bring B02 to **58/311** provisional airport passenger proposals, leaving **253** airports without a positive source-matched candidate. These sources represent international or published arrivals/departures, not exhaustive all-service airport annual totals and not civilian access approvals.

- **Guyana, Eugene F. Correia / Ogle (SYGO; source airport 41513):** the Government of Guyana [Bureau of Statistics arrivals-and-departures source](https://statisticsguyana.gov.gy/subjects/demography-vital-and-social-statistics/summary-of-arrivals-and-departures-guyana-2015-to-2026/) reports 2025 Q1-Q4 arrivals **8,089, 8,909, 10,199, 9,911** and departures **8,777, 8,731, 9,677, 8,826**. The resulting **73,119** arrival/departure movements support a **Regional minimum candidate**, using `GY_BOS_2025_ARR_DEP_MINIMUM`. Scope of other domestic traffic is unresolved; this is not a complete passenger-audit number.
- **Suriname, Johan Adolf Pengel (SMJP; source airport 6195):** [Airport Management Ltd official 2025 monthly movement bulletin](https://usercontent.one/wp/www.japi-airport.com/wp-content/uploads/2026/01/PBM-Stats-2020-2025.pdf) reports **519,171** *international* passenger movements in calendar 2025, including **392** reported diverted-flight transit passengers. The airport's arrivals and departures totals differ by one from the full printed total with the transit note. Use the published annual total and record the caveat; `SR_AIRPORT_2025_INTL_PASSENGER_FLOOR` supports **Medium minimum candidate**, not a universal annual all-service total.
- **Guyana, Cheddi Jagan (SYCJ; source airport 6356):** the [Guyana Department of Public Information statement](https://dpi.gov.gy/guyanas-aviation-sector-records-unprecedented-growth-between-2020-and-2025/) attributes **14.43 million kilograms of 2025 cargo imports+exports** to the airport. The approximate conversion is **14,430 tonnes**; `GY_CJIA_2025_ROUNDED_CARGO_KG` and `ANNUAL_ROUNDED_CARGO_TONNES_REPORTED` preserve precision and unit. Its independently reported 2025 **973,016 passenger movements** and the original passenger category remain unchanged. This freight count is not cargo handling authorization.

The two passenger rows are appended to [B02 passenger evidence CSV](b02_additional_2025_verified_airport_totals.csv); the cargo original and conversion are in [Guyana 2025 freight CSV](b02_guyana_2025_official_cargo.csv). The code validates source airport IDs, 2025, positive counts, ICAO match, precise rounded kg-to-tonne conversion, and prevents a partial floor being confused with full annual observed traffic. Added unit tests cover classification and preserving independent cargo. Other countries remain partially researched. The existing GitHub workflow must still be manually run by an authenticated GitHub user for full CI certification.

## October 22 — Peru 2025 freight and published runway capacity; B02 validator repairs

**Passenger candidate coverage remains 58/311 (18.6%).** Peru's Jorge Chávez International (OurAirports original source ID **6217**, source code **SPIM**, GPS SPJC) retains its original 2025 regular-passenger estimate and *Major Hub* proposal. A separate [CORPAC report citing ACI-LAC 2025](https://www.gob.pe/institucion/corpac/noticias/1389048-el-aeropuerto-jorge-chavez-figura-entre-los-10-principales-aeropuertos-de-la-region-en-el-que-corpac-se-ocupa-de-la-navegacion-aerea) records **267,156 tonnes of cargo**. This new positive 2025 tonne signal is added to [Peru cargo crosswalk](b02_peru_2025_official_airport_cargo.csv) and the separate annual cargo field, without changing the passenger number or provisional category. B02 airports with structured 2025 annual cargo data increase **3 to 4** (Lima, Quito, Guayaquil, Cheddi Jagan). No cargo permission is inferred.

Peru's [Transport Ministry statement of 23 December 2025](https://www.gob.pe/institucion/mtc/noticias/1319000-mtc-aeropuerto-internacional-jorge-chavez-reanuda-las-operaciones-aereas-en-sus-dos-pistas-de-aterrizaje) gives **52 runway movements per hour** across two runways (27 takeoffs + 25 landings per hour), up from 35 previously. The number is preserved in [published capacity evidence](../../operations/b02_2025_published_capacity_evidence.csv) as source-specific observed infrastructure-capacity **evidence**, not an approved Airlinerra time-slot allowance.

The [B02 measurement discrepancy queue](b02_2025_metric_reconciliation_queue.csv) lists **three unresolved source-scope conflicts**: Lima's DGAC/regular-passenger proxy versus ACI-LAC airport passenger headline; Ecuador national 2025 DGAC cargo 424,790.46 versus 434,368 tonnes in its later fiscal-accountability statement; and Guayaquil national DGAC 26,991.92 tonnes versus coastal DGAC 31,957.59 tonnes implied by separate national/international figures. **Do not merge or overwrite any of these sources** without reconciling reporting scope and definitions.

The classification generator now accepts the already-committed Suriname `SR` airport observation and correctly validates decimal Ecuador cargo `annual_cargo_tonnes`. Both previously blocked deterministic reconstruction. Tests were added for these regressions and independent Peru cargo evidence. The future Supabase handoff now exports published capacity evidence as a separate file, with `game_slot_capacity_approved=false` on every such record.


## 2026-10-22 consolidated Colombia Aerocivil direct-data pass — 46 airports, 36 new tiers

The [Aerocivil official commercial origin-destination open-data table](https://www.datos.gov.co/Transporte/Transporte-A-reo-Comercial-Tr-fico-Origen-Destino-/gb6w-ynu4) is published by Aerocivil and contains year/month, flight type, IATA source/destination, `pasajeros` and `carga_correo_kg`. Its **2025 `tipo_vuelo='R'` (regular flights)** records are aggregated separately by `origen` and `destino` using the public Socrata SoQL API. For each matched runway-qualified **Colombian** airport, the endpoint proxy is **regular departing passengers + regular arriving passengers** and **regular outgoing cargo-plus-mail kilograms + regular incoming cargo-plus-mail kilograms**. These are source-defined *airport endpoint* observations; one domestic traveler may appear at both endpoints and totals **must not be added across airports as distinct national passengers**. The source excludes nonregular/charter flights and is NOT a reconciled all-service total.

Source filters and aggregation (same request independently with `origen` and `destino`):

```text
GET https://www.datos.gov.co/resource/gb6w-ynu4.json
?$select=origen,sum(pasajeros) as pax,sum(carga_correo_kg) as cargo_kg,count(distinct n_mero_de_mes) as months
&$where=a_o=2025 and tipo_vuelo='R'
&$group=origen
&$limit=1500
```

The two queries produced 594 departure and 610 arrival distinct IATA endpoint codes (each below the 1,500-row query cap); after [ICAO/IATA mapping from the public Colombia airport-code list](https://en.wikipedia.org/wiki/List_of_airports_in_Colombia) and **exact source-ID / country / ICAO verification** against the 8,153-row master, **46 of Colombia's 76 runway-qualified airports** have positive Aerocivil regular passenger evidence. Of those, **36 previously had no provisional tier** and now receive `PROVISIONAL_B02_AEROCIVIL_REGULAR_ENDPOINT`; the ten previously categorized airports preserve their original tier and original reported 2025 operator/secondary full or rounded total, while the additional regular endpoint number is independently populated in `regular_passenger_proxy`.

There are **43** positive 2025 *regular cargo-plus-mail* endpoint kg observations stored in `regular_cargo_proxy_kg` and `REGULAR_CARGO_MAIL_OBSERVED_OFFICIAL_2025`. This must **not** be interpreted as freight-only tons, airport cargo capacity, separate cargo rights or in-game capacity. Three crosswalked airports have zero positive regular cargo+mail kg in this particular published metric; no absence of other cargo service is inferred.

Original ICAO/IATA matched 64 of the 76 Colombian master airports; the other 12 remain an identifier-evidence queue, not a traffic=0 conclusion. Within these 64, only the 46 with positive source-matched regular passenger counts generate tier proposals. **Thirty Colombian airports have no provisional passenger tier**, and 217 B02 airports remain without a provisional tier worldwide.

[Country official 2025 crosswalk](b02_colombia_2025_aerocivil_regular_airport_endpoints.csv) preserves original Airlinerra source IDs, IATA and ICAO codes, year, source URLs, source-defined measure, departures/arrivals and their sums, cargo+mail kg and monthly coverage. **Important:** for the already-tiered ten Colombian airports, Aerocivil *regular-only* passengers are lower than certain published airport operator/secondary full-service totals. These are different metrics and must NOT be silently reconciled or overwritten. Bogotá SKBO is one example: 38,594,428 regular endpoint observations versus the prior 45,470,711 secondary-attributed all-service figure, pending authority/measure reconciliation.

B02 source coverage is now **94/311 (30.2%)**. No final category was assigned to a real airport, no original runway-qualified airport was removed, and neither cargo evidence nor provisional airport tiers activate route permissions. The complete Python/GitHub Actions validation suite must still run on the new commit.
