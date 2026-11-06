# Group 2 and Group 3 vs Group 1 — actual Airlinerra status

Checked 2026-11-06 against the central working Supabase project `hwllkabgzaynalahvkpz`.

## Source of truth

- `airlinerra_game.aircraft_groups123_parity_v1` is a private RLS-invoker, no-public-grant comparison across all aircraft configurations.
- Verified catalog: Group 1 **186**; Group 2 **47**; Group 3 **39**; **272 total**.
- `scripts/verify_aircraft_groups123_catalog_parity.sql` checks 272 catalog configurations, research completeness for Groups 2/3, source-backed exact role assessments, future restrictions, image coverage for Group 2, and no accidental gameplay release.

| Audit | Group 1 | Group 2 | Group 3 |
| --- | ---: | ---: | ---: |
| Aircraft | 186 | 47 | 39 |
| Core technical fields populated | 184 | 47 | 39 |
| Full modeled aircraft game research | 184 | 47 | 39 |
| Individual commercial service audit records | Existing variant service records | 47 | 39 |
| Model/configuration role with specific historical/current evidence | 185 broad variant statuses | 30 exact roles | 30 exact roles |
| Confirmed 2026 operator exact role in the group-specific audit | Not a comparable group-specific figure | 24 | 1 |
| Approved exact configuration hero image | 186 | 47 | 0 (user preparing separately) |
| Actual flight fuel profiles enabled for gameplay | 0 | 0 | 0 |
| Actual in-game purchasing/scheduled flying released | 0 | 0 | 0 |

**Important:** Group 1 is a research catalog standard, NOT a functioning, published in-game economy. Platform release flag `airlinerra_game.platform_release_gate.enabled` is FALSE, the development repository has no playable player UI or transaction engine, and no airline fleet aircraft are in the live inventory. It is technically incorrect to call Group 1 fully unlocked. Neither Group 2 nor Group 3 can be fully unlocked to working player purchase/lease/scheduling by changing only model research flags.

### Work completed in this review

1. Group 3 now has `airlinerra.aircraft_expansion_group3_commercial_service_audit` (39/39 assessments), the same structural fields and evidence checks as Group 2. Its RLS-protected `airlinerra.aircraft_expansion_group3_commercial_service_readiness_v1` reports current verified, historic exact role, future, mismatch and unknown status.
2. Added source-backed exact-role history to 30 of 39 Group 3 aircraft. Examples: A340-500 Emirates, PNG Air ATR72-600 Combi actual 2015 delivery/service, Boeing 727-200 Northeast 1967, CRJ100 Lufthansa CityLine 1992, 777-300ERSF IAI/Kalitta 2026, Boeing 747 variants historical operators, 767-200 and -200ER El Al, 767-300 JAL, MD-11 Alitalia combi, etc.
3. Promoted only source-backed previously-unverified models in Groups 2 and 3 to catalog `service_verified`. For verified-current 2026 operator types, set `civilian_service_status='active'` with verification date. This is a **catalog evidence status**, not `catalog_status='released'`, game purchase authorization, certification or automatic fleet admission. Historic types with no verified 2026 operating record were NOT falsely made active.
4. Corrected ATR72-600 Combi production history with manufacturer-confirmed PNG Air November 2015 customer delivery and in-service record.
5. Added `airlinerra_game.aircraft_groups123_parity_v1` and a regression script. All Group3 planning/history/economics/loading/noise/integration scripts and new 272-aircraft parity test passed.

### Why some records remain classified as uncertain

- Group 2 has **seven future aircraft** with orderable-intent versus display-only choices originally set by the owner. "Future" does NOT mean already delivered or available in the game.
- Group 3 has **three display-only future aircraft** and one **unlaunched Dash 8-400 Cargo Combi**; none may be automatically inserted into a fleet or flown. Its 737-700C exact mixed-layout evidence is military C-40A and is not proof of civilian airline operation. Several converted aircraft have no exact role-specific weight/airworthiness documents; retain models' safe provisional game caps.
- A historical model's 1970s–2000s airline service is not evidence it remains operational in 2026. Generic variant-level operator evidence from another configuration must not be copied as exact cargo/combi verification.
- Model-specific noise, detailed runway, and burn/range certification remains partly game-estimated in **all three** cohorts; no real-world flight dispatch approval is granted.

### Actual remaining prerequisites for fully playable Groups 1/2/3

1. Build/connect the actual **player application** and airline aircraft market (this research archive has no playable React/Netlify game app code).
2. Build transactional purchase / leasing logic, accounting, airline ownership checks, aircraft delivery, and used aircraft vs new-build vs future timing constraints; use server-side validation at final transaction.
3. Build real fleet management, position/turnaround, route persistence and departure/arrival validation, including airport schedule/runway/noise, fuel + cargo-mode checks. Current route checker is only a research preview.
4. Finish the exact configuration hero images for Group 3 (user working on these separately) and record in `airlinerra.aircraft_configuration_media` with exact model type/role.
5. Define and test explicit owner-authorized **gameplay release** for eligible aircraft and futures, without confusing source-verification and game release. Do not enable the global platform or issue transactions merely to make a dashboard appear green.

Current decision: **Research data 86/86 completed; historical/current exact-role verification 60/86 supported; no aircraft groups have working player release (0/272).** The remaining gaps are not properly resolved by setting all catalog statuses to `released` or flipping the global platform release switch.
