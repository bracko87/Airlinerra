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

## Additional independent findings — research only, awaiting Supabase write

Database query/write access was blocked in this session; the following are **not counted as reviewed** and should not increase the 849 checkpoint until saved and read back. These codes came from the previous unreviewed queue.

- **EMM, Kemmerer, WY:** Wyoming DOT lists Kemmerer as an *Intermediate Airport*, for medium/small business jet and recreational operations; its label is a Wyoming system planning class, **not** an Airlinerra tier. Sources: https://www.dot.state.wy.us/home/aeronautics/planning--programming-program/wyoming-statewide-system.html and https://www.dot.state.wy.us/home/aeronautics/education-outreach/wy-fly-passport-program/visitor-station-locations.html. No specific carrier authorization confirmed.
- **BCE, Bryce Canyon, UT:** Garfield County says runway is 7,400 ft and serves Bryce Canyon Airlines-associated small propeller aircraft, charters and private aircraft; ability to take large aircraft in emergencies does not imply regular air-carrier rights. Source https://www.garfield.utah.gov/Departments/Bryce-Canyon-Airport . Confirm current operations and permissions separately.
- **EVW, Evanston, WY:** Uinta County describes privately operated and general aviation users, runway 7,300 ft, fuel and maintenance; Wyoming DOT lists airport as *Business Airport*. Sources https://www.uintacountywy.gov/1019/Airports and https://www.dot.state.wy.us/home/aeronautics/planning--programming-program/wyoming-statewide-system.html . Neither proves scheduled routes or carrier certification.
- **AFO, Afton, WY:** Wyoming DOT lists Afton Municipal as a *Business Airport* and identifies Star Valley Aviation FBO; no scheduled airline evidence established. Sources https://www.dot.state.wy.us/home/aeronautics/planning--programming-program/wyoming-statewide-system.html and https://www.dot.state.wy.us/home/aeronautics/education-outreach/wy-fly-passport-program/visitor-station-locations.html .

**Status remains 849/1,929 database-verified** until the pending reviews are written, and 44 still needed to finish Batch 34. No new game admissions.
