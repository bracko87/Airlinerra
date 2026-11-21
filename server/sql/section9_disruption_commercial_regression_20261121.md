# Section 9 — commercial disruption regression

Executed 2026-11-21 against the connected World 1 database. All test fixtures and mutable financial, maintenance, fuel and movement records were transactionally rolled back; no release flags were enabled persistently. The fixture setup temporarily provided activated schedule/capacity/certification evidence and, where needed, a paid-service maintenance record or initial approved fuel custody. The actual movement recorder, fuel receipt processing, maintenance usage, reconciliation, cost approval and finance posting functions were executed without replacing them. This is controlled integration evidence, not evidence of a live operated flight or of every schedule certification path.

## Signed lifecycle and finance

BEG–BUD, 60 minutes in flight, 45 minutes turnaround, 124 passengers at $50 each. Tested normal and +45 minute delayed variants independently. Both produced identical results:

| Metric | Normal | Delayed |
|---|---:|---:|
| Ticket revenue USD | 6200.00 | 6200.00 |
| Fuel burn kg | 1395.31 | 1395.31 |
| Remaining fuel kg | 1241.57 | 1241.57 |
| Flight hours added | 1 | 1 |
| Cycles added | 1 | 1 |
| Fuel cost USD | 1325.54 | 1325.54 |
| Airport/navigation cost USD | 9357.35 | 9357.35 |
| Net cash delta USD | -4482.89 | -4482.89 |

Finance posting, arrival fuel burn and usage replay protection verified. Simulation tariffs; crew, maintenance service expenses and ownership are not included in this per-flight settlement.

## Automatic dispatcher

With all seven disruption flags temporarily enabled in rollback-only transactions, directly invoked the existing scheduled dispatcher for four separate due-event cases: normal departure, delayed departure, normal arrival, delayed arrival. Each processed exactly one intended signed event without blockers; actual timestamp and fuel/usage receipt were verified, and rerunning processed zero duplicate movements. The arrival fixtures included a previously recorded signed departure and fuel custody. Technical decisions and replacement pair evidence were seeded for these dispatcher tests; the automatic decision-to-rotation and connection-cancellation integration was tested separately in the preceding development package.

## Cleanup and release

Verified zero test occurrences, movements, replacement pairs, passenger reservations, finance postings, departure and arrival fuel receipts, usage receipts, recovery receipts and maintenance-service receipts remaining. Schedule activation guard restored; existing dispatch cron active; cash matches ledger. All seven disruption release flags remain false. The live starter had daily/weekly maintenance due before testing; fixture service records were rolled back and do not clear actual maintenance. Final release review must consider multi-airline load, unresolved recovery, cargo exclusions, and cross-day scheduling; no universal scenario coverage is claimed.
