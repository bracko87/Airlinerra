# Airlinerra — Argentina official 2025 airport passenger reconciliation

## Scope (2026-10-22)

- Source: Argentina Administración Nacional de Aviación Civil (ANAC), *Informe Mensual, Diciembre 2025*, section **Pasajeros Totales por Aeropuerto**.
- Official report: https://docs.anac.gob.ar/index.php/s/pk8HDnYWX5X3aKL/download/Informe%20Mensual%20Diciembre%202025.pdf
- Report metric: 2025 **regular + nonregular commercial passengers embarked and disembarked** per airport; values shown in thousands (`Pax TOTALES [000]`), *rounded*, not exact to the individual passenger.
- Curated code-to-original-OurAirports-source-ID crosswalk: [group46 Argentina annual totals](../commercial/group46/group46_argentina_anac_2025_official_passenger_totals.csv).
- Separate six-category *proposals*, not gameplay assignments: [worldwide classification review](../classification/airport_classification_review.csv).

## Verified import summary

| Check | Result |
|---|---:|
| Runway-screened worldwide master | 8,153 |
| Runway-screened Argentine airports | 121 |
| Official ANAC 2025 named-airport records imported | 38 |
| Exact source ID + airport code crosswalk matches | 38 of 38 |
| Argentina airports with a provisional traffic tier | 38 |
| Argentina airports remaining `NEEDS_EVIDENCE` | 83 |
| Remaining real-airport final category assignments | Not yet approved |

The crosswalk covers approximately **50.587 million** reported airport passenger movements across its 38 named airports. The ANAC report total is **50.611 million**, with its additional aggregated "Otros" row, as well as rounding. Do **not** distribute the residual to individual airports or infer zero traffic at the other 83 runway-screened Argentine airports.

### Argentina provisional categories (draft thresholds)

| Proposed category | Airports |
|---|---:|
| Local | 0 |
| Regional | 11 |
| Medium | 18 |
| Large | 7 |
| Major Hub | 2 |
| Mega Hub | 0 |
| **Total provisional** | **38** |

Aeroparque Jorge Newbery **SABE** is included after separate official runway recovery: original OurAirports airport source ID **5771**, runway ID **233011**, official runway **2,350 m concrete**. This airport was absent in the earlier 8,152-airport technical checkpoint but has been restored to the current 8,153-airport master. Historical green validation #60 refers to the earlier technical snapshot; it does **not** certify the subsequent 8,153-airport master or classification changes.

Rio Cuarto airport is joined to OurAirports source ID **5796**, code **SAOC** ("Area De Material Airport"); Argentina's official aeronautical publications explicitly name **Río Cuarto / Área de Material (SAOC)**, confirming the identity: https://ais.anac.gob.ar/descarga/sup-690a1df614cff

## Safeguards

The classification generator now validates that Argentina source IDs exist in the technical master, that official ICAO/ident codes agree with the source airport row, and that `reported_2025_thousands` is consistently converted to the estimated total-passenger scale. Unit tests include wrong-code, wrong-magnitude and unsupported-metric cases.

**Important:** Argentine rounded *total* passenger observations cannot be represented as confirmed **regular-flight-only** passenger totals. Brazil 2025 observations are separately tagged regular flight-stage proxies; do not mix them as equivalent audited measures. Every non-evidenced airport stays UNKNOWN, not NO. Commercial operating rights, military/civilian access, cargo classification and final six-category assignments remain unapproved. No Supabase import or production deployment.

## Next source batch

Collect a comparable official annual passenger dataset for the next country (e.g. Chile), retain original airport/source IDs and code mapping, and produce provisional traffic tiers only for identified matched airports. A successful new-run GitHub validation will eventually be needed for the changed technical master; do not falsely claim the earlier green checkpoint validates current changes.
