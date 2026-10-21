# Airlinerra — Group 6 initial commercial aviation assessment (2026-10-21)

**Scope**: 11 source-screened airports across Lithuania (6), Luxembourg (1), Malta (1), Moldova (3), and Liechtenstein (**0**). Every source airport ID is preserved; no entries have been deleted or activated.

## Country results

```csv
country_iso,country_name,runway_qualified_candidates,passenger_evidenced,cargo_eligible_evidenced,military_review,other_unknown_both,public_airport_service_unverified
LI,Liechtenstein,0,0,0,0,0,0
LT,Lithuania,6,4,4,2,2,0
LU,Luxembourg,1,1,1,0,0,0
MT,Malta,1,1,1,0,0,0
MD,Moldova,3,1,2,0,1,0
TOTAL,TOTAL,11,7,8,2,3,0
```

**Passenger evidence** includes actual scheduled/charter passenger operations or explicit licensed passenger-handling/civil-access capability (Siauliai). **Cargo evidence** includes actual freight and/or government/operator certified freight-handling services; it does NOT necessarily mean regular dedicated cargo flights or unrestricted permissions. Columns overlap: cargo YES can coexist with passenger UNKNOWN and important operational restrictions.

### Key evidence and limitations

- **Lithuania:** LTOU identifies the three normal passenger airports Kaunas, Palanga and Vilnius and publishes airport-specific historical cargo tonnes for each (2024 values: Kaunas 5,200 t, Palanga 472 t, Vilnius 16,300 t). The military/civil **Siauliai** aerodrome has separately authorized civilian ground handling, including passenger service and cargo/customs. **No regularly scheduled passenger flights are evidenced at Siauliai**, so its passenger YES denotes confirmed passenger-handling eligibility only. Kėdainiai and Panevėžys military airfields remain UNKNOWN pending AIP and defense/civilian permission evidence.
  https://ltou.lt/en/about-us/managed-airports/
  https://ltou.lt/en/lithuanian-airports-set-a-new-milestone-6-6-million-passengers-handled-in-2024/
  https://www.siauliai-airport.com/about-us/
  https://www.siauliai-airport.com/cargo-service/
- **Luxembourg:** Luxembourg-Findel supports scheduled passenger and major cargo transport, including Cargolux and established freight terminals. Luxembourg government 2026 expansion masterplan is not an operational slot-capacity declaration.
  https://www.lux-airport.lu/de/unternehmen/ueber-uns/unsere-geschichte/
  https://mmtp.gouvernement.lu/fr/actualites.gouvernement2024%2Bfr%2Bactualites%2Btoutes_actualites%2Bcommuniques%2B2026%2B04-avril%2B16-backes-masterplan-aeroport.html
- **Malta:** National Statistics Office records Malta International Airport passenger volume in 2025; official Malta 2026 AIP lists cargo handling equipment and customs/handling services. This does not imply zero curfew, unlimited apron stands or cargo movements/hour.
  https://nso.gov.mt/air-transport-main-page/
  https://www.transport.gov.mt/LM_AIP_2026_81-EFF-19-MAR-2026.pdf-f11344
- **Moldova:** 2025 Civil Aviation Authority reporting confirms Chișinău passenger activity, and official licence lists separately confirm Chișinău cargo and passenger handling providers. Bălți-Leadoveni remains UNKNOWN: absence from reviewed certified operator list is not proof that every kind of operation is prohibited.
  https://www.caa.md/index.php/en/statistics
  https://caa.md/ro/agenti-aeronautici-certificati-pentru-operarea-domeniul-aeroportuar
- **Mărculești / LUBM — serious route restriction:** CAA listed cargo/mail handling provider **AIM Handling** is approved excluding dangerous goods. Aerodrome certificate P-0004/2025, in force through **2026-12-08**, explicitly bars outbound **international departures** carrying **checked baggage, cargo, mail or onboard supplies**. Keep this airport in the source dataset but prevent routine international cargo simulation until route restrictions, actual certification and status are implemented and revalidated. An absence of blanket passenger rights is not the same as a universal ban on all local operations. **See machine-readable `group6_operational_restrictions.csv`.**
  https://caa.md/ro/agenti-aeronautici-certificati-pentru-operarea-domeniul-aeroportuar

### Technical and gameplay safeguards

- Country LI has a **documented zero**: do not add any airport to make the country nonzero.
- Airport identification, airport coordinates, runways, fictional LYAL, the existing 7,846-record technical master, and original groups remain unchanged.
- These preliminary YES markers mean supported activity/capability, not regulatory authorization for every aircraft or route, 24/7 operation, terminal capacity, or new airline traffic demand.
- No guessed slots, gate counts, remote stands, noise restrictions, curfew windows, actual traffic time series, or daily/weekly/monthly/yearly game demand were added. Official AIP/NOTAM review and demand-engine modelling are separate stages.
- The reusable validator supports explicitly screened **zero-airport countries** (LI) and recognizes `CARGO_EVIDENCED_ROUTE_RESTRICTED`, without allowing unsupported negative decisions.

## Validation

Run `python scripts/validate_commercial_group.py --group 6` (and optionally groups 1–5). The 11 commercial review IDs must reconcile one-for-one against Group 6 historic runway candidates, and Liechtenstein's zero must reconcile against the source country count file.

**Next group:** Group 7 — Monaco, Montenegro, Netherlands, North Macedonia, Norway (47 original technical candidates).
