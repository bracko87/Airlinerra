# Airlinerra — Phase 4 Batch 15 (25 October 2026)

**Supabase verified:** 10 unique airport reviews. Two airports with published LDAs above 1,200m (**OXR, PNE**); two with below-minimum landing directions (**PHD, PWK**); six still needing authoritative per-direction LDA. All **BLOCKED_PENDING_REQUIRED_EVIDENCE / NOT_APPROVED**, no gameplay or category changes.

**Batch:** `US_EXPANSION_PHASE4_NEXT_GATE_BATCH_15_2026_10_25`. FAA data effective Oct 01, 2026 unless otherwise noted. No review constitutes real-world flight authorization.

## Individual reviews

### OXI — Starke County
Good asphalt RW18/36 **5,002x75ft, S-30,000lb**; RW09/27 **3,096ft turf**, nonqualifying. Crop spraying, NOTAM, usable LDA, owner commercial consent and named licensed operator all require verification. [FAA](https://www.airnav.com/airport/koxi) · [Prior airport evidence](https://www.airportiq5010.com/5010ReportRouter/default.aspx?airportID=OXI).

### OXR — Oxnard
FAA publishes **RW07 LDA 5,654ft**, **RW25 LDA 5,500ft** on 5,953ft asphalt. For unscheduled air-carrier flights with aircraft having **more than nine passenger seats**, FAA demands advance airport coordination and available ARFF. Part139/seat-class applicability, operator licence and owner permission remain unverified. [FAA](https://www.airnav.com/airport/OXR) · [Chart reference](https://skyvector.com/airport/OXR/Oxnard-Airport).

### PHD — Harry Clever Field
Gross paved RW15/33 **3,951ft**, but officially published **RW15 LDA 3,621ft (~1,104m)** and **RW33 LDA 3,634ft (~1,108m)**: BOTH FAIL 1,200m. Short turf RW12/30 cannot substitute. Keep held regardless of otherwise available Jet A or pavement loading unless published LDA materially changes. [FAA runway and LDA](https://www.airnav.com/airport/PHD) · [City owner](https://www.newphiladelphiaoh.gov/315/Harry-Clever-Field-KPHD).

### PHN — St. Clair County International
RW04/22 **5,104x100ft grooved asphalt, S40/D55/DT90**; separate RW10/28 **4,000x75ft, S16**. International entry requires flight-specific CBP and agricultural notice. Landing fee waiver after fuel purchase is financial policy, not runway closure. Official LDAs, loading and owner/operator legal rights remain open. [FAA](https://www.airnav.com/airport/PHN) · [County owner](https://www.stclaircounty.org/Offices/airport/).

### PMH — Greater Portsmouth Regional
RW18/36 **5,001x100ft good asphalt, S30/D42/DT70**; skydiving and sightseeing require separation. Jet A1+ full service after hours by manager callout, while turbine landing-fee waiver is not an aircraft restriction. Official LDA, notices and commercial operator rights not yet verified. [FAA](https://www.airnav.com/airport/PMH) · [County](https://www.sciotocountyoh.com/airport).

### PNE — Northeast Philadelphia
Main RW06/24 **7,000ft** with published **RW06 LDA 6,502ft** and **RW24 LDA 6,102ft**; both pass length. But FAA explicitly states **AIRPORT CLOSED TO PART 121 AIR CARRIER AND PART 135 SCHEDULED SERVICE**. This blocks those game flight classes, not all lawful GA. Turbojets generally confined to main runway; international CBP requires advance permission. [FAA](https://www.airnav.com/airport/PNE) · [City pilot guidance](https://www.phl.org/PNE/pilot-information).

### PRO — Perry Municipal
Current Iowa DOT **RW14/32 5,500x100ft concrete**, S28/D48; **RW04/22 2,322ft turf** excluded. Older city runway figures must not supersede DOT. Parachuting and winter NOTAM, actual usable LDA and owner-paid rights require verification. [Iowa DOT](https://opmapps.iowadot.gov/aviation/airports/PRO) · [Airport project](https://www.perryia.org/city-projects-blog/perry-municipal-airport-runway-reconstruction-expansion).

### PSK — New River Valley
RW06/24 **6,201x150ft good grooved asphalt**, ILS RW06, Jet A and major repairs. Customs port of entry and FTZ status require flight-specific clearance, not automatic passenger/cargo landing permission. Official LDA, wheel loads, approach trees and certificated operator unverified. [FAA](https://www.airnav.com/airport/PSK) · [Airport owner](https://newrivervalleyairport.com/).

### PSX — Palacios Municipal
**RW13/31 5,001x150ft good concrete**, while **08/26 and 18/36 are poor**, with vegetation and markings problems. Do not transfer those defects to the good runway. FAA listing does not currently establish routine fuel/rescue response; official LDA and signed commercial-use permit remain unresolved. [FAA](https://www.airnav.com/airport/PSX) · [City owner](https://www.cityofpalacios.org/palacios-municipal-airport).

### PWK — Chicago Executive
Main **RW16/34 5,001x150ft good asphalt** remains subject to official LDA and loading review. Crosswind **RW12/30 4,415ft** has published **RW12 LDA 3,785ft (~1,154m)** and **RW30 LDA 3,725ft (~1,135m)**: BOTH FAIL 1,200m. Separate RW06/24 and Taxiway F permanently closed. Class B/ATCT and customs-service requirements remain. [FAA runway LDAs](https://www.airnav.com/airport/PWK) · [FAA briefing](https://www.faa.gov/flight_deck/pwk).

## Audit and next steps

Supabase Batch 15 independent audit: **10 distinct rows; 2 documented above-threshold LDA; 2 airports with four below-threshold directions; 6 cases pending official LDA; zero evidence/ID/Phase3 errors and zero approvals.**

**Cumulative:** Phase 4 **150 of 211** reviewed, **61 remaining**; Phase 3 **833 reviewed, 622 held**; **1,929** candidate records and **3,140** original playable airports preserved.

Final eligibility always requires operational paved runway **>=1,200m official usable landing distance by direction**, airplane type loading and obstacles, dated FAA NOTAM/FICON, fuel/handling/rescue, written owner paid-use consent and actual certificated flight operator. Exactly **six airport categories** remain defined, none assigned.

**Next:** Phase 4 Batch 16; separately resolve the 622 Phase 3 held airports.
