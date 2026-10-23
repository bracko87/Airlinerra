# Airlinerra — U.S. expansion airport commercial verification (2026-10-23)

**Status: Database review queue created and 13 individually sourced airport reviews recorded. No airport is approved for gameplay.**

The priority research scope is the **1,929 U.S. airports** in cohort `EXPANSION_3906` already matched by immutable OurAirports ID to 2026-10-01 FAA NASR records. Each has an `EXACT_FAA_IDENTIFIER_AND_WITHIN_5KM` match, FAA-reported open public use and runway screening. **FAA public use is not equivalent to permission for scheduled air carrier flights, charter rights, cargo service, Part 139 certification or game suitability.** Supabase working table `airlinerra.airport_access_reviews` continues to keep final commercial permission unverified.

## Supabase work completed

In private schema `airlinerra`:

- **`airport_commercial_verification` (1,929 rows)** — evidence-linked, one row per immutable airport key, from the 2026-10-01 FAA NASR snapshot. Stores original FAA identifier and state, ownership code, runway length/width/surface/condition, snapshot hash, evidence record link, and separate checks for Part 139, scheduled passenger, small aircraft charter, cargo and aircraft compatibility. Every row has `game_admission_status=NOT_APPROVED`.
- **`airport_commercial_review_queue` (1,929 rows)** — convenient private, `security_invoker` query view joining airport names, provisional *unapproved* Local/Regional tier and the next research action. Sort by `research_priority` ascending.
- Both data sources remain private (RLS on the table; no `anon` or `authenticated` grants). They are not part of the public Netlify website.

### Evidence-first review groups

These are **research triage queues, not definitive categories of commercial airport eligibility**:

| Queue | Rows | Why |
|---|---:|---|
| Long runway air-carrier investigation | 128 | FAA-reported runway ≥2,000 m, GOOD/EXCELLENT condition, non-private/non-military owner codes |
| Medium runway passenger/charter investigation | 890 | FAA-reported runway ≥1,500 m, GOOD/EXCELLENT condition, selected after higher-priority queue |
| Small aircraft / charter investigation | 486 | FAA-reported runway below 1,500 m, GOOD/EXCELLENT condition |
| Additional runway-condition follow-up | 315 | FAA reports FAIR rather than GOOD/EXCELLENT |
| Ownership / operating-rights hold | 63 | Private or military owner code after higher-impact condition issues are separated |
| Condition not reported | 2 | Need source condition verification |
| Poor/failed reported pavement | 45 | Recheck runway status, pavement and operator restrictions before further commercial assessment |
| **Total** | **1,929** | All have no final commercial approval |

Across the whole group, FAA ownership codes are `PU` 1,859, `PR` 66, and `MR` 4. The 63 owner-review queue is not the full 70 PR/MR records because seven receive more urgent pavement/condition review. No airport is excluded solely for a private or military owner code.

The queue uses FAA *reported* conditions from source date 2026-10-01. These are neither a fresh field inspection nor proof of airline performance for any specific aircraft. Longer runway length is used for ordering research, not automatic admission, certification or promotion to a higher of the six Airlinerra levels.

### Individually reviewed airport records — 13 airports

Four initial operator evidence records were added for three airports, followed by ten additional dated/source-linked evidence records for ten further airports. This covers **13 distinct airports with 14 individual evidence records**. Each source distinguishes actual airline service from facilities and permissive general aviation descriptions:

1. **Scottsdale Airport (SDL; `OURAIRPORTS:21045`)**: City describes a GA reliever **without commercial commuter/airline service** ([official city general info](https://www.scottsdaleaz.gov/scottsdale-airport/general-information)). The city [airport business directory](https://www.scottsdaleaz.gov/scottsdale-airport/airport-airpark-businesses) lists **aircraft-charter businesses**. Scheduled airline: operator reports none. Charter providers: identified; airport-specific permits, aircraft compatibility and routes not independently approved. Cargo: not checked.
2. **Crater Lake–Klamath Regional (LMT; `OURAIRPORTS:3646`)**: City [passenger page](https://klamathfalls.city/157/Passengers) says no current commercial-airline service. This does not prove that charter, cargo, or restored scheduled operations are illegal/impossible; those require separate research.
3. **Mojave Air & Space Port (MHV; `OURAIRPORTS:20507`)**: Airport operator [contracts and leasing](https://www.mojaveairport.com/contracts-leasing) describes its runway as accommodating large cargo aircraft and offers warehousing/logistics infrastructure. This is **facility capability evidence only**, not proof of active commercial cargo operations, operating authorization, scheduled airline service or a game route.

### Ten additional authority-backed airport reviews

| Airport / FAA code | Official source and narrow finding | Remaining decision |
| --- | --- | --- |
| Donaldson Field **GYH** | [SC Aeronautics, updated Aug 18 2026](https://aeronautics.sc.gov/airports/donaldson-fld-airport): A26 remark restricts air carrier operations with over 30 seats **except with 24-hour prior permission**; taxiway restrictions also apply | Verify permitted aircraft, prior-permission process, Part 139 and commercial operations; not a blanket exclusion |
| Francis S. Gabreski **FOK** | [Suffolk County](https://suffolkcountyny.gov/Departments/Economic-Development-and-Planning/Francis-S-Gabreski-Airport/Airport-History) reports civil air taxi/corporate traffic and a military rescue wing | Mixed use; neither automatically military-only nor airline-certified |
| Reno-Stead **RTS** | [Reno-Tahoe Airport Authority](https://www.renoairport.com/airport-authority/stead-airport/) describes general aviation | No inference of scheduled passenger/cargo operations |
| Phoenix Goodyear **GYR** | [City of Phoenix](https://www.phoenix.gov/administration/departments/aviation.html) reports general aviation, maintenance, large-aircraft MRO, training and corporate operations | Aircraft servicing is not a passenger/cargo route |
| TSTC Waco **CNW** | [Texas State Technical College](https://www.tstc.edu/tstc-waco-airport/) describes educational use and two major paved runways | Training and infrastructure are not operator permission |
| Phoenix Deer Valley **DVT** | [Municipal operator](https://www.deervalleyairport.com/about-dvt-airport/) says airport serves civil aviation *except commercial passenger service*, while [FAA flight deck](https://www.faa.gov/flight_deck/dvt) references a ramp reserved for commercial air carrier and passenger air taxi aircraft | Scope **conflict** flagged for direct clarification; no automatic permission/ban |
| Central Colorado Regional **AEJ** | [Town of Buena Vista](https://buenavistaco.gov/2679/Voluntary-Noise-Abatement) explicitly reports **no scheduled commercial flights**; GA/air ambulance uses separately | On-demand charter not ruled out by this finding |
| Stennis International **HSA** | [Hancock County port authority](https://www.portairspace.com/logistics) reports large freighter capable runway and FBO ground cargo support | Cargo-capable is not proof of active cargo routes or carrier permission |
| Ardmore Municipal **ADM** | [Oklahoma aviation authority](https://oklahoma.gov/aerospace/airports/find-an-airport/ardmore-municipal.html) confirms runway, terminal, tower and services (page updated 2023) | Historical facility source needs current aircraft/Part 139 and service check |
| Enid Woodring **WDG** | [Oklahoma aviation authority](https://oklahoma.gov/aerospace/airports/find-an-airport/enid-woodring-regional.html) confirms runway and terminal services (page updated 2023) | Current charter, cargo and Part 139 independently unresolved |

**Database checkpoint:** `airport_commercial_verification` has **1,929** rows, **13** with `independent_review_at` set and linked operator/authority pages. `airport_evidence` contains **14** new `PRIMARY_OPERATOR_SOURCE_REPORTED` entries. Every reviewed airport remains `NOT_APPROVED`. The official September 3, 2026 FAA Part 139 XLSX has a verified [FAA publication page](https://www.faa.gov/airports/airport_safety/part139_cert/part_139_airport_certification_status_list), but direct file downloading returned binary data inaccessible to the current importer, so **0 of 1,929 Part 139 statuses were marked checked**. It would be misleading to use an older public PDF as if it were September 2026 certification evidence.

These individual source pages do not all identify a separately dated publication/effective record. Database evidence preserves that limitation and records the date they were checked (2026-10-23). Part 139 for all 1,929 remains **NOT_CHECKED**. Work must resume from the verified September file, not from guesses or stale proxy lists.

## Regulatory crosswalk still required

FAA's [Part 139 Airport Certification Status List](https://www.faa.gov/airports/airport_safety/part139_cert/part_139_airport_certification_status_list) links an official **September 3, 2026 .xlsx** file. The September spreadsheet was identified but **not machine-parsed or joined into the database yet**, therefore no certification results were assumed or fabricated. FAA confirms that Part 139 governs specified U.S. scheduled/unscheduled passenger air carrier operations; many smaller GA and charter operations are outside the Part 139 trigger (FAA [scope guidance](https://www.faa.gov/airports/airport_safety/part139_cert/airports-affected)). Absence from this certification list **does not mean every commercial flight is prohibited**.

Next evidence tasks in order:

1. Validate official FAA Part 139 status XLSX and match by actual FAA location identifier + state and operator identity; mark certificate class, ARFF index, inactive status and effective date only on unambiguous matches; otherwise `NOT_CHECKED`.
2. Research the **128 long-runway group** using operators/AIPs and distinguish scheduled air carrier rights, unscheduled small-aircraft charters, actual cargo capability and appropriate aircraft operating conditions.
3. Independently review **45 poor/failed surface reports**, **two unreported conditions**, and PR/MR ownership and access restrictions; do not declare permanent ineligibility from runway condition or owner code alone.
4. Progress to the **890 medium**, **486 small-aircraft**, then **315 fair-condition** airports; preserve `UNKNOWN` and exact official evidence citations.
5. Only after verified source-backed review propose gameplay decisions and *separately* assess exactly the six categories: Local, Regional, Medium, Large, Major Hub, Mega Hub. Passenger and cargo approvals are independent.

## Verification queries

```sql
select research_priority, review_bucket, count(*) n
from airlinerra.airport_commercial_verification
group by 1,2 order by 1;

select airport_key,airport_name,faa_identifier,provisional_game_category,
       runway_length_m,runway_condition,research_priority,review_bucket,
       next_action,scheduled_passenger_verification,cargo_flight_verification
from airlinerra.airport_commercial_review_queue
order by research_priority,runway_length_m desc,airport_key limit 100;

select count(*) from airlinerra.airport_commercial_verification; -- 1929
select count(*) from airlinerra.airport_world_activation where active; -- 0
```

**No destructive operation or modification to the 3,140-airport original cohort. No airports activated. The broad 3,906 expansion remains provisional and the other 1,106 master airports remain for later review.**
