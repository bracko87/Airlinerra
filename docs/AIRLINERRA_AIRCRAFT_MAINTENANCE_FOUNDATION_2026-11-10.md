# Airlinerra — Aircraft maintenance v1 (10 November 2026)

Status: **database + read-only per-aircraft planning, NOT operational maintenance activation**.

## Owner-approved gameplay policy
- No separate pre-flight maintenance action.
- Daily check: every 24 hours, 1 hour of downtime. All approved game airports.
- Weekly check: every 7 days, 3 hours of downtime. All approved game airports.
- A check: each 500 verified operating flight hours, 6 hours of downtime. Only an approved aircraft-type MRO location.
- B check: each 750 verified flight hours, 24 hours of downtime. Only an approved aircraft-type MRO location.
- C check: each 5,500 verified flight hours OR 24 months, whichever occurs first, 7 days of downtime. Only an approved aircraft-type MRO location.
- D / Heavy check: every 8 years, 21 days of downtime. Only an approved aircraft-type MRO location.
- Interval values are **game rules**, NOT real aircraft airworthiness instructions or legal certification. Real programmes vary by aircraft type/operator, and B is often bundled into other checks today.

## One condition value
- Store **one overall condition from 0 to 100** per individual airframe, no separate airframe/engine/cabin/avionics components.
- Condition is **NULL = unverified** until a trusted baseline is established. Do not seed arbitrary 100% or claim a catalog model's age is a particular acquired airframe's age.
- Store actual aircraft manufacture year only when sourced. Catalog production-start date is not manufacture year.
- Track total verified hours and cycles **since a known engine tracking baseline**. Do not label tracking totals as lifetime flight hours.
- Maintenance history stays blank until genuine service completions are received from a trusted game engine.

## Cost categories
Eight maintenance-cost groups (all 271 current aircraft configurations mapped via **game estimated MTOW / type tier**). These are provisional USD **game tariffs** for balancing, not vendor quotes.

| Group | Daily | Weekly | A | B | C | D |
|---|---:|---:|---:|---:|---:|---:|
| 1 Light utility | 30 | 100 | 600 | 1,500 | 10,000 | 50,000 |
| 2 Small commuter | 50 | 180 | 1,200 | 4,000 | 20,000 | 85,000 |
| 3 Regional turboprop | 90 | 260 | 2,500 | 8,000 | 35,000 | 180,000 |
| 4 Regional jet / midsize | 140 | 550 | 6,000 | 16,000 | 90,000 | 350,000 |
| 5 Small narrowbody | 240 | 900 | 12,000 | 30,000 | 200,000 | 850,000 |
| 6 Standard narrowbody | 300 | 1,100 | 18,000 | 48,000 | 280,000 | 1,200,000 |
| 7 Medium / large widebody | 500 | 1,900 | 32,000 | 85,000 | 600,000 | 2,500,000 |
| 8 Heavy / special | 1,000 | 3,500 | 58,000 | 160,000 | 1,100,000 | 4,800,000 |

Age modifiers (based only on verified individual build year, plus confirmed game date): 0–5 years 1.00x; 6–12 1.10x; 13–20 1.25x; 21–30 1.45x; 31+ 1.70x. If age is unknown, display the **base estimate only**, not a definitive payment price.

For example the existing Airbus A319-100 belongs to group 5. Its **base** C-check estimate is $200,000. It does **not** yet have a verified manufacture year or condition; no age-adjusted price is asserted.

## MRO capability registry
Separate from airport-facility hangar estimates. A hangar at an airport is not proof of particular model maintenance capability.

Initial research records:
- Singapore Changi WSSS — SIA Engineering Company: official publication of scheduled heavy maintenance up to D check, with model family capabilities. Initial owner-approved game A–D facility/model matches.
  https://www.siaec.com.sg/our_services/base_maintenance/airframe_maintenance.html
- Hamburg EDDH — Lufthansa Technik: candidate pending explicit location/airframe matching.
  https://www.lufthansa-technik.com/en/base-maintenance
- Istanbul LTFM — Turkish Technic: candidate pending current location/type scope verification.
  https://www.turkishtechnic.com/mro-solution/aircraft-maintenance-services
- Ezhou ZHEC — ST Engineering: real heavy maintenance facility, specific model scope pending.
  https://www.stengg.com/en/newsroom/news-releases/st-engineering-sf-airlines-open-airframe-mro-facility-ezhou-china/

Initial database acceptance: 4 provider/location entries, 316 game-approved configuration/check matches, all 271 aircraft configurations mapped to a group. This is NOT all possible worldwide MRO locations; research expansion remains open.

## Future maintenance scheduling requirements (not yet activated)
1. Verified aircraft position must be **grounded at the maintenance airport**. No teleporting an aircraft to a MRO.
2. A/B/C/D requires an exact approved configuration + check + provider + airport match.
3. Reserve the full check downtime with no overlap with flights, including turnarounds and existing checks. Prevent double booking of a hangar.
4. Explicit, costed maintenance positioning/repositioning flights to the site and back to the airline's hub must be independently authorised by the same trusted operations engine that handles normal movements.
5. Check payment and fleet condition update occur only on authenticated, completed service; price may vary with verified manufacture year and approved extra repairs. Quote must not be client-supplied.
6. On a higher-level check, lower-level tasks it already includes should not be billed a second time. Define check coverage before operational activation.
7. Update signed flight-hours/cycles once on **verified arrival** (idempotent event) rather than calculating per airplane every minute. A once-per-game-day maintenance deadline scan is adequate for future warnings.
8. The active operations worker, travel to/from MRO, line/base hangar capacity slots, maintenance work orders, grounding, payments and condition restoration must be separately implemented and proven before allowing booking.
9. Keep all of this isolated to Airlinerra's production Supabase project and GitHub main branch.

## Live readiness check on 10 November 2026
- Signed operated movement events: 0.
- Verified maintenance check completions: 0.
- Aircraft with a trusted usage-tracking baseline: 0.
- Game clock's confirmed date was NULL; clock_source = not_connected.
- Therefore no aircraft can accurately show a maintenance countdown, finished check, confirmed price adjusted for age, or proceed with a live booking.

## Technical references
- FAA AC 120-16F: maintenance intervals may depend on calendar, operating hours or cycles: https://www.faa.gov/documentlibrary/media/advisory_circular/ac%20120-16f.pdf
- EASA Part-145: provider approvals are limited by certified scope, location, aircraft rating: https://www.easa.europa.eu/en/the-agency/faqs/part-145
- Migrations: `20261110144000_airlinerra_aircraft_maintenance_foundation_v1.sql`.
- Policy engine: `server/airlinerra-maintenance-policy.mjs`.
- Read-only owner-verified endpoint: `/api/v1/player/fleet-acquisition`, action `maintenance-preview`.
- Player UI: each aircraft's page loads only its own maintenance preview; no new player startup import.
