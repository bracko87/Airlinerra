# Airlinerra — Batch 4 local readiness gate (2026-10-28)

Completed as local preview: homepage registration/sign-in links; invitation-only Auth; horizontal grouped player navigation; 3,140 approved World 1 airports and three real world rows exported from Supabase; local read-only country/airport search; local browser-tab draft and restore by exact airport key; Fleet, Routes, seven-day Schedule, Finances and local Settings page states; logout.

Still explicitly not complete: authenticated live hosted read API, production player-data integration, real airline creation, official legal consent, activation of any world, $5m ledger credit, actual aircraft inventory/route/schedule/finances and payments. No Netlify changes or remote DB writes.

Release acceptance: green GitHub tests; local owner review using `cd website && npm run preview` at 5188; verify no production passwords are entered in localhost demo, country DE and Berlin airport lookup, draft survives refresh in same tab, resetting country clears selected airport, sign out revokes local demo. Real game release requires separately approved legal and backend security gates.
