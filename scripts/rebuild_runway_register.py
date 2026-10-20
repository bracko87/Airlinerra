#!/usr/bin/env python3
"""Rebuild the runway-only master from ALL completed group screens.

Never rebuild from a single group: a subsequent group must not erase prior rows.
Only runway-qualified records are included; no final six-category ranking.
"""
from __future__ import annotations
import argparse
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
GENERATED = ROOT / "data/airports/generated"
REGISTER = ROOT / "data/airports/airport_register.csv"
COLUMNS = (
    "source_airport_id", "country_iso", "airport_name", "ident", "gps_code",
    "runway_length_m", "runway_surface", "minimum_eligible_level", "runway_status"
)

def paths():
    found = sorted(GENERATED.glob("group*/group*_technical_candidates.csv"))
    if not found:
        raise ValueError("No group screens available; existing master must not be replaced")
    return found

def build(target: Path = REGISTER) -> int:
    existing = paths()
    records=[]
    seen_ids=set()
    seen_codes=set()
    countries={}
    for source in existing:
        group = source.parent.name
        with source.open(newline="", encoding="utf-8-sig") as infile:
            source_rows = list(csv.DictReader(infile))
        if not source_rows:
            raise ValueError(f"Empty technical screen for {group}; refuse to erase data")
        for row in source_rows:
            airport_id=row["ourairports_id"].strip()
            country=row["iso_country"].strip()
            name=row["airport_name"].strip()
            code=(row.get("gps_code") or row.get("ident") or "").strip()
            runway_m=float(row["longest_reported_eligible_runway_m"])
            if not airport_id or not country or not name or runway_m < 1200:
                raise ValueError(f"Invalid runway candidate in {group}: {airport_id}")
            if airport_id in seen_ids:
                raise ValueError(f"Duplicate source airport ID {airport_id} in {group}")
            seen_ids.add(airport_id)
            if code and (country,code) in seen_codes:
                raise ValueError(f"Duplicate airport code {country}/{code}")
            if code: seen_codes.add((country,code))
            if country in countries and countries[country]!=group:
                raise ValueError(f"Country {country} screened by multiple groups; investigate grouping")
            countries[country]=group
            records.append({
                "source_airport_id":airport_id,
                "country_iso":country,
                "airport_name":name,
                "ident":row.get("ident",""),
                "gps_code":row.get("gps_code",""),
                "runway_length_m":row["longest_reported_eligible_runway_m"],
                "runway_surface":row["surface"],
                "minimum_eligible_level":"1",
                "runway_status":"RUNWAY_QUALIFIED"
            })
    records.sort(key=lambda r:(r["country_iso"],r["airport_name"],int(r["source_airport_id"])))
    target.parent.mkdir(parents=True,exist_ok=True)
    with target.open("w",encoding="utf-8",newline="") as outfile:
        writer=csv.DictWriter(outfile,fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(records)
    print(f"MASTER: {len(records)} runway-only Level-1 candidates from {len(existing)} groups, {len(countries)} countries")
    return len(records)

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--out",type=Path,default=REGISTER)
    args=parser.parse_args()
    build(args.out)
