# Airlinerra — US FAA Part 139 commercial-service review, Batch 01

Date: 2026-10-23. Scope: 10 top-priority FAA matches (eight Class I, one Class II, one Class III) from the September 3, 2026 crosswalk. The primary FAA certification evidence is in [the previous report](FAA_PART139_CROSSWALK_2026-09-03.md).

## Research findings

| FAA LOC ID | Class | Airport | Current scheduled passenger evidence | Source |
|---|---|---|---|---|
| BJI | I | Bemidji Regional | Confirmed: Delta Connection/SkyWest service to Minneapolis–St Paul on official airport schedule | https://www.bemidjiairport.org/flight-schedule |
| DRT | I | Del Rio International | Not established; secondary route directory lists zero scheduled routes, needs primary confirmation | https://www.flightsfrom.com/DRT |
| MTH | I | Florida Keys Marathon | County FAQ says no regularly scheduled air service; on-demand charter available, although city page contains conflicting wording | https://www.monroecounty-fl.gov/m/faq?cat=27 |
| FMN | I | Four Corners Regional | Confirmed: daily United Express/SkyWest service to Denver on city's airport page | https://www.farmingtonnm.gov/172/Airport |
| JKA | I | Gulf Shores International / Jack Edwards | Confirmed: Allegiant scheduled passenger flights; seasonal availability, not year-round on every route | https://flyjka.com/flights/ |
| APF | I | Naples | Future: American Airlines approved twice-daily Charlotte flights beginning December 2, 2026; as of review date not in operation; airport publishes 75,000-pound weight limit | https://www.flynaples.com/naples-airport-approves-operating-agreement-with-american-airlines/ |
| HEZ | I | Natchez–Adams County | Confirmed: local authority's July 1, 2026 account of United Express/SkyWest flights launched to Houston | https://natchezinc.com/natchez-adams-county-airport-hez-welcomes-united-airlines-to-new-commercial-terminal/ |
| FPR | I | Treasure Coast International | Certification and airline recruitment confirmed; scheduled passenger service NOT confirmed | https://flytci.com/about/commercial-service-development/ |
| FKL | II | Venango Regional | Pending: find definitive 2026 airport/operator service evidence | — |
| 1G4 | III | Grand Canyon West | Pending: distinguish sightseeing/charter from Part 139 scheduled small-carrier passenger service; determine public access | — |

Research results are **evidence** rather than game clearance. Some official sources may be stale or internally conflicting; preserve discrepancies for resolution. Current routes are not blanket authority for all aircraft. Do not infer airliner compatibility from airport classes or runway lengths.

## Database effect

Eight of the ten expansion-candidate rows received an operator evidence URL, dated source research note, and review timestamp in private `airlinerra.airport_commercial_verification`. FKL and 1G4 require more evidence. No `scheduled_passenger_verification` final adjudication was forced where database state values/criteria have not been established. The original 3,140 airports, all `game_admission_status` values and airport-world activations remain unchanged.

## Next decisions

1. Resolve MTH conflicting official statements; independently corroborate DRT; find 2026 operator/service data for FKL and 1G4.
2. Check route/operator actuality and service schedules for the four confirmed airports, particularly seasonal schedules at JKA.
3. Cross-check available runway lengths/conditions, aircraft takeoff performance, access rights, and required passenger facilities for each candidate.
4. Work through the remaining 32 Class IV non-inactive candidates, then eight inactive certification records, preserving the difference between certification and airport closure.
5. Admit no airport until explicit review gates pass. Airlinerra's six gameplay categories remain Local, Regional, Medium, Large, Major Hub and Mega Hub.
