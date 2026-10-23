# Field-completeness audit — 3,906 candidate Local/Regional airports (2026-10-23)

This is a **research queue**, not a commercial approval or game deployment. Source files and the original 3,140-airport shortlist remain unchanged.

| Test | Count |
|---|---:|
| New airports, unique source IDs | 3,906 |
| Duplicate source IDs with original 3,140 | 0 |
| Source country code, position and region code present | 3,906 |
| Source municipality missing | 158 |
| Source GPS code missing | 229 |
| Source ICAO code missing | 2,091 |
| Source IATA code missing | 2,184 |
| Airports missing at least one source identifier | 2,337 |
| Airports missing all three | 199 |
| Master-qualified runways | 3,906 |
| Detailed qualifying-runway matches | 3,688 |
| No matching detailed qualifying-runway record | 218 |
| Source qualifying-runway width documented | 3,655 |
| Width not documented in the available detailed dataset | 251 (218 without matching detailed record, 33 with missing width) |
| Provisional tiers | 2,447 Local, 1,459 Regional |
| Specific civilian evidence needing follow-up | 2 |
| General civilian-permission review | 3,904 |
| Commercially approved for play | 0 |

Per-airport audit: [candidate_completeness_audit.csv](candidate_completeness_audit.csv). Machine-readable totals: [candidate_completeness_summary.json](candidate_completeness_summary.json).

## Audit interpretations

- The master proves technical runway qualification under the pinned source and overrides; the enriched runway detail comes from a separate source snapshot. No match for 218 airports does **not** mean they lack runways. The matched qualifying-runway row count is **not** the all-runways inventory.
- Source-reported GPS, ICAO and IATA values are not all authority certified. Blanks remain blank; future Airlinerra-only code values must use separate game fields with explicit fictional provenance and global collision checking.
- The 6 (Local) / 10 (Regional) estimated movements per hour are copied from the original startup *provisional game model*. They are **not** verified airport slot allocations, terminal capacities, or permission to activate the airport.
- Unverified commercial access is not verified military-only status. The 266 military-name and 147 specialized-use holds are separate from this 3,906-row candidate ledger and require their own reviews.

## Completion path

1. Resolve the 218 runway-detail joins, fill or transparently estimate the 251 missing game-reference width fields (preserve sources), then audit the entire runway inventory and designators.
2. Source or explicitly handle 158 municipalities, 229 GPS, 2,091 ICAO and 2,184 IATA blanks; do not invent official values.
3. Verify official civilian access plus scheduled/charter/cargo permissions, start with the two earlier civilian-evidence candidates, then proceed in country batches across the 3,904 other candidates.
4. Review 6 game categories and real capacity separately and request owner approval for the actually eligible set. Keep all airports non-playable until approval.

**Result at this checkpoint: 3,906 technically shortlisted; 0 documented commercially approved.**