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
