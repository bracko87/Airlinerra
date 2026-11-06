# Airlinerra Section 5 — Airport Curfew & Noise status (6 Nov 2026)

**Truthful status: IN PROGRESS, NOT FULL RELEASE COMPLETE.**

## Work implemented this round

- New private security-invoker game catalog `airlinerra_game.section5_airport_game_restriction_catalog_v1`: all 3,141 approved airports with separate source-screened research, mandatory game time/runway rules, review-only rules, noise status, timezone, local clock windows, aircraft use type, calendar validity, weekday scope and primary-source links.
- Authenticated airport profile service now reads that catalog; Supabase Edge function `airlinerra-airport-profile` active **v10**.
- Player airport profile frontend displays a dedicated operating restrictions panel with links and precise classification. All evidence rendered as text nodes; URL links restricted to HTTPS.
- Route planner frontend now provides an optional catalog-aircraft and exact-UTC departure/arrival **read-only preflight**. Browser and same-origin Netlify relay to existing authenticated Supabase Edge preflight `airlinerra-noise-curfew-check` active **v5**. No simulated aircraft is treated as actually purchased/authorized.
- Added and tested private server-side `airlinerra_game.section5_reject_prohibited_flight_v1`: raises a rejection for a real confirmed game hard-rule conflict. It is intended for use inside the eventual schedule write transaction; it does not mutate schedules or activate commercial flights by itself.
- Verified French Toulouse decree (29 June 2026): departure and arrival scheduling limits take effect **1 January 2027**, with a temporary 2027–2028 arrival exemption needing operator-specific annual movement/slot ledger. Four machine-readable time rules now capture the 2027 and 2029 transitions. See https://www.legifrance.gouv.fr/loda/id/JORFTEXT000054341715/.
- Verified all three existing SQL regression suites after the change, plus a new World 1 acceptance suite covering Fukuoka night denial, Toulouse date transitions, time-only vs certified aircraft restrictions, full 3,141-airport catalog and the activation guard. All SQL tests passed in Supabase.
- Added source-level UI/preflight tests and CI workflow coverage; **GitHub Actions job results and a real signed-in browser UI check have not been independently confirmed.**
- Preserved prelaunch flags; no live flight scheduling writes, airline/flight operations, traffic rights, slots or finance data modified.

## Verified database counters

- Approved World1 airports: **3,141**. Researched positive operating/noise condition airports: **1,312**.
- Positive condition airports still requiring precise rule normalization: **1,246**. They are **not** all blanket airport curfews. Do not mark automatically enforced or erase those requirements without reviewing sources.
- Structured time rule records: **91**, covering **66** airports; mandatory time rule records **55**.
- Permanent automatically enforced runway-specific restrictions: **1**. Physical-runway and directional NOTAM/operating status evidence remains mostly unverified.
- Aircraft catalog configurations currently **272**. Aircraft noise certification table: **10** configuration-matched, **219** `CERTIFICATE_NOT_VERIFIED` at this checkpoint; other status levels exist. Additional **40** aircraft pending integration in another workstream. Universal gate uses dynamic configuration IDs, so no model-by-model engine edits are needed.

## Why we cannot truthfully say 100% completed

1. The 1,246 positive research cases require legal/operational source-specific normalization: runway ends, aircraft noise certificates, EPNdB quota counts, PPR permissions, seasons, weekends, DST and one-off NOTAM dates cannot be reduced to generic 24/7 closures.
2. The live game still has **browser-session route drafts**, not a transactional create/edit/activate flight schedule backend. The server-side mandatory rejection guard cannot block a write pathway that does not yet exist.
3. Airport runway status and actual matched aircraft noise certification remain incomplete; future 40 models are not all present. Real-world dispatch approval is always false.
4. UI source, route proxy and database endpoint exist, but a real authenticated hosted-browser end-to-end validation after deployment is required.

Tracked as [GitHub issue #9](https://github.com/bracko87/Airlinerra/issues/9).
