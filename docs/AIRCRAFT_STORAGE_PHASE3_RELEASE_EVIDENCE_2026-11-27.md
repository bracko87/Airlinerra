# Phase 3 storage-only evidence — 2026-11-27

Read-only database inspection and public source review. No live admission or permission granted. All four candidates exist in the airport registry; none has a game reference profile or runway inventory for World 1. Mojave and Pinal have no unified commercial operations row. Cotswold and St Athan have operationally_authorized=false; preserve existing commercial scope.

| Candidate | Registry key | Reviewed physical runway reference | Routine service / permission evidence | Remaining decision |
|---|---|---|---|---|
| Pinal Airpark KMZJ | OURAIRPORTS:20594 | 6849 x 150 ft (2087.6 x 45.7 m) | Attended 0700–1530 local; fuel/ground service after hours or holidays by arrangement; operator describes first-time arrival permission | Confirm directional distances, routine service days and first-arrival permission mechanism |
| Mojave KMHV | OURAIRPORTS:20507 | FAA runway 12/30 12500 x 200 ft (3810 x 60.96 m); retain conservative length | Jet A listed; airport attended continuously, tower and service hours differ; special operations subject to coordination | Confirm routine ferry fuel hours, runway restrictions and explicit game elevation factor; do not equate special operations policy with all ferry flights |
| Cotswold EGBP | OURAIRPORTS:2395 | 2009 x 45 m physical reference; directional declared distances still to reconcile | Airport publishes daily 0900–1700 and prior permission for every movement; Jet A-1 available by arrangement | Mandatory game permission and noise policy; confirm conservative declared lengths |
| St Athan EGSY | OURAIRPORTS:2409 | Operator describes 1800 m runway; previous candidate 1828 x 45 m requires authoritative width and declared distance review | Official operator lists Jet A-1, daily 0900–1700 local, mandatory PPR and host/sponsor; outside-hours requests at least 48 hours in advance | Reconcile legacy ident EGDX with current EGSY without duplicate; explicit permission/sponsor model; confirm runway width |

## Evidence and source limitations

- Pinal county confirms storage/MRO: https://www.pinal.gov/1831/Pinal-Airpark
- Pinal airport record: https://www.airnav.com/airport/MZJ ; operator service/access: https://sjhaerocare.com/facility
- Mojave FAA long runway: https://www.faa.gov/space/spaceports_by_state ; fuel: https://www.airnav.com/airport/KMHV/A1 ; airport special operations: https://www.mojaveairport.com/operations/page/special-operations
- Mojave current airport listing: https://vfrmap.com/fe?q=KMHV&req=get_afd ; operator runway page returned HTTP 403 during review, so not relied upon as verified.
- Cotswold hours and briefing: https://cotswoldairport.com/pilot-briefing/ ; mandatory PPR: https://cotswoldairport.com/online-ppr-prior-permission-required/ ; fuel: https://cotswoldairport.com/fuel-jet-a1-and-avgas/ ; physical dimensions: https://kembleflyingclub.com/our-airport/ ; storage: https://airsalvage.co.uk/location/
- St Athan primary operator: https://www.brotathan.wales/egsyoverview ; storage operator: https://www.ecube.aero/about-us/locations/united-kingdom/ ; CAA record of change from EGDX to EGSY: https://airspacechange.caa.co.uk/documents/download/852 (search-index evidence; primary document to confirm before changing registry identity).

Official St Athan airport operator confirms Jet A-1 is available, resolving the prior public-source fuel uncertainty, not authorizing a game fuel supplier. Keep existing provisional database evidence until reviewed profile and fuel approval are staged. No changes to commercial airport registry, commercial operations, game reference profiles or facility authorization.

## Release sequencing

The service calendar implementation passed isolated workflow 46028225183. Mandatory prior permission currently fails closed. Add a scoped game-only permission workflow with airline, aircraft, airport, operation, time window and revocation evidence before approving PPR-only facilities. No real permission is requested or implied. Ordinary booking must not bypass approval. All six dedicated storage airports still need actual game operational reviews and final admission snapshots. KAVQ (Marana Regional) is a separate airport and remains excluded. Storage capacity and duration remain unlimited; monthly USD 4000/8000/15000 unchanged.
