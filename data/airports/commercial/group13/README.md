# Airlinerra — Group 13 commercial screening (2026-10-21)

This is a **first-pass, not final commercial-clearance audit** of all **558 original runway-qualified airports** across **Cambodia 7, China 166, India 176, Indonesia 128 and Iran 81**. The real-airport technical register, runway source IDs, surface review queues, disputed codes, and fictional LYAL are untouched; no data import/gameplay activation/deployment performed.

## Country coverage and confirmed evidence

```csv
country_iso,country_name,runway_qualified_candidates,passenger_evidenced,cargo_eligible_evidenced,military_review,other_unknown_both,public_airport_service_unverified
KH,Cambodia,7,5,2,0,2,0
CN,China,166,83,83,4,83,0
IN,India,176,43,36,21,132,0
ID,Indonesia,128,47,5,3,81,0
IR,Iran,81,21,1,5,60,0
TOTAL,TOTAL,558,199,127,33,358,0
```

**Important counting semantics:** A passenger or cargo `YES` means **historical published airport-specific throughput, or directly documented operator service**. It is not unrestricted present-day commercial permission, a regular daily passenger schedule, an approved cargo aircraft model, or future in-game airline demand. `UNKNOWN` means **research not yet complete**, NOT no flights or zero cargo. Do **not** present these lower-bound evidence counts as the actual number of commercially functioning airports. Passenger and cargo columns overlap, as do military access reviews and unknowns.

`group13_traffic_evidence.csv` preserves sources, observed count fields, and their provenance year/type for the airport IDs with positive evidence. Data includes several noncomparable reporting periods; never sum India FY2025–26 numbers with calendar 2025 China or 2019 Iran as a global 2025 total.

### Cambodia (KH)

- **Techo/KTI (source ident KH-0002, GPS VDTI)** began commercial passenger flights **9 September 2025**, replacing **Phnom Penh/VDPP**. Techo has verified inbound/outbound cargo, customs facilities, cold store and freighter handling. Original ident remains `KH-0002`: do not overwrite it with GPS code. [Techo operator](https://www.techoairport.com.kh/news/techo-intl-airport-welcome-first-flight-09-sep-2025) · [cargo procedures](https://pnh.cambodia-airports.aero/cargo_process)
- **Siem Reap Angkor/VDSA** replaced historic Siem Reap REP airport in October 2023, handled 1.47 million passengers in 2025 and opened dedicated freight facilities alongside passenger operations. [Cambodia government](https://www.akp.gov.kh/post/detail/378331) · [airport cargo operator](https://english.sai-airport.com/hyysfw/38940.jhtml)
- **Sihanouk/VDSV** appears as a 2025 passenger air-arrival port in Cambodia's tourism dataset. [Ministry of Economy and Finance](https://data.mef.gov.kh/datasets/pd_6a8555f7911be0000713a2c1)
- **Dara Sakor/DSY (source ident KH-0001)** began Air Cambodia's roughly twice-weekly commercial service in December 2025. [Air Cambodia](https://www.aircambodia.com/en/offer/-welcome-the-new-domestic-route-to-the-southwest-of-cambodia)
- **Old Phnom Penh/VDPP** has historical passenger evidence but was succeeded by Techo. This non-war service relocation appears in `group13_operational_restrictions.csv`; **its positive historic passenger status is not approval for a present-day scheduled airline route**. Battambang and Stung Treng remain UNKNOWN.

### China (CN)

Civil Aviation Administration of China **CAAC 2025** reported **270 certificated civil transport airports** in China and published an original airport-level 2025 passenger/cargo/mail XLSX. Airport-specific records used in this stage are the **108-airport top-traffic transcription** with IATA+ICAO and numeric 2025 throughput. **83** match exact Group 13 source IDs/ICAO airport codes, with observed passengers and positive 2025 cargo/mail; remaining **83 of our Group 13 Chinese candidates have not yet had their 2025 annual statistics matched**. Do not interpret them as 83 closed airports.
- [CAAC official 2025 report and original airport ranking XLSX](https://www.caac.gov.cn/XXGK/XXGK/TJSJ/202602/t20260226_230119.html)
- [108-airport ranking with ICAO and individual cargo/passenger data](https://en.wikipedia.org/wiki/List_of_the_busiest_airports_in_China)

**CRITICAL TECHNICAL SOURCE COVERAGE ISSUE:** **25** airports in the same 2025 top-108 airline traffic table, some handling many millions of passengers (e.g. Zhuhai, Korla, Yiwu source concerns), are **absent** from our original 166 airport source IDs. Those **must not be called unqualified**; research exact OurAirports IDs, paved runways (>=1,200m), surfaces and source-generation omissions in separate technical audit. The absent airport codes are listed individually in `group13_source_coverage_gaps.csv` and must never be silently fabricated or appended without checks. China cannot be considered fully technically/operationally covered before this is addressed.

### India (IN)

AAI publishes ongoing airport-wise passenger and freight Annexure III/IV data. A published 2025–26 airport ranking identifies **43 exact airport matches** in the existing 176-runway candidate set with recorded commercial passenger traffic (including Delhi, Mumbai, Bengaluru, Hyderabad, Kolkata and Chennai). A separate airport-by-airport **FY2024–25 airfreight league** compiled from AAI's figures documents positive freight at **36** Indian candidate airports; do not present all 176 as having been independently checked against AAI raw statistics. Four commercial cargo airports (Lucknow, Indore, Bhubaneswar and Bagdogra) and three additional passenger airports (Hindon, Gorakhpur and Jodhpur) appear in traffic rankings **but are missing** from original Group 13 candidate IDs. These are source-coverage gaps for review, not aviation-ineligible findings.
- [AAI official airport traffic statistics portal](https://www.aai.aero/en/business-opportunities/aai-traffic-news)
- [Airport-specific 2025–26 passenger ranking](https://en.wikipedia.org/wiki/List_of_busiest_airports_in_India)
- [AAI-based FY2024–25 40-airport freight compilation](https://safeandsecure.in/airports/)

### Indonesia (ID)

Historical top-airport tables match **47 original Indonesian airport ICAO IDs** with prior positive passenger traffic. This is **pre-2020 observed traffic**, not automatically proof of current 2026 scheduled flights. Indonesia's BPS 2025 **domestic cargo** table confirms five source airports: **Jakarta Halim, Jakarta Soekarno-Hatta, Surabaya Juanda, Makassar Hasanuddin and Jayapura Sentani**, with documented annual domestic freight. These figures exclude international freight, so they are not comparable to all-cargo airport statistics. The original 128 source IDs remain intact, and the other 81 are UNKNOWN pending Indonesian DGCA detailed 2025 airport-specific data.
- [Indonesia Directorate General of Civil Aviation 2025 air-traffic portal](https://hubud.kemenhub.go.id/lalu-lintas)
- [Historical passenger-ranked airports and ICAO IDs](https://en.wikipedia.org/wiki/List_of_the_busiest_airports_in_Indonesia)
- [BPS 2025 domestic cargo table, December 2025 release](https://id.scribd.com/document/1013084744/2544)

### Iran (IR)

Older 2019 airport-by-airport positive passenger figures verify **20 source airport records**. **Payam International/OIIP** has its operator's own positive passenger and cargo handling/air-logistics history, giving Iran **21** passenger-evidenced and **1** cargo-evidenced airports in this preliminary pass. **These are lower-bound evidence coverages, NOT plausible final national totals**: 2024/2025 Iranian civil-aviation passenger and cargo data need further airport-wise extraction. Original **OIBH conflict** (Bahregan OI20 and Bastak OIBH) remains unresolved; never collapse records by ICAO/GPS code or invent a unique classification.
- [2019 airport-specific historical passenger ranking](https://en.wikipedia.org/wiki/List_of_the_busiest_airports_in_Iran)
- [Payam airport operator's history of passenger and cargo services](https://www.www.api.payamaviation.ir/en-US/douranPortal/5029/page/history-)
- [Payam official cargo flight handling instructions](https://www.payamaviation.ir/en-US/douranportal/5167/page/Offering-the-airport-services)

**Airlinerra no-war scenario:** Do not import actual war-related flight bans or airspace closures as game restrictions for any country. Ordinary non-war transfer of airline routes, airport certification limits, airport runway condition, customs and military/civilian permissions remain independent and can affect eventual game access. See `../SCENARIO_POLICY.md`.

## Technical/data-integrity safeguards and follow-up

- All **558** source airport IDs are covered exactly once in `group13_commercial_review.csv`; `group13_country_counts.csv` reconciles exactly to original Group 13 country totals.
- The **32 missing-source-code candidates** in `group13_source_coverage_gaps.csv` (China 25; India 7) are observations only — *not automatically accepted technical airports*; require a distinct source/runway audit before adding.
- A historical passenger YES from a 2019 ranked airport list does not establish modern scheduled service or aircraft/slot availability. China 2025 cargo mail figures are not the same metric as Indonesia domestic freight alone; Indian fiscal-year figures differ from calendar-year totals.
- No final six-tier airport category changed. Only future six official categories are **Local, Regional, Medium, Large, Major Hub, Mega Hub**.
- No inferred terminal counters, freighter payload, movement slot capacity, stands, cargo-hours, noise curfews, market demand, per-route prices or daily/monthly/yearly 2026 passengers added.
- Remaining evidence work: match full official CAAC XLSX for remaining 83 Chinese source candidates; read complete AAI traffic Annexure III/IV for 176 Indian candidates; DGCA airport-by-airport 2025 traffic for 128 Indonesian candidates; IAC Iranian current passenger and cargo airport details for 81; settle 32 source coverage gaps without disturbing 7,846 global master.
- Verification: `python scripts/validate_commercial_group.py --group 13`, plus direct ID/country, positive URL, independent traffic-sidecar and gap/restriction checks.
- **Next geographic Group 14**: Iraq 15, Israel 17, Japan 106, Jordan 8, Kazakhstan 26 (**172** runway candidates), without splitting Kazakhstan or importing war-related closures.
