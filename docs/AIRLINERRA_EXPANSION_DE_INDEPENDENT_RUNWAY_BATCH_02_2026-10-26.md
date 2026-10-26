# Airlinerra — German Expansion Runway Batch 02

**26 October 2026 | Private Supabase:** `hwllkabgzaynalahvkpz`, `airlinerra` | **GitHub `main`**

## Completed batch

**8** further airports from the 3,906-airport expansion cohort reviewed. **6** advanced on independently sourced operator/municipal paved-runway evidence. **2** remain unverified for technical/source reasons. There were **zero game activations**. The original **3,140** World 1 airports and their home-airport registration catalog were unchanged.

| Metric | After batch |
|---|---:|
| German Batch 02 research rows | 8 |
| Operator/municipal runway evidence confirmed, simulation release pending | 6 |
| Independent-source holds retained | 2 |
| Worldwide expansion independent verification holds | 1,815 (from 1,821) |
| German independent verification holds | 32 (from 38) |
| World 1 active foundation airports | 3,140 |
| Newly activated expansion airports / World 2–3 | 0 / 0 |

## All eight airports and sources

| ICAO and airport | Main runway | Evidence and important conditions |
|---|---|---|
| **EDBR Rothenburg/Görlitz** | 17/35, **2,000 × 30m asphalt** | **Advanced**. [Operator-hosted approved airport regulation](https://flugplatz-rothenburg-goerlitz.de/images/pdf/FBO_EDBR_2024_genehmigt.pdf) lists **TORA and LDA 2,000m**, PCN23; [operator information](https://www.flugplatz-rothenburg-goerlitz.de/informationen-fuer-piloten) lists seasonal PPR. Fuel must be arranged and rescue/snow-clearance restrictions independently checked. |
| **EDCO Obermehler-Schlotheim** | 11/29, **1,450 × 30m asphalt** | **Advanced**. [Airport operator](https://www.flughafen-obermehler.de/) confirms dimensions and a 14t aircraft limit; 11/29 direction corroborated by [aviation directory](https://dulv.de/fmwebphp/Flugplatz/details.php?id=1047). Limited seasonal opening and PPR; fuel station described as being prepared, **not verified available**. |
| **EDCP Peenemünde** | 13/31, **2,400m concrete**, disputed width | **Hold**. [Older IVAO procedure](https://de.ivao.aero/prozeduren/edww/e/edcp/) says **48m wide**; [DULV](https://dulv.de/fmwebphp/Flugplatz/details.php?id=1071) says **60m**. Operator's site could not be accessed. No verified current primary-source runway width or operational status. |
| **EDCY Welzow** | 03/21, **2,000 × 30m concrete** | **Advanced**. [Operator runway data](https://www.airport-welzow.de/fliegerinfos/) confirms dimensions, 14t standard limit (higher by exception), VFR and fuel. [Current operator events](https://www.airport-welzow.de/willkommen-mit-kalender/) list aerobatic training **October 26–29**, requiring flight-date checks. Nearby water landing area is a different facility. |
| **EDFB Reichelsheim** | 18/36, **1,300 × 23m asphalt** | **Advanced**. [Operator pilot information](https://www.edfb-reichelsheim.de/PILOTENINFO) explicitly says RW18 **LDG 1,230m**, RW36 **LDG 1,300m** (takeoff runs 1,300m/1,230m); both landings meet 1,200m, but RW18 only by 30m. Secondary directory shows older/conflicting 15m width; operator says 23m. Aircraft above 8t require prior permission. |
| **EDFE Frankfurt-Egelsbach** | 08/26, **1,400 × 25m asphalt** | **Hold**. A search-indexed [2025 airport-operator regulation PDF](https://egelsbach-airport.com/wp-content/uploads/2025/11/EDFE-Benutzungsordnung-25-11-2025-FinalohneUnterschrift-EN.pdf) states RW08 LDA **1,400m**, **RW26 LDA 1,166m — below the threshold**. The source host currently returns a temporary BSI-related unavailable notice, so current document/AIP revalidation is outstanding. Do not infer that both ends have a 1,400m usable landing distance. |
| **EDFQ Allendorf/Eder** | 11/29, **1,240 × 30m asphalt** | **Advanced**. [Current airport operator](https://www.flugplatz-allendorf.de/) confirms runway length/width and local operating/PPR procedures. [Resident club](https://www.lsv-ederbergland.de/der-flugplatz-allendorf-eder/) and [aviation directory](https://dulv.de/fmwebphp/Flugplatz/details.php?id=623) corroborate surface; current per-end LDA still unverified. Only 40m above physical threshold. |
| **EDGE Eisenach-Kindel** | 10/28, **1,720 × 55m concrete** | **Advanced**. [Official 18 August 2025 municipal presentation by airport management](https://ris.eisenach.de/bi/getfile.php?id=130445&type=do) states concrete **1,720 × 55m**, aircraft up to 20t. [Current operator page](https://www.flugplatz-eisenach.de/flugbetrieb/) corroborates operations. [DULV](https://dulv.de/fmwebphp/Flugplatz/details.php?id=781) cites only 30m width, so source disparity remains noted; landing distance not yet authenticated. |

The airport registry's original physical runway lengths were **not overwritten**. Batch 02 records keep both original registry length and individually cited operator length, width, surface, possible direction-specific published LDA, evidence confidence grade and follow-up notes.

## Database updates and protection

The six primary operator/municipal evidence cases advanced from `HOLD_INDEPENDENT_VERIFICATION` to `INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING` in `airlinerra.airport_access_reviews`; both `identity_status` and `paved_runway_status` were changed to `VERIFIED`, but **no real-world commercial airline approval** was given. EDCP and EDFE retain their original source-verification holds.

All eight records are `NOT_APPROVED` with `simulation_world_active=false`. Existing private research RLS and no public/authenticated read permissions were independently checked. The World 1 catalog retains **3,140** active airports and **3,140** registration picker entries; no expansion airport or other world has been activated.

## Version control

- [Reproducible Batch 02 source evidence and guarded status updates](./sql/AIRLINERRA_EXPANSION_DE_INDEPENDENT_RUNWAY_BATCH_02_2026-10-26.sql)
- [Read-only SQL audit queries](./sql/AIRLINERRA_EXPANSION_DE_INDEPENDENT_RUNWAY_BATCH_02_CHECKS_2026-10-26.sql)

Source-row readback, backlog, privacy and world-activation checks completed in live Supabase. A single composite DO-block acceptance query could not be executed because the database query interface rejected it; the report does **not** claim that test passed.

## Next

Continue with the **32 German expansion candidates still on independent-source hold**, resolving any source-length and landing-distance conflicts without delaying the 3,140 already authorized simulation locations. Any newly playable expansion airports require a separately controlled owner-authorized game release.
