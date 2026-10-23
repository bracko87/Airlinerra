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
