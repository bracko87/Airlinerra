# Airlinerra — U.S. Expansion Batch 15, 50-airport physical screening (2026-10-23)

A single deterministic Supabase SQL update advanced exactly **50** FAA-matched expansion records from the existing Batch 13 prepared queue to a **technical physical-screening complete** next-action flag.

## Applied mechanical rules
- Pinned FAA data: public-use `PU` and open `O`
- Qualifying runway length >= 1,200 m
- Surface: `ASPH`, `CONC`, or `ASPH-CONC`
- Runway condition: `GOOD` or `EXCELLENT`
- Deterministic batch: first 50 pending by descending recorded runway length, stable airport key.

A read-after-write database check confirmed **50 batch-15 flags**, **44** still in the original Batch 13 prepared queue, **83** individually source-researched across the 1,929 FAA-matched candidates, and **zero approval status changes**.

**Do not conflate bulk physical screening with independent commercial service verification:** `independent_review_at`, `game_admission_status`, final classification, original 3,140 airport records and activation were not changed. These 50 are physically eligible for the next airport-selection research stage, not commercially verified or game-approved.

Next: process the other 44 prepared airports in a single technical-screening operation, then prioritize individual civilian charter/cargo and scheduled service evidence by clusters. Keep exactly six categories: Local, Regional, Medium, Large, Major Hub, Mega Hub.