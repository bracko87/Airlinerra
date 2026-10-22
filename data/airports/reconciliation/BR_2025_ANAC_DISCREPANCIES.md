# Brazil Group 46 — commercial review discrepancies against official ANAC 2025

Audit date: 2026-10-22. Evidence basis: `group46_brazil_anac_2025_official_crosswalk.csv` and `group46_commercial_review.csv` on `main`.

## Results
- All 577 Brazilian source airport IDs are represented in the official 2025 evidence crosswalk and coverage register.
- Existing commercial-review passenger flags: 51 YES, 526 UNKNOWN. Existing cargo flags: 20 YES, 557 UNKNOWN.
- ANAC 2025 positive evidence: passenger 143, freight 142, with 151 airports having matching flight stages.
- **Five existing passenger YES flags lack positive passenger observations in the ANAC source join**. This is a discrepancy requiring additional source checks, **not evidence that the airport had no commercial service**:

| OurAirports ID | Code | Airport | 2025 passenger ANAC |
|---|---|---|---|
| 43312 | SDNM | Brigadeiro Eduardo Gomes Airport | UNKNOWN |
| 304 | SNEW | Fazenda Congonhas Airport | UNKNOWN |
| 332909 | BR-0538 | Fazenda Santa Maria Airport | UNKNOWN |
| 176 | BR-2155 | Juazeiro Airport | UNKNOWN |
| 201 | SDSC | Mário Pereira Lopes–São Carlos International Airport | UNKNOWN |

Investigate current/historical ICAO aliasing, airport role or names, and the provenance of prior preliminary passenger YES decisions. Do not confuse SDNM with SBEG. Check underlying stage semantics to avoid treating endpoint-associated quantities as independently audited airport totals.

## Interpretation and next actions
1. Review the five discrepancies individually with official aeronautical and operations sources. Keep the prior classifications intact until evidence adjudication.
2. Distinguish regularly scheduled positive passenger/freight movements from nonregular service. ANAC evidence is historical (2025), not an automatic grant of 2026 gameplay permissions.
3. Confirm the 426 no-stage-match airports against alternative aliases/source names. Preserve UNKNOWN, not NO.
4. After adjudication, revise the separate commercial review with explicitly sourced decisions. No six-category final assignments, technical-runway changes, database deployment or gameplay activation are authorized.
