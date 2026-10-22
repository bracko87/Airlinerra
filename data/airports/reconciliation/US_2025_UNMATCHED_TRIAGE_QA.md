# FAA 2025 U.S. unmatched commercial-service airport triage — QA

Checked 2026-10-22 against `main` at `data/airports/reconciliation/faa_2025_unmatched_commercial_service_airports.csv`.

The originally identified **66 FAA primary/nonprimary commercial-service rows** outside the initial Group 45 U.S. ID crosswalk have now been assigned explicit resolution statuses in the repository. They span U.S. states and separately screened U.S. territories, so "unmatched" did **not** mean 66 additional U.S. airports needed to be imported.

| Source-reconciliation status | Rows |
| --- | ---: |
| BELOW_1200M_MINIMUM | 33 |
| SURFACE_NOT_ASPHALT_CONCRETE | 17 |
| NO_OPEN_RUNWAY_IN_SOURCE | 1 |
| ALREADY_IN_TECHNICAL_REGISTER | 13 |
| RESTORED_TO_TECHNICAL_REGISTER | 2 |
| **TOTAL** | **66** |

Checks performed: 66 unique `faa_state,faa_locid` audit records; each has an assigned disposition, and counts sum to 66. Source FAA enplanement table: https://www.faa.gov/airports/planning_capacity/passenger_allcargo_stats/passenger/arp-cy2025-all-enplanements.pdf .

**Scope distinction:** FAA enplanements prove passenger activity, but eligibility for Airlinerra's technical register requires an **open asphalt/concrete runway at least 1,200 m long**. Rows assigned BELOW_1200M_MINIMUM or SURFACE_NOT_ASPHALT_CONCRETE should not be imported without new airport/runway-specific evidence. The 13 already-present and two restored rows should not be inserted a second time.

**Remaining uncertainty:** This QA confirms the repository's **triage accounting**, not a fresh aeronautical-authority check of all 51 excluded rows. A separate official-runway-source audit can challenge any outdated or ambiguous source surface and reopen a case when supported by evidence. Preserve source IDs and existing group records. No new airports were added by this QA.

This is separate from the **450** FAA 2025 U.S. commercial-service matches in the 2,879-airport technical U.S. register and the **149** cargo-positive records. Scheduled vs nonscheduled routes remain unverified.
