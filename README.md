# Airlinerra

Private Next Quest Studio repository for Airlinerra, a real-time browser airline-management game.

## Controlled development
- **`staging`**: all normal changes, runway-data collection and testing.
- **`main`**: production, changed only through a reviewed PR with testing and explicit owner approval.
- Normal release windows are twice daily, manual (morning/evening); urgent releases require validation and owner approval.
- Nothing in this repository changes ProPeloton Manager or the Game Control Center.

See [AGENTS.md](AGENTS.md) and [release procedures](docs/CONTROLLED_RELEASES.md).

## Airport runway collection — current stage
For now we store ONLY airports reporting a **non-closed asphalt/concrete runway of at least 1,200 metres**. Each meets **minimum Level 1 (Local)** runway criteria; no final categorization, operating permissions or other airport information is being gathered.

[Permanent master airport register](data/airports/airport_register.csv): **618 runway-qualified airport candidates, Groups 1–7 combined**.

| Group | Airports in runway-only master |
| --- | ---: |
| 1 — Albania, Armenia, Austria, Azerbaijan | 30 |
| 2 — Belarus, Belgium, Bosnia and Herzegovina, Bulgaria, Croatia | 58 |
| 3 — Cyprus, Czechia, Denmark, Estonia, Finland | 74 |
| 4 — France, Georgia, Germany, Greece, Hungary | 307 |
| 5 — Iceland, Ireland, Italy, Kosovo, Latvia | 91 |
| 6 — Liechtenstein, Lithuania, Luxembourg, Malta, Moldova | 11 |
| 7 — Monaco, Montenegro, Netherlands, North Macedonia, Norway | 47 |
| **Total** | **618** |

**Important distinction:** Earlier discussions selected **110 airports** for Groups 1–3. The **162** airport candidates now in the master for those groups are a fresh, *runway-only* screen. The historical count of 110 and its 56 recovered names remain documented separately; it is not equivalent to the current screening count.

[Full airport-register documentation and source files](data/airports/README.md) · [Historical recovery file](data/airports/historical_approved_recovery.csv).

Validate with:
```sh
python scripts/validate_airports.py
python scripts/validate_historical_airports.py
```

## Game premises
One real day = one in-game day, no historical eras. Airlines begin with $5,000,000 USD and zero aircraft. Architecture supports three independent worlds, initially launching one.
