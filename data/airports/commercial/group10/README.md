# Airlinerra — Group 10 preliminary commercial review (2026-10-21)

**Scope:** Switzerland 17, Turkey 75 (whole country), Ukraine 27, United Kingdom 96, Vatican City 0 = **215 original runway-qualified airport IDs**. All identifiers, source names and codes remain immutable. This review does NOT change the global airport register, directly assign any of the six final airport tiers, import into Supabase, or activate playable airline routes.

## Reconciled totals

```csv
country_iso,country_name,runway_qualified_candidates,passenger_evidenced,cargo_eligible_evidenced,military_review,other_unknown_both,public_airport_service_unverified
CH,Switzerland,17,5,2,5,12,0
TR,Turkey,75,50,49,10,25,0
UA,Ukraine,27,0,0,4,27,0
GB,United Kingdom,96,43,29,28,53,0
VA,Vatican City,0,0,0,0,0,0
TOTAL,TOTAL,215,98,80,47,117,0
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

## Ukraine (UA) — 27 runway-qualified candidates, **zero current civil-operating approvals**

**CRITICAL OPERATIONAL RULE:** EASA's 2026 conflict-zone bulletin references Ukrainian NOTAM A0021/26 and says that the **entire Ukrainian airspace** across FIRs Lviv, Kyiv, Dnipro, Simferopol and Odesa is **closed for civil aviation** due to active conflict hazards. Therefore all 27 original runway-qualified airport IDs must remain in the *technical* inventory but **all 27 must be blocked from playable civil passenger and cargo routes** until BOTH official airspace reopening and individual airport readiness are reverified. Do not invent actual physical post-conflict conditions; airport infrastructure may be damaged. No contemporary civil activity is considered eligible just because a runway previously met asphalt/concrete criteria.

- https://www.easa.europa.eu/en/domains/air-operations/czibs/czib-2022-01r14
- Machine-readable table: `group10_operational_restrictions.csv` includes **27 distinct Ukraine source airport IDs**.

`passenger_commercial_permission` / `cargo_commercial_permission` are UNKNOWN, not a misleading claim that these airports had no historical service or a permanent postwar ban. Do not confuse current conflict safety with historical traffic demand or political/territorial classification.

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
- No airport is discarded from the technical 7,846-record global register. Fictional Serbian LYAL remains protected. Turkey remains one whole country. Ukraine airport origin/source codes stay identical even in a period of closure.
- All unknown airport-specific **runway slots, terminals/gate counts, remote stands, handling hours, airframe operating weights, curfews and noise limits** remain UNKNOWN. Actual past passenger/cargo movements must not become made-up future daily/week/month/year game demand.
- `group10_operational_restrictions.csv` contains 29 restricted/hold-for-review records: Ukraine 27; Turkey LTAF and LTBA 2. These are route eligibility rules for **future** implementation, not proof that the game route engine already enforces them.
- Validate using `python scripts/validate_commercial_group.py --group 10` and cross-check the operational-restrictions sidecar. Do not trigger automatic GitHub Actions, change Supabase or activate in-game airports.

**Next geographic batch:** Group 11 — small European territories, with zero-candidate places documented and no duplicates against Group 10.
