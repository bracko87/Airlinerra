# Airlinerra Group 7 — commercial evidence review (2026-10-21)

This review covers **47** original runway-qualified candidates: Montenegro 2, North Macedonia 2, Netherlands 12, Norway 31 and Monaco 0. The original `airport_register.csv` remains the immutable technical source, not a list of playable commercial airports.

## Evidence-based country counts

| Country | Technical candidates | Passenger evidence | Cargo evidence | Military review | Both unknown |
|---|---:|---:|---:|---:|---:|
| Monaco | 0 | 0 | 0 | 0 | 0 |
| Montenegro | 2 | 2 | 2 | 0 | 0 |
| North Macedonia | 2 | 2 | 1 | 0 | 0 |
| Netherlands | 12 | 6 | 3 | 4 | 6 |
| Norway | 31 | 22 | 8 | 2 | 9 |
| **TOTAL** | **47** | **32** | **14** | **6** | **15** |

The categories overlap. Passenger and cargo YES require a real airport-specific activity report or published handling service; they are **not** authorizations for all commercial aircraft, hours, routes or volumes. The unknown state does **not** mean a legal ban. Official flight frequencies, actual monthly/yearly traffic, aircraft size limits, runway slots, remote stands, gates, curfews, noise thresholds and modelled daily demand are still outstanding.

## Source notes and important exceptions

- **Monaco (MC):** No airport met the required 1,200m asphalt/concrete fixed-wing runway screen. Heliports do not count.
- **Montenegro:** Podgorica and Tivat operator reports commercial passenger service and separately documents cargo/mail handling. At Podgorica, the cargo handling and customs warehouse have special acceptance and storage conditions. Sources: https://montenegroairports.com/novosti/datum-za-istoriju-nase-avijacije-aerodromi-prvi-put-u-istoriji-opsluzili-tri-miliona-putnika/ , https://montenegroairports.com/en/podgorica-airport/business-information/airport-services/ , https://montenegroairports.com/en/tivat-airport/business-information/airport-services .
- **North Macedonia:** TAV operator publishes 2026 passenger activity at Skopje and Ohrid; only Skopje has independently confirmed cargo terminal and customs handling in this review. Skopje airport is described as H24, **but the usual cargo desk hours differ**. Sources: https://ohd.airports.com.mk/en-EN/media-centre/press-releases/page/tav-macedonia-skopje-and-ohrid-airports-air-traffic-results-january-september-2026-eng- , https://airports.mk/en-EN/airport-facilities-services/cargo-terminal/page/cargo-terminal-cargo-services .
- **Netherlands:** Statistics Netherlands 2025 confirms five public passenger airports: Schiphol, Eindhoven, Groningen, Maastricht and Rotterdam. Freight is specifically published at Schiphol and Maastricht. **Den Helder** operator documents commercial helicopter **offshore** passengers and freight (2025), so it is not a regular fixed-wing public scheduled-airline destination merely because passenger YES. **Lelystad** is currently not authorized for proposed scheduled leisure operations, pending aviation and environmental permissions (government April 2026). See machine-readable restrictions CSV. Sources: https://www.cbs.nl/nl-nl/nieuws/2026/07/ruim-78-miljoen-luchtvaartpassagiers-in-2025 , https://www.cbs.nl/en-gb/figures/detail/37478eng , https://denhelderairport.nl/luchthaven/ , https://www.rijksoverheid.nl/actueel/nieuws/2026/04/17/minister-karremans-streeft-naar-opening-lelystad-airport-in-oktober-2027 .
- **Norway:** Avinor lists operating public passenger airports individually, with actual 2025/2026 company traffic statistics. Torp Sandefjord has its own published passenger figures. Airfreight handling companies are published for Oslo, Bergen, Stavanger, Bodø, Florø, Røros, Sandnessjøen and Svalbard; a freight operator's presence does not prove dedicated freighter operations. Fagernes' scheduled traffic stopped 2016 and commercial charter service closed 2018. Rygge and Ørland remain military/civilian access reviews, and Svalbard has specific PPR restrictions to verify. Sources: https://www.avinor.no/en/ , https://om.avinor.no/en/about-us/traffic-statistics/ , https://torp.no/om-torp-sandefjord-lufthavn/passasjerstatistikk/ , https://www.stortinget.no/no/Saker-og-publikasjoner/Sporsmal/Skriftlige-sporsmal-og-svar/Skriftlig-sporsmal/?qnid=87341 .

## Game and audit safeguards

`group7_operational_restrictions.csv` captures source-backed Lelystad and Fagernes constraints. Do not automatically activate a runway-qualified airport as passenger/cargo destination. Never assume UNKNOWN = 0 traffic or 24/7 operating rights. Do not infer a missing ICAO code from a source ident or replace existing airport source IDs. All historical airports, including fictional LYAL, remain unchanged and none are imported into Supabase.

The original Group 7 country counts include MC=0. Check all 47 source IDs and zero jurisdictions using:

```sh
python scripts/validate_commercial_group.py --group 7
```

Next Group 8: Poland, Portugal, Romania, Russia as one whole country, San Marino. Its 397 airports justify reviewing Russia in sub-batches without geographic splitting.
