# Airlinerra — Group 2 operating restrictions and test cleanup (2026-11-10)

## Section 5 evidence: first two airport reviews
Actual public records reviewed against Group 2 Batch 1:

- **Onslow (YOLW), Group 2 airport OURAIRPORTS:27866**: Shire of Ashburton airport operator site https://www.ashburton.wa.gov.au/community/shire-facilities/onslow-airport.aspx confirms licensed, security-controlled airport and scheduled services. It does **not** establish explicit curfew/noise-chapter restrictions. Continue airport/AIP lookup.
- **Pakhokku (VYPU), Group 2 airport OURAIRPORTS:30234**: Myanmar historical AIP (2022 AIRAC) https://www.ais.gov.mm/eAIP/2022-01-21-AIRAC/html/eAIP/AD-2.VYPU-en-GB.html includes VFR/operational hours HO, but neither verifies a 2026 curfew nor a noise chapter restriction. Seek current AIP and published operating restrictions.

The separate public AirlineSim airport detail pages for these Group 2 airports were not retrieved by ordinary public search. Browser interaction in TinyFish could not start due to insufficient connected service credit. **Neither review is sufficient to mark a game restriction fact verified or operationally cleared**.

Production evidence table `airlinerra_game.airport_group2_section5_source_findings_v1` records URL, observed information, status and unknown restriction booleans. The corresponding status view confirms exactly **2 source-reviewed, 0 fully verified, 1,118 unresolved**. All 23 Group 2 batch review queues remain open. No game night ban/noise fields were overwritten, and no flight authorizations were enabled.

## GitHub test corrections made directly on main
Updated test files:
- `tests/test_airline_workspace.mjs`
- `tests/test_operations_center_navigation.mjs`
- `tests/test_fleet_acquisition_api.mjs`
- `tests/test_route_planner_ui.mjs`

These align assertions with 46 current views, removed demo fleet UI, encoded markup and a genuine newline-control-character negative test; game application code was not altered. A new passing CI result is **not yet verified**, and PRs #56–#60 remain open. Do not interpret test file edits as proof of successful release.

## Safety
No changes to Group 1 (3,141 airports); no Group 2 commercial airport activation; World 1 stays planned.
