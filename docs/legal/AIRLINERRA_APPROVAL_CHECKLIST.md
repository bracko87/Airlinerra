# Production-onboarding legal release checklist — 2026-10-28

**Status: NOT APPROVED.** The authenticated read and onboarding APIs are coded. The new public registration form uses actual Supabase signup (not mock) but intentionally remains hidden until all required controls are genuinely active:
- Supabase Auth signup enabled with required email confirmation and official localhost/production callback redirect allowlist.
- Real Terms and Privacy HTML pages published with a reviewed `data-airlinerra-legal-approved="true"` attribute. Do not add this attribute before review.
- `airlinerra_game.legal_release_policy` contains exact approved, published Terms/Privacy versions and approval timestamp set by the authorized operator.
- `airlinerra_game.platform_release_gate` enabled and World 1 state `registration_open`; this does NOT mean the flight engine is operational.
- Local private DB connection available to the preview server; secure hosted backend in place before Netlify deployment.
- Automated tests and a genuine manual registration + real mail + write to DB + balance readback pass.

**Operator identification supplied 28 October 2026:** Next Quest Studio — sole proprietorship operated by Aleksandar Levnajic; Horst-Embacher-Allee 3; 22850 Norderstedt; Germany; Email: contact@nextqueststudio.net; German commercial register: not entered (as declared in the operator's existing Impressum). The owner supplied these particulars in a screenshot of the existing Next Quest Studio legal notice. This identifies the sole proprietor rather than inventing a separate company.
**Trial decision confirmed 28 October 2026:** A full seven-day trial starts after successful airline creation; neither registration nor trial requires payment details; no automatic conversion or charge; a paid subscription is available only after a separate explicit choice. These approved business rules are reflected in server policy, website and Terms draft.
**Still missing for Terms/Privacy approval:** subscription amount and interval, actual paid-checkout and withdrawal/cancellation conditions, expired-trial read-only/data-retention behavior; verified processor arrangements, retention periods and international-transfer information; applicable VAT or other mandatory business disclosures; and explicit approval of the final document versions. Do not mark them approved while those are open. Prepare approved policies and then enable the necessary provider/database release settings in a controlled release. The user's existing confirmed account can sign in now.

No Supabase release gates, user records or airline records were mutated during this code batch; no Netlify deploy occurred.

## Legal website pages added for local review
`/impressum.html` displays the owner-provided operator and contact information. `/terms.html` and `/privacy.html` are conspicuously labelled **review drafts**. They intentionally lack the `data-airlinerra-legal-approved="true"` marker and cannot unlock public signup. No production deployment or Supabase legal approval was made.
