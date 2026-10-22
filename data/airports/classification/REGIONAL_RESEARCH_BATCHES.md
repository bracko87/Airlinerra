# Airlinerra — Worldwide airport traffic research batches

**As of 22 October 2026, from the current `main` technical master and classification review.** This is the live source-of-truth tracking baseline for *traffic evidence and eventual six-tier classification*, distinct from the already completed runway screening.

## Overall status

- All **49 runway-screening groups** cover **248 country/territory source codes**; **232** have eligible airport records, **16** have no qualifying runway in the current dataset.
- Master: **8,153 airports** (**8,152 real** and fictional LYAL). The historic green CI run #60 certified 8,152 records *before* SABE Aeroparque was restored; do not claim that CI result validates the current master.
- **Argentina, Brazil and Peru** have imported official 2025 passenger evidence used for provisional tiers: Argentina **38/121**, Brazil **138/576**, Peru **25/42**. Ecuador has two documented 2025 annual cargo-volume figures, but no traffic-based passenger categories. They are **PARTIALLY RESEARCHED**, not fully done.
- The other **230 country/territory codes with eligible real airports initially had no imported traffic tiers**; **Peru has 25 provisional regular-passenger tiers**, **Chile has 11 provisional domestic-only lower-bound tiers**, Ecuador has two annual cargo records without passenger tiers, and other B02 countries remain queued. **0 real airports** have owner-approved final six-tier assignments; fictional LYAL is Local.
- All 8,152 runway-qualified real airports still require eventual gameplay access and cargo/passenger rules to be established. Missing traffic evidence means **UNKNOWN**, not NO, not Local.

## Larger research batches

Instead of one country or many small GitHub Actions runs, research related country datasets as regional **batches**. Each batch should produce a **single crosswalk** of official named-airport annual passenger and cargo observations to existing source airport IDs, an evidence/unknown summary, and **one combined commit** to `main`. Work within any batch by national data source, without inventing evidence for unreported airports. Run automated validation at the end of a batch, not after each individual country.

| Batch | Scope | Source codes | Real airports | Provisional today | Status |
|---|---|---:|---:|---:|---|
| B01 | Argentina + Brazil — imported (partial) | 2 | 697 | 176 | Partially researched |
| B02 | Rest of South America | 13 | 311 | 47 | In progress: 47 provisional passenger proposals across eight areas |
| B03 | Canada + Mexico | 2 | 412 | 0 | Queued |
| B04 | United States — bulk national dataset | 1 | 2,879 | 0 | Queued |
| B05 | Northern America & Caribbean A | 14 | 75 | 0 | Queued |
| B06 | Northern America & Caribbean B | 23 | 83 | 0 | Queued |
| B07 | Europe A — groups 1–4 | 19 | 469 | 0 | Queued |
| B08 | Europe B — groups 5–8 | 20 | 546 | 0 | Queued |
| B09 | Europe C — groups 9–11 | 19 | 367 | 0 | Queued |
| B10 | Asia A — groups 12–14 | 15 | 757 | 0 | Queued |
| B11 | Asia B — groups 15–18 | 20 | 372 | 0 | Queued |
| B12 | Asia C — groups 19–21 | 12 | 173 | 0 | Queued |
| B13 | Oceania & Pacific — groups 22–25 | 28 | 362 | 0 | Queued |
| B14 | Africa A — groups 26–30 | 25 | 261 | 0 | Queued |
| B15 | Africa B — groups 31–37 | 34 | 388 | 0 | Queued |
| B16 | Antarctica — no technical candidates | 1 | 0 | 0 | No eligible airports |

## Complete country/territory list by batch

Each entry includes the number of runway-qualified real airports in parentheses. **Zero** means the technical runway screen found none, not that a country has no airports.

### B01: Argentina + Brazil — imported (partial)

Argentina (AR, 121) · Brazil (BR, 576)

### B02: Rest of South America

Bolivia (BO, 23) · Chile (CL, 46) · Colombia (CO, 76) · Ecuador (EC, 30) · Falkland Islands (Islas Malvinas) (FK, 1) · French Guiana (GF, 2) · Guyana (GY, 4) · Paraguay (PY, 12) · Peru (PE, 42) · South Georgia and South Sandwich Islands (GS, 0) · Suriname (SR, 1) · Uruguay (UY, 7) · Venezuela (VE, 67)

### B03: Canada + Mexico

Canada (CA, 280) · Mexico (MX, 132)

### B04: United States — bulk national dataset

United States (US, 2879)

### B05: Northern America & Caribbean A

Anguilla (AI, 1) · Antigua & Barbuda (AG, 2) · Aruba (AW, 1) · Bahamas (BS, 24) · Barbados (BB, 1) · Belize (BZ, 1) · Bermuda (BM, 1) · British Virgin Islands (VG, 1) · Caribbean Netherlands (BQ, 2) · Cayman Islands (KY, 2) · Costa Rica (CR, 9) · Cuba (CU, 28) · Curaçao (CW, 1) · Dominica (DM, 1)

### B06: Northern America & Caribbean B

Dominican Republic (DO, 10) · El Salvador (SV, 3) · Grenada (GD, 1) · Guadeloupe (GP, 2) · Guatemala (GT, 8) · Haiti (HT, 2) · Honduras (HN, 9) · Jamaica (JM, 4) · Martinique (MQ, 1) · Montserrat (MS, 0) · Nicaragua (NI, 7) · Panama (PA, 11) · Puerto Rico (PR, 9) · Saint Barthélemy (BL, 0) · Saint Martin (French part) (MF, 0) · St. Kitts & Nevis (KN, 2) · St. Lucia (LC, 2) · St. Pierre & Miquelon (PM, 1) · St. Vincent & Grenadines (VC, 2) · Sint Maarten (Dutch part) (SX, 1) · Trinidad & Tobago (TT, 2) · Turks & Caicos Islands (TC, 4) · U.S. Virgin Islands (VI, 2)

### B07: Europe A — groups 1–4

Albania (AL, 3) · Armenia (AM, 4) · Austria (AT, 9) · Azerbaijan (AZ, 14) · Belarus (BY, 14) · Belgium (BE, 14) · Bosnia & Herzegovina (BA, 4) · Bulgaria (BG, 16) · Croatia (HR, 10) · Cyprus (CY, 5) · Czechia (CZ, 17) · Denmark (DK, 12) · Estonia (EE, 6) · Finland (FI, 34) · France (FR, 151) · Georgia (GE, 10) · Germany (DE, 93) · Greece (GR, 42) · Hungary (HU, 11)

### B08: Europe B — groups 5–8

Iceland (IS, 8) · Ireland (IE, 7) · Italy (IT, 70) · Kosovo (XK, 2) · Latvia (LV, 4) · Liechtenstein (LI, 0) · Lithuania (LT, 6) · Luxembourg (LU, 1) · Malta (MT, 1) · Moldova (MD, 3) · Monaco (MC, 0) · Montenegro (ME, 2) · Netherlands (NL, 12) · North Macedonia (MK, 2) · Norway (NO, 31) · Poland (PL, 35) · Portugal (PT, 29) · Romania (RO, 21) · Russia (RU, 312) · San Marino (SM, 0)

### B09: Europe C — groups 9–11

Serbia (RS, 6) · Slovakia (SK, 7) · Slovenia (SI, 5) · Spain (ES, 63) · Sweden (SE, 61) · Switzerland (CH, 17) · Turkey (TR, 75) · Ukraine (UA, 27) · United Kingdom (GB, 96) · Vatican City (VA, 0) · Åland Islands (AX, 0) · Andorra (AD, 0) · Faroe Islands (FO, 1) · Gibraltar (GI, 1) · Greenland (GL, 5) · Guernsey (GG, 1) · Isle of Man (IM, 1) · Jersey (JE, 1) · Svalbard and Jan Mayen (SJ, 0)

### B10: Asia A — groups 12–14

Afghanistan (AF, 12) · Bahrain (BH, 3) · Bangladesh (BD, 9) · Bhutan (BT, 2) · Brunei (BN, 1) · Cambodia (KH, 7) · China (CN, 166) · India (IN, 176) · Indonesia (ID, 128) · Iran (IR, 81) · Iraq (IQ, 15) · Israel (IL, 17) · Japan (JP, 106) · Jordan (JO, 8) · Kazakhstan (KZ, 26)

### B11: Asia B — groups 15–18

Kuwait (KW, 2) · Kyrgyzstan (KG, 10) · Laos (LA, 8) · Lebanon (LB, 4) · Malaysia (MY, 27) · Maldives (MV, 6) · Mongolia (MN, 8) · Myanmar (Burma) (MM, 24) · Nepal (NP, 7) · North Korea (KP, 34) · Oman (OM, 9) · Pakistan (PK, 51) · Palestine (PS, 0) · Philippines (PH, 53) · Qatar (QA, 3) · Saudi Arabia (SA, 64) · Singapore (SG, 5) · South Korea (KR, 28) · Sri Lanka (LK, 10) · Syria (SY, 19)

### B12: Asia C — groups 19–21

Taiwan (TW, 15) · Tajikistan (TJ, 9) · Thailand (TH, 48) · Timor-Leste (TL, 4) · Turkmenistan (TM, 16) · Hong Kong (HK, 2) · United Arab Emirates (AE, 16) · Uzbekistan (UZ, 22) · Vietnam (VN, 27) · Yemen (YE, 12) · British Indian Ocean Territory (IO, 1) · Macao (MO, 1)

### B13: Oceania & Pacific — groups 22–25

Australia (AU, 256) · Christmas Island (CX, 1) · Cocos (Keeling) Islands (CC, 1) · Fiji (FJ, 2) · Kiribati (KI, 1) · Marshall Islands (MH, 4) · Micronesia (FM, 4) · Nauru (NR, 1) · New Zealand (NZ, 30) · Palau (PW, 1) · Papua New Guinea (PG, 20) · Samoa (WS, 1) · Solomon Islands (SB, 2) · Tonga (TO, 1) · Tuvalu (TV, 1) · American Samoa (AS, 1) · Cook Islands (CK, 2) · French Polynesia (PF, 19) · Guam (GU, 1) · New Caledonia (NC, 2) · Niue (NU, 1) · Norfolk Island (NF, 1) · Northern Mariana Islands (MP, 3) · Pitcairn Islands (PN, 0) · Tokelau (TK, 0) · US Minor Outlying Islands (UM, 2) · Vanuatu (VU, 3) · Wallis & Futuna (WF, 1)

### B14: Africa A — groups 26–30

Algeria (DZ, 48) · Angola (AO, 25) · Benin (BJ, 1) · Botswana (BW, 11) · Burkina Faso (BF, 2) · Burundi (BI, 1) · Cameroon (CM, 10) · Cape Verde (CV, 5) · Central African Republic (CF, 2) · Chad (TD, 5) · Comoros (KM, 3) · Congo - Brazzaville (CG, 8) · Congo - Kinshasa (CD, 22) · Côte d’Ivoire (CI, 7) · Djibouti (DJ, 2) · Egypt (EG, 56) · Equatorial Guinea (GQ, 5) · Eritrea (ER, 2) · Eswatini (SZ, 2) · Ethiopia (ET, 17) · Gabon (GA, 11) · Gambia (GM, 1) · Ghana (GH, 7) · Guinea (GN, 6) · Guinea-Bissau (GW, 2)

### B15: Africa B — groups 31–37

Kenya (KE, 12) · Lesotho (LS, 2) · Liberia (LR, 2) · Libya (LY, 46) · Madagascar (MG, 21) · Malawi (MW, 6) · Mali (ML, 7) · Mauritania (MR, 9) · Mauritius (MU, 4) · Morocco (MA, 21) · Mozambique (MZ, 17) · Namibia (NA, 17) · Niger (NE, 9) · Nigeria (NG, 36) · Rwanda (RW, 3) · São Tomé & Príncipe (ST, 2) · Senegal (SN, 10) · Seychelles (SC, 5) · Sierra Leone (SL, 1) · Somalia (SO, 7) · South Africa (ZA, 81) · South Sudan (SS, 4) · Sudan (SD, 12) · Tanzania (TZ, 13) · Togo (TG, 2) · Tunisia (TN, 12) · Uganda (UG, 3) · Western Sahara (EH, 3) · Zambia (ZM, 9) · Zimbabwe (ZW, 7) · French Southern Territories (TF, 0) · Mayotte (YT, 1) · Réunion (RE, 2) · Saint Helena, Ascension and Tristan da Cunha (SH, 2)

### B16: Antarctica — no technical candidates

Antarctica (AQ, 0)

### B02 source and status\n\nCombined updates now include **25 Peru regular-passenger estimates**, **11 Chile domestic-only quarterly estimates** and **two Ecuador annual cargo figures**. See [B02 source index](../commercial/batchB02/b02_official_2025_source_index.csv) and [report](../commercial/batchB02/B02_RESEARCH_REPORT.md). B02 remains **in progress**: 47 of 311 airports have passenger proposals, while 264 still lack source-matched passenger counts.\n\n## Execution order

1. **B02 — Rest of South America**: Bolivia, Chile, Colombia, Ecuador, Falkland Islands, French Guiana, Guyana, Paraguay, Peru, South Georgia/South Sandwich Islands, Suriname, Uruguay, Venezuela. Investigate bulk official traffic datasets; keep any unmatched airports UNKNOWN.
2. **B03 and B04 — Canada/Mexico + United States**: source-led national bulk research, not thousands of manual airport lookups. United States is a standalone batch because of its scale.
3. **B05–B15**: proceed through Caribbean/Central America, Europe, Asia, Oceania and Africa. Group countries by common public data providers when that reduces work.
4. **B01 revisit**: complete outstanding Argentina/Brazil traffic, alias and operational-access gaps. This step is distinct from the source import already finished.

No Supabase database or production changes are needed; final category assignments and permissions stay unmodified. All 6 proposed airport tiers remain: Local, Regional, Medium, Large, Major Hub, Mega Hub.

The authoritative row-by-row country checklist is [country_research_progress.csv](country_research_progress.csv). Regenerate or update it when airport totals or traffic-source coverage change; do not mistake this baseline for a constantly updated live database.
