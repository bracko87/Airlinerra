#!/usr/bin/env python3
"""Validate airport master, all group runway screens and fictional overlay."""
from __future__ import annotations
import csv
import math
import sys
from pathlib import Path
from airport_surface import surface_type
from rebuild_runway_register import CODE_CONFLICTS, CONFLICT_COLUMNS, code_conflicts

ROOT=Path(__file__).resolve().parents[1]
MASTER=ROOT/"data/airports/airport_register.csv"
FICTIONAL=ROOT/"data/airports/fictional_airports.csv"
GENERATED=ROOT/"data/airports/generated"
HISTORICAL14=ROOT/"data/airports/group4_review.csv"
COLUMNS={"source_airport_id","country_iso","airport_name","ident","gps_code",
         "runway_length_m","runway_surface","minimum_eligible_level",
         "runway_status","source_type","assigned_category"}
CATEGORIES={"Local","Regional","Medium","Large","Major Hub","Mega Hub"}

def load(path):
    with path.open("r",encoding="utf-8-sig",newline="") as f:
        reader=csv.DictReader(f)
        if not reader.fieldnames or len(reader.fieldnames)!=len(set(reader.fieldnames)):
            raise ValueError(f"{path}: invalid CSV headers")
        rows=list(reader)
        if any(None in row for row in rows): raise ValueError(f"{path}: malformed CSV")
    return set(reader.fieldnames),rows

def validate():
    if (surface_type("asphalt concrete")!="ELIGIBLE_LABEL"
        or any(surface_type(v)!="ELIGIBLE_LABEL" for v in ("PEM","CONC-G","ASPH-G","CONC-GRVD","ASPH-CONC-F"))
        or any(surface_type(v)=="ELIGIBLE_LABEL" for v in ("paved","ASPH-GRVL","BITUM","ASPH-TURF","DIRT"))):
        raise ValueError("Runway material classification regression")
    cols,rows=load(MASTER)
    if cols!=COLUMNS or not rows: raise ValueError("Missing master fields or airport rows")
    ids=set()
    codes=set()
    master={}
    for line,row in enumerate(rows,2):
        ident=row["source_airport_id"].strip()
        country=row["country_iso"].strip()
        name=row["airport_name"].strip()
        code=(row["gps_code"] or row["ident"]).strip()
        if not ident or ident in ids: raise ValueError(f"Row {line}: empty/duplicate source ID")
        ids.add(ident)
        master[ident]=row
        if len(country)!=2 or country!=country.upper() or not country.isalpha() or not name:
            raise ValueError(f"Row {line}: invalid country/name")
        if code: codes.add((country,code))
        try: length=float(row["runway_length_m"])
        except ValueError: raise ValueError(f"Row {line}: invalid length") from None
        if not math.isfinite(length) or length<1200:
            raise ValueError(f"Row {line}: runway shorter than 1200m")
        if surface_type(row["runway_surface"].strip().strip(chr(39)+chr(34)))!="ELIGIBLE_LABEL":
            raise ValueError(f"Row {line}: unverified asphalt/concrete surface")
        if row["minimum_eligible_level"]!="1" or row["runway_status"]!="RUNWAY_QUALIFIED":
            raise ValueError(f"Row {line}: invalid runway-level marker")
        origin=row["source_type"]
        category=row["assigned_category"]
        if origin=="OURAIRPORTS":
            if not ident.isdigit() or category:
                raise ValueError(f"Row {line}: real dataset airports have no final category yet")
        elif origin=="FICTIONAL":
            if not ident.startswith("fictional:") or category not in CATEGORIES:
                raise ValueError(f"Row {line}: fictional airport needs explicit six-tier category")
        else: raise ValueError(f"Row {line}: unknown airport source type {origin}")

    conflict_cols,reported_conflicts=load(CODE_CONFLICTS)
    expected_conflicts=code_conflicts(rows)
    if conflict_cols!=set(CONFLICT_COLUMNS) or reported_conflicts!=expected_conflicts:
        raise ValueError("Source airport-code conflict queue is stale or invalid")
    sources=sorted(GENERATED.glob("group*/group*_technical_candidates.csv"))
    if not sources: raise ValueError("Missing airport screening groups")
    seen=set()
    screened=0
    for path in sources:
        _,raw_rows=load(path)
        if not raw_rows:
            if path.parent.name != "group49":
                raise ValueError(f"Screen empty: {path}")
            counts_path=path.parent/"group49_country_counts.csv"
            count_cols,count_rows=load(counts_path)
            if count_cols!={"country_iso","country","technical_candidates","minimum_eligible_level"} or len(count_rows)!=2 or any(r["technical_candidates"]!="0" for r in count_rows) or {r["country_iso"] for r in count_rows}!={"AQ","TOTAL"}:
                raise ValueError("Group 49 empty screen needs verified AQ/TOTAL zero counts")
            continue
        for original in raw_rows:
            ident=original["ourairports_id"]
            if ident in seen: raise ValueError(f"Duplicate source ID between groups: {ident}")
            seen.add(ident)
            screened+=1
            row=master.get(ident)
            if row is None or row["source_type"]!="OURAIRPORTS":
                raise ValueError(f"Screened airport {ident} missing from master")
            if (row["country_iso"],row["airport_name"],row["runway_surface"])!=(
                    original["iso_country"],original["airport_name"],original["surface"]):
                raise ValueError(f"Screen/master fields mismatch for airport {ident}")
            if abs(float(row["runway_length_m"])-float(original["longest_reported_eligible_runway_m"]))>0.01:
                raise ValueError(f"Screen/master runway mismatch for airport {ident}")

    fcols,fictional=load(FICTIONAL)
    if fcols!=COLUMNS or not fictional: raise ValueError("Missing fictional airports overlay")
    fiction_ids=set()
    for definition in fictional:
        ident=definition["source_airport_id"]
        if ident in fiction_ids: raise ValueError(f"Duplicate fictional airport {ident}")
        fiction_ids.add(ident)
        if master.get(ident)!=definition:
            raise ValueError(f"Fictional airport missing or not identical in master: {ident}")
    expected=next((r for r in fictional if r["ident"]=="LYAL"),None)
    if not expected or (expected["airport_name"],expected["country_iso"],
                       expected["runway_length_m"],expected["runway_surface"],
                       expected["assigned_category"])!=(
                       "Aleksandrovo Airport","RS","2200.0","Asphalt","Local"):
        raise ValueError("Owner-approved fictional Aleksandrovo Airport LYAL must be preserved")
    if len(master)!=screened+len(fictional):
        raise ValueError(f"Master has {len(master)}, expected {screened}+{len(fictional)}")

    group4=GENERATED/"group4/group4_technical_candidates.csv"
    _,group4rows=load(group4)
    _,prior=load(HISTORICAL14)
    for row in prior:
        if row["status"]!="REVIEW":
            raise ValueError("Prior Group 4 candidate must remain historic review")
        if not any(s["gps_code"]==row["icao"] or s["ident"]==row["icao"] for s in group4rows):
            raise ValueError(f"Old Group 4 airport lost: {row['icao']}")
    print(f"VALIDATED {len(master)} airports: {screened} screened in {len(sources)} groups, {len(fictional)} fictional (LYAL Level 1), historic Group 4 preserved; {len(expected_conflicts)} code conflicts queued")

if __name__=="__main__":
    try:validate()
    except Exception as exc:
        print(f"VALIDATION FAILED: {exc}",file=sys.stderr)
        sys.exit(1)
