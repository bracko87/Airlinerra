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
2. Austria AIP AD 1.1 archive, military-field civil use and prohibition of commercial aviation (applies to LOXT and LOXZ; current issue must be rechecked before later operational admission): https://eaip.austrocontrol.at/lo/251003/PART_3/AD_1/LO_AD_1_1_en.pdf
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
