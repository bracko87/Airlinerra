# Airlinerra — B02 South America: first official evidence batch (2026-10-22)

**Batch scope:** 13 South American countries/territories outside Argentina and Brazil, **311 runway-qualified real airport rows** from the 8,153-airport master. This is **an in-progress batch, not a completed regional commercial audit**.

## Verified work imported

- **Peru (PE):** official Ministry of Foreign Trade and Tourism / DGAC *2025 General Movement of Passengers in Peru Airports*, page **22**, regular commercial air service annual passenger movements (arrivals+departures), reported **in thousands**. **25 airport rows** matched by original OurAirports source ID and airport identifier, yielding **25 provisional categories**. Peru has 42 runway-qualified airport rows, so 17 remain without matched 2025 regular traffic evidence. The official report lists additional smaller airfields that were not confidently mapped to eligible technical master IDs; no invented IDs.
- **Ecuador (EC):** official DGAC 2025 report separately documents **397,798.54 annual cargo tonnes at Quito Mariscal Sucre (SEQM, source ID 308273)** and **26,991.92 tonnes at Guayaquil José Joaquín de Olmedo (SEGU, source ID 6056)**. The country-level 2025 total is 424,790.46 tonnes in that report, exactly the sum of these figures. The two airports are marked **CARGO_ONLY_REVIEW**: no passenger category is assigned from freight evidence; these statistics do not imply there were no passenger flights.
- Other B02 airports retain **UNKNOWN** passenger evidence. Official national sources located for **Bolivia**, **Chile** and **Colombia** are listed in [B02 source index](b02_official_2025_source_index.csv); no guessed individual totals have been imported.

## Source citations, units and limitations

- Peru PDF: https://cdn.www.gob.pe/uploads/document/file/10074446/8207018-informe-anual-movimiento-general-de-pasajeros-en-los-aeropuertos-del-peru-ano-2025.pdf?v=1780349699
- Ecuador DGAC: https://www.aviacioncivil.gob.ec/el-transporte-aereo-ecuatoriano-movilizo-a-8-millones-de-pasajeros-en-el-2025/
- Peru numeric examples: Jorge Chávez Lima **27,219 thousand**, Cusco **4,697 thousand**, Arequipa **2,345 thousand** regular passenger arrival/departure movements. Every imported integer is the published thousands multiplied by 1,000, explicitly an *estimate* because the source is rounded.
- Different source definitions across **Brazil stage-endpoint regular observations**, **Argentina total regular+nonregular observations**, and **Peru regular commercial annual figures** remain labeled separately. Never blend these metrics without a harmonization review.
- Ecuador cargo tonne figures remain `annual_cargo_tonnes_proxy` — **not** `regular_cargo_proxy_kg`. Annual tonnes are not proof of available commercial cargo permissions.
- All technical airport IDs, runway eligibility, six final-tier rules, source conflict queues and fictional **LYAL** stay unchanged. No Supabase, playable operations or final categories are authorized.

## B02 backlog

Finish country-source downloads, per-airport annual statistics and source-ID crosswalks for Chile, Colombia, Bolivia, Ecuador's passenger aviation, and the remaining territories. The whole B02 research batch is **PARTIALLY COMPLETED** only. Do not claim the source index establishes 2025 per-airport movement for unverified sources.
