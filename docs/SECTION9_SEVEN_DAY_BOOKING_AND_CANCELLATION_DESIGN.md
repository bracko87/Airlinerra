# Airlinerra — seven-day ticket booking and route cancellations
Status: DESIGN ONLY. Not a live booking, cancellation, or finance engine. 2026-11-12.

## Rules
- Route start preference: immediately when operationally eligible, or after 3 or 7 **game** days. First real departure is the first certified scheduled occurrence after both the launch date and readiness. Planning is not activation.
- Ticket reservation window: upcoming 7 game days. Only a certified, dated, saleable occurrence can receive reservations. Sales depend on demand, fares, competition, seats and time before departure; there is no guaranteed sell-out.
- Tickets are reserved but not paid upfront. No airline cash or earned revenue is credited at booking.
- When a flight completes, post realized fare, baggage, onboard service and cargo revenue and genuine operating costs once. No completed flight = no ticket revenue.
- Cancellation options: one dated future flight, all future unstarted flights immediately, or stop selling future inventory and operate the already-saleable 7-day window before route retirement.
- Protect every confirmed passenger booked on an affected flight across the entire 7-day window. At 48 hours or less before departure, escalate assistance/rebooking urgency and potential costs. Do not assume refunds for unpaid tickets.
- When cancelling, release only the aircraft occupation and the relevant **dated** airport slots after an atomic server transaction has recorded cancellation and passenger protection. Do not cancel a completed/in-progress flight or release a weekly airport slot reservation incorrectly.

## Necessary data and server transitions
1. Authoritative running game clock. Record route creation game date, desired launch delay and immutable planned retirement cutoff.
2. Server-created dated flight occurrences (not just weekly templates), with aircraft, departure, arrival, turnaround, and slots.
3. Per-occurrence seat inventory, booking and passenger reaccommodation records.
4. Route lifecycle states: draft, certified, saleable, flying, completed, cancelled, retired.
5. Validated owner-scoped cancellation command. Lock flight, bookings and dated aircraft/airport resources; record passenger obligations, cancel, release capacity, commit or roll back.
6. Idempotent completed-flight-only financial settlement; cancelled flights may incur rebooking/assistance costs.
7. Full audit history, failure retries and prevention of duplicate cancellations/settlements.

## Required verification before going live
- Test 0/3/7-day launches against the real game clock, seven-day advance selling, low/high demand, flight completion and finances.
- Test single-day cancellations, immediate route cancellation and retirement after the seven-day saleable window.
- Test passenger rebooking for every affected confirmed reservation and extra assistance within 48 hours.
- Test crossing midnight, daylight-saving differences, 24-hour turnaround, conflicts, release of dated airport slots and exactly-once finance.
- Never allow route edit/deletion from the browser to count as a verified server-side cancellation.

## Current implemented scope
- Game launch preference 0/3/7 is saved on route planning drafts only. It does not activate flights or sell seats.
- Route Details can cancel local drafts and owner-verified server planning routes, only when no operational schedule is attached.
- Actual bookings, dated flight cancellations, passenger rebooking, operational slot release, live engine and settlement are **not yet built**.


## Implementation update — 12 November 2026
- The protected airline flight-schedule API exposes a read-only, owner-scoped preview of seven upcoming **game calendar dates** for an operational schedule. It uses the authoritative World 1 game date, the origin airport's IANA timezone and DST validation. It reports **not saleable** and provides no invented booking counts.
- Private tables `airlinerra_game.section9_dated_flight_occurrences_v1` and `airlinerra_game.section9_passenger_reservation_batches_v1` are installed as versioned storage foundations. The tables currently have zero records.
- Both tables have row-level security enabled and direct `anon`, `authenticated` and `service_role` table privileges revoked. The first is constrained to zero booked seats, no ticket sales and zero earned revenue. The second permits only unissued reservation drafts, no payments and no earned revenue.
- The game still reports `actualFlightBookingsEnabled: false`, `engineEventProducerConnected: false`, and no operational schedules or certifications. Do not start sales, create confirmed passengers or settle flight revenue until those are corrected and tested end to end.
