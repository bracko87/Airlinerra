#!/usr/bin/env python3
"""Prepare a source-ID-safe Brazil 2025 commercial traffic crosswalk from ANAC flight stages.

Reads the full ANAC Dados_Estatisticos.csv in streaming mode (no pandas or database).
This creates a REVIEW file only: it NEVER promotes passenger/cargo permissions, changes
the technical register, or enables airports in gameplay.

Official dataset:
https://sistemas.anac.gov.br/dadosabertos/Voos%20e%20opera%C3%A7%C3%B5es%20a%C3%A9reas/Dados%20Estat%C3%ADsticos%20do%20Transporte%20A%C3%A9reo/
"""
import argparse
import csv
import pathlib
import re
import unicodedata
from collections import defaultdict

ROOT = pathlib.Path(__file__).resolve().parents[1]
SOURCE = ROOT / "data/airports/generated/group46/group46_technical_candidates.csv"
DEFAULT_OUTPUT = ROOT / "data/airports/commercial/group46/group46_brazil_anac_2025_official_crosswalk.csv"
DATA_URL = ("https://sistemas.anac.gov.br/dadosabertos/Voos%20e%20opera%C3%A7%C3%B5es"
            "%20a%C3%A9reas/Dados%20Estat%C3%ADsticos%20do%20Transporte%20A%C3%A9reo/"
            "Dados_Estatisticos.csv")


def norm(value):
    value = unicodedata.normalize("NFKD", (value or "").upper())
    return re.sub(r"[^A-Z0-9]", "", "".join(c for c in value if not unicodedata.combining(c)))


def number(value):
    value = (value or "").strip().replace(" ", "")
    if not value:
        return 0.0
    # ANAC uses decimal comma. Statistics must be nonnegative; ignore invalid values.
    try:
        result = float(value.replace(".", "").replace(",", "."))
    except ValueError:
        return 0.0
    return result if result > 0 else 0.0


def columns(fields):
    normalized = {norm(k): k for k in fields}
    wanted = {
        "year": "ANO",
        "origin": "AEROPORTODEORIGEMSIGLA",
        "destination": "AEROPORTODEDESTINOSIGLA",
        "flight": "GRUPODEVOO",
        "paid_pax": "PASSAGEIROSPAGOS",
        "free_pax": "PASSAGEIROSGRATIS",
        "paid_kg": "CARGAPAGAKG",
        "free_kg": "CARGAGRATISKG",
    }
    missing = [name for name, key in wanted.items() if key not in normalized]
    if missing:
        raise ValueError("ANAC CSV missing columns: " + ", ".join(missing) +
                         ". Found: " + ", ".join(normalized)[:500])
    return {name: normalized[key] for name, key in wanted.items()}


def source_airports():
    with SOURCE.open(encoding="utf-8-sig", newline="") as f:
        records = [r for r in csv.DictReader(f) if r["iso_country"] == "BR"]
    ids = [r["ourairports_id"] for r in records]
    if len(set(ids)) != len(ids):
        raise ValueError("Duplicate technical source airport ID")
    codes = defaultdict(set)
    for r in records:
        for code in [r["ident"], r["gps_code"]]:
            if code and len(code) == 4:
                codes[code.upper()].add(r["ourairports_id"])
    return records, {code: next(iter(ids)) for code, ids in codes.items() if len(ids) == 1}


def aggregate(data_rows, fieldnames, code_to_id, year=2025):
    c = columns(fieldnames)
    totals = defaultdict(lambda: {"regular_pax": 0.0, "nonregular_pax": 0.0,
                                  "regular_kg": 0.0, "nonregular_kg": 0.0,
                                  "flight_stage_rows": 0})
    matched_rows = 0
    for row in data_rows:
        if row.get(c["year"], "").strip() != str(year):
            continue
        flight = norm(row.get(c["flight"]))
        if flight == "REGULAR":
            tag = "regular"
        elif flight in {"NAOREGULAR", "NREGULAR"}:
            tag = "nonregular"
        else:
            # Exclude non-revenue/improductive and uninterpretable flight groups.
            continue
        origin = row.get(c["origin"], "").strip().upper()
        dest = row.get(c["destination"], "").strip().upper()
        matched = {code_to_id[code] for code in (origin, dest) if code in code_to_id}
        if not matched:
            continue
        matched_rows += 1
        pax = number(row.get(c["paid_pax"])) + number(row.get(c["free_pax"]))
        kg = number(row.get(c["paid_kg"])) + number(row.get(c["free_kg"]))
        for airport_id in matched:
            d = totals[airport_id]
            d[tag + "_pax"] += pax
            d[tag + "_kg"] += kg
            d["flight_stage_rows"] += 1
    return totals, matched_rows


def write_crosswalk(path, records, totals, source_url):
    path.parent.mkdir(parents=True, exist_ok=True)
    fields = ["source_airport_id", "icao_or_ident", "airport_name", "year",
              "regular_passenger_movements", "nonregular_passenger_movements",
              "regular_cargo_kg", "nonregular_cargo_kg", "matched_flight_stage_rows",
              "passenger_evidence", "cargo_evidence", "source_url", "qualification_note"]
    with path.open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(fields)
        for r in records:
            d = totals.get(r["ourairports_id"], {})
            rp, np = d.get("regular_pax", 0), d.get("nonregular_pax", 0)
            rk, nk = d.get("regular_kg", 0), d.get("nonregular_kg", 0)
            w.writerow([r["ourairports_id"], r["gps_code"] or r["ident"],
                        r["airport_name"], 2025, round(rp), round(np),
                        round(rk), round(nk), d.get("flight_stage_rows", 0),
                        "YES" if rp + np > 0 else "UNKNOWN",
                        "YES" if rk + nk > 0 else "UNKNOWN",
                        source_url,
                        "Evidence of 2025 traffic only; not 2026 permissions. Missing ANAC evidence != no service."])


def smoke_test():
    header = ["ANO", "AEROPORTO DE ORIGEM (SIGLA)", "AEROPORTO DE DESTINO (SIGLA)",
              "GRUPO DE VOO", "PASSAGEIROS PAGOS", "PASSAGEIROS GRÁTIS",
              "CARGA PAGA (KG)", "CARGA GRÁTIS (KG)"]
    rows = [
        dict(zip(header, ["2025", "SBEG", "SBGR", "REGULAR", "10", "2", "100,5", "0"])),
        dict(zip(header, ["2025", "SBEG", "XXXX", "NÃO REGULAR", "4", "", "0", "3"])),
        dict(zip(header, ["2025", "SBEG", "SBGR", "IMPRODUTIVO", "999", "", "999", ""])),
        dict(zip(header, ["2024", "SBEG", "SBGR", "REGULAR", "999", "", "999", ""])),
    ]
    totals, matched = aggregate(rows, header, {"SBEG": "5897", "SBGR": "5910"})
    assert matched == 2, matched
    assert totals["5897"]["regular_pax"] == 12
    assert totals["5897"]["nonregular_pax"] == 4
    assert totals["5897"]["regular_kg"] == 100.5
    assert totals["5897"]["nonregular_kg"] == 3
    assert totals["5910"]["regular_pax"] == 12
    print("SMOKE TEST PASSED — regular/charter split, ANAC headers, year filter, positive cargo")


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--anac-csv", type=pathlib.Path, help="Locally downloaded official ANAC Dados_Estatisticos.csv")
    ap.add_argument("--output", type=pathlib.Path, default=DEFAULT_OUTPUT)
    ap.add_argument("--encoding", default="cp1252", help="ANAC input encoding; use utf-8-sig if needed")
    ap.add_argument("--smoke-test", action="store_true")
    args = ap.parse_args()
    if args.smoke_test:
        smoke_test()
        return
    if not args.anac_csv or not args.anac_csv.is_file():
        ap.error("--anac-csv requires an existing ANAC official CSV; do not commit the large raw source into git")
    airports, codes = source_airports()
    with args.anac_csv.open("r", encoding=args.encoding, errors="replace", newline="") as f:
        # ANAC can prefix exports with an "Atualizado em" metadata line.
        # Locate the actual column header before parsing the rows.
        header = None
        for line_no, line in enumerate(f, 1):
            if line_no > 30:
                break
            fields = next(csv.reader([line], delimiter=";"), [])
            try:
                columns(fields)
            except ValueError:
                continue
            header = fields
            break
        if header is None:
            raise ValueError("ANAC column header not found within first 30 lines")
        reader = csv.DictReader(f, fieldnames=header, delimiter=";")
        totals, matched = aggregate(reader, header, codes)
    write_crosswalk(args.output, airports, totals, DATA_URL)
    print(f"Wrote {len(airports)} Brazil airport audit rows to {args.output}; "
          f"2025 airline flight-stage matches: {matched}; "
          f"pax-positive airports: {sum(x['regular_pax'] + x['nonregular_pax'] > 0 for x in totals.values())}; "
          f"freight-positive airports: {sum(x['regular_kg'] + x['nonregular_kg'] > 0 for x in totals.values())}")
    print("No game permission, technical runway, or commercial YES flags modified.")


if __name__ == "__main__":
    main()
