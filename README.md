# Airlinerra

Private Next Quest Studio repository for Airlinerra, a real-time browser airline-management game.

## Controlled development
- **`staging`**: all normal changes, runway-data collection and testing.
- **`main`**: production, changed only through a reviewed PR with testing and explicit owner approval.
- Normal release windows are twice daily, manual (morning/evening); urgent releases require validation and owner approval.
- Nothing in this repository changes ProPeloton Manager or the Game Control Center.

See [AGENTS.md](AGENTS.md) and [release procedures](docs/CONTROLLED_RELEASES.md).

## Airport runway collection — current stage
For now we store ONLY airports reporting a **non-closed asphalt/concrete runway of at least 1,200 metres**. Each meets **minimum Level 1 (Local)** runway criteria; no final categorization, operating permissions or other airport information is being gathered.

[Permanent master airport register](data/airports/airport_register.csv): **3,046 airports: 3,045 runway-screened candidates across Groups 1–25 plus one fictional airport**.

| Group | Airports in runway-only master |
| --- | ---: |
| 1 — Albania, Armenia, Austria, Azerbaijan | 30 |
| 2 — Belarus, Belgium, Bosnia and Herzegovina, Bulgaria, Croatia | 58 |
| 3 — Cyprus, Czechia, Denmark, Estonia, Finland | 74 |
| 4 — France, Georgia, Germany, Greece, Hungary | 307 |
| 5 — Iceland, Ireland, Italy, Kosovo, Latvia | 91 |
| 6 — Liechtenstein, Lithuania, Luxembourg, Malta, Moldova | 11 |
| 7 — Monaco, Montenegro, Netherlands, North Macedonia, Norway | 47 |
| 8 — Poland, Portugal, Romania, Russia (entire country), San Marino | 397 |
| 9 — Serbia, Slovakia, Slovenia, Spain, Sweden | 142 real + 1 fictional |
| 10 — Switzerland, Turkey, Ukraine, United Kingdom, Vatican City | 215 |
| 11 — Andorra, Åland Islands, Faroe Islands, Gibraltar, Guernsey, Isle of Man, Jersey, Svalbard and Jan Mayen, Greenland | 10 |
| 12 — Asia: Afghanistan, Bahrain, Bangladesh, Bhutan, Brunei | 27 |
| 13 — Asia: Cambodia, China, India, Indonesia, Iran | 558 |
| 14 — Asia: Iraq, Israel, Japan, Jordan, Kazakhstan (entire country) | 172 |
| 15 — Asia: Kuwait, Kyrgyzstan, Laos, Lebanon, Malaysia | 51 |
| 16 — Asia: Maldives, Mongolia, Myanmar, Nepal, North Korea | 79 |
| 17 — Asia: Oman, Pakistan, Palestine, Philippines, Qatar | 116 |
| 18 — Asia: Saudi Arabia, Singapore, South Korea, Sri Lanka, Syria | 126 |
| 19 — Asia: Taiwan, Tajikistan, Thailand, Timor-Leste, Turkmenistan | 92 |
| 20 — Asia: United Arab Emirates, Uzbekistan, Vietnam, Yemen; Hong Kong | 79 |
| 21 — Asia geographic-code catch-up: Macao and British Indian Ocean Territory | 2 |
| 22 — Oceania: Australia, Christmas Island, Cocos (Keeling) Islands, Fiji, Kiribati | 261 |
| 23 — Oceania: Marshall Islands, Micronesia, Nauru, New Zealand, Palau | 40 |
| 24 — Oceania: Papua New Guinea, Samoa, Solomon Islands, Tonga, Tuvalu | 25 |
| 25 — Oceania catch-up: Vanuatu and 12 separately coded Pacific jurisdictions | 35 |
| **Total** | **3,046** |

**Important distinction:** Earlier discussions selected **110 airports** for Groups 1–3. The **162** airport candidates now in the master for those groups are a fresh, *runway-only* screen. The historical count of 110 and its 56 recovered names remain documented separately; it is not equivalent to the current screening count.

Group 12 begins the **Asia region**, using alphabetical five-country groups without repeating previously screened whole countries. Group 13 adds 558 qualifying airports: Cambodia 7, China 166, India 176, Indonesia 128, Iran 81. Six initially ambiguous runway surfaces were checked; four gained published surface confirmation, while Aurangabad and Baramati remain pending. One duplicate source code (Iran's OIBH) is kept in a separate conflict queue, not silently corrected or treated as approval.

Group 14 adds 172 runway-qualified airports: Iraq 15, Israel 17, Japan 106, Jordan 8, Kazakhstan 26. All of Kazakhstan is treated as one country. The original `asphalt concrete` material label for Mount Fuji Shizuoka Airport (RJNS, 2,200 m) now qualifies without assuming generic `paved` or `hard` surfaces are asphalt.

Group 15 adds 51 runway-qualified candidates: Kuwait 2, Kyrgyzstan 10, Laos 8, Lebanon 4, Malaysia 27. No additional uncertain runway labels or source-code collisions were found.

Group 16 adds 79 runway-qualified candidates (Maldives 6, Mongolia 8, Myanmar 24, Nepal 7, North Korea 34). This group has no unresolved runway-surface labels or new airport code conflicts. North Korea's results are runway-only and do **not** establish civilian access or game playability.

Group 17 adds 116 runway-qualified candidates (Oman 9, Pakistan 51, Palestine 0, Philippines 53, Qatar 3). The Palestine zero represents no matching records under the current dataset/criteria and does not assert no airport exists. No unresolved runway surfaces or new duplicate identifiers were found.

Group 18 adds 126 runway-qualified candidates (Saudi Arabia 64, Singapore 5, South Korea 28, Sri Lanka 10, Syria 19). No ambiguous runway surfaces or new source-code duplicates were found. These counts qualify runways only, without confirming civilian or commercial access.

Group 19 adds 92 runway-qualified candidates using OurAirports geographic codes: Taiwan (TW) 15, Tajikistan 9, Thailand 48, Timor-Leste 4 and Turkmenistan 16. The group has no uncertain runway-surface labels or new identifier conflicts. The screening uses source geography only and does not decide political status, civilian access or commercial operation.

Group 20 adds 79 runway-qualified candidates: United Arab Emirates 16, Uzbekistan 22, Vietnam 27, Yemen 12, Hong Kong 2. Hong Kong (HK) is a distinct OurAirports geographic source code. This adds missing Asian-country coverage and one separately coded territory; zero unresolved runway surfaces and no new duplicate identifiers.

Group 21 adds two runway-qualified candidates from separately coded Asian jurisdictions: Macau International Airport (VMMC, Macao/MO, 3,213.8 m concrete) and Naval Support Facility Diego Garcia (FJDG, British Indian Ocean Territory/IO, 3,658.5 m concrete). These airport-source geography codes do not decide sovereignty. Military or civilian-access issues are explicitly deferred; Diego Garcia's runway qualification does not establish that it is usable by player airlines. Other outlying Australian Indian Ocean territories will be screened with Oceania, not duplicated in Asia.

Group 22 starts **Oceania** with 261 runway-qualified candidates: Australia (whole country) 256, Christmas Island/CX 1, Cocos (Keeling) Islands/CC 1, Fiji 2 and Kiribati 1. Christmas Island and Cocos are kept as distinct source geographies, not double-counted under Australia. Australian Carrapateena Airport (YCPT) has a 1,600 m `BITUM`-reported runway; it remains on the unverified surface queue rather than being assumed asphalt. No Group 22 duplicate source identifiers were detected.

Group 23 adds 40 runway-qualified Oceania candidates: Marshall Islands 4, Micronesia 4, Nauru 1, New Zealand 30 and Palau 1. There are no new ambiguous runway-surface labels or duplicate identifiers. The unresolved Group 22 Carrapateena surface label remains excluded.

Group 24 adds 25 runway-qualified Oceania candidates: Papua New Guinea 20, Samoa 1, Solomon Islands 2, Tonga 1 and Tuvalu 1. No ambiguous runway surfaces or duplicate source identifiers were found in this group. Results qualify runway dimensions/material only, with operating access and six-category classification deferred.

Group 25 covers Vanuatu and 12 remaining Pacific jurisdictions, adding 35 qualifying airports: Vanuatu 3, American Samoa 1, Cook Islands 2, French Polynesia 19, Guam 1, New Caledonia 2, Niue 1, Norfolk Island 1, Northern Mariana Islands 2, Pitcairn Islands 0, Tokelau 0, Wallis and Futuna 1 and US Minor Outlying Islands 2. Zero matches do not imply no airfields exist. No new ambiguous runway surfaces or duplicate source identifiers were found; all are runway-only records pending operational evaluation and final six-tier classification.

Turkey is **one whole country**, including both European and Asian territories; Group 10 contains 75 Turkish runway-qualified airports.

Russia is **one country** in Airlinerra: all qualifying Russian airports are included regardless of whether they are in Europe or Asia. Russia has 312 runway-qualified records within Group 8; no longitude cutoff applies.

**Group 11 coverage note:** Åland's Mariehamn Airport (EFMA) is already counted under Finland in Group 3, and Svalbard Airport, Longyear (ENSB) is already counted under Norway in Group 7. Neither is duplicated. Greenland has five qualifying records and remains a single territory.

Group 9 contains two Spain runway-surface verifications based on official ENAIRE aeronautical material, recorded in [runway surface evidence](data/airports/runway_surface_overrides.csv).

**User-created fictional airport:** [Aleksandrovo Airport (LYAL)](data/airports/fictional_airports.csv), Serbia, has a **2,200 m asphalt runway** and an explicitly assigned **Level 1 (Local)** category. Its origin is marked FICTIONAL in the master and it will survive automated runway-screen refreshes. No real-world location or operational details have been invented.

[Full airport-register documentation and source files](data/airports/README.md) · [Historical recovery file](data/airports/historical_approved_recovery.csv).

Validate with:
```sh
python scripts/validate_airports.py
python scripts/validate_historical_airports.py
```

## Game premises
One real day = one in-game day, no historical eras. Airlines begin with $5,000,000 USD and zero aircraft. Architecture supports three independent worlds, initially launching one.
