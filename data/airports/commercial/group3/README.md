# Airlinerra — Commercial-eligibility review, Group 3 (2026-10-21)

**Scope**: original 74 technical runway candidates in Cyprus (5), Czechia (17), Denmark (12), Estonia (6), Finland (34). Source IDs and original geographic ownership unchanged. This is a **preliminary evidence-backed commercial review**, not a final civil-access legal determination or playable activation.

## Group 3 counts

```csv
country_iso,country_name,runway_qualified_candidates,passenger_evidenced,cargo_eligible_evidenced,military_review,other_unknown_both,public_airport_service_unverified
CY,Cyprus,5,3,2,1,2,0
CZ,Czechia,17,5,3,4,12,0
DK,Denmark,12,6,2,0,6,0
EE,Estonia,6,5,1,1,1,0
FI,Finland,34,18,5,1,16,0
TOTAL,TOTAL,74,37,13,7,37,0
```

These columns OVERLAP: cargo-evidenced airports can be within passenger-evidenced, and military-review cases are normally also in the unknown-both group.

## Evidence standards

- A `YES` is reserved for an operator's schedule, airport-level passenger statistics, operator cargo handling or government freight/mail transport totals. It means the specific activity/capability was evidenced, not a legal approval for **any** airline or unrestricted route access. A facility with 1 tonne of mail still needs customs/freighter-compatibility research.
- `UNKNOWN` is not `NO`. All 74 remain in technical master, with none activated. Military passenger transport at RAF Akrotiri (including staff/family services) is NOT public commercial permission.
- Ercan (LCEN) reports real commercial passenger volumes. Airport code, internationally permissible airspace/routes, customs and carrier/aviation-regulator requirements need distinct operational/legal verification; do not interpret these as political status conclusions.
- Czech airports Brno, Ostrava, Prague document passenger and cargo, but smaller seasonal charter airports (Pardubice, České Budějovice) are **not** considered daily scheduled hubs merely because seasonal traffic exists.
- Denmark's Billund and Copenhagen publish airport-specific passenger and freight activity, but other airports in Denmark need cargo verification.
- Estonia: Pärnu reports 2026 Q1 passenger movements, which does **not** prove a scheduled passenger flight service. The Tallinn cargo operator list applies only to Tallinn, not other regional airports.
- Finland: published August 2026 airport-level passenger and cargo/mail totals provide evidence for actual activity at the matching airports. **Zero in one month is not zero annual passenger demand**; no unknown is converted to `NO`. Finland's Lappeenranta and Enontekiö report zero August passengers but cannot be rejected on that basis.
- No new airport IDs, locations, runway lengths, airport classifications, gates, stands, curfews, airport slots, demand estimates or actual traffic volumes are added/changed by this review.

## Validation

`python scripts/validate_commercial_group.py --group 3`

Keeps exact group IDs, protects country totals, requires citations for positive fields, disallows unsupported NO, and matches schema of Groups 1 and 2.

## Next

Continue Group 4 (France, Georgia, Germany, Greece, Hungary), preferably in sub-batches because it is much larger; independently research and reconcile unverified access/cargo cases and verify any applicable passenger/cargo permissions with national AIPs, airport operators and aviation regulators before activating a game airport.
