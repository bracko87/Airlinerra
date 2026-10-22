# Airlinerra — Phase A: Six-tier airport classification review (proposal v1)

## Scope and guardrails

The validated technical master contains **8,152** airports, including **8,151 real** airports and the owner-defined fictional **LYAL**. This Phase A output is a **separate, non-operational REVIEW**. It does **not** populate the real-airport `assigned_category` field, authorize passenger or cargo routes, infer civilian access, update Supabase, or deploy the game.

Categories (exact names, 1–6): **Local, Regional, Medium, Large, Major Hub, Mega Hub**. The screened runway minimum (1,200 m paved) establishes only *minimum technical Level 1*, **not** the final six-tier category.

## Proposed *provisional* passenger-volume tiers (not yet approved game policy)

| Candidate tier | Positive 2025 regular-passenger *stage-endpoint-associated* proxy |
|---|---:|
| Local | 1–9,999 |
| Regional | 10,000–99,999 |
| Medium | 100,000–999,999 |
| Large | 1,000,000–9,999,999 |
| Major Hub | 10,000,000–49,999,999 |
| Mega Hub | 50,000,000+ |

These are **draft game-design thresholds**, not an official ICAO/ACI airport classification. The Brazil source is ANAC's 2025 air-transport flight-stage open data, as reconciled by source airport ID in `commercial/group46/group46_brazil_anac_2025_official_crosswalk.csv`. Endpoint-associated passengers are **not independent audited airport totals**; values are historical, may require identity reconciliation, and do not establish 2026 scheduled-flight rights. Only **positive regular passenger observations** generate a provisional passenger tier. Nonregular/charter-only activity, freight-only activity and missing matches do **not** create an automatic tier. The reported cargo kilograms remain a **separate signal**; a future combined passenger/cargo rule and operational access assessment is still needed.

## Review statuses

- `OWNER_ASSIGNED`: protected fictional airport LYAL, final **Local**.
- `PROVISIONAL_REGULAR_TRAFFIC`: 2025 ANAC regular passengers >0; a draft candidate tier, **not final**.
- `NONREGULAR_ONLY_REVIEW`: 2025 nonregular passenger proxy only; no auto category.
- `CARGO_ONLY_REVIEW`: positive freight proxy but no positive passenger proxy; no auto category.
- `NEEDS_EVIDENCE`: source absent or insufficient; **UNKNOWN is not NO**, and cannot automatically mean Local.
- `EXISTING_FINAL_ASSIGNMENT`: preserves any future separately approved assignment without rewriting it.

The initial data covers the worldwide master, but the only imported comparable per-airport traffic proxy in this version is **Brazil**. Historical ANAC crosswalk has 577 airport IDs; Coroa do Avião/SIFC source ID **335361** is excluded by its separate official runway-exclusion record, leaving **576** eligible Brazil airports. The Iran OIBH source-code conflict remains a separate review item.

## Refresh / validation

Run `python scripts/build_airport_classification_review.py` after verified source changes. Run `python scripts/build_airport_classification_review.py --check` to confirm the committed review is reproducible. Unit tests: `python -m unittest discover -s tests -p test_airport_classification.py`.

The next dataset milestones are airport-specific passenger and freight sources for **other countries**, verification of civilian access, identifier conflicts, consistent cargo thresholds and human review before promoting *any* real airport to a final tier. Supabase is unnecessary for this data-preparation phase.
