# Airlinerra — Aircraft–Runway Performance Research Screen (2026-10-27)

**Status:** Implemented as **server-only source code** and unit tested. **NOT** a flight-scheduling release, aircraft certification service, gameplay activation or public API.

## Scope

- [Private numeric aircraft runway evaluator](../../server/private-aircraft-runway-screen.mjs) compares *externally calculated* aircraft-required takeoff runway (**TORA**), takeoff distance (**TODA**), accelerate-stop (**ASDA**) and landing distance (**LDA**) against an airport's effective published directional runway data.
- Requires explicit aircraft identifier, actual operating mass, a traceable performance calculation reference, flight phase and ALL distances required for that phase.
- The evaluator does **not** derive those aircraft performance demands from aircraft specifications; density altitude, obstacles, slope, wind, weather, runway condition and performance margins must be evaluated separately before operational use.
- A runway physical length is **never substituted** for an absent directional declared distance. Positive numerical sufficiency is labelled **research-only**.
- Runway-material verification, physical runway status, airport admission, scheduled carrier permission and direction-specific prohibition remain **independent holds**. Even if every hypothetical permission and numeric check passes, the returned `schedulingAllowed` is **always false**.
- Supports a **scheduled-passenger research scenario only**; cargo, military and charter-specific permission models must be added separately and cannot inherit passenger permissions.
- The [private inspection adapter](../../server/private-runway-inspection.mjs) is required for the optional wrapper; its World 1 catalog matching, source-effective-date filter and default-disabled switch remain unchanged.

## Regression examples

- **Melun LFPM**: takeoff RW28 has physical **1,972 m**, TODA **2,650 m** including clearway, TORA/ASDA **1,972 m**. A 2,000 m required TORA **fails** even though a 2,500 m required TODA **passes**.
- **Lannion LFRO**: 1,400 m required landing distance fails RW11 (**LDA 1,376 m**) but is numerically sufficient for RW29 (**LDA 1,463 m**). Unknown TORA/TODA/ASDA stays unknown.
- **Paris–Le Bourget LFPB**: numeric suitability never overrides airport-specific scheduled/charter prohibition or runway-direction takeoff/landing restrictions.
- **Orange LFMO**: macadam with limited concrete threshold sections and military restrictions never becomes independently verified asphalt/concrete runway suitability.
- **Unapproved French airport**: inspection produces no permissible game-airport candidates.

Local isolated Node tests: 12 synthetic cases passed with Node 22 before committing. The repository's separate committed runway-screen tests are included in the standard `website/package.json` test script and run through [non-deploying GitHub CI](https://github.com/bracko87/Airlinerra/actions/workflows/airlinerra-account-node-ci.yml).

## Prelaunch boundaries

The static website build continues to copy an explicit set of `website/` assets; none of the new server-only modules or test files are among them. No Netlify Functions, player-facing routes, Supabase schema migrations, game catalog writes, airline activation, six-tier classification decisions or aircraft scheduling changes were made.

The owner-approved World 1 catalog remains **3,140** entries, and the private source-runway pilot remains at **18 source versions** for 14 French expansion candidates outside World 1. The game release gate stays disabled. No user flight can currently be scheduled from this research evaluator.

## Remaining work

1. Add real aircraft model/variant specification records and independently derived aircraft takeoff/landing performance data under reference conditions.
2. Build performance calculations for departure/arrival mass, elevation, temperature, wind, runway slope/condition and applicable margins; verify with aircraft-specific references and synthetic boundary tests.
3. Build a *separately reviewed* effective airport/runway-game publication and permit/NOTAM/PPR framework tied to approved World 1 airports.
4. Only after an owner-approved release decision, integrate a different flight-scheduling authorization service. **Do not repurpose this evaluator as authorization.**
