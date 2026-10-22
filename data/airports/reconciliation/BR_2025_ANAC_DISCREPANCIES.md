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

## 2026-10-22 follow-up: provisional flags corrected

The five prior preliminary passenger-YES statuses listed above were changed to **UNKNOWN** in the separate commercial-review CSV. Their 2025 ANAC observations contain no positive passenger evidence. This does **not** establish that they have no airline service. All original runway-qualified technical airport records remain intact.

Additional independently checked sources:

- **SDNM:** DECEA October 2026 aerodrome index identifies Brigadeiro Eduardo Gomes at **Nova Mutum**, not Manaus; SBEG remains the separately registered international airport in Manaus. https://aisweb.decea.mil.br/eaip/20-2026_2026_10_01/eAIP/AD%201.3-en-GB.html
- **SNEW:** DECEA AISWEB explicitly describes Fazenda Congonhas in Carneirinho/MG as **AD PRIV** (private aerodrome). This does not justify passenger-YES. https://aisweb.decea.mil.br/?codigo=SNEW&i=aerodromos
- **BR-0538:** No reliable airport-specific 2025 passenger record or official alternate ICAO was established in this review; remains UNKNOWN.
- **BR-2155:** Brazil's public aerodrome grant listing identifies **Juazeiro — SDKF** (pending homologation), but this alone does not establish that the technical source record BR-2155 is the same facility. Alias join remains unresolved. https://www.gov.br/portos-e-aeroportos/pt-br/assuntos/transporte-aereo/outorgas-aerodromo/outorgas-de-aerodromos-por-estado
- **SDSC:** Brazil's transport ministry explains that São Carlos is primarily for aircraft maintenance and the reported international maintenance authorization prohibits passenger/cargo boarding or unloading. Separate 2026 government reporting confirms the LATAM maintenance center there. https://www.gov.br/transportes/pt-br/assuntos/noticias/ultimas-noticias/aeroporto-de-sao-carlos-recebe-voo-internacional-exclusivamente-para-manutencao and https://www.gov.br/portos-e-aeroportos/pt-br/assuntos/noticias/2026/03/presidente-lula-e-silvio-costa-filho-visitam-centro-de-manutencao-aeronautica-em-sao-carlos-sp

**Remaining:** all nonmatching airports still need optional alias/alternative-source review. Do not conflate airport source IDs and similar names; 2025 nonregular traffic alone does not establish scheduled commercial passenger service. The original 2025 ANAC crosswalk is a historical activity review, not a direct 2026 game-operations permission.
