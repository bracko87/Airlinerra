> **CURRENT GAME STATE (27 October 2026, manual review reset):** World 1 APPROVED and ACTIVE = **3,140 original founding airports only**. **4,996** formerly active additional approvals were archived and deactivated by explicit owner request. The earlier 8,136 approved airport report below is an **obsolete historical audit snapshot**, not the current game membership. Owner-checked airports go to a separate `airlinerra.airport_candidate_preapproval_pool`, **not** straight into World 1. Currently **33 pre-approved**, **3,678** review candidates pending, **17 excluded in finalized Batch 2**, **3** known rejected in the ICAO candidate queue. The next batch is [airports 51–100](world1_manual_preapproval_batch_2_51_to_100_2026-10-27.csv). Only submitting the checked batch finalizes its unchecked exclusions.

# Airlinerra — World 1 airport catalog (27 October 2026)

This is the **current authoritative GitHub index** for the Airlinerra airport audit. Older 8,148-, 8,139- and 18-exception snapshots are superseded.

## World 1 game membership (verified against Supabase)

| Admission status | Count |
|---|---:|
| Preserved founding airports | 3,140 |
| Extra airports accepted with source-reported ICAO + historical paved runway | 2,391 |
| Extra airports accepted using historical runway/identifiers | 2,605 |
| **Total activated and approved** | **8,136** |
| **Confirmed exclusions, inactive** | **17** |
| Overall candidate registry | 8,153 |

## Latest reference lists

- [All 8,136 accepted game airports](airlinerra_world1_accepted_8136_2026-10-27.csv)
- [17 confirmed exclusions and reasons](airlinerra_world1_rejected_17_2026-10-27.csv)
- [21 individual runway-source reviews](airlinerra_independent_runway_checks_21_2026-10-27.csv)
- [All 870 high-flag airports with separated runway and access reviews — latest](airlinerra_flagged_870_resolution_latest_2026-10-27.csv)
- [The remaining 7 specific runway material/operational exceptions — latest](airlinerra_remaining_7_runway_exceptions_2026-10-27.csv)

## Resolved high-priority runway evidence

The 870 non-foundation game airports with previous high-priority quality flags were audited separately for the physical runway requirement, without conflating that with airline operating permissions.

| Runway evidence | Airports |
|---|---:|
| FAA NASR October 2026 confirmed >1,200m asphalt/concrete | 841 |
| Official non-FAA primary-source confirmation | 9 |
| Airport operator confirmation | 4 |
| Secondary/historical aviation sources corroborate long paved runway | 9 |
| **Still pending exact technical runway verification** | **7** |
| **Total** | **870** |

The **seven targeted exceptions** are Ambrì (LSPM), Avord (LFOA), Cazaux (LFBC), Évreux-Fauville (LFOE), Orange-Caritat (LFMO), Phalsbourg-Bourscheid (LFQP), and Solenzara (LFKS).

- For Ambrì, Swiss FOCA evidence gives about 1,285m hard paved physical runway but **1,120m maximum usable runway**, plus unresolved civil conversion appeal. The precise eligibility interpretation is not reconciled.
- For French cases, published AIP surfaces such as **macadam** or **revêtue** have not yet been fully reconciled to the narrower user requirement of asphalt or concrete, or continuous qualifying segments must be verified. Historic ASP/CON registry records remain available.
- These seven remain **simulation-only historical admissions, not operationally verified safe airports**. There was no unsupported bulk rejection.
- Saint Hubert EBSU and Yucca Lake historical airstrip were separately corroborated as historically paved, but **not cleared for civilian scheduled airline operations**. The legacy `NV11` display code on Yucca was set to NULL in the game approved-airport catalog because that FAA identifier is now assigned to the separate Owyhee Hospital Heliport.
- Alpnach has different historical and aviation chart runway lengths, but all corroborating asphalt lengths exceed 1,200m. Its exact operational dimensions and military restrictions remain separate.
- Dübendorf, Emmen, Payerne, Étain-Rouvres, Saint-Dizier, Salon-de-Provence and Toulouse-Francazal have positive operator or aviation source checks; independent source quality is labeled explicitly.

## Access restrictions are a separate question

Of the 870 reviewed airports, 841 have FAA public-use evidence but **commercial permission has not been verified**; 28 have private/military restrictions recorded; and one has civilian access unconfirmed. Verifying a paved runway does **not** mean an airport is authorized for scheduled passenger or cargo operations.

## Source of truth

Supabase project `hwllkabgzaynalahvkpz`:
- `airlinerra.airport_world1_review_20261027`
- `airlinerra.airport_flagged_review_resolution_20261027`
- `airlinerra.airport_world_activation`
- `airlinerra_game.approved_game_airports`
- `airlinerra.airport_quality_audit_flags`

The original 3,140-airport founding cohort is untouched. The game catalog is for **simulation**, not real-world flight planning. Provisional game categories remain the six required levels: Local, Regional, Medium, Large, Major Hub, and Mega Hub.
