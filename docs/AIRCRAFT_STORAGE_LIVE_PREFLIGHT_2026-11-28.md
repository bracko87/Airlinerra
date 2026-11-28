# Aircraft storage live preflight — 28 November 2026

Read-only audit of the current Airlinerra game database. No production writes, deployment or activation authorized.

## Database compatibility
- Four source function fingerprints and the ledger valid_entry_kind constraint matched the exact reviewed hashes (5/5).
- All nine airport identities matched source type, source ID, country, source ident and GPS code.
- All 271 live catalogue rows matched reviewed configuration ID, family ID, variant ID and configuration code; 271 distinct IDs, zero mismatches.
- No relations or functions in airlinerra_game beginning aircraft_storage_ or storage_ were present; no storage scheduler job matched the audited name/command predicates.
- Blocked candidate SHA-256 3e9e6fa6e17f0036f3e2beb5ce1eb9d5683d2d9447d4241018386c554e40edec, last verified workflow 46154422547. Persistent clone run 46151229346. No installation SQL modified by this audit.

## Live commercial policy prerequisites
World 1 current policy:
- automatic_dispatch_event_isolation_enabled=false
- automatic_normal_crew_enforcement_enabled=false
- delayed crew binding_enabled=false
- crew movement capture_enabled=false

The storage dispatcher adapter requires exclusive atomic binding for a storage-aware commercial handoff. It rejects storage handoffs when atomic event isolation is off, when delayed or downstream binding is required, or when the storage commercial binding gate is disabled. The signed departure trigger also requires the storage handoff and legacy capture release. No activation of storage-aware crew handoffs is authorized with the present policy.

Important limitation: current patched dispatcher evaluates storage handoff/custody after automatic fuel supply. In the legacy non-atomic branch a rejected handoff can leave a verified fuel top-up (no departure, booking closure, receipt or crew binding). Existing synthetic no_atomic regression explicitly permits this effect. Before any operational activation, resolve the ordering/atomicity gap, test disabled-state normal dispatch and legacy arrivals and ensure failure cannot create an unintended fuel effect. Do not enable global atomic/normal crew/capture policies just to bypass this gap. Any SQL change requires renewed exact-digest rehearsal and candidate review.

The installed-but-disabled design seeds no storage handoffs, crew reservations or commercial departure evidence. Existing ordinary commercial rows should not meet the new storage-history predicates. However, shared movement and crew triggers execute on legacy tables; the commercial departure trigger takes an airline row lock even with no storage handoff. Existing synthetic branch acceptance and schema compatibility do not establish live lock-order parity or full commercial runtime equivalence. Review concurrency and disabled-state behavior before installation approval.

## Remaining before production installation approval
- Verify backup/PITR availability and recovery point through the project dashboard or authorized backup evidence; current connector has no backup inspection action. Do not claim a backup was taken.
- Complete disabled-state commercial trigger/lock review and agree treatment of the non-atomic fuel ordering gap.
- Recheck current source fingerprints and main revision before execution; no authorization inferred from a successful preflight.
- Prepare separate approved execution boundary; blocked candidate remains blocked.

Individual airport operational statuses, pavement/access policies, Roswell independent runway correction, 271 billing class approvals, application deployment and scheduler/booking activation are separately gated.

No production writes performed.
