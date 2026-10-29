# Airlinerra - Financial charts and site-wide footer
Updated: 29 October 2026

## Overview Dashboard
- Removed the former airline news panel and latest-transaction list from the bottom row.
- Added two balanced responsive SVG finance panels:
  - **Cash balance trend:** rendered only from actual owner-scoped financial ledger entries and verified current cash. The existing starting-capital transaction produces one real plotted point, **not** invented historical cash values.
  - **Income vs expenses:** recognized operating income and cost ledger entry types are grouped by recorded month. Starting capital is **not** operating income, and unrecognized events are omitted. Without applicable events the graphic shows a clear empty state, not zero-valued fake results.
- Added a separate full-width **Management insights** section below graphs, linking to Fleet, Routes and Finance. It offers local planning actions only; none place orders, create live routes or transact money.
- The existing top company/cash cards, current-flight placeholder and traffic-statistics placeholder remain. No fake flight, cargo, passenger, ranking or income data was introduced.
- Authenticated ledger responses and release controls unchanged. No new Supabase migrations or API endpoints.

## Site-wide footer
- Shared assets: `website/studio-footer.js` and `website/studio-footer.css`.
- The script transforms existing semantic footers into an identical responsive footer across the public homepage, manager page, registration, account, tester, Terms, Privacy, legal notice, FAQ and Pricing.
- Clock uses `Intl.DateTimeFormat` with `timeZone: 'Europe/Berlin'` and updates once per second. It displays Germany civil time and is labeled Game time, matching the game's 1:1 real-time schedule. It reflects the client system clock, not an invented accelerated simulation clock.
- Studio link: `https://nextqueststudio.net/`. Game cross-promotion: `https://propelotonmanager.com/` and `https://tennislegacygame.com/`, text-only.
- Includes Terms and Conditions, Privacy Policy, Legal Notice, FAQ, Pricing, Contact email, copyright year, company and time.
- New public FAQ and Pricing pages have honest descriptions of the seven-day trial, no automatic charges, and **no invented price** before pricing is set.
- The shared footer **retains the homepage's existing backend health widget and its event listeners** by moving the same DOM element rather than replacing it with a copy.
- The public health-check endpoint `/health.html` intentionally remains minimal for monitoring and is not a user-facing navigation page.
- Build script now copies FAQ, Pricing and both footer assets. Legal CSP is extended narrowly to `script-src 'self'` to allow the local footer module.

## Checks
- Four focused tests in `tests/test_financial_charts_and_studio_footer.mjs` passed with source and pure-function validation.
- SVG chart rendering was exercised with one real ledger point and hypothetical classified entries in local test memory only. Hypothetical entries were **not** written to any database or user ledger.
- Shared footer rendering and Berlin time updates were exercised with a DOM stub; cross-links, existing health node preservation and date/time formatting passed.
- Full `npm run build`, Node test suite and owner logged-in browser visual review remain to be verified in the owner's local development environment. Avoid claiming these were already run.
- GitHub main is the source; no Netlify deployment or production database mutation was performed for this change.
