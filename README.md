# Airlinerra

Public development repository for Airlinerra, a real-time browser airline-management game. Source code is public during development and may become private when the game launches (public copies cannot be recalled).

## Development process — main only
- **`main`** is the only active development branch. Routine code, runway collection, fixes and documentation changes go directly to `main`; do not use legacy `staging`.
- The project is **not production-live** merely because it is public. No production app or database deployment is authorized by development pushes.
- Run local validation regularly; group-specific GitHub Actions workflows are manual-only to avoid needless runs. Standard runners are free while the repository is public.
- Before connecting a production deployment to `main`, confirm the deployment policy because subsequent pushes may publish immediately.
- Nothing in this repository changes ProPeloton Manager or Game Control Center.

See [AGENTS.md](AGENTS.md) and [release procedures](docs/CONTROLLED_RELEASES.md).

## Airport runway collection — current stage
For now we store ONLY airports reporting a **non-closed asphalt/concrete runway of at least 1,200 metres**. Each meets **minimum Level 1 (Local)** runway criteria; no final categorization, operating permissions or other airport information is being gathered.

[Permanent master airport register](data/airports/airport_register.csv): **8,153 airports: 8,152 real runway-qualified candidates across 49 groups plus fictional LYAL**. Final gameplay categories remain unassigned for real airports. A [separate six-tier classification review](data/airports/classification/CLASSIFICATION_POLICY_V1.md) now holds preliminary traffic-based proposals without changing the master.

The table below is a **historical Groups 1–35 snapshot**, not the worldwide total.

| Group | Airports in historic Groups 1–35 |
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
| 26 — Africa: Algeria, Angola, Benin, Botswana, Burkina Faso | 87 |
| 27 — Africa: Burundi, Cabo Verde, Cameroon, Central African Republic, Chad | 23 |
| 28 — Africa: Comoros, Republic of the Congo, Côte d'Ivoire, Democratic Republic of the Congo, Djibouti | 42 |
| 29 — Africa: Egypt, Equatorial Guinea, Eritrea, Eswatini, Ethiopia | 82 |
| 30 — Africa: Gabon, The Gambia, Ghana, Guinea, Guinea-Bissau | 27 |
| 31 — Africa: Kenya, Lesotho, Liberia, Libya, Madagascar | 83 |
| 32 — Africa: Malawi, Mali, Mauritania, Mauritius, Morocco | 47 |
| 33 — Africa: Mozambique, Namibia, Niger, Nigeria, Rwanda | 82 |
| 34 — Africa: São Tomé and Príncipe, Senegal, Seychelles, Sierra Leone, Somalia | 25 |
| 35 — Africa: South Africa, South Sudan, Sudan, Tanzania, Togo | 112 |
| **Historical Groups 1–35 subtotal** | **3,656** |

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

Group 26 begins **Africa** with 87 runway-qualified candidates: Algeria 48, Angola 25, Benin 1, Botswana 11, Burkina Faso 2. No ambiguous runway surfaces or duplicate identifiers were found in this group. These are technical runway candidates only; civilian access, other airport details, and six-category classification remain deferred.

Group 27 adds 23 runway-qualified candidates in Africa: Burundi 1, Cabo Verde 5, Cameroon 10, Central African Republic 2, Chad 5. The Group 27 surface-review and duplicate-identifier queues are empty. Final classification and operating-access assessment are deferred.

Group 28 adds 42 runway-qualified candidates in Africa: Comoros 3, Republic of the Congo 8, Côte d'Ivoire 7, Democratic Republic of the Congo 22 and Djibouti 2. The Republic of the Congo (CG) and Democratic Republic of the Congo (CD) remain separate source codes. No new ambiguous runway materials or duplicate airport identifiers were found. These are runway-only candidate records, not proofs of civilian accessibility or final six-category ranking.

Group 29 adds 82 runway-qualified candidates in Africa: Egypt 56, Equatorial Guinea 5, Eritrea 2, Eswatini 2 and Ethiopia 17. Group 29 reported no ambiguous runway materials or duplicate identifiers. The existing review queues remain open; these are not approvals for civilian operation or final six-tier airport categories.

Group 30 adds 27 runway-qualified candidates in Africa: Gabon 11, The Gambia 1, Ghana 7, Guinea 6 and Guinea-Bissau 2. No new ambiguous runway-surface labels or duplicate source identifiers were found. These records qualify by runway only; civilian accessibility and final six-category ranking are deferred.

Group 31 adds 83 runway-qualified candidates in Africa: Kenya 12, Lesotho 2, Liberia 2, Libya 46 and Madagascar 21. The Group 31 uncertain runway-surface and duplicate-identifier queues are empty. These are technical runway matches only, with operating permissions and six-category classification deferred.

Group 32 adds **47** runway-qualified candidates: Malawi 6, Mali 7, Mauritania 9, Mauritius 4 and Morocco 21. Agalega Island Airstrip (FIMA) in Mauritius is included through a documented correction: the official 2026 AIP reports a 3,000 m rigid-pavement runway and OIDC confirms concrete, superseding the older source 1,303 m `Tarmac` entry. This correction is recorded in [runway surface evidence](data/airports/runway_surface_overrides.csv). Group 32 has zero unresolved surface or duplicate identifier cases; these are runway-qualified records only, not civil-operation or final airport-category approvals.

Group 33 adds **82** qualifying airports: Mozambique 17, Namibia 17, Niger 9, Nigeria 36, Rwanda 3. Official ASECNA AIP evidence confirms Niger's DRRN has a 3,800 m bituminous-concrete (asphalt-based) runway. This is an airport-specific correction, not a general acceptance of `BITUM` surfaces.

Group 34 adds **25** runway-qualified airports: São Tomé and Príncipe 2, Senegal 10, Seychelles 5, Sierra Leone 1, Somalia 7. No newly unresolved surfaces or duplicate identifiers. Final categorization among the six levels and game activation are deferred.

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


**2026-10-22 technical recovery:** Buenos Aires Aeroparque Jorge Newbery (SABE) was missing despite its official concrete runway; source ID 5771/runway 233011 restored. Total **8,153** including fictional LYAL, with Argentina **121** and Brazil **576**. The [Argentina ANAC annual traffic evidence](data/airports/commercial/group46/group46_argentina_anac_2025_official_passenger_totals.csv) is for provisional classification only.
