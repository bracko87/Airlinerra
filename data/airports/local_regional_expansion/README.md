# Airlinerra — Local and Regional expansion, second pass (23 October 2026)

## Scope and owner intent

This is a **non-production, non-authorized commercial-operations candidate screen** of the **5,012 real runway-qualified airports** in the 8,153-airport technical master that were **not** among the initial 3,140 source-`scheduled_service=yes` airports. All 5,012 have source `scheduled_service=no`; that signal does not establish the absence or presence of civil charter/cargo permission.

The objective is to expand the **provisional Local and Regional design-review pool only**, leaving original 3,140 entries, four higher game categories, and fictional LYAL completely unchanged. Do not count these candidates as approved passenger/cargo airports or activate them in Supabase/the game.

## Files

- [screened_5012.csv](screened_5012.csv) — every remaining technical airport with its source identifiers, geolocation, known runway details, reversible proposed Local/Regional tier (if any), rule, military/private-use flags, and non-activation status
- [candidates_local_regional.csv](candidates_local_regional.csv) — the **3,906** airports that satisfy the Local/Regional physical screen and have not been put on a military/specialized name-review hold; **3,904 still need basic civilian commercial evidence**, while only **two have some previously collected positive civilian-use evidence**, neither of which independently confers authorization for game operation
- [review_holds.csv](review_holds.csv) — **413** technically suitable but held airports: **266** military-name/review queue cases and **147** private/specialized-use name cases. Name-based holds are **not military-only determinations or permanent exclusions**
- [country_summary.csv](country_summary.csv) — country-by-country new Local/Regional candidates and review holds; 157 geographical source codes contain one or more airports in this second-pass screen
- [summary.json](summary.json) — exact record totals, pinned source references, and approval status

## Provisional screening rules — exactly six game categories overall

*Local/Regional only* second-pass technical rules:

1. OurAirports `small_airport`, qualified master runway **1,200–1,799 m**: propose **Local**.
2. OurAirports `small_airport`, qualified master runway **1,800–2,999 m**: propose **Regional**.
3. OurAirports `medium_airport`, qualified master runway **below 2,400 m**: **Regional candidate for design review**, not an automatic downgrade of an existing approved Medium airport; none of these 5,012 has an assigned final category.
4. All other source types/runway-length combinations: `OUTSIDE_TECHNICAL_SCOPE` for this particular Local/Regional expansion, **not rejection from worldwide airport research**.
5. For a technically eligible airport, put an **unverified military/mixed-use name or existing military-review queue entry** on hold unless separate positive civil-service evidence is already recorded; otherwise put **private/specialized-use name indicators** on hold, likewise unless prior civilian evidence exists. The name patterns are heuristics, not facts of airport operating status. Normal candidate cases still require operator/authority evidence before civil charter, cargo, or passenger eligibility can be approved.

The source itself already enforces the **open asphalt/concrete runway ≥1,200 m** technical runway threshold. Runway length and source type are preliminary game-design filters, not aircraft-specific operational certifications. Unverified civilian access is **not** the same as definitely military-only.

## Results

| Second-pass group | Count |
|---|---:|
| Provisional Local candidates needing civil operations review (across all selected cases) | 2,447 |
| Provisional Regional candidates needing civil operations review (across all selected cases) | 1,459 |
| **Selected for future Local/Regional civilian review** | **3,906** |
| Military-name / mixed-use review hold | 266 |
| Specialized/private-name review hold | 147 |
| Outside proposed Local/Regional technical rules | 693 |
| **All previously unreviewed real airports screened** | **5,012** |

With the *original 104 Local and 103 Regional provisional categories*, the review-only design pool becomes **2,551 Local and 1,562 Regional — 4,113 total**. The pre-existing **Medium (1,752), Large (906), Major Hub (205), Mega Hub (70)** remain exactly as they were. The candidate counts are **not** an approved 7,046-airport commercial roster, and are not additions to the production game.

## What comes next

1. Verify real-world civilian charter/cargo/public airport operations on the 3,906 shortlist, prioritizing candidate Local/Regional airports that actually serve communities; distinguish source-reported scheduled-service absence from legally allowed charter and cargo.
2. Review 266 military-name holds and 147 specialized-name holds without automatically removing civilian/mixed-use facilities. If an airfield is verified military-only, keep its technical historical record, but exclude it from any future playable commercial roster.
3. Before gameplay import, review current runway/aircraft compatibility, business rules, gates/terminal capacity and category approvals. Review source-code gaps separately; **never interpret a fictional game code as evidence of real commercial permission**.

All original airport/runway/identity records and `data/airports/startup/` remain unchanged. Re-run `python -m unittest discover -s tests -p test_airport_local_regional_expansion.py` to verify split and provenance. GitHub Actions has not yet been demonstrated running these new tests.
