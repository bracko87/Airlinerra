# Airlinerra — Airport Selection Reset and Backlog Audit (2026-10-23)

## Ground truth: live private Supabase
`airlinerra.airport_research_backlog` shows **8,153** airport records, all bearing preliminary `RUNWAY_QUALIFIED` screening status. That is *not commercial approval*.

| Cohort | Count |
|---|---:|
| ORIGINAL_3140 | 3,140 |
| EXPANSION_3906 | 3,906 |
| OTHER_MASTER | 1,106 |
| FICTIONAL | 1 |
| **Total** | **8,153** |

### Expansion eligibility review buckets
| Access review status | Count |
|---|---:|
| FAA_PHYSICAL_AND_PUBLIC_USE_VERIFIED_COMMERCIAL_REVIEW | 1,929 |
| HOLD_INDEPENDENT_VERIFICATION | 1,827 |
| FAA_NON_PUBLIC_USE_ACCESS_HOLD | 115 |
| HOLD_NO_UNAMBIGUOUS_FAA_MATCH | 19 |
| FAA_NO_CONFIRMED_1200M_ASPHALT_CONCRETE_RUNWAY_HOLD | 13 |
| HOLD_PRIVATE_COMMERCIAL_PERMISSION | 1 |
| FAA_AIRPORT_NOT_OPEN_HOLD | 1 |
| HOLD_IDENTITY_AND_PAVEMENT_CONFLICT | 1 |
| **Total** | **3,906** |

**Crucial distinction:** 1,929 matched records are physically/public-use verified but still lack final commercial suitability approval. Another 1,827 require independent verification. The other 150 are explicit holds, not automatic exclusions. `database_final_category` and review-level approval have not yet been populated in the research backlog for any of the expansion candidates (the original 3,140 also have no final-category entry in this view); do not overstate completed classifications.

## Simple airport-selection protocol
1. Confirm real airport identity, reliable position/codes and civilian access (exclude military-only and permission-denied).
2. Confirm **operational** qualifying runway >=1,200 metres with asphalt/concrete pavement, using individual runway observations and actual surface/closure status. A cached `RUNWAY_QUALIFIED` status is only an initial screen.
3. Confirm legitimate passenger/charter/cargo suitability at the *airport* level; do not individually validate aircraft tail numbers or FAA Part 135 charter operators in this selection phase.
4. Assign one of exactly six Airlinerra game categories: Local, Regional, Medium, Large, Major Hub, Mega Hub. Category classification separate from FAA Part139 class.
5. Review and approve appropriate capacity/airport record before activation; preserve original cohort until final reconciliation.

## Processing order
- First complete 1,929 FAA physical/public-use verified candidates' commercial suitability; the 50 FAA Part139 matching subset already has initial service desk research, not complete approvals.
- Then work through 1,827 independent verification candidates, focusing on strong paved runway and civilian access evidence.
- Finally adjudicate the 150 holds, escalating access/identity/pavement conflicts.
- Run a distinct data completeness audit on the original 3,140 before assuming their classification is finished. Existing source-reported codes may legitimately be absent; missing ICAO/IATA is not itself proof of closure.

No gameplay approvals or world activations were changed during this audit. Supabase is the master dataset; GitHub stores versioned research decisions.
