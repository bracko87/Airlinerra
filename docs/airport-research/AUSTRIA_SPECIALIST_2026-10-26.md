# Airlinerra airport expansion — Austria specialist batch 01
**Audit date:** 2026-10-26  
**Scope:** Three Austrian source-registry airports outside the original World 1 startup catalog; source-research only.  
**Central research batch marker:** `AT_SPECIALIST_01_2026_10_26`  
**Supabase project:** Airlinerra / private schema `airlinerra`, table `airport_evidence`.

## Database counts confirmed
- Austrian entries in `airport_registry`: 9.
- Austrian airports in the initial World 1 game catalog: 6.
- Austrian registry entries outside World 1 reviewed here: 3.
- Entire World 1 catalog remains **3,140**, unchanged after this research batch.

## Decision matrix
| Source key | ICAO | Airport | Current physical-runway evidence | Runway-only collection | Airline gameplay |
|---|---|---|---|---|---|
| `OURAIRPORTS:29484` | LOXT | Brumowski Air Base / Tulln | AIP 2026-10-02 edition reports RWY 08L/26R **1,400 x 45 m concrete panels**. Registry reports 1,399.9 m **asphalt**; preserve this source difference for reconciliation. | Physical >=1,200 m asphalt/concrete pass | NOT APPROVED; military commercial-use restriction |
| `OURAIRPORTS:4436` | LOXZ | Hinterstoisser Air Base / Zeltweg | Zeltweg published runway information reports RWY 08R/26L **2,750 x 60 m asphalt**. Registry 2,749.9 m asphalt. | Physical >=1,200 m asphalt/concrete pass | NOT APPROVED; military commercial-use restriction |
| `OURAIRPORTS:4429` | LOLW | Wels Airfield | Operator reports public civilian airfield, RWY 08L/26R **1,390 x 30 m asphalt**. Registry 1,389.9 m asphalt. | Physical >=1,200 m asphalt/concrete pass | NOT APPROVED; commercial permission, declared distances, operations and aircraft-level suitability unverified |

**Important separation of gates:** All three satisfy the present airport-collection physical runway criterion. A military-use restriction must not be misrepresented as a failed physical runway screen. Conversely, physical runway eligibility does not imply playable-airport admission, civilian commercial operations, aircraft dispatch permission, or a final Airlinerra category.

## Evidence links
1. LOXT current AIP edition, page LOXT AD 2 runway physical data: https://eaip.austrocontrol.at/lo/261002/PART_3/AD_2/MIL/AD_2_LOXT/LO_AD_2_LOXT_en.pdf
2. Austria AIP AD 1.1 archive, military-field civil use and prohibition of commercial aviation (applies to LOXT and LOXZ; current issue must be rechecked before later operational admission): https://eaip.austrocontrol.at/lo/261002/PART_3/AD_1/LO_AD_1_1_en.pdf
3. Zeltweg published operational and runway data; site warns official AIP and NOTAM supersede informal information: https://www.loxz.at/?page_id=68
4. Wels aerodrome operator, runway dimensions/public civil operations: https://www.wmw.at/en/ and https://www.wmw.at/en/airfield-wels-lolw/
5. Current Austrian AIP index (as checked 2026-10-26, current edition from 2026-10-02): https://eaip.austrocontrol.at/

## Persisted research evidence
The `airlinerra.airport_evidence` table now contains five additional, separately typed records, all tagged `AT_SPECIALIST_01_2026_10_26`:
- 2092 LOXT physical AIP length/surface reconciliation;
- 2093 LOXT military commercial-use restriction;
- 2094 LOXZ physical operator runway evidence;
- 2095 LOXZ military commercial-use restriction;
- 2096 LOLW operator physical runway and public-civil-field evidence.

The core `airport_registry` records remain untouched, including LOXT's historically recorded surface pending controlled source reconciliation. There has been no World 1 catalog insert, no approval, no change to `airport_world_activation`, and no six-category finalization.

## Next checks
- **LOXT:** Confirm the current official AIP surface definition and prepare a provenance-preserving correction proposal for the registry; retain the 1,400 m concrete data as independently verified research.
- **LOXZ:** Revalidate latest official AIP and relevant NOTAMs, preserving commercial aviation restriction separately from physical runway suitability.
- **LOLW:** Confirm latest official aeronautical declared distances, availability of commercial charter/cargo operations, operator permissions and appropriate aircraft capability. The 1,390 m paved physical runway alone is not sufficient for airline-game admission.
- **Owner gate:** Approve any later World 1 additions and any final classification separately, using the six categories: Local, Regional, Medium, Large, Major Hub, Mega Hub.

**Research stage outcome:** Initial Austria batch evidence recorded; aviation permissions and gameplay admission remain pending. Germany's three specialist cases were not changed by this batch.

---

## Batch 02 — current Austrian AIP adjudication (2026-10-26)

**Status:** Source validation and private research database decisions completed. The effective AIP edition is **2026-10-02 through 2026-10-29**. This does **not** constitute current NOTAM clearance, an airline operating permit, a final Airlinerra six-category decision, or a game release.

**Central research marker:** `AT_SPECIALIST_02_2026_10_26`.

### Finalized research facts and access-review outcomes

| ICAO | Official-source runway detail | Access and traffic rule | Central access-review decision | Gameplay |
|---|---|---|---|---|
| LOXT | AIP LOXT AD 2.12 confirms RWY 08L/26R 1,400 x 45m **concrete panels**; raw registry still lists 1,399.9m **ASPHALT**. | AIP AD 1.1 requires military permission for civil use and prohibits commercial aviation. | Physical/identity verified; runway surface source correction documented but raw source preserved; commercial permission `PROHIBITED_BY_AIP`. | `NOT_APPROVED` |
| LOXZ | AIP LOXZ AD 2.12 confirms RWY 08R/26L 2,750 x 60m **asphalt**, composite construction. | Same AIP AD 1.1 military restriction, commercial aviation prohibited. | Physical/identity verified; commercial permission `PROHIBITED_BY_AIP`. | `NOT_APPROVED` |
| LOLW | AIP LOLW AD 2.12/13 publishes RWY 08L/26R 1,390 x 30m **Bitumen**; operator explicitly calls it **asphalt**. | AIP AD 1.3 lists Wels **VFR, non-scheduled and private (NS-P)**, without scheduled traffic (S). AIP AD 1.1 says Wels is a **public civil airfield** subject to aerodrome user conditions. | Airport identity, paved runway and civilian access verified. Airline charter/cargo commercial permissions remain `UNVERIFIED`; scheduled traffic is not listed in current AIP. | `NOT_APPROVED` |

These are THREE valid **physical-runway collection** cases, not three additional playable airline airports. The two military fields are barred from commercial aviation on the verified AIP edition, not excluded because of inadequate runway lengths.

### Wels specific operating limits

| Runway direction | TORA | TODA | ASDA | LDA |
|---|---:|---:|---:|---:|
| 08L | 1,319 m | 1,390 m | 1,390 m | 1,291 m |
| 26R | 1,291 m | 1,390 m | 1,390 m | 1,319 m |

The Wels AIP specifies runway load capacity **SIWL 11,000 kg**; SIWL is *single isolated wheel load*, not a blanket maximum aircraft takeoff weight. Aircraft/gear loading, performance, operator permissions, daylight/VFR/weather, published hours and updated NOTAMs must be separately checked before flights are simulated. Its published operator user conditions (dated January 2019) describe a public general-aviation civil airfield, actual measured runway length **1,384.33m (rounded 1,390m)**, asphalt surface and 11,000kg SIWL. These rules do not themselves prove charter, cargo or scheduled-airline approval.

### Source archive (verified in current AIP)

- AIP Austria edition index, October 2 to October 29, 2026: https://eaip.austrocontrol.at/lo/261002/index.htm
- AIP AD 1.1 military commercial prohibition and Wels public-civilian-use conditions: https://eaip.austrocontrol.at/lo/261002/PART_3/AD_1/LO_AD_1_1_en.pdf
- AIP AD 1.3 airport traffic types: https://eaip.austrocontrol.at/lo/261002/PART_3/AD_1/LO_AD_1_3_en.pdf
- AIP LOXT AD 2 runway: https://eaip.austrocontrol.at/lo/261002/PART_3/AD_2/MIL/AD_2_LOXT/LO_AD_2_LOXT_en.pdf
- AIP LOXZ AD 2 runway: https://eaip.austrocontrol.at/lo/261002/PART_3/AD_2/MIL/AD_2_LOXZ/LO_AD_2_LOXZ_en.pdf
- AIP LOLW AD 2 runway/declared distances: https://eaip.austrocontrol.at/lo/261002/PART_3/AD_2/SRY/AD_2_LOLW/LO_AD_2_LOLW_en.pdf
- Wels operator's aerodrome user conditions (Jan 2019): https://www.wmw.at/download/flugplatz/Zivilflugplatz-Benuetzungsbedingungen.pdf
- Wels operator site: https://www.wmw.at/en/

### Persisted private-database evidence and access audit

- Added **7** evidence records under batch `AT_SPECIALIST_02_2026_10_26` to `airlinerra.airport_evidence`: IDs 2097-2103. Together with Batch 01's 5 records, **12 evidence records** now support the 3 Austrian specialist cases.
- Added `airlinerra.airport_access_reviews` for LOXT and LOXZ with distinct verified runway eligibility and prohibitions on commercial use; updated LOLW's existing review to `VERIFIED` identity, runway and civilian access, but `UNVERIFIED` commercial permissions.
- Wrote three batch-scoped review events, IDs 6-8, to `airlinerra.airport_review_events`.
- No core `airport_registry` row was changed. Specifically, the raw LOXT surface remains `ASPHALT` and the authority-reported concrete surface is held separately, not silently overwritten.
- No changes to `airport_game_world1_catalog`, `airport_world_activation` or six-category finalized classifications. Retain the existing 3,140 World 1 airports and the German EDMB/EDXJ/EDCP holds.

### Remaining operational work

1. **LOXT:** If a source-aware physical registry canonicalization is later requested, reconcile the original OurAirports asphalt label against authoritative concrete AIP in a traceable override. No physical-collection rejection.
2. **LOXZ and LOXT:** Recheck latest AIP/NOTAM during later release windows; current AIP commercial prohibition means there is no reason to pursue an airline-game activation while that restriction remains.
3. **LOLW:** Obtain current aerodrome user conditions and *explicit operator/authority confirmation* whether commercial **non-scheduled passenger charter and cargo** services may use the airport, for which aircraft and circumstances. The AIP NS-P classification is a lead, **not authorization for any individual commercial carrier**. Scheduled service is not listed.
4. Reassess on **2026-10-29** when the next Austrian AIP effective edition begins. Neither the latest NOTAM package nor individual aircraft performance/ground-loading has been independently cleared by this batch.

**Research conclusion:** Austrian technical and AIP access triage finished; two military airline exclusions are source-grounded, one Wels commercial-review case remains open; zero new game admissions.
