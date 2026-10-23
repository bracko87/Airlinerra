# Airlinerra — initial 3,140-airport startup shortlist (23 October 2026)

This is a **pre-production commercial candidate dataset**, built strictly from all 3,140 **real** runway-screened master airports whose pinned OurAirports `scheduled_service` flag equals `yes`. This is **not** a worldwide count of commercial-eligible airports, and does **not** verify operating permits, civilian airline eligibility, aircraft compatibility, access restrictions, cargo permissions, or live traffic. The other 5,012 real airports and fictional LYAL stay in the original 8,153-airport master and **were not reclassified or deleted**.

## Files

- [airports_3140.csv](airports_3140.csv): one source-ID-joined record per airport, with full source country and region names, coordinates, city as reported, reported GPS/ICAO/IATA/local identifiers and their source status, airport type, master-approved qualifying runway, a runway summary, positive civilian-access evidence where already linked, and explicit non-operational flags.
- [runways_3140.csv](runways_3140.csv): all 4,738 corresponding **OurAirports runway records** (including closed runways) with runway end identifiers, source length/width in feet and metres, surface, lighting, closure, and conservative asphalt/concrete >=1,200 m match. This is a source inventory, **not** an aeronautical-surveyed current runway chart.
- [exceptions_3140.csv](exceptions_3140.csv): an auditable list of source-missing or conflicting fields. A missing GPS/ICAO/IATA allocation does not prove that an airport is military-only, closed, or commercially ineligible; do not invent codes.
- [summary.json](summary.json): source pins and aggregate counts.
- [additional_official_runway_evidence.csv](additional_official_runway_evidence.csv): Iowa DOT confirmation of KCID's two asphalt/concrete runways and Brazil DECEA official AIP confirmation of SBEG's asphalt runway, resolving two nonstandard raw source surface-label cases. Earlier official corrections remain in `data/airports/runway_surface_overrides.csv`.

## Provenance

- [OurAirports source commit](https://github.com/davidmegginson/ourairports-data/tree/11e4de2834aff6ab54c1f8fc89b8679ea3d08418) is pinned, matching the existing identity refresh. `runways.csv` blob SHA: `69dc1264b05591400baf60b713af9acc41de6ea7`. Country and region names come from the same source commit.
- The canonical master `data/airports/airport_register.csv` is the authority for **the one previously qualified runway**. Its original material and length are retained even when the raw runway snapshot is older/different. Individual runway details in this startup dataset are raw source observations, not a replacement for specific official AIP overrides.
- Full civilian-operator evidence remains in `data/airports/identity/military_use_civilian_evidence.csv`. Fourteen cases in the worldwide military-name review have positive civilian evidence, of which **12 are in this 3,140 shortlist**. Remaining military-name matches require review; none are automatically excluded.
- Original identifiers remain source-reported; no 100% independent ICAO/IATA validation is claimed. Stable internal key is always `source_airport_id`.

## Physical infrastructure and six *provisional* game categories

Categories are deliberately separated from the existing canonical master `assigned_category`, which remains blank for every real airport. The present **proposed** category is a deterministic *startup game model based on observed airport type and paved runway infrastructure*, **not a regulator/operator classification**:

| Source airport type | Rule | Proposed game category |
| --- | --- | --- |
| small_airport | master runway <1,800 m AND fewer than two open qualifying paved runways | Local |
| small_airport | master runway >=1,800 m OR at least two open qualifying paved runways | Regional |
| medium_airport | fewer than two open paved runways >=2,400 m, or master qualifying runway <2,500 m | Medium |
| medium_airport | at least two open paved runways >=2,400 m AND master qualifying runway >=2,500 m | Large |
| large_airport | fewer than two open paved runways >=2,400 m | Large |
| large_airport | two open paved runways >=2,400 m | Major Hub |
| large_airport | three or more open paved runways >=2,400 m | Mega Hub |
| heliport (source anomaly) | requires correction; model minimum only | Local |

**These are technical game-design *proposals*, not final authorized tiers.** The type `heliport` appears for one scheduled-service airport (Narsarsuaq) despite the runway-screen master; this specific record is flagged rather than silently discarded.

**Game slot model** (`game_slots_per_hour_baseline`) assumes *aircraft movements per hour*, not stands, gates or issued arrival/departure slots: Local=6, Regional=10, Medium=16, Large=24, Major Hub=36, Mega Hub=50. These figures are **invented, explicitly labelled, reversible initial gameplay estimates** and **must not be represented as real-world slot limits or automatically deployed**. Real operational scheduling and capacity will be designed in a future game-engine phase. No final game capacity is approved by this file.

## What is populated and what remains source-unreported

| Field | Count present in shortlist | Gap |
| --- | ---: | ---: |
| name, source ID, country code/name, region, GPS position, master runway length/material | 3,140 | 0 |
| municipality | 3,088 | 52 |
| source GPS code | 3,133 | 7 |
| source ICAO code | 3,125 | 15 |
| source IATA code | 3,111 | 29 |
| source-linked runway count, open/closed detail, length and surface | 3,140 | 0 source-runway lists absent |
| at least one open runway width reported | 3,053 | 87 |
| at least one raw-source open 1,200m asphalt/concrete runway | 3,132 | 8 source/master discrepancies |
| independently approved civilian commercial operations | **not established worldwide** | 3,140 cannot be treated as approved |

The eight raw runway/qualified-master disagreements have different source-reported surface labels. **Six** correspond to pre-existing individual runway surface override records, and the remaining **two** (KCID and SBEG) now have dated official source cross-references in `additional_official_runway_evidence.csv`. The raw-source discrepancy flags are intentionally retained for source transparency; they do **not** mean that all eight airports have invalid runways. Individual physical runway data should be read with these evidence overlays rather than blindly replacing official values with unparsed OurAirports labels. The source can legitimately omit assigned codes, municipality or runway width; do not falsely mark those values as *verified zero*. No production import, Supabase mutation, playable activation, or route simulation is performed.

## Validation and future refresh

`python -m unittest discover -s tests -p test_airport_startup_3140.py`

The tests confirm source ID joins and immutable master fields, data counts, six proposed tier values, the explicitly synthetic slot basis, military/positive-civilian overlap, and no real-world gameplay activation. When updating sources, rebuild and verify together, never import mixed snapshot versions or wipe the original 8,153-row master. The second-pass examination of the other **5,012** real airports for additional cargo and charter candidates is intentionally **outside this task**.


## Targeted field-completion pass — researched sidecar (23 October 2026)

[researched_field_enrichments_3140.csv](researched_field_enrichments_3140.csv) is a separate joinable research layer with **57 sourced entries**: 52 candidate served-city/municipality values for the 52 source blanks, and five officially reported physical runway widths. The original 3,140-airport source columns, all 4,738 individual source runway records, all 227 original exception records, and the 8,153-row master remain untouched.

- **Municipality:** 52 of the 52 source blanks now have an explicitly labelled candidate city/commune/served locality with an evidence URL. Most are straightforward airport-place pairings in aeronautical publications or airport operators' material. **Beloyarsky, Russia** has been cross-referenced against the airport operator business address. Broad name-based pairings should still receive specific locality review before claiming 100% authority-grade validation. For airports located outside the town served, the sidecar notes the distinction (e.g. King Island airport is in Loorana and serves Currie; Totegegie serves Rikitea in Gambier commune). The raw source's missing value is NOT overwritten.
- **Reported runway width:** VEAP Maa Mahamaya runway 16/34 = 30 m (India AIP 2026), RPSP Bohol-Panglao runway 03/21 = 45 m (CAAP summary), and YMTG Mount Gambier runway 18/36 = 30 m (Australian RDS 2026). Two additional 2026 AIP sources establish Kalaburagi VOGB runway 09/27 = 45 m and Muan RKJB runway 01/19 = 45 m. These external cross-references lower the *operational research queue* from 87 to **82**, not the raw OurAirports count of 87. Width values are runway-specific; do not blindly apply them to every runway at an airport. Consult the exact source edition before gameplay use.
- **Codes:** 7 missing source GPS, 15 ICAO and 29 IATA remain as **source NOT_REPORTED**, which is not synonymous with an officially unassigned code. Never manufacture or automatically copy one identifier type into another to fill a blank. Validate current official allocation and record genuinely *not assigned* separately.
- **Other flags:** 28 military-name civilian-use reviews, eight source surface disagreements and the Narsarsuaq source-type anomaly remain in the documented exception ledger; they are **not** numerically counted as additional missing municipality/code/width fields.

**Join rule:** select `researched_field_enrichments_3140.csv` rows by `source_airport_id` and `field`; treat `municipality` as a researched served-place candidate, and `runway_width_m` as the cited specific runway only. Do not replace source fields or conclude all airports are approved commercial airports. The regression test `test_external_research_overlay_preserves_pinned_fields` checks alignment and original-source immutability. GitHub Actions execution is still unverified.


## Game planning runway-width completion — averages explicitly authorized (23 October 2026)

To close the **game-design data gap** promptly, the owner authorized averages for the missing source runway widths instead of another airport-by-airport exact-width search. **No physical runway observations or regulator certificates have been invented or overwritten.**

- [game_runway_widths_3140.csv](game_runway_widths_3140.csv) provides one joinable **game-planning runway width** for each of the 3,140 startup airports: 3,053 from an open source-reported runway, five separately researched and evidence-linked widths, and 82 explicitly estimated widths. Each row has a `width_provenance`, source runway ID and length reference, and the usage restriction `SIMULATION_PLANNING_ONLY_NOT_REAL_WORLD_DISPATCH`.
- [estimated_runway_widths_3140.csv](estimated_runway_widths_3140.csv) is the **82-row estimated-only subset**, with the exact observed donor mean, count, length band, and strategy encoded in `estimate_method`. It exists independently of the pinned source runway inventory.
- **Average calculation:** use physical widths between 10 and 100 m reported for open, qualifying asphalt/concrete runways within the 3,140-airport source snapshot. Compare the target runway to the groups **1,200–1,799 m**, **1,800–2,399 m**, **2,400–2,999 m**, and **3,000 m or longer**. Use the arithmetic mean for its *country plus runway-length group* if there are at least three sample runways; otherwise use the *worldwide mean for that length group*. Round to the nearest 5 m and clamp to the 20–60 m game-design range. **72** estimates used country-length peers and **10** used worldwide-length peers. No searching for exact widths is required for startup game planning.
- **Provenance must be retained:** reported width `OURAIRPORTS_SOURCE_REPORTED`; official researched width `OFFICIAL_RESEARCHED`; average `GAME_ESTIMATE_AVERAGE`. Do not present estimated numbers as airport facts, official data, aircraft-certified takeoff/landing minima, or real operational restrictions. `game_runway_widths_3140.csv` picks one *representative* open runway per airport, not certified widths for all its individual runways.
- **Raw observations remain unchanged:** the original 87 OurAirports airports without open runway widths are still 87 *in the pinned source*; five have separate official references and the other 82 now have estimated *game* values. Source-exception records stay in the original ledger for traceability.
- **One source-reported outlier:** Nay Pyi Taw International Airport has a raw 152.4 m width in the pinned snapshot. This is source-reported, **not independently validated**. It remains traceable and requires particular caution if later developing performance checks; the new file is not clearance for real aircraft-performance calculations.
- **Identifier gaps are not numeric:** 7 GPS, 15 ICAO and 29 IATA source blanks remain. [missing_identifier_game_handling_3140.csv](missing_identifier_game_handling_3140.csv) explicitly documents all 51 unreported field instances and the stable `source_airport_id` game fallback. Never average, guess or generate fake official codes. These identifiers are optional *database attributes*, not substitutes for the internal airport ID.

**Tests:** `python -m unittest discover -s tests -p test_airport_startup_3140.py` now verifies complete coverage, donor averages, roundings, provenance, original-source immutability and official/estimated separation. The manual `.github/workflows/validate-airports.yml` includes this test in its next run. This startup sidecar does **not** activate airports or change any canonical master, gameplay category, slot allocation, or production data.


## One-file current-status export (23 October 2026)

[airports_3140_current_status.csv](airports_3140_current_status.csv) is the owner-friendly **3,140-row consolidated review table**, keyed by `source_airport_id`, combining the raw commercial shortlist, the municipality research overlay, the 3,140-row game-planning width table, and the original exceptional-review ledger. It covers 229 source countries/geographies.

Key column distinctions:
- `municipality_for_game` is sourced directly for 3,088 airports; 52 candidate localities are external research, marked by `municipality_provenance`. These are usable initial locality display values, not a claim every place matches a formally regulated municipality boundary.
- `game_reference_runway_width_m` is filled for 3,140 airports (3,053 source reported, 5 official researched, 82 game averages). `game_runway_width_provenance` makes the difference explicit; a single representative reference runway does not describe every runway at a multi-runway airport.
- `gps_code`, `icao_code`, and `iata_code` remain blank when unreported (7, 15, 29 missing fields respectively). **40 distinct airports** have at least one of these code gaps; four are missing all three. Airport source ID is the unique internal join key; blank codes must not be fabricated.
- `military_access_review` flags **28** airports needing separate positive civilian-operation evidence; `runway_source_discrepancy_review` flags eight raw-source inconsistencies with supporting override/correction records; `source_airport_type_review` flags Narsarsuaq's source heliport anomaly.
- `proposed_category` and `game_slots_per_hour_baseline` are **preliminary game-design values**, not certified airport categories or actual coordinated movement slots. `commercial_eligibility_status` remains non-approved across this entire shortlist; no production activation has taken place.

This is a review/export convenience file, **not a new operationally verified airport master**. The 8,153-row original master, 4,738 original source runway records and original exception history remain immutable.


## Owner-approved missing game code completion — 23 October 2026

The owner has explicitly authorized plausible **fictional, Airlinerra-only** values if a quick published-code check does not establish a missing GPS, ICAO or IATA source value. This **supersedes the prior ban on fictional values for game-display fields only**. It does **not** authorize adding synthetic identifiers to the source/reported code columns, claiming IATA/ICAO issuance, permitting physical operations, or using these codes for live ticketing or flight planning.

- [game_code_resolutions_3140.csv](game_code_resolutions_3140.csv) is the complete **51-row** exception-resolution ledger. Of the original source gaps (GPS 7, ICAO 15, IATA 29), **3** GPS game values reuse published government ICAO-style location indicators (VEAP, FAHS, SVSE); **4** ICAO game values match published secondary airport listings (UHSN, ULAS, UESK, UNIM) pending regulator-level confirmation; **44** values are synthetic identifiers labelled `FICTIONAL_GAME_ONLY`.
- [game_airport_codes_3140.csv](game_airport_codes_3140.csv) joins all three **effective game** identifier columns for each of the 3,140 airports, with a separate origin label for each code and a boolean `contains_fictional_code`. Exactly **40** airports required at least one resolution and **33** received at least one synthetic game-only identifier.
- [airports_3140_current_status.csv](airports_3140_current_status.csv) now includes the game code fields `game_gps_code`, `game_icao_code`, `game_iata_code` and matching `*_origin` metadata alongside the unchanged original source `gps_code`, `icao_code`, and `iata_code` columns. **All 3,140 rows have game code values in all three fields**. The original 51 source blanks still exist for evidence quality and future revisions.
- Fictional IATA-like codes use exactly three uppercase ASCII letters; ICAO-like and generated GPS identifiers use four uppercase ASCII letters. Synthetic values were screened for duplicates against the pinned **8,153-airport** identity register's reported matching identifier types and source identifiers, as well as against the 3,140-airport game code columns. This is a **game-local collision check**, not a worldwide IATA/ICAO namespace reservation. A synthetic code may coincide with an external authoritative future or existing assignment not in the pinned data; it is never sent to third-party ticketing or aeronautical services.
- GPS is not identical to ICAO/airport local ID by definition. When the published government reference is an ICAO-style indicator reused for the missing **game** GPS field, the ledger explicitly marks this as a code reuse, not a separately verified GPS allocation. Likewise, the four researched Russian ICAO labels are secondary-published rather than regulator-certified.

**Remaining operational review:** military-name civilian-access reviews (28), eight documented original runway-label discrepancies, Narsarsuaq airport-type anomaly, a source-width outlier, and actual commercial permissions/slot/terminal constraints remain separate from the now-full *game identifier* fields. Re-examine the two historical/operational-use candidates **Old Nabire Airport** and **Tabing Airport** before activating them as contemporary scheduled passenger airports; a pinned `scheduled_service=yes` record may be stale. All 3,140 entries remain pre-production candidates with provisional categories and slots.

The user intends to expand **Local** and **Regional** candidates later from the remaining real airport pool, preserving the existing Medium, Large, Major Hub and Mega Hub assignments until explicitly reviewed. Do not initiate the worldwide second-pass audit as part of this identifier completion.
