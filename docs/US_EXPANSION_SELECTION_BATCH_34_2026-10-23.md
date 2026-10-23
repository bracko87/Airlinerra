# Airlinerra — Batch 34, ongoing (2026-10-23)

**Partial batch:** six independently sourced airport reviews saved and read back from private Supabase `airlinerra.airport_commercial_verification`. Target remains 50 distinct previously unreviewed records; **44 more are needed** before this batch is complete. Prior checkpoint: 843/1,929; expected after this write 849/1,929 (confirm aggregate separately). No gameplay admissions.

| FAA | State | Source | Evidence and limits |
|---|---|---|---|
| EKS | MT | https://www.madisoncountymt.gov/601/Airports | Madison County: public-use general aviation; FBO. Carrier or charter permissions not confirmed. |
| SIY | CA | https://www.siskiyoucounty.gov/generalservices/page/siskiyou-county-airport-ksiysiy | County: non-towered, Jet-A and seasonal USFS tanker base; not proof of scheduled or cargo services. |
| AEG | NM | https://www.faa.gov/flight_deck/aeg | FAA: GA, medevac, training, operational hazards; no airline service confirmation. |
| DIJ | ID | https://driggsairport.org/about/overview/ | City airport: business charter operations alongside GA; no confirmation of individual carrier authorizations or routes. |
| INW | AZ | https://azdot.gov/airports/winslowlindberg-regional-airport | State DOT airport directory and documents; no confirmed scheduled service. |
| FST | TX | https://www.iflightplanner.com/Airports/KFST | Aviation directory: air ambulance; reported temporary runway closure Oct 19-23, 2026; independently verify active NOTAMs. |

Evidence URLs, source notes, and `independent_review_at` are in the database on their immutable airport keys. Source review is separate from Part 139, scheduled passenger, charter, cargo and aircraft fit. All six retain `game_admission_status=NOT_APPROVED`. Six-tier system only: Local, Regional, Medium, Large, Major Hub, Mega Hub. Existing 3,140-airport playable cohort unchanged.

**Next:** Select 44 more unreviewed entries using `independent_review_at is null`, check independent airport/operator sources, and record specific evidence and limitations. Do not mark generic FAA runway-only rows as independently reviewed.
