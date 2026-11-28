# Roswell storage compatibility review — 2026-11-27

Review only. No game runway inventory changes or activation.

## Verified evidence
- Latest Tarbes compatibility regression 46067397627 passed at f852d2269df836594a4330c097e1207783b5aa25.
- Fresh read-only game query found exactly one runway for OURAIRPORTS:3856 in world 1: source 244235, 17/35, 3050.4 x 30.5 m, ASP, historical_unverified, operational_status unknown.
- Existing Section 5 operating baseline at ASP, LDE and ROW reports pavement_strength_status=UNVERIFIED and zero operational source records. No aircraft-specific FAA operation readiness cases exist for ROW.
- AirNav FAA-derived data effective 11 June 2026: 17/35 10008 x 100 ft, asphalt, published TORA/LDA 10008 ft each end; reported wheel-load ratings single 77,000 lb, dual 104,000 lb, double tandem 165,000 lb; reported PCR 150/R/C/W/T. 03/21 is a separate 13000 x 150 ft concrete runway with reported ratings 100,000/200,000/400,000 lb and PCR 1140/R/C/W/T. Source https://www.airnav.com/airport/KROW. SkyVector FAA data effective 29 October 2026 corroborates 17/35 dimensions: https://skyvector.com/airport/ROW/Roswell-Air-Center-Airport.
- The discrepancy is a missing runway in the game, not simply a storage restriction. Published data are static and not a current runway clearance. No aircraft-specific width or pavement compatibility follows from wingspan or MTOW alone.

## Proposed approach
1. Review 03/21 through existing airport inventory evidence process (source identity, geometry, directional limits, surface, width, elevation and operating status). Do not fabricate source ID or copy 17/35 status.
2. Review change impact on normal game commercial selection before any shared inventory write. Alternative is separate storage-only runway selection integrated with Section 5, not a silent replacement.
3. For phase 1 storage approval, require a documented game decision on pavement and aircraft-specific width. Either retain the game's explicitly approved simplified screening model, or collect per-configuration evidence; do not infer gear ratings or convert PCR into a universal MTOW limit.
4. Until approved, keep ROW candidate inactive. Existing commercial operations remain unchanged. Tarbes compatibility is tested but the revised integrated rehearsal and final policy approval remain pending. ASP also requires runway-status review.
5. Separate disabled structural deployment package from airport activation so missing runway evidence cannot accidentally grant new operational rights.

No production write performed.
