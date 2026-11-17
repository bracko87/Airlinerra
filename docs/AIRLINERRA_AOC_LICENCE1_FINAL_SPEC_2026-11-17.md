# Airlinerra — Licence 1: Air Operator Certificate (AOC)
Decision specification — 17 November 2026
Status: Product rules finalized and clarified 17 November 2026; NOT active in the live game.
Scope: Game-only AOC, not a government aviation certificate.

## 1. Confirmed product decisions

| Setting | Agreed rule |
| --- | --- |
| Original airline | AOC issued automatically and immediately on successful original airline registration. |
| Original airline initial fee | $0. No manual application. |
| New, separately incorporated subsidiary | Must apply for its own AOC. Does not inherit parent/sibling AOC. |
| Subsidiary initial approval cost | $10,000, charged once upon successful issue. |
| Subsidiary processing time | 3 game days after application acceptance. |
| Certificate validity | 365 game days per issue or renewal. |
| Reminder | One notification 90 game days before expiry. |
| Renewal | Automatic server-side safety assessment, no manual renew button. |
| Safety threshold | At least 70/100 for successful renewal. |
| No completed flights | No penalty or renewal refusal on that basis. |
| Crew | Outside AOC scoring/renewal in the current development phase. |

Recommended game-balance setting, consistent with the simple-renewal design: automatic annual renewal and reinstatement cost $0.

All AOC timing uses the server's independently verified WORLD GAME DATE, not the desktop clock or the 60-real-day holding-registration rule. A frozen clock does not expire a certificate.

## 1A. Exact legal-company scope: NOT a holding-wide rating

The AOC and Airline Safety Rating are attached to the **specific separately registered COMMERCIAL AIRLINE / AIR OPERATOR company**, identified by its unique airline ID and world ID. They are NEVER issued to the holding/parent; the holding has **no AOC, no Airline Safety Rating, and no company-wide/aggregated Company Image score**.

In this game, AOC-eligible operating company business types include **passenger, regional, low-cost, cargo, commercial charter, and commercial VIP airline** (including mixed passenger/cargo operations under the appropriate later scope). These companies each have their OWN AOC validity, renewal clock, safety events, safety score, and corrective action register.

An **academy / flight training unit** and **aircraft maintenance / MRO business** do NOT receive this airline AOC solely for running training or maintenance. Such activities belong to their own future training-organisation/maintenance permissions, to be specified under separate licence reviews. An academy situated *inside* an airline is not a second commercial airline and does not receive a second AOC; the parent airline's commercial flying still uses its existing AOC. If an academy later also operates commercial passenger/cargo charter transport as a separate air operator, only that separately authorised commercial transport activity would bring it into AOC scope.

**Independence under a common holding:** Holding H may own passenger airline A and cargo airline B. If B's AOC fails renewal and B is grounded, **A continues flying with its own valid AOC**, subject only to A's own flight clearances. Neither B's incidents nor B's safety-score penalties change A's score. Company A also cannot use B's certificate. Never query by holding ID when applying AOC stop/reinstate/renewal; owner- and world-verify the exact airline/company ID. No group-average score, no cascading suspension or cross-company recovery credit.

A company can operate several aircraft or service types under its own AOC and relevant individual operating scopes: an incident belongs to that operating company, not automatically to other companies or the holding.

## 2. Original airline: immediate, free AOC

After owner-verified creation of the FIRST operating airline in a world, the trusted server creates one AOC entitlement and certificate for that airline, with no fee and without requiring a purchased aircraft. This AOC never automatically bypasses separate aircraft readiness, maintenance, slots, airport permissions, traffic rights or commercial flight release gates.

Persist owner/world/airline/jurisdiction, certificate source ORIGINAL_REGISTRATION, issued game day, expires game day, score policy version, immutable audit and idempotency key. No browser-created or manually edited certificates.

On release, the already-registered original airline must receive a ONE-TIME free backfill, dated from the verified release game day, not retroactively backdated to become expired. If no trustworthy current game day exists, keep issuance queued and the free entitlement intact; never invent a date, debit money or wipe the game.

IMPORTANT ENGINE COMPATIBILITY: current private operator-licence verifiers require an approved paid application linked to a ledger transaction. They cannot validate this free original certificate yet. Introduce a STRICT, owner/world-scoped, server-authorized free issue provenance and adjust the verifier safely; do not insert an unsupported "verified" row or bypass provenance checking.

## 3. Subsidiary: separate paid application

- A legal subsidiary and its funding must already be recorded in the parent holding's authoritative books; a regional/cargo brand or internal branch is not a separate company.
- Only the verified owner can apply. The application itself is free to submit. Accept one outstanding application per airline/AOC scope.
- A trusted reviewer evaluates after 3 VERIFIED GAME DAYS. Check lawful same-world subsidiary registration/ownership and ability to pay. In this simplified game phase, buying an extra aircraft, appointing crew or maintaining an arbitrary extra reserve is not an AOC-issue prerequisite. Operational flights remain independently gated.
- If approved, charge precisely $10,000 ONCE, in the same locked transaction as the AOC issue, and create an immutable finance ledger entry.
- If ineligible or underfunded, do not issue, do not charge and explain the failure; the owner can correct the situation and reapply. Replayed requests, review decisions or clock ticks must never charge twice.
- A subsidiary's own AOC is independent from the original airline and any other subsidiary.

## 4. Safety Rating — simple, auditable 0–100 rule

The AOC score is NOT customer satisfaction or Company Image. The latter may exist separately to affect passengers, sponsors and reputation, but must not decide whether an AOC renews.

A newly issued original/subsidiary airline begins at 100/100, labelled an INITIAL GAME BASELINE, NOT a verified real-world safety grade.

Deduct points ONLY for uniquely identified, server-confirmed GAME safety events associated with the correct airline:

| Verified game event | Points |
| --- | ---: |
| Normal flight, no flights, delays, low demand, cancellation | 0 |
| Routine aircraft maintenance or correctly grounding one aircraft | 0 |
| Minor verified safety incident | -5 |
| Serious verified safety incident | -20 |
| Major deliberate safety violation | -30 |

These event weights are initial BALANCING DEFAULTS to test, not existing live evidence. No random penalty roll, invented incidents, fake historic events, player-editable scores or crew penalties. Never treat a server-BLOCKED unsafe departure as an actual completed unsafe flight.

SIMPLE RECOVERY: current rating = clamp(100 minus the points from UNRESOLVED verified events, 0, 100). Completing a trustworthy, incident-specific corrective action marks that incident RESOLVED and restores its remaining points ONCE. Retain the incident in permanent history with evidence and resolution dates. Maintain two display counters: incidents in the most recent 365 game days and all-time incidents. Flight frequency alone never improves or degrades the rating.

**Grounded-airline correction loop (CRITICAL, otherwise the player can be trapped):**
1. The airline with expired AOC can still open its **Safety issues / Corrective actions** screen, view every unresolved evidence-backed event, request inspections, book maintenance, repair its aircraft, record an authorised safety review, and complete the exact remediation required for that event. These are non-commercial, non-flight actions and **cannot** be blocked merely because the AOC expired.
2. Every incident must contain an objectively achievable remediation path BEFORE its penalty can be enabled. Example: a specific verified aircraft-safety violation requires the corresponding aircraft repair plus a separate verified inspection/release; an organisational safety finding requires a confirmed corrective audit. Do not allow arbitrary money purchases to buy safety points, unrelated routine maintenance to clear incidents, or a random waiting timer that leaves the AOC permanently expired.
3. The protected server confirms event-specific corrective evidence, marks it resolved ONCE, and immediately recalculates the SAME airline's current score. Example: two unresolved serious incidents lower 100 to 60. Fixing either verified serious incident removes its 20-point unresolved penalty and produces 80; its historical occurrence still counts.
4. When this airline's score is >=70, the trusted signed game-clock worker **automatically reinstates that same company's AOC**, without waiting for the next annual review and without requiring a flight. Normal independent flight readiness gates remain.
5. If the remediation system or game-day clock is unavailable or incidents cannot practically be corrected, the game **must not** enforce a renewal failure that leaves the player unable to recover. Build and positively test the corrections path before release of rating-based expiry.

An expired airline never needs to fly to regain its AOC, and its sister companies may operate normally throughout.


### 4A. Guaranteed, paid recovery and no stranded score (confirmed 17 November 2026)

**No unresolved incidents = 100 Safety Rating** under the approved model, even when the airline has a severe historical incident record. All historical incidents still count in the last-365-game-days and lifetime counters, but verified-and-resolved incidents **never keep deducting current score points**.

**Authoritative formula:**
`safety_rating = max(0, 100 - SUM(penalty_points for unresolved verified safety incidents of THIS airline))`

The rating is DERIVED from the incident ledger on each material safety update and before every AOC renewal/reinstatement, not stored as an independent manually mutable total. Therefore an airline cannot legitimately have no outstanding safety incidents and a rating below 70.

**Recovery is not free.** Every actual remedial operation (aircraft repair, specialist safety inspection, mandatory reinspection, compliance audit or corrective training when that future system exists) must have a real nonzero GAME fee/cost charged **to the affected airline company's own cash**, with a protected ledger transaction, before that action can count as complete. The AOC annual renewal and automatic reinstatement themselves stay **$0**, as already agreed; the company pays for the actual corrective work, not simply to buy points.

**Payment and completion flow:**
1. A recorded incident lists one or more SPECIFIC corrective tasks that resolve its underlying cause; show each task, eligibility, expected cost, game time/duration, airport/provider if relevant, and evidence required. The player can view incidents free of charge but cannot execute the corrective work for free.
2. Quote each action from its supported game service/maintenance pricing rules. For aircraft work, use the existing model/age/condition/workshop prices where established. Separate specialist reviews/inspections must also have an explicit **nonzero, approved game price** before the feature can be released. Do not guess a worldwide real-world fee or fabricate an invoice. The player must see and approve the GAME cost before it is committed.
3. Book and pay through the trusted owner-verified, airline-scoped game ledger; spending by a holding or a sister airline is NOT automatic. If insufficient funds, the task cannot complete and the rating stays unchanged. If funding is later legitimately transferred to the company through the separate holding treasury system, it can then pay for its own task.
4. The independent game maintenance/inspection service records a genuinely completed corrective task (including necessary duration and resulting evidence), not merely a payment. A paid-but-unperformed repair DOES NOT remove a safety penalty. Each charge and completion has an idempotency key; never double-debit on retries.
5. Once all mandatory paid corrective tasks for a particular incident are VERIFIED complete, mark that incident resolved and immediately recalculate its company's rating. The original incident remains in immutable history.
6. If the refreshed rating is >=70 and the relevant clock/ownership evidence is valid, automatically reinstate the same airline's AOC; aircraft still need their own dispatch clearances.

**Fail-safe for the player's exact concern:** If the interface ever shows **zero unresolved incidents but a Safety Rating below 70**, that is a score/data-consistency bug, NOT a legitimate reason to keep the airline grounded. The server must recompute from the authoritative incident records; with none unresolved it yields 100. Do not invent a secret penalty, request another paid repair when no underlying problem exists, or require the player to operate flights. Record/alert the mismatch and repair the derived display. There is no charge to correct a SOFTWARE/accounting inconsistency; the player already paid for all real corrective work.

**No dead end:** Each future penalty category MUST ship with an executable, fully priced, positively tested non-flight corrective path before its event type can start deducting points. Unsupported/unremediable incident types cannot cause AOC renewal failure. This applies even if the airline AOC is expired and all aircraft are grounded. If the ability to view, quote, pay for, and independently complete corrective tasks is down, fail safely rather than permanently denying an otherwise eligible renewal.

**Acceptance cases:** no open incidents + score shown as 60 => recompute to 100 without another fee; two -20 incidents => 60; after paying and completing ONLY the first full task => 80; second paid task => 100; uncompleted task despite payment => 60; insufficient airline cash => no completed task/no score recovery/no balance change; duplicate task/fee receipt => only one charge/one restoration; holding/company B payment or completion cannot repair company A's safety rating.

Until signed incident and corrective-action systems actually exist, do NOT invent incidents or enforce penalties from missing data. Display the initial/no-confirmed-events baseline honestly, and never deny renewal due to a read failure or missing future scoring system.

## 5. Annual automatic review, expiry, reinstatement

If issued on game day D, certificate is valid for the exact half-open interval [D, D+365). It reaches expiry at D+365.

- D+275: record and send one "AOC expires in 90 game days" notification, with current score and verified unresolved items. No duplicate notifications on worker retries.
- D+365: one authoritative, atomic renewal decision using score verified at that game day. If score is 70–100, renew automatically for another 365 GAME DAYS from the renewal boundary, fee $0.
- If score is below 70 at the expiry boundary, status becomes EXPIRED — RENEWAL FAILED. The server blocks commercial departures requiring this AOC. It does not delete aircraft, routes, registration, cash, history, or existing maintenance appointments.
- Once verified corrective actions raise the score back to 70 or higher, the trusted server automatically REINSTATES the AOC for 365 game days from reinstatement, without a manual application or fee.
- If no incidents are recorded, the starting score remains 100 and renewal passes. If the incident feed, clock or review service is temporarily unavailable, leave the decision PENDING; do not fabricate negative safety evidence or impose a false loss.
- No arbitrary pre-expiry AOC suspension/revocation scenarios for missing crew, temporarily grounded aircraft, all aircraft being unavailable, low company image, low cash or lack of routes. Separate flight-level maintenance and safety block rules continue independently.
- A permanently dissolved company is handled by the future company lifecycle; do not build an unrelated speculative revocation game.

All processing must be idempotent, owner/world scoped, and safe for cron retry, clock stoppage, missed daily runs, and duplicate review events. Once per day check and enforce expiry in a verified server worker.

BOOKINGS SAFETY GATE: do not activate AOC-dependent departure cancellation until atomic cancelled-flight ticket booking/rebooking/refund and no-charge settlement paths have been verified. Preserve schedules and player finances.

## 6. Licences & Permits UI

Original airline: "AOC — Issued automatically with airline registration — $0".
New subsidiary: "Apply for AOC — $10,000 — 3 game days" when eligible and when applications actually open.
Common display:
- Status: Active / Renewal approaching / Application under review / Expired (score below 70) / Reinstated.
- Issued game date, expires game date, next review, 90-game-day notification.
- Safety Rating (initial score prominently labelled, never claimed as certified safety), last-365-day incidents, all-time incidents, unresolved verified incidents and corrective actions, if supported.
- "Automatic annual renewal — free". No renewal button, and no original-airline AOC application form.
- Clear status/reason if checks fail. All money amounts show without trailing ".00".

Before release the page must clearly say "Planned — not yet enabled", not show a fabricated issued AOC or deduct funds. Keep rules separate from the new EU operating licence, aircraft certificates, traffic rights, slots and maintenance permissions.

## 7. Current state and implementation gap (checked 17 November 2026)

Database AOC reference: $10,000, processing 3 game days, enabled_in_game=false. Issuance policy: 365 game days, release_enabled=false. At inspection, zero recorded applications and zero issued operator-licence evidence rows. Existing planner text incorrectly proposed $150,000 and 7 game days for subsidiary and ongoing validity. This spec supersedes that read-only draft.

No active Safety Rating / signed incident registry exists. The existing issuer needs new first-airline free-provenance handling, auto-renewal and zero-fee reinstatement. In particular, its ledger-linked paid-AOC assumption is incompatible with the confirmed free original and free renewal rules.

No AOC policy, fee debit, live airline permission, flight operation, player account or scheduled worker is changed by authoring this spec.

## 8. Implementation acceptance tests before any activation

1. Original airline creates or backfills exactly ONE free AOC for the correct airline/world, without changing seed capital. First/original identity stays stable even when holding structure is created. A parent holding never has an AOC or aggregated Safety Rating / Company Image.
2. Subsidiary gets NO inherited AOC. A separate application processes at +3 game days. Approval charges one $10,000 ledger entry; rejection/insufficient funds charges zero. Replay charges zero.
3. Reminders happen at exactly expiry minus 90 game days, once. Validity boundary D+364 active; D+365 renews if score >=70 or expires below 70; no off-by-one errors.
4. No flights, maintenance-only downtime and lack of crew do not cause negative events or expiry. A company image of 0 does not reduce AOC Safety Rating.
5. Verified incident event IDs deduct -5/-20/-30 once; an authorized, linked correction resolves only that event and restores its penalty once. Scores clamp 0..100; show last-365-day and lifetime incident counts without deleting history.
6. Expired airline with a verified score recovery automatically reinstates for a new 365 days; affected commercial flights cannot depart during expiry but aircraft/route data is preserved.
7. Frozen or unsigned clock, unexpected service outage, skipped days, repeated cron, forged browser score/certificates, foreign airline ID, rejected owner and cross-world attempts never invent new AOCs or charges.
8. Before enabling expiry enforcement, prove that cancelled-flight bookings/refunds and financial settlements handle denied flights safely. Verify protected UI and real-world staging integration.
9. A passenger or cargo sister airline keeps its flights when a different separately registered sister company's AOC expires; no cross-company score contribution, no holding-level score, no global holding suspension. Academy/training and MRO business types have no commercial-airline AOC merely for operating their own activity.
10. Confirm an AOC-expired airline can request/complete event-specific maintenance and inspection or compliance corrective actions without flights, restore a verified score from 60 to 80, and automatically regain its OWN AOC. Historical incidents remain. Never release a penalty event without a working correction mechanism.
11. Only after explicit deployment/release acceptance may private policy flags change. Do not automatically activate the game while implementing or reviewing this document.

## 9. Source references and game-versus-real distinction

Existing game code: website/licensing-planner.mjs; website/game-permission-applications-view.mjs; docs/SECTION9_GAME_PERMISSION_APPLICATION_LIFECYCLE.md; docs/SECTION9_PERMISSION_PLAYER_APPLICATION_API_UI.md; supabase/migrations/20261113211000_section9_global_game_licence_fee_policy_draft_v1.sql; supabase/migrations/20261113217000_section9_private_signed_game_permission_auto_review_v1.sql.

AOC continuous oversight in actual European aviation is separate from this game's invented annual expiry mechanic: https://www.easa.europa.eu/en/domains/air-operations/air-operator-certificate-aoc ; https://eur-lex.europa.eu/eli/reg/2012/965/2026-02-22/eng.

NEXT: Implement and independently test Licence 1 before opening its rules. Licence 2 to be reviewed separately.
