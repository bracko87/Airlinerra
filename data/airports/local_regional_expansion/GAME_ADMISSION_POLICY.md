# Airlinerra — strict game-admission gate for new Local/Regional airports

Date: 23 October 2026. Owner-directed policy, **not a modification of the technical runway register**.

**Rule:** An airport does not enter Airlinerras playable commercial roster merely because the source dataset says it has a runway, that its airport name sounds civilian, or that a fictional game identifier can be generated.

The `data/airports/airport_register.csv` technical master and original 3,140-airport shortlist remain research snapshots. The 3,906 Local/Regional second-pass records stay in the research pool, but **all 3,906 start blocked for gameplay**, unless individually verified and subsequently approved.

## Required evidence before approving one of these 3,906 airports

1. **Facility identity/location:** Ground the exact facility in named authoritative or operator materials, with geographic coordinates, distinguish similarly named nearby airfields, and verify that it currently exists. A source name/coordinate alone is insufficient for final admission.
2. **Paved runway:** Independently substantiate at least one currently usable, non-closed runway **at least 1,200 metres long**, with surface explicitly **asphalt or concrete** (including explicit asphalt-concrete). Verify length, actual surface, runway ends/designators and operational restrictions; reject grass, dirt, earth, gravel, compacted laterite, and merely ambiguous `paved`, `hard` or `BITUM` without strong evidence.
3. **Civilian/commercial accessibility:** Establish that the field is not exclusively military or otherwise barred and that the intended civilian **passenger/charter/cargo operations are permitted**. Public general-aviation access alone is not automatic commercial-airline authorization. Private fields additionally need documented access and intended commercial permissions; a historically military runway may be civilian-usable now. Mark unknown `HOLD`, never guess.
4. **Airport and aircraft suitability:** Before scheduling, review runway width, declared lengths/obstacles, airport/aircraft compatibility, permitted operating conditions, capacity and relevant infrastructure; do not assume that a runway of 1,200 m permits every ATR, turboprop or commercial flight.
5. **Identifiers:** Preserve source-reported GPS/ICAO/IATA blanks. Search reliable authorities for actual published codes. When truly unavailable, synthetic values may be supplied **only in separate, explicitly labelled game-only fields** after a collision check. Do not invent or label real ICAO/IATA allocations. Missing codes are not in themselves a reason to reject a verified usable airport.
6. **Six tiers, traffic model:** Retain exactly Local, Regional, Medium, Large, Major Hub and Mega Hub. Review any provisional tier against validated runway data; very low-volume tourist airports can have 1–2 *hypothetical* flights per week, not automatic demand or real reported statistics. Traffic frequency and game hourly capacity are different concepts.
7. **Approval:** All earlier checks and explicit owner final review must pass before switching to `APPROVED_FOR_GAME` or deploying in Supabase. No technical/research record is deleted to implement a gameplay exclusion.

## Verification ledger and initial three cases

- `game_admission_evidence.csv`: researched evidence and source links for Airglades (18593), Belterra BR-2772 (37074), and Casey (39730).
- `game_admission_status_3906.csv`: an independent per-airport **game-admission gate**, which does not change the 3,906-row candidate technical screen.
- Airglades: 2026 Florida airport directory records runway 13/31, **5,902 ft / ~1,799 m asphalt**; FAA local identifier **2IS**, not verified ICAO/IATA. Public-use evidence supports civilian access, but commercial eligibility still requires checking. Source provisional Regional based on 1,813.6m must be reviewed against more current 1,799m figure (possible Local).
- Belterra: **do not conflate** BR-2772 (source airport candidate, -2.668108, -54.895660, source `2000m ASP`) with separate SWPX (-2.672198, -54.951510, officially 950m GRVL). Compacted-laterite/earth descriptions conflict with `BR-2772` asphalt assertion. Place candidate **on hold** until its actual runway surface, location/identity and permissions are resolved; do not treat SWPX as evidence about BR-2772.
- Casey: operator confirms private recreational/tourism use at local code CSQ4, 5,411ft runway, **no regular runway maintenance and no night landings**; source reports concrete pavement. Commercial permissions and independent safety review remain outstanding. Low-traffic tourism is **possible future game design**, not approval now.

### Initial status
- `HOLD_INDEPENDENT_VERIFICATION`: 3,903.
- `HOLD_COMMERCIAL_PERMISSION`: 1 (Airglades).
- `HOLD_IDENTITY_AND_PAVEMENT_CONFLICT`: 1 (Belterra candidate).
- `HOLD_PRIVATE_COMMERCIAL_PERMISSION`: 1 (Casey).
- **Approved for playable commercial flights: zero.**

**Never import `candidates_local_regional.csv` directly as playable airports**. Use the separate review gate and final, evidence-based owner approvals. The 413 military/private review holds and the original 3,140 are not being silently reclassified by this document.
