# Airlinerra — Group 8 commercial suitability initial screening (2026-10-21)

This file describes the **preliminary passenger/cargo evidence screening of 397 runway-qualified airports** in **Poland (35), Portugal (29), Romania (21), Russia (312, whole country), and San Marino (0)**. The source airport records and 7,846-record master are preserved. Original Russia is one country, without European/Asian splits.

## Evidence totals

```csv
country_iso,country_name,runway_qualified_candidates,passenger_evidenced,cargo_eligible_evidenced,military_review,other_unknown_both,public_airport_service_unverified
PL,Poland,35,15,2,13,20,0
PT,Portugal,29,13,0,6,16,0
RO,Romania,21,17,1,3,4,0
RU,Russia,312,74,11,89,238,0
SM,San Marino,0,0,0,0,0,0
TOTAL,TOTAL,397,119,14,111,278,0
```

**Interpretation:** `YES` means documented historic airport passenger traffic, a published future/ongoing subsidized passenger-route plan, or airport-level cargo service/traffic (identified separately in the Russia evidence-types CSV), not final authorization for a game airline, freighter fleet, international route, or night operation. `UNKNOWN` is **not** a `NO`, and technical paved runway alone is not enough to activate an airport. A military-labelled airport is a civilian-access review, not automatically banned.

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

### Russia — 312, a single whole-country review (corrected 2026-10-21)

**Correction:** The original first-pass Group 8 review incorrectly reported passenger evidence for **only 5 airports** and **0 cargo airports**. Those were research-coverage counts, NOT an accurate estimate of the Russian commercial aviation network. A second, airport-specific review now records:

- **36** airports with positive actual **2025** passenger activity identified by individually matched airport name/code in an industry-compiled airport table. Historical observation is not a live 2026 flight schedule: https://www.avia-adv.ru/stat/airports-ru-2025.htm
- **38 additional** airports appearing as an airport/city endpoint on Rosaviatsiya's **2026 subsidized passenger-route plan**. These routes have named carriers and published validity windows, but the route list alone does **not prove all flights were actually operated**, and it does not prove unrestricted commercial permissions: https://special.favt.gov.ru/dejatelnost-vozdushnye-perevozki-subsidirovanie-regiony/ and https://favt.gov.ru/dejatelnost-vozdushnye-perevozki-subsidirovanie-1172/
- **74 unique passenger-evidenced airport records** in total. In addition, **11 airport records** have independently documented cargo terminals/handling providers; cargo processing capability is not evidence of dedicated scheduled freighter traffic or cargo tonnage.
- The remaining **238** airports have neither passenger nor cargo evidence marked YES; their statuses are unverified, **not unsuitable**. **89** military-labelled candidates remain access reviews, overlapping the 238.
- Only airports present among the exact **312 existing Russian source airport IDs** were counted. No missing airports were fabricated or dropped; Russia was never geographically divided.

The new `group8_russia_evidence_types.csv` records the specific verification tier and URL for each of the 312 Russian airport IDs. **Never interpret a 2026 subsidized flight PLAN as observed 2026 passengers**: it is a different evidence tier, explicitly labeled.

**Cargo evidence sources and representative cases (all airport-specific):**
- Sheremetyevo (UUEE) Moscow Cargo: https://www.moscow-cargo.com/index.php/en/about
- Domodedovo (UUDD) cargo terminal: https://business.dme.ru/en/company/group/dc/
- Vnukovo (UUWW) official 2026 cargo terminal tariffs: https://www.vnukovo.ru/uploads/content/news/2025/12/04.12.2025/01-437-ob-izmeneniyah-v-tarifah-na-uslugi-ooo-vnukovo-kargo.pdf
- Pulkovo (ULLI) cargo terminal: https://pulkovoairport.ru/partners/cargo/
- Novosibirsk Tolmachevo (UNNT) 2025 volume (22,838 t) reported by operator: https://www.aviaport.ru/news/aeroport-tolmachevo-podvel-itogi-raboty-za-pervoe-polugodie-2026-goda/
- Koltsovo (USSS) published airport cargo terminal and customs facilities: https://ura.aero/en/partners/shippers/terminal/
- Ufa (UWUU) airport cargo operator: https://www.airportufa.ru/partners/info/cargo/
- Yakutsk (UEEE) cargo terminal and 2026 freight acceptance: https://yks.aero/cargo/services
- Krasnoyarsk (UNKL) official airport cargo warehouse: https://team.kja.aero/media/sklad-vremennogo-hraneniya-gruzovogo-terminala-aeroporta-Krasnoyarsk-otkryt
- Vladivostok (UHWW) specialist cargo terminal: https://air-cargo.ru/index.php?lang=ru
- Khabarovsk (UHHH) airport cargo services: https://khv.aero/cargo/

The Russian civil aerodrome registry, international-airport roster and 2026 airline schedules remain critical next data sources to match further airport names/codes, terminal facilities and **current** legal operating status. Government registry membership alone proves neither actual flights nor cargo operations. The regulatory review must also check restricted airspace and NOTAMs at game-route activation time; a historical short-lived interruption is not a permanent closure.

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
