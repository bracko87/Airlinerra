# Production-onboarding legal release checklist — 2026-10-28

**Status: NOT APPROVED.** The authenticated read and onboarding APIs are coded. The new public registration form uses actual Supabase signup (not mock) but intentionally remains hidden until all required controls are genuinely active:
- Supabase Auth signup enabled with required email confirmation and official localhost/production callback redirect allowlist.
- Real Terms and Privacy HTML pages published with a reviewed `data-airlinerra-legal-approved="true"` attribute. Do not add this attribute before review.
- `airlinerra_game.legal_release_policy` contains exact approved, published Terms/Privacy versions and approval timestamp set by the authorized operator.
- `airlinerra_game.platform_release_gate` enabled and World 1 state `registration_open`; this does NOT mean the flight engine is operational.
- Local private DB connection available to the preview server; secure hosted backend in place before Netlify deployment.
- Automated tests and a genuine manual registration + real mail + write to DB + balance readback pass.

**Information missing to approve Terms/Privacy:** legally registered/proprietor name, business address, support/privacy email, payment/trial terms and withdrawal policy, confirmed data processor/legal transfer arrangements and retention periods. These cannot legitimately be invented. Prepare approved policies and then enable the necessary provider/database release settings in a controlled release. The user's existing confirmed account can sign in now.

No Supabase release gates, user records or airline records were mutated during this code batch; no Netlify deploy occurred.
