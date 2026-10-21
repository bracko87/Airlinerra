# Airlinerra — Group 10 preliminary commercial review (2026-10-21)

**Scope:** Switzerland 17, Turkey 75 (whole country), Ukraine 27, United Kingdom 96, Vatican City 0 = **215 original runway-qualified airport IDs**. All identifiers, source names and codes remain immutable. This review does NOT change the global airport register, directly assign any of the six final airport tiers, import into Supabase, or activate playable airline routes.

## Reconciled totals

```csv
country_iso,country_name,runway_qualified_candidates,passenger_evidenced,cargo_eligible_evidenced,military_review,other_unknown_both,public_airport_service_unverified
CH,Switzerland,17,5,2,5,12,0
TR,Turkey,75,50,49,10,25,0
UA,Ukraine,27,14,3,4,12,0
GB,United Kingdom,96,43,29,28,53,0
VA,Vatican City,0,0,0,0,0,0
TOTAL,TOTAL,215,112,83,47,102,0
```

Counts overlap: military access cases commonly have passenger/cargo UNKNOWN. `YES` means airport-specific **real passenger traffic or directly published passenger charter/scheduled services** and/or **actual handled cargo**, as specified in the row evidence note. It is NOT a universal legal commercial-operating permit, proof of regular flights every day, or a cargo capacity/slot allocation. Historical activity is not a current 2026 operating guarantee; `UNKNOWN` is not `NO`.

## Switzerland (CH)

Zürich operator reports **2025 32.6 million passengers and 440,930 tonnes of TOTAL freight handled** (includes airfreight and road-fed cargo, so do not mistake 440,930 tonnes for pure airborne uplift). Zurich's financial figures distinguish 311,584 tonnes air cargo and 129,345 tonnes road feeder in 2025. Geneva operator reports **17.85 million passengers and 96,047 tonnes freight/mail** for 2025. Swiss Altenrhein's airline publishes 2026 scheduled flights to Vienna; Bern has 2026 documented seasonal charter destinations, and Engadin/Samedan advertises private passenger charter flights, not regular airliner schedules. Those three regional cases have passenger YES, cargo UNKNOWN.
- https://newsroom.flughafen-zuerich.ch/en/zurich-airport-reaches-a-new-annual-peak-in-passenger-figures/
- https://report.flughafen-zuerich.ch/2025/ar/de/verkehrskennzahlen-standort-zuerich
- https://www.gva.ch/en/airport/Publications/actus/Davantage-de-passagers-mais-moins-de-vols
- https://peoples.ch/peoples-airline/linienfluege-altenrhein-wien/sommeraktion-wien-altenrhein
- https://helvetic.com/en/destination/brn-bern
- https://www.engadin-airport.ch/en/homebase-samedan/

Do not conflate aircraft movements at Buochs or Air Bases with public scheduled commercial passengers. Basel-Mulhouse is not a Group 10 CH source airport because its aviation data belongs to the earlier screened source geography; do not duplicate.

## Turkey (TR) — all 75 candidate airports, entire country

DHMİ **airport-specific April 2026 year-to-date passenger statistics** and **May 2026 year-to-date cargo statistics** (national government authority) support the evidence-bearing source-code matches; privately run Istanbul, Sabiha Gökçen, Çukurova and other DHMİ-supervised airports are retained under Turkey. Cargo refers to DHMİ's distinct **`CARGO.pdf`** air cargo statistics (not `FREIGHT.pdf`, which combines **baggage + cargo + mail** and should never be mistaken for pure airport airfreight demand). Both historic comparison-year activity and 2026 current figures appear in those tables: where only the earlier year shows positive activity, mark this a historical indicator not proof of current flights.
- https://www.dhmi.gov.tr/Lists/Istatislikler_EN/Attachments/268/PASSENGER.pdf
- https://www.dhmi.gov.tr/Lists/Istatislikler_EN/Attachments/269/CARGO.pdf
- https://dhmi.gov.tr/Sayfalar/EN/Statistics.aspx

**Special commercial-service restrictions:** Adana Şakirpaşa (LTAF) transferred scheduled airline services to Çukurova International Airport (LTDB) in **August 2024**. Istanbul Atatürk (LTBA) stopped scheduled and non-scheduled commercial passenger flights in **April 2019**; permitted specialist cargo/maintenance/general aviation was historically still possible. Both are runway-qualified but have passenger UNKNOWN (not auto-playable as ordinary passenger terminals). See `group10_operational_restrictions.csv`.
- https://www.flypgs.com/basin-odasi/duyurular/adana-sakirpasa-havalimani-degisikligi-hakkinda-duyuru-2024
- https://www.dhmi.gov.tr/Lists/AnnualReports/Attachments/13/2019.pdf

Dedicated military bases are civilian-access review cases; no blanket NO was inferred. Some military/civil dual-use fields show positive scheduled passenger and cargo traffic in DHMİ statistics and are categorized as evidenced civilian use with a separate dual-use caution, not falsely classified as wholly closed bases.

## Ukraine (UA) — no-war scenario and 2021 commercial baseline

**Owner-approved gameplay rule (2026-10-21): AIRLINERRA HAS NO WAR. Ukraine's national civil airspace is NOT closed by conflict in the game.** Previous blanket closures affecting all 27 airports were removed from `group10_operational_restrictions.csv`. Real-world post-2021 war closures and infrastructure damage do not constrain Airlinerra's game world. No gameplay enforcement is claimed by this data-only change.

**Evidence baseline: calendar 2021 (before the full-scale 2022 closure).** Each of the 27 original runway-qualified Ukraine airport IDs is preserved. Group10 now records **14 airports with individual pre-closure passenger-service activity** and **3 with cargo-service evidence**. Specifically, **Boryspil and Lviv** have both passenger and freight evidence, while **Hostomel (Antonov)** has specialized oversized freight/customs handling but no general public passenger flight evidence. The remaining 12 have both statuses UNKNOWN; that means further pre-closure service review, **not war-induced flight bans**. Four Air Bases remain military-civil access reviews, not automatically available scheduled airline airports.

Historical passenger figures are kept in **`group10_ukraine_prewar_baseline.csv`**, explicitly tagged `NO_WAR_OPEN_AIRSPACE`, reporting year 2021, source URLs and passenger-service type. **Do not blindly scale actual 2021 COVID-era passenger counts into fictional 2026 demand**: these are grounded historical reference points for later scenario-specific demand modeling.

- Boryspil operator: **9,433,000 passengers in 2021, including 8,797,800 scheduled; 45,675 tonnes air cargo and 6,828 tonnes mail separately**. Do not add cargo and mail unless the statistic specifically calls for combined freight/post. https://kbp.aero/en/news/passenger-flow-boryspil-international-airport-amounted-9-4-million-results-2021/
- Center for Transport Strategies, with 2021 airport-specific actual passenger counts for Lviv, Kyiv/Zhuliany, Dnipro, Zaporizhzhia, Kherson, Ivano-Frankivsk, Mykolaiv, Uzhhorod, Chernivtsi, Kryvyi Rih, Rivne and Vinnytsia. Some small airports had low-volume business/charters rather than scheduled daily flights; normal runway reconstruction could suspend services even in a no-war world. https://cfts.org.ua/articles/aeroporty_ukrainy_v_2021_godu_osnovnye_trendy_1878/128870
- Zaporizhzhia airport's own 2021 report: 617,518 passengers, of which 534,340 international and 83,178 domestic. https://ozh.aero/zvit-za-gruden-2021-roku/
- Lviv regional state statistics office: 2021 airport air cargo approximately 0.7 thousand tonnes by its transport definition; avoid combining this with differing freight-handling service indicators. https://lv.ukrstat.gov.ua/ukr/help/report_development%20trend%202021/chapter_14.html
- Antonov operator and archived customs procedure document Hostomel's heavy-cargo airbase and customs freight facilities. It is cargo-specialist YES, not general passenger YES; tonnes not fabricated. https://www.antonov.com/en/article/avialiniji-antonova-perevezli-70-tonn-medichnogo-priladdya-z-nimechchini-do-namibiji-za-programoyu-salis-nato and https://docs.dtkt.ua/doc/1025.5497.1
- Simferopol's 2021 airport-issued traffic report confirms **6.83 million** passengers. Recorded as source airport `UKFF` without changing original source geography. Its statistical scope **differs** from the Ukrainian aviation authority's **16.221 million** nationwide 2021 figure: never sum them as though they were the same coverage, and do not treat these source codes as a geopolitical conclusion. https://www.aviaport.ru/news/705617/

**Important completeness follow-up:** Two major airports serving **Odesa** and **Kharkiv** operated passenger flights in 2021 but were *absent from the existing 27-airport technical source group*. This is a separate runway-screen/source-coverage problem, **not a finding that those airports had no commercial passenger traffic**. Preserve the 27 original source IDs; audit the earlier technical runway filter and historical airport register later with genuine pre-closure pavement evidence before adding missing real airport candidates.

**No-war does not mean every paved airfield offers passenger tickets:** private, military and unverified fields remain UNKNOWN or MILITARY_ACCESS_REVIEW. Other non-conflict operational constraints, such as routine planned runway repairs, customs approvals, noise regulations and cargo hours, still need evidence. The Turkish LTAF/LTBA airport service transfer records remain in the restrictions file because those were nonwar changes.

## United Kingdom (GB) — 96 original airport candidates

**UK CAA Table 09 (2025 terminal/transit passengers)** and **Table 13.2 (2025 airport-specific actual freight tonnes)** are used individually. A CAA commercial passenger-positive record can include business/charter movements (e.g. Farnborough, Biggin Hill, Lydd's five recorded passengers). It does NOT mean the site has public daily 737/A320 schedules. Freight numbers can be tiny (Kirkwall, Benbecula, Norwich): `cargo YES` is historic positive tonnage, not a certified modern freight stand or warehouse.

- UK CAA statistics portal: https://www.caa.co.uk/data-and-analysis/uk-aviation-market/airports/uk-airport-data/uk-airport-data-2025/annual-2025/
- Passenger source: https://www.caa.co.uk/Documents/Download/24007/87fb7670-4e10-4aeb-942d-509238aa25a1/17553
- Freight source: https://www.caa.co.uk/Documents/Download/24007/87fb7670-4e10-4aeb-942d-509238aa25a1/17517

2025 UK CAA reports very large air cargo at **East Midlands, Heathrow, Stansted, Manchester**, etc. They are distinct from private, RAF/RNAS fields; the latter retain technical runway eligibility but require civilian access authorization. Brize Norton RAF troop transport is not public commercial passenger evidence. Carlisle, Bruntingthorpe and other airfields remain UNKNOWN pending updated operating approvals. Territories such as Jersey, Guernsey and Isle of Man are already recorded in their own source geographies and must not be duplicated in GB.

## Vatican City (VA)

The source screening identified **zero** >=1,200 m asphalt/concrete runways, which does not imply the absence of a heliport or any helicopter traffic.

## Game-engine/data integrity notes

- EXACTLY six future airport categories: Local, Regional, Medium, Large, Major Hub, Mega Hub. No airport receives a final new category from this commercial evidence review.
- No airport is discarded from the technical 7,846-record global register. Fictional Serbian LYAL remains protected. Turkey remains one whole country. Ukraine's original airport codes stay unchanged; the no-war scenario excludes conflict airspace blocks.
- All unknown airport-specific **runway slots, terminals/gate counts, remote stands, handling hours, airframe operating weights, curfews and noise limits** remain UNKNOWN. Actual past passenger/cargo movements must not become made-up future daily/week/month/year game demand.
- `group10_operational_restrictions.csv` now contains only two non-conflict-related Turkish service relocation records; 27 Ukraine conflict-related records have been removed. A separate scenario policy specifies no wartime airspace blocks. These are route eligibility rules for **future** implementation, not proof that the game route engine already enforces them.
- Validate using `python scripts/validate_commercial_group.py --group 10` and cross-check the operational-restrictions sidecar. Do not trigger automatic GitHub Actions, change Supabase or activate in-game airports.

**Next geographic batch:** Group 11 — small European territories, with zero-candidate places documented and no duplicates against Group 10.
