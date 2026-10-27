# Airlinerra — France specialist airport expansion audit (2026-10-26)

## Why this batch started

The Swiss specialist series is **paused at an evidence-access boundary**: five remaining Swiss physical pavement/declared-distance checks require live Skyguide AIP/VFR or separate military publication access. Two Swiss inquiry drafts were prepared in Gmail but **not sent** because the email-send approval was declined; no paid source access was authorized. They remain unsent and those five Swiss technical holds remain unchanged.

To avoid repeated low-value Swiss research loops, the audit moved on to France. Supabase inspection found **105 French airport-registry records outside active World 1**, with **25 of these lacking an `airport_access_reviews` row** before this batch. The first batch addresses **three** of those 25, using the official **SIA France electronic AIP edition effective October 1, 2026**. It does **not** automatically increase gameplay-airport count.

**Batch marker:** `FR_SPECIALIST_01_2026_10_26`.

## First primary-source airport audit

| ICAO | Name | Imported source-runway result | Official French SIA eAIP 2026 AD 2.12 runway evidence | AD 2.13 declared distances / civil access | Specialist decision |
|---|---|---|---|---|---|
| **LFLX** | Châteauroux-Déols | 3,500 m `CON` | **RWY 03/21, 3,500 × 45 m, béton bitumineux / bituminous concrete (asphalt)** | Both directions **TORA, TODA, ASDA, LDA 3,500 m**. Civil IFR/VFR, published airport/AFIS/TWR hours, handling, customs for extra-Schengen **PPR 24h** | Independent physical asphalt/concrete length **VERIFIED**, identity/civil access **VERIFIED**; individual commercial passenger/cargo/charter permissions **UNVERIFIED**. Registry source surface `CON` preserved without falsely claiming the asphalt mixture is pure Portland cement concrete |
| **LFRC** | Cherbourg-Manche | 2,439.9 m `ASP` | **RWY 10/28, 2,440 × 45 m, béton / concrete** | RW10 TORA/TODA/ASDA/LDA **2,440m**. RW28 TORA **2,440**, TODA **2,715**, ASDA/LDA **2,440**: the **275 m** difference is a *clearway*, not extra physical runway. Open civil public IFR/VFR; extra-hour services and customs require relevant notice | Independent physical pavement **VERIFIED** (official **CONCRETE**, conflicting original `ASP`); operator commercial licensing remains unverified |
| **LFPB** | Paris–Le Bourget | **2,395.1 m** `ASP` | **Three qualifying asphalt/bituminous concrete runways:** 07/25 **2,991 × 45m** (longest), 03/21 **2,395 × 45m**, 09/27 **1,847 × 45m**. Original registry value corresponds to a *shorter* existing runway instead of the official longest runway | Official AD 2.2 expressly states: **"Prohibited to scheduled commercial traffic and to charter flights."** RW09 landings and RW27 takeoffs also specifically prohibited in AD 2.13. Airfield civil with business/private traffic and mandatory approved handling; not unrestricted airline operations | Physical pavement **VERIFIED**. **Passenger scheduled = PROHIBITED_BY_AIP** and **passenger charter = PROHIBITED_BY_AIP**. Specific general `commercial_permission_status` remains **UNVERIFIED**, not blanket authorized. Game **NOT_APPROVED** |

### Primary sources

1. French SIA AIP, LFLX AD 2: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-2.LFLX-fr-FR.html — runway length/surface AD 2.12; declared distances AD 2.13; services AD 2.3. Specific AD 2 page heading valid since 6 Aug 2026 within the **October 1 eAIP package**.
2. French SIA AIP, LFRC AD 2: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-2.LFRC-fr-FR.html — concrete surface, physical runway and 275m RW28 clearway. Specific AD 2 page heading valid since 6 Aug 2026 within **October 1 eAIP package**.
3. Cherbourg operator independent physical concrete confirmation (2,440 × 45 m): https://cherbourg.aeroport.fr/domaines-application/espace-pilote/
4. French SIA AIP, LFPB AD 2: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-2.LFPB-fr-FR.html — official October 1 effective edition, AD 2.2 traffic restrictions, AD 2.12 three runway lengths/surfaces, AD 2.13 declared lengths and disallowed direction operations.

### Evidence and controlled write-back

- Six source-specific `airlinerra.airport_evidence` entries: **IDs 2166–2171**, two per reviewed airport (physical AIP, operating rules), marker `FR_SPECIALIST_01_2026_10_26`.
- Three new `airlinerra.airport_access_reviews` rows created for the previously unreviewed airport keys **`OURAIRPORTS:4147` LFLX**, **`OURAIRPORTS:4207` LFRC**, **`OURAIRPORTS:4183` LFPB**.
- Each record: `identity_status='VERIFIED'`, `paved_runway_status='VERIFIED'`, `civilian_access_status='VERIFIED'`, `commercial_permission_status='UNVERIFIED'`, `game_admission_status='NOT_APPROVED'`. Le Bourget explicitly has `passenger_scheduled_status='PROHIBITED_BY_AIP'` and `passenger_charter_status='PROHIBITED_BY_AIP'`.
- Three immutable `airport_review_events`, **IDs 39–41**.
- Source `airport_registry` measurements and surface flags **not modified**, preserving provenance. The runway collection physical threshold is passed independently; ultimate per-airline service and aircraft scheduling are separate from runway-only admission.
- **No** World 1 additions, `airport_world_activation` changes, production deployment or final six-category assignments. The original **3,140 active World 1 airport records** must remain stable.
- The exact six game categories remain **Local, Regional, Medium, Large, Major Hub, Mega Hub**. These records do not assign a final category.

### Next French audit batch

There were **25** French registry candidates without access-review rows before this batch; now **22** remain. Prioritize additional civil aerodromes with independently source-verified qualifying asphalt/concrete material, for instance Épinal–Mirecourt LFSG and Saint-Nazaire–Montoir LFRZ, then review the military-only candidates with proper access distinction. French SIA AD1.3 often labels the surface merely **revêtue/paved**, which is **not** proof that it is explicitly asphalt or concrete; look for AD2.12 or an authoritative operator source before marking independently paved `VERIFIED`. Surface discrepancies must be logged and never silently overwritten.

**Conclusion:** France Batch 01 completed as **three specialist airport source reviews** with consequential correction of LFRC surface and LFPB longest-runway provenance, and an explicit Le Bourget commercial scheduled/charter prohibition. **Zero new playable airports admitted**.

---

## Batch 02 — France civil and naval/civil runway specialist review (2026-10-26)

**Source run:** `FR_SPECIALIST_02_2026_10_26`  
**Scope:** Épinal–Mirecourt (LFSG), Saint-Nazaire–Montoir (LFRZ), Lorient Lann-Bihoué/Bretagne Sud (LFRH), Dijon–Longvic (LFSD). All four were source-registry `RUNWAY_QUALIFIED`, outside World 1 and missing an access review. The French **SIA eAIP cycle effective 2026-10-01 through 2026-10-28** is the controlling publication period for this audit; where SIA AD2 pages were inaccessible, **specific gaps are marked** rather than substituting dates silently.

### Summary decision table

| ICAO | Original registry | Independent runway facts | Civil and operational constraints | Database physical gate | Game admission |
|---|---|---|---|---|---|
| **LFSG** Épinal–Mirecourt | 2,699.9 m `CON` | Current SIA 2026 AD 1.3 **2,700 × 45 m `revêtue` (paved)**, 08/26. French airport association 2022–23 guide calls the surface **`bitume` (asphalt)**. Last accessible detailed **2025-10-02** SIA AD2 table: RW08 TORA/TODA/ASDA/LDA **2,700m**; RW26 TORA 2,700, TODA/ASDA 2,820, LDA **2,440m**. **2026 current detailed AD2 material/declared distances not fetched**. | French municipality recognizes seasonal scheduled, charter, business, freight and ambulance aviation in principle; operator-specific airline permission and current published service gates still pending. | **VERIFIED physical paved collection** using independent historical material plus current 2,700m official paved runway; exact current material/source conflict recorded | **NOT_APPROVED** |
| **LFRZ** Saint-Nazaire–Montoir | 2,400 m `ASP` | Current SIA 2026 AD 1.3 **2,405 × 45m paved** 07/25, **5m difference** from source registry and airport operator 2,400m. Earlier **French DREAL official transport infrastructure** report (2015 data, 2016 publication) says **`bitume`**; Ministry of Sports facility census says **`béton`**. Both types qualify, but **actual 2026 subtype unresolved**, particularly after 2019 pavement improvements. Latest AD2 TORA/LDA could not be fetched. | VINCI Airport operator confirms airport dedicated to Airbus BelugaXL / aviation industrial transport, 2019 €15m upgrades and 2023 21,500 tonnes industrial freight. This **does not** prove general passenger carrier admission or unrestricted airline slots. | **VERIFIED physical asphalt-or-concrete collection** based on public-sector material records and current official `paved` length; exact subtype conflicts preserved | **NOT_APPROVED** |
| **LFRH** Lorient Bretagne Sud / Lann-Bihoué | 2,403 m `CON` | Current SIA 2026 AD2.12 **RW07/25 2,403 × 45m CONCRETE**, **RW02/20 1,670 × 45m CONCRETE**. RW07 TORA 2,403/TODA 2,428/ASDA 2,428/LDA 2,403; RW25 TORA 2,403/TODA 2,503/ASDA 2,503/**LDA 2,230** due **173m displaced threshold**. RW02 TORA 1,670/TODA 1,885/ASDA 1,670/LDA 1,670; RW20 all 1,670. | Active **French Navy-operated** airport with separately serviced civilian terminal. Civil flights allowed within military/naval controls; ATS weekdays on PPR, non-Schengen customs notice 24h, arrestor wires, radio/transponder requirements, and **ICAO code-E taxiway usage prohibited**. Never infer unrestricted airline use. | **VERIFIED** two qualifying concrete runways | **NOT_APPROVED** |
| **LFSD** Dijon–Longvic | 2,400 m `ASP` | Current SIA 2026 AD2.12 **RW17/35 2,400 × 45m béton bitumineux (ASPHALT)** and **RW01/19 1,200 × 23m béton bitumineux**. Directional AD2.13 TORA/TODA/ASDA/LDA equal physical runway lengths for all four directions. | Civil IFR/VFR EDEIS site, AFIS normally **08:00–17:00 UTC winter**; extension **PPR 24h**. Handling mandatory aircraft **MTOW >3t**, RFFS Cat 5 during ATS, Cat 1 outside unless special PPR. Commercial individual airline permissions unresolved. | **VERIFIED** two qualifying asphalt runways | **NOT_APPROVED** |

**Physical runway-only rule:** Airlinerra collection requires ≥1,200 m **physical** paved asphalt/concrete and runway not recorded closed. A reduced LDA, naval arrestor cable, clearway, PPR, service-hours restriction or absent airline contract does not retrospectively change physical runway length or confer an unrestricted route right. The SIA use of `béton bitumineux` means bituminous concrete/asphalt, not necessarily plain Portland cement concrete.

### Sources and evidence confidence

**Directly authenticated effective October 2026 French eAIP:**
- LFSD detailed AD2 runway materials/lengths, declared distances, PPR/handling/RFF: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-2.LFSD-fr-FR.html (AD2.2–2.6, 2.12–2.13).
- LFRH detailed AD2 materials, declared distances and naval/civil access rules: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-2.LFRH-fr-FR.html (AD2.2–2.4, 2.12–2.13, 2.20–2.23).
- Official 2026 AD1.3 nationwide aerodrome register lists **LFSG 2,700 ×45 paved 08/26** and **LFRZ 2,405 ×45 paved 07/25**: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-1.3-fr-FR.html . The very large AD1.3 HTML was accessible via search excerpts, not a full-page reader. Direct detailed **LFSG** and **LFRZ** SIA AD2 URLs could not be fetched: current exact asphalt/concrete subtype and 2026 per-direction declared distances are separately unverified.
- Historical (not 2026) LFSG detailed SIA AD2 available in **2025-10-02 AIP**: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_30_OCT_2025/FRANCE/AIRAC-2025-10-02/html/eAIP/FR-AD-2.LFSG-fr-FR.html . Do not make prior 2025 TORA/LDA effective in 2026 automatically.

**Independent airfield operator/public administration:**
- Épinal airport association 2022–23 guide (search-indexed, download did not open for full source validation): https://www.aeroport.fr/uploads/documents/guide-des-aeroports-francais-2022-2023.pdf?v12.2= . It identifies **2,700 ×45 m bitumen**. Confidence below current official AD2, but independently corroborates surface type. Épinal city public flight-service information: https://www.epinal.fr/vivre-a-epinal/me-deplacer/en-avion/ .
- Saint-Nazaire DREAL government transport-statistics report, published 2016 for 2015, says **2,400 ×45m bitumen**: https://portail.documentation.developpement-durable.gouv.fr/pub/PLOOUV00267331-situation-des-transports-pays-loire-les-flux-aerie.html .
- French Sports facility inventory also classifies airport runway as **concrete** (important material subtype conflict, 2,400 ×45m), mirrored with official attribution by https://www.cartes-2-france.com/activites/I441030009/aerodrome-saint-nazaire-montoir.php .
- VINCI Airports operator: https://vinci-airports.com/fr/nos-aeroports/france/aeroport-saint-nazaire-montoir/ ; 2,400m runway, 2019 refurbishments, BelugaXL and industrial cargo. Physical source discrepancy 2,400 vs 2026 official 2,405 preserved, *no rewrite of registry source*.

**Important data-strength note:** Unlike LFSD/LFRH, **LFSG/LFRZ's specific current asphalt-or-concrete composition is not directly spelled out in the retrievable October 2026 SIA AD2 publication.** The `paved_runway_status='VERIFIED'` field here means independently corroborated eligible **physical runway candidate** using historic government/association specific material plus current SIA paved length, not full current AIP operating or runway-material recertification. If future policy demands current original AD2 for every verified type, place LFSG/LFRZ on a stricter final-current-publication gate until those pages are obtained.

### Actual recorded changes

- **Eight** private `airlinerra.airport_evidence` records, IDs **2172–2179**, two source-specific records per reviewed airport, tied to `FR_SPECIALIST_02_2026_10_26`.
- **Four** new `airlinerra.airport_access_reviews`: verified identities and physical asphalt/concrete research candidate screens. Lorient `civilian_access_status='RESTRICTED_NAVAL_CIVIL_SHARED'`; other three `civilian_access_status='VERIFIED'`. All four retain `commercial_permission_status='UNVERIFIED'` and `game_admission_status='NOT_APPROVED'`.
- **Four** `airlinerra.airport_review_events`, IDs **42–45**, preserving the AIP/secondary distinction.
- **Zero** entries added to World 1, **zero** source rows overwritten, **zero** final category assignments. Category names remain **Local, Regional, Medium, Large, Major Hub, Mega Hub**.

**Next:** Twenty-two French candidates lacked access-review rows after France Batch 1; four of them are now covered by Batch 2, leaving **18** pending access-review creation if no concurrent process has changed this subset. Continue direct French SIA AIP investigation for additional civilian sites, or use a deliberately separate military access research stream; do not conflate runway eligibility with legal passenger service.

---

## France Batch 03 — military access and specific runway-material verification (2026-10-26)

Batch `FR_SPECIALIST_03_2026_10_26`, source evidence IDs **2180–2188** (9 observations), new access-review rows for **4 airports**, audit event IDs **46–49**. No World 1 admissions or changes to the original registry. Source edition: French SIA eAIP October 1, 2026.

| ICAO | Source-runway comparison | Physical independent status | Flight access |
|---|---|---|---|
| LFRJ Landivisiau | Registry 2699.9m CON. SIA AD2 official **2700×45m concrete** RW07/25. Non-based aircraft normally only **2410m TORA/TODA/ASDA**, full 2700m with prior request; nominal LDA 2700m. | **VERIFIED** | French Navy airbase **not open to public air traffic**, special permission/PPR 48h. |
| LFOA Avord | Registry 3503.1m ASP. SIA RW06/24 **3503×45m macadam** (not explicitly asphalt or concrete). RW06 ASDA 3903m includes 400m stopway, **not** added physical length. | **UNVERIFIED** specific material; registry provisional `RUNWAY_QUALIFIED` untouched | Military BA702 **not open to public air traffic**; civil permission at least 72h beforehand. |
| LFMO Orange-Caritat | Registry 2410.7m CON. SIA RW14/32 **2407×45m macadam**, with **330m** concrete at one threshold and **262m** concrete at other. The short concrete sections alone cannot independently establish a continuous ≥1200m runway of explicit asphalt/concrete material. | **UNVERIFIED** specific qualifying surface; provisional original registry screen retained | Military BA115 **not open to public air traffic**, requires flight director approval. |
| LFBF Toulouse-Francazal | Registry 1800.1m ASP. Airport operator RW11/29 **1800×45m paved**. Main-runway contractor Spie batignolles documents 2020 runway bituminous rehabilitation (overall project 40,000 tonnes bituminous mix; **do not assign this whole tonnage to runway**). | **VERIFIED** research asphalt-pavement gate; October 2026 directional TORA/LDA still unchecked | Civil airport, **airport-operator authorization required** before arrival. |

**Official October 2026 SIA AD2 sources:** 
- https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-2.LFRJ-fr-FR.html
- https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-2.LFOA-fr-FR.html
- https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-2.LFMO-fr-FR.html

**Civil airport operator:** https://toulouse-francazal.aeroport.fr/en/domaines-application/pilot-info/  
**Actual runway rehabilitation contractor:** https://www.spiebatignolles.fr/realisation/aeroport-toulouse-francazal/

All four `commercial_permission_status='UNVERIFIED'` and `game_admission_status='NOT_APPROVED'`; military/civilian operating restrictions encoded in `civilian_access_status`. Total France missing-access-review candidates went from 18 to **14** following these four records. The unchanged six classification tiers are **Local, Regional, Medium, Large, Major Hub, Mega Hub**.

---

## France Batch 04 — four further military fields, 27 October 2026

**Marker:** `FR_SPECIALIST_04_2026_10_27`. Earlier France Batch 03 documentation has been committed separately to GitHub `main` (commit `6a7901a59f9ff51072fdee5b2ee9cc59def290b5`). This batch reviews four of the **14** remaining French airports without access-review records. All measurements below are from the **official France SIA AD 1.3 register, effective October 1, 2026**, and apply to the October 2026 record snapshot. The indexed official register contained the relevant airfield rows; the more detailed AD2 aerodrome publications were not independently retrieved this pass. **AD1.3 does not supply full TORA/TODA/ASDA/LDA, aircraft restrictions or carrier-specific authorizations.**

| Airport | Original OurAirports registry | French SIA October 2026 AD1.3 official physical runway | Airfield use and distinct research status |
|---|---|---|---|
| **LFMI Istres–Le Tubé** | 3,750m **ASP** | **RW 15/33, 3,750 × 53m, béton / concrete** | Military **restricted**. `paved_runway_status='VERIFIED'` based on explicit independently published concrete; original registry asphalt surface retained as an unmodified source discrepancy. Commercial/civilian airline use unverified. |
| **LFSX Luxeuil–Saint-Sauveur** | 2,432.9m **ASP** | **RW 11/29, 2,433 × 45m, béton / concrete** | Military **restricted**. `paved_runway_status='VERIFIED'`; original ASP source preserved, official concrete material used in research review. The French military aeronautical DIRCAM catalog also documents this as a restricted-use facility, but current detailed AD2 rules remain to be checked. |
| **LFKS Solenzara (BA126)** | 2,627.1m **CON** | **RW 18/36, 2,627 × 45m, revêtue / paved**, *exact specific surface material not given in accessible AD1.3* | Military **reserved to the State**. Existing source-registry runway provisional `RUNWAY_QUALIFIED` preserved, but independent explicit asphalt/concrete gate `UNVERIFIED`. Detailed AD2/military material source and any approved civilian exceptions still missing. |
| **LFMY Salon-de-Provence (BA701)** | 2,001m **CON** | **RW 16/34, 2,001 × 45m, revêtue / paved**, plus short grass runways | Military **restricted**. Exact asphalt/concrete surface independently `UNVERIFIED` on AD1.3 alone; independent historic secondary sources call 16/34 concrete, but not accepted as current direct SIA pavement certification. No automatic airline permission. |

**Primary source:** [French DGAC SIA eAIP AD 1.3, AIRAC Oct 1 2026](https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-1.3-fr-FR.html). Relevant published rows are LFMI, LFSX, LFKS and LFMY.

**Source distinctions:** `béton` is explicitly concrete and meets the minimum. `revêtue` only means paved, so **not** independently conclusive under Airlinerra's strict asphalt-or-concrete rule. Runway source data in `airport_registry` are not overwritten. The `RUNWAY_QUALIFIED` candidate flag remains from the original data even where independently reviewed exact material is not yet verified. A military restricted field can qualify physically without authorizing scheduled airline flights.

**Confirmed Supabase work:**
- **8** `airport_evidence` observations, IDs **2189–2196**, separate physical-vs-legal provenance for each field.
- **4** new `airport_access_reviews` with identity verified; two physical independent `VERIFIED`, two `UNVERIFIED` exact-material holds. `commercial_permission_status='UNVERIFIED'` and `game_admission_status='NOT_APPROVED'` for all four.
- **4** `airport_review_events`, IDs **50–53**, source marker as above.
- No new gameplay admissions, no direct activation or source-runway mutation, and no final six-tier classification assigned.
- Follow-up: retrieve effective original AD2 or DIRCAM military data for 2026 declared distances and exact surfaces especially LFKS/LFMY; clarify any civilian privileges separately. The remaining French unreviewed set is expected to fall from **14 to 10** (verify live SQL after this documentation commit).

**Game safeguard:** The 3,140 World 1 airport activation records must remain active and unchanged. Six final categories are only **Local, Regional, Medium, Large, Major Hub, Mega Hub**.

---

## France Batch 05 — Évreux, Saint-Dizier, Orléans and Nancy-Ochey (27 October 2026)

**Research marker:** `FR_SPECIALIST_05_2026_10_27`. Four further military aerodromes were present in `airport_registry` but outside World 1 and without a dedicated `airport_access_reviews` record. The source period is **official French SIA eAIP 01 October 2026**, valid through 28 October inclusive. The SIA **AD 1.3** nationwide published aerodrome register is a current physical and general-use source, **not** the full aerodrome AD2 with takeoff/landing-distance and legal operating procedures. Historic AD2/military charts are recorded as auxiliary provenance only. Do not overwrite the original imported registry.

| ICAO / name | OurAirports source | Official current SIA AD1.3 | Independent runway gate | Civil/airline gate |
|---|---|---|---|---|
| **LFOJ Orléans–Bricy (BA123)** | 2,404m ASP | **RWY07/25, 2,404×45m, `béton` / concrete** | **VERIFIED** explicit concrete >1,200m. Current DGAC material **CONCRETE** differs from raw source ASP | `RESTRICTED_MILITARY_RESERVED_TO_STATE` per DGAC register; carrier specific permissions `UNVERIFIED`; game `NOT_APPROVED` |
| **LFSO Nancy–Ochey (BA133)** | 2,401.2m CON | **RWY02/20, 2,400×45m `béton` / concrete** | **VERIFIED** explicit 2026 current SIA concrete. 1.2m imported length difference. **Note** older 16 May 2024 French military DIRCAM aerodrome chart described the runway as **1,920m central bitumen/asphalt plus 240m concrete at each end**. The 2026 SIA single material label may simplify that mixed composition. Both sources describe eligible materials; never silently rewrite raw source or conflate dates. | `RESTRICTED_MILITARY_RESERVED_TO_STATE`; no scheduled airline right; game `NOT_APPROVED` |
| **LFOE Évreux–Fauville (BA105)** | 2,995m ASP | **RWY04/22, 3,001×45m `revêtue` / paved** | **UNVERIFIED precise explicit material** in current AD1.3; physical length now **6m longer** than registry. Archived April 2026 SIA AD2 reports **concrete–macadam mixed** surface and 3,001m, but does not quantify how much is continuously asphalt/concrete under a strict material-only test. Preserve original provisional `RUNWAY_QUALIFIED`, not a verified current full asphalt runway. | `RESTRICTED_MILITARY_AERODROME`; no general commercial right; game `NOT_APPROVED` |
| **LFSI Saint-Dizier–Robinson (BA113)** | 2,411.9m ASP | **RWY11/29, 2,413×45m `revêtue` / paved**; also RW11L/29R **1,200×100m grass** (does *not* qualify). | **UNVERIFIED precise asphalt-or-concrete**: current AD1.3 specifies only paved, not subtype. Source registry difference **1.1m**. Earlier AIP mentions apron/taxiway concrete/macadams, which are **not evidence of runway surface**. | `RESTRICTED_MILITARY_AERODROME`; no general commercial right; game `NOT_APPROVED` |

**Primary official 2026 source:** French DGAC SIA AD1.3, 01 October 2026, including the four named airport rows: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-1.3-fr-FR.html .

**Additional date-bounded source context (not current operational authority):**
- LFOE original SIA AD2 April 2026 archive, surfaced with `béton/concrete–macadam` remark and 3001m declared nominal distances: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_16_APR_2026/FRANCE/AIRAC-2026-04-16/pdf/FR-AD-2.LFOE-fr-FR.pdf . The PDF reader's image request did not load, so figures were not promoted to current Oct 2026 flight-performance data.
- LFSO French military DIRCAM landing chart, 16 May 2024, states **bitumen central 1,920m, concrete 240m both ends**, recorded as an **older source-specific material description**: https://www.dircam.dsae.defense.gouv.fr/images/Stories/Doc/AVUE/avue_nancy_ochey_lfso.pdf . The direct PDF viewer timed out; do not claim contemporary detailed TORA/LDA proof from it.
- LFOJ archived DGAC AD2 April 2026 also lists 2404×45 concrete; 2026 October AD1.3 is the **controlling current source** rather than that historic detailed page.

**Changes in private Supabase project `hwllkabgzaynalahvkpz`:**
- **8** `airlinerra.airport_evidence` entries IDs **2197–2204**, two per airport (physical SIA register vs military-access status), using marker `FR_SPECIALIST_05_2026_10_27`.
- **4** new `airlinerra.airport_access_reviews`: identities verified; LFOJ/LFSO paved material independently **VERIFIED**, LFOE/LFSI **UNVERIFIED** specific material; all restricted military and `commercial_permission_status='UNVERIFIED'`, `game_admission_status='NOT_APPROVED'`.
- **4** `airlinerra.airport_review_events` IDs **54–57**, with field-level provenance and no gameplay authorization.
- No changes to original `airlinerra.airport_registry` source length/surface, no new airport admissions, world activations or category assignments. The exact six final game categories remain **Local, Regional, Medium, Large, Major Hub, Mega Hub**.

**Follow-up:** obtain the 2026 effective SIA AD2 detailed surface and available-distance notes for LFOE/LFSI and recheck LFSO's 2024 military mixed-pavement context, keeping civil authorizations a distinct legal gate. The remaining previously-unreviewed French military airports will be counted from live Supabase after this commit.
