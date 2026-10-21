# Airlinerra — Group 12 commercial passenger/cargo evidence (2026-10-21)

All **27** original runway-qualified airports are preserved: Afghanistan AF 12, Bahrain BH 3, Bangladesh BD 9, Bhutan BT 2, and Brunei BN 1. This is the **commercial service and cargo evidence** layer, NOT a new runway screen or game activation.

## Reconciled counts

```csv
country_iso,country_name,runway_qualified_candidates,passenger_evidenced,cargo_eligible_evidenced,military_review,other_unknown_both,public_airport_service_unverified
AF,Afghanistan,12,8,1,2,4,0
BH,Bahrain,3,1,1,2,2,0
BD,Bangladesh,9,7,2,1,2,1
BT,Bhutan,2,2,1,0,0,0
BN,Brunei,1,1,1,0,0,0
TOTAL,TOTAL,27,19,6,5,8,1
```

Passenger and cargo counts overlap. Passenger YES means documented historic passenger flights or named currently published services, and not necessarily the same year or a daily 2026 schedule. Cargo YES means airport-specific documented actual shipments or approved facilities, **not a blanket certificate for scheduled freighter flights**. UNKNOWN does not mean forbidden or zero commercial potential. All current operating/access/cargo-capacity limitations remain to be verified before game activation.

## Afghanistan (AF) — no-war scenario, historical service and current routes kept distinct

Airlinerra operates under `../SCENARIO_POLICY.md`: **NO WAR**, so real-world conflict-related closures, airspace restrictions, combat damage and sanctions are **not** imported into gameplay. The documented **2020 pre-conflict domestic route network** (Austrian administrative court's aviation-country information) confirms historic passenger connections at Kabul, Kandahar, Herat, Mazar, Bost/Lashkar Gah, Kunduz and Tarinkot; this is **historical route evidence**, not proof that 2026 timetables operate. Khost has separately published commercial 2026 flights to Dubai, and Kabul, Kandahar, Herat and Mazar have recent airline schedules. Eight unique AF airports therefore carry evidence of passenger service, but **two AF airbases** (Bagram and Shindand) still need civilian-access confirmation. Jalalabad and Sheberghan remain UNKNOWN under the exact source IDs, not rejected.

- Historic route evidence: https://www.ris.bka.gv.at/Dokumente/Bvwg/BVWGT_20210317_W144_2184360_2_00/BVWGT_20210317_W144_2184360_2_00.html
- Recent scheduled domestic passenger destinations: https://www.flightconnections.com/flights-from-kabul-kbl ; Khost–Dubai: https://www.flightconnections.com/flights-from-kht-to-dxb
- Kabul cargo: airline documented Jan 2026 contracted **Boeing 737-300 freighter**, intended primarily for Kabul–Delhi cargo, without an inferred annual freight volume: https://www.ariananews.af/ariana-cargo-aircraft-arrives-in-kabul-boosting-trade-and-exports/

No cargo YES at Kandahar/Herat/Mazar was inferred from Afghanistan-wide export plans. Cargo YES is currently airport-individual at Kabul only. Military airports are not automatically normal commercial airports in a no-war world.

## Bahrain (BH)

Bahrain International (OBBI) operator publishes approximately **9.74 million passenger movements and 405,217 tonnes cargo handled in 2025** through ACI's regional reporting. Its airport operator confirms purpose-built 25,000 sqm cargo terminal and logistics operators including DHL/FedEx. Unlike travel-industry summaries using different cargo scopes, the operative commercial screen cites an explicit airport operator cargo-service description; actual tonnage differences require source-definition reconciliation rather than averaging. Sakhir and Shaikh Isa Air Bases remain military access review.

- 2025 traffic: https://www.aci-asiapac.aero/media-centre/news/bahrain-international-airport-sets-operational-records-in-2025
- Cargo facilities: https://www.bahrainairport.bh/corporate/cargo-facilities

## Bangladesh (BD)

Bangladesh CAAB's airport directory lists five domestic *operational* airports (Cox's Bazar, Rajshahi/Shah Makhdum, Jashore, Saidpur, Barishal), plus international Shah Amanat/Chattogram and Osmani/Sylhet. The 2026 national passenger-airport report confirms traffic at all seven in Group 12. At Jashore, US-Bangla independently announced the scheduled service resumption from **9 September 2026** (six weekly operations). **Ishurdi** is listed by CAAB as service-unavailable; **Tejgaon** requires advance aviation-authority approval, and is a military/civil-access review. These are non-war issues.
- CAAB airport service listing: https://new.caab.gov.bd/airportsf.html
- 2026 airport-specific positive passengers: https://www.thedailystar.net/business/economy/news/four-domestic-airports-see-big-drop-passenger-traffic-4291401
- Jashore specific flights: https://www.bssnews.net/others/418015

**Osmani/Sylhet** had a documented dedicated freighter departure with **~60 tonnes** export cargo (April 2025), besides an approved CAAB cargo warehouse. **Shah Amanat/Chattogram** is documented for actual import cargo and handling, but a 2025 cargo scanner failure significantly affected operations and direct export-freighter proposals were delayed; no future freighter schedule or screening equipment uptime is assumed.
- Sylhet actual cargo: https://www.bangladeshmonitor.com.bd/en/sylhet-airport-begins-cargo-operations ; CAAB cargo building: https://new.caab.gov.bd/airports/osmani.html
- Chattogram actual cargo: https://www.tbsnews.net/economy/aviation/scanner-breakdown-disrupts-cargo-operations-ctg-airport-1219611 ; proposed freighter network delay: https://www.tbsnews.net/economy/four-months-ctgs-air-cargo-dreams-grounded-tender-delays-drag-1212986

**Major source coverage gap:** Dhaka **Hazrat Shahjalal International Airport (VGHS)** — Bangladesh's largest passenger and cargo gateway — is missing from the original nine Bangladesh technical-source airports. It is NOT counted as unqualified or fictitious; the *missing technical source* has to be reconciled with source runway records and official pavement measurements before the register is updated. Explicit gap log: `group12_source_coverage_gaps.csv`. Do not silently add it and change the canonical source IDs.

## Bhutan (BT)

Drukair's live route directory documents passenger operations at Paro and Gelephu. Paro's aviation authority publishes cargo/mail services, airwaybill requirements, import/export customs procedures and small aircraft hold/80kg shipment constraints. Gelephu obtained scheduled domestic **third weekly Paro service effective 2 September 2026** and has a 2026 report confirming smaller ATR-class aviation limits; this is not widebody or heavy-freighter clearance. Cargo at Gelephu remains UNKNOWN.

- Airline routes: https://drukair.com.bt/plan/plan-your-trip/destinations/
- Gelephu schedule: https://drukair.com.bt/third-weekly-flights-between-paro-and-gelephu/
- Paro cargo: https://www.doat.gov.bt/paro/agencies/druk-air-cargo/
- Gelephu aircraft access: https://www.bbs.bt/197229/

## Brunei (BN)

**Brunei International Airport WBSB** has 2026 passenger ticket itineraries sold by its flag carrier and named international destinations; Royal Brunei's cargo office states that the airport has about **64,000 sq ft** of purpose-built cargo complex and documented bonded/perishable/valuable shipments. The ground handler BIACC confirms a cargo terminal separately. This does not establish a daily freight-tonnage baseline or future capacity.

- Passenger routes: https://www.flyroyalbrunei.com/en-bn/flights-from-brunei
- Airline cargo: https://www.flyroyalbrunei.com/brunei/en/information/cargo/
- Ground handler cargo terminal: https://biacc.com.bn/cargo-services/

## Important future simulation safeguards

- `group12_operational_restrictions.csv`: 4 specific NON-WAR constraints or recheck items: Ishurdi services, Tejgaon prior permission, Gelephu aircraft type, and a **historical** Chattogram freight-scanner failure (not automatically an ongoing 2026 closure). No wartime restriction applied anywhere.
- `group12_source_coverage_gaps.csv`: missing technical screening of Dhaka VGHS to be fixed in a **separate source/airport register audit**. Do not deduce missing passenger or cargo airports have zero service.
- Six final airport classifications ONLY: Local, Regional, Medium, Large, Major Hub, Mega Hub. No real airport is classified in this preliminary layer.
- No guessed runway slots, gate/apron stands, airline freighter aircraft max payload, passenger/cargo monthly/annual demand, curfews, owner access or cargo processing capacity.
- Existing global register, runway source ID, country geography, code-conflict and ambiguous-surface queues, fictional Aleksandrovo `LYAL` stay intact.
- Nothing is imported into Supabase or activated in the route engine.
- Validator: `python scripts/validate_commercial_group.py --group 12`; separately check restriction and coverage-gap sidecars.

**Next:** Group 13 — Cambodia, China, India, Indonesia and Iran, **558** runway-qualified airports. Given size, review in country sub-batches without changing the complete country roster or main branch policy.
