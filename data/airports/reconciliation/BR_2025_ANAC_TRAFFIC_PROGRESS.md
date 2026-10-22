# Brazil 2025 airport passenger and cargo verification — evidence progress

Audit date: 2026-10-22; active Airlinerra branch: `main`.

## Technical and commercial scope

* **577** source-ID-preserved technical runway-qualified airports are in Group 46 for Brazil.
* **20** airport-specific 2025 passenger and freight observations were reliably matched by the **exact ICAO code** from the LAWINFRA aggregation of Brazil's official ANAC flight-stage dataset.
* **557** Brazil technical airports are **not yet independently joined** to the full 2025 ANAC traffic files. An UNKNOWN review outcome is not a finding of no service.
* Group 46 now records **51 preliminary passenger YES candidates**, of which **20 have confirmed 2025 passenger movements from this source**. The other 31 are *still provisional* and must not be labeled verified.
* Group 46 now records **20 cargo YES** for Brazil, up from seven, after **13 newly evidenced positive cargo airports**. A cargo-positive airport may also be passenger-positive.
* **SBEG Manaus Eduardo Gomes has now been restored to the technical group and master** with original OurAirports airport **5897**, runway **234094**, and official DECEA 2,700 x 45 m asphalt classification. It is distinct from SDNM and SBMN.

## Evidence and definitions

The airline-operations aggregate for 2025 is a *secondary presentation* of official **ANAC Dados Estatísticos do Transporte Aéreo**, not directly processed raw ANAC file data in this audit:

https://www.lawinfra.com.br/mapa?camada=aeroportos

The 20 most-active airports displayed here provide 2025 rounded passenger-movement counts and 2025 cargo tonnage: `data/airports/commercial/group46/group46_anac_2025_top20_observed_activity.csv`. The site identifies passenger counts as paid + complimentary, all arrivals + departures, and cargo as paid + complimentary excluding mail/baggage, not unique travellers. **20/20 now have original source-ID matches in the restored roster.**

Our 576-row machine-readable crosswalk of verified versus unverified 2025 evidence is `data/airports/commercial/group46/group46_brazil_2025_source_coverage.csv`. Rows with no source join remain explicitly unverified.

The authoritative *raw* ANAC airline-carrier statistical dataset is available in official public file directories (very large CSV/JSON):

https://sistemas.anac.gov.br/dadosabertos/Voos%20e%20opera%C3%A7%C3%B5es%20a%C3%A9reas/Dados%20Estat%C3%ADsticos%20do%20Transporte%20A%C3%A9reo/

ANAC airport operator monthly RIMA files for 2025 (12 CSV files, each roughly 33–37 MB) are indexed at:

https://sistemas.anac.gov.br/dadosabertos/Operador%20Aeroportu%C3%A1rio/Dados%20de%20Movimenta%C3%A7%C3%A3o%20Aeroportu%C3%A1rias/2025/

ANAC notes that RIMA operator files cover concession airports and selected significant Infraero airports and are released on a six-month delay; absence from RIMA is *not* evidence of no flight service.

**Still required before declaring full verification:** download the 2025 official carrier flight-stage data, aggregate both origin and destination by ICAO (taking care not to double-count a movement within one airport), distinguish `REGULAR` from `NÃO REGULAR`, and require **positive paid/free passenger movements** or **positive paid/free freight kg**. Safely join to all 576 exact source IDs, recording source period and both country and ICAO identifiers. Resolve unjoined airports with ANAC aerodrome data/ICAO aliases or leave UNKNOWN. Cargo flights vs freight carried in passenger aircraft must be kept distinct where needed.

## Missing Manaus airport (high priority)

Brazil DECEA eAIP (AIP effective September 2026), SBEG AD 2.12: 2700 x 45 m, ASPHALT, runway 11/29:

https://aisweb.decea.mil.br/eaip/A%2016-2026_2026_09_03/eAIP/AD%202%20SBEG-pt-BR.html

Original raw OurAirports SBEG runway surface string is `ASPH 71/F/C/X/T`, a compound code not directly accepted by the current Airlinerra surface filter. Its verified **Asphalt** has now been recorded as an airport-specific surface override tied to runway **234094**. Do not confuse **SBEG** (Eduardo Gomes International Airport) with **SDNM** (Brigadeiro Eduardo Gomes) or **SBMN** (Ponta Pelada Manaus Air Base), which are different airports already in the roster.

The master technical register has been updated with one original-runway-ID-backed airport, SBEG. Existing airport records and six-category definitions have been preserved. No gameplay database changes or deployment. The official full 2025 ANAC statistical CSV remains unprocessed; ANAC monthly operator files were indexed but an attempted January fetch timed out. The 557 previously unverified Brazil technical airports still require direct row-level source reconciliation.
