# Airlinerra — Group 5 commercial review (2026-10-21)

Scope: **91** original runway-qualified airports. Iceland 8, Ireland 7, Italy 70, Kosovo (source region XK) 2, Latvia 4. No original source IDs or master records were dropped. The 7,846-record technical runway register, original coordinates and fictional LYAL remain unchanged.

## Initial review totals
| Country | Candidate airports | Passenger evidence | Cargo evidence | Military review | Both permissions unknown |
|---|---:|---:|---:|---:|---:|
| Iceland | 8 | 6 | 1 | 0 | 2 |
| Ireland | 7 | 5 | 4 | 1 | 2 |
| Italy | 70 | 39 | 31 | 17 | 30 |
| Kosovo | 2 | 1 | 0 | 1 | 1 |
| Latvia | 4 | 1 | 1 | 1 | 3 |
| **TOTAL** | **91** | **52** | **37** | **20** | **38** |

Statuses overlap; military cases commonly also have both permissions UNKNOWN. Unconfirmed does not mean prohibited or inactive. Original runway acceptance alone does not establish civilian commercial access.

## Evidence used

- **Iceland:** Isavia 2025 passenger network report, Reykjavik domestic network and Hornafjordur airport schedules. Cargo is marked YES only for Keflavik, where the operator explicitly lists cargo airlines and facilities.
  https://www.kefairport.com/corporate/isavia-group
  https://www.innanlandsflugvellir.is/en/reykjavik-airport/flight-information/destinations
  https://www.innanlandsflugvellir.is/en/hornafjordur-airport
  https://www.kefairport.com/corporate/cargo-info
- **Ireland:** Central Statistics Office commercial passenger and freight/mail statistics by airport, calendar 2025. Passenger YES at Dublin, Cork, Shannon, Kerry and Knock. Freight YES at Dublin, Cork, Shannon and Knock; Kerry's lack of recorded freight does **not** establish cargo prohibition.
  https://www.cso.ie/en/releasesandpublications/ep/p-as/aviationstatisticsquarter4andyear2025/
- **Italy:** Assaeroporti calendar 2025 per-airport `Totale Commerciale` passenger field and `Cargo (Tons)`. 41 matching commercial airport statistical entries were checked against the Group 5 airport-code roster. **Taranto-Grottaglie** recorded 3,463 t cargo but only two commercial passengers; its regular passenger suitability remains UNKNOWN. **Brescia** has substantial freight but small historical commercial passenger traffic. Military/civil Grosseto remains separate military-access review. Very small reported 0.1 t cargo (Treviso) or 1 t (Pescara) do not establish dedicated cargo operations or terminal/freighter compatibility.
  https://assaeroporti.com/statistiche/?month=12&selectedYear=2025
  https://www.enac.gov.it/pubblicazioni/dati-di-traffico-2025/
- **Kosovo (source geography XK):** Kosovo aviation authority's Pristina airport 2025 passenger figures. Gjakove Air Base retained in military access review; no cargo claim is made.
  https://caa.rks-gov.net/prishtina-international-airport-adem-jashari-records-over-4-6-million-passengers-in-2025-a-13-increase-compared-to-2024/
- **Latvia:** Riga airport operator's audited 2025 passenger and freight reporting; **Liepaja** operator currently says no regular flights, which is not a ban on commercial/charter operations and is recorded as UNKNOWN, rather than NO. Lielvarde military facility remains review pending.
  https://www.riga-airport.com/en/news/riga-airport-closes-2025-profit-eur-42-million
  https://liepaja-airport.lv/en/services/services/scheduled-flights/

## Schema interpretation

`passenger_commercial_permission=YES` is a historical passenger-service evidence flag in this **preliminary** dataset, not a legal certificate for game airlines to operate all routes. `cargo_commercial_permission=YES` is similarly specific evidence of positive handled freight or an airport's named cargo services; this is NOT a guarantee of suitable freighter stands, customs processing, or cargo growth. Military access is not a blanket NO. No passenger demand per day/week/month/year, actual traffic time series, curfews, gates or slots have been created from this evidence.

## Validation and follow-up

Use `python scripts/validate_commercial_group.py --group 5` to validate immutable original IDs, per-country reconciliation, evidence URLs and allowed classifications. Continue **Group 6: Liechtenstein, Lithuania, Luxembourg, Malta and Moldova**, 11 airports by historical runway-screen criteria.
