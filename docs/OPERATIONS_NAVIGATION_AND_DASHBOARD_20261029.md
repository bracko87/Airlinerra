# Airlinerra - Operations navigation, company news and dashboard layout
Updated 29 October 2026.

## Navigation
- Dashboard stays separate.
- Removed the top-level Manager dropdown. My airline, manager profile and world rankings are available under **Settings**; existing airline setup is still conditionally accessible to users who do not have a company.
- Game Worlds and Airports moved from Operations to **Settings**.
- Operations menu now includes **Create a route** (#routes), **My routes** (#route-list), **Hubs and airport operations** (#hubs), **Flight schedule** (#schedule), **Cabin services** (#service), **Ticket prices and analysis** (#tickets), and **Personnel and staff** (#staff).
- Removed the orange 3px inset bar on the selected dropdown link. Selected pages retain a subtle blue background; top-level active navigation remains distinguishable.
- Settings dropdown scrolls for smaller displays rather than overflowing the viewport.

## Dashboard layout
- Upper-left: **Company news**, populated from owner-verified company registration and actual STARTING_CAPITAL ledger evidence when available. It explicitly states that the separate live alert/newsletter backend is not connected.
- Upper-right: airline traffic/statistics (truthful Not Available placeholders until live engine data).
- Below: **full-width Current Flights** table (up to 10 flights once the flight engine read service exists; no fabricated flights).
- Finance row: left is a **navy-and-orange doughnut chart** using actual available cash and recognized operating costs, never fictional slices. When no operating expenses are recorded, the chart is 100% verified cash; orange appears in the legend/brand treatment and becomes a proportionate slice only when genuine operating-cost entries exist. Right remains Income vs Expenses, empty until real operations.
- Full-width Management Insights remains below financial charts.

## Operations functionality and safety
- Existing approved-airport route workshop remains the **Create a route** workflow. It now maintains a list of up to 25 browser-session draft routes; saving a draft updates My Routes immediately.
- **My routes** lists and deletes browser-session drafts. No live-route creation or editing occurs.
- **Hubs** displays verified home airport; authorized approved-airport search can save/remove up to 10 *planned* hubs, not activate them or charge fees. Additional blocks describe gates, turnaround, ground handling, basing and connections.
- **Ticket prices and analysis** has editable passenger seats, average fare, assumed load factor, weekly departures, and operating cost per departure. It computes purely hypothetical passengers/revenue/cost/margin, and optionally saves inputs in browser session only. No demand feed or real ticket sales are implied.
- **Staff** provides 36 airline roles under Board/Executive, Flight Operations, Cabin Services, Engineering, Ground/Hub Operations, Commercial/Support. Every role supports user-entered planned headcount and gross monthly USD salary. Current employee counts are labelled Not connected, and total monthly and yearly *planned* payroll is calculated. No server hiring, contracts or payroll changes.
- The new operations module shares the existing account-scoped sessionStorage draft key, with collision-safe writes in the route-workshop module and immediate refresh events. No route, hub, salary, fare or aircraft write is sent to Supabase. Existing verified account, game world, cash and global release gate are unchanged.

## Verification
- Tests: `tests/test_operations_center_navigation.mjs`; updated menu/navigation tests and Dashboard finance/footer tests.
- Source checks: 22 expected page-view routes and 22 menu links, no duplicate element IDs. Dashboard DOM render test with real-style Panonian data successfully displayed a verified Horizon company milestone, full-width flight empty row and a cash doughnut. All altered .mjs modules passed syntax compilation in Code Mode.
- Local Node build/full regression suite and browser visual acceptance still require owner localhost review. No Netlify deployment or Supabase database changes.
