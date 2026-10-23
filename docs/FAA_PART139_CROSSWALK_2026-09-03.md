# Airlinerra — FAA Part 139 September 2026 crosswalk

**Completed and verified 23 October 2026. This is a certification research layer, NOT approval of commercial flights or Airlinerra gameplay.**

## Official source

- Publisher: Federal Aviation Administration (FAA).
- [Official publication page](https://www.faa.gov/airports/airport_safety/part139_cert/part_139_airport_certification_status_list).
- [Official XLSX dated 2026-09-03](https://www.faa.gov/sites/faa.gov/files/arp-aas-part139-cert-status-table-2026-09-03.xlsx), effective **September 3, 2026**, page last updated **September 8, 2026**.
- **517 source rows** and **71,610 bytes** in the official file retrieved for this import. Raw FAA spreadsheet columns are: State, FAA Region, Airport Identifier (LOC ID), Airport Name, Associated City, Inactive Status, Hub Size, NPIAS Role, Class, ARFF Index, ATCT, SMS Trigger, SMS Waiver.
- Private import manifest stores **517 expected/517 imported, VERIFIED**, effective date, source URL, row field mapping and MD5 **`352602769a41bc94c6d1b063e9de80e3`** of normalized source row identifiers/classes/index data (not a raw-file MD5 or SHA). The complete parsed rows and source row numbers are preserved in Supabase.
- The one-time FAA data retrieval endpoint was disabled and returned to JWT-protected 410 Gone after this operation. No public airport research API or service role credential was created.

## Scope and results

We matched the official FAA roster to **exactly the 1,929 U.S. expansion airports** in `airlinerra.airport_commercial_verification`, whose FAA NASR (2026-10-01) airport identifiers had already been independently pinned as exact FAA identifier matches within 5 km.

**Matching requires BOTH exact state code and FAA location identifier.** Never use airport name alone; do not conflate reused similar names, prefixes `K`, ICAO or IATA with FAA LOC ID.

| Result | Airports |
| --- | ---: |
| 2026 FAA-listed Part 139 airports (exact state + FAA code) | **50** |
| Of these, no `Inactive` marker in the September source | **42** |
| Of these, **explicitly `Inactive`** on September source | **8** |
| **Not listed on this Part 139 roster** (not proof of closure or prohibition of small charter/cargo) | **1,879** |
| **Total expansion candidates cross-checked** | **1,929** |

**Official FAA Part 139 class of the 50 FAA-listed airports:** Class I 8, Class II 1, Class III 3, Class IV 38. Of the eight marked inactive, two are Class III and six Class IV. All eight Class I and the Class II have no inactive marker in this source. `Not marked inactive` is **not** equivalent to a certified currently operating airline route or unrestricted airport access.

The FAA's [classes of airports](https://www.faa.gov/airports/airport_safety/part139_cert/classes-of-airports) have operational meaning:

- **Class I:** may serve scheduled large air carrier flights; other covered passenger operations may also be served.
- **Class II:** scheduled small and unscheduled large air carrier flights (not scheduled large).
- **Class III:** scheduled small air carrier flights (not large).
- **Class IV:** unscheduled large air carrier flights (not scheduled air carrier flights under the class).
- Operations outside Part 139's triggers may still occur at non-Part-139 airports. A Class IV or a runway with 2,000+ m does **not** imply scheduled passenger flights.

**Do not confuse FAA's four regulatory classes with Airlinerra's exactly SIX game airport categories:** Local, Regional, Medium, Large, Major Hub and Mega Hub.

### New private Supabase objects

| Object | Rows | Role |
| --- | ---: | --- |
| `airlinerra.faa_part139_source_rows` | **517** | Original September FAA record fields, codes, class, ARFF, source page/row and date |
| `airlinerra.faa_part139_import_manifest` | **1** | Verified import counts, source reference and normalized digest |
| `airlinerra.airport_certifications` | **50** | Linked evidence for the 50 exact-match expansion airports |
| `airlinerra.airport_commercial_verification` | **1,929** | Now has explicit `part139_certificate_status`: listed/not-marked-inactive; listed/inactive; not-listed-in-September-roster |
| `airlinerra.airport_part139_crosswalk` | **1,929** | Private read-only research view: airport names, FAA classification, ARFF, inactive flag and next action |

All new source tables have RLS enabled and no public anonymous/authenticated grants. Crosswalk view uses `security_invoker=true`. The original 3,140-airport cohort was **not edited or recategorized**, and `airport_world_activation` still has **zero active airports**. All 1,929 expansion `game_admission_status` entries remain `NOT_APPROVED`.

### Eight explicitly inactive FAA rows in the expansion scope

| Airport | FAA LOC ID | FAA Part 139 class |
| --- | --- | --- |
| Chico Regional Airport | CIC | III |
| Columbus Municipal Airport | BAK | IV |
| Igor I Sikorsky Memorial Airport | BDR | IV |
| Mount Vernon Outland Airport | MVN | IV |
| Oxnard Airport | OXR | III |
| Porter County Municipal Airport | VPZ | IV |
| Southern Wisconsin Regional Airport | JVL | IV |
| The Ohio State University Airport – Don Scott Field | OSU | IV |

These are **FAA certification inactive indicators from the 2026-09-03 roster**, not confirmed complete airport closures or proof they cannot host any smaller civil flights.

## Follow-up research order

1. **Eight Class I listed/not inactive**: independently confirm present scheduled passenger air-carrier operations, airport/operator permissions, aircraft compatibility, facilities and service rules. Prioritize airline-capable routes based on actual operating evidence.
2. **One Class II + one non-inactive Class III**: validate 10–30-seat scheduled air carrier service and airport-specific restrictions (e.g., ATR-size compatibility is a separate aircraft/runway issue; do not infer aircraft certification from category).
3. **32 Class IV listed/not inactive**: check unscheduled large-air-carrier passenger access, small charter operators and cargo independently. Never mark these as scheduled airline airports simply because Class IV is listed.
4. **Eight FAA-marked inactive**: verify updated status and restrictions before proposing any service model.
5. **1,879 not listed on FAA Part 139**: research legitimate non-Part-139 activities such as very small charter, nonscheduled cargo, and qualifying on-demand operations. No blanket exclusion or automatic zero capacity. Continue the runway-condition and owner-permission review queues separately.

### Useful SQL

```sql
select effective_date, expected_records,imported_records,import_status,data_digest_md5
from airlinerra.faa_part139_import_manifest;

select part139_certificate_status,count(*)
from airlinerra.airport_commercial_verification
group by 1 order by 1;

select airport_name,faa_identifier,faa_state, faa_part139_class,arff_index,
       faa_inactive_status,part139_next_action,proposed_airlinerra_category
from airlinerra.airport_part139_crosswalk
where on_2026_faa_part139_list
order by part139_followup_priority,airport_name;

select count(*) from airlinerra.airport_world_activation where active; -- 0
```

**Next phase is individual commercial-operating evidence, not another generic airport list.** GitHub remains the source-controlled research/report archive, and Supabase is the central structured airport database. Re-run a controlled and dated FAA snapshot when FAA publishes a newer roster; do not overwrite evidence from earlier dates.
