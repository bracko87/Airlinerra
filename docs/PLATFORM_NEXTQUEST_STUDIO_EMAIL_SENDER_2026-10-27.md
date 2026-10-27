# Airlinerra prelaunch email sender — NextQuest Studio (2026-10-27)

**Owner decision:** Use the existing NextQuest Studio corporate domain **`nextqueststudio.net`** as the outbound sender for Airlinerra invitations, confirmations and password recovery instead of registering a fourth sending domain. **Never remove or replace any existing Resend domain.** Airlinerra's official website remains `https://airlinerra.com`.

## Proposed sender configuration

- From display name: `Airlinerra — NextQuest Studio`
- From address: `noreply@nextqueststudio.net`
- Email verification, invitation and password reset callback website: `https://airlinerra.com/account.html`
- Sender purpose: authentication and transactional emails only, not Tennis Legacy health alerts or mass promotional email.
- Resend account: use its existing company sender-domain registration; do not register `airlinerra.com` or buy an upgrade merely to use a separate From address on the verified company domain.
- **Status: DNS PUBLISHED; RESEND VERIFICATION PENDING.** The three required records were added to Namecheap and are already visible in public DNS. Resend verification was requested on 2026-10-27; its latest domain status has now moved to **`pending`**, with all Resend DNS checks pending. Do not send hosted mail until the domain status is explicitly `verified`.

## Domain verification prerequisites

Public authoritative delegation of `nextqueststudio.net` currently points at Namecheap DNS servers `dns1.registrar-servers.com` and `dns2.registrar-servers.com`. Public Google DNS lookup on 2026-10-27 confirmed that Resend's sender-specific `resend._domainkey.nextqueststudio.net` TXT and `send.nextqueststudio.net` TXT/MX records were missing. Resend's dashboard separately marks the matching DKIM, SPF and MX records `failed`.

Set the **following Resend-provided records in the currently authoritative DNS zone** after confirming the labels and that no existing records would be overwritten. Names below are relative to `nextqueststudio.net`.

| Type | Host | Resend-provided value | Priority |
| --- | --- | --- | --- |
| TXT (DKIM) | `resend._domainkey` | `p=MIGfMA0GCSqGSIb3DQEBAQUAA4GNADCBiQKBgQDUWKJNYmodtdY3XyEeaClwh6zn3msg4h4T0GB2q7Lyc7bv9jDYPVnuRp/EHt8OrPpCGIXj+1Tbv3SF2wxHXg2bM0LOV54LqmWGxibwtieNWJ+wrIxVtlscycFWXMVLMo4tu/Ezpj6HmEACb/puEckEqjlRtjl69DFzTJZQF9CRIQIDAQAB` | – |
| TXT (SPF) | `send` | `v=spf1 include:amazonses.com ~all` | – |
| MX (custom return path) | `send` | `feedback-smtp.eu-west-1.amazonses.com` | 10 |

Resend also displays an optional `rsend` CNAME → `send.forge.rmta.net` with status `not_started`; do not make unrelated DNS changes without verifying the Resend dashboard.

**Live DNS safety audit (27 October 2026):** The root domain currently receives company mail through **Zoho EU**: `MX 10 mx.zoho.eu`, `MX 20 mx2.zoho.eu`, and `MX 50 mx3.zoho.eu`. These MUST remain unchanged. Resend's `send` MX must be installed **only at the `send` subdomain**, never replacing or moving any of the Zoho root records. On Namecheap, MX editing can require switching the **domain-wide Mail Settings** mode to `Custom MX`; do **not** change that dropdown before comparing and preserving the Zoho delivery settings. If the UI cannot add a subdomain MX without affecting root Zoho mail, leave the MX pending and escalate to a DNS API or registrar support rather than risking normal corporate email.

**Update 2026-10-27:** The user saved an authenticated Namecheap browser session. All three missing Resend records were subsequently saved under `nextqueststudio.net` using its Advanced DNS editor. A public DNS lookup returned **Status 0 and the expected values** for `resend._domainkey` TXT, `send` SPF TXT, and `send` MX. The site ALIAS and www CNAME, the Zoho root SPF and DKIM records, and root MX priorities 10/20/50 were confirmed unchanged. The Resend `verify_domain` operation was invoked; its immediate follow-up `get_domain` continued showing `failed`. Wait for verified Resend status before enabling hosted Supabase SMTP. Do not request or paste Namecheap passwords into chat.

**Preserve all root MX and other mail DNS records.** The SPF/MX records here use the dedicated `send` subdomain and do **not** alter where normal company incoming mail is received. Do not change DNS if an existing `send` TXT/MX record already has a conflicting purpose; investigate it first.

## Hosting follow-up after Resend verifies domain

1. In the existing Airlinerra Supabase project's Auth SMTP settings, use Resend's documented SMTP host/port and its secure credentials; the From address and sender name above must be configured there. Store credentials **only in secure provider settings**, never in GitHub, the public website, or Netlify static files.
2. Configure Supabase Auth to require confirmed email and **block public registration**, permitting only owner-admin invitations while prelaunch testing remains private. Verify hosted email template URLs point back to `https://airlinerra.com`.
3. Run a single authorized tester invitation, confirmation and recovery test after server-side access and legal settings have been verified. Do not change the main game-world release gates or send tester email before the callback UI is deployed.
4. Monitor account-wide sending quotas. On 2026-10-27, the shared Resend account had 3/3 domain registrations and a daily sending limit of 100; Tennis Legacy's repeated system incident emails were separately stopped at their source in the Tennis Legacy database, leaving unrelated email services untouched.

**Three new Resend sending DNS records were saved to Namecheap and publicly resolved successfully. No existing domain or DNS record was deleted or altered, no mail was sent, and hosted SMTP is NOT yet active.**
