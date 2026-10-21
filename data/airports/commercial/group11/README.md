# Group 11 — Commercial passenger and cargo screening (2026-10-21)

**Coverage: exactly 10 original runway-qualified source airports.** Andorra AD 0, Åland AX 0, Faroe Islands FO 1, Gibraltar GI 1, Guernsey GG 1, Isle of Man IM 1, Jersey JE 1, Svalbard/Jan Mayen SJ 0, Greenland GL 5. Country codes are original OurAirports source geographies, not sovereignty assertions. No airport IDs, source names or runway geometry modified.

## Country totals

```csv
country_iso,country_name,runway_qualified_candidates,passenger_evidenced,cargo_eligible_evidenced,military_review,other_unknown_both,public_airport_service_unverified
AD,Andorra,0,0,0,0,0,0
AX,Åland Islands,0,0,0,0,0,0
FO,Faroe Islands,1,1,1,0,0,0
GI,Gibraltar,1,1,1,0,0,0
GG,Guernsey,1,1,1,0,0,0
IM,Isle of Man,1,1,1,0,0,0
JE,Jersey,1,1,1,0,0,0
SJ,Svalbard and Jan Mayen,0,0,0,0,0,0
GL,Greenland,5,5,5,0,0,0
TOTAL,TOTAL,10,10,10,0,0,0
```

**Interpretation:** 10 passenger-evidenced and 10 cargo-evidenced means these airports have **real observed passenger traffic/scheduled transport OR documented passenger/carried shipment services**. It does NOT mean 10 independently available fixed-wing public airline destinations in 2026, unrestricted freighter rights, or that every destination has daily scheduled aircraft. Several cargo-positive results are airline courier or small air-freight/mail carriage, not dedicated freighter terminals. Exceptional restrictions below apply separately.

## Evidence and operational nuances

- **Faroe Islands — Vágar EKVG:** Airport operator reported 2025 **461,064 passengers and >8,400 tonnes air freight**, with substantial salmon exports through FarCargo. Distinct from 2026 forecasting. Sources: https://local.fo/vagar-airport-saw-record-numbers-of-passengers-in-2025/ ; https://statbank.hagstova.fo/pxweb/en/H2/H2__SS__SS01/ferd_lfarm.px/
- **Gibraltar LXGB:** Gibraltar Airport publishes 2025 **437,172 passengers and 106,940 kg cargo/mail/courier** (combined, 106.94 tonnes). Shared military/civil runway and customs constraints need airport-specific review. Source: https://gibraltarairport.gi/uploads/air-traffic-statistics/2025-air-traffic-statistics.pdf
- **Guernsey EGJB, Isle of Man EGNS, Jersey EGJJ:** UK CAA 2025 non-UK-reporting Table 9 gives actual passenger movements of **692,139, 617,085, 1,453,675**, respectively; Table 13.2 reports actual freight **346, 12, 477 tonnes**. A tiny cargo record is not evidence of a dedicated heavy freighter terminal. No duplication with the United Kingdom's separate Group 10 source IDs. Sources: https://www.caa.co.uk/Documents/Download/24007/87fb7670-4e10-4aeb-942d-509238aa25a1/17553 ; https://www.caa.co.uk/Documents/Download/24007/87fb7670-4e10-4aeb-942d-509238aa25a1/17517
- **Greenland Nuuk BGGH and Kangerlussuaq BGSF:** Air Greenland's live 2026 route network evidences commercial passenger flights and its cargo operator publishes named freight terminals at both airports. Passenger and cargo service times are distinct. Sources: https://www.airgreenland.com/routemap/ ; https://www.airgreenland.com/cargo/contact-air-greenland-cargo/
- **Greenland Qaqortoq GL-0012 / gps BGQO:** Opened **16 April 2026**, receives Air Greenland's scheduled Dash-8 passenger services and appears in the airline express-cargo destination list. **April 2026 aviation authority approval was CONDITIONAL**, limiting the initial operator/traffic; do not interpret freight carriage as dedicated freighter stands. Identifier GL-0012 is the immutable original OurAirports `ident`, while GPS code BGQO remains stored separately: **do NOT silently change code/identity**. Sources: https://www.trafikstyrelsen.dk/nyheder/2026/apr/sydgroenlands-nye-lufthavn-i-qaqortoq-er-godkendt ; https://www.airgreenland.com/cargo/tuavi/
- **Greenland Narsarsuaq BGBW:** Original runway is physically in the register and it historically handled fixed-wing passenger flights. **Fixed-wing service ended 15 April 2026 and the airfield converted to a heliport from 16 April 2026.** Airline still lists Narsarsuaq cargo handling, and helicopter/passenger links have historical and transitional evidence. Its passenger/cargo YES is SERVICE/HISTORICAL evidence only: the machine-readable restriction **must prevent any inference that a fixed-wing commercial airline can currently operate**. Sources: https://www.airgreenland.com/news/a-transition-in-the-air/ ; https://www.airports.gl/app/uploads/2025/12/ENG-Tariffs-and-payments-using-helicopter-aerodromes-and-airports-in-Greenland-01-jan-2026-ver-1.1-with-Appendix.pdf ; https://www.airgreenland.com/cargo/contact-air-greenland-cargo/
- **Greenland Pituffik BGTL:** Air Greenland sells **scheduled passenger transit/settlement flights** and includes Pituffik/Thule in freight products, but **passengers must obtain ministry-issued transit/entry permits** even for brief transfer. The military Space Base does not grant unrestricted civilian public use. Sources: https://agent.airgreenland.com/hc/en-us/articles/212915278-Military-base-defence-area-PITUFFIK-SPACE-BASE ; https://www.airgreenland.com/cargo/settlements/ ; https://www.airgreenland.com/cargo/tuavi/

The **three machine-readable special cases** are Narsarsuaq (non-war heliport conversion), Pituffik (defence-area permit requirements) and Qaqortoq (conditional startup certification). These require future simulation logic before treating service-evidenced airports as unrestricted airline route destinations; no such route-engine enforcement is claimed to be already deployed.

## Zero-result territories / duplicate protections

- Andorra AD and Åland AX have no *additional* qualifying airports in their original source geographies. Mariehamn (EFMA) already belongs to FI (Group 3); do not double count.
- Svalbard/Jan Mayen SJ has zero unique records in this group. Longyear/ENSB is already in Norwegian Group 7; do not double count. 
- Four zero territories do **not** imply that there are no aviation facilities or heliports there.
- Neither technical runway availability nor passenger/freight history is sufficient by itself to set airport classification or game demand. Airlinerra has exactly six eventual tiers: Local, Regional, Medium, Large, Major Hub, Mega Hub.
- The user-approved **NO WAR** world policy in `data/airports/commercial/SCENARIO_POLICY.md` remains in force: no war-based blanket airspace closures. Narsarsuaq's documented heliport transition is **not** a conflict closure and must still be considered.

## Validation and next

Run `python scripts/validate_commercial_group.py --group 11`. Independently verify source IDs, review decisions, zero-territory totals, special-case identifiers and original master before closing the group. This is data research only, no Supabase/gameplay import or automatic GitHub Actions. **Next Group 12: Afghanistan, Bahrain, Bangladesh, Bhutan and Brunei (27 runway-qualified airports).**
