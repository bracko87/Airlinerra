# Airlinerra — German Expansion Runway Review, Batch 03

**26 October 2026 | Central Supabase `hwllkabgzaynalahvkpz`, schema `airlinerra` | GitHub `main`**

## Verified result

**Eight new German expansion airports reviewed** from the 3,906-airport expansion cohort. The founding **3,140 active World 1 airport records and registration selection options are untouched.** This review introduces no airport game activations or airline commercial rights.

| Outcome | Airports |
| --- | ---: |
| Current operator evidence supports a paved runway ≥1,200m; research advanced | **6** |
| Disputed airport-source pavement classification; generic evidence hold retained | **1 — EDLD** |
| Current airport-operator runway below 1,200m despite >1,200m stored registry; new technical hold | **1 — EDMB** |
| Total newly reviewed | **8** |
| Expansion generic independent source queue after batch | **1,808** (was 1,815) |
| Germany's generic independent source queue | **25** (was 32) |
| Founding World 1 airports active and present in registration picker | **3,140** |
| New expansion airports activated | **0** |

## Individual reviews

| ICAO | Airfield | Paved runway evidence (metres) | Research disposition |
| --- | --- | --- | --- |
| **EDGS** | Siegerland | Operator identifies asphalt **13/31, 1,620m**, PCN53. Secondary technical guide gives **30m** width. | **Advanced**. [Operator pilots page](https://www.siegerland-airport.de/fuer-piloten/infos-fuer-piloten/) confirms runway and Oct 2026 opening-hours revision. Night/IFR, scheduled closure dates and rescue service need date and aircraft verification. Current published LDA unavailable in this source. |
| **EDHK** | Kiel-Holtenau | [Operator's 2025 airport brochure](https://www.airport-kiel.de/files/Airport/Downloads/Airport%20Kiel%20-%20web%20DE%202025.pdf) identifies asphalt **08/26, 1,320 × 30m**. The registry/older directories show only **1,260m**. | **Advanced** on first-party *published runway evidence*, **not on final declared landing distance**. The PDF source was indexed as an operator publication, but remote screenshot fetch failed; effective AIP and **60m length difference** remain follow-up. |
| **EDLD** | Dinslaken/Schwarze Heide | [Airport operator's history page](https://schwarze-heide.com/edld/neuigkeiten/) confirms the extension to **1,500m**; [on-site flight school](https://jp-flugschule.de/standorte/) and [independent directory](https://dulv.de/fmwebphp/Flugplatz/details.php?id=764) give **08/26, 1,500 × 30m asphalt** while legacy registry calls the surface *concrete*. | **Hold unchanged.** Pavement-type conflict requires current operator/AIP specification. [Operator approach instruction](https://schwarze-heide.com/fuer-piloten/pilot-informationen/) says a **400m shifted touchdown point for aircraft below 2 tonnes** on RW26, which must not be treated as a published LDA. |
| **EDLE** | Essen/Mülheim | [Current operator airport information](https://www.flughafen-essen-muelheim.de/piloten/allgemein): asphalt **06/24, 1,553 × 45m**, RW06 **LDA 1,553m / TORA 1,200m**, RW24 **LDA 1,200m / TORA 1,553m**. Older secondary guides use 07/25: use effective AIP at operation date. | **Advanced** for physical runway evidence, with explicit **jet-powered-aircraft ban except ambulance flights**. [2026 airport use regulation](https://www.flughafen-essen-muelheim.de/assets/media/flugplatzbenutzungsordnung-stand-01.01.26.pdf) defines further limits. Physical qualification **does not** permit a generic jet airline. |
| **EDLI** | Bielefeld | [Official airport operator](https://flugplatz-bielefeld.de/flugplatzdaten/) reports asphalt **11/29, 1,256 × 20m**. | **Advanced**. Narrow 20m width and only 56m above gross-length minimum; operator allows aircraft up to 3t normally, 5.7t PPR. Directional usable LDA unverified. |
| **EDLS** | Stadtlohn-Vreden | [Current operator pilot data](https://www.flugplatz-stadtlohn.de/index.php?L=1&id=79): asphalt **11/29, 1,240 × 30m**. **RW11 LDA 1,200m and TORA 1,240m; RW29 LDA 1,240m and TORA 1,200m**. | **Advanced**. RW11 passes landing minimum **exactly**; any aircraft-specific required margins remain unverified. >5.7t aircraft require PPR; hours end at sunset or 21:00 local. |
| **EDMA** | Augsburg | [Operator technical data](https://www.augsburg-airport.de/flughafen/flughafendaten/): asphalt **07/25, 1,594m**; [older German AIP](https://www.euroga.org/system/1/user_files/files/000/042/014/42014/802240a5f/original/ED_AD_2_EDMA_en_2019-07-18.pdf) records **30m width**. RW07 published **LDA 1,355m**, RW25 **LDA 1,331m**; **TORA 1,406m each direction**. | **Advanced**. Operator's TODA and optional extra takeoff pavement are *not* landing distances. 2019 width reference requires fresh official AIP comparison. |
| **EDMB** | Biberach an der Riß | [Current airport operator's approach page](https://www.edmb.de/fur-piloten/an-abflug/) states runway **04/22, 980 × 23m asphalt**; RW04 landing **780m**, RW22 landing **980m**. Historic research registry says **1,314.9m** qualifying runway. | **Separate technical discrepancy hold.** Current official operator evidence **fails** minimum gross length and landing distances. Preserve source conflict; seek current effective German AIP or proof of another qualifying paved runway before any final reject/approval decision. |

## Data integrity and the Biberach finding

**EDMB** is not a simple "verification pending" row: the live operator data contradicts the older research qualification. We recorded it separately in a new private, RLS-enabled table `airlinerra.airport_expansion_runway_technical_exceptions`. It enforces a documented **sub-1,200m** source length and a distinct originally recorded **≥1,200m** length. The source observation is **980m**, old registry **1,314.9m**, a **334.9m difference**. Its central status is now `HOLD_OPERATOR_RUNWAY_BELOW_1200M_REGISTRY_CONFLICT`. **We did not overwrite the source master or permanently reject EDMB without adjudicating the discrepancy.**

Seven others are stored in the pre-existing private `airport_expansion_independent_paved_runway_reviews` table. **Six** advanced to `INDEPENDENT_OPERATOR_PAVED_RUNWAY_VERIFIED_SIMULATION_RELEASE_PENDING`; EDLD remains `HOLD_INDEPENDENT_VERIFICATION`. All research game admissions remain `NOT_APPROVED` and no expansion airport world activation was inserted.

The main source records preserve direction-specific landing distance where an operator publishes it, rather than equating runway gross length to legal LDA. Differing operator data and older registry entries (Kiel and EDLD) are explicitly retained as discrepancy notes.

## Security and reproducibility

- [Source records for seven paved-runway reviews, Biberach 980m exception schema/record and guarded status updates](./sql/AIRLINERRA_EXPANSION_DE_INDEPENDENT_RUNWAY_BATCH_03_2026-10-26.sql)
- [Acceptance and World 1 protection test](./sql/AIRLINERRA_EXPANSION_DE_INDEPENDENT_RUNWAY_BATCH_03_TESTS_2026-10-26.sql)

The live Supabase acceptance test returned **PASS** on October 26, 2026, verifying **7** paved source records, **1** short-runway exception, **6** advanced research statuses, EDLD retained as held, EDMB explicitly held and **3,140** unmodified active World 1 airports. Both private research tables have RLS enabled and no anonymous/authenticated SELECT permissions.

## Next

Continue verifying the **25 remaining German generic independent-source holds**, plus separately adjudicate the specifically held source-conflict cases: EDAK, EDBN, EDCP, EDFE, EDLD and the new EDMB runway-length issue. This batch did not add any airport to a game world. The game retains exactly six eventual size categories: Local, Regional, Medium, Large, Major Hub and Mega Hub.

**Batch 03: eight reviewed, six advanced, two held for different reasons, no activation.**
