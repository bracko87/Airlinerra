# Airlinerra — US Airport Selection Batch 13 (2026-10-23)

## Bulk processing restored

The live Supabase table `airlinerra.airport_commercial_verification` now has **100** medium-runway-priority airports tagged in `next_action` with `Batch 13: airport-level civilian service verification pending`. These were selected by `research_priority=20`, `independent_review_at IS NULL`, descending recorded runway length and stable airport key.

Post-write verification confirms:
- **100** rows tagged.
- **0** of these have been independently reviewed.
- **0** of these are approved for gameplay.
- The total unreviewed airport queue remains **1,852**, because this was bulk queue preparation, not commercial service confirmation.

The existing FAA-matched 1,929 expansion candidates remain a physically screened candidate set, not game-approved airports. Prior bucket counts among unreviewed: 83 priority 10, 866 priority 20, 486 priority 30, 307 priority 40, 63 priority 70, 2 priority 85 and 45 priority 90.

Next: obtain individual or sufficiently authoritative bulk airport-level operating evidence, focusing on the 100 queued airports. Do not convert first-pass runway and public-use evidence into claims of scheduled passenger, charter or cargo service. Retain exactly six Airlinerra classes: Local, Regional, Medium, Large, Major Hub and Mega Hub. The original 3,140 remain unchanged.
