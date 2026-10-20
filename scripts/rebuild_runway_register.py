#!/usr/bin/env python3
"""Build the permanent, minimum-Level-1 runway-only Airlinerra airport register.

Airport inclusion is based ONLY on source records reporting an operational
asphalt/concrete runway of at least 1200 m. No civilian access, restrictions,
six-level final assignment or playable status checks belong to this phase.
"""
from __future__ import annotations
import argparse
import csv
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCREENED = ROOT / "data/airports/generated/group4/group4_technical_candidates.csv"
REGISTER = ROOT / "data/airports/airport_register.csv"
COLUMNS = (
    "source_airport_id", "country_iso", "airport_name", "ident", "gps_code",
    "runway_length_m", "runway_surface", "minimum_eligible_level", "runway_status"
)

def build(source: Path = SCREENED, target: Path = REGISTER) -> int:
    with source.open(newline="", encoding="utf-8-sig") as infile:
        source_rows = list(csv.DictReader(infile))
    if not source_rows:
        raise ValueError("Missing technical runway screening data; never erase a master register")
    records=[]
    seen_ids=set()
    seen_codes=set()
    for row in source_rows:
        airport_id=row["ourairports_id"].strip()
        country=row["iso_country"].strip()
        name=row["airport_name"].strip()
        code=(row.get("gps_code") or row.get("ident") or "").strip()
        runway_m=float(row["longest_reported_eligible_runway_m"])
        if not airport_id or not country or not name or runway_m < 1200:
            raise ValueError(f"Missing/invalid mandatory runway record {airport_id}")
        if airport_id in seen_ids:
            raise ValueError(f"Duplicate airport source ID {airport_id}")
        seen_ids.add(airport_id)
        if code and (country,code) in seen_codes:
            raise ValueError(f"Duplicate airport identifier {country}/{code}")
        if code: seen_codes.add((country,code))
        records.append({
            "source_airport_id":airport_id,
            "country_iso":country,
            "airport_name":name,
            "ident":row.get("ident", ""),
            "gps_code":row.get("gps_code", ""),
            "runway_length_m":row["longest_reported_eligible_runway_m"],
            "runway_surface":row["surface"],
            "minimum_eligible_level":"1",
            "runway_status":"RUNWAY_QUALIFIED",
        })
    records.sort(key=lambda r:(r["country_iso"],r["airport_name"],r["source_airport_id"]))
    target.parent.mkdir(parents=True,exist_ok=True)
    with target.open("w",encoding="utf-8",newline="") as out:
        writer=csv.DictWriter(out,fieldnames=COLUMNS)
        writer.writeheader()
        writer.writerows(records)
    print(f"MASTER AIRPORT REGISTER: {len(records)} runway-qualified minimum-Level-1 records")
    return len(records)

if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--source",type=Path,default=SCREENED)
    parser.add_argument("--out",type=Path,default=REGISTER)
    args=parser.parse_args()
    build(args.source,args.out)
