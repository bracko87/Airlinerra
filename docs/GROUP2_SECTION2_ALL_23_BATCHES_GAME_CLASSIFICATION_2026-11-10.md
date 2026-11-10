# Group 2 — Section 2 classification game-data completion
Date: 2026-11-10

## Accepted game-data result
All **1,118** owner-preapproved Group 2 airports, in the immutable **23 batches** defined in Section 1, have a valid six-tier game category and one of Passenger, Cargo or Both. All batches are accepted as `game_complete_estimated`; this does **not** imply independently verified passenger volumes, cargo tonnage, runway capability or airport operational certification.

Category distribution: Local 754, Regional 338, Medium 26, Large 0, Major Hub 0, Mega Hub 0.
Traffic-intention distribution: Passenger 953, Cargo 43, Both 122.

The existing owner-selected provisional categories are preserved. No category is upgraded or downgraded from runway measurements alone.

## Storage and inspection
- `airport_group2_section2_game_registry_v1`: every airport with frozen batch/case, category, traffic intention and game completeness.
- `airport_group2_section2_batch_completion_v1`: live per-batch counts.
- `airport_group2_section2_batch_acceptance_v1`: immutable 23-batch closure snapshots.
- `airport_group2_section2_overall_status_v1`: global acceptance and distribution.
- New objects deny direct anon/authenticated access; acceptance table uses RLS and immutable trigger.

## Verification and limitations
Production migration applied and post-install readback checked: 23 batches, 1118 airports, 1118 complete; Group 1 unchanged at 3141; Group 2 commercial-enabled = 0; world remains planned. The classification's source-verification status remains false. Airports must not be admitted to live flight scheduling by this change.

## Next
Proceed with **Section 3** against the same 23 fixed batches, preserving estimates and explicit source-provenance labels.
