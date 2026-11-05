# Airlinerra passenger popularity (2026-11-05)

## Implemented
- Private Supabase table: `airlinerra_game.aircraft_passenger_popularity_v1`.
- One rating per passenger or combi configuration, integer 1–6.
- 151/151 passenger-capable configurations rated (140 passenger, 11 combi). 84 cargo-only configurations intentionally have no rating.
- Baseline values are **game-design estimates** for passenger appeal, not real passenger survey data, objective aircraft safety scores, regulatory approval or individual airframe condition.
- The private aircraft-library API joins and serializes the score and multiplier; Supabase Edge Function `airlinerra-aircraft-library` version 9 deployed.
- The aircraft profile places a blue/gray six-block indicator in the final highlight tile after Noise chapter. Cargo configurations show Not applicable.
- Read-only calculator deployed: `airlinerra_game.adjust_passenger_demand_for_popularity_v1(configuration_id, base_passengers)`. Returns NULL for cargo, missing or negative demand. It does not activate flights.
- Production database migrations are mirrored in `docs/sql/AIRLINERRA_AIRCRAFT_PASSENGER_POPULARITY_V1_2026_11_05.sql` and `docs/sql/AIRLINERRA_AIRCRAFT_PASSENGER_DEMAND_CALCULATOR_V1_2026_11_05.sql`.

## Game-balancing values

| Popularity | Baseline passenger demand multiplier |
| --- | --- |
| 1 | 0.60 |
| 2 | 0.75 |
| 3 | 0.90 |
| 4 | 1.00 |
| 5 | 1.15 |
| 6 | 1.30 |

Sample database assignments: Airbus A350-900 = 6, Airbus A320neo = 6, Boeing 787-9 = 6, Boeing 737-800 = 5, Airbus A340-300 = 4, Ilyushin Il-62M = 1, Tupolev Tu-154B-2 = 1, Yakovlev SJ-100 (PD-8) = 4.

Ratings are model-specific. Historic designs may receive lower scores, while new but less familiar aircraft do not automatically receive a 6. They are adjustable balancing assumptions.

## Not yet activated in flight sales

Live flight scheduling, real passenger offers, bookings, fare competition, airport/route demand and aircraft-condition calculations are separate work. The new calculator and database are **not** connected to those live workflows. Do not claim passenger sales or occupancy is already affected.

When implementing real demand:
1. Start with the route/date/market baseline and permitted origin/destination.
2. Read the selected **passenger or combi aircraft configuration ID** and the stored popularity multiplier; apply it **once** to the baseline passenger interest before calculating confirmed passengers.
3. Apply ticket price, frequency, service quality, punctuality, competition and individual airframe condition as separate factors. Avoid counting model age twice.
4. Cap carried passengers to available seats and operational constraints; do not generate passengers without route demand.
5. For cargo-only aircraft, do **not** apply passenger popularity to cargo demand or capacity. Combi passenger and cargo constraints stay independent.
6. Add simulation tests for score 1 vs 6, all 151 rated configurations, missing/invalid values, cargo-only, low/no demand, and mixed-fleet aircraft assignments.

The popularity factor is a commercial passenger-choice modifier. It must never bypass runway, certification, curfew, noise, licensing or flight-release gates.
