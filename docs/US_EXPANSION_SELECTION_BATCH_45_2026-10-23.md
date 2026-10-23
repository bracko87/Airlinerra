# Airlinerra — US Expansion Research Batch 45 (2026-10-23)

**Verified completion:** 50 previously unreviewed airports received airport-specific source-review records, saved and read back from private Supabase `airlinerra.airport_commercial_verification`. Overall **1,443 of 1,929 reviewed (74.80%)**, **486 still unreviewed**, **zero gameplay approvals**. Original 3,140 game airports were not touched.

These are *first-pass* airport facility/operating-condition source reviews, not commercial airline, charter or cargo permissions, not Part 139 certification, and not a blanket determination of aircraft compatibility. Aircraft-specific runway/landing-distance/pavement strength, active FAA NOTAMs, fuel logistics, airport rules and actual scheduled versus on-demand commercial activity need dedicated final confirmation.

## Major source findings

- **93F Mignon Laird, Oklahoma:** State airport plan describes 4,022×60ft asphalt runway and reports a **4,000-pound single-wheel pavement rating**. This requires substantial aircraft-model restrictions, notwithstanding public-use status. https://oklahoma.gov/aerospace/airports/find-an-airport/mignon-laird-municipal.html
- **X26 Sebastian, Florida:** City documents 2024 resurfacing of its 4,024×150ft main runway; FDOT classifies its approaches as visual-only, and secondary runway 10 has a displaced threshold. https://www.cityofsebastian.org/384/Pilots-Information
- **COQ Cloquet/Carlton County, Minnesota:** FAA-derived record has 8,000lb single-wheel runway 18/36 rating and Oct 2026 **both runway-end identifier lights reported out** until April 2027; recheck active NOTAM. https://www.airnav.com/airport/COQ
- **OMN Ormond Beach, Florida:** City owns GA airport with runways 9/27 and 17/35. FAA-derived October 2026 notices report several approach-lighting outages. https://ormondbeach.org/77/Airport
- **EPM Eastport, Maine:** City reports 4,000ft runway, self-service 100LL and Jet A+ and airport-of-entry customs facilities, none of which alone establishes any active scheduled cross-border passenger/cargo carrier. https://www.eastport-me.gov/206/Municipal-Airport
- **65S Boundary County, Idaho:** FBO verifies Jet A/100LL and maintenance for 4,002×75ft runway. Winter/terrain aircraft performance and carrier rights need checking. https://northernairaviation.com/
- **3MY Mount Hawley, Illinois:** Peoria airport authority's GA auxiliary airport offers 4,001×60ft runway, fuel and RNAV approach, distinct from scheduled airline service at PIA. https://www.fly3my.com/airport/pilot-information/
- **50I Kentland, Indiana:** Indiana state plan describes GA/business/agricultural use and no scheduled commercial enplanement forecast, though 100LL/Jet A is available. https://kentland.in.gov/wp-content/uploads/2022/09/50I_Kentland-Municipal.pdf

## Research admission controls

All 50 are `game_admission_status=NOT_APPROVED`; no game activation or changes to the original 3,140 airports. Exactly **six** Airlinerra categories: Local, Regional, Medium, Large, Major Hub, Mega Hub. Airport proper names and FAA/state planning designations do not constitute a game classification.

The two sections below contain the full 50-record Supabase source ledger, including immutable key, authority/airport-specific URL, detailed note and UTC timestamp.
