#!/usr/bin/env python3
"""Validate airport runway-only master against ALL available group screens."""
from __future__ import annotations
import csv
import math
import sys
from pathlib import Path
from screen_group4 import surface_type

ROOT=Path(__file__).resolve().parents[1]
MASTER=ROOT/"data/airports/airport_register.csv"
GENERATED=ROOT/"data/airports/generated"
HISTORICAL14=ROOT/"data/airports/group4_review.csv"
COLUMNS={"source_airport_id","country_iso","airport_name","ident","gps_code","runway_length_m","runway_surface","minimum_eligible_level","runway_status"}

def load(path):
    with path.open("r",encoding="utf-8-sig",newline="") as stream:
        reader=csv.DictReader(stream)
        if not reader.fieldnames or len(reader.fieldnames)!=len(set(reader.fieldnames)):
            raise ValueError(f"{path}: missing/duplicate headers")
        rows=list(reader)
        if any(None in row for row in rows):
            raise ValueError(f"{path}: malformed CSV")
    return set(reader.fieldnames),rows

def validate():
    cols,rows=load(MASTER)
    if cols!=COLUMNS or not rows:
        raise ValueError("Master needs nonempty runway-only records and exact required columns")
    ids=set()
    codes=set()
    master={}
    for line,row in enumerate(rows,2):
        ident=row["source_airport_id"].strip()
        country=row["country_iso"].strip()
        name=row["airport_name"].strip()
        code=(row["gps_code"] or row["ident"]).strip()
        if not ident or ident in ids: raise ValueError(f"Row {line}: duplicate or empty airport ID")
        ids.add(ident)
        master[ident]=row
        if len(country)!=2 or not country.isalpha() or country!=country.upper() or not name:
            raise ValueError(f"Row {line}: invalid country/name")
        if code:
            key=(country,code)
            if key in codes: raise ValueError(f"Row {line}: duplicate country/airport code {key}")
            codes.add(key)
        try:
            length=float(row["runway_length_m"])
        except ValueError:
            raise ValueError(f"Row {line}: invalid length") from None
        if not math.isfinite(length) or length<1200:
            raise ValueError(f"Row {line}: runway <1200 m")
        if surface_type(row["runway_surface"].strip().strip(chr(39)+chr(34)))!="ELIGIBLE_LABEL":
            raise ValueError(f"Row {line}: surface not identified as asphalt/concrete")
        if row["minimum_eligible_level"]!="1" or row["runway_status"]!="RUNWAY_QUALIFIED":
            raise ValueError(f"Row {line}: incorrect minimum-level runway status")
    paths=sorted(GENERATED.glob("group*/group*_technical_candidates.csv"))
    if not paths: raise ValueError("Missing technical group screens")
    seen=set()
    total=0
    for path in paths:
        _,raw_rows=load(path)
        if not raw_rows: raise ValueError(f"Empty screen: {path}")
        for row in raw_rows:
            ident=row["ourairports_id"]
            if ident in seen: raise ValueError(f"Repeated source ID across groups: {ident}")
            seen.add(ident)
            total+=1
            canonical=master.get(ident)
            if canonical is None: raise ValueError(f"Airport {ident} absent from master: {path}")
            if (canonical["country_iso"],canonical["airport_name"],canonical["runway_surface"])!=(
                    row["iso_country"],row["airport_name"],row["surface"]):
                raise ValueError(f"Airport {ident}: data mismatch: {path}")
            if abs(float(canonical["runway_length_m"])-float(row["longest_reported_eligible_runway_m"]))>0.01:
                raise ValueError(f"Airport {ident}: runway length mismatch")
    if len(master)!=total:
        raise ValueError(f"Master rows {len(master)} != screened rows {total}; untraceable airports present")

    group4=GENERATED/"group4/group4_technical_candidates.csv"
    if not group4.exists(): raise ValueError("Group 4 source must be retained")
    _,group4rows=load(group4)
    _,prior=load(HISTORICAL14)
    for row in prior:
        if row["status"]!="REVIEW":
            raise ValueError("Historical Group 4 list must remain a review record")
        if not any(s["gps_code"]==row["icao"] or s["ident"]==row["icao"] for s in group4rows):
            raise ValueError(f"Previously known airport absent from Group 4: {row['icao']}")
    print(f"VALIDATED: {len(rows)} runway-only minimum-Level-1 airports from {len(paths)} groups; {len(group4rows)} Group 4, {len(prior)} historic cross-checks")

if __name__=="__main__":
    try: validate()
    except Exception as exc:
        print(f"VALIDATION FAILED: {exc}",file=sys.stderr)
        sys.exit(1)
