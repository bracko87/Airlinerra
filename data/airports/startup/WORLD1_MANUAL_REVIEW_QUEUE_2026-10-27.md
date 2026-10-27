# Airlinerra — non-foundation ICAO & paved-runway manual review queue

Generated 27 October 2026 from Airlinerra Supabase project `hwllkabgzaynalahvkpz`.

## Exact set arithmetic

- Initial master shortlist: **6,862** (dedicated source-reported ICAO or ICAO-looking four-letter ID; registry records asphalt/concrete/PEM paved runway >=1,200 metres).
- Airport IDs from the existing original 3,140 **that are present in the master shortlist:** **3,131**.
- Original 3,140 IDs **not present** in the master shortlist: **9**. They were not in the starting list and cannot be subtracted from it.
- **Remaining, non-foundation candidate IDs: 3,731**.
  - 2,393 with source-reported dedicated ICAO field.
  - 1,338 with four-letter identifiers **not verified as official ICAO**.
- **Three already rejected records:** Creil Air Base, Hiroshima Heliport, Hagler Army Heliport. These remain visible in full list but marked `REJECT_KNOWN`, not valid for manual approval.
- **Remaining reviewable cases: 3,728**; all have blank manual approval field and `PENDING` review status.

## Files

- [Complete non-foundation review queue (3,731)](world1_nonfoundation_icao_runway_3731_review_queue_2026-10-27.csv)
- [First 50 airports for manual review](world1_first_50_for_manual_check_2026-10-27.csv)
- [Pending only (3,728), excludes 3 known rejects](world1_remaining_3728_pending_checks_2026-10-27.csv)

## Manual checking workflow

Use column `CHECKED_TO_APPROVE_YES`. Leave blank until all of the following are manually verified:
1. ICAO location indicator truly belongs to that airport (a four-letter source value alone is not evidence).
2. At least one continuous >=1,200m asphalt/concrete fixed-wing runway, not combined asphalt + dirt length. PEM means combined asphalt/concrete.
3. Airport not permanently closed and still supports fixed-wing operations.
4. Civilian scheduled airline access is possible under known operating restrictions.

Enter `YES` to request approval, or `REJECT`/`NEEDS REVIEW` as the appropriate decision. The spreadsheet/CSV does **not live-sync** changes into Supabase. Return the checked file, or send airport sequence numbers and decisions to ChatGPT so the selected airport IDs can be recorded in Supabase. Do not bulk-approve blank entries.

### Current World 1 activation caveat

**All 3,728 currently reviewable rows are ALREADY active in World 1**, because they were admitted under an earlier historical-runway **simulation-only** approval. The manual review status is therefore not equivalent to game activation status. This task deliberately changes **review queue only**, not game membership. If future policy requires removing unreviewed airports from the playable game, treat that as a separate, explicit migration so the older World 1 game configuration is not silently destroyed.

Permanent review state: `airlinerra.airport_icao_manual_review_20261027`, with `review_sequence`, `review_status`, `manually_checked`, and individual confirmation booleans.

Original 3,140 are preserved, and existing confirmed-rejected airports remain excluded.
