# United States 2025 FAA passenger classification quality check

Verification date: 2026-10-22. Source data on branch `main`.

This independent consistency check compared all Group 45 U.S. rows with `group45_faa_2025_passenger_crosswalk.csv` and `group45_country_counts.csv`.

| Check | Result |
| --- | ---: |
| U.S. runway-qualified technical records | 2,879 |
| U.S. FAA passenger crosswalk records | 2,879 |
| FAA primary commercial-service (P) matches | 386 |
| FAA nonprimary commercial-service (CS) matches | 64 |
| **P/CS evidence-supported passenger YES** | **450** |
| FAA general aviation (GA) matches | 816 |
| FAA records flagged NO_2025_FAA_AIRPORT_MATCH | 1,612 |
| Unmatched or other non-commercial case(s) | 1 |
| FAA P/CS positive airports outside technical roster | 66 |
| Separately cargo-evidenced Group 45 U.S. airports | 149 |
| Passenger P/CS entries missing YES in review | **0** |

The 450 passenger YES records match the P/CS FAA rows exactly; no evidence-supported commercial-service record is absent from the review CSV.

**Interpretation:** FAA P/CS records support 2025 passenger boardings, **not** an assertion that every route is scheduled, continuously operating or permitted by game rules. The 816 GA-class rows may include passenger boardings but are not treated as commercial-service airport YES. Airport rows without passenger evidence remain UNKNOWN. The 66 unmatched FAA P/CS LOCIDs must be checked against the technical runway criteria before any addition; they must not be added simply to raise the total.

Official FAA data: https://www.faa.gov/airports/planning_capacity/passenger_allcargo_stats/passenger/arp-cy2025-all-enplanements.pdf

See source crosswalk: `data/airports/commercial/group45/group45_faa_2025_passenger_crosswalk.csv`. No airport IDs, source runways, six-tier definitions, or cargo classifications changed in this quality check.

The 1,612 explicit NO_MATCH plus one other non-commercial/ambiguous row account for the 1,613 rows without a positive P/CS or GA classification. 

## Disposition of the 66 initially unmatched FAA LOCIDs (22 October 2026)

FAA entries were originally unmatched to **the US Group 45** source IDs, not necessarily absent worldwide. The subsequent original-OurAirports-ID and runway audit found **13 already present elsewhere in the worldwide technical register** (including the VA/DCA versus US-DC designation case), **33 below the 1,200m technical minimum**, **17 with runway surface not meeting asphalt/concrete criteria**, **1 without a documented open runway**, and **2 qualifying omissions restored in MP and PR**.

**Restored:** `PGWT/TNI` source 5434 runway 235364 (2,621.3m asphalt/concrete), and `TJRV/RVR` source 42321 runway 254009 (3,352.8m asphalt/concrete). Both are separately FAA passenger YES in their territorial Group 25 and Group 43 commercial reviews, with cargo UNKNOWN. Worldwide canonical register total is now **8,152 (8,151 real + fictional LYAL)**. The U.S. country totals of 2,879 technical airports and 450 P/CS matches are unchanged because neither addition is coded US. Details: `data/airports/reconciliation/faa_2025_unmatched_runway_audit.csv`.
