# Airlinerra — Phase 3 Supplemental Operational Constraint Review (26 Airports, October 25, 2026)

**COMPLETE; VERIFIED BY DIRECT SUPABASE READ-BACK.** This supplemental review documents 26 additional distinct cases selected from unresolved operational holds. **Seven have a verified narrower runway/noise issue and advance to the NEXT ELIGIBILITY GATE; 19 remain held.** All 26 retain individual evidence URLs and next actions. None was added to gameplay.

**Separate workstream notice:** A separately published [Operational Batch 02 report](./US_EXPANSION_PHASE3_OPERATIONAL_CONSTRAINT_BATCH_02_2026-10-25.md) already covers **40 different airport records** and is preserved unchanged. This report is not a replacement, nor a retroactive change to that published batch. Global aggregate counters may include independent/concurrent reviews; only the exact 26 codes in this ledger are attributed to this supplemental review.

## Supplemental results

| Check | Result |
|---|---:|
| Individually reviewed airports / unique immutable keys | **26 / 26** |
| Confirmed distinct qualifying paved main runway vs short turf/secondary | **6** |
| Voluntary curfew, not legally mandatory all-airport closure | **1** |
| **Moved to next eligibility gate** | **7** |
| Retained case-specific operational hold | **19** |
| Final game admission or categories | **0** |
| Modification of original 3,140-airport roster | **None** |

### Seven advanced only to the next checks

**OLU (Nebraska), ADT (Kansas), CAD (Michigan), DNS (Iowa), HYR (Wisconsin), LWV (Illinois)** each have source-documented paved runway capacity distinct from shorter or nonqualifying turf strips. [Iowa DOT Denison example](https://opmapps.iowadot.gov/aviation/airports/dns) records 5,000ft concrete 12/30 and a separate 2,000ft turf 18/36. Nonqualifying turf does not close the main concrete.

**SUA — Martin County Witham Field, Florida:** [Martin County airport operator](https://www.martin.fl.us/pilot-information) directly states 23:00–07:00 noise curfew **voluntary**; a requested restriction is not a blanket legally binding shutdown. Published control-tower hours are separate. Actual aircraft weight, declared LDA, owner and operator requirements remain.

Advancement is only a resolution of the *particular source restriction*, NOT final airport suitability, classification or game admission.

### Why the other nineteen did not advance

- Reported PAPI/ILS/IAP/REIL outages at **06A, 74V, I40, K24, MFV, OTG, VSF** need current date-specific FAA procedure/lighting checks, but do not themselves imply permanent runway closure.
- Aerobatic activities at **L08 Borrego Valley** and **PYP Centre–Piedmont** had date-limited October event notices already elapsed by the Oct 25 review; other ongoing jump activity or new notices may still apply. A historical notice's expiry does not automatically constitute a live cleared NOTAM.
- **P13 San Carlos Apache** needs tribal-owner permission and updated fuel/PAPI/REIL/AWOS notices; **S33 Madras** has positive charter leads but dated procedure and actual operator-license validation remain.
- **CAG Craig-Moffat**, **E24 Whiteriver**, **LXV Lake County**, **S52 Methow Valley**, **T50 Menard**, **T69 Sinton** need aircraft-specific altitude, load, width, access or usable landing distances. Menard's RW15 displaced threshold and Sinton's narrow 55ft runway are not the same as a standard 1,200m usable paved runway for all directions.
- **HVE Hanksville** lacks assured ground fuel; **MAW Malden** lists Jet A by prior callout. Neither fuel issue automatically means the runway is closed, but real operational logistics remain outstanding.

## All 26 independently saved records

| FAA | Immutable key | Review subtype | Result | Airport-specific finding | Next required validation | Source |
|---|---|---|---|---|---|---|
| 06A | `OURAIRPORTS:18322` | DATED_NOTAM_RECHECK | Retained hold | Moton Field FAA October airport remarks report both runway PAPIs unserviceable and wildlife. Approach-aid outages are not automatic pavement/runway closure, but current NOTAM/landing configuration unknown. | Check current individual PAPI NOTAM, wildlife, published LDA, safe approaches and field owner and aircraft suitability. | [Source](https://www.airnav.com/airport/06A) |
| 74V | `OURAIRPORTS:19031` | DATED_NOTAM_RECHECK | Retained hold | Roosevelt Municipal Utah has ~6501ft paved runway and FAA-derived RW07 PAPI outage. Outage affects visual guidance rather than proving the whole runway shut. | Verify exact RW07 PAPI repair/NOTAM dates, remaining instrument/visual procedures, aircraft loading and owner commercial permission. | [Source](https://www.airnav.com/airport/74V) |
| ADT | `OURAIRPORTS:19238` | QUALIFYING_PRIMARY_PAVED_RUNWAY_DISTINCT | Next eligibility check | Atwood-Rawlins County Kansas airport directory records a 5000ft paved main distinct from 2400ft turf. Nonqualifying turf is not a main paved runway closure. | Check latest paved LDA/weight, winter use, owner commercial rules and aircraft fuel/endurance; Jet A not assumed. | [Source](https://aviation.ks.gov/files/KDOT_Airport_Directory_2025-2026.pdf) |
| CAD | `OURAIRPORTS:19458` | QUALIFYING_PRIMARY_PAVED_RUNWAY_DISTINCT | Next eligibility check | Cadillac Wexford County Michigan has a separate 5001x100ft paved main runway with Jet A/avgas, while the 1986ft turf secondary fails the Airlinerra threshold. | Validate main paved directional LDA/weight, winter snow clearing, airport owner use and aircraft/operator rules. | [Source](https://www.flightaware.com/resources/airport/KCAD) |
| CAG | `OURAIRPORTS:19459` | RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK | Retained hold | Craig Moffat Colorado has ~5606ft pavement at high elevation and FAA cold-temperature/wildlife notices; these affect performance and safe dispatch, but cannot be inferred to close the runway. | Evaluate actual elevation/density-altitude climb and landing, obstacles/wildlife/winter, structural runway rating and approved operator. | [Source](https://www.airnav.com/airport/KCAG) |
| DNS | `OURAIRPORTS:19646` | QUALIFYING_PRIMARY_PAVED_RUNWAY_DISTINCT | Next eligibility check | Iowa DOT publishes Denison 12/30 5000x75ft concrete, separate 18/36 2000ft turf, and Jet A/avgas. Short turf does not disqualify the main runway. | Use only concrete 12/30 for physical screening; confirm usable LDA/weight and city aircraft/commercial rules. | [Source](https://opmapps.iowadot.gov/aviation/airports/dns) |
| E24 | `OURAIRPORTS:19690` | RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK | Retained hold | Whiteriver White Mountain Apache tribal airport has east ramp closed and multiple PAPI/REIL lights out as of Oct2026; west access, RW19 displaced threshold and 5153ft elevation require checking. A ramp closure is not a runway closure. | Confirm live lighting and ramp NOTAM, usable RW19 LDA, tribal commercial access and high-altitude airplane performance. | [Source](https://www.airnav.com/airport/E24) |
| HVE | `OURAIRPORTS:20098` | FUEL_OR_FBO_HANDLING_RECHECK | Retained hold | Hanksville Utah remote unattended airport uses pilot lights/AWOS; FAA October airport data list no on-site fuel. Lack of fuel is a significant logistics limitation but not a paved runway closure. | Verify owner emergency support, reliable alternate fueling, terrain/winds, runway bearing and current lawful air taxi rights. | [Source](https://www.airnav.com/airport/KHVE) |
| HYR | `OURAIRPORTS:20108` | QUALIFYING_PRIMARY_PAVED_RUNWAY_DISTINCT | Next eligibility check | Sawyer County Wisconsin operates an excellent-quality 5003x100ft paved main and distinct 1088ft turf strip; nonqualifying turf should not close qualifying paved operations. | Check primary runway actual LDA, snow/FICON, aircraft wheel loads, FBO and owner route permission. | [Source](https://www.iflightplanner.com/Airports/KHYR) |
| I40 | `OURAIRPORTS:20130` | DATED_NOTAM_RECHECK | Retained hold | Richard Downing Airport Coshocton OH October FAA-derived remark cites RW04 PAPI outage; do not infer a full closure or transfer airport identity to similarly coded West Virginia location. | Verify live RW04 PAPI notice and alternative approach, 5000ft runway LDA/load and Coshocton municipal operator rules. | [Source](https://www.coshoctoncountyairport.com/info.htm) |
| K24 | `OURAIRPORTS:20245` | DATED_NOTAM_RECHECK | Retained hold | Russell County Kentucky 5010ft-class paved runway has prior FAA-derived RW17 PAPI out-of-service notice; current effective dates unverified. Physical runway not necessarily closed. | Confirm live RW17 PAPI repair/NOTAM and type-specific approaches, usable landing distance, structural capacity and county permissions. | [Source](https://www.iflightplanner.com/Airports/K24) |
| L08 | `OURAIRPORTS:20284` | DATED_NOTAM_RECHECK | Retained hold | Borrego Valley CA issued October aeronautical notice for aerobatic box Oct19-Oct25 at 01:02 UTC, plus independent skydiving and ramp wingspan. Date scoped area use does not mean permanent runway closure. | Check FAA notice at/after 2026-10-25 01:02 UTC and separate jump activity, ramp constraints, aircraft performance and San Diego County approval. | [Source](https://www.iflightplanner.com/Airports/L08) |
| LWV | `OURAIRPORTS:20394` | QUALIFYING_PRIMARY_PAVED_RUNWAY_DISTINCT | Next eligibility check | Lawrenceville-Vincennes Illinois has two paved 5198ft-class runways and a separate ultralight turf runway, which is not a candidate for paved commercial runway admission. | Verify independently each paved runway directional LDA/load, ultralight traffic coordination and lawful airport paid-use rules. | [Source](https://www.airnav.com/airport/LWV) |
| LXV | `OURAIRPORTS:20398` | RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK | Retained hold | Leadville Lake County Colorado at 9934ft MSL has an operational main pavement after 2020 rehabilitation but unusually severe hot/high performance requirements, loose aggregate in old taxi/ramp segments and seasonal afterhours PPR. | Evaluate specific aircraft climb, takeoff, engine-out and landing performance at extreme elevation and current taxi path/owner charter restrictions. | [Source](https://www.lakecountyco.gov/285/Airport) |
| MAW | `OURAIRPORTS:20473` | FUEL_OR_FBO_HANDLING_RECHECK | Retained hold | Malden Missouri airport-specific aviation services list Jet A by advance call; prior-notice fueling is a provisioning issue, not automatic airport closure. | Confirm actual Jet A callout duration, hours/availability, selected aircraft performance/runway strength, city permissions and operator certificate. | [Source](https://airnav.com/airport/maw) |
| MFV | `OURAIRPORTS:20497` | DATED_NOTAM_RECHECK | Retained hold | Accomack County Virginia source references instrument-approach outages in October 2026; validity and alternate procedures are uncertain. This is a procedure availability question, not proof that the paved airport closed. | Check live IAP NOTAM and effective IFR/VFR approaches, current runway distance/load, county use rules and actual charter/cargo permissions. | [Source](https://doav.virginia.gov/airport-directory/) |
| OLU | `OURAIRPORTS:3750` | QUALIFYING_PRIMARY_PAVED_RUNWAY_DISTINCT | Next eligibility check | Columbus Municipal Nebraska city records a primary 6800x100ft concrete runway and a separate turf crosswind; turf operational limits do not close the qualifying paved runway. | Confirm currently published directional LDA, airplane gear loading, ATC/snow support and city commercial permissions before gameplay. | [Source](https://www.columbusne.us/280/Airport-Information) |
| OTG | `OURAIRPORTS:20769` | DATED_NOTAM_RECHECK | Retained hold | Worthington Minnesota source reports RW29 ILS outage through Dec30 2026 and LOM decommissioned; IFR ILS unavailability is not whole airport runway closure, and RNAV procedures need verification. | Recheck FAA Dec30 ILS notice and lawful alternative approach/procedures, owner paid-use and type-specific runway capacity. | [Source](https://www.iflightplanner.com/Airports/KOTG) |
| P13 | `OURAIRPORTS:20796` | DATED_NOTAM_RECHECK | Retained hold | San Carlos Apache Arizona tribal field has 100LL outage until Oct31 and RW09/27 PAPI/REIL plus AWOS notices reported into Apr2027; no proof primary runway itself is closed, but owner and approach aids are material. | Check active fuel, lighting and weather NOTAM with tribal airport owner; obtain commercial-use permission and airplane landing performance. | [Source](https://www.iflightplanner.com/Airports/P13) |
| PYP | `OURAIRPORTS:43022` | DATED_NOTAM_RECHECK | Retained hold | Centre-Piedmont Cherokee County Alabama Oct24 2026 aerobatic activity NOTAM was specifically dated 14:00-23:00Z and ended before Oct25 review; separate right-traffic and other activity may remain. Expired event does not confirm all current NOTAMs are clear. | Verify newer FAA aerobatic/parachute NOTAM and published pattern at intended service date, owner charter rights and aircraft loading. | [Source](https://www.iflightplanner.com/Airports/KPYP) |
| S33 | `OURAIRPORTS:21001` | DATED_NOTAM_RECHECK | Retained hold | Madras Oregon services advertise charter flights, while airport FAA procedure NOTAMs require time-specific checking; a charter lead alone does not establish operating carrier certificate nor runway closure. | Verify current active approach/airspace NOTAM, FAA Part135 operator/company, runway aircraft loading and owner authorization. | [Source](https://www.iflightplanner.com/Airports/S33) |
| S52 | `OURAIRPORTS:21011` | RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK | Retained hold | Methow Valley State Washington is open generally but WSDOT warns winter plowing is limited and state airports primarily serve emergency uses; no regular commercial rights or year-round dispatch availability established. | Confirm Washington DOT owner approval for routine paid service, winter NOTAM/clearing, aircraft runway capacity and reliable ground support. | [Source](https://wsdot.wa.gov/travel/aviation/airports-list/methow-valley-state) |
| SUA | `OURAIRPORTS:21115` | NONBINDING_OR_PARKING_ONLY_POLICY | Next eligibility check | Martin County government confirms Witham Field is public-use and its 23:00-07:00 curfew is VOLUNTARY, not a hard airport closure, with documented 07:00-22:00 tower hours and separate emergency exemptions. | Respect voluntary noise guidance, confirm tower/ATC and any binding restrictions, published LDA/loads, owner and actual licensed charter operating scope. | [Source](https://www.martin.fl.us/pilot-information) |
| T50 | `OURAIRPORTS:21155` | RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK | Retained hold | Menard County Texas fair 4100x60ft asphalt has RW15 threshold displaced 480ft, reducing potential RW15 landing length to around 3620ft (<1200m), with PAPI/marking and 12500lb wheel rating concerns. Opposite direction must be independently verified. | Get current FAA published RW15/RW33 declared LDA (rather than assume physical 4100ft), marking repairs and gear load; county commercial approval. | [Source](https://www.airnav.com/airport/T50) |
| T69 | `OURAIRPORTS:21163` | RUNWAY_AIRCRAFT_OR_ACCESS_RECHECK | Retained hold | Sinton Texas fair 4323x55ft asphalt rated 8000lb single-wheel, with 250ft/400ft displaced thresholds; secondary turf 03/21 closed indefinitely. Both paved landing usable lengths need actual declared LDA and aircraft width/weight check. | Verify current official 14/32 LDA each direction, narrow width and 8000lb single-wheel bearing; do not substitute closed turf; obtain operator right. | [Source](https://www.airnav.com/airport/T69) |
| VSF | `OURAIRPORTS:21336` | DATED_NOTAM_RECHECK | Retained hold | Hartness State Springfield Vermont 2026 source reports RW05 REIL outage to Oct31 and grass cutting notices for runway vicinities; lighting and grasswork are not proof full paved runway closed. | Check Oct31 REIL outage expiry against current FAA NOTAM, active paved directional distances and Vermont owner commercial policies. | [Source](https://www.airnav.com/airport/VSF) |

## Current Phase 3 selection snapshot (includes other workstreams)

| Selection status | Airports |
|---|---:|
| `PRELIMINARY_SHORTLIST` | 1013 |
| `OPERATIONAL_CONSTRAINT_HOLD` | 786 |
| `IDENTITY_RECONCILED_NEXT_ELIGIBILITY` | 74 |
| `CONSTRAINT_SCOPE_CONFIRMED_NEXT_ELIGIBILITY` | 47 |
| `PROVISIONAL_EXCLUSION_REVIEW` | 8 |
| `ALTERNATE_RUNWAY_VERIFIED_NEXT_ELIGIBILITY` | 1 |
| **Total** | **1,929** |

All expansion approvals, airport world activations and new game categories remain **zero**. The original 3,140 airports remain unchanged.

## Next 20 unreviewed operational records in the snapshot

Requery Supabase at next execution to avoid double-reviewing records modified by other batches.

| FAA | State | Immutable key | Existing issue |
|---|---|---|---|
| HCR | UT | `OURAIRPORTS:18657` | LANDING_FEES_AIRPORT_MINIMUM_STANDARDS |
| AEJ | CO | `OURAIRPORTS:19243` | HIGH_ALTITUDE_BUENA_VISTA |
| AFO | WY | `OURAIRPORTS:19249` | WYOMING_HIGH_ALTITUDE_AND_PLANNING_TIER |
| ANK | CO | `OURAIRPORTS:19283` | SALIDA_CHARTER_FREIGHT_HIGH_ALTITUDE |
| AXX | NM | `OURAIRPORTS:19340` | 8380FT_MOUNTAIN_DENSITY_ALTITUDE |
| BCE | UT | `OURAIRPORTS:19357` | BRYCE_SMALL_PROP_HIGH_ALTITUDE |
| BPI | WY | `OURAIRPORTS:19401` | 6990FT_HIGH_ELEVATION_CHARTER_SUPPORT |
| C08 | CO | `OURAIRPORTS:19435` | 8290FT_MOUNTAIN_55FT_RUNWAY |
| DIJ | ID | `OURAIRPORTS:19629` | DRIGGS_MOUNTAIN_CHARTER |
| E91 | AZ | `OURAIRPORTS:19711` | NAVAJO_MANAGED_AIRPORT_PERMISSION |
| EKS | MT | `OURAIRPORTS:19747` | MONTANA_MOUNTAIN_WINTER_CONSTRAINTS |
| EMM | WY | `OURAIRPORTS:19755` | HIGH_ALTITUDE_BUSINESS_AIRPORT |
| MHV | CA | `OURAIRPORTS:20507` | SPACEPORT_MRO_FLIGHT_OPERATION_DIVIDE |
| MZJ | AZ | `OURAIRPORTS:20594` | AIRCRAFT_STORAGE_NOT_AIRLINE |
| PNE | PA | `OURAIRPORTS:20850` | TWO_RUNWAYS_DIFFERENT_CAPACITY |
| RIL | CO | `OURAIRPORTS:20931` | FEES_AND_GA_HELICOPTER_AIRCRAFT_FIT |
| SAA | WY | `OURAIRPORTS:21031` | WIND_SHEAR_WILDLIFE |
| SIY | CA | `OURAIRPORTS:21072` | USFS_FIRE_TANKER_SEASON |
| TYL | AZ | `OURAIRPORTS:21239` | 12500LB_SINGLE_WHEEL |
| X60 | FL | `OURAIRPORTS:21407` | RW32_DISPLACED_APPROACH |

## Rules preserved

Airlinerra uses exactly six possible airport classifications: **Local, Regional, Medium, Large, Major Hub, Mega Hub**. None was assigned by this research. The game does not require an existing real scheduled airline to support future player-created routes; it does require actual airport runway, owner, load, approach and aircraft restrictions to be verified before any explicitly approved integration.

*Research audit only; not live FAA flight clearance or gameplay authorization.*
