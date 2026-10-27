# Airlinerra prelaunch email sender — NextQuest Studio (2026-10-27)

**Owner decision:** Use the existing NextQuest Studio corporate domain **`nextqueststudio.net`** as the outbound sender for Airlinerra invitations, confirmations and password recovery instead of registering a fourth sending domain. **Never remove or replace any existing Resend domain.** Airlinerra's official website remains `https://airlinerra.com`.

## Proposed sender configuration

- From display name: `Airlinerra — NextQuest Studio`
- From address: `noreply@nextqueststudio.net`
- Email verification, invitation and password reset callback website: `https://airlinerra.com/account.html`
- Sender purpose: authentication and transactional emails only, not Tennis Legacy health alerts or mass promotional email.
- Resend account: use its existing company sender-domain registration; do not register `airlinerra.com` or buy an upgrade merely to use a separate From address on the verified company domain.
- **Status: NOT LIVE.** This exact corporate domain is currently `failed` in Resend, so do not attempt SMTP delivery using it until Resend confirms `verified`.

## Domain verification prerequisites

Public authoritative delegation of `nextqueststudio.net` currently points at Namecheap DNS servers `dns1.registrar-servers.com` and `dns2.registrar-servers.com`. Public Google DNS lookup on 2026-10-27 confirmed that Resend's sender-specific `resend._domainkey.nextqueststudio.net` TXT and `send.nextqueststudio.net` TXT/MX records were missing. Resend's dashboard separately marks the matching DKIM, SPF and MX records `failed`.

Set the **following Resend-provided records in the currently authoritative DNS zone** after confirming the labels and that no existing records would be overwritten. Names below are relative to `nextqueststudio.net`.

| Type | Host | Resend-provided value | Priority |
| --- | --- | --- | --- |
| TXT (DKIM) | `resend._domainkey` | `p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDUWKJNYmodtdY3XyEeaClwh6zn3msg4h4T0GB2q7Lyc7bv9jDYPVnuRp/EHt8OrPpCGIXj+1Tbv3SF2wxHXg2bM0LOV54LqmWGxibwtieNWJ+wrIxVtlscycFWXMVLMo4tu/Ezpj6HmEACb/puEckEqjlRtjl69DFzTJZQF9CRIQIDAQAB` | – |
| TXT (SPF) | `send` | `v=spf1 include:amazonses.com ~all` | – |
| MX (custom return path) | `send` | `feedback-smtp.eu-west-1.amazonses.com` | 10 |

Resend also displays an optional `rsend` CNAME → `send.forge.rmta.net` with status `not_started`; do not make unrelated DNS changes without verifying the Resend dashboard.

**Preserve all root MX and other mail DNS records.** The SPF/MX records here use the dedicated `send` subdomain and do **not** alter where normal company incoming mail is received. Do not change DNS if an existing `send` TXT/MX record already has a conflicting purpose; investigate it first.

## Hosting follow-up after Resend verifies domain

1. In the existing Airlinerra Supabase project's Auth SMTP settings, use Resend's documented SMTP host/port and its secure credentials; the From address and sender name above must be configured there. Store credentials **only in secure provider settings**, never in GitHub, the public website, or Netlify static files.
2. Configure Supabase Auth to require confirmed email and **block public registration**, permitting only owner-admin invitations while prelaunch testing remains private. Verify hosted email template URLs point back to `https://airlinerra.com`.
3. Run a single authorized tester invitation, confirmation and recovery test after server-side access and legal settings have been verified. Do not change the main game-world release gates or send tester email before the callback UI is deployed.
4. Monitor account-wide sending quotas. On 2026-10-27, the shared Resend account had 3/3 domain registrations and a daily sending limit of 100; Tennis Legacy's repeated system incident emails were separately stopped at their source in the Tennis Legacy database, leaving unrelated email services untouched.

**No domain was removed; no sender records were written to Namecheap in this milestone.**
