#!/usr/bin/env python3
"""Verify permanent Airlinerra airport data in runway-only collection phase.

This checks only the minimum-Level-1 candidate criteria. Final six-category
ranking, civilian access, operational limits and playable status are DEFERRED.
"""
from __future__ import annotations

import csv
from pathlib import Path
import sys
from screen_group4 import surface_type

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "data/airports/airport_register.csv"
GROUP4 = ROOT / "data/airports/generated/group4/group4_technical_candidates.csv"
HISTORICAL14 = ROOT / "data/airports/group4_review.csv"
COLUMNS = {
    "source_airport_id","country_iso","airport_name","ident","gps_code",
    "runway_length_m","runway_surface","minimum_eligible_level","runway_status"
}

def read_csv(path):
    with path.open("r",encoding="utf-8-sig",newline="") as stream:
        reader=csv.DictReader(stream)
        if not reader.fieldnames or len(reader.fieldnames)!=len(set(reader.fieldnames)):
            raise ValueError(f"{path} missing or duplicate headers")
        rows=list(reader)
        if any(None in row for row in rows):
            raise ValueError(f"{path}: extra CSV fields")
        return set(reader.fieldnames),rows

def validate():
    columns,rows=read_csv(MASTER)
    if columns != COLUMNS:
        raise ValueError(f"Master must contain ONLY current-phase columns, got {sorted(columns)}")
    if not rows:
        raise ValueError("Master airport register must not be empty")
    ids=set()
    codes=set()
    master={}
    for line,row in enumerate(rows,2):
        ident=row["source_airport_id"].strip()
        country=row["country_iso"].strip()
        airport_name=row["airport_name"].strip()
        code=(row["gps_code"] or row["ident"]).strip()
        if not ident or ident in ids:
            raise ValueError(f"Row {line}: missing or duplicate source ID")
        ids.add(ident)
        master[ident]=row
        if len(country)!=2 or not country.isalpha() or country.upper()!=country:
            raise ValueError(f"Row {line}: invalid country")
        if not airport_name:
            raise ValueError(f"Row {line}: missing airport name")
        if code:
            key=(country,code)
            if key in codes:
                raise ValueError(f"Row {line}: duplicate airport code {key}")
            codes.add(key)
        try:
            length=float(row["runway_length_m"])
        except ValueError:
            raise ValueError(f"Row {line}: invalid runway length") from None
        if length < 1200 or length != length:
            raise ValueError(f"Row {line}: runway shorter than 1200 m")
        if surface_type(row["runway_surface"])!="ELIGIBLE_LABEL":
            raise ValueError(f"Row {line}: runway surface is not verified asphalt/concrete label")
        if row["minimum_eligible_level"]!="1" or row["runway_status"]!="RUNWAY_QUALIFIED":
            raise ValueError(f"Row {line}: invalid Level-1 runway-only marker")

    _,screened=read_csv(GROUP4)
    screening={row["ourairports_id"]:row for row in screened}
    if len(screening)!=len(screened):
        raise ValueError("Group 4 source has duplicate airport source IDs")
    for ident,raw in screening.items():
        if ident not in master:
            raise ValueError(f"Group 4 screened airport {ident} missing from permanent register")
        canonical=master[ident]
        if (canonical["country_iso"],canonical["airport_name"],canonical["runway_surface"]) != (
            raw["iso_country"],raw["airport_name"],raw["surface"]):
            raise ValueError(f"Airport {ident}: permanent data differs from technical screening")
        if abs(float(canonical["runway_length_m"])-float(raw["longest_reported_eligible_runway_m"]))>0.01:
            raise ValueError(f"Airport {ident}: runway length differs from technical screening")

    _,prior=read_csv(HISTORICAL14)
    for row in prior:
        if row["status"]!="REVIEW":
            raise ValueError("Older 14-airport notes must remain historical review records")
        if not any(s["gps_code"]==row["icao"] or s["ident"]==row["icao"] for s in screened):
            raise ValueError(f"Previously found airport missing from Group 4: {row['icao']}")
    print(f"VALIDATED: {len(rows)} permanent minimum-Level-1 runway candidates; "
          f"{len(screened)} screened Group 4 airports reconciled; "
          f"{len(prior)} previous notes reconciled. Final airport ranking deferred.")

if __name__=="__main__":
    try: validate()
    except Exception as e:
        print("VALIDATION FAILED: "+str(e),file=sys.stderr)
        sys.exit(1)
