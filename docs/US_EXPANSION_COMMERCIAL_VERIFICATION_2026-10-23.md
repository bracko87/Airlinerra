# Airlinerra — U.S. expansion airport commercial verification (2026-10-23)

**Status: Review queue created, 13 individual operator reviews recorded, and official September 3, 2026 FAA Part 139 certification crosswalk imported and verified. No airport is approved for gameplay.**

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

**Database checkpoint:** `airport_commercial_verification` has **1,929** rows, **13** with individual operator/authority evidence, and **14** newly created `PRIMARY_OPERATOR_SOURCE_REPORTED` evidence entries. The FAA's official September 3, 2026 Part 139 XLSX was subsequently imported in full: **517 official rows, 50 exact FAA state+LOC-ID expansion matches (42 without an inactive marker, 8 explicitly inactive), 1,879 expansion airports not listed**. The complete source import, status code definitions, class limitations and follow-up tasks are documented in [FAA Part 139 crosswalk](FAA_PART139_CROSSWALK_2026-09-03.md). All airports remain NOT_APPROVED.

These individual source pages do not all identify a separately dated publication/effective record. Database evidence preserves that limitation and records the date they were checked (2026-10-23). Part 139 source matching is now **COMPLETE for all 1,929** using the published September spreadsheet. Airport operating permission, actual scheduled service, charter rights, cargo capability and aircraft compatibility remain separate **UNVERIFIED / NOT_CHECKED** tasks.

## Regulatory crosswalk completed — next service verification

The [official FAA Part 139 September 3 spreadsheet](https://www.faa.gov/airports/airport_safety/part139_cert/part_139_airport_certification_status_list) was successfully parsed in a fixed-source, validated import and written to private Supabase tables: 517 source airport entries, exactly 50 matched to our 1,929 U.S. expansion records, with exact FAA state + LOC ID matching, class I–IV, ARFF index and inactive status. See [full crosswalk and its remaining restrictions](FAA_PART139_CROSSWALK_2026-09-03.md).

**Next evidence tasks:**

1. Verify actual scheduled service and aircraft constraints for the eight Class I matched airports not marked inactive.
2. Verify small scheduled carrier activity for the single Class II and single non-inactive Class III matches.
3. Check the 32 non-inactive Class IV matches for unscheduled large-air-carrier flights, smaller charters and cargo; never infer scheduled service from Class IV.
4. Individually investigate the eight official FAA rows marked inactive and their current operator restrictions.
5. Continue operator and cargo/charter evidence for the 1,879 unlisted airports, the 45 poor/failed runway conditions and the 63 ownership special cases. **Not on Part 139 is not a universal commercial-airport prohibition.**

Maintain exactly six **Airlinerra gameplay categories** independently of FAA's four regulatory classes and never activate airports automatically.

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
