# Airlinerra airport collection — permanent runway-only register

## Current phase
Only collect airports having **at least one runway 1,200 m or longer**, reported **asphalt or concrete**, with both runway and airport not recorded closed. Facilities that say only "paved" are sent to a surface-check queue and not assumed eligible.

A matching airport can be considered **at least Level 1 (Local)**. This is only a lower-bound technical qualification, NOT a final assignment to Airlinerra's exact six tiers: Local, Regional, Medium, Large, Major Hub, Mega Hub. All other airport details are postponed.

## Canonical master
- `airport_register.csv`: **1,015 runway-qualified airport records across Groups 1–8**, with identifiers, country, name, longest reported qualifying runway, surface and minimum eligible level 1. This is not a list of operational or playable airports.
- Each group's `generated/groupN/groupN_technical_candidates.csv`: source screening that feeds the master.
- Each group's `generated/groupN/groupN_country_counts.csv`: country-level counts.
- `generated/groupN/groupN_surface_review.csv`: unclear pavement labels, excluded pending runway-surface verification.
- `generated/groupN/SOURCE.txt`: snapshot checksums and audit trail.
- `historical_approved_recovery.csv`: separate historical record of 56 name-level selections from earlier Groups 1–3 discussions; **do not add those as extra airports** unless already in a source screen.
- `group4_14_reconciliation.csv`: all 14 older Group 4 candidates were already included in the Group 4 technical screen.

## Totals for the current runway-only definition
| Group | Countries | Runway-qualified airports |
| --- | --- | ---: |
| 1 | Albania, Armenia, Austria, Azerbaijan | 30 |
| 2 | Belarus, Belgium, Bosnia and Herzegovina, Bulgaria, Croatia | 58 |
| 3 | Cyprus, Czechia, Denmark, Estonia, Finland | 74 |
| 4 | France, Georgia, Germany, Greece, Hungary | 307 |
| 5 | Iceland, Ireland, Italy, Kosovo, Latvia | 91 |
| 6 | Liechtenstein, Lithuania, Luxembourg, Malta, Moldova | 11 |
| 7 | Monaco, Montenegro, Netherlands, North Macedonia, Norway | 47 |
| 8 | Poland, Portugal, Romania, Russia (entire country), San Marino | 397 |
| **TOTAL** | | **1,015** |

**Historic Groups 1–3 selection: 110 airports (21/30/59).** The fresh runway-only screening produces **162 candidates** across those three groups (30/58/74), not 110. Do not conflate these two counts. The earlier list applied additional screening/selection rules; the current register is deliberately a broader technical pool. The separate 56-name historical recovery file remains on staging for reference, while 54 historic names were not recovered.

Uncertain runway surfaces: Group 4 has 4 entries requiring a later material check; Groups 1–3 and 5–8 have 0 in their current output. Russia is included once as RU for the whole country, with 312 runway-qualified candidates. These 4 are outside the master 1,015.

## Safe refresh
- Group 4: `Refresh Group 4 technical airport screening`.
- Group 5: `Refresh Group 5 technical airport screening`.
- Group 6: `Refresh Group 6 technical airport screening`.
- Group 7: `Refresh Group 7 technical airport screening`.
- Group 8: `Refresh Group 8 technical airport screening` (**all of Russia included**, with no European/Asian separation or longitude cutoff).
- Groups 1–3: `Backfill Groups 1-3 runway candidates`.
- Each workflow downloads the same OurAirports data files, screens its group and **rebuilds the master by combining every group's screens**, deduplicating by source airport ID. It does not replace other groups' records.
- `python scripts/rebuild_runway_register.py` rebuilds the permanent master from all completed group screens.
- `python scripts/validate_airports.py && python scripts/validate_historical_airports.py` validates the master and the historical file.
- Always use GitHub `staging`. Production `main` is unchanged without approved release.

## Future phase (not now)
Civilian or military status, operating permissions, opening hours, equipment/aircraft eligibility, final six-category rankings, terminals, finances, game activation and Supabase database migrations are deferred.
