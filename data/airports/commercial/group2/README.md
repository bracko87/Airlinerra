# Airlinerra — Group 2 commercial screening (2026-10-21)

**Scope:** 58 historic runway-qualified airport IDs from Bosnia and Herzegovina (4), Belgium (14), Bulgaria (16), Belarus (14) and Croatia (10). This is the commercial **evidence layer**, not a newly screened runway group and not a game activation decision.

## Reconciliation

```csv
country_iso,country_name,runway_qualified_candidates,passenger_evidenced,cargo_eligible_evidenced,military_review,other_unknown_both,public_airport_service_unverified
BA,Bosnia and Herzegovina,4,4,2,0,0,0
BE,Belgium,14,5,4,8,8,0
BG,Bulgaria,16,5,4,3,11,0
BY,Belarus,14,4,0,7,10,0
HR,Croatia,10,7,1,0,3,0
TOTAL,TOTAL,58,25,11,18,32,0
```

- Commercial passenger evidence includes **operating permissions for scheduled flights**, documented passenger handling and *charter/business* passenger statistics where noted; not all YES records have frequent scheduled commercial airlines.
- Cargo evidence includes officially described handling capacity/permission or actual cargo traffic. **YES does not mean dedicated scheduled freighter service, unrestricted cargo permissions or a minimum annual cargo tonnage.**
- Unknown passenger/cargo permission is not NO. Military-source airbases and non-public airfields remain unresolved until official national AIP/airport-operator review. No registered candidate was deleted or made playable.
- Belgium's Liège Airport is strong evidence for **cargo only**, so passenger stays UNKNOWN until specific validation; Belgium's Kortrijk-Wevelgem is evidenced for small business passenger activity but not scheduled regular airlines.
- Bulgarian Gorna Oryahovitsa has **licences for handling passengers and cargo** without proof of current scheduled traffic; preserve this difference when designing demand.
- Belarusian passenger records derive from the airline's advertised departure cities; 2026 schedule frequency, actual numbers, and aviation restrictions require follow-up. Belarus military fields do not automatically permit commercial operators.
- Croatia passenger evidence is based on 2026 **actual airport-specific passenger traffic**. Cargo is not backfilled from national totals and remains unknown except Zagreb, where airport-specific tonnage is documented.
- No gate/stand counts, hourly slots, curfews, published runway operating capacity, aircraft-compatibility declarations or game passenger/cargo demand values have been guessed.

## Provenance and next review

All positive decisions carry a specific official government/operator/aviation provider URL in the CSV. Evidence and classifications are **as of 2026-10-21**. Codes are preserved from the historical runway source and not reinterpreted as officially validated ICAO codes. Runway register and previous groups unchanged. `scripts/validate_commercial_group.py --group 2` validates completeness and rollup totals.

**Next:** Group 3 (Cyprus, Czechia, Denmark, Estonia, Finland) and separately re-review unresolved Group 1–2 access cases with aviation authority AIPs; final six-tier category assignment awaits operational and demand models.
