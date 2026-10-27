# Airlinerra World 1 — Manual airport approval checklist

## Scope and reference datasets

This is a **database review**, not real-world flight certification. All values are in the 27 October 2026 Airlinerra airport registry. The files below are **review candidates**, not an assertion that an ICAO assignment or runway is independently validated.

1. [Master shortlist — 6,862 rows](world1_icao_paved_1200_master_6862_2026-10-27.csv) (5,518 dedicated ICAO field + 1,344 source four-letter codes that need ICAO classification).
2. [Recorded ICAO field + historic paved >=1,200m — 5,518](world1_recorded_icao_paved_1200_5518_2026-10-27.csv).
3. [Other four-letter source identifiers for manual ICAO verification — 1,344](world1_possible_icao_paved_1200_1344_2026-10-27.csv).
4. [Current World 1 approval and exceptions](CURRENT_WORLD1_AIRPORT_CATALOG.md).

### Mandatory approval gates for a *playable civilian-airline airport* in World 1

- **Identity:** ICAO location indicator is legitimately assigned to *this airport*, ideally verified from official State AIP/regulator or ICAO Doc 7910. A four-letter source string is **not** proof. ICAO code must not duplicate a different airport, be retired/reassigned or confuse a nearby air base or heliport. Non-ICAO local/GPS identifiers stay separate.
- **Physical runway:** At least one **single continuous, operational fixed-wing runway** has an asphalt or concrete paved section **>=1,200m**. Composite asphalt/concrete pavement qualifies. Do not add grass/gravel/dirt sections to paved length, merge multiple runways or rely solely on historical overall length. Save source, runway identifier, length and surface. Interpret bitumen/macadam independently before equating to the approved two surfaces.
- **Current usable status:** Not permanently closed, dismantled or converted into a heliport. For temporary closures, record restricted/unavailable until reopened, rather than silently letting normal airline routes operate.
- **Civilian access:** Public/civil fixed-wing flights are allowed, or legitimate civil use with explicitly supported restrictions. **Military-only, private PPR, glider-only and test-field facilities are not automatically playable normal airline destinations**, even when they pass the runway test. Store restriction status separately from runway verification. Do not misstate this as proof of a commercial airline operating licence.
- **Minimum gameplay data:** Valid country, airport identity, coordinates, unique `airport_key`, source-backed runway dimensions and one provisional category from exactly **Local, Regional, Medium, Large, Major Hub, Mega Hub**; world_number=1. The classification can be refined using traffic/capacity later, but cannot be an invented claim of terminal capacity.

### Decisions

- `APPROVE_PLAYABLE` — all mandatory gates cleared for the game catalog.
- `RESTRICTED_NOT_ROUTEABLE` — physical airport exists/qualifies but normal civil airline operations not supported; may be kept as historical world reference without playable airline routes.
- `REVIEW_NEEDED` — missing or inconsistent ICAO, pavement, closure status or access evidence.
- `REJECT` — documented false airport identity, permanently closed/non-fixed-wing, or no qualifying paved runway.

## Not required for initial airport eligibility

IATA three-letter code, passenger-demand forecasts, cargo estimates, top destinations, fuel facilities, detailed terminal capacity, jet bridges and airline traffic history are **not** prerequisites for the basic airport list. They are later game-modeling tasks.

## Integrity notes

On this date, **5,518** of 8,153 registry airports contain four-letter codes in the dedicated `airport_codes.code_system='ICAO'` field and a registry asphalt/concrete/PEM runway >=1,200m, but that field's provenance is `IDENTITY_SOURCE_REPORTED_UNVERIFIED`. **5,516** are already active; **2** are explicitly rejected (Creil Air Base LFPC — legal closure; Hiroshima Heliport RJBH — no current 1,200m fixed-wing runway). Among the 5,518, **71** have no qualifying separate runway-observation row and warrant priority confirmation. The other 1,344 airport sources have similar four-letter GPS or source identifiers but **no dedicated ICAO-code entry**. Treat this as an ICAO verification queue, not proven ICAO assignment.

The existing 3,140-airport foundation World 1 cohort is preserved. This checklist does not automatically reactivate known rejected facilities, nor demote currently active ones without specific evidence and review.
