# FAA commercial verification — Batch 2 (2026-10-23)

Follow-up to [Batch 1](FAA_COMMERCIAL_SERVICE_REVIEW_BATCH_01_2026-10-23.md). FAA Part 139 classes are regulatory and do not replace Airlinerra's six game categories.

| Airport | FAA code | Class | Verified research evidence | Gameplay review |
|---|---|---|---|---|
| Venango Regional | FKL | II | 2024 regional plan and March 2026 local report describe scheduled commercial airline cessation in 2019; general aviation continues, possible charter development | No scheduled airline assumed; review charter eligibility |
| Grand Canyon West | 1G4 | III | Grand Canyon Scenic Airlines advertises scheduled bookable flights connecting 1G4 and Boulder City | Tourism-specific service; review permissions and aircraft constraints |
| Willow Run | YIP | IV | Airport officially identifies Kalitta Air, Kalitta Charters, USA Jet and Ameristar, describing cargo and corporate service | High-priority cargo evidence; do not infer scheduled passenger service |
| Donaldson Field | GYH | IV | Airport operator SCTAC advertises cargo, charters, industrial/MRO activities, 8,000-ft runway, Part 139 status | High-priority cargo/charter evidence; no scheduled passenger service established |

Sources:
- Venango: https://www.explorevenango.com/local/2026/03/09/venango-regional-airport-is-busier-than-you-probably-realize-619481/ and https://www.pa.gov/agencies/penndot/traveling-in-pa/airports/venango-regional-airport and https://cms5.revize.com/revize/northwest/Document_Center/Community%20Development/Studies%20and%20plans/NW%20RPO%20LRTP%202050.pdf
- Grand Canyon West: https://www.scenic.com/flights/grand-canyon
- Willow Run: https://www.willowrunairport.com/cargo
- Donaldson Field: https://sc-tac.com/services/industrial-airpark/

Private Supabase table `airlinerra.airport_commercial_verification`: four rows updated with dated research notes; FKL, 1G4 and YIP received operator/source URLs; GYH already had a state aeronautics evidence URL and retains it, with supplemental SCTAC source in its note. No airport game admission statuses or world activations changed.

Next: continue Class IV airports, differentiate cargo/charter use from scheduled passenger service, validate aircraft performance and airport access prior to any gameplay approval.