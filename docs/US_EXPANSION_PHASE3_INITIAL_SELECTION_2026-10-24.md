# Airlinerra — U.S. Expansion, Phase 3: Initial Airport Selection (2026-10-24)

**EXECUTED AND VERIFIED IN SUPABASE.** All **1,929** reviewed expansion airports have an independently stored, rule-based *selection-screen* outcome in `airlinerra.airport_expansion_selection_phase3`. This is a **preliminary game expansion shortlist**, not a final eligibility sign-off and not activation of any airport.

## Phase 3 first-pass selection results

| Outcome | Airports | Decision |
|---|---:|---|
| **`PRELIMINARY_SHORTLIST`** | **1,013** | Passes current nominal public/open, >=1,200m paved runway and fair-or-better reported condition screens; airline/operator verification is still outstanding, but an existing scheduled airline is **not required** to create airline routes in this game |
| `OPERATIONAL_CONSTRAINT_HOLD` | 833 | Material operating limits, pavement conditions, airport ownership, restrictions/NOTAMs or airframe compatibility require case-specific validation |
| `IDENTITY_HOLD` | 74 | Historical/current airport codes, names, state, coordinates or source associations need correction |
| `PROVISIONAL_EXCLUSION_REVIEW` | 8 | Strong possible runway eligibility failure or current closure; independently validate before rejection, especially where temporary NOTAM may expire |
| `RUNWAY_CONDITION_OR_DATA_HOLD` | 1 | AST Astoria, Oregon runway-condition field is unknown; physically long enough but pavement condition needs independent verification |
| **TOTAL** | **1,929** | **100% have a saved initial selection disposition** |
| **Final approved for gameplay** | **0** | No admission or activation was authorized by this screening |

**1,013 shortlisted + 916 held = 1,929 total.** There are no definitive rejections from this first automated decision pass, because the source notes identify conditional/temporary restrictions and require owner/FAA verification. An initial shortlist position **is not a finding of legally authorized airline operations, reliable 2026 runway LDA, all-weather access, capacity or approval for gameplay**.

## Rule used — version `PHASE3_INITIAL_SCREEN_2026_10_24_V1`

A `PRELIMINARY_SHORTLIST` decision requires **all**:

1. Prior Phase 2 status is `EVIDENCE_GAP_HOLD`, rather than unresolved runway constraints or identity; lack of an *existing* charter/scheduled/cargo carrier is **not itself a game exclusion**.
2. Current FAA dataset reports **open (`O`)** and **public use (`PU`)**, with an exact FAA identifier/location match.
3. Recorded paved runway length **at least 1,200 metres** and surface code `ASPH`, `CONC` or `ASPH-CONC`.
4. Runway-condition record **`FAIR`, `GOOD` or `EXCELLENT`**.
5. Remain unapproved in gameplay database; **no automatic category assignment**.

The other selection statuses are assigned from distinct previously audited Phase 2 operational, identity and provisional screen conditions, with a special data hold for absent pavement-condition evidence. The **1,929 source runway records all have nominal >=1,200m paved runway entries**, but this is not proof each has >=1,200m *usable declared landing distance*, adequate airplane load, open primary runway or legal commercial permission. Every saved selection row includes Phase 2 finding/follow-up, original source URL/reference date and a strict `NOT_APPROVED` guard.

## Verifications passed

| Selection and game integrity check | Result |
|---|---:|
| Phase 3 records / unique immutable keys | **1,929 / 1,929** |
| Phase 3 missing required decision/source fields | **0** |
| Invalid physical/runway-condition entry among 1,013 shortlist rows | **0** |
| FAA non-open or non-public status among recorded candidates | **0** |
| FAA identifier/location mismatches in the 2026 candidate screening column | **0** |
| Candidate key overlap with original 3,140 roster | **0** |
| Original playable roster | **3,140 unchanged** |
| Expansion gameplay approvals | **0** |
| Airport world activations / category approvals | **0 / 0** |

The new selection table is in the `airlinerra` schema, with **row-level security enabled** and public/anon/authenticated table access explicitly revoked. Its independent `final_game_approval_status` field is database-checked to remain `NOT_APPROVED`. Existing `airport_commercial_verification.game_admission_status`, `airport_access_reviews`, `airport_world_activation`, `airport_game_profiles` and original cohorts were **not modified** by the Stage 3 screening.

## Nine first-priority runway/eligibility data review cases

Eight airports have a preliminary exclusion flag; the ninth (AST) is missing runway-condition data. These are **NOT definitive permanent closures or irreversible rejections**.

| FAA | State | Immutable airport key | Nominal paved length | Recorded condition | Existing issue | Next verification |
|---|---|---|---|---|---|---|
| 14G | OH | `OURAIRPORTS:18419` | 1261.0 m | POOR | USABLE_RUNWAY_BELOW_1200M | Confirm airport-operator declared usable runway distances and repair/extension before reconsidering the minimum paved-runway gate. |
| 53A | GA | `OURAIRPORTS:18876` | 1524.9 m | GOOD | CURRENT_RUNWAY_CLOSURE_TO_NOV15 | Recheck FAA NOTAM expiry Nov15 and available runway/apron, 780ft displaced RW18 threshold and usable LDA, then rescreen before any game activation. |
| L66 | LA | `OURAIRPORTS:20305` | 1371.3 m | FAILED | SHORTENED_RUNWAY_BELOW_1200M | Obtain official usable runway measurements and closure/reopening evidence; 1,200m minimum currently not met on the recorded paved runway. |
| N59 | NV | `OURAIRPORTS:20615` | 1463.0 m | FAILED | PAVED_RUNWAY_CLOSED | Exclude from new game runway candidates until official reopening and acceptable paved operational runway are independently documented. |
| O61 | CA | `OURAIRPORTS:20700` | 1234.7 m | FAIR | USABLE_LANDING_DISTANCE_BELOW_1200M | Provisionally fail **usable-landing-distance** screen only; confirm official published declared landing distances and whether Airlinerra's 1200m ru... |
| PVJ | OK | `OURAIRPORTS:20889` | 1524.3 m | GOOD | AIRPORT_PUBLISHED_INDEFINITE_RUNWAY_RECONSTRUCTION_CLOSURE | Obtain currently effective FAA NOTAM and owner written runway-reopening confirmation before rescreening or any gameplay activation. |
| SRC | AR | `OURAIRPORTS:21107` | 1831.2 m | FAIR | RUNWAY_CLOSED_OCT5_TO_OCT31 | Verify reopening and updated FAA NOTAM after October 31, then recheck aviation fuel and commercial access. |
| U14 | UT | `OURAIRPORTS:21256` | 1920.2 m | FAIR | BATCH09_U14 | Verify current airport manager/FAA NOTAM, runway-specific usable length and loading, aircraft compatibility, and charter or cargo permission; resol... |
| AST | OR | `OURAIRPORTS:19314` | 1766.0 m | UNKNOWN | PAVEMENT_CONDITION_UNREPORTED | Astoria source runway condition not reported in screen; explicitly request current runway condition, Coast Guard coexistence and certified commerci... |

This queue includes **53A**, **SRC**, and **U14** with date-specific closures/temporary changes that must be rechecked as NOTAMs expire. Do not treat temporary restrictions as permanent rejection. **N59** and **L66** require authoritative reopening/usable pavement proof. **AST** should not be excluded just because one condition field was missing.

## Full 74-airport identity reconciliation queue

These 74 candidate keys remain on hold even though their initial FAA status-matching field returned a match. Source alias history, recorded state/location or first-pass note can still be contradictory; a coarse identifier match **does not negate the specific researched discrepancy**.

| FAA | State | Immutable airport key | Identity/source issue |
|---|---|---|---|
| 71J | AL | `OURAIRPORTS:19024` | REGISTRY_GPS_K71U_VS_FAA_71J |
| A08 | AL | `OURAIRPORTS:19213` | ERRONEOUS_FIRST_PASS_AIRPORT_DESCRIPTION |
| BFZ | AL | `OURAIRPORTS:19114` | FORMER_8A0_CURRENT_BFZ |
| CQF | AL | `OURAIRPORTS:18845` | LEGACY_K4R4_TO_KCQF |
| HDL | AL | `OURAIRPORTS:18369` | FORMER_0J6_NOW_HDL |
| ADF | AR | `OURAIRPORTS:20461` | FORMER_M89_CURRENT_ADF |
| JTC | AZ | `OURAIRPORTS:19608` | FORMER_KD68_TO_KJTC |
| CFO | CO | `OURAIRPORTS:19903` | LEGACY_FTG_VS_CFO_AIRPORT_CODE |
| CO4 | CO | `OURAIRPORTS:19222` | LEGACY_SOURCE_IDENT |
| FLY | CO | `OURAIRPORTS:18306` | FAA_CODE_TRANSITION |
| RCV | CO | `OURAIRPORTS:19147` | FORMER_8V1_CURRENT_RCV |
| RYA | CO | `OURAIRPORTS:18629` | FORMER_2V5_CURRENT_RYA |
| HEF | DC | `OURAIRPORTS:20041` | WRONG_FAA_STATE_DC_VS_VA |
| BCR | FL | `OURAIRPORTS:18477` | FORMER_1J0_CURRENT_BCR |
| FHB | FL | `OURAIRPORTS:18881` | FORMER_55J_CURRENT_FHB |
| FIN | FL | `OURAIRPORTS:21400` | LEGACY_KXFL_VS_CURRENT_KFIN |
| FPY | FL | `OURAIRPORTS:18757` | K40J_LEGACY_SOURCE_IDENT |
| CNI | GA | `OURAIRPORTS:18786` | FORMER_47A_CURRENT_CNI |
| CPP | GA | `OURAIRPORTS:18709` | FORMER_3J7_CURRENT_CPP |
| CVC | GA | `OURAIRPORTS:19175` | FORMER_9A1_CURRENT_CVC |
| EBA | GA | `OURAIRPORTS:18556` | FORMER_27A_CURRENT_EBA |
| HMP | GA | `OURAIRPORTS:18805` | FORMER_4A7_CURRENT_HMP |
| JCA | GA | `OURAIRPORTS:18439` | FORMER_19A_NOW_JCA |
| MAN | ID | `OURAIRPORTS:21014` | OLD_S67_NOW_MAN_CHARTERS_CONFIRMED_ADVERTISED |
| GPC | IN | `OURAIRPORTS:18823` | FORMER_4I7_CURRENT_GPC |
| I20 | IN | `OURAIRPORTS:20770` | LEGACY_2IG4_VS_I20 |
| JHN | KS | `OURAIRPORTS:18597` | FORMER_2K3_CURRENT_JHN |
| BYL | KY | `OURAIRPORTS:21353` | REGISTRY_W38_TO_CURRENT_KBYL_UNPROVEN_LINEAGE |
| GDA | KY | `OURAIRPORTS:18916` | FORMER_5M9_CURRENT_GDA |
| JQD | KY | `OURAIRPORTS:19062` | LEGACY_K7K4_VS_CURRENT_KJQD |
| RGA | KY | `OURAIRPORTS:20129` | RICHMOND_OLD_KI39_VS_KRGA |
| SJS | KY | `OURAIRPORTS:20244` | LEGACY_K22_NOW_SJS |
| SYM | KY | `OURAIRPORTS:45427` | HISTORICAL_M97_TO_SYM_UNCONFIRMED |
| APS | LA | `OURAIRPORTS:18483` | FORMER_1L0_CURRENT_APS |
| IYA | LA | `OURAIRPORTS:18387` | LEGACY_0R3_NOW_IYA |
| MNE | LA | `OURAIRPORTS:19805` | LEGACY_F24_TO_MNE |
| REG | LA | `OURAIRPORTS:20297` | LEGACY_L38_TO_REG |
| CBE | MD | `OURAIRPORTS:19462` | FAA_MD_ADMIN_STATE_VS_PHYSICAL_WV |
| 22T | MI | `OURAIRPORTS:10193` | HISTORIC_FAA_IDENT |
| RGK | MN | `OURAIRPORTS:20926` | WISCONSIN_PHYSICAL_MN_ADMIN_CITY |
| FYG | MO | `OURAIRPORTS:20541` | FORMER_MO6_CURRENT_FYG |
| HFJ | MO | `OURAIRPORTS:20444` | SOURCE_NOTE_BELONGS_TO_NEOSHO |
| OZS | MO | `OURAIRPORTS:20007` | LEGACY_H21_TO_OZS |
| PCD | MO | `OURAIRPORTS:20236` | LEGACY_K02_TO_PCD |
| JVW | MS | `OURAIRPORTS:20412` | FORMER_M16_NOW_JVW |
| RVF | MT | `OURAIRPORTS:19076` | FORMER_7S1_CURRENT_RVF |
| SCR | NC | `OURAIRPORTS:18938` | FORMER_5W8_CURRENT_SCR |
| BAC | ND | `OURAIRPORTS:18981` | LEGACY_6D8_CURRENT_BAC_REGISTRY |
| BRG | NM | `OURAIRPORTS:19709` | LEGACY_KE80_TO_KBRG |
| DNA | NM | `OURAIRPORTS:18929` | LEGACY_K5T6_TO_KDNA |
| SXU | NM | `OURAIRPORTS:20135` | FORMER_I58_NOW_SXU |
| N58 | NV | `OURAIRPORTS:20614` | RENAMED_FIELD_POOR_PAVEMENT |
| RTS | NV | `OURAIRPORTS:18853` | LEGACY_K4SD_TO_KRTS |
| TMT | NV | `OURAIRPORTS:19204` | FORMER_9U3_CURRENT_TMT |
| HTF | NY | `OURAIRPORTS:18819` | FORMER_4G6_CURRENT_HTF |
| IUA | NY | `OURAIRPORTS:19598` | FORMER_D38_NOW_KIUA |
| JPX | NY | `OURAIRPORTS:20093` | HISTORIC_KHTO_TO_KJPX_MAY2022_AND_NOISE |
| FZI | OH | `OURAIRPORTS:19918` | REGISTRY_CURRENT_AIRPORT_NAME_ALIAS |
| GDK | OH | `OURAIRPORTS:20124` | FORMER_I19_NOW_GDK |
| JRO | OH | `OURAIRPORTS:20131` | FORMER_I43_TO_JRO_RW01_DISPLACED |
| SCA | OH | `OURAIRPORTS:20120` | SIDNEY_FORMER_KI12_VS_KSCA |
| 1PP | OK | `OURAIRPORTS:20675` | RENAMED_FAA_CODE_TRIBAL_PAVEMENT |
| GZL | OK | `OURAIRPORTS:19834` | LEGACY_F84_VS_CURRENT_GZL |
| H04 | OK | `OURAIRPORTS:20003` | AIRPORT_IDENTITY_VINITA_NOT_WEATHERFORD_OJA |
| RCE | OK | `OURAIRPORTS:19807` | LEGACY_F29_TO_RCE |
| JSY | OR | `OURAIRPORTS:18851` | FORMER_4S3_CURRENT_JSY |
| XNX | TN | `OURAIRPORTS:20427` | FORMER_M33_NOW_XNX_WITH_PART139_DISTINCTION |
| 2E5 | TX | `OURAIRPORTS:18576` | FAA_GPS_CODE_IDENTITY_MISMATCH |
| LUV | TX | `OURAIRPORTS:18581` | FORMER_2F5_CURRENT_LUV |
| TXW | TX | `OURAIRPORTS:21161` | LEGACY_T65_TO_TXW_AND_CARGO_MRO_DISTINCTION |
| SVR | UT | `OURAIRPORTS:21261` | OFFICIAL_U42_TO_SVR_2025_CHARTER_POSITIVE |
| W11 | WI | `OURAIRPORTS:9987` | FORMER_31WI_NEW_W11 |
| DUB | WY | `OURAIRPORTS:21257` | HISTORIC_KU25_TO_KDUB |
| DWX | WY | `OURAIRPORTS:19205` | LEGACY_K9U4_TO_KDWX |

## Next verified actions

**Priority A — Resolve 74 identity cases and 9 pavement/exclusion exceptions.** Use authoritative current airport ownership/FAA evidence and preserved original identifiers; never create a second game airport for the same physical field. Recheck temporary closures against current FAA notices before ruling out the airport.

**Priority B — Evaluate 833 operational constraints.** Prioritize actual qualifying paved runway usable landing distance and closure state, aircraft weight/width, mountainous/winter/weather needs, owners' commercial access, restricted airspace, repairs and services. Where the problem is a short-lived NOTAM, reclassify after source verification.

**Priority C — Validate the 1,013 shortlisted records against final airplane and gameplay standards.** The absence of an existing scheduled airline does not disqualify a valid player-created airline route. But runways, owner limits, any actual blanket commercial-use prohibition, category criteria and record freshness need a distinct signoff before inclusion. The six authorized airport categories are **Local, Regional, Medium, Large, Major Hub, Mega Hub**; none has been assigned or approved through this screening.

**No gameplay activation until separately reviewed and explicitly authorized.** A successful screening is not legal flight clearance or a commitment that all 1,013 will be approved.
