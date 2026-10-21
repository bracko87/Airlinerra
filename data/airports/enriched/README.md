# Airlinerra — worldwide enriched airport data

This directory contains the **first, provenance-tracked data layer**, not the commercial airport activation list.

| File | Role |
| --- | --- |
| `airport_identity.csv` | 7,846 airport identities, separate source-reported ICAO/IATA/local codes and coordinates |
| `qualifying_runways.csv` | 9,260 individual source/override runways which meet the 1,200m asphalt/concrete screen |
| `commercial_review_queue.csv` | Separate passenger/cargo review fields for every airport. Initial permission unknown everywhere |
| `serbia_commercial_pilot.csv` | Seven Serbia airport pilot assessments, with evidence and explicit unknowns |
| `SERBIA_PILOT.md` | Pilot findings, source links and important Ponikve geometry discrepancy |
| `country_counts.csv` | Country-by-country reconciled identity and runway row totals |
| `enrichment_exceptions.csv` | Automated source ID, coordinate or runway mismatches; currently zero in bulk snapshot |
| `SOURCE.txt` | Pinned source commit |

## Important accuracy safeguards

- 7,845 real candidates have coordinates from source; **fictional LYAL** has no approved coordinates.
- **5,409 source-reported ICAO**, **5,179 source-reported IATA** entries: not independently confirmed. GPS/source identification codes are never silently treated as valid official ICAO.
- 9,260 runway rows mean separate runway strips, not runway endpoints; one airport can have several.
- This dataset keeps the original `airport_register.csv` intact.
- **All passenger/cargo approvals remain UNKNOWN in the global queue** until separately verified. The pilot is an independent curated evidence layer and does not overwrite the global queue.
- No automatic inference of zero slots, zero cargo, no curfews, unlimited hours or commercial access.
- Rely on official AIPs/airport operators for permissions, declared runway lengths, noise restrictions and operating hours; some raw source measurements can be stale (especially Ponikve).

## Reproduce

Fetch pinned datasets:

```bash
SHA=b529623d2a0b09a9be78d37fc7a7a5e1e16e3451
curl -L --fail https://raw.githubusercontent.com/davidmegginson/ourairports-data/$SHA/airports.csv -o /tmp/airports.csv
curl -L --fail https://raw.githubusercontent.com/davidmegginson/ourairports-data/$SHA/runways.csv -o /tmp/runways.csv
python scripts/enrich_airport_reference.py --airports /tmp/airports.csv --runways /tmp/runways.csv --source-commit "$SHA"
python scripts/validate_airport_enrichment.py
```

Manual GitHub Actions workflow: `.github/workflows/refresh-airport-enrichment.yml`. Never set push triggers or game/production deploy hooks.

## Next phase

Review passenger/cargo access independently, then curfews, gates, stands and capacity; compute game model demand using independently specified economic assumptions. Both observed traffic and generated demand need sources/models and should never be fabricated as factual statistics.
