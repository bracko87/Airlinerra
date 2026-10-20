# Airlinerra — canonical airport register

This directory is the permanent, version-controlled source for approved airports and reviewed candidates.
Supabase will become the game's live database after its own Airlinerra project is provisioned; a committed migration is NOT an executed migration.

## Known historical state
- Groups 1–3: 110 airports reported approved in prior conversation (21 + 30 + 59). **56 historically approved Local airport names recovered in `historical_approved_recovery.csv` (Groups 1/2/3: 9/11/36), without current-source verification. 54 individual records still missing. 0 imported into the playable master register.** Do not treat the count as a complete master CSV.
- Group 4 preliminary register: 103 candidates across FR 37, GE 4, DE 26, GR 31, HU 5. Rows not yet recovered in this repository.
- Group 4 broader screening: 307 technical runway-qualified records (FR 151, GE 10, DE 93, GR 42, HU 11). These are NOT approved. Screening source and snapshot must be reproduced before importing.
- 14 additional Group 4 candidates are tracked in `group4_review.csv` with `REVIEW` status only.

## Exact six categories
1. Local
2. Regional
3. Medium
4. Large
5. Major Hub
6. Mega Hub

Category assignment should be recorded only after the user-approved six-category criteria are retrieved and confirmed. Above are the historical names; numeric thresholds/definitions are not reconstructed here.

## Approval policy
- Runway: >=1,200 m operational asphalt/concrete (or independently verified material).
- Confirm civilian operating permission. Exclude military-only without confirmed civil authorization.
- Check weight/aircraft-type limits, opening hours, seasonal conditions and prior-permission requirements.
- Separate permanent airfield constraints from temporary NOTAMs.
- Each approval requires sources, review date and explicit status. An airport may remain playable with aircraft-type restrictions if civilian use is permitted.
- Deduplicate by authoritative identifiers (ICAO where available, plus source airport ID); avoid inferring ICAO from an unverified identifier.

## Workflow
1. Append raw screening data as REVIEW, never as playable airports.
2. Attach source evidence, classify approval status (`APPROVED`, `REVIEW`, `EXCLUDED`) and assign exactly one of six categories to APPROVED rows.
3. Run CSV validation in CI, review the change on staging.
4. Sync only APPROVED rows to the Airlinerra Supabase `airports` table, through separately approved migration/import job.
5. Preserve excluded/review records for audit traceability.

Files: `historical_approved_recovery.csv` preserves 56 previously approved Local names but they are NOT currently verified for gameplay. `group4_review.csv` is NOT imported into gameplay. `airport_register.csv` is the canonical approved export and is intentionally header-only until source records are recovered.
