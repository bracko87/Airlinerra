# Airlinerra — Licence 2: Four-Level Commercial Operating Licence

**17 November 2026 — PROPOSED DESIGN; not implemented, not approved for release.**  
**Supersedes:** the 14-level idea and the earlier automatic-with-AOC Licence 2 issuance idea. Neither obsolete draft should be used to activate game rules.

## Confirmed user direction

- Exactly **four levels**. Levels 1–3 restrict the **number of distinct airports served** and destination airport categories. Level 4 has no airport-count or airport-category cap and must be exceptionally hard to obtain.
- **No minimum aircraft quantity per licence level.** A Level 1 applicant still needs **at least one delivered aircraft ready to fly**, not a certain fleet size for Level 2/3/4.
- First application requires **at least 90 game days** since airline company registration, a valid own AOC (Licence 1), a registered home airport, Safety Rating at least **80/100**, no unresolved critical maintenance issues, and verified available company funds for **90 days of projected operating expenses**.
- Licence 2 is **indefinite (no renewal)**. Upgrade assessment may be requested **once every 365 game days**, and the applicant can **skip multiple levels** if it qualifies.
- Licence 2 is company-specific, not holding-wide. Its basic country-market rights are simple: EU/EEA companies get the EU/EEA market; others get domestic rights in their registered country; any company can run home-market↔foreign-country flights without individual country-by-country applications. No implicit standalone third-country↔third-country routes for non-EU/EEA companies.
- Temporary problems should prompt correction opportunities, with serious independent AOC or aircraft-grounding issues continuing to block unsafe operations immediately. Full suspension/revocation timing not yet final.

## Actual World 1 EU/EEA game-airport counts (read from Airlinerra Supabase, 17 November)

Source: `airlinerra_game.airport_sections1_8_combined_catalog_v1`, `world_id=1`, ISO countries EU27 + Norway, Iceland and Liechtenstein; distinct airport keys, categorized by `game_category`.

| Category | Group 1 existing cohort | Group 2 prepared/not commercially admitted | Combined |
|---|---:|---:|---:|
| Local | 8 | 73 | 81 |
| Regional | 4 | 30 | 34 |
| Medium | 188 | 2 | 190 |
| Large | 153 | 0 | 153 |
| Major Hub | 36 | 0 | 36 |
| Mega Hub | 4 | 0 | 4 |
| **TOTAL** | **393** | **105** | **498** |

EU countries **465**; EEA countries outside EU **33**. Of the four EU Mega Hubs in this game catalogue: **FRA, CDG, AMS, MAD**. The category data are **game estimates**; this does not establish real-world airport rank. Group 2 is **NOT yet commercially admitted**. Approval/readiness for actual flights is determined by independent game airport gates, NOT category lookup alone.

## Four levels — balancing figures for approval, NOT implemented

| Level | Maximum distinct served airports excluding registered home base | Category rules for destinations other than home airport | Potential EU/EEA catalogue pool* |
|---|---:|---|---:|
| 1 — Starter Commercial | **8** | Local, Regional, Medium | 305 |
| 2 — Established Commercial | **25** | Local through Large | 458 |
| 3 — International Commercial | **75** | Local through Major Hub; also at most **2 separate Mega Hubs** | 498 candidates, but at most 2 of 4 Mega Hubs concurrently |
| 4 — Global Commercial | **No game-licence airport cap** | Every airport category, no special Mega Hub cap | 498 (subject to each airport's real operational gate) |

*Potential pool means catalogue candidates, **not airports simultaneously servable** and **not currently all operational**. A licence's distinct-airport cap is much smaller than this available pool. EU/EEA and worldwide foreign airports share the SAME per-company cap; international flights do not circumvent the limit.

**Count by unique airport key**, not routes, departures, aircraft count or operating airline's fleet size. A return flight never adds extra airport entitlement. One registered **home airport is exempt** from the numeric and category restriction so a new airline headquartered at Frankfurt can operate at lower levels; other airports—including airline offices—are not automatically exempt. If a company serves both A→B and B→C, unique B/C airports both count unless one is its registered home airport. Do not restrict *flight frequency* by Licence 2; normal schedule, safety and slot rules continue to apply.

## Proposed assessment thresholds — NEED ECONOMY BALANCING

| Eligibility | Level 1 | Level 2 | Level 3 | Level 4 |
|---|---|---|---|---|
| Company registration age | **90 days** | 180 days | 365 days | **730 days** |
| Own active AOC | Required | Required | Required | Required |
| Ready-to-fly aircraft | **At least 1** | At least 1, **no fleet-size floor** | Same | Same |
| Home airport | Registered | Registered | Registered | Registered |
| Current AOC Safety Rating | ≥80/100 | ≥85/100 | ≥90/100 | **≥95/100** |
| Critical maintenance | No unresolved critical defects | Same | Same | Same |
| Liquid reserve | ≥90 days of projected costs | ≥120 days | ≥180 days | **≥365 days** |
| Demonstrated operating history | None required before first licence | ≥90 game days of genuine operations | ≥180 game days of genuine operations | **≥365 game days profitable in aggregate**, with no verified serious compliance issue in last 365 days |
| Minimum equity/net company assets | No arbitrary separate floor | No extra arbitrary floor | No extra arbitrary floor | **$50 million**, independently verified and not faked by loans without net assets |
| Processing period, approval fees | Prior proposal: 5 game days and $25,000 charged **only on approval** for initial application | Upgrade processing/fees undecided | Upgrade processing/fees undecided | Upgrade processing/fees undecided |

**Level 4's $50 million equity is a proposed economy-balancing threshold**, not a current verified game formula or real aviation licensing rule. Review it against game revenue and business accounting before final approval. 730 game days is roughly two real years under the current 1:1 clock; Level 4 is intentionally long-term.

**Annual assessment:** first approved licence starts annual upgrade eligibility at least 365 game days after last approved licence-level assessment. At that date the airline may request the HIGHEST level for which it qualifies, skipping intermediate levels. The first ever application after 90 days may only grant a higher level if it satisfies all requirements for that higher level (including operating-history requirements, so first-time companies without commercial flight records are not credited fictional history). An unsuccessful upgrade does not erase existing level and should not consume its annual successful-upgrade entitlement; anti-spam retry/cost rules remain to be decided.

Financial checks require actual game accounting, not invented balances, profit or cost forecasts. No commercial operation before initial Licence 2 approval may be required as a condition of Level 1.

## Warnings/loss — proposed common rules

- Rating falls below the **current level's** published safety threshold, cash reserve below the current requirement, missing registered home airport, unpaid mandatory charges, unresolved critical maintenance, or loss of a valid AOC can trigger the relevant warning/suspension rules. The safety threshold is NOT a fabricated second score; use the existing AOC Safety Rating.
- For correctable Licence 2 failures, start a provisional **90 game-day warning** with 30/60-day reminders. If unresolved, suspend the commercial licence while retaining the previous approved level; verify correction and reinstate without full reapplication.
- If rating remains ≥80 but falls below an upgraded level's higher standard, consider first a **level downgrade** to the highest still qualifying level rather than destroying the entire licence. Exact downgrade/grace handling is still to decide.
- Invalid AOC or unsafe aircraft must stop affected operations immediately under separate independent rules: commercial-licence warning grace never authorizes unsafe flight.
- Bankruptcy, dissolution, or proven fraudulent authority may produce revocation after independent verification, not a random game event. One company never changes sister companies' licences.
- Future route-limit downgrade/suspension must safely handle prebooked flights, affected airport access, refunds, current/airborne flight completion, and the same airline's asset rights before enabling enforcement.

## Research: analogous real-world licences

There is NO matching official *four airport-count / airport-category ladder* across the reviewed regimes; levels 1–4 are an Airlinerra-created commercial progression, not legally recognized categories.

1. **EU:** Regulation (EC) 1008/2008 contains the real operating-licence regime and oversight of licensed carriers, including financial conditions. Existing `EU_AIRLINE_OPERATING_LICENCE` catalogue code remains a regulatory reference, not a worldwide game grant. https://transport.ec.europa.eu/transport-modes/air/internal-market_en
2. **United States:** US Department of Transportation economic operating authority, separate from the FAA safety certificate. The DOT checks financial resources, managerial fitness and compliance, and monitors carriers after licensing. This is analogous in PURPOSE to Licence 2. Reuse the same four-tier Airlinerra game licence model for US airlines; do not add duplicate US-specific purchase/approval steps. https://www.transportation.gov/policy/aviation-policy/licensing/US-carriers
3. **United Kingdom:** UK CAA **Type A** and **Type B** licences, separated by aircraft weight/seating; finances are reviewed. These are real classes but NOT four airport-access levels. Since Airlinerra levels must not depend on aircraft counts, do not copy these as a separate competing ladder. https://www.caa.co.uk/commercial-industry/airlines/licensing/licence-types/operating-licences/
4. **Canada:** Agency domestic, scheduled international and non-scheduled international licences, with some differences by aircraft passenger capacity. These are service **scopes**, not an airport-count ladder. Keep international rights SIMPLE as already approved rather than creating every-country paperwork. https://otc-cta.gc.ca/eng/faq-air-licensing

**Avoid duplicate licences:** Airlinerra already separately lists cargo operations, charter/VIP operations, dangerous goods and airport slots/permissions in its reference planner; consider these later by activity, not as different national versions of Licence 2. Keep real-world legal details clearly distinguished from invented game balancing.

## Status

Research + proposal only. **No deployment, fee, AOC, licence level, permission issuance or operational airport access is changed by this proposal.** Existing live rules and the old planner text must be reconciled only after explicit confirmation and independent tests.
