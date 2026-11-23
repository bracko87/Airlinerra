# Airlinerra — development milestone and remaining-work overview
_Date: 2026-11-23. Development branch: `phase-14h-crew-integration`._

## What is confirmed by this branch's verification suite

- Certified synthetic FRA–MUC round-trip activation, rollback on either leg,
  replay and booking-capacity safety. Fixtures are synthetic; not operational
  certification of actual fleets or airports.
- Unchanged direct passenger booking and real two-leg demand-conversion
  workflows, including reviewed *undeployed* ticket-writer correction,
  worker locking and independent overlapping-itinerary races.
- Original connecting-passenger recovery function: permitted recovery,
  replacement of disrupted second leg, rollback on ticket insertion failure,
  replay, concurrency with a connecting-ticket issuer in both orders.
- Original unflown cancellation function: safely refuses operated,
  financially prepared, revenue-recognized and upfront-paid reservations.
  The player-initiated active-flight cancellation endpoint remains disabled.
- Original final financial posting: isolated full USD 300 revenue / USD 100
  expense / USD 200 cash-delta receipt, stable replay and transaction rollback
  on an injected receipt-write failure. Also tested posting mutex and original
  posting versus original cancellation on preclosed prepared flights in both
  session orderings.
- Owner-scoped read-only cancellation assessment surfaces booking/financial
  blockers; website and backend static builds and regression tests are green.

## Boundaries on what the tests mean

The CI database is disposable PostgreSQL 17 and uses synthetic signed
operational evidence for many cases. Passing tests does **not** imply
production deployment, working real-world flight/crew/fuel proof, or
complete player-facing gameplay. The candidate two-leg ticket bug fix is
in `supabase/migration_candidates/`, not an applied migration. No live
airline balances, flights or bookings were changed by these tests.

The latest verified CI run is
https://github.com/bracko87/Airlinerra/actions/runs/45210407030 .

## Prioritized outstanding work

1. **Signed movement versus cancellation:** independently test the real
   signed departure and arrival publication functions against unflown
   cancellation. Detect and correct any non-atomic boundary between state
   transition, signed movement, capacity and cancellation.
2. **Real arrival-to-money chain:** integrate signed engine events,
   measured fuel receipts, approved final costs, ticket reconciliation and
   the actual money writer, rather than mocked evidence. Include rollback,
   replay, mid-flight changes and interruption scenarios.
3. **Connecting-ticket deployment decision:** review the private writer
   correction, ensure production migration safety, reviewer approval,
   rollback procedures and security audit before installation.
4. **Refund eligibility:** trace actual collection/refund identifiers,
   design approved compensation journal and test idempotent passenger
   recovery. A quoted fare is not an actual refunded payment.
5. **Player-facing operations:** audit each UI entry point against real,
   authorized backend actions. Prioritize working schedule/route list,
   booking status, availability, operations and finance evidence in the
   game UI. Do not expose held/cancelled operational controls prematurely.
6. **Broader release validation:** airport group activation, fleet/crew/
   maintenance/fuel rules, security and permissions, live world-clock
   scheduling, economics and real player end-to-end journeys must pass
   acceptance. Verify independent features instead of inferring readiness
   from section-9 CI.
7. **Production release:** maintain a reviewed staging rollout, regression
   and reconciliation checks, operator approvals, deployment/rollback
   plan and monitored post-release game-control center.

## What is and is not ready to release

**Ready for continued development and review:** the verified isolated
regressions and the read-only owner-scoped safety evidence.

**Not approved for public activation:** player active-flight cancellation,
refund execution, the reviewed connecting-ticket writer migration and
the unverified real movement-to-settlement production lifecycle.

No reliable total-project completion percentage can be inferred without
a feature-by-feature production UI and gameplay acceptance audit.
