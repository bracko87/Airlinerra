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

---

## France Batch 06 — six final missing-access-review candidates (27 October 2026)

**Research marker:** `FR_SPECIALIST_06_2026_10_27`  
**Edition:** French DGAC SIA AIRAC **10/26** (October 1–28, 2026), official eAIP AD 1.3 register, with expressly dated supplemental evidence from May 2026 SIA AD 2, 2025 DIRCAM, and a **binding 2021 French ministerial closure decree**. These are research audits, **not flight-planning guidance**; live NOTAMs and carrier permits remain separate. The registry is preserved exactly as imported, even where its historic runway figures conflict with later authority information.

### Decisions by airfield

| ICAO | Historical registry length / material | Authoritative later runway evidence | Independent strict asphalt-or-concrete review / access |
|---|---|---|---|
| **LFBC Cazaux (BA120)** | 2,407.9m `ASP` | DGAC original AD 2 available May 2026 describes **RWY 06/24 2,398 ×45m** `béton-macadam` (concrete–macadam), **9.9m less** than registry. Dated source also lists RW06 clearway 318m / RW24 314m; these are **not** extra physical runway. | `paved_runway_status='UNVERIFIED'` under strict current continuous asphalt/concrete surface proof: mixed material not quantified and 2026 October AD2 update unverified. Active **military restricted**. No commercial route authorization. |
| **LFQE Étain–Rouvres (ALAT)** | **2,400m `ASP`** | **October 2026 SIA AD1.3 1,721 ×45m `revêtue`** RW01/19 — **679m shorter** than imported runway. Older original military DIRCAM (2025, preserved as secondary copy) also lists 1,721m physical, with RW01 TODA 2,000m / ASDA+LDA 1,721m and RW19 TODA 1,996m / ASDA+LDA 1,721m. Those larger TODA figures are **not physical runway**. Historical DIRCAM directory indicates mixed concrete–macadam rather than definitive asphalt continuous 1,200m. | `paved_runway_status='UNVERIFIED'` independent exact material, **registry remains source-screen provisional only**, military access restricted. The **679m length mismatch is high-priority cleanup** before aircraft performance calculations. |
| **LFPC Creil (former BA110)** | 2,399.1m `CON` (historic runway) | **French ministerial arrêté of June 2, 2021, in force June 14, 2021** **CLOSED the aerodrome to ALL air traffic and removed it from the designated aerodrome list**. Former airfield grounds were redeveloped for an industrial-scale solar farm by July 2026. Historical concrete runway is not evidence of an operational airport. | **Definitive exclusion:** `review_status='FR_B6_EXCLUDED_BY_LEGAL_AERODROME_CLOSURE_2021'`, `civilian_access_status='CLOSED_ALL_AIR_TRAFFIC_BY_FRENCH_LAW_2021'`, passenger scheduled/charter/cargo/commercial all `PROHIBITED_CLOSED_AERODROME`, `game_admission_status='NOT_APPROVED'`. Do not re-import or activate as a new playable airport regardless of length. Historical `airport_registry` source row is retained solely for immutable provenance. |
| **LFQP Phalsbourg–Bourscheid** | 2,196.1m `ASP` | Oct 2026 SIA AD1.3 **2,202 ×45m `macadam`**, RW05/23; **5.9m longer** than original, and current runway magnetic labels differ from older RW06/24 charts. | `paved_runway_status='UNVERIFIED'` exact asphalt/concrete; military restricted, airline permission unresolved. |
| **LFXA Ambérieu (BA278)** | 2,000.1m `ASP` | Oct 2026 SIA AD1.3 **RW01L/19R 1,993 ×30m `revêtue` / paved**, **7.1m shorter** than registry; also 800×100m **unpaved** RW01R/19L, which does NOT qualify. Published **mixed military/civil, open to public air traffic**; this is not the same as a general commercial passenger/charter carrier permit. Older DIRCAM VAC lists **RW19R LDA 1,791m** vs RW01L 1,993m, but does not independently certify current runway asphalt/concrete material. | `paved_runway_status='UNVERIFIED'` exact subtype; `civilian_access_status='MIXED_MILITARY_CIVIL_OPEN_TO_PUBLIC_AIR_TRAFFIC'`. Legal airport open, but airline-specific authorization unverified and game NOT_APPROVED. |
| **LFPV Vélizy–Villacoublay (BA107)** | **1,813m `ASP`** | Oct 2026 SIA AD1.3 **RW09/27 1,957 ×45m `enrobé bitumineux` (bituminous asphalt)**, **144m longer** than source registry. Archived 2023 French DIRCAM chart independently agrees with 1,957m and lists directional LDA 1,886m / 1,884m (not certified October 2026). | **VERIFIED** independently explicit full-length asphalt >=1,200m; **military restricted**. No scheduled/commercial general permission, game NOT_APPROVED. |

### Authoritative and dated sources

- **Current (as of Oct 27, 2026) DGAC/SIA nationwide AD1.3** with LFQE 1,721m, LFQP 2,202m macadam, LFXA 1,993m paved and LFPV 1,957m bituminous runway: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-1.3-fr-FR.html .
- **Official legally binding Creil closure**, **June 2, 2021 arrêté** in force June 14, 2021, French Government Légifrance: https://www.legifrance.gouv.fr/loda/id/JORFTEXT000043648488/ .
- **Creil site reuse, 2026 local-government document:** https://www.ccac.fr/wp-content/uploads/2026/02/Deliberations-et-annexes-du-conseil-communautaire-du-10-fevrier-2026-sans-PV.pdf . July 2026 news corroboration: https://www.leparisien.fr/oise-60/150-millions-deuros-et-331-830-panneaux-plus-tard-lex-base-militaire-de-creil-devient-la-2e-ferme-solaire-de-france-06-07-2026-ZNBOTCC675AYNAQ3NGIO5GI52U.php .
- **LFBC DGAC/SIA dated May 14, 2026 original detailed AD2:** https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_14_MAY_2026/FRANCE/AIRAC-2026-05-14/pdf/FR-AD-2.LFBC-fr-FR.pdf (search-extracted official text reports 2,398m concrete–macadam; direct full-page PDF capture unavailable during this pass, so treat it as date-bounded until checked).
- **LFQE military DIRCAM 2025 original chart copied via external reproduction**, not a current 2026 AIP: https://fr.scribd.com/document/910791323/LFQE-Etain-Rouvres-VAC .
- **LFQP supplementary independent airfield directory** matches 2,202m dimensions: https://europeairfields.com/airfields/france/lfqp/phalsbourg-bourscheid .
- **LFXA secondary dated original DIRCAM runway VFR transcription:** https://www.wingman-vfr.com/terrain/lfxa .
- **LFPV DIRCAM 2023 original military chart** corroborates 1,957×45m and directional shorter LDA: https://www.dircam.dsae.defense.gouv.fr/images/Stories/Doc/MIAC4/miac4_villacoublay_lfpv.pdf (historic chart only, not 2026 flight clearance).

### Supabase records and version-control safeguards

- **12** `airlinerra.airport_evidence` rows, IDs **2205–2216**, two observations per airport (physical source distinction and legal-access status).
- **6** new `airlinerra.airport_access_reviews` with four explicit technical-material holds (LFBC, LFQE, LFQP, LFXA), one `VERIFIED` asphalt pavement (LFPV), and one **legally closed airport** separately excluded (LFPC).
- **6** `airlinerra.airport_review_events` IDs **58–63**, `source_run_id='FR_SPECIALIST_06_2026_10_27'`.
- **No mutations** of `airport_registry` historical raw source values, **no World 1 additional airport approvals or activations**, **no final six-category assignments**. Creil is an exclusion despite the registry's historic `RUNWAY_QUALIFIED` marker because it violates the mandatory **not-closed** runway-collection criterion.
- Audits include the source-effective date and distinguish current aerodrome register from historical pilot charts and operator/public law. The original registry should not be overwritten to “correct” discrepancies unless a separately authorized versioned source-correction process is adopted.

### Consolidated France result after Batches 01–06

**The original French outside-World1 registry contains 105 candidates. All 105 now have access-review records: 0 missing.** Six specialist batches have filled the **25 previously absent** access reviews, with **51 distinct research evidence records** across those 25 airports (6+8+9+8+8+12).

Live field-level totals as of this batch: **14/105 `paved_runway_status='VERIFIED'`**, **91/105 `UNVERIFIED'`**. The 91 include **one separate definitive legal closure (LFPC Creil)** and **90 unresolved pavement-review cases**, many of which were already present as pre-existing source-only reviews before the specialist project. **A populated access-review record means that case has entered or passed a review step, not that every technical and legal gate passed.** All **105/105** currently remain `game_admission_status='NOT_APPROVED'`, including the 14 with independent pavement verification.

**Research milestone completed:** France's **missing-access-review backlog is zero**, but **the technical evidence backlog is NOT zero**. Prioritize French existing older source-only `UNVERIFIED` candidates that could pass the strict pavement gate and have plausible civil operations; do not repeatedly research closed LFPC or try to approve military-only airports automatically.

**Game catalog:** World 1's already-approved 3,140 source keys in the private prelaunch `airlinerra_game` catalog remain unchanged. The six categories are still exactly **Local, Regional, Medium, Large, Major Hub, Mega Hub**; none assigned by this specialist review. No launch authorization granted.

---

## France civil airport verification pass 01 — existing technical holds (27 October 2026)

**Run marker:** `FR_SPECIALIST_CIVIL_01_2026_10_27`. This is the first targeted pass against the **90 unresolved French pavement review cases**, prioritizing civil airports over military fields. It reopens **four existing `airport_access_reviews`** rather than adding more rows to the already complete 105/105 initial-review inventory. The **official October 1, 2026 French DGAC SIA eAIP** was opened directly for each reviewed airport; the LFBA, LFLY and LFRD aerodrome subsections carry locally dated **August 6, 2026** amendment validity and appear within the October cycle, whereas LFOH's page is effective **October 1, 2026**. The current eAIP is effective October 1–28, 2026; later updates/NOTAMs have not been checked.

### Authority-backed physical and operational records

| ICAO, airport | Current DGAC/SIA AD2.12 **physical runway** | Current DGAC/SIA AD2.13 **directional declared distances** | Technical and commercial disposition |
|---|---|---|---|
| **LFOH Le Havre–Octeville** | **RW04/22 2,300 × 40m, `béton bitumineux` / bituminous concrete (asphalt)**; original registry 2,300m ASP agrees. | RW04 and RW22 each **TORA/TODA/ASDA/LDA 2,300m**. | **Independent `paved_runway_status='VERIFIED'`**. Civil IFR/VFR airport, AFIS and published handling/airport hours, customs/immigration requests tied to date/service. AIP AD2.20 additionally states **code D aircraft lack paved shoulders on main runway and taxiway**; taxiway A wingspan <36m restriction. Do not infer individual airline or any unrestricted hub operation. |
| **LFRD Dinard–Pleurtuit–Saint-Malo** | **Two qualifying runways, both `béton bitumineux` / asphaltic concrete:** RW17/35 **2,200 ×45m** and RW11/29 **1,290 ×45m**. Additional RW17R/35L **200×20m unpaved** does *not* qualify. | RW17 and RW35 each **TORA/TODA/ASDA/LDA 2,200m**; RW11 and RW29 all **1,290m**. Published intersection takeoffs may use less; these do not reduce physical runway. | **`paved_runway_status='VERIFIED'`**. Civil IFR/VFR, TWR and airport operator SEARD. Extra-Schengen immigration **PPR 24h weekdays, PPR 48h weekends/public holidays**, only during permitted 07:00–19:00 hours. Individual passenger/charter/cargo airline rights **UNVERIFIED**. |
| **LFLY Lyon–Bron** | RW16/34 **1,820 ×45m `revêtue` / paved**, grooved 33m width. Imported source 1,820m ASP. October cycle original detailed SIA AD2.12 does **not** explicitly label the runway asphalt/concrete. | **RW16 TORA/TODA/ASDA 1,820m, LDA 1,520m**. **RW34 TORA/TODA 1,820m; ASDA 1,970m including 150m STOPWAY; LDA 1,520m**. The 1,970m ASDA is **not** physical runway length. | `paved_runway_status='UNVERIFIED'` at independent exact-asphalt/concrete gate; `civilian_access_status='VERIFIED_CIVIL_BUSINESS_AVIATION'`, operator Aéroports de Lyon, customs and terminal/AFIS operating restrictions. Aviation club historical technical article (1972) describes bituminous resurfacing of old full runway; such an aged source **does not certify current 2026 pavement material** and does not override the hold. |
| **LFBA Agen–La Garenne** | RW11/29 **2,165 ×30m `revêtue` / paved**. Source registry 2,165m ASP. SIA AD2.8 says **apron** `enrobé`, but apron asphalt must NOT be misrepresented as runway material. | **RW11 TORA/TODA/ASDA 2,075m, LDA 1,910m**; **RW29 TORA/TODA/ASDA 2,140m, LDA 1,740m**. End of nominal distances lies 90m and 25m inside physical runway ends. | `paved_runway_status='UNVERIFIED'` on current source explicit material. **Crucial AD2.20 aircraft-performance restriction:** ordinary runway use is limited to aircraft whose certified maximum-takeoff-weight, ISA sea-level, still-air, zero-slope required takeoff distance is **less than 1,200m**, with normal wingspan **<24m** (certain exceptions up to **27.10m** with gear width conditions). Operators outside these criteria require **airport operator technical dossier submitted at least three months before first operation**, and approval may be refused. This 1,200m **aircraft certification performance** restriction is not the 1,200m physical-runway collection threshold and does not make the 2,165m pavement physically shorter. The separate 2022/23 French Airport Union directory search index describes the material as `bitume`, but the **original PDF could not be directly fetched/authenticated** in this pass; treat as a source lead, not current AIP asphalt certification. |

### Original October 2026 aeronautical sources

- **LFOH:** https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-2.LFOH-fr-FR.html — AD2.2, AD2.3, AD2.12–13, AD2.20.
- **LFRD:** https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-2.LFRD-fr-FR.html — AD2.2, AD2.3, AD2.12–13.
- **LFLY:** https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-2.LFLY-fr-FR.html — AD2.2, AD2.3, AD2.12–13, contemporary short LDA and stopway.
- **LFBA:** https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-2.LFBA-fr-FR.html — AD2.12–13 and *critical* AD2.20. Distinguish specific operational-aircraft requirements from surface material.
- **Independent current Lyon-Bron airport operator (confirms 1,820m grooved runway and FBO):** https://businessaviation.lyonaeroports.com/fr/preparation-du-vol-lyn .
- **French Airport Union historical 2022–23 airport guide search-indexed LFBA material (`bitume`), PDF not accessible for original verification:** https://www.aeroport.fr/uploads/documents/guide-des-aeroports-francais-2022-2023.pdf?v12.2= .
- **Historical Lyon-Bron runway bituminous-pavement study (1972) is older physical provenance, not current material certification:** https://trid.trb.org/View/1081355 .

### Database audit and constraints

- **8** private evidence records **2217–2224**, two per airport for official physical AD2.12/13 and current operational restrictions; `audit_batch='FR_SPECIALIST_CIVIL_01_2026_10_27'`.
- **4** pre-existing access-review records updated with exact current source links, official review dates, civil usage and critical operating restrictions. **LFOH and LFRD promoted to independently physically `VERIFIED`; LFLY and LFBA remain `UNVERIFIED` specific asphalt/concrete material.**
- **4** review events **64–67**, recording each source and the distinction between physical-runway qualification and directional/aircraft-operating restrictions.
- All four retain `commercial_permission_status='UNVERIFIED'` and `game_admission_status='NOT_APPROVED'`, no approved owner, no new World 1 airport or prelaunch `airlinerra_game` catalog changes, original `airport_registry` values untouched. **No airline route should be made automatically bookable or simulated from these research flags.**
- The six Airlinerra eventual tiers remain **Local, Regional, Medium, Large, Major Hub, Mega Hub**, no categories inferred or assigned by runway length.

**Next research:** Continue reviewing French civil source-only holds where an original accessible DGAC AD2.12 expressly says *asphalt/béton bitumineux* or *béton*. Prioritize material verification that converts actual technical holds into specific decisions. Lyon-Bron and Agen may warrant airport-runway paving documents before exact-material promotions. **Do not confuse an airport with complete physical gate and an airport ready for unrestricted commercial gameplay.**

---

## France civilian-airport verification pass 02 — October 27, 2026

**Supabase research run:** `FR_SPECIALIST_CIVIL_02_2026_10_27`  
**Scope:** Five previously `UNVERIFIED` French outside-World-1 airports with plausible civil use, not an additional batch of new registry candidates. Official airport-operator and 2026 SIA original runway sources were checked. All five remain **game NOT_APPROVED** and commercial carrier-specific rights **UNVERIFIED**, even where physical runway suitability is now independently verified.

| Airport | Source-verified physical runway and its provenance | Technical result and operating qualifications |
|---|---|---|
| **LFMH Saint-Étienne–Bouthéon** | **2,300 ×45m RW17/35, `bitume` / asphalt**, airport manager's directly accessible current technical page. Imported 2,300m ASP matches. | **`paved_runway_status='VERIFIED'`**. Civil airport; operator publishes Mon–Fri 08:00–18:00, Sat 09:00–13:00, closed Sunday/holidays unless requested opening, passenger terminal and cargo facilities. Does not certify airline-specific permission, Oct 2026 directional TORA/LDA or out-of-hours access. |
| **LFRT Saint-Brieuc–Armor** | **2,200 ×45m RW06/24, `bitume` / asphalt**, directly accessible airport-operator technical page. Imported 2,200m ASP agrees. | **`VERIFIED`**. Civil IFR/night VFR and AFIS, handling, GPU, Jet A1, level-2/5 rescue by request. Operational support on request does not mean automatic scheduled traffic approval. |
| **LFOP Rouen–Vallée de Seine** | **1,700 ×45m RW04/22 `enrobé bitumineux` / asphalt**, **official French SIA October 1 2026 AD1.3**. Imported 1,699.9m ASP effectively agrees. The separate RW05/23 **900×80m grass** does not qualify. | **`VERIFIED`** current original regulator surface. Civil open to public air traffic, IFR/VFR; commercial permission and 2026 detailed declared distances unverified. |
| **LFLV Vichy–Charmeil** | 2026 official French AD1.3 RW01/19 **2,200×45m `revêtue` / paved**; airport municipality's **November 2018** page explicitly says **`macadam`**, not certified precise asphalt/concrete. Regional heritage history notes the original **1954 bituminous 1,600m runway extended by 600m in 1961**. | **Remain `UNVERIFIED` for present-day full-length explicit asphalt/concrete**, despite the old registry `ASP` and separate old asphalt construction history. Municipal page confirms civil **open to public air traffic**, but not an unrestricted modern airline service. |
| **LFJR Angers–Marcé** | **1,800×45m RW08/26 `revêtue`**, official SIA Oct 2026 AD1.3 and current Angers Loire EDEIS operator. Original registry 1,800.1m ASP. Neither accessible current source independently spells out runway material as asphalt or concrete. | **Remain `UNVERIFIED` exact material.** Important conflicting numbers across airport operator's own 2026-presented bilingual pages: **French RW26 TORA1,728 / TODA1,800 / ASDA1,800 / LDA1,650m**, while **English RW26 TORA1,728 / TODA1,800 / ASDA1,728 / LDA1,578m**. Do not accept either as authenticated October 2026 SIA AD2 until reconciled. Civil IFR/VFR business/general operations exist; airline permission remains unverified. |

### Direct sources / documentation uncertainty

- **LFMH airport operator, bitume and hours:** https://saint-etienne.aeroport.fr/info-pratiques/informations-techniques/
- **LFRT airport operator, bitume RW06/24:** https://www.st-brieuc.aeroport.fr/donnees-techniques/
- **LFOP SIA official AD1.3, 01 Oct 2026:** https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-1.3-fr-FR.html
- **LFLV municipality's 2018 macadam runway specification:** https://www.vichy-communaute.fr/aeroport/
- **LFLV regional historical bituminous original runway and 1961 extension, not current proof:** https://patrimoine.auvergnerhonealpes.fr/dossier/IA03000594
- **LFJR French operator original data:** https://angers.aeroport.fr/domaines-application/informations-tarifs-et-pilotes/
- **LFJR English operator inconsistent data:** https://angers.aeroport.fr/en/domaines-application/information-rates-and-pilots/
- **LFJR current SIA AD1.3 paved physical runway:** same 2026 DGAC AD1.3 URL as LFOP.

**Persistence:** **10** private `airport_evidence` rows IDs **2225–2234**, two per airport; **5** updates to existing `airport_access_reviews`, physical status **3 promoted VERIFIED / 2 retained UNVERIFIED**; **5** `airport_review_events` IDs **68–72**. Raw `airport_registry` runway values/surfaces and original identity keys untouched. `game_admission_status='NOT_APPROVED'` and `commercial_permission_status='UNVERIFIED'` all five. No final category, World 1 airport activation, 3,140-key private game catalog, or public launch changes.

**Next:** Prioritize other civilian source-only holds with original 2026 SIA `béton / béton bitumineux / enrobé bitumineux` or current first-party airport `bitume / concrete` runway evidence; avoid using apron or taxiway surface as proof for runway. Follow up Angers bilingual declared-distance inconsistency from original current SIA AD2 before applying aircraft performance logic. Six allowed eventual categories unchanged: Local, Regional, Medium, Large, Major Hub, Mega Hub.

---

## France civilian verification pass 03 — Quimper, Valence, Albert, Melun (27 October 2026)

**Research batch:** `FR_SPECIALIST_CIVIL_03_2026_10_27`; **airfield scope:** LFRQ, LFLU, LFAQ, LFPM. These are pre-existing, unapproved research-candidate airports outside World 1. The official French eAIP edition effective **1–28 October 2026** was used, paired with airport/operator first-party publications; LFPM AD2 subsection itself is dated **6 August 2026** and included in that October publication. **No live NOTAM check or commercial operator authorization was completed.**

| ICAO and airport | Independent runway evidence | Independent pavement gate | Civil-operational issue |
|---|---|---|---|
| **LFRQ Quimper–Cornouaille / Pluguffan** | Original registry **2,150.1m ASP**. French **SIA Oct 2026 AD1.3** RW09/27 **2,150 ×45m `asphalte`**, explicitly qualifying asphalt. Civil, IFR/VFR, open to public air traffic. | **VERIFIED** | A **14 Sept 2026 French government decree** allows a **temporary prohibited airspace ZIT PLUGUFFAN** on specified dates through 28 October 2026 **only when activated by NOTAM** with 48h notice. It has an exception for qualifying IFR arrivals/departures at Quimper and does **not** mean the airport is closed. An active NOTAM was **not independently checked** on October 27; no automatic airline route clearance. |
| **LFLU Valence–Chabeuil** | Original registry **2,100.1m ASP**; DGAC/SIA Oct2026 AD1.3 RW01/19 **2,100 ×45m paved**. **Airport operator original technical page expressly gives `bitume` (asphalt)** for the **2,100 ×45m** runway. Civil/military mixed airport, IFR/night VFR, open to public air traffic. Additional strips **1,190m and 400m are unpaved**, so they do not qualify. | **VERIFIED** by directly operated airfield specific bitume source | Official operator has current 2026 tariff reference, but this is **not** the DGAC detailed AD2 by-direction 2026 TORA/LDA. Commercial flight/handling, hours, aircraft acceptance and NOTAMs still need independent review. |
| **LFAQ Albert–Bray / Amiens Henry Potez** | Original registry **2,200m ASP**; **DGAC/SIA Oct2026 AD1.3 RW08/26 2,200 ×45m `revêtue` / paved**. Operator and Albert municipality corroborate 2,200 ×45m and the **1,000 ×80m grass secondary**. Operator advertises cargo/Airbus Beluga support, ILS CAT I, AFIS, ground services; municipality states aerodrome is open to public air traffic. **Neither SIA AD1.3 nor obtained operator pages specify asphalt/concrete for the main runway.** | **UNVERIFIED** independently exact surface; original OurAirports ASP candidate `RUNWAY_QUALIFIED` retained, not rejected. | Active civil/cargo support **does not** prove current runway material or unrestricted commercial carrier rights. Current original eAIP LF**AQ** detailed AD2 was not accessible in this source retrieval. |
| **LFPM Melun–Villaroche** | Original registry **1,975.1m ASP**. **DGAC/SIA October-cycle detailed AD2.12** confirms two paved runways: RW10/28 **1,972 ×45m**, RW01/19 **1,300 ×30m**; **3.1m difference** from original imported main length. **AD2.13 main RW10 TORA/TODA/ASDA/LDA=1,972m; RW28 TORA1,972, TODA2,650, ASDA1,972, LDA1,890.** The **678m extra TODA is clearway**, *not* physical asphalt/concrete pavement. Detailed AD2.8 calls **apron/taxiways asphalt/concrete**, but that is **not runway material evidence**. Both actual runways only `revêtue`/paved in AD2.12. | **UNVERIFIED** exact runway asphalt or concrete; preserved provisional original source ASP. | Civil IFR/VFR; ATS weekdays 08:00–16:00 UTC, out-of-hours AFIS requires **PPR 48h**; handling mandatory for **non-based aircraft MTOW above 3 tonnes**, normal RFFS level 2 with ATS and 1 outside, possible level 5 on PPR 48h. No blanket airline authorization. |

### Primary official references

- **France DGAC SIA official AD1.3, Oct 1 2026**, LFAQ paved 2,200m, LFRQ *asphalte* 2,150m, LFLU paved 2,100m, LFPM paved 1,972m: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-1.3-fr-FR.html
- **LFRQ temporary-airspace conditional restriction**, French government order 14 September 2026, IFR airport exemption and NOTAM activation: https://www.legifrance.gouv.fr/jorf/article_jo/JORFARTI000054850535
- **Valence–Chabeuil operator explicitly `bitume` 2,100×45m**: https://www.valenceaeroport.fr/fr/donnees-techniques-et-aeronautiques/
- **Albert/Amiens airport operator 2,200×45m runway and services**: https://aeroportamienspotez.fr/infrastructures-et-caracteristiques/
- **Municipality confirms LFAQ airport public access and cargo functions**: https://www.ville-albert.fr/aeroport/
- **Melun original detailed DGAC/SIA AD2**, page dated 6 Aug 2026 in October 2026 cycle: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-2.LFPM-fr-FR.html

**Source limitation:** The original October DGAC detailed LF**AQ**, LF**RQ**, LF**LU** AD2 HTML endpoints did not resolve through the research reader in this run; the official nationwide AD1.3 was indexed and source values were corroborated where required. Therefore no current LF**AQ**/LF**RQ**/LF**LU** AD2 directional flight distances were invented. This report never turns historic registry/source-only `ASP` or an AD2 **apron** surface into proof of a **runway** surface.

### Supabase and gameplay record

- **8** `airlinerra.airport_evidence` entries **2235–2242**, two per airport, batch marker `FR_SPECIALIST_CIVIL_03_2026_10_27`.
- **4** existing `airlinerra.airport_access_reviews` updated: LFRQ and LFLU exact 1,200m asphalt/concrete technical gate now **VERIFIED**; LFAQ and LFPM **UNVERIFIED** with precise source-access/material holds; civil/open-to-CAP separately recorded.
- **4** `airport_review_events` audit IDs **73–76**, preserving the evidence versus admission distinction.
- **Zero** gameplay admissions, no source-register mutation, no new six-level classification, no `airport_world_activation` or `airlinerra_game.approved_game_airports` mutations. All four `game_admission_status='NOT_APPROVED'`, `commercial_permission_status='UNVERIFIED'`.
- The **six** and only six game categories remain **Local, Regional, Medium, Large, Major Hub, Mega Hub**.

**Next priority:** continue civil runway material checks with accessible DGAC AD2 or original airport operator declarations, not repeated military-only investigations. For LFAQ and LFPM, demand runway-specific material, not generic `revêtue` or apron material; for LFPM, preserve the 1,890m RW28 LDA and separate 678m clearway in eventual aircraft scheduling.

---

## France civilian verification pass 04 — Merville, Lannion, Niort, Le Touquet, Saint-Yan (27 October 2026)

**Run:** `FR_SPECIALIST_CIVIL_04_2026_10_27`. These five airports were already in the French **105 airports outside World 1** with provisional OurAirports source-runway qualification, but each had an `airport_access_reviews.paved_runway_status='UNVERIFIED'` before this run. Sources distinguish **official effective October 1, 2026 DGAC SIA AD1.3 (through October 28)**, official May 14, 2026 detailed AD2 for Lannion, and first-party airport operators. We never overwrite original source length/surface. **Commercial airline permission and gameplay admission remain separate gates**.

| ICAO / airport | Imported source runway | Official/airport operator result | Independent pavement/operational outcome |
|---|---|---|---|
| **LFQT Merville–Calonne/Lestrem** | **1840.1m ASP** | Airport's own technical page explicitly says `une piste en enrobé de 1840 m` — **1,840m asphalt/bituminous**. Official SIA Oct 2026 AD1.3 **RW04/22 1,840 × 30m paved**. Secondary RW04R/22L **1,000 ×80m grass** is not qualifying. | **`paved_runway_status='VERIFIED'`**. Civil airport open to public air traffic, operator confirms ILS CAT I, up to ATR72-type operations and tower/lighting; carrier-specific authorizations unverified. `NOT_APPROVED` game admission. |
| **LFRO Lannion–Côte de Granit Rose** | **1699.9m ASP** | **Official original French SIA May 14 2026 AD2.12 RW11/29 1,602 ×45m `revêtue`**, corroborated by the airport's **currently updated October 2026** original page. **Difference −97.9m** versus import. Operator lists **RW11 LDA 1,376m and RW29 LDA 1,463m**; both landing distances are smaller than physical runway. | Exact material in obtainable authority/airport sources only `revêtue` (paved), not certified asphalt/concrete. **`UNVERIFIED`**, source discrepancy retained, civil open to public, IFR and night, commercial service-hour extension requires **PPR72h**, RFFS5 PPR72h. **Do not schedule against imported 1700m**. |
| **LFBN Niort–Marais Poitevin** | **1759.9m ASP** | **Oct 2026 French SIA AD1.3** and municipal airport operator agree on **RW07/25 1,783 ×30m `revêtue`**, **+23.1m** versus import. Other unpaved RW07L/25R ~682m, ULM ~400m not eligible. Municipal city describes regional transport and aircraft facilities, not specific main runway composition. | Specific asphalt/concrete present-day runway composition **`UNVERIFIED`**. Civil airport open to public, H24 fuel and published operating assistance; airline-specific rights unverified. |
| **LFAT Le Touquet–Elizabeth II** | **1850.1m ASP** | **Oct2026 SIA AD1.3 RW13/31 1,850 ×40m `revêtue`**. Airport's current page says **`Tarmac`** (a general label rather than a source-certified exact material specification); also publishes 2026 tariffs, civil public/international air traffic, IFR/ILS Cat I. | Retain stricter independent **`UNVERIFIED`** asphalt/concrete subtype. **Historical February 20, 2025 official SIA AD2** gives RW13 TORA 1700, TODA1760, ASDA1700, LDA1700 and RW31 TORA/TODA/ASDA1850, LDA1700, but these are **2025 dated** and **NOT automatically current October 2026 declared distances**. Commercial flight RFFS4/5 can require PPR24h. |
| **LFLN Saint-Yan** | **2030m CON** | **Oct2026 SIA AD1.3** main **RW15L/33R 2,034 ×45m `revêtue`** (**+4m** vs import); second paved RW15R/33L **1,200 ×30m**; third grass RW15/33 **720 ×70m** not qualifying. 2022–23 French Airports Union guide also says only `revêtue` for both paved runways. | Retain independent full asphalt/concrete exact-material **`UNVERIFIED`** despite historical registry CON. Civil airport open to public, IFR/VFR and flight training, but no commercial-player route authorization. Avoid relying on virtual ATC/simulation websites for concrete/asphalt verification. |

### Sources and evidence limitations

1. **Merville–Lestrem airport operator, primary direct runway-asphalt verification:** https://www.aeroport-mervillelestrem.fr/aeroport/ .
2. **Lannion airport operator, 1602m runway, directional LDA and October 2026 price update:** https://www.lannion.aeroport.fr/ .
3. **Lannion older but original May 14 2026 SIA detailed AD2** confirms 1602 ×45m paved (not explicit subtype): https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_14_MAY_2026/FRANCE/AIRAC-2026-05-14/pdf/FR-AD-2.LFRO-fr-FR.pdf . This original PDF was surfaced via search extract, **not directly screenshot inspected**; live October SIA detailed AD2 not independently checked. The airport operator current original site is decisive for current runway length/LDAs.
4. **French SIA official eAIP Oct 1 2026 AD1.3**, LFQT/LFBN/LFAT/LFLN current runway length/designators and paved attributes: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_01_OCT_2026/FRANCE/AIRAC-2026-10-01/html/eAIP/FR-AD-1.3-fr-FR.html .
5. **Niort municipality first party runway** 1783 ×30m and public operations: https://cdn.vivre-a-niort.com/services-publics/les-equipements/aerodrome/index.html .
6. **Le Touquet operator**, tarmac, 1850 ×40m and RFF commercial hours/PPR: https://www.aeroport-letouquet.com/informations-et-services/ .
7. **Le Touquet official older 2025 detailed AD2**, archival runway-direction declaration only: https://www.sia.aviation-civile.gouv.fr/media/dvd/eAIP_15_MAY_2025/FRANCE/AIRAC-2025-05-15/html/eAIP/FR-AD-2.LFAT-fr-FR.html .
8. **French Airports Union historical 2022–23 directory Saint-Yan** lists 2034 ×45m paved + 1200 ×30m paved, **not explicit concrete**: https://www.aeroport.fr/uploads/documents/guide-des-aeroports-francais-2022-2023.pdf?v12.2= .

**Database audit:** **10** `airport_evidence` entries **2243–2252**, **5** previously existing `airport_access_reviews` updated (**LFQT promoted VERIFIED; LFRO/LFBN/LFAT/LFLN remain UNVERIFIED with current civil-access and physical-length evidence**), **5** `airport_review_events` IDs **77–81**. Marker `FR_SPECIALIST_CIVIL_04_2026_10_27`. Raw source keys/lengths/materials preserved. Every airport still `game_admission_status='NOT_APPROVED'` and `commercial_permission_status='UNVERIFIED'`. No new World 1 game catalog airport, no prelaunch release, no four-level or arbitrary final classification. Six categories remain **Local, Regional, Medium, Large, Major Hub, Mega Hub**.

**Follow-up:** Seek runway-specific asphalt/concrete source for LFRO/LFBN/LFAT/LFLN and resolve 97.9m Lannion and 23.1m Niort imported length errors in a separately versioned runway correction workflow before those raw figures are used for aircraft performance. Review additional French civil source-only holds rather than unqualified military activation.
