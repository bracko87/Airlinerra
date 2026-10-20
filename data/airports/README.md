# Airlinerra airport collection — permanent runway-only register

## Current phase
Only collect airports having **at least one runway 1,200 m or longer**, reported **asphalt or concrete**, with both runway and airport not recorded closed. Facilities that say only "paved" are sent to a surface-check queue and not assumed eligible.

A matching airport can be considered **at least Level 1 (Local)**. This is only a lower-bound technical qualification, NOT a final assignment to Airlinerra's exact six tiers: Local, Regional, Medium, Large, Major Hub, Mega Hub. All other airport details are postponed.

## Canonical master
- `airport_register.csv`: **2,946 airport records (2,945 screened real-world candidates + 1 fictional airport) across Groups 1–22**, with identifiers, country, name, longest reported qualifying runway, surface and minimum eligible level 1. This is not a list of operational or playable airports.
- `fictional_airports.csv`: owner-defined airports outside OurAirports. **Aleksandrovo Airport (LYAL), Serbia** — fictional, runway 2,200 m asphalt, **assigned Level 1 / Local**. Protected from being erased by future runway-only screenings; no coordinates or additional data assumed.
- `airport_register.csv` has `source_type` (`OURAIRPORTS` / `FICTIONAL`) and `assigned_category` (blank for screened real airports, `Local` for LYAL) to keep these records unambiguously separated.
- Each group's `generated/groupN/groupN_technical_candidates.csv`: source screening that feeds the master.
- Each group's `generated/groupN/groupN_country_counts.csv`: country-level counts.
- `generated/groupN/groupN_surface_review.csv`: unclear pavement labels, excluded pending runway-surface verification.
- `generated/groupN/SOURCE.txt`: snapshot checksums and audit trail.
- `historical_approved_recovery.csv`: separate historical record of 56 name-level selections from earlier Groups 1–3 discussions; **do not add those as extra airports** unless already in a source screen.
- `group4_14_reconciliation.csv`: all 14 older Group 4 candidates were already included in the Group 4 technical screen.

## Totals for the current runway-only definition
| Group | Countries | Runway-qualified airports |
| --- | --- | ---: |
| 1 | Albania, Armenia, Austria, Azerbaijan | 30 |
| 2 | Belarus, Belgium, Bosnia and Herzegovina, Bulgaria, Croatia | 58 |
| 3 | Cyprus, Czechia, Denmark, Estonia, Finland | 74 |
| 4 | France, Georgia, Germany, Greece, Hungary | 307 |
| 5 | Iceland, Ireland, Italy, Kosovo, Latvia | 91 |
| 6 | Liechtenstein, Lithuania, Luxembourg, Malta, Moldova | 11 |
| 7 | Monaco, Montenegro, Netherlands, North Macedonia, Norway | 47 |
| 8 | Poland, Portugal, Romania, Russia (entire country), San Marino | 397 |
| 9 | Serbia, Slovakia, Slovenia, Spain, Sweden | 142 source-screened + 1 fictional |
| 10 | Switzerland, Turkey, Ukraine, United Kingdom, Vatican City | 215 |
| 11 | Andorra, Åland Islands, Faroe Islands, Gibraltar, Guernsey, Isle of Man, Jersey, Svalbard and Jan Mayen, Greenland | 10 |
| 12 | Asia — Afghanistan, Bahrain, Bangladesh, Bhutan, Brunei | 27 |
| 13 | Asia — Cambodia, China, India, Indonesia, Iran | 558 |
| 14 | Asia — Iraq, Israel, Japan, Jordan, Kazakhstan (entire country) | 172 |
| 15 | Asia — Kuwait, Kyrgyzstan, Laos, Lebanon, Malaysia | 51 |
| 16 | Asia — Maldives, Mongolia, Myanmar, Nepal, North Korea | 79 |
| 17 | Asia — Oman, Pakistan, Palestine, Philippines, Qatar | 116 |
| 18 | Asia — Saudi Arabia, Singapore, South Korea, Sri Lanka, Syria | 126 |
| 19 | Asia — Taiwan, Tajikistan, Thailand, Timor-Leste, Turkmenistan | 92 |
| 20 | Asia — United Arab Emirates, Uzbekistan, Vietnam, Yemen; Hong Kong | 79 |
| 21 | Asia source-geography catch-up — Macao, British Indian Ocean Territory | 2 |
| 22 | Oceania — Australia, Christmas Island, Cocos (Keeling) Islands, Fiji, Kiribati | 261 |
| **TOTAL** | | **2,946** |

**Historic Groups 1–3 selection: 110 airports (21/30/59).** The fresh runway-only screening produces **162 candidates** across those three groups (30/58/74), not 110. Do not conflate these two counts. The earlier list applied additional screening/selection rules; the current register is deliberately a broader technical pool. The separate 56-name historical recovery file remains on staging for reference, while 54 historic names were not recovered.

Uncertain runway surfaces: Group 4 has 4 unresolved labels, Group 13 has 2 (Aurangabad macadam composite; Baramati unspecified paved), and Group 22 has 1 (Carrapateena Airport/YCPT, 1,599.9 m, source surface `BITUM`). All other groups screened so far have zero in their surface-review queues. Russia remains one country (RU) with 312 runway-qualified candidates. All seven unresolved cases remain outside the 2,946-record master.

Two Spanish airports from Group 9 were upgraded from surface-review candidates to the runway-qualified master using **official ENAIRE evidence only**: LENE (La Caminera, 1,400 m concrete) and LEDA (Lleida-Alguaire, 2,500 m asphalt). The original ambiguous source labels remain documented in `runway_surface_overrides.csv`; no unknown `paved`/`hard` surfaces are accepted without documentary confirmation.

**Group 11 jurisdiction reconciliation:** screening the nine missing jurisdictions/territories yielded Andorra 0, Åland 0, Faroe Islands 1, Gibraltar 1, Guernsey 1, Isle of Man 1, Jersey 1, Svalbard and Jan Mayen 0, Greenland 5. The zero counts for Åland and Svalbard do not imply no qualifying airports there: source records already include **Mariehamn Airport (EFMA)** under Finland (Group 3) and **Svalbard Airport, Longyear (ENSB)** under Norway (Group 7), so those records are preserved and not duplicated. These are OurAirports jurisdiction-code totals, not comprehensive airport inventories.

**Next regional sequence:** Groups 1–11 covered Europe and associated jurisdictions. Group 12 begins Asia with five alphabetically selected countries. Countries already screened as a whole, such as Russia and Turkey, remain in their previous groups and must not be counted twice. The sequence is an organizational choice, not final airport category assignment.

**Group 13 surface evidence:** Four raw uncertain labels were separately confirmed and recorded with sources in `runway_surface_overrides.csv`: Jiayuguan (ZLJQ, concrete, municipal government project report), Linyi Qiyang (ZSLY, concrete, published airport technical reference), Panzhihua (ZUZH, concrete, published airport technical reference), and Shirdi (VASD, asphalt, official Indian AIP). The source `paved`/`hard` labels are retained in the audit file. Aurangabad's Indian AIP reports mixed macadam/concrete and Baramati has no verified asphalt/concrete material yet; neither is assumed qualified.

**Source airport-code conflict:** `airport_code_conflicts.csv` contains one unresolved clash in Iran: code `OIBH` occurs for source IDs `3350` (Bahregan Airport) and `5140` (Bastak Airport). Both match runway-only criteria and remain in the master with their original source identifiers. Codes must be resolved before operational/game import; never invent a replacement ICAO or collapse distinct source airport IDs. The rebuild script generates this conflict report and validation checks it.

**Group 14 material clarification:** OurAirports labels Mount Fuji Shizuoka Airport's (RJNS) 2,200 m runway `asphalt concrete`. This is an explicit asphalt-based paving material and qualifies technically; the Group 14 screen accepts that exact label, and the canonical master/validator also recognize it through `scripts/airport_surface.py`. Generic `paved`, `hard` or unverified materials remain excluded. All of Kazakhstan is screened once, regardless of continent. No new source code conflicts arose; Iran's earlier `OIBH` collision remains in the separate audit file.

**Group 22 Oceania screening:** Australia (entire country) 256, Christmas Island/CX 1, Cocos (Keeling) Islands/CC 1, Fiji 2, Kiribati 1, for 261 runway-qualified candidates. Christmas Island and Cocos (Keeling) Islands use distinct OurAirports geographic codes and must not be duplicated under AU. Carrapateena Airport (YCPT) has a reported 1,599.9 m runway labeled `BITUM`; the label is not sufficient to establish the exact asphalt/concrete surface rule, and remains in `group22_surface_review.csv` pending clearer evidence. This does not imply the runway is unusable. The Group 22 duplicate-identifier audit is empty; the earlier Iran OIBH conflict remains in `airport_code_conflicts.csv`. All records are runway-only, never confirmed for civilian operation or final six-tier assignment.

**Group 21 Asian jurisdiction catch-up:** OurAirports MO reports Macau International Airport (VMMC, 3,213.8 m concrete); OurAirports IO reports Naval Support Facility Diego Garcia (FJDG, 3,658.5 m concrete). Both are runway-qualified; no ambiguous runway materials or duplicate airport identifiers in Group 21. The dataset's country/geography codes are not political determinations. **Diego Garcia must not be treated as civilian-accessible** based on this screening. Source screening cannot independently prove all Asian facilities have been captured, and final airport ranking and gameplay import remain deferred. Christmas Island and Cocos (Keeling) Islands are screened in Group 22 (Oceania) rather than duplicated in Asia.

**Group 20 collection note:** United Arab Emirates 16, Uzbekistan 22, Vietnam 27, Yemen 12, Hong Kong 2, for 79 new runway-only candidates. HK is an OurAirports geographic code, not a sovereignty classification. None of the five screening areas has an unresolved surface queue or duplicate source identifiers. Other Asian territories, notably Macao, were set aside for Group 21; Group 20 by itself did not certify regional completeness.

**Group 19 collection note:** Geographic screening of Taiwan (TW) 15, Tajikistan 9, Thailand 48, Timor-Leste 4 and Turkmenistan 16 produced 92 qualifying runway-only records. TW is a dataset geographic code, not a statement about political sovereignty. Zero Group 19 ambiguous-surface cases or duplicate airport identifiers; the Iranian OIBH source-code conflict remains in a separate audit file.

**Group 18 collection note:** Saudi Arabia 64, Singapore 5, South Korea 28, Sri Lanka 10 and Syria 19 runway-qualified candidates were added to staging, for 126 total. There are no Group 18 ambiguous-surface entries or duplicate airport identifiers. Earlier unresolved surfaces from Groups 4 and 13 and the Iranian OIBH source-code conflict remain in their separate queues. No civilian-use verification or six-category assignment has been performed.

**Group 17 collection note:** The five jurisdictions yielded Oman 9, Pakistan 51, Palestine 0, Philippines 53 and Qatar 3 qualifying runway-only records. Palestine's 0 indicates no matching OurAirports records under the current runway and surface criteria, not an assertion about the existence of airport facilities. The group has no newly flagged ambiguous surface labels or code duplications; the existing Iranian `OIBH` conflict remains on file.

**Group 16 collection note:** The five complete countries were screened without assigning final airport categories or confirming civilian access. North Korea's 34 records are only runway-qualified source candidates; this does not imply open commercial operations. The `OIBH` code conflict from Iran remains in the separate audit queue.

## Safe refresh
- Group 4: `Refresh Group 4 technical airport screening`.
- Group 5: `Refresh Group 5 technical airport screening`.
- Group 6: `Refresh Group 6 technical airport screening`.
- Group 7: `Refresh Group 7 technical airport screening`.
- Group 8: `Refresh Group 8 technical airport screening` (**all of Russia included**, with no European/Asian separation or longitude cutoff).
- Group 9: `Refresh Group 9 technical airport screening` (Spain includes official runway-surface corrections in `runway_surface_overrides.csv`).
- Group 10: `Refresh Group 10 technical airport screening` (Turkey is one country including all territories, 75 qualifying airports).
- Group 11: `Refresh Group 11 technical airport screening` (completion of omitted European jurisdictions and territories; do not duplicate existing Finnish/Norwegian airport records).
- Group 12: `Refresh Group 12 technical airport screening` (start Asia; Afghanistan 12, Bahrain 3, Bangladesh 9, Bhutan 2, Brunei 1).
- Group 13: `Refresh Group 13 technical airport screening` (Cambodia 7, China 166, India 176, Indonesia 128, Iran 81; review two unverified surfaces and one source-code collision).
- Group 14: `Refresh Group 14 technical airport screening` (Iraq 15, Israel 17, Japan 106, Jordan 8, Kazakhstan 26).
- Group 15: `Refresh Group 15 technical airport screening` (Kuwait 2, Kyrgyzstan 10, Laos 8, Lebanon 4, Malaysia 27; no surface ambiguities or new code conflicts).
- Group 16: `Refresh Group 16 technical airport screening` (Maldives 6, Mongolia 8, Myanmar 24, Nepal 7, North Korea 34; no unresolved runway surfaces or new duplicate airport identifiers).
- Group 17: `Refresh Group 17 technical airport screening` (Oman 9, Pakistan 51, Palestine 0, Philippines 53, Qatar 3; no unresolved surface labels or duplicate identifiers).
- Group 18: `Refresh Group 18 technical airport screening` (Saudi Arabia 64, Singapore 5, South Korea 28, Sri Lanka 10, Syria 19; zero unresolved surface labels and new duplicate identifiers).
- Group 19: `Refresh Group 19 technical airport screening` (Taiwan/TW 15, Tajikistan 9, Thailand 48, Timor-Leste 4, Turkmenistan 16; zero unresolved runway materials or duplicate identifiers).
- Group 20: `Refresh Group 20 technical airport screening` (UAE 16, Uzbekistan 22, Vietnam 27, Yemen 12, Hong Kong 2; zero unresolved surfaces or duplicate identifiers).
- Group 21: `Refresh Group 21 technical airport screening` (Macao/MO 1, British Indian Ocean Territory/IO 1; both runway-only, no surface or ID conflicts).
- Group 22: `Refresh Group 22 technical airport screening` (Australia 256, Christmas Island 1, Cocos (Keeling) Islands 1, Fiji 2, Kiribati 1; Carrapateena BITUM flagged for material confirmation).
- Groups 1–3: `Backfill Groups 1-3 runway candidates`.
- Each workflow downloads the same OurAirports data files, screens its group and rebuilds the master by combining every group's screens **and all `fictional_airports.csv` records**, deduplicating by source airport ID. It does not replace other groups' records.
- `python scripts/rebuild_runway_register.py` rebuilds the permanent master **and `airport_code_conflicts.csv`** from all completed group screens.
- `python scripts/validate_airports.py && python scripts/validate_historical_airports.py` validates the master and the historical file.
- Always use GitHub `staging`. Production `main` is unchanged without approved release.

## Future phase (not now)
Civilian or military status, operating permissions, opening hours, equipment/aircraft eligibility, final six-category rankings, terminals, finances, game activation and Supabase database migrations are deferred.
