# Serbia / Group 9: commercial-readiness pilot (2026-10-21)

The pilot is stored in `serbia_commercial_pilot.csv` and keyed by **immutable source airport ID**. It contains **all 7** Serbia records, including fictional LYAL. Nothing here changes the original runway-qualified master or assigns real airports to one of the six final categories.

## Preliminary screening results

- **BEG/LYBE (Belgrade)**: confirmed scheduled passenger operations; airport operator explicitly provides cargo handling and customs facilities. Source: https://beg.aero/eng/practical-informations/cargo ; https://begv2-live.ha.rs/eng
- **INI/LYNI (Niš)**: confirmed scheduled passenger traffic, operator provides cargo handling/storage. Source: https://aerodromisrbije.rs/sajt/pocela-primena-letnjeg-reda-letenja-na-aerodromima-u-nisu-i-kraljevu-2/ ; https://ini.aerodromisrbije.rs/kargo-transport/
- **KVO/LYKV (Morava)**: confirmed 2026 scheduled passenger routes; cargo operations, terminal and permission not verified. Source: https://aerodromisrbije.rs/sajt/pocela-primena-letnjeg-reda-letenja-na-aerodromima-u-nisu-i-kraljevu-2/
- **LYUZ (Ponikve)**: official operator states *public use possible with prior approval*; this is not confirmation of unrestricted scheduled cargo/passenger commerce. **Important geometry discrepancy:** operator publishes paved usable runway **1,830 × 30m**, while source register preserves older OurAirports 3,087m-length candidate. Verify from AIP before using aircraft/slots engine. Source: https://aerodromponikve.rs/pilot-info/?lang=en
- **LY87 (Kovin)**: 2,184m paved runway in source, no source scheduled-service flag. No verified civilian commercial access or cargo facilities yet; status deliberately **NEEDS_REVIEW** rather than claiming airport unusable. Do not activate.
- **LYBT (Batajnica)**: military airport. No independent evidence reviewed proving commercial passenger/cargo availability. Status military review, *not* automatic civil activation.
- **LYAL (Aleksandrovo)**: owner-defined fictional Level 1, no approved coordinates. Await airport location and optional fictional operations rules; nothing invented.

## Rules applied

- `passenger_commercial_permission` and `cargo_commercial_permission` are independent; `UNKNOWN` does not mean `NO`.
- Confirmed 2026 scheduled passenger service provides evidence of actual passenger service. Cargo requires independent confirmation.
- `commercial_review_status` is preliminary; no in-game airport activated yet.
- Airport slots, apron stands, gates, capacity, noise restrictions, and curfews remain unverified and are **not set to zero**.
- Absolute traffic volumes are not claimed based on mere schedules.
- At least one paved runway >=1,200m does not guarantee capacity to serve a given model of airplane.

Next: check all five non-fictitious airport operational permissions from the most current Serbian AIP/operator publications, reconcile Ponikve official declared distances and assess the Kovin site. Apply the reviewed methodology group by group with priority on airports likely to be playable.
