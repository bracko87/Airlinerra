# Airlinerra — Group 9 commercial-aviation evidence review (2026-10-21)

**Coverage:** Exactly 142 historic runway-qualified **real** airports: Serbia 6, Slovakia 7, Slovenia 5, Spain 63, Sweden 61. The fictional Aleksandrovo Airport (LYAL) is **one additional protected Serbian airport** in the separate source `data/airports/fictional_airports.csv`; it is **not** a seventh real Group 9 airport. Existing master 7,846 rows remains unchanged.

## Reconciled country totals

```csv
country_iso,country_name,runway_qualified_candidates,passenger_evidenced,cargo_eligible_evidenced,military_review,other_unknown_both,public_airport_service_unverified
RS,Serbia,6,3,2,1,3,0
SK,Slovakia,7,4,2,1,3,0
SI,Slovenia,5,1,1,1,4,2
ES,Spain,63,46,28,4,17,0
SE,Sweden,61,39,5,7,22,0
TOTAL,TOTAL,142,93,38,14,49,2
```

Columns are NOT disjoint: many passenger-positive airports are also cargo-positive; airbase review airports frequently have neither evidentiary YES. Missing passenger/cargo evidence means `UNKNOWN` — not legal denial, zero actual demand or zero possible freight. Positives indicate **observed historical airport passengers/freight** or **documented commercial handling infrastructure**; they do not grant airline authorization, slots or all aircraft-category access.

## Country source reviews

### Serbia — six real airports, plus one independently preserved fictional airport

Official Government of Serbia infrastructure figures confirm 2025 passengers at Belgrade (**about 8.91 million**), Niš (**393,102**) and Morava (**14,713**). Cargo is separately operator-backed at Belgrade (5,500 m² domestic/international cargo warehouse and bonded customs services, with published handling equipment) and at Niš (2025 freight already exceeded **2,559 tonnes** by November and the operator reported flights from Urumqi). **Morava has passenger evidence, but no independently confirmed current commercial cargo-handling operation in this review.**
- https://www.srbija.gov.rs/tekst/en/130033/infrastructure.php
- https://beg.aero/eng/practical-informations/cargo
- https://ini.aerodromisrbije.rs/2025/11/17/ispisana-istorija-na-aerodromu-u-nisu-novi-godisnji-rekord-u-kargo-transportu/

**Kovin LY87:** 2,184m qualifying paved runway is a *technical* result only. No documented 2025/2026 commercial passenger flights, cargo terminal, public-airline permission or slots have been established, therefore both remain UNKNOWN and not playable by default. Batajnica LYBT remains military-access review, Ponikve LYUZ unverified. The owner-defined fictional **LYAL Aleksandrovo**, 2,200 m asphalt and **Local** tier, must always remain distinct from real infrastructure: its location, passenger/cargo service, slots and commercial access are not invented.

### Slovakia

Bratislava operator reports 2025 **2,438,215 passengers** and **18,929 tonnes** of cargo (including DHL freight). Košice operator reports **827,798 passengers**; its airport website explicitly offers cargo handling, with cargo flight handling around the clock but **cargo delivery/pickup only weekdays 07:00–15:00**. Poprad airport documents **111,658 passengers** in 2025. Bratislava operator confirms seasonal passenger charter at Piešťany (2025), not daily year-round service. Sliač, Trenčín and Malacky/Kuchyňa require separate civilian-access verification; absence of service proof does not mean prohibited.
- https://www.bts.aero/en/airport/press/latest-news/2-438-215-passengers-handled-in-2025-the-highest-annual-result-in-the-airport-s-history/
- https://www.airportkosice.sk/en/b2b/cargo
- https://www.letisko-poprad.sk/statistiky-letiska-poprad-2025-letecke-pohyby/
- https://www.bts.aero/en/airport/press/latest-news/bratislava-joins-piestany-in-offering-flights-from-tel-aviv/

### Slovenia

Statistics Slovenia reports 2025 **1.59m Ljubljana passengers**, plus more than **11,800 tonnes of goods transported through the airport**. Fraport Slovenia reports **27,186 tonnes of total handled cargo** in its operator-wide activity definition; these figures use **different definitions** and MUST NOT be added or interchanged. Ljubljana Airport cargo handling operations are performed within published times; cargo logistics warehouse standard reception is weekdays 07:30–17:30, Saturdays 08:00–12:00, with exceptions by prior notice.
- https://www.stat.si/StatWeb/en/News/Index/14283
- https://www.fraport-slovenija.si/content/fraport-company-slovenija/en/about-us/facts-and-figures.html
- https://b2b.lju-airport.si/en/cargo/logisticni-center/capacity-and-equipment/

The national report lists Maribor and Portorož as international airports and includes them within its combined annual passenger overview; **without airport-level positive passenger statistics**, we keep their `passenger_commercial_permission` as UNKNOWN pending a separate schedule/traffic confirmation. Cerklje remains a military-access case. Slovenj Gradec runway exists technically but is not presumed a commercially served airport.

### Spain — 63 real airports

Aena's **definitive annual 2025 airport-level passenger and cargo table** supports 2025 positive passenger movements for the matched airports, and *independently positive* freight/mail figures for 28 airports. The annual report distinguishes Madrid, Barcelona, Zaragoza and Vitoria as major cargo centres; Spain's passenger airports include numerous very small/seasonal fields. Tiny numbers at Albacete, Huesca or Madrid-Cuatro Vientos do **not** prove that scheduled airline tickets are available: YES here denotes positive *recorded passengers*, not regular route permission. Galicia, Balearic Islands, Canary Islands and mainland are all in one Spanish country group, no splitting.
- https://www.aena.es/sites/Satellite?blobcol=urldata&blobkey=id&blobtable=MungoBlobs&blobwhere=1576875166736&ssbinary=true

The Catalan authority separately records 2025 passenger activity and scheduled/other movements at **Lleida-Alguaire LEDA** and **Andorra-La Seu LESU**. The latter remains **Spain ES source geography** (airport not in Andorra). No passport country change.
- https://aeroports.gencat.cat/en/actualitat/2026/01/doble-record-passatgers-operacions-aeroports-lleida-alguaire-andorra-la-seu

Teruel aviation industrial airport and Ciudad Real have qualifying runways but not established public scheduled passenger operations here; private strips and naval/airbases likewise stay UNKNOWN. **Do not confuse all Aena recorded passengers with scheduled passengers**.

### Sweden — 61 real airports

The Swedish Transport Agency's official February 2026 report has a by-airport table of **positive actual 2025 passenger traffic**, including small airports and Bromma. **Swedavia** independently confirms cargo facilities for **Stockholm Arlanda, Göteborg Landvetter, Malmö and Luleå**; **Örebro** airport documents dedicated FedEx/DHL freight-handling facilities. The five cargo-positive airports therefore have specific cargo operations/capability evidence instead of extrapolated national tons.
- https://www.transportstyrelsen.se/globalassets/global/publikationer-och-rapporter/luftfart/flygtrafikstatistik-2025.pdf
- https://www.swedavia.com/about-swedavia/air-cargo/
- https://orebroairport.se/orebro-airport/top-meny/air-cargo

**Bromma ESSB** recorded 2025 passenger traffic but scheduled operations fell drastically after BRA moved most routes to Arlanda; it is *not* a dead airport, nor can former ~1m passenger levels be used as current demand. The 2025 operator website reports ~25,000 passengers and three domestic destinations. Military airfields in Sweden remain access reviews.
- https://www.swedavia.se/bromma/om-flygplatsen/

## Preservation, validation and next tasks

- Machine-readable `group9_commercial_review.csv` preserves every original source ID/name/code for the 142 technical candidates, positive evidence URL and date on each YES, plus an explicit review class and notes per airport.
- `group9_country_counts.csv` reconciles all 142 source IDs by country; `group9_special_cases.csv` enumerates non-automatic activation considerations (Kovin, Batajnica, Aleksandrovo, Bromma, etc.), **not formal prohibitions**.
- All airport location, physical runway counts/surfaces, source codes and the 7,846-airport register remain unchanged. Exactly six airport tiers exist: Local, Regional, Medium, Large, Major Hub, Mega Hub; only the fictional LYAL retains its already owner-assigned `Local` category.
- Cargo terminal working hours, actual legal airport operating hours/curfews, gate/remote-stand capacity, movement-slot calculation and simulated game passenger/cargo demand need separate implementation. Never infer zero curfew or unlimited slots.
- Validation: `python scripts/validate_commercial_group.py --group 9` (source ID integrity, positive evidence links, source-country totals).
- **Next geographic Group 10**: Switzerland, Turkey (whole country), Ukraine, United Kingdom, Vatican City (215 real runway-qualified airports). War-related airspace closure restrictions must be reviewed explicitly before gameplay activation.
