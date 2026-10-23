# Airlinerra — Batch 17, 50-airport selection disposition (2026-10-23)

This is **50 airport records handled in one batch**, not 50 independent commercial confirmations.

## Results
- **2 individually source-reviewed** and independently timestamped (FMY, CLM).
- **48** given an explicit `commercial evidence NOT ESTABLISHED` next-action disposition from existing FAA physical/public-use source. No independent-review timestamp was assigned to those 48.
- **0** game admissions changed; all 50 remain NOT_APPROVED.

### Positive official airport-level evidence
- **FMY Page Field, FL:** Lee County Port Authority says GA with air charter businesses and no scheduled commercial airlines; charter vendor listed in airport service directory. https://www.flylcpa.com/fmy/about-page-field/ and https://www.flylcpa.com/fmy/airport-service-providers/
- **CLM William R Fairchild International, WA:** Port of Port Angeles says private, business and charter airplanes/helicopters operate, with main runway 6,347 x 150 ft and weight rating up to 115,000 lb. https://portofpa.com/air/

For remaining 48, the FAA records confirm the preliminary physical/public-use screen only. Do not mark charter/cargo/scheduled service confirmed without airport or operator evidence. No final game category assignments made.

Post-write Supabase check: 48 tagged as Batch 17 evidence pending; **85** of 1,929 now have independent-review timestamps, **1,844** remain; **0** approvals.

## Process improvement
Use 50-airport selection-disposition batches, and identify separate counts for physical-screened, independent commercial evidence, held, and approved. Avoid misleading reports implying that every queued airport was individually verified when only existing FAA runway data was checked. Future research should focus on airport owner/authority or documented operator evidence across the 48 pending airports.
