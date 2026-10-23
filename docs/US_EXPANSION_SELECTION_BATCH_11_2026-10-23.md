# Airlinerra — US expansion airport selection, Batch 11 (2026-10-23)

Three FAA-matched airports source-checked against official municipal/county material. Findings are *airport-level* research, not final commercial/game approval.

| FAA ID | Airport | Findings | Official evidence |
|---|---|---|---|
| GVT | Greenville Municipal / Majors Field, Texas | City lists active corporate, medical, general aviation **and charter flight services**, with >8,000-ft runway; no scheduled airline service established. | https://www.greenvilletx.gov/1475/Airport |
| PIL | Port Isabel–Cameron County, Texas | County describes county-operated public general-aviation airport with contracted FBO. Charter or cargo-airline operations not established. | https://cameroncountytx.gov/wp-content/uploads/document_center/CC___MOST_IMPROVED_AIRPORT_APPLICATION_.pdf |
| 0E0 | Moriarty Municipal, New Mexico | City confirms asphalt 7,700-ft runway, field elevation 6,199 ft, single-wheel 30,000 lb / dual-wheel 45,000 lb runway capacity, fuel, maintenance and glider rides; scheduled passenger and Part 135 charter not established. | https://www.moriartynm.gov/city-venues/moriarty-airport |

Three existing private `airlinerra.airport_commercial_verification` rows updated with dated source research and timestamps; all remain `NOT_APPROVED`. Existing 1,929 public-use FAA-matched candidates now have 74 individual review timestamps (1,855 still pending). Research timestamps do not mean approved for game access; the original 3,140 and all six airport categories remain unchanged.

Next priority: continue source-backed selection in batches; do not infer airline operations solely from long runways, FBO presence or public-use status.
