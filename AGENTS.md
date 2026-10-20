# Airlinerra repository instructions

These rules apply to all contributors, automated agents and connected development tools.

## Branch safety
- All normal development, bug fixes, data curation, migrations, tests and documentation MUST target `staging`, explicitly.
- The `main` branch represents production. NEVER commit or push ordinary changes directly to `main`.
- Before a production release, compare `staging` to `main`, run required validation, and open a reviewed pull request.
- Merge or deploy to `main` ONLY after explicit owner approval for that release.
- Standard releases are grouped into two owner-operated manual release windows per day: morning and evening. Neither is automatic.
- Urgent releases may happen outside those windows, but still require testing and explicit owner approval.
- Never touch ProPeloton Manager or Game Control Center as part of Airlinerra changes.

## Airport data
- Airlinerra uses EXACTLY six airport classes in this order: Local, Regional, Medium, Large, Major Hub, Mega Hub. Never replace with a 4-tier system.
- Airport categorization and airport eligibility are two separate review processes.
- Baseline runway rule: at least one operational runway >= 1200 m with an asphalt or concrete surface. An unspecified 'paved' label needs verification.
- Military-only aerodromes are not playable unless civilian use is independently established.
- Runway eligibility does not confer automatic approval; confirm civilian access and limits, and retain evidence.
- Treat the earlier Group 4 figure of 307 strictly as unapproved runway-screening records.
- Do not manufacture missing airport records. Groups 1–3 were previously reported as 110 approved (21+30+59) but 56 historical Local airport names are now recovered in `data/airports/historical_approved_recovery.csv`, while 54 remain to be recovered. Historical approval must NOT be treated as evidence of current runway or civilian-access eligibility. None have been imported as playable.
- Keep permanent canonical records under `data/airports/`. `approved` means backed by specific reviewed evidence; `review` is never ingested as playable.
- All generated SQL is reviewed and tested on staging before production; never infer that committing a migration executed it in Supabase.

## Game rules
- Real-time worlds: one real day is one in-game day. No historical eras.
- New airlines start with USD 5,000,000 and zero aircraft.
- Initial architecture supports three worlds; launch with one.
