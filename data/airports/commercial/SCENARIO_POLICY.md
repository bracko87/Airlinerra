# Airlinerra gameplay scenario — NO WAR / no conflict-related aviation closures

Owner decision confirmed **2026-10-21**: Airlinerra is a fictional **no-war airline management world**. The current simulation must **not** replicate real-world war-related airspace closures, geopolitical combat threats, bomb damage, sanctions arising exclusively from an ongoing war, or airport suspensions caused by armed conflict.

### Aviation records and historical reference

- Preserve original runway-qualified airports and source IDs regardless of observed post-2021 real-world interruptions; **do not rewrite historical runway database or airport names automatically**.
- For countries whose real-world air services have been interrupted by war, use documented **pre-conflict passenger and freight operations** to inform the game's airport-service research. For Ukraine, use the **2021 pre-closure baseline** in `data/airports/commercial/group10/group10_ukraine_prewar_baseline.csv`.
- No-war/open-airspace means **no war-related blanket closure**, not that all technically runway-qualified airports have an unrestricted civilian operating certificate, commercial demand, terminal facilities or airline routes.
- Historical service YES is evidence for candidate passenger/cargo suitability, not automatic playable activation. Unproven airports remain UNKNOWN; military airbases require independent civilian permissions; genuine NON-WAR restrictions (ordinary airport closures, airport operator rules, runway works, noise curfews, airport slots) must still be respected.
- Any airspace/NOTAM historical notes resulting from war in other group data must be treated as **REAL_WORLD_ONLY / NOT_APPLICABLE_TO_NO_WAR_GAME** unless the owner separately requests a conflict scenario. Do not encode a universal wartime route block into the future game engine.
- International/local country or airport geography in the source data is preserved as a source convention and must never be changed simply to express a political conclusion.
- The scenario currently has **no asserted running route-engine enforcement**: commercial assessments and restriction CSVs are research-only, never a claim about deployed gameplay code.

This policy applies to **all Airlinerra airport groups and future commercial aviation screening**. Do not reintroduce the 2026 Ukraine-wide conflict-related closure in future audits.
