# Airlinerra — consolidated trial registration and visual form review

- Header no longer displays a duplicate Register button. The 7-Day Free Trial CTA (header, hero, membership and closing) now navigates to /register.html, as does the footer trial link. The page accurately states both public registration and the seven-day trial are pending and no signup endpoint exists.
- The private invitation Sign in link remains in the header.
- Registration, invitation sign-in, private tester home and player-app content use the same desktop max content width of 1,220px, with responsive gutters. This is horizontal consistency; each page still has its own content height.
- On localhost:5188, email/password inputs are editable for layout review. Submission is intercepted, the password field is cleared and no Auth SDK or network is initialized. Password recovery is also visual-only, no email sent. This is NOT local login or a test of Supabase sign-in.
- On https://airlinerra.com the existing invitation-only authenticated behavior remains unchanged, including hosted provider restrictions and sign-in.
- No Netlify deployment settings or Supabase switches were changed. Follow owner GitHub main -> localhost review -> manual Netlify publication.
