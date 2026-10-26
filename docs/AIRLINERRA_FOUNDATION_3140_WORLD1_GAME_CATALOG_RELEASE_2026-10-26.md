# Airlinerra — Owner-authorized foundation release: 3,140 game airports in World 1

**Date:** 26 October 2026 · **Source of truth:** Supabase `hwllkabgzaynalahvkpz`, private schema `airlinerra` · **GitHub:** `main`.

## Decision and exact scope

The owner explicitly requested the original **3,140** runway-screened airports to become available for the *simulated Airlinerra game* so ongoing account-registration and airline-creation work is not blocked by the 3,906-airport US/global expansion verification program. This was implemented as the **first owner-authorized game catalog wave for World 1 only**, not a production web deployment or an assertion of real FAA/DOT, airport-owner, military, cargo or commercial operating permission.

**Migration applied successfully and audited in Supabase:** `airlinerra_owner_approved_original_3140_game_world1_20261026`.

| Independently verified metric | Value |
| --- | ---: |
| Original cohort identities | **3,140** |
| World 1 active in `airport_world_activation` | **3,140** |
| Active airports in private `airport_game_world1_catalog` view | **3,140** |
| Original foundation release member rows | **3,140** |
| Geographic country/source codes represented | **229** |
| Expansion cohort active | **0 of 3,906** |
| World 2/3 airport activations | **0** |
| Former commercial-access game approvals (FAA/operator/airport owner verified) | **0** |
| Final six-tier classifications approved | **0** — proposed tier values are retained |
| Public production website deployment | **Not performed** |

Every airport has a stable source ID, runway screen `RUNWAY_QUALIFIED`, recorded qualifying runway >=1,200m, geolocation, country and one of the six proposed tiers. All 3,140 original profiles remain intact. No source record, category approval timestamp, airport capacity, other research cohort or real-world commercial-access verification record was artificially modified.

## Six game-category proposals for World 1

| Provisional game-display tier | Original airports |
| --- | ---: |
| Local | **104** |
| Regional | **103** |
| Medium | **1,752** |
| Large | **906** |
| Major Hub | **205** |
| Mega Hub | **70** |
| **Total** | **3,140** |

These six are the **existing proposed categories**, not new owner-approved final economic/capacity categories. The private game catalog deliberately exposes them as `game_display_category`, alongside nullable `final_category` and explicit `category_finalized=false`. Any capacity-based flight scheduler must obtain separately approved slot and runway-specific operational rules before treating these tiers as authoritative.

## Exactly how the database was enabled

1. Created an explicit owner-scope audit record `FOUNDATION_ORIGINAL_3140_WORLD1_2026_10_26`, recording scope as **simulated game catalog only**, one world, exactly 3,140 airports and commercial/production permissions as **not established**.
2. Populated 3,140 members referencing the original-cohort foreign key. Constraints prohibit other cohort names, other worlds, and fabricated commercial permissions.
3. Revised the pre-existing `enforce_game_airport_activation()` trigger to accept the **exact authorized World 1 founding release** after checking original-cohort identity, airport registry runway qualification and six-tier game profile. For all other airports/worlds, the original strict access-certification+approved-category gate continues unmodified.
4. Inserted 3,140 active World 1 rows in `airlinerra.airport_world_activation`, with activation timestamps. All other world rows are absent.
5. Created the private, `security_invoker=true` read-only view `airlinerra.airport_game_world1_catalog` with country, airport code/name, municipality, geographic coordinates, qualified runway length/surface, minimum technical eligibility level and proposed game display tier.
6. Audited active World 1 count, cohort membership, release record coverage, existing real-world access approval state and privacy. Independently attempted unauthorized expansion and World 2 activation; both were correctly rejected by the trigger.

## Security and scope distinction

The research and original-cohort tables retain RLS. Both new release tables have RLS enabled, no `anon` or `authenticated` access and refer only to the authorized original cohort. The private catalog view also has no direct `anon` or `authenticated` SELECT permission. **The public Supabase Data API or signup UI has not been granted access automatically**; the account-registration integration must use a restricted server-side backend or explicitly reviewed read-only game-data endpoint.

Most importantly, `airport_access_reviews.game_admission_status` deliberately remains `NOT_APPROVED` because it means independently verified airport owner/commercial access. **Do not repurpose that status to claim FAA/air-carrier permissions merely because an airport is made available as a simulated game location.** This separation is the architectural reason the founding release can unblock the game catalog without falsifying aviation research.

## Reproducibility

- [Owner-authorized first-cohort SQL release and guarded trigger](./sql/AIRLINERRA_OWNER_APPROVED_ORIGINAL_3140_WORLD1_GAME_CATALOG_2026-10-26.sql)
- [World 1 3,140-airport smoke and negative authorization tests](./sql/AIRLINERRA_ORIGINAL_3140_WORLD1_RELEASE_TESTS_2026-10-26.sql)

## Handoff to the simultaneous account registration task

**Backend query (privileged internal service, not user-facing browser key):**

```sql
SELECT airport_key, airport_name, airport_code, country_iso, municipality,
       latitude_deg, longitude_deg, game_display_category
FROM airlinerra.airport_game_world1_catalog
WHERE world_number = 1
ORDER BY country_iso, airport_name;
```

The result now contains **3,140 options** for a home-airport picker. Do not count `airport_registry` (8,153 research rows) or all game profiles (7,046 proposals) as already playable. The other registration task should connect this private catalog via its authorized backend, ensure world 1 is selected, and test home-airport selection, country filters and creation of an airline against real installed game tables. UI/registration integration is **not proven in this release**.

## Subsequent expansion releases

Continue research on 3,906 expansion airports without blocking registration. Release smaller, explicitly approved groups later into World 1 by additional well-audited cohorts, keeping source provenance, qualifying runway rules, realistic simulated game constraints and separately authorized game-release decisions. Worlds 2 and 3 remain untouched. No premature final rejection of unreviewed candidates.

**Result: World 1 simulated-game airport catalog increased from 0 to 3,140 active records. Full playable account/airline/flight functionality still requires the separate application integration and category/capacity work.**
