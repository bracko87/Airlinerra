# Airlinerra production aircraft removal — 2026-11-06

User-approved permanent removal from the game catalog and source aircraft database:

| Aircraft | Configuration ID | Variant ID | Family ID | Use type |
|---|---:|---:|---:|---|
| Curtiss-Wright Curtiss C-46 Commando civilian cargo | 136 | 140 | 68 | Cargo |
| Douglas Aircraft Company Douglas DC-3 cargo-configured | 135 | 136 | 64 | Cargo |

## Action performed

Removed both aircraft from `airlinerra.aircraft_configurations`, their dedicated
`airlinerra.aircraft_variants`, and exclusive `airlinerra.aircraft_families`,
with dependent aircraft research, media link, game-service, noise, technical-specification,
and airport compatibility records. The deletion was transactionally guarded to match
these exact IDs, manufacturers, model names and roles. No player-held or test-fleet
airframes referenced either configuration.

The two removed aircraft had **6,282 total airport compatibility rows** in
`airlinerra_game.section5_full_weight_airport_aircraft_screen_v2`, also deleted
with the aircraft records.

## Post-deletion verification

- Raw configurations: **233** (down from 235).
- Raw aircraft variants: **195** (down from 197).
- Player-visible aircraft: **229** (with four earlier catalog exclusions unchanged).
- Removed aircraft configurations/variants/families remaining: **0**.
- Their airport compatibility records remaining: **0**.
- Missing active aircraft images: **0**.
- No matching hardcoded fallback mappings found in the website aircraft library.
- The existing production aircraft-library API query automatically excludes
  the deleted records; no endpoint redeployment is needed.

Two PNG files remain *unlinked* in the public `Admin/Airplanes` Storage folder:
`Airplanes/Curtiss-Wright Curtiss C-46 Commando civilian cargo cargo.png`
and `Airplanes/Douglas Aircraft Company Douglas DC-3 cargo-configured cargo.png`.
Their content is no longer referenced by the game catalog or aircraft-media tables.
Removing those two physical blobs requires the Supabase Storage API; deleting
`storage.objects` rows directly with SQL is intentionally avoided.

## Import/research caution

Do not reintroduce these two exact aircraft into a future scheduled aircraft import
without a new explicit product decision. Other Douglas or Curtiss aircraft, if any,
must remain unaffected.
