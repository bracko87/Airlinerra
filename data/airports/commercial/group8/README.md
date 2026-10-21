# Airlinerra — Group 8 commercial suitability initial screening (2026-10-21)

This file describes the **preliminary passenger/cargo evidence screening of 397 runway-qualified airports** in **Poland (35), Portugal (29), Romania (21), Russia (312, whole country), and San Marino (0)**. The source airport records and 7,846-record master are preserved. Original Russia is one country, without European/Asian splits.

## Evidence totals

```csv
country_iso,country_name,runway_qualified_candidates,passenger_evidenced,cargo_eligible_evidenced,military_review,other_unknown_both,public_airport_service_unverified
PL,Poland,35,15,2,13,20,0
PT,Portugal,29,13,0,6,16,0
RO,Romania,21,17,1,3,4,0
RU,Russia,312,5,0,89,307,0
SM,San Marino,0,0,0,0,0,0
TOTAL,TOTAL,397,50,3,111,347,0
```

**Interpretation:** `YES` means an independently documented commercial passenger service or airport-level cargo service/traffic, not final authorization for a game airline, freighter fleet, international route, or night operation. `UNKNOWN` is **not** a `NO`, and technical paved runway alone is not enough to activate an airport. A military-labelled airport is a civilian-access review, not automatically banned.

### Poland — 35
Poland's ULC 2025 airport-by-airport passenger report identifies 15 airports in this technical group with commercial passenger transport. The ULC reports Warsaw Chopin as Poland's largest air-cargo airport (64.1% of 2025 tonnage); Katowice's operator publishes 46,448 tonnes in 2025 and dedicated freighter services. Other cargo airports remain UNKNOWN in this initial pass, not 0.
- https://ulc.gov.pl/_download/statystyki/2025/q4_en/by_airports_q42025.pdf
- https://caa.gov.pl/aktualnosci/przewozy-w-polskich-portach-lotniczych-w-2025-roku
- https://www.katowice-airport.com/en/our-airport/statistics/annual-statistics

### Portugal — 29
ANA confirms 2025 passenger activity at Lisbon, Porto, Faro, Madeira, Porto Santo, Ponta Delgada, Flores, Horta and Santa Maria; island-airport traffic in Graciosa, São Jorge, Pico and Lajes is independently confirmed by Azores regional statistics. Beja has a civilian airport terminal at an airbase, but its **current airport-specific commercial movements and regular scheduled access remain unknown**. Air-cargo evidence is deliberately UNKNOWN for all Portugal Group 8 airports until individual positive freight and handler data are verified: Portuguese national air-cargo totals cannot be distributed arbitrarily.
- https://www.ana.pt/en/business/airlines/our-airports
- https://srea.azores.gov.pt/2026/01/09/movimento-de-passageiros-aereos-dezembro-2025/
- https://www.anac.pt/VPT/GENERICO/PUBLICACOESINAC/NEWSLETTERSDETRAFEGO/Paginas/NewslettersdeTrafego.aspx

### Romania — 21
Romanian Airports Association 2025 Q1 airport-specific passenger graphic identifies 17 airports with observed passenger movements (including small/seasonal Arad and Tulcea). Bucharest airports' operator corroborates traffic at the two Bucharest airports. Cluj Airport's official 2025 financial/operational report documents **6,630.91 tonnes of freight/mail**, so it has a supported positive cargo marker. This is NOT the assertion that other Romanian airports lack cargo transport or facilities.
- https://airportaar.ro/wp-content/uploads/2025/05/1-David-Ciceo-_Adunare-Gen.-AAR_MAI2025_FINAL.pdf
- https://aeroporturibucuresti.ro/b2b/
- https://www.airportcluj.ro/wp-content/uploads/2026/01/Raport-activitate-AN_2025-.pdf

### Russia — 312, a single whole-country review
Only **five source airports** were assigned positive passenger-service evidence in this first pass from individually grounded materials:
- Sheremetyevo UUEE — airport operator: https://www.svo.aero/ru/press_center/press_releases
- Pulkovo ULLI — 2026 airport passenger publication: https://pulkovoairport.ru/about/press_center/news/65919/
- Domodedovo UUDD — commercial airport 2026 reporting: https://www.reuters.com/business/russia-sells-moscows-nationalised-domodedovo-airport-sheremetyevo-subsidiary-2026-01-29/
- Vnukovo UUWW — official departure/arrival services: https://www.vnukovo.ru/en/
- Ufa UWUU — 2025 airport passenger report and 2026 scheduled service: https://www.airportufa.ru/news/2025/mezhdunarodnyy-aeroport-ufa-podvel-itogi-2025-goda/

The other **307 Russian runway-qualified airports have not yet received individual passenger or cargo permission confirmations**. This is a conservative **research queue**, not a finding that 307 are unsuitable. Rosaviatsiya's September 2026 civil-aerodrome registry and list of airports open to international flights provide important follow-up *airport certification and international eligibility* evidence, but do not alone prove currently scheduled airline service or dedicated cargo facilities:
- https://favt.gov.ru/dejatelnost-ajeroporty-i-ajerodromy-reestr-grajdanskih-ajerodromov-rf/
- https://favt.gov.ru/dejatelnost-ajeroporty-i-ajerodromy-mezhdunarodnye-ajeroporty

**Russia needs finer internal research batches**, e.g. 40–60 airports per pass, without dividing its geographic country code or changing Group 8 ownership. Continue verifying licenses, airline schedules, cargo handler publications and airspace/NOTAM access individually. National 2025 passengers (Rosaviatsiya ~109m) **must never be assigned** to unverified individual airports.

Dynamic airspace restrictions must be handled **at route time**, not by treating temporary suspensions as permanent closures. See `group8_operational_restrictions.csv` for historically reported Pulkovo/Ufa interruptions on 2026-10-16; both currently have evidence of passenger service, and neither row is a permanent closure.

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
