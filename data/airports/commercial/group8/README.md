# Airlinerra — Group 8 commercial suitability initial screening (2026-10-21)

This file describes the **preliminary passenger/cargo evidence screening of 397 runway-qualified airports** in **Poland (35), Portugal (29), Romania (21), Russia (312, whole country), and San Marino (0)**. The source airport records and 7,846-record master are preserved. Original Russia is one country, without European/Asian splits.

## Evidence totals

```csv
country_iso,country_name,runway_qualified_candidates,passenger_evidenced,cargo_eligible_evidenced,military_review,other_unknown_both,public_airport_service_unverified
PL,Poland,35,15,2,13,20,0
PT,Portugal,29,13,7,6,15,0
RO,Romania,21,17,3,3,4,0
RU,Russia,312,84,16,89,228,0
SM,San Marino,0,0,0,0,0,0
TOTAL,TOTAL,397,129,28,111,267,0
```

**Interpretation:** `YES` means documented historic airport passenger traffic, a published future/ongoing subsidized passenger-route plan, or airport-level cargo service/traffic (identified separately in the Russia evidence-types CSV), not final authorization for a game airline, freighter fleet, international route, or night operation. `UNKNOWN` is **not** a `NO`, and technical paved runway alone is not enough to activate an airport. A military-labelled airport is a civilian-access review, not automatically banned.

### Poland — 35
Poland's ULC 2025 airport-by-airport passenger report identifies 15 airports in this technical group with commercial passenger transport. The ULC reports Warsaw Chopin as Poland's largest air-cargo airport (64.1% of 2025 tonnage); Katowice's operator publishes 46,448 tonnes in 2025 and dedicated freighter services. Other cargo airports remain UNKNOWN in this initial pass, not 0.
- https://ulc.gov.pl/_download/statystyki/2025/q4_en/by_airports_q42025.pdf
- https://caa.gov.pl/aktualnosci/przewozy-w-polskich-portach-lotniczych-w-2025-roku
- https://www.katowice-airport.com/en/our-airport/statistics/annual-statistics

### Portugal — 29 (cargo recheck)

Portugal **now has 7 airports with cargo evidence**, compared with 0 before this targeted audit. ANA's own **2024** audited management report documents freight at Lisbon (191,892 tonnes), Porto (38,120 t), Faro (approximately 37 t) and the Beja civil terminal (approximately 2 t). Madeira's official airport operator lists dedicated cargo terminals and handlers; **do not misassign the aggregated Madeira Islands cargo volume to Madeira Airport alone**. Separately, airport-specific 2025 cargo/mail values for Ponta Delgada (7,449 t) and Horta (881 t) are presented by an independent site citing Eurostat, and should be verified against Eurostat original tables when those are imported.
- https://www.ana.pt/sites/default/files/2025-05/ANA_RGC_2024_PT_Website.pdf
- https://www.ana.pt/en/content-topic/airlines-0
- https://aeroplano.de/flughafen-ponta-delgada/
- https://aeroplano.de/flughafen-horta/

These represent documented **past freight or available cargo handling**, not promises of frequent freighter operations, commercial cargo permissions for every aircraft, or daily/monthly cargo demand. Portugal still has 13 passenger-evidenced airports. Beja's very small 2024 cargo figure does not imply a scheduled passenger market.

### Romania — 21 (cargo recheck)

Romania now has **3** airports with documented cargo handling, up from 1: Cluj, Bucharest Henri Coandă and Timișoara. Bucharest's airport operator reports **43,947 tonnes** in 2025. Romania's national statistics show roughly **6,500 tonnes** at Timișoara, in addition to Cluj's 2025 reported freight/mail. All other airports remain `UNKNOWN` for cargo unless independently verified.
- https://bucharestairports.ro/old/files/pages_files/BHCIA_WEBSITE_2024_-_2025.pdf
- https://agerpres.ro/economic/2026/03/15/ins-transportul-aerian-de-marfuri-a-crescut-cu-10-5-in-2025--1537357
- https://www.airportcluj.ro/wp-content/uploads/2026/01/Raport-activitate-AN_2025-.pdf

### Russia — 312, complete country (third-pass update)

Russia now has **84 passenger-evidenced airports** and **16 cargo-evidenced airports**, increased from 74 and 11 on the previous pass (and the originally underresearched 5 and 0).

The airport-specific evidence sidecar distinguishes:
- `PUBLISHED_SUBSIDIZED_PASSENGER_ROUTE_2026`: 37 airports
- `NOT_INDIVIDUALLY_VERIFIED`: 228 airports
- `RECORDED_PASSENGERS_2025`: 42 airports
- `RECORDED_PASSENGERS_2024`: 1 airports
- `PUBLISHED_PASSENGER_SCHEDULE_2025`: 1 airports
- `RECORDED_PASSENGERS_2026`: 2 airports
- `OPERATOR_DOCUMENTED_SERVICE_2026`: 1 airports

The previous 2025 industry ranking, 2026 Rosaviatsiya regional subsidized-route lists, and airport-specific sources are not interchangeable: **a planned airline route is not actual flown passenger traffic**. The latest targeted pass upgraded Bugulma from route-plan evidence to **observed 2025 passenger traffic**, and added the previously missing airport records for Norilsk Alykel, Begishevo, Gelendzhik, Krasnodar Pashkovsky, Elista, Tobolsk Remezov, Arkhangelsk Talagi, Nizhny Novgorod Strigino, Magnitogorsk and Cherepovets. Cherepovets' evidence is a **2025 schedule** and its subsequent temporary suspension notice requires a 2026 access recheck, not automatic activation.

New positive Russian cargo evidence was found at **Begishevo, Elista, Nizhny Novgorod Strigino, Magnitogorsk and Tobolsk Remezov**. A documented cargo warehouse or positive freight/mail volumes is not proof of unrestricted dedicated freighter service.

Key airport-specific sources:
- https://news.sgnorilsk.ru/2025/09/26/direktor-aeroporta-alykel-prokommentiroval-rekonstrukcziyu-vozdushnoj-gavani/
- https://www.rzd-partner.ru/aviation/news/passazhiropotok-v-aeroportakh-tatarstana-v-2025-godu-prevysil-6-millionov-chelovek/
- https://gelaero.ru/news/aeroport-gelendzhik-obsluzhil-300-000-passazhirov-s-nachala-2026-goda/
- https://www.interfax.ru/russia/1102504
- https://www.interfax-russia.ru/index.php/south-and-north-caucasus/news/passazhiropotok-aeroporta-elisty-za-9-mesyacev-snizilsya-na-19-na-fone-priostanovki-raboty-iz-za-kapremonta
- https://ar-rmz.ru/about/news/aeroport-remezov-otmechaet-5-letie/
- https://disclosure.1prime.ru/Portal/GetDocument.aspx?docId=4ac962b962ae41089795b5a98d7db133&emId=2901015817
- https://nta-pfo.ru/news/society/2026/news_731652/
- https://www.aviaport.ru/news/passazhiropotok-aeroporta-magnitogorska-v-2025g-prevysil-278-tys-chelovek-ostalsya-na-urovne-2024/
- https://severstal-avia.ru/news/the-schedule-of-regular-flights-for-the-2025-summer-season/
- https://www.nbc.aero/partners/trucking/
- https://ar-rmz.ru/

**228 of the 312 Russian airports** still have neither passenger nor cargo confirmation. That is an unverified research remainder, **not an estimate that those airports are not commercially viable**. 89 are flagged as military access reviews, overlapping these columns. Russia must always remain a **single complete country**. Future work: verify Rosaviatsiya civil certificates / airport-specific flight schedules and cargo facilities, including any current airspace/NOTAM restrictions, in batches of 40–60 airports. Airport code/geographic matching must be exact; country-level passenger totals are not assigned to individual unknown airports.

### San Marino — 0
Zero runway-qualified candidates in original San Marino source geography; do not add nonqualifying airports to fill the count.

## Game data rules
- Technical airport list, original names, codes, exact qualifying pavement fields and fictional LYAL remain unchanged.
- No gameplay airport has been activated, categorized, or imported into Supabase.
- Passenger/commercial evidence is independent from cargo evidence; historic charters, specialized military/civil dual-use and tiny freight/mail volumes cannot infer unrestricted scheduled flights.
- Curfew windows, noise rules, gate counts, remote stands, live slots, aircraft mass/weight restrictions and game-created daily/weekly/monthly/annual passenger/cargo demand remain UNKNOWN unless independently evidenced.
- Existing official Airlinerra classification has **six** possible tiers: Local, Regional, Medium, Large, Major Hub, Mega Hub. No final tier is assigned here.

## Validation and next
`python scripts/validate_commercial_group.py --group 8`

Next **Group 9** will include Serbia (including separate fictional LYAL sidecar), Slovakia, Slovenia, Spain and Sweden. Also continue Russian Group 8 sub-batches and unresolved review cases as a distinct verification pass, rather than prematurely considering all 397 commercially cleared.
