# Airlinerra — Group 4 commercial evidence review (2026-10-21)

**Scope**: 307 runway-qualified source airports in France (151), Georgia (10), Germany (93), Greece (42), and Hungary (11). All airport IDs and source names remain immutable. This is an **initial evidence-backed airport-level review**, NOT final permission to operate or in-game activation.

## Country reconciliation

```csv
country_iso,country_name,runway_qualified_candidates,passenger_evidenced,cargo_eligible_evidenced,military_review,other_unknown_both,public_airport_service_unverified
DE,Germany,93,21,19,18,72,0
FR,France,151,53,32,19,98,0
GE,Georgia,10,3,1,5,7,0
GR,Greece,42,30,1,8,12,0
HU,Hungary,11,2,1,3,9,0
TOTAL,TOTAL,307,109,54,53,198,0
```

Counts overlap: military-review cases generally are in the both-unknown group. YES means evidence of real commercial passenger operations, positive freight/mail, or a supported commercial handling service, not universal legal rights, freighter aircraft capability, active scheduled flights or passenger/cargo *demand*. 2025 national traffic is historical activity, not a claimed 2026 schedule.

## Country evidence provenance

- **France:** DGAC 2025 annual commercial traffic bulletin (May 2026 edition), pp. 19–21 in PDF, airport-by-airport tables. Positive passenger decision requires distinct listed commercial traffic; cargo YES requires a matching positive 2025 *fret et poste* figure. Mail counts are not assumed dedicated freighter flights. Executive passenger movements at Le Bourget are not ordinary scheduled airline service.
  https://www.ecologie.gouv.fr/sites/default/files/documents/Bulletin_Statistiques_transport_aerien_2025.pdf
- **Germany:** Destatis GENESIS 46421-0005, 2025 reporting-airport origin/destination passenger and airfreight loads/unloads; zero freight statistics do not create legal NO and unavailable airports are UNKNOWN rather than inactive.
  https://genesis.destatis.de/datenbank/online/statistic/46421/table/46421-0005
- **Greece:** Fraport Greece 14 operated passenger airports, 2025 passenger report; HCAA 2026 24-government-airport passenger activity list; Athens Airport 2025 passenger and cargo reporting. Do not apply network-level passenger numbers or cargo assumptions to specific airports.
  https://www.fraport-greece.com/en/media-center/news1/2026/fraport-greece--passenger-traffic-growth-continues--supported-by.html
  https://www.ypa.gr/news/ypa-se-nea-ypshla-epipeda-gia-to-eptamhno-toy-2026-h-epibatikh-kinhsh-sta-24-aerodromia
  https://media.aia.gr/assets/aiaportal/media/root/investors/financial%20information/financial%20reports/2025/2025annualfinancialreport_en.pdf
- **Georgia:** airport-specific Tbilisi, Kutaisi and Batumi passenger activity reported in 2026 Q1 based on GCAA figures; Tbilisi's own operator documents named cargo handling companies, customs and warehouses. Separate GCAA regulatory statement raises access-certification issue at Sukhum; do not represent it as a routine playable destination.
  https://georgiatoday.ge/tbilisi-kutaisi-airports-grow-batumi-down-in-q1-passenger-traffic/
  https://tbilisiairport.com/en-EN/business/page/cargo-terminal-business
  https://gcaa.ge/en/statement-of-georgian-civil-aviation-agency-2/
- **Hungary:** Budapest operator 2025 passenger and cargo reporting, Debrecen operator's published 2026 passenger departures and current Hungary eAIP entry for operational context.
  https://www.bud.hu/en/mediacenter/airport-news/budapest-airport-closed-the-75th-anniversary-of-its-opening-with-new-records.html
  https://www.debrecenairport.com/en/departing-flights

## Important restrictions

- Unverified airports remain UNKNOWN, not rejected. Airbases are review categories, not automatically non-commercial.
- Coordinates, runway geometry, source airport IDs, code-conflict queue and LYAL fictional record are preserved. This layer does not relabel or import airports.
- Gate counts, remote stands, slot capacities, curfew/noise exemptions, game daily passenger/cargo demand, annual actual traffic totals and six final airport categories remain outside this initial review. Airlinerra's official six future airport classes are Local, Regional, Medium, Large, Major Hub, Mega Hub.
- **Source limitations:** some DGAC data are 2025; 2026 restrictions and closures can vary. 2025 cargo+mail is not necessarily freighter cargo. A YES in this preliminary review must be revalidated for regulatory permission and timetable freshness before gameplay activation.

## Validation and next actions

`python scripts/validate_commercial_group.py --group 4`

Next: review unresolved 2026 passenger/cargo permissions by original country-specific sub-batch, prioritizing private, military, mixed-use and cargo-only fields. Group 5 is Iceland, Ireland, Italy, Kosovo and Latvia (91 airport candidates). Do not activate/play, change Supabase or production automatically.
