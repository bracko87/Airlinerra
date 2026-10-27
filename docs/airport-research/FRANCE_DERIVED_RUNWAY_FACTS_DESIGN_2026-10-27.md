# Airlinerra — proposed versioned runway facts layer

**Date:** 2026-10-27  
**Status:** Design only — not deployed, no SQL migrations, no game admission changes.

## Purpose

French runway audit has source-validated **14 of 14** proposed physical-length corrections. The original OurAirports imports must remain immutable. Do not copy correction proposals directly into the 3,140-airport private World 1 game catalog or scheduling rules.

## Proposed data model (future engineering review)

- **Runway source versions:** airport key, runway pair, authority, original URL, publication/effective date, review timestamp, evidence ID and prior version. Retain older data.
- **Runway physical facts:** source version, runway identifier, length, width, original material description, normalized ASPHALT/CONCRETE/MIXED/UNKNOWN/NONPAVED type, exact-material verification status and operational runway status. Never substitute generic 'paved' or 'macadam' for explicitly verified asphalt/concrete.
- **Runway directional facts:** runway end, TORA, TODA, ASDA, LDA, displaced threshold, clearway and stopway; store unknown values as NULL. Include applicable runway-end aircraft restrictions with authority and source effective date.
- **Airport operating permissions:** scheduled passenger, charter, cargo, private and military rights independently, with PROHIBITED, PERMISSION_REQUIRED, CONDITIONAL or UNVERIFIED states; no inference from runway length or public-aerodrome listing.
- **Private effective-view selection:** only after separate review and migration; source-effective-dated and RLS protected. A data view does not automatically authorize an airport or commercial flight.

## Mandatory regression tests

1. **Étain LFQE:** original 2400m versus proposed 1721m; military restrictions and pavement-material hold persist.
2. **Le Bourget LFPB:** original 2395.1m represents real RW03/21, not longest RW07/25 at 2991m. Scheduled/charter remains prohibited.
3. **Villacoublay LFPV:** original 1813m versus 1957m bituminous; military restrictions remain.
4. **Lannion LFRO:** original 1699.9m versus 1602m; LDA11=1376m and LDA29=1463m, exact material still pending.
5. **Orange LFMO:** 2407m macadam with concrete threshold sections 330m/262m; short sections do not prove full 1200m eligible material.
6. **Melun LFPM:** physical 1972m, RW28 TODA2650 includes 678m clearway, RW28 LDA1890m; avoid substituting TODA for physical length.
7. **Creil LFPC:** legally closed; never admitted from historic runway length.
8. **World 1:** original 3140 approved keys unchanged; no automatic gameplay admissions.
9. Preserve exactly six categories: Local, Regional, Medium, Large, Major Hub, Mega Hub.

## Related audits

- [Physical-length correction proposals v3](FRANCE_RUNWAY_CORRECTION_PROPOSALS_2026-10-27.json)
- [French source review](FRANCE_SPECIALIST_2026-10-26.md)

**No database tables/views, migrations, website deployment, public release or game scheduling changes are authorized by this design.**
