# Local full registration rehearsal — October 28, 2026

Access: `http://localhost:5188/register.html` and click **Try the full registration walkthrough on localhost**. The special page `/__local_registration__/` is served from `website/dev-only/` by the loopback server only; its HTML/JS/CSS are not part of Netlify `dist`.

Steps: choose a fictional `@example.test` identity -> simulated mailbox confirmation link -> type and confirm a *sample* password (never stored) -> select one of three game worlds, country from 229 and airport from the 3,140 approved World 1 snapshot -> choose airline name -> store only a browser-tab local onboarding draft -> open the local player dashboard. The dashboard shows this simulated identity; sign-out clears the demo session.

This is NOT a Supabase account, real email delivery, actual legal consent, or real airline creation. Production public signup and release gates remain closed. A real first-registration test will require an explicitly authorized isolated Auth/email service and verified hosted backend. Do not enter real credentials in this rehearsal. No Netlify deployment is necessary.
